local diff = require "bsrocks.lib.diffmatchpatch"
local fileWrapper = require "bsrocks.lib.files"

local function files(file)
	local stack, n = { file }, 1

	return function()
		while n > 0 do
			local top = stack[n]
			n = n - 1

			if fs.isDir(top) then
				for _, file in ipairs(fs.list(top)) do
					n = n + 1
					stack[n] = fs.combine(top, file)
				end
			else
				return top
			end
		end
	end
end

local matches = {
	["^"] = "%^", ["$"] = "%$", ["("] = "%(", [")"] = "%)",
	["%"] = "%%", ["."] = "%.", ["["] = "%[", ["]"] = "%]",
	["*"] = "%*", ["+"] = "%+", ["-"] = "%-", ["?"] = "%?",
	["\0"] = "%z",
}

--- Escape a string for using in a pattern
-- @tparam string pattern The string to escape
-- @treturn string The escaped pattern
local function escapePattern(pattern)
	return (pattern:gsub(".", matches))
end

local function makePatches(original, changed, patches)
	local originalP = escapePattern(original)
	local changedP = escapePattern(changed)
	local patchesP = escapePattern(patches)

	local patches, remove = {}, {}
	for file in files(original) do
		local originalS = fileWrapper.read(file)

		local changedPath = file:gsub("^" .. originalP, changedP)
		if fs.exists(changedPath) then
			local changedS = fileWrapper.read(changedPath)

			local diffs = diff.diff_main(originalS, changedS)
			diff.diff_cleanupSemantic(diffs)

			os.queueEvent("diff")
			coroutine.yield("diff")

			local patch = diff.patch_toText(diff.patch_make(originalS, diffs))
			if #patch > 0 then
				patches[#patches + 1] = file:gsub("^" .. originalP, "")
				fileWrapper.write(file:gsub("^" .. originalP, patchesP) .. ".patch", patch)
			end

			os.queueEvent("diff")
			coroutine.yield("diff")
		else
			remove[#remove + 1] = file:gsub("^" .. originalP, "")
		end
	end

	local added = {}
	for file in files(changed) do
		local originalPath = file:gsub("^" .. changedP, originalP)
		if not fs.exists(originalPath) then
			added[#added + 1] = file:gsub(changedP, "")
		end
	end

	return patches, added, remove
end

local function applyPatches(original, changed, patchDir, patches, added, removed)
	local originalP = "^" .. escapePattern(original)
	local changedP = escapePattern(changed)
	local patchesP = escapePattern(patchDir)

	local modified = {}
	for _, file in ipairs(patches) do
		modified[file:gsub(originalP, "")] = true

		local patchFile = fs.combine(patchDir, file) .. ".patch"
		local changedFile = fs.combine(changed, file)
		local originalFile = fs.combine(original, file)

		if not fs.exists(patchFile) then
			error("Cannot find patch " .. file .. ".patch")
		end

		if not fs.exists(originalFile) then
			error("Cannot find original " .. file .. ".patch")
		end

		local originalS = fileWrapper.read(originalFile)
		local patchS = fileWrapper.read(patchFile)

		local patches = diff.patch_fromText(patchS)
		local changedS = diff.patch_apply(patches, originalS)

		fileWrapper.write(changedFile, changedS)

		os.queueEvent("diff")
		coroutine.yield("diff")
	end

	for _, file in ipairs(removed) do
		modified[file:gsub(originalP, "")] = true
	end

	for _, file in ipairs(added) do
		modified[file:gsub(originalP, "")] = true
		fs.copy(fs.combine(patchDir, file), fs.combine(changed, file))
	end

	for file in files(original) do
		if not modified[file:gsub(originalP, "")] then
			local changed = file:gsub(originalP, changedP)
			fs.copy(file, changed)
		end
	end
end

return {
	makePatches = makePatches,
	applyPatches = applyPatches,
}
