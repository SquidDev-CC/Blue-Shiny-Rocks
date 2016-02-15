local diff = require "bsrocks.rocks.diff"
local serialize = require "bsrocks.lib.serialize"
local fileWrapper = require "bsrocks.lib.files"

local function execute(name)
	if not name then error("Expected name", 0) end

	local original = shell.resolve("rocks-original/" .. name)
	local patch = shell.resolve("rocks/" .. name)
	local changed = shell.resolve("rocks-changes/" .. name)

	if not fs.exists(original) then error("Cannot find original sources", 0) end

	local info = patch .. ".patchspec"
	if not fs.exists(info) then error("Cannot find original sources", 0) end

	local data = serialize.unserialize(fileWrapper.read(info))
	fs.delete(changed)

	diff.applyPatches(original, changed, patch, data.changed or {}, data.added or {}, data.removed or {})
end

return {
	name = "apply-patches",
	help = "Apply patches for a package",
	syntax = "<name>",
	execute = execute
}
