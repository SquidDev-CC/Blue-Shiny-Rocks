local diff = require "bsrocks.lib.diffmatchpatch"
local unserialize = require "bsrocks.lib.serialize".unserialize

local cache = {}
local function fetchPatchspec(servers, name)
	local result = cache[name] or false
	if result then return result end

	for _, server in ipairs(servers) do
		local handle = http.get(servers .. name)
		if handle then
			local contents = handle.readAll()
			handle.close()

			result = unserialize(contenets)
			break
		end
	end

	cache[name] = result
	return result
end

local function makePatches(original, changed)
	local patches, remove = {}, {}
	local files = {}

	for path, originalContents in pairs(original) do
		local changedContents = changed[path]
		if changedContents then
			local diffs = diff.diff_main(originalContents, changedContents)
			diff.diff_cleanupSemantic(diffs)

			os.queueEvent("diff")
			coroutine.yield("diff")

			local patch = diff.patch_toText(diff.patch_make(originalContents, diffs))
			if #patch > 0 then
				patches[#patches + 1] = path
				files[path .. ".patch"] = patch
			end

			os.queueEvent("diff")
			coroutine.yield("diff")
		else
			remove[#remove + 1] = path
		end
	end

	local added = {}
	for path, contents in pairs(changed) do
		if not original[path] then
			added[#added + 1] = path
			files[path] = contents
		end
	end

	return files, patches, added, remove
end

local function applyPatches(original, files, patches, added, removed)
	assert(type(original) == "table", "exected table for original")
	assert(type(files) == "table", "exected table for replacement")
	assert(type(patches) == "table", "exected table for patches")
	assert(type(added) == "table", "exected table for added")
	assert(type(removed) == "table", "exected table for removed")

	local changed = {}
	local modified = {}
	for _, file in ipairs(patches) do
		local patchContents = files[file .. ".patch"]
		local originalContents = original[file]

		if not patchContents then error("Cannot find patch " .. file .. ".patch") end
		if not originalContents then error("Cannot find original " .. file) end

		local patches = diff.patch_fromText(patchContents)
		local changedContent = diff.patch_apply(patches, originalContents)

		changed[file] = changedContent
		modified[file] = true

		os.queueEvent("diff")
		coroutine.yield("diff")
	end

	for _, file in ipairs(removed) do
		modified[file] = true
	end

	for _, file in ipairs(added) do
		local changedContents = files[file]
		if not changedContents then error("Cannot find added file " .. file) end

		changed[file] = changedContents
		modified[file] = true
	end

	for file, contents in pairs(original) do
		if not modified[file] then
			changed[file] = contents
		end
	end

	return changed
end

return {
	fetchPatchspec = fetchPatchspec,
	makePatches = makePatches,
	applyPatches = applyPatches,
}
