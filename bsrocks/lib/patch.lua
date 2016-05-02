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
				local change = math.min(context, #lines)
				for i = 1, change do
					cn = cn + 1
					current[cn] = { mode, lines[i] }
				end

				current.oCount = current.oCount + change
				current.nCount = current.nCount + change

				if #lines > context then
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

return {
	makePatch = makePatch,
	writePatch = writePatch,
}
