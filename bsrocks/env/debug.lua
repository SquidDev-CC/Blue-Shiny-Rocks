--- Tiny ammount of the debug API
-- http://www.lua.org/manual/5.1/manual.html#5.9

local traceback = require "bsrocks.lib.utils".traceback
local function err(name)
	return function() error(name .. " not implemented", 2) end
end

--- Really tacky getinfo
local function getInfo(thread, func, what)
	if type(thread) ~= "thread" then
		func = thread
	end

	local data = {
		what = "lua",
		source = "",
		short_source = "",
		linedefined = -1,
		lastlinedefined = -1,
		currentline = -1,
		nups = -1,
		name = "?",
		namewhat = "",
		activelines = {},
	}

	local t = type(func)
	if t == "number" or t == "string" then
		func = tonumber(func)

		local _, name = pcall(error, "", 2 + func)
		name = name:gsub(":?[^:]*: *$", "", 1)
		data.source = "@" .. name
		data.short_source = name
	elseif t == "function" then
		-- We really can't do much
		data.func = func
	else
		error("function or level expected", 2)
	end

	return data
end


return function(env)
	local debug = {
		getfenv = getfenv,
		gethook = err("gethook"),
		getinfo = getInfo,
		getlocal = err("getlocal"),
		gethook = err("gethook"),
		getmetatable = getmetatable,
		getregistry = err("getregistry"),
		setfenv = setfenv,
		sethook = err("sethook"),
		setlocal = err("setlocal"),
		setmetatable = setmetatable,
		setupvalue = err("setupvalue"),
		traceback = traceback,
	}
	env._G.debug = debug
end
