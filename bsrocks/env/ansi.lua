local write = write
local type = type

local defBack, defText = term.getBackgroundColour(), term.getTextColour()
local setBack, setText = term.setBackgroundColour, term.setTextColour

local function create(func, col)
	return function() func(col) end
end

local escapes = {
	['0'] = function()
		setBack(defBack)
		setText(defText)
	end,
	['30'] = create(setText, colours.black),
	['31'] = create(setText, colours.red),
	['32'] = create(setText, colours.green),
	['33'] = create(setText, colours.orange),
	['34'] = create(setText, colours.blue),
	['35'] = create(setText, colours.purple),
	['36'] = create(setText, colours.cyan),
	['37'] = create(setText, colours.lightGrey),

	['40'] = create(setBack, colours.black),
	['41'] = create(setBack, colours.red),
	['42'] = create(setBack, colours.green),
	['43'] = create(setBack, colours.orange),
	['44'] = create(setBack, colours.blue),
	['45'] = create(setBack, colours.purple),
	['46'] = create(setBack, colours.cyan),
	['47'] = create(setBack, colours.lightGrey),

	['90'] = create(setText, colours.grey),
	['91'] = create(setText, colours.red),
	['92'] = create(setText, colours.lime),
	['93'] = create(setText, colours.yellow),
	['94'] = create(setText, colours.lightBlue),
	['95'] = create(setText, colours.pink),
	['96'] = create(setText, colours.cyan),
	['97'] = create(setText, colours.white),

	['100'] = create(setBack, colours.grey),
	['101'] = create(setBack, colours.red),
	['102'] = create(setBack, colours.lime),
	['103'] = create(setBack, colours.yellow),
	['104'] = create(setBack, colours.lightBlue),
	['105'] = create(setBack, colours.pink),
	['106'] = create(setBack, colours.cyan),
	['107'] = create(setBack, colours.white),
}
local function writeAnsi(str)
	if stdout and stdout.isPiped then
		return stdout.write(text)
	end

	if type(str) ~= "string" then
		error("bad argument #1 (string expected, got " .. type(ansi) .. ")", 2)
	end

	local offset = 1
	while offset <= #str do
		local start, finish = str:find("\27[", offset, true)

		if start then
			if offset < start then
				write(str:sub(offset, start - 1))
			end

			local remaining = true
			while remaining do
				finish = finish + 1
				start = finish

				while true do
					local s = str:sub(finish, finish)
					if s == ";" then
						break
					elseif s == "m" then
						remaining = false
						break
					elseif s == "" or s == nil then
						error("Invalid escape sequence at " .. s)
					else
						finish = finish + 1
					end
				end

				local colour = str:sub(start, finish - 1)
				local func = escapes[colour]
				if func then func() end
			end

			offset = finish + 1
		elseif offset == 1 then
			write(str)
			return
		else
			write(str:sub(offset))
			return
		end
	end
end

function printAnsi(...)
	local limit = select("#", ...)
	for n = 1, limit do
		local s = tostring(select(n, ... ))
		if n < limit then
			s = s .. "\t"
		end
		writeAnsi(s)
	end
	write("\n")
end

return {
	write = writeAnsi,
	print = printAnsi,
}
