local diff = require "bsrocks.rocks.diff"
local serialize = require "bsrocks.lib.serialize"
local fileWrapper = require "bsrocks.lib.files"

local function execute(name)
	if not name then error("Expected name") end

	local original = shell.resolve("rocks-original/" .. name)
	local changed = shell.resolve("rocks-changes/" .. name)

	if not fs.exists(original) then error("Cannot find original sources", 0) end
	if not fs.exists(changed) then error("Cannot find changed sources", 0) end

	local info = shell.resolve("rocks/" .. name .. "/info.lua")
	local data = {}
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))
	end

	local patch = shell.resolve("rocks/" .. name)
	fs.delete(patch)

	data.changed = diff.makePatches(original, changed, patch)
	fileWrapper.write(info, serialize.serialize(data))
end

return {
	name = "make-patches",
	help = "Make patches for a package",
	syntax = "<name>",
	execute = execute
}
