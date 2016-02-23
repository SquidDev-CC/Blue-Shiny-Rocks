local dependencies = require "bsrocks.rocks.dependencies"
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local servers = require "bsrocks.lib.settings".servers
local unserialize = require "bsrocks.lib.serialize".unserialize

local manifestCache = {}
local rockCache = {}

local function fetchManifest(server)
	local manifest = manifestCache[server]
	if manifest then return manifest end

	log("Fetching manifest " .. server)

	local handle = http.get(server .. "manifest-5.1")
	if not handle then
		error("Cannot fetch manifest: " .. server, 0)
	end

	local contents = handle.readAll()
	handle.close()

	manifest = unserialize(contents)
	manifestCache[server] = manifest
	return manifest
end

local function findRock(name)
	for _, server in ipairs(servers) do
		local manifest = fetchManifest(server)
		if manifest.repository[name] then
			return server, manifest
		end
	end

	return
end

local function latestVersion(manifest, name, constraints)
	local module = manifest.repository[name]
	if not module then error("Cannot find " .. name) end

	local version
	for name, dat in pairs(module) do
		local ver = dependencies.parseVersion(name)
		if constraints then
			if dependencies.matchConstraints(ver, constraints) then
				if not version or ver > version then
					version = ver
				end
			end
		elseif not version or ver > version then
			version = ver
		end
	end

	if not version then error("Cannot find version for " .. name) end

	return version.name
end

local function fetchRockspec(repo, name, version)
	local whole = name .. "-" .. version

	local rockspec = rockCache[whole]
	if rockspec then return rockspec end

	log("Fetching rockspec " .. whole)

	local handle = http.get(repo .. name .. '-' .. version .. '.rockspec')
	if not handle then
		error("Canot fetch " .. name .. "-" .. version .. " from " .. repo, 0)
	end

	local contents = handle.readAll()
	handle.close()

	rockspec = unserialize(contents)
	rockCache[whole] = rockspec
	return rockspec
end

--- Extract files to download from rockspec
-- @see https://github.com/keplerproject/luarocks/wiki/Rockspec-format
local function extractFiles(rockspec, blacklist)
	local files, fileN = {}, 0
	blacklist = blacklist or {}

	local build = rockspec.build
	if build then
		if build.modules then
			for _, file in pairs(build.modules) do
				if not blacklist[file] then
					fileN = fileN + 1
					files[fileN] = file
				end
			end
		end

		-- Extract install locations
		if build.install then
			for _, install in pairs(build.install) do
				for _, file in pairs(install) do
					if not blacklist[file] then
						fileN = fileN + 1
						files[fileN] = file
					end
				end
			end
		end
	end

	return files
end

local function saveFiles(rockspec, files, directory)
	local build = rockspec.build
	if build then
		if build.modules then
			local moduleDir = fs.combine(directory, "lib")
			for module, file in pairs(build.modules) do
				fileWrapper.write(fs.combine(moduleDir, module:gsub("%.", "/") .. ".lua"), files[file])
			end
		end

		-- Extract install locations
		if build.install then
			for name, install in pairs(build.install) do
				local dir = fs.combine(directory, name)
				for name, file in pairs(install) do
					fileWrapper.write(fs.combine(dir, name .. ".lua"), files[file])
				end
			end
		end
	end
end

return {
	fetchManifest = fetchManifest,
	findRock = findRock,
	latestVersion = latestVersion,
	fetchRockspec = fetchRockspec,

	extractFiles = extractFiles,
	saveFiles = saveFiles,
}
