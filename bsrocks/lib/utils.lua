-- local current = fs.getName(shell.getRunningProgram())
-- local currentLen = #current

--- Checks an argument has the correct type
-- @param arg The argument to check
-- @tparam string argType The type that it should be
local function checkType(arg, argType)
	local t = type(arg)
	if t ~= argType then
		error(argType .. " expected, got " .. t, 3)
	end
	return arg
end

--- Generate a temp name for a file
-- Pretty safe, though not 100% accurate
local function tmpName()
	return "/tmp/" .. os.clock() .. "-" .. math.random(1, 2^32)
end

local function traceback(thread, message, level)
	if type(thread) ~= "thread" then
		level = message
		message = thread
	end

	local level = checkType(level or 1, "number")

	local result = {"stack traceback: "}
	for i = 2, 20 do
		local _, err = pcall(error, "", i + level)
		if err == "" then -- or err:sub(1, currentLen) == current
			break
		end

		result[i] = err
	end

	local contents = table.concat(result, "\n\t")
	if message then
		return tostring(message) .. "\n" .. contents
	end
	return contents
end

return {
	checkType = checkType,
	tmpName = tmpName,
	traceback = traceback,
}
