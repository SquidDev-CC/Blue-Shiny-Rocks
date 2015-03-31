return function()
	local globals = _G

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
		_VERSION = "Lua 5.1" -- Potentially dangerous.
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
		if type(v) == "function" then
			_G[k] = v
		end
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
		local out = stdout
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

	-- Setup other items
	io(env)
	os(env)

	package(env)

	return env
end
