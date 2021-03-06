local fileWrapper = require "bsrocks.lib.files"

local function addWithMeta(src, dest)
	for k, v in pairs(src) do
		if dest[k] == nil then
			dest[k] = v
		end
	end

	local meta = getmetatable(src)
	if type(meta) == "table" and type(meta.__index) == "table" then
		return addWithMeta(meta.__index, dest)
	end
end

return function()
	local nImplemented = function(name)
		return function()
			error(name .. " is not implemented", 2)
		end
	end

	local _G = {
		math = math,
		string = string,
		table = table,
		coroutine = coroutine,
		collectgarbage = nImplemented("collectgarbage"),
		_VERSION = _VERSION
	}
	_G._G = _G
	_G._ENV = _G

	local env = {
		_G = _G,
		dir = shell.dir(),

		stdin = false,
		stdout = false,
		strerr = false,
		cleanup = {}
	}

	function env.resolve(path)
		if path:sub(1, 1) ~= "/" then
			path = fs.combine(env.dir, path)
		end
		return path
	end

	function _G.load(func, chunk)
		local cache = {}
		while true do
			local r = func()
			if r == "" or r == nil then
				break
			end
			cache[#cache + 1] = r
		end

		return _G.loadstring(table.concat(func), chunk or "=(load)")
	end

	-- Need to set environment
	function _G.loadstring(name, chunk)
		return load(name, chunk, nil, _G)
	end

	-- Customised loadfile function to work with relative files
	function _G.loadfile(path)
		path = env.resolve(path)
		if fs.exists(path) then
			return load(fileWrapper.read(path), path, "t", _G)
		else
			return nil, "File not found"
		end
	end

	function _G.dofile(path)
		assert(_G.loadfile(path))()
	end

	function _G.print(...)
		local out = env.stdout
		local tostring = _G.tostring -- Allow overriding
		local t = {...}
		for i = 1, select('#', ...) do
			if i > 1 then
				out:write("\t")
			end
			out:write(tostring(t[i]))
		end

		out:write("\n")
	end

	local errors, nilFiller = {}, {}
	local function getError(message)
		if message == nil then return nil end

		local result = errors[message]
		errors[message] = nil
		if result == nilFiller then
			result = nil
		elseif result == nil then
			result = message
		end
		return result
	end
	env.getError = getError

	local e = {}
	if select(2, pcall(error, e)) ~= e then
		local function extractError(...)
			local success, message = ...
			if success then
				return ...
			else
				return false, getError(message)
			end
		end

		function _G.error(message, level)
			level = level or 1
			if level > 0 then level = level + 1 end

			if type(message) ~= "string" then
				local key = tostring({}) .. tostring(message)
				if message == nil then message = nilFiller end
				errors[key] = message
				error(key, 0)
			else
				error(message, level)
			end
		end

		function _G.pcall(func, ...)
			return extractError(pcall(func, ...))
		end

		function _G.xpcall(func, handler)
			return xpcall(func, function(result) return handler(getError(result)) end)
		end
	end

	-- Setup other items
	require "bsrocks.env.fixes"(env)

	require "bsrocks.env.io"(env)
	require "bsrocks.env.os"(env)

	if not debug then
		require "bsrocks.env.debug"(env)
	else
		_G.debug = debug
	end

	require "bsrocks.env.package"(env)

	-- Copy functions across
	addWithMeta(_ENV, _G)
	_G._NATIVE = _ENV

	return env
end
