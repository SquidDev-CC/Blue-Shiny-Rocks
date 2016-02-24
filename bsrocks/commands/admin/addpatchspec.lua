local fileWrapper = require "bsrocks.lib.files"
local manifest = require "bsrocks.rocks.manifest"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"

local function execute(name, version)
	if not name then error("Expected name", 0) end
	name = name:lower()

	local rock = rockspec.findRockspec(name)
	if not rock then
		error("Cannot find '" .. name .. "'", 0)
	end

	if not version then
		version = rockspec.latestVersion(rock, name)
	end

	local data = {}
	local info = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))
	end

	if data.version == version then
		error("Already at version " .. version, 0)
	end

	data.version = version
	fileWrapper.write(info, serialize.serialize(data))
	fs.delete(fs.combine(patchDirectory, "rocks-original/" .. name))

	local locManifest, locPath = manifest.loadLocal()
	locManifest.patches[name] = version
	fileWrapper.write(locPath, serialize.serialize(locManifest))

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
