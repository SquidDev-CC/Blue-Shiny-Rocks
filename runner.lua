local function load(file, ...)
	assert(file and fs.exists(shell.resolve(file)), "Cannot find file " .. (file or "<nil>"))
	local loaded, msg = env()._G.loadfile(file)
	if not loaded then error(msg, 0) end

	local args = {...}
	local ok, msg = xpcall(function() loaded(unpack(args)) end, utils.traceback)

	if not ok then
		printError(msg)
	elseif msg then
		print(msg)
	end
end

load(...)