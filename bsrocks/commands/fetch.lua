local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local settings = require "bsrocks.lib.settings"
local repo = require "bsrocks.rocks.repository"
local serialize = require "bsrocks.lib.serialize"

local patchDirectory = settings.patchDirectory
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

	local files = repo.extractFiles(rockspec)
	if #files == 0 then error("No files for " .. name .. "-" .. version, 0) end

	local downloaded = download(rockspec.source, files)

	if not downloaded then error("Cannot find downloader for " .. rockspec.source.url, 0) end
	print()

	local dir = fs.combine(patchDirectory, "rocks-original/" .. name)
	for name, contents in pairs(downloaded) do
		fileWrapper.write(fs.combine(dir, name), contents)
	end

	fs.delete(fs.combine(patchDirectory, "rocks-changes/" .. name))

	local info = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
	local data = {}
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))
	end

	data.version = version
	fileWrapper.write(info, serialize.serialize(data))

	print("Run 'apply-patches " .. name .. "' to apply")
end

return {
	name = "fetch",
	help = "Fetch a package for patching",
	syntax = "<name> [version]",
	execute = execute
}
