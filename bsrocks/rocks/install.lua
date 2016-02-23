local dependencies = require "bsrocks.rocks.dependencies"
local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local patchspec = require "bsrocks.rocks.patchspec"
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"
local tree = require "bsrocks.downloaders.tree"

local installDirectory = settings.installDirectory

local fetched = false
local installed = {}

local function save(rockS, patchS)
	local blacklist = {}
	if patchspec and patchspec.remove then
		for _, v in ipairs(patchspec.remove) do blacklist[v] = true end
	end

	local files = rockspec.extractFiles(rockS, blacklist)
	local downloaded = download(rockS.source, files)

	if not downloaded then
		error("Cannot find downloader for " .. rockS.source.url .. ". . Please suggest this package to be patched.", 0)
	end

	if patchS then
		local patchFiles = rockspec.extractFiles(patchS)
		local downloadPatch = tree(patchFiles.server .. rockS.name, patchFiles)

		files = applyPatches(downloaded, downloadPatch, patchS.patches or {}, patchS.added or {}, patchS.removed or {})
	end

	rockspec.saveFiles(rockS, downloaded, installDirectory)
	fileWrapper.write(fs.combine(installDirectory, rockS.package .. ".rockspec"), serialize.serialize(rockS))
	installed[rockS.package] = rockS
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
				end
			end
		end
	end

	return installed
end

local function install(name, version, constraints)
	name = name:lower()

	-- Do the cheapest action ASAP
	local installed = getInstalled()
	local current = installed[name]
	if current and ((version == nil and constraints == nil) or current.version == version) then
		error("Already installed", 0)
	end

	local server, manifest = rockspec.findRock(name)

	if not server then
		error("Cannot find '" .. name .. "'", 0)
	end

	local patchspec = patchspec.findPatchspec(name)
	if not version then
		if patchspec then
			version = patchspec.version
		else
			version = rockspec.latestVersion(manifest, name, constraints)
		end
	end

	if current and current.version == version then
		error("Already installed", 0)
	end

	local rockspec = rockspec.fetchRockspec(server, name, version)

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
}
