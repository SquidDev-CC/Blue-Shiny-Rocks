local env = require "bsrocks.env"
local settings = require "bsrocks.lib.settings"

local description = [[
	<file>	The file to execute relative to the current directory.
	[args...] Arguments to pass to the program.

This will execute the program in an emulation of Lua 5.1's environment.

Please note that the environment is not a perfect emulation.
]]

return {
	name = "exec",
	help = "Execute a command in the emulated environment",
	syntax = "<file> [args...]",
	description = description,
	execute = function(file, ...)
		if not file then error("Expected file", 0) end

		if file:sub(1, 1) == "@" then
			file = file:sub(2)

			local found
			for _, path in ipairs(settings.binPath) do
				path = path:gsub("%%{(%a+)}", settings):gsub("%?", file)
				if fs.exists(path) then
					found = path
					break
				end
			end

			file = found or shell.resolveProgram(file) or file
		else
			file = shell.resolve(file)
		end

		local loaded, msg = loadfile(file)
		if not loaded then error(msg, 0) end

		local env = env()
		local thisEnv = env._G
		thisEnv.arg = {[-2] = "/" .. shell.getRunningProgram(), [-1] = "exec", [0] = "/" .. file, ... }
		setfenv(loaded, thisEnv)

		local args = {...}
		local success, msg = xpcall(
			function() return loaded(unpack(args)) end,
			function(msg)
				msg = env.getError(msg)
				if type(msg) == "string" then
					local code = msg:match("^Exit code: (%d+)")
					if code and code == "0" then return "<nop>" end
				end

				if msg == nil then
					msg = "<No message>"
				else
					msg = tostring(msg)
				end
				return thisEnv.debug.traceback(msg, 2)
			end
		)
		loaded(...)

		for _, v in pairs(env.cleanup) do v() end

		if not success and msg ~= "<nop>" then
			error(msg, 0)
		end
	end,
}
