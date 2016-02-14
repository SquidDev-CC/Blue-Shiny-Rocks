local repo = require "bsrocks.rocks.repository"
local download = require "bsrocks.downloaders"

local function execute(name, version)
	if not name then error("Expected name", 0) end

	-- TODO: Multiple servers
	local server = repo.servers[1]
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

	local files = repo.extractFiles(rockspec)
	if #files == 0 then error("No files for " .. name .. "-" .. version, 0) end

	local downloaded = download(rockspec.source, files)

	if not downloaded then error("Cannot find downloader for " .. rockspec.source.url) end
	print()

	repo.saveFiles(rockspec, downloaded, shell.resolve("rocks-original/" .. name))
	repo.saveFiles(rockspec, downloaded, shell.resolve("rocks-changes/" .. name))
end

return {
	name = "install",
	help = "Install a repository",
	syntax = "<name> [version]",
	execute = execute
}
