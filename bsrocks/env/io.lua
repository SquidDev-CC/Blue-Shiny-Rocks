--- The main io library
-- See: http://www.lua.org/manual/5.1/manual.html#5.7
-- Some elements are duplicated in /rom/apis/io but this is a more accurate representation

local utils = require "bsrocks.lib.utils"
local ansi = require "bsrocks.env.ansi"
local checkType = utils.checkType

local function isFile(file)
	return type(file) == "table" and file.close and file.flush and file.lines and file.read and file.seek and file.setvbuf and file.write
end

local function checkFile(file)
	if not isFile(file) then
		error("Not a file: Missing one of: close, flush, lines, read, seek, setvbuf, write", 3)
	end
end

local function getHandle(file)
	local t = type(file)
	if t ~= "table" or not file.__handle then
		error("FILE* expected, got " .. t)
	end

	if file.__isClosed then
		error("attempt to use closed file", 3)
	end

	return file.__handle
end

local fileMeta = {
	__index = {
		close = function(self)
			self.__handle.close()
			self.__isClosed = true
		end,
		flush = function(self)
			getHandle(self).flush()
		end,
		read = function(self, ...)
			local handle = getHandle(self)

			local returns = {}

			local data = {...}
			local n = select("#", ...)
			if n == 0 then n = 1 end
			for i = 1, n do
				local format = data[i] or "l"
				format = checkType(format, "string"):gsub("%*", ""):sub(1, 1) -- "*" is not needed after Lua 5.1 - lets be friendly

				local res, msg
				if format == "l" then
					res, msg = handle.readLine()
				elseif format == "a" then
					res, msg = handle.readAll()
				elseif format == "r" then
					res, msg = handle.read() -- Binary only
				else
					error("(invalid format", 2)
				end

				if not res then return res, msg end
				returns[#returns + 1] = res
			end

			return unpack(returns)
		end,

		seek = function(self, ...)
			error("File seek is not implemented", 2)
		end,

		setvbuf = function() end,

		write = function(self, ...)
			local handle = getHandle(self)

			local data = {...}
			local n = select("#", ...)
			for i = 1, n do
				local item = data[i]
				local t = type(item)
				if t ~= "string" and t ~= "number" then
					error("string expected, got " .. t)
				end

				handle.write(tostring(item))
			end

			return true
		end,

		lines = function(self, ...)
			return self.__handle.readLine
		end,
	}
}

return function(env)
	local io = {}
	env._G.io = io

	local function loadFile(path, mode)
		path = env.resolve(path)
		mode = (mode or "r"):gsub("%+", "")

		local ok, result = pcall(fs.open, path, mode)
		if not ok or not result then
			return nil, result or "No such file or directory"
		end
		return setmetatable({ __handle = result }, fileMeta)
	end

	do -- Setup standard outputs
		local function voidStub() end
		local function closeStub() return nil, "cannot close standard file" end
		local function readStub() return nil, "bad file descriptor" end

		env.stdout = setmetatable({
			__handle = {
				close = closeStub,
				flush = voidStub,
				read = readStub, readLine = readStub, readAll = readStub,
				write = function(arg) ansi.write(arg) end,
			}
		}, fileMeta)

		env.stderr = setmetatable({
			__handle = {
				close = closeStub,
				flush = voidStub,
				read = readStub, readLine = readStub, readAll = readStub,
				write = function(arg)
					local c = term.isColor()
					if c then term.setTextColor(colors.red) end
					ansi.write(arg)
					if c then term.setTextColor(colors.white) end
				end,
			}
		}, fileMeta)

		env.stdin = setmetatable({
			__handle = {
				close = closeStub,
				flush = voidStub,
				read = function() return string.byte(os.pullEvent("char")) end,
				readLine = read, readAll = read,
				write = function() error("cannot write to input", 3) end,
			}
		}, fileMeta)

		io.stdout = env.stdout
		io.stderr = env.stderr
		io.stdin  = env.stdin
	end

	function io.close(file)
		(file or env.stdout):close()
	end

	function io.flush(file)
		env.stdout:flush()
	end

	function io.input(file)
		local t = type(file)

		if t == "nil" then
			return env.stdin
		elseif t == "string" then
			file = assert(loadFile(file, "r"))
		elseif t ~= "table" then
			error("string expected, got " .. t, 2)
		end

		checkFile(file)

		io.stdin = file
		env.stdin = file

		return file
	end

	function io.output(file)
		local t = type(file)

		if t == "nil" then
			return env.stdin
		elseif t == "string" then
			file = assert(loadFile(file, "w"))
		elseif t ~= "table" then
			error("string expected, got " .. t, 2)
		end

		checkFile(file)

		io.stdout = file
		env.stdout = file

		return file
	end

	function io.popen(file)
		error("io.popen is not implemented", 2)
	end

	function io.read(...)
		return env.stdin:read(...)
	end

	local temp = {}
	function io.tmpfile()
		local name = utils.tmpName()
		temp[name] = true
		return loadFile(name, "w")
 	end

	io.open = loadFile

 	function io.type(file)
 		if isFile(file) then
 			if file.__isClosed then return "closed file" end
 			return "file"
		else
			return type(file)
 		end
 	end

 	function io.write(...)
 		return env.stdout:write(...)
 	end

	env._G.write = io.write
	env._G.print = ansi.print

 	-- Delete temp files
	env.cleanup[#env.cleanup + 1] = function()
		for file, _ in pairs(temp) do
			pcall(fs.delete, file)
		end
	end

	return io
end
