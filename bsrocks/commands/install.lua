local fileWrapper = require "bsrocks.lib.files"
local install = require "bsrocks.rocks.install"
local repo = require "bsrocks.rocks.repository"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"

local installDirectory = settings.installDirectory
local servers = settings.servers

local function execute(name, version)
	if not name then error("Expected name", 0) end

	local server, manifest = repo.findRock(servers, name)
	if not server then
		error("Cannot find '" .. name .. "'", 0)
	end

	if not version then
		version = repo.latestVersion(manifest, name)
	end

	local versions = install.getInstalled()
	local current = versions[name]
	if current then
		print("Current version is " .. current.version)
		if current.version == version then
			error("Already installed", 0)
		end
	end

	local rockspec = repo.fetchRockspec(server, name, version)

	for _, name in ipairs(rockspec.dependencies) do
		print(name)
	end

	install.save(rockspec)
end

return {
	name = "install",
	help = "Install a package",
	syntax = "<name> [version]",
	execute = execute
}
