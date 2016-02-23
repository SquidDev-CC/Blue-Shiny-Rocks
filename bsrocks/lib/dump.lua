local keywords = {
	[ "and" ] = true, [ "break" ] = true, [ "do" ] = true, [ "else" ] = true,
	[ "elseif" ] = true, [ "end" ] = true, [ "false" ] = true, [ "for" ] = true,
	[ "function" ] = true, [ "if" ] = true, [ "in" ] = true, [ "local" ] = true,
	[ "nil" ] = true, [ "not" ] = true, [ "or" ] = true, [ "repeat" ] = true, [ "return" ] = true,
	[ "then" ] = true, [ "true" ] = true, [ "until" ] = true, [ "while" ] = true,
}

local function serializeImpl(t, tracking, indent, length)
	local objType = type(t)
	if objType == "table" and not tracking[t] then
		tracking[t] = true

		if next(t) == nil then
			return "{}"
		else
			local result, n = {"{\n"}, 1
			length = length or #t
			local subIndent = indent .. "  "
			local seen = {}
			for k = 1, length do
				seen[k] = true
				n = n + 1
				result[n] = subIndent .. serializeImpl(t[k], tracking, subIndent) .. ",\n"
			end
			for k,v in pairs(t) do
				if not seen[k] then
					local entry
					if type(k) == "string" and not keywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
						entry = k .. " = " .. serializeImpl(v, tracking, subIndent) .. ",\n"
					else
						entry = "[" .. serializeImpl(k, tracking, subIndent) .. "] = " .. serializeImpl(v, tracking, subIndent) .. ",\n"
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
		return (string.format("%q", t):gsub("\\\n", "\\n"))
	else
		return tostring(t)
	end
end

local function serialize(t, n)
	return serializeImpl(t, {}, "", n)
end

return serialize
