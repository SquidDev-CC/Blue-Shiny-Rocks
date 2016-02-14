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
	local originalP = "^" .. escapePattern(original)
	local changedP = escapePattern(changed)
	local patchesP = escapePattern(patches)

	local changed = {}
	for file in files(original) do
		local originalS = fileWrapper.read(file)
		local changedS = fileWrapper.read(file:gsub(originalP, changedP))

		local diffs = diff.diff_main(originalS, changedS)
		diff.diff_cleanupSemantic(diffs)

		os.queueEvent("diff")
		coroutine.yield("diff")

		local patch = diff.patch_toText(diff.patch_make(originalS, diffs))
		if #patch > 0 then
			changed[#changed + 1] = file:gsub(originalP, "")
			fileWrapper.write(file:gsub(originalP, patchesP) .. ".patch", patch)
		end

		os.queueEvent("diff")
		coroutine.yield("diff")
	end

	return changed
end

local function applyPatches(original, changed, patches)
	local originalP = "^" .. escapePattern(original)
	local changedP = escapePattern(changed)
	local patchesP = escapePattern(patches)

	for file in files(original) do
		local patchFile = file:gsub(originalP, patchesP) .. ".patch"
		local changedP = file:gsub(originalP, changedP)
		if fs.exists(patchFile) then
			local originalS = fileWrapper.read(file)
			local patchS = fileWrapper.read(patchFile)

			local patches = diff.patch_fromText(patchS)
			local changedS = diff.patch_apply(patches, originalS)

			fileWrapper.write(changedP, changedS)

			os.queueEvent("diff")
			coroutine.yield("diff")
		else
			fs.copy(file, changedP)
		end
	end
end

return {
	makePatches = makePatches,
	applyPatches = applyPatches,
}
