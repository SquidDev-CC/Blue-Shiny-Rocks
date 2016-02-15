local diff = require "bsrocks.rocks.diff"
local fileWrapper = require "bsrocks.lib.files"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local serialize = require "bsrocks.lib.serialize"

local function execute(name)
	if not name then error("Expected name", 0) end

	local original = fs.combine(patchDirectory, "rocks-original/" .. name)
	local changed = fs.combine(patchDirectory, "rocks-changes/" .. name)

	fileWrapper.assertExists(original, "original sources", 0)
	fileWrapper.assertExists(changed, "changed sources", 0)

	local patch = shell.resolve("rocks/" .. name)
	fs.delete(patch)

	local info = patch .. ".patchspec"
	local data = {}
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))
	end

	local changed, added, removed = diff.makePatches(original, changed, patch)
	data.changed = changed
	data.added = added
	data.removed = removed

	fileWrapper.write(info, serialize.serialize(data))
end

return {
	name = "make-patches",
	help = "Make patches for a package",
	syntax = "<name>",
	execute = execute
}
