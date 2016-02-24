return function(options)
	local globals = _G
	options = options or {}

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

	-- Copy functions across
	for k,v in pairs(globals) do
		if not _G[k] then
			_G[k] = v
		end
	end

	-- FIXME:
	_G.shell = shell
	_G.multishell = multishell

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
		local result, message = loadstring(name, chunk)
		if result then
			return setfenv(result, _G)
		end

		return result, message
	end

	-- Customised loadfile function to work with relative files
	function _G.loadfile(path)
		local result, message = loadfile(env.resolve(path))
		if result then
			return setfenv(result, _G)
		end

		return result, message
	end

	function _G.dofile(path)
		_G.loadfile(path)()
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

	local errors = {}
	local function extractError(...)
		local success, message = ...
		if success then
			return ...
		else
			local result = errors[message] or message
			errors[message] = nil
			return false, result
		end
	end

	function _G.error(message, level)
		level = level or 1
		if level > 0 then level = level + 1 end

		if type(message) ~= "string" then
			local key = tostring({}) .. tostring(message)
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
		return xpcall(func, function(result) return handler(extractError(result)) end)
	end

	-- Setup other items
	require "bsrocks.env.io"(env)
	require "bsrocks.env.os"(env)

	if options.debug ~= false then
		require "bsrocks.env.debug"(env)
	end

	require "bsrocks.env.package"(env)

	return env
end
