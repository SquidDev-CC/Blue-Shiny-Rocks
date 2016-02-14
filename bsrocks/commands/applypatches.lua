local diff = require "bsrocks.rocks.diff"

local function execute(name)
	if not name then error("Expected name") end

	local original = shell.resolve("rocks-original/" .. name)
	local patch = shell.resolve("rocks/" .. name)
	local changed = shell.resolve("rocks-changes/" .. name)

	if not fs.exists(original) then error("Cannot find original sources", 0) end

	fs.delete(changed)

	if not fs.exists(patch) then
		-- No patches, just copy
		fs.copy(original, changed)
	else
		-- Else: apply patches
		diff.applyPatches(original, changed, patch)
	end
end

return {
	name = "apply-patches",
	help = "Apply patches for a package",
	syntax = "<name>",
	execute = execute
}
