preload['bsrocks.env'] = function()
	return function()
		return {
			cleanup = {},
			_G = setmetatable({}, {__index = _ENV})
		}
	end
end

return require "bsrocks.commands.repl".execute(...)
