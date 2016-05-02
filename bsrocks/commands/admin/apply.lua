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
	elseif select("#", ...) == 1 and (... == "-f"  or ... == "--force") then
		force = true
		patched = patchspec.getAll()
	else
		force = true
		patched = {}
		for _, name in pairs({...}) do
			name = name:lower()
			local file = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
			if not fs.exists(file) then error("No such patchspec " .. name, 0) end

			patched[name] = serialize.unserialize(fileWrapper.read(file))
		end
	end

	local hasChanged = false
	for name, data in pairs(patched) do
		local original = fs.combine(patchDirectory, "rocks-original/" .. name)
		local patch = fs.combine(patchDirectory, "rocks/" .. name)
		local changed = fs.combine(patchDirectory, "rocks-changes/" .. name)

		if force or not fs.isDir(changed) then
			hasChanged = true
			log("Applying " .. name)

			fileWrapper.assertExists(original, "original sources for " .. name, 0)
			fs.delete(changed)

			local originalSources = fileWrapper.readDir(original, fileWrapper.readLines)
			local replaceSources = {}
			if fs.exists(patch) then replaceSources = fileWrapper.readDir(patch, fileWrapper.readLines) end

			local changedSources = patchspec.applyPatches(
				originalSources, replaceSources,
				data.patches or {}, data.added or {}, data.removed or {}
			)

			fileWrapper.writeDir(changed, changedSources, fileWrapper.writeLines)
		end
	end

	if not hasChanged then
		error("No packages to patch", 0)
	end
end

local description = [[
  [name] The name of the package to apply. Otherwise all un-applied packages will have their patches applied.
]]

return {
	name = "apply-patches",
	help = "Apply patches for a package",
	syntax = "[name]...",
	description = description,
	execute = execute,
}
