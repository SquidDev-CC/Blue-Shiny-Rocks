--- Pure lua implementation of the OS api
-- http://www.lua.org/manual/5.1/manual.html#5.8

local utils = require "bsrocks.lib.utils"
local checkType = utils.checkType

return function(env)
	local os, shell = _G.os, _G.shell
	env._G.os = {
		clock = os.clock,
		date = function(format, time)
			format = checkType(format or "*t", "string")
			time = checkType(time or os.time(), "number")

			-- TODO: Implement this properly
			return textutils.formatTime(time)
		end,


		-- Returns the number of seconds from time t1 to time t2. In POSIX, Windows, and some other systems, this value is exactly t2-t1.
		difftime = function(t1, t2)
			return t2 - t1
		end,

		execute = function(command) return shell.run(command) and 0 or 1 end,
		exit  = function(code) error("Exit code: " .. (code or 0), 2) end,
		getfenv = function(name)
			-- I <3 ClamShell
			if shell.getenv then
				return shell.getenv(name)
			end
		end,

		remove = function(path)
			return pcall(fs.delete, env.resolve(checkType(path, "string")))
		end,
		rename = function(oldname, newname)
			return pcall(fs.rename, env.resolve(checkType(oldname, "string")), env.resolve(checkType(newname, "string")))
		end,
		setlocale = function() end,
		-- Technically not
		time  = os.time,
		tmpname = utils.tmpName
	}
end
