local logFile = require "bsrocks.lib.settings".logFile

if fs.exists(logFile) then fs.delete(logFile) end

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
	return "/tmp/" .. os.clock() .. "-" .. math.random(1, 2^31-1)
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
		if err == "" or err == "nil:" then
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

local printColoured, writeColoured
if term.isColour() then
	printColoured = function(text, colour)
		term.setTextColour(colour)
		print(text)
		term.setTextColour(colours.white)
	end

	writeColoured = function(text, colour)
		term.setTextColour(colour)
		write(text)
		term.setTextColour(colours.white)
	end
else
	printColoured = function(text) print(text) end
	writeColoured = write
end

local function doLog(msg)
	local handle
	if fs.exists(logFile) then
		handle = fs.open(logFile, "a")
	else
		handle = fs.open(logFile, "w")
	end

	handle.writeLine(msg)
	handle.close()
end

local function log(msg)
	doLog("[LOG] " .. msg)
	printColoured(msg, colours.lightGrey)
end

local function warn(msg)
	doLog("[WARN] " .. msg)
	printColoured(msg, colours.yellow)
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

local term = term
local function printIndent(text, indent)
	if type(text) ~= "string" then error("string expected, got " .. type(text), 2) end
	if type(indent) ~= "number" then error("number expected, got " .. type(indent), 2) end
	if stdout and stdout.isPiped then
		return stdout.writeLine(text)
	end

	local w, h = term.getSize()
	local x, y = term.getCursorPos()

	term.setCursorPos(indent + 1, y)

	local function newLine()
		if y + 1 <= h then
			term.setCursorPos(indent + 1, y + 1)
		else
			term.setCursorPos(indent + 1, h)
			term.scroll(1)
		end
		x, y = term.getCursorPos()
	end

	-- Print the line with proper word wrapping
	while #text > 0 do
		local whitespace = text:match("^[ \t]+")
		if whitespace then
			-- Print whitespace
			term.write(whitespace)
			x, y = term.getCursorPos()
			text = text:sub(#whitespace + 1 )
		end

		if text:sub(1, 1) == "\n" then
			-- Print newlines
			newLine()
			text = text:sub(2)
		end

		local subtext = text:match("^[^ \t\n]+")
		if subtext then
			text = text:sub(#subtext + 1)
			if #subtext > w then
				-- Print a multiline word
				while #subtext > 0 do
					if x > w then newLine() end
					term.write(subtext)
					subtext = subtext:sub((w-x) + 2)
					x, y = term.getCursorPos()
				end
			else
				-- Print a word normally
				if x + #subtext - 1 > w then newLine() end
				term.write(subtext)
				x, y = term.getCursorPos()
			end
		end
	end

	if y + 1 <= h then
		term.setCursorPos(1, y + 1)
	else
		term.setCursorPos(1, h)
		term.scroll(1)
	end
end


return {
	checkType = checkType,
	escapePattern = escapePattern,
	log = log,
	printColoured = printColoured,
	writeColoured = writeColoured,
	printIndent = printIndent,
	tmpName = tmpName,
	traceback = traceback,
	warn = warn
}
