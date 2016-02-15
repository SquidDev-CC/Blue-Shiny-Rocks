local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local settings = require "bsrocks.lib.settings"
local repo = require "bsrocks.rocks.repository"
local serialize = require "bsrocks.lib.serialize"

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

	local rockspec = repo.fetchRockspec(server, name, version)

	for _, name in ipairs(rockspec.dependencies) do
		print(name)
	end
	error("Not actually installing", 0)

	local files = repo.extractFiles(rockspec)
	if #files == 0 then error("No files for " .. name .. "-" .. version, 0) end

	local downloaded = download(rockspec.source, files)

	if not downloaded then error("Cannot find downloader for " .. rockspec.source.url, 0) end
	print()

	repo.saveFiles(rockspec, downloaded, installDirectory)
	fileWrapper.write(fs.combine(installDirectory, name .. ".rockspec"), serialize.serialize(rockspec))
end

return {
	name = "install",
	help = "Install a package",
	syntax = "<name> [version]",
	execute = execute
}
