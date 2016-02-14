local diff = require "bsrocks.lib.diffmatchpatch"

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

local function readFile(file)
	local handle = fs.open(file, "r")
	local contents = handle.readAll()
	handle.close()
	return contents
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

return function(original, changed, dest)
	local originalP = "^" .. escapePattern(original)
	local changedP = escapePattern(changed)
	local destP = escapePattern(dest)

	for file in files(original) do
		local originalS = readFile(file)
		local changedS = readFile(file:gsub(originalP, changedP))

		local diffs = diff.diff_main(originalS, changedS)
		diff.diff_cleanupSemantic(diffs)

		os.queueEvent("diff")
		coroutine.yield("diff")

		local patch = diff.patch_toText(diff.patch_make(originalS, diffs))
		if #patch > 0 then
			local handle = fs.open(file:gsub(originalP, destP) .. ".patch", "w")
			handle.write(patch)
			handle.close()
		end

		os.queueEvent("diff")
		coroutine.yield("diff")
	end
end
