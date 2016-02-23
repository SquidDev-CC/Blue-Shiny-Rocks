local diff = require "bsrocks.lib.diffmatchpatch"
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local settings = require "bsrocks.lib.settings"
local unserialize = require "bsrocks.lib.serialize".unserialize

local patchDirectory, servers = settings.patchDirectory, settings.patchServers

local cache = {}
local function findPatchspec(name)
	local result = cache[name] or false
	if result then return result end

	log("Fetching patchspec for " .. name)
	local patchS = name .. ".patchspec"

	for _, server in ipairs(servers) do
		local handle = http.get(server .. patchS)
		if handle then
			local contents = handle.readAll()
			handle.close()

			result = unserialize(contents)
			result.server = server
			break
		end
	end

	cache[name] = result or false
	return result
end

local installed = nil
local function getAll()
	if not installed then
		installed = {}
		local dir = fs.combine(patchDirectory, "rocks")
		for _, file in ipairs(fs.list(dir)) do
			if file:match("%.patchspec$") then
				local path = fs.combine(dir, file)
				local patchspec = unserialize(fileWrapper.read(path))
				installed[file:gsub("%.patchspec$", "")] = patchspec
			end
		end
	end

	return installed
end

local function extractFiles(patch)
	local files, n = {}, 0

	if patch.added then
		for _, file in ipairs(patch.added) do
			n = n + 1
			files[n] = file
		end
	end

	if patch.patches then
		for _, file in ipairs(patch.patches) do
			n = n + 1
			files[n] = file .. ".patch"
		end
	end

	return files
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
	findPatchspec = findPatchspec,
	makePatches = makePatches,
	applyPatches = applyPatches,
	extractFiles = extractFiles,
	getAll = getAll,
}
