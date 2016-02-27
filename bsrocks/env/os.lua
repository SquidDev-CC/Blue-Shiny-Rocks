--- Pure lua implementation of the OS api
-- http://www.lua.org/manual/5.1/manual.html#5.8

local utils = require "bsrocks.lib.utils"
local date = require "bsrocks.env.date"
local checkType = utils.checkType

return function(env)
	local os, shell = os, shell
	local temp = {}
	env._G.os = {
		clock = os.clock,
		date = function(format, time)
			format = checkType(format or "%c", "string")
			time = checkType(time or os.time(), "number")

			-- Ignore UTC/CUT
			if format:sub(1, 1) == "!" then format = format:sub(2) end

			local d = date.create(time)

			if format == "*t" then
				return d
			elseif format == "%c" then
				return date.asctime(d)
			else
				return date.strftime(format, d)
			end
		end,


		-- Returns the number of seconds from time t1 to time t2. In POSIX, Windows, and some other systems, this value is exactly t2-t1.
		difftime = function(t1, t2)
			return t2 - t1
		end,

		execute = function(command)
			if shell.run(command) then
				return 0
			else
				return 1
			end
		end,
		exit  = function(code) error("Exit code: " .. (code or 0), 0) end,
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
		time = function(tbl)
			if not tbl then return os.time() end

			checkType(tbl, "table")
			return date.timestamp(tbl)
		end,
		tmpname = function()
			local name = utils.tmpName()
			temp[name] = true
			return name
		end
	}

	-- Delete temp files
	env.cleanup[#env.cleanup + 1] = function()
		for file, _ in pairs(temp) do
			pcall(fs.delete, file)
		end
	end
end
