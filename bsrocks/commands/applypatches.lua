local patchspec = require "bsrocks.rocks.patchspec"
local fileWrapper = require "bsrocks.lib.files"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local serialize = require "bsrocks.lib.serialize"

local function execute(name)
	if not name then error("Expected name", 0) end

	local original = fs.combine(patchDirectory, "rocks-original/" .. name)
	local patch = fs.combine(patchDirectory, "rocks/" .. name)
	local changed = fs.combine(patchDirectory, "rocks-changes/" .. name)

	fileWrapper.assertExists(original, "original sources", 0)

	local info = patch .. ".patchspec"
	fileWrapper.assertExists(info, "patchspec", 0)

	local data = serialize.unserialize(fileWrapper.read(info))
	fs.delete(changed)

	local originalSources = fileWrapper.readDir(original)
	local replaceSources = {}
	if fs.exists(patch) then replaceSources = fileWrapper.readDir(patch) end

	local changedSources = patchspec.applyPatches(
		originalSources, replaceSources,
		data.patches or {}, data.added or {}, data.removed or {}
	)

	fileWrapper.writeDir(changed, changedSources)
end

return {
	name = "apply-patches",
	help = "Apply patches for a package",
	syntax = "<name>",
	execute = execute
}
