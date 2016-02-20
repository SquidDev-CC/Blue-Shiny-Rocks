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

		local loaded, msg = loadfile(shell.resolve(file))
		if not loaded then error(msg, 0) end

		setfenv(loaded, env()._G)

		return loaded(...)
	end,
}
