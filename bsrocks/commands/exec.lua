local env = require "bsrocks.env"

return {
	name = "exec",
	help = "Execute a command in the emulated environment",
	syntax = "<file> [args]",
	execute = function(file, ...)
		if not file then error("Expected file", 0) end

		local loaded, msg = loadfile(shell.resolve(file))
		if not loaded then error(msg, 0) end

		setfenv(loaded, env()._G)

		return loaded(...)
	end,
}
