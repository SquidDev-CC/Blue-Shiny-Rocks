local function load(file, ...)
	local loaded, msg = env()._G.loadfile(file)
	if not loaded then error(msg, 0) end
	loaded(...)
end

load(...)
