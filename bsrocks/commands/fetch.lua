local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"

local patchDirectory = settings.patchDirectory
local servers = settings.servers

local function execute(name, version)
	if not name then error("Expected name", 0) end

	local server, manifest = rockspec.findRock(servers, name)
	if not server then
		error("Cannot find '" .. name .. "'", 0)
	end

	if not version then
		version = rockspec.latestVersion(manifest, name)
	end

	local rockspec = rockspec.fetchRockspec(server, name, version)

	local files = rockspec.extractFiles(rockspec)
	if #files == 0 then error("No files for " .. name .. "-" .. version, 0) end

	local downloaded = download(rockspec.source, files)

	if not downloaded then error("Cannot find downloader for " .. rockspec.source.url, 0) end

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
