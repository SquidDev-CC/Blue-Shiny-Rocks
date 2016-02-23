local env = require "bsrocks.env"
local serialize = require "bsrocks.lib.dump"
local parse = require "bsrocks.lib.parse"

local function execute()
	local running = true
	local thisEnv = env()._G

	thisEnv.exit = setmetatable({}, {
		__tostring = function() return "Call exit() to exit" end,
		__call = function() running = false end,
	})

	-- We need to pass through a secondary function to prevent tail calls
	thisEnv._noTail = function(...) return ... end

	-- As per @demhydraz's suggestion. Because the prompt uses Out[n] as well
	local output = {}
	thisEnv.Out = output

	local inputColour, outputColour, textColour = colours.green, colours.cyan, term.getTextColour()
	local codeColour, pointerColour = colours.lightGrey, colours.lightBlue
	if not term.isColour() then
		inputColour = colours.white
		outputColour = colours.white
		codeColour = colours.white
		pointerColour = colours.white
	end

	local autocomplete = nil
	if not settings or settings.get("lua.autocomplete") then
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
	local function setOutput(out, length)
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
				print(serialize(out, length))
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
				setOutput({...}, len)
			end
		else
			printError(...)
		end
	end

	local function handleError(lines, line, column, message)
		local contents = lines[line]
		term.setTextColour(codeColour)
		print(" " .. contents)
		term.setTextColour(pointerColour)
		print((" "):rep(column) .. "^ ")
		printError(" " .. message)
	end

	local function execute(lines, force)
		local buffer = table.concat(lines, "\n")
		local forcePrint = false
		local func, err = load(buffer, "lua", "t", thisEnv)
		local func2, err2 = load("return " .. buffer, "lua", "t", thisEnv)
		if not func then
			if func2 then
				func = load("return _noTail(" .. buffer .. ")", "lua", "t", thisEnv)
				forcePrint = true
			else
				local success, tokens = pcall(parse.lex, buffer)
				if not success then
					local line, column, resumable, message = tokens:match("(%d+):(%d+):([01]):(.+)")
					if line then
						if line == #lines and column > #lines[line] and resumable == 1  then
							return false
						else
							handleError(lines, tonumber(line), tonumber(column), message)
							return true
						end
					else
						printError(tokens)
						return true
					end
				end

				local success, message = pcall(parse.parse, tokens)

				if not success then
					if not force and tokens.pointer >= #tokens.tokens then
						return false
					else
						local token = tokens.tokens[tokens.pointer]
						handleError(lines, token.line, token.char, message)
						return true
					end
				end
			end
		elseif func2 then
			func = load("return _noTail(" .. buffer .. ")", "lua", "t", thisEnv)
		end

		if func then
			handle(forcePrint, pcall(func))
			counter = counter + 1
		else
			printError(err)
		end

		return true
	end

	local lines = {}
	local input = "In [" .. counter .. "]: "
	local isEmpty = false
	while running do
		term.setTextColour(inputColour)
		write(input)
		term.setTextColour(textColour)

		local line = read(nil, history, autocomplete)
		if not line then return end

		if #line:gsub("%s", "") > 0 then
			for i = #history, 1, -1 do
				if history[i] == line then
					table.remove(history, i)
					break
				end
			end

			history[#history + 1] = line
			lines[#lines + 1] = line
			isEmpty = false

			if execute(lines) then
				lines = {}
				input = "In [" .. counter .. "]: "
			else
				input = (" "):rep(#tostring(counter) + 3) .. "... "
			end
		else
			execute(lines, true)
			lines = {}
			isEmpty = false
			input = "In [" .. counter .. "]: "
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
