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

	local data = {}
	local info = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))
	end

	if data.version == version then
		error("Already at version " .. version, 0)
	end

	local rock = rockspec.fetchRockspec(server, name, version)

	data.version = version
	fileWrapper.write(info, serialize.serialize(data))
	fs.delete(fs.combine(patchDirectory, "rocks-original/" .. name))

	print("Run 'fetch " .. name .. "' to download files")
end

local description = [[
  <name>    The name of the package
  [version] The version to use

Adds a patchspec file, or sets the version of an existing one.
]]

return {
	name = "add-patchspec",
	help = "Add or update a package for patching",
	syntax = "<name> [version]",
	description = description,
	execute = execute,
}
