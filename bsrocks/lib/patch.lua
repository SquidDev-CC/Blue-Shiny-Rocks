local CONTEXT_THRESHOLD = 3

local function makePatch(diff)
	local out, n = {}, 0

	local oLine, nLine = 1, 1

	local current, cn = nil, 0
	local context = 0

	for i = 1, #diff do
		local data = diff[i]
		local mode, lines = data[1], data[2]

		if mode == "=" then
			oLine = oLine + #lines
			nLine = nLine + #lines

			if current then
				local change
				local finish = false
				if #lines > context + CONTEXT_THRESHOLD then
					-- We're not going to merge into the next group
					-- so just write the remaining items
					change = context
					finish = true
				else
					-- We'll merge into another group, so write everything
					change = #lines
				end

				for i = 1, change do
					cn = cn + 1
					current[cn] = { mode, lines[i] }
				end

				current.oCount = current.oCount + change
				current.nCount = current.nCount + change

				if finish then
					-- We've finished this run, and there is more remaining, so
					-- we shouldn't continue this patch
					context = 0
					current = nil
				else
					context = context - change
				end
			end
		else
			context = CONTEXT_THRESHOLD

			if not current then
				current = {
					oLine = oLine,
					oCount = 0,
					nLine = nLine,
					nCount = 0,
				}
				cn = 0

				local previous = diff[i - 1]
				if previous and previous[1] == "=" then
					local lines = previous[2]
					local change = math.min(CONTEXT_THRESHOLD, #lines)
					current.oCount = current.oCount + change
					current.nCount = current.nCount + change

					current.oLine = current.oLine - change
					current.nLine = current.nLine - change

					for i = #lines - change + 1, #lines do
						cn = cn + 1
						current[cn] = { "=", lines[i] }
					end
				end

				n = n + 1
				out[n] = current
			end

			if mode == "+" then
				nLine = nLine + #lines
				current.nCount = current.nCount + #lines
			elseif mode == "-" then
				oLine = oLine + #lines
				current.oCount = current.oCount + #lines
			else
				error("Unknown mode " .. tostring(mode))
			end

			for i = 1, #lines do
				cn = cn + 1
				current[cn] = { mode, lines[i] }
			end
		end
	end

	return out
end

local function writePatch(patch, name)
	local out, n = {}, 0

	if name then
		n = 2
		out[1] = "--- " .. name
		out[2] = "+++ " .. name
	end

	for i = 1, #patch do
		local p = patch[i]

		n = n + 1
		out[n] = ("@@ -%d,%d +%d,%d @@"):format(p.oLine, p.oCount, p.nLine, p.nCount)

		for i = 1, #p do
			local row = p[i]
			local mode = row[1]
			if mode == "=" then mode = " " end

			n = n + 1

			out[n] = mode .. row[2]
		end
	end

	return out
end

local function readPatch(lines)
	if lines[1]:sub(1, 3) ~= "---" then error("Invalid patch format on line #1") end
	if lines[2]:sub(1, 3) ~= "+++" then error("Invalid patch format on line #2") end

	local out, n = {}, 0
	local current, cn = nil, 0

	for i = 3, #lines do
		local line = lines[i]
		if line:sub(1, 2) == "@@" then
			local oLine, oCount, nLine, nCount = line:match("^@@ %-(%d+),(%d+) %+(%d+),(%d+) @@$")
			if not oLine then error("Invalid block on line #" .. i .. ": " .. line) end

			current = {
				oLine = oLine,
				oCount = oCount,
				nLine = nLine,
				nCount = nCount,
			}
			cn = 0

			n = n + 1
			out[n] = current
		else
			local mode = line:sub(1, 1)
			local data = line:sub(2)

			if mode == " " or mode == "" then
				-- Allow empty lines (when whitespace has been stripped)
				mode = "="
			elseif mode ~= "+" and mode ~= "-" then
				error("Invalid mode on line #" .. i .. ": " .. line)
			end

			cn = cn + 1
			if not current then error("No block for line #" .. i) end

			current[cn] = { mode, data }
		end
	end

	return out
end

local function applyPatch(patch, lines, file)
	local out, n = {}, 0

	local oLine = 1
	for i = 1, #patch do
		local data = patch[i]

		for i = oLine, data.oLine - 1 do
			n = n + 1
			out[n] = lines[i]
			oLine = oLine + 1
		end

		if oLine ~= data.oLine and oLine + 0 ~= data.oLine + 0 then
			return false, "Incorrect lines. Expected: " .. data.oLine .. ", got " .. oLine .. ". This may be caused by overlapping patches."
		end

		for i = 1, #data do
			local mode, line = data[i][1], data[i][2]

			if mode == "=" then
				if line ~= lines[oLine] then
					return false, "line #" .. oLine .. " is not equal."
				end

				n = n + 1
				out[n] = line
				oLine = oLine + 1
			elseif mode == "-" then
				if line ~= lines[oLine] then
					-- TODO: Diff the texts, compute difference, etc...
					-- print(("%q"):format(line))
					-- print(("%q"):format(lines[oLine]))
					-- return false, "line #" .. oLine .. " does not exist"
				end
				oLine = oLine + 1
			elseif mode == "+" then
				n = n + 1
				out[n] = line
			end
		end
	end

	for i = oLine, #lines do
		n = n + 1
		out[n] = lines[i]
	end

	return out
end

return {
	makePatch = makePatch,
	applyPatch = applyPatch,

	writePatch = writePatch,
	readPatch = readPatch,
}
