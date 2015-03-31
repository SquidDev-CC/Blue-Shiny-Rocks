--- Checks an argument has the correct type
-- @param arg The argument to check
-- @tparam string argType The type that it should be
function checkType(arg, argType)
	local t = type(arg)
	if t ~= argType then
		error(argType .. " expected, got " .. t, 3)
	end
	return args
end

-- Pretty safe, though not 100% accurate
function tmpName()
	return "/tmp-" .. os.clock() .. "-" .. math.random(1, 2^32)
end
