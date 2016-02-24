local download = require "bsrocks.downloaders"
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
	local info = fs.combine(patchDirectory, "rocks/" .. name .. "-" .. version .. ".rockspec")
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))

		if data.version == version then
			error("Already at version " .. version, 0)
		end
	else
		data = rockspec.fetchRockspec(rock.server, name, version)
	end

	data.version = version
	fileWrapper.write(info, serialize.serialize(data))

	local locManifest, locPath = manifest.loadLocal()
	local versions = locManifest.repository[name]
	if not versions then
		versions = {}
		locManifest.repository[name] = versions
	end
	versions[version] = { { arch = "rockspec"  } }
	fileWrapper.write(locPath, serialize.serialize(locManifest))

	print("Added rockspec. Feel free to edit away!")
end

local description = [[
  <name>    The name of the package
  [version] The version to use

Refreshes a rockspec file to the original.
]]

return {
	name = "add-rockspec",
	help = "Add or update a rockspec",
	syntax = "<name> [version]",
	description = description,
	execute = execute,
}
