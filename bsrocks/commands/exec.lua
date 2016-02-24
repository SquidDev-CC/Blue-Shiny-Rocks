local env = require "bsrocks.env"

local description = [[
  <file>    The file to execute relative to the current directory.
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
		file = shell.resolve(file)

		local loaded, msg = loadfile(file)
		if not loaded then error(msg, 0) end

		local thisEnv = env()._G
		thisEnv.arg = {[0] = fil, ... }
		setfenv(loaded, thisEnv)

		local args = {...}
		xpcall(
			function() return loaded(unpack(args)) end,
			function(msg)
				printError(env()._G.debug.traceback(msg, 2))
			end
		)
	end,
}
