local function unserialize(text)
	local table = {}
	assert(load(text, "unserialize", "t", table))()
	table._ENV = nil
	return table
end

local keywords = {
	[ "and" ] = true, [ "break" ] = true, [ "do" ] = true, [ "else" ] = true,
	[ "elseif" ] = true, [ "end" ] = true, [ "false" ] = true, [ "for" ] = true,
	[ "function" ] = true, [ "if" ] = true, [ "in" ] = true, [ "local" ] = true,
	[ "nil" ] = true, [ "not" ] = true, [ "or" ] = true, [ "repeat" ] = true, [ "return" ] = true,
	[ "then" ] = true, [ "true" ] = true, [ "until" ] = true, [ "while" ] = true,
}

local function serializeImpl(value, tracking, indent, root)
	local vType = type(value)
	if vType == "table" then
		if tracking[value] ~= nil then error("Cannot serialize table with recursive entries") end
		tracking[value] = true

		if next(value) == nil then
			-- Empty tables are simple
			if root then
				return ""
			else
				return "{}"
			end
		else
			-- Other tables take more work
			local result, resultN = {}, 0
			local subIndent = indent
			if not root then
				resultN = resultN + 1
				result[resultN] = "{\n"
				subIndent = indent  .. "  "
			end

			local seen = {}
			local finish = "\n"
			if not root then finish = ",\n" end
			for k,v in ipairs(value) do
				seen[k] = true

				resultN = resultN + 1
				result[resultN] = subIndent .. serializeImpl(v, tracking, subIndent, false) .. finish
			end
			local keys, keysN, allString = {}, 0, true
			local t
			for k,v in pairs(value) do
				if not seen[k] then
					allString = allString and type(k) == "string"
					keysN = keysN + 1
					keys[keysN] = k
				end
			end

			if allString then
				table.sort(keys)
			end

			for _, k in ipairs(keys) do
				local entry
				local v = value[k]
				if type(k) == "string" and not keywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
					entry = k .. " = " .. serializeImpl(v, tracking, subIndent)
				else
					entry = "[ " .. serializeImpl(k, tracking, subIndent) .. " ] = " .. serializeImpl(v, tracking, subIndent)
				end
				resultN = resultN + 1
				result[resultN] = subIndent .. entry .. finish
			end

			if not root then
				resultN = resultN + 1
				result[resultN] = indent .. "}"
			end

			return table.concat(result)
		end

	elseif vType == "string" then
		return string.format( "%q", value )

	elseif vType == "number" or vType == "boolean" or vType == "nil" then
		return tostring(value)
	else
		error("Cannot serialize type " .. type, 0)
	end
end

local function serialize(table)
	return serializeImpl(table, {}, "", true)
end

return {
	unserialize = unserialize,
	serialize = serialize,
}
