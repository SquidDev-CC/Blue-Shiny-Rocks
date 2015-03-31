--- The main package library - a pure lua reimplementation of the package library in lua
-- See: http://www.lua.org/manual/5.1/manual.html#5.3

local checkType = utils.checkType

return function(env)
	local _G = env._G

	local package = {
		loaded = {},
		preload = {},
		path = shell.path():gsub(":", ";"),
	}
	-- Set as a global
	_G.package = package

	--- Load up the package data
	-- This by default produces an error
	function package.loadlib(libname, funcname)
		return nil, "dynamic libraries not enabled", "absent"
	end

	--- Allows the module to access the global table
	-- @tparam table module The module
	function package.seeall(module)
		checkType(module, "table")

		local meta = getmetatable(module)
		if not meta then
			meta = {}
			setmetatable(module, meta)
		end

		meta.__index = _G
	end

	package.loaders = {
		--- Preloader - checks preload table
		-- @tparam string name Package name to load
		function(name)
			checkType(name, "string")
			return package.preload[name] or ("\n\tno field package.preload['" .. name .. "']")
		end,

		function(name)
			checkType(name, "string")
			local path = package.path
			if type(path) ~= "string" then
				error("package.path is not a string", 2)
			end

			name = name:gsub("%.", "/")

			local errs = {}

			local pos, len = 1, #path
			while pos <= len do
				local start = path:find(";", pos)
				if not start then
					start = len + 1
				end

				local filePath = env.resolve(path:sub(pos, start - 1):gsub("%?", name, 1))
				pos = start + 1

				local loaded, err = loadfile(filePath)
				if type(loaded) == "function" then
					return setfenv(loaded, _G)
				end

				errs[#errs + 1] = "'" .. filePath .. "': " .. err
			end

			return table.concat(errs, "\n\t")
		end
	}

	--- Require a module
	-- @tparam string name The name of the module
	-- Checks each loader in turn. If it finds a function then it will
	-- execute it and store the result in package.loaded[name]
	function _G.require(name)
		checkType(name, "string")

		local loaded = package.loaded
		local thisPackage = loaded[name]

		if thisPackage ~= nil then
			if thisPackage then return thisPackage end
			error("loop or previous error loading module ' " .. name .. "'", 2)
		end

		local loaders = package.loaders
		checkType(loaders, "table")

		local errs = {}
		for _, loader in ipairs(loaders) do
			thisPackage = loader(name)

			local lType = type(loader)
			if lType == "string" then
				errs[#errs + 1] = lType
			elseif lType == "function" then
				-- Prevent cyclic dependencies
				loaded[name] = false

				-- Execute the method
				local result = thisPackage(name)

				-- If we returned something then set the result to it
				if result ~= nil then
					loaded[name] = result
				else
					-- If set something in the package.loaded table then use that
					result = loaded[name]
					if result == false then
						-- Otherwise just set it to true
						loaded[name] = true
						result = true
					end
				end

				return result
			end
		end

		-- Can't find it - just error
		error("module '" .. name .. "' not found: " .. name .. table.concat(errs))
	end

	-- Find the name of a table
	-- @tparam table table The table to look in
	-- @tparam string name The name to look up (abc.def.ghi)
	-- @return The table for that name or a new one or nil if a non table has it already
	local function findTable(table, name)
		local pos, len = 1, #name
		while pos <= len do
			local start = name:find(".", pos)
			if not start then
				start = len + 1
			end

			local key = path:sub(pos, start - 1)
			pos = start + 1

			local val = rawget(table, key)
			if val == nil then
				-- If it doesn't exist then create it
				val = {}
				table[key] = val
				table = val
			elseif type(val) == "table" then
				table = val
			else
				return nil
			end

		end
	end

	-- Set the current env to be a module
	-- @tparam lua
	function _G.module(name, ...)
		checkType(name, "string")

		local module = package.loaded[name]
		if type(module) ~= "table" then
			module = findTable(_G, name)
			if not module then
				error("name conflict for module '" .. name .. "'", 2)
			end

			package.loaded[name] = module
		end

		-- Init properties
		if module._NAME == nil then
			module._M = module
			module._NAME = name:gsub("([^.]+%.)", "") -- Everything afert last .
			module._PACKAGE = name:gsub("%.[^%.]+$", "") or "" -- Everything before the last .
		end

		-- Technically we need to set the environment above to access this.
		-- Instead we just set the __newindex functions t o use it
		local env = getfenv(2)

		local meta = getmetatable(env)
		if meta == nil then
			meta = {}
			setmetatable(env, meta)
		end

		local rawset = rawset
		-- Copy all variables over
		for k, v in pairs(module) do
			rawset(env, k, v)
		end

		-- We rawset the current table as well so things like
		--  for k, v in pairs(getfenv()) do ... end work
		meta.__newindex = function(self, key, value)
			rawset(self, key, value)
			module[key] = value
		end

		-- Applies functions. This could be package.seeall or similar
		for _, modifier in pairs({...}) do
			modifier(module)
		end
	end

	-- Populate the package.loaded table
	local loaded = package.loaded
	for k, v in pairs(_G) do
		if type(v) == "table" then
			loaded[k] = v
		end
	end

	return package
end
