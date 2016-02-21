local dependencies = require "bsrocks.rocks.dependencies"
local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"
local utils = require "bsrocks.lib.utils"

local installDirectory = settings.installDirectory
local servers = settings.servers
local patchServers = settings.patchServers

local fetched = false
local installed = {}

local function save(rockS)
	local files = rockspec.extractFiles(rockS)

	local downloaded = download(rockS.source, files)

	if not downloaded then
		error("Cannot find downloader for " .. rockS.source.url)
	end

	rockspec.saveFiles(rockS, downloaded, installDirectory)
	fileWrapper.write(fs.combine(installDirectory, rockS.package .. ".rockspec"), serialize.serialize(rockS))
	installed[rockS.package] = rockS
end

local function getInstalled()
	if not fetched then
		fetched = true

		for name, version in pairs(settings.existing) do
			installed[name] = { version = version, package = name, builtin = true }
		end

		if fs.exists(installDirectory) then
			for _, file in ipairs(fs.list(installDirectory)) do
				if file:match("%.rockspec") then
					local data = serialize.unserialize(fileWrapper.read(fs.combine(installDirectory, file)))
					installed[data.package] = data
				end
			end
		end
	end

	return installed
end

local function install(name, version, constraints)
	local server, manifest = rockspec.findRock(servers, name)
	if not server then
		error("Cannot find '" .. name .. "'")
	end

	if not version then
		version = rockspec.latestVersion(manifest, name, constraints)
	end

	local versions = getInstalled()
	local current = versions[name]
	if current then
		if current.version == version then
			error("Already installed")
		end
	end

	local rockspec = rockspec.fetchRockspec(server, name, version)

	local installed = getInstalled()
	for _, deps in ipairs(rockspec.dependencies) do
		local dependency = dependencies.parseDependency(deps)
		local name = dependency.name
		local current = installed[name]

		if current then
			local version = dependencies.parseVersion(current.version)
			if not dependencies.matchConstraints(version, dependency.constraints) then
				print("Should update " .. dependency.name .. " ( got " .. current.version .. ", need " .. deps .. ")")
			end
		else
			print("Installing dependency " .. name)
			install(name, nil, dependency.constraints)
		end
	end

	save(rockspec)
end

return {
	getInstalled = getInstalled,
	install = install,
}
