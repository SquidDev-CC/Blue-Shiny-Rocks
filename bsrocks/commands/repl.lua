local env = require "bsrocks.env"

local keywords = {
	[ "and" ] = true, [ "break" ] = true, [ "do" ] = true, [ "else" ] = true,
	[ "elseif" ] = true, [ "end" ] = true, [ "false" ] = true, [ "for" ] = true,
	[ "function" ] = true, [ "if" ] = true, [ "in" ] = true, [ "local" ] = true,
	[ "nil" ] = true, [ "not" ] = true, [ "or" ] = true, [ "repeat" ] = true, [ "return" ] = true,
	[ "then" ] = true, [ "true" ] = true, [ "until" ] = true, [ "while" ] = true,
}

local function serializeImpl(t, tracking, indent)
	local objType = type(t)
	if objType == "table" and not tracking[t] then
		tracking[t] = true

		if next(t) == nil then
			return "{}"
		else
			local result, n = {"{\n"}, 1
			local subIndent = indent .. "  "
			local seen = {}
			for k,v in ipairs(t) do
				seen[k] = true
				n = n + 1
				result[n] = subIndent .. serializeImpl( v, tracking, subIndent ) .. ",\n"
			end
			for k,v in pairs(t) do
				if not seen[k] then
					local entry
					if type(k) == "string" and not keywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
						entry = k .. " = " .. serializeImpl(v, tracking, subIndent) .. ",\n"
					else
						entry = "[ " .. serializeImpl(k, tracking, subIndent) .. " ] = " .. serializeImpl(v, tracking, subIndent) .. ",\n"
					end

					n = n + 1
					result[n] = subIndent .. entry
				end
			end

			n = n + 1
			result[n] = indent .. "}"
			return table.concat(result)
		end

	elseif objType == "string" then
		return string.format("%q", t)
	else
		return tostring(t)
	end
end

local function serialize(t)
	return serializeImpl(t, {}, "")
end

local function execute()
	local running = true
	local thisEnv = env()._G

	thisEnv.exit = setmetatable({}, {
		__tostring = function() return "Call exit() to exit" end,
		__call = function() running = false end,
	})

	-- As per @demhydraz's suggestion. Because the prompt uses Out[n] as well
	local output = {}
	thisEnv.Out = output

	local inputColour, outputColour, textColour = colours.green, colours.cyan, term.getTextColour()
	if not term.isColour() then
		inputColour = colours.white
		outputColour = colours.white
	end

	local autocomplete = nil
	if settings.get("lua.autocomplete") then
		autocomplete = function(line)
			local start = line:find("[a-zA-Z0-9_%.]+$")
			if start then
				line = line:sub(start)
			end
			if #line > 0 then
				return textutils.complete(line, thisEnv)
			end
		end
	end

	local history = {}
	local counter = 1

	--- Prints an output and sets the output variable
	local function setOutput(out)
		thisEnv._ = out
		thisEnv['_' .. counter] = out
		output[counter] = out

		term.setTextColour(outputColour)
		write("Out[" .. counter .. "]: ")
		term.setTextColour(textColour)

		if type(out) == "table" then
			local meta = getmetatable(out)
			if type(meta) == "table" and type(meta.__tostring) == "function" then
				print(tostring(out))
			else
				print(serialize(out))
			end
		else
			print(serialize(out))
		end
	end

	--- Handle the result of the function
	local function handle(forcePrint, success, ...)
		if success then
			local len = select('#', ...)
			if len == 0 then
				if forcePrint then
					setOutput(nil)
				end
			elseif len == 1 then
				setOutput(...)
			else
				setOutput({...})
			end
		else
			printError(...)
		end
	end

	while running do
		term.setTextColour(inputColour)
		write("In [" .. counter .. "]: ")
		term.setTextColour(textColour)

		local line = read(nil, history, autocomplete)

		if #line:gsub("%s", "") > 0 then
			for i = #history, 1, -1 do
				if history[i] == line then
					table.remove(history, i)
					break
				end
			end

			history[#history + 1] = line

			local forcePrint = false
			local func, err = load(line, "lua", "t", thisEnv)
			local func2, err2 = load("return " .. line, "lua", "t", thisEnv)
			if not func then
				if func2 then
					func = func2
					forcePrint = true
				end
			else
				if func2 then
					func = func2
				end
			end

			if func then
				handle(forcePrint, pcall(func))
			else
				printError(err)
			end

			counter = counter + 1
		end
	end
end

local description = [[
This is almost identical to the built in Lua program with some simple differences.

Scripts are run in an environment similar to the exec command.

The result of the previous outputs are also stored in variables of the form _idx (the last result is also stored in _). For example: if Out[1] = 123 then _1 = 123 and _ = 123 
]]
return {
	name = "repl",
	help = "Run a Lua repl in an emulated environment",
	syntax = "",
	description = description,
	execute = execute,
}
