return function(text)
	local func = assert(loadstring(text, "unserialize"))

	local table = {}
	setfenv(func, table)()
	return table
end
