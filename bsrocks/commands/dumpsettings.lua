local fileWrapper = require "bsrocks.lib.files"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"
local utils = require "bsrocks.lib.utils"

return {
	name = "dump-settings",
	help = "Dump all settings",
	syntax = "",
	execute = function()
		local dumped = serialize.serialize(settings)
		utils.log("Dumping to .bsrocks")
		fileWrapper.write(".bsrocks", dumped)
	end,
}
