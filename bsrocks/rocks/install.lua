local dependencies = require "bsrocks.rocks.dependencies"
local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local patchspec = require "bsrocks.rocks.patchspec"
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"
local tree = require "bsrocks.downloaders.tree"
local utils = require "bsrocks.lib.utils"

local installDirectory = settings.installDirectory
local log, warn = utils.log, utils.warn

local fetched = false
local installed = {}
local installedPatches = {}

local function save(rockS, patchS)
	local blacklist = {}
	if patchspec and patchspec.remove then
		for _, v in ipairs(patchspec.remove) do blacklist[v] = true end
	end

	local files = rockspec.extractFiles(rockS, blacklist)

	for _, file in ipairs(files) do
		local ext = file:match("[^/]%.(%w+)$")
		if ext and ext ~= "lua" then
			warn("File extension is not lua for " .. file .. ". It may not work correctly.")
		end
	end
	local downloaded = download(rockS.source, files)

	if not downloaded then
		error("Cannot find downloader for " .. rockS.source.url .. ". . Please suggest this package to be patched.", 0)
	end

	if patchS then
		local patchFiles = rockspec.extractFiles(patchS)
		local downloadPatch = tree(patchS.server .. rockS.name, patchFiles)

		files = applyPatches(downloaded, downloadPatch, patchS.patches or {}, patchS.added or {}, patchS.removed or {})
	end

	local build = rockS.build
	if build then
		if build.modules then
			local moduleDir = fs.combine(installDirectory, "lib")
			for module, file in pairs(build.modules) do
				fileWrapper.write(fs.combine(moduleDir, module:gsub("%.", "/") .. ".lua"), files[file])
			end
		end

		-- Extract install locations
		if build.install then
			for name, install in pairs(build.install) do
				local dir = fs.combine(installDirectory, name)
				for name, file in pairs(install) do
					fileWrapper.write(fs.combine(dir, name .. ".lua"), files[file])
				end
			end
		end
	end

	fileWrapper.write(fs.combine(installDirectory, rockS.package .. ".rockspec"), serialize.serialize(rockS))

	if patchS then
		fileWrapper.write(fs.combine(installDirectory, rockS.package .. ".patchspec"), serialize.serialize(patchS))
	end

	installed[rockS.package] = rockS
end

local function remove(rockS, patchS)
	local blacklist = {}
	if patchspec and patchspec.remove then
		for _, v in ipairs(patchspec.remove) do blacklist[v] = true end
	end

	local files = rockspec.extractFiles(rockS, blacklist)

	local build = rockS.build
	if build then
		if build.modules then
			local moduleDir = fs.combine(installDirectory, "lib")
			for module, file in pairs(build.modules) do
				fs.delete(fs.combine(moduleDir, module:gsub("%.", "/") .. ".lua"))
			end
		end

		-- Extract install locations
		if build.install then
			for name, install in pairs(build.install) do
				local dir = fs.combine(installDirectory, name)
				for name, file in pairs(install) do
					fs.delete(fs.combine(dir, name .. ".lua"))
				end
			end
		end
	end

	fs.delete(fs.combine(installDirectory, rockS.package .. ".rockspec"))
	installed[rockS.package] = nil
end

local function getInstalled()
	if not fetched then
		fetched = true

		for name, version in pairs(settings.existing) do
			installed[name:lower()] = { version = version, package = name, builtin = true }
		end

		if fs.exists(installDirectory) then
			for _, file in ipairs(fs.list(installDirectory)) do
				if file:match("%.rockspec") then
					local data = serialize.unserialize(fileWrapper.read(fs.combine(installDirectory, file)))
					installed[data.package:lower()] = data
				elseif file:match("%.patchspec") then
					local name = file:gsub("%.patchspec", ""):lower()
					local data = serialize.unserialize(fileWrapper.read(fs.combine(installDirectory, file)))
					installedPatches[name] = data
				end
			end
		end
	end

	return installed, installedPatches
end

local function install(name, version, constraints)
	name = name:lower()

	-- Do the cheapest action ASAP
	local installed = getInstalled()
	local current = installed[name]
	if current and ((version == nil and constraints == nil) or current.version == version) then
		error("Already installed", 0)
	end

	local rockManifest = rockspec.findRockspec(name)

	if not rockManifest then
		error("Cannot find '" .. name .. "'", 0)
	end

	local patchManifest = patchspec.findPatchspec(name)

	if not version then
		if patchManifest then
			version = patchManifest.patches[name]
		else
			version = rockspec.latestVersion(rockManifest, name, constraints)
		end
	end

	if current and current.version == version then
		error("Already installed", 0)
	end

	local patchspec = patchManifest and patchspec.fetchPatchspec(patchManifest.server, name)
	local rockspec = rockspec.fetchRockspec(rockManifest.server, name, version)

	if rockspec.build and rockspec.build.type ~= "builtin" then
		error("Cannot build type '" .. rockspec.build.type .. "'. Please suggest this package to be patched.", 0)
	end

	for _, deps in ipairs(rockspec.dependencies) do
		local dependency = dependencies.parseDependency(deps)
		local name = dependency.name:lower()
		local current = installed[name]

		if current then
			local version = dependencies.parseVersion(current.version)
			if not dependencies.matchConstraints(version, dependency.constraints) then
				log("Updating dependency " .. name)
				install(name, nil, dependency.constraints)
			end
		else
			log("Installing dependency " .. name)
			install(name, nil, dependency.constraints)
		end
	end

	save(rockspec, patchspec)
end

return {
	getInstalled = getInstalled,
	install = install,
	remove = remove,
}
