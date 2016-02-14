local unserialize = require "bsrocks.lib.unserialize"

local servers = {
	'http://luarocks.org/repositories/rocks/',
}

local function fetchManifest(repo)
	local handle = http.get(repo .. "manifest-5.1")
	if not handle then
		error("Cannot fetch manifest: " .. repo)
	end

	local contents = handle.readAll()
	handle.close()
	return unserialize(contents)
end

local function latestVersion(manifest, name)
	local module = manifest.repository[name]
	if not module then error("Cannot find " .. name) end

	for name, dat in pairs(module) do
		version = name
	end

	if not version then error("Cannot find version for " .. name) end

	return version
end

local function fetchRockspec(repo, name, version)
	local handle = http.get(repo .. name .. '-' .. version .. '.rockspec')
	if not handle then
		error("Canot fetch " .. name .. "-" .. version .. " from " .. repo)
	end

	local contents = handle.readAll()
	handle.close()
	return unserialize(contents)
end

--- Extract files to download from rockspec
-- @see https://github.com/keplerproject/luarocks/wiki/Rockspec-format
local function extractFiles(rockspec)
	local files, fileN = {}, 0

	local build = rockspec.build
	if build then
		if build.modules then
			for _, file in pairs(build.modules) do
				fileN = fileN + 1
				files[fileN] = file
			end
		end

		-- Extract install locations
		if build.install then
			for _, install in pairs(build.install) do
				for _, file in pairs(install) do
					fileN = fileN + 1
					files[fileN] = file
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
				local handle = fs.open(fs.combine(moduleDir, module:gsub("%.", "/") .. ".lua"), "w")
				handle.write(files[file])
				handle.close()
			end
		end

		-- Extract install locations
		if build.install then
			for name, install in pairs(build.install) do
				local dir = fs.combine(directory, name)
				for name, file in pairs(install) do
					local handle = fs.open(fs.combine(dir, name .. ".lua"), "w")
					handle.write(files[file])
					handle.close()
				end
			end
		end
	end
end

return {
	servers = servers,
	fetchManifest = fetchManifest,
	latestVersion = latestVersion,
	fetchRockspec = fetchRockspec,

	extractFiles = extractFiles,
	saveFiles = saveFiles,
}
