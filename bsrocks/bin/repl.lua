preload['bsrocks.env'] = function()
	return function()
		return {
			cleanup = {},
			_G = setmetatable({}, {__index = getfenv()})
		}
	end
end

return require "bsrocks.commands.repl".execute(...)
