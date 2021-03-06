--- Various patches for LuaJ's

local type, pairs = type, pairs

local function copy(tbl)
	local out = {}
	for k, v in pairs(tbl) do out[k] = v end
	return out
end

local function getmeta(obj)
	local t = type(obj)
	if t == "table" then
		return getmetatable(obj)
	elseif t == "string" then
		return string
	else
		return nil
	end
end

return function(env)
	env._G.getmetatable = getmeta

	if not table.pack().n then
		local table = copy(table)
		table.pack = function( ... ) return {n=select('#',...), ... } end

		env._G.table = table
	end

end
