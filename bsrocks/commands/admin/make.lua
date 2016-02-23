local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local patchspec = require "bsrocks.rocks.patchspec"
local serialize = require "bsrocks.lib.serialize"

local function execute(...)
	local patched, force
	if select("#", ...) == 0 then
		force = false
		patched = patchspec.getAll()
	else
		force = true
		for _, name in pairs({...}) do
			local file = fs.combine(patchDirectory, name .. ".patchspec")
			if not fs.exists(file) then error("No such patchspec " .. name, 0) end

			patched[name] = serialize.unserialize(fileWrapper.read(file))
		end
	end

	for name, data in pairs(patched) do
		local original = fs.combine(patchDirectory, "rocks-original/" .. name)
		local changed = fs.combine(patchDirectory, "rocks-changes/" .. name)
		local patch = fs.combine(patchDirectory, "rocks/" .. name)
		local info = patch .. ".patchspec"

		log("Making " .. name)

		fileWrapper.assertExists(original, "original sources for " .. name, 0)
		fileWrapper.assertExists(changed, "changed sources for " .. name, 0)
		fileWrapper.assertExists(info, "patchspec for " .. name, 0)

		fs.delete(patch)

		local data = serialize.unserialize(fileWrapper.read(info))
		local originalSources = fileWrapper.readDir(original)
		local changedSources = fileWrapper.readDir(changed)

		local files, patches, added, removed = patchspec.makePatches(originalSources, changedSources)
		data.patches = patches
		data.added = added
		data.removed = removed

		fileWrapper.writeDir(patch, files)
		fileWrapper.write(info, serialize.serialize(data))
	end
end

local description = [[
  [name] The name of the package to create patches for. Otherwise all packages will make their patches.
]]

return {
	name = "make-patches",
	help = "Make patches for a package",
	syntax = "[name]...",
	description = description,
	execute = execute
}
