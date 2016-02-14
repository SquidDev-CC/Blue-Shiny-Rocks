local diff = require "bsrocks.rocks.diff"

local function execute(name)
	if not name then error("Expected name") end

	local original = shell.resolve("rocks-original/" .. name)
	local changed = shell.resolve("rocks-changes/" .. name)

	if not fs.exists(original) then error("Cannot find original sources", 0) end
	if not fs.exists(changed) then error("Cannot find changed sources", 0) end

	local patch = shell.resolve("rocks/" .. name)
	fs.delete(patch)

	diff(original, changed, patch)
end

return {
	name = "make-patches",
	help = "Make patches for a package",
	syntax = "<name>",
	execute = execute
}
