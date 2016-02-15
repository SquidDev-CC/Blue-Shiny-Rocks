local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local settings = require "bsrocks.lib.settings"
local repo = require "bsrocks.rocks.repository"
local serialize = require "bsrocks.lib.serialize"

local installDirectory = settings.installDirectory
local servers = settings.servers

local function execute(name, version)
	if not name then error("Expected name", 0) end

	-- TODO: Multiple servers
	local server = servers[1]
	if not version then
		print("Fetching manifest from " .. server)
		local manifest = repo.fetchManifest(server)
		if not manifest.repository[name] then
			error("Cannot find '" .. name .. "'", 0)
		end
		version = repo.latestVersion(manifest, name)
	end

	print("Using " .. name .. "-" .. version)

	local rockspec = repo.fetchRockspec(server, name, version)

	for _, name in ipairs(rockspec.dependencies) do
		print(name)
	end
	error("Done", 0)

	local files = repo.extractFiles(rockspec)
	if #files == 0 then error("No files for " .. name .. "-" .. version, 0) end

	local downloaded = download(rockspec.source, files)

	if not downloaded then error("Cannot find downloader for " .. rockspec.source.url, 0) end
	print()

	repo.saveFiles(rockspec, downloaded, installDirectory)
end

return {
	name = "install",
	help = "Install a package",
	syntax = "<name> [version]",
	execute = execute
}
