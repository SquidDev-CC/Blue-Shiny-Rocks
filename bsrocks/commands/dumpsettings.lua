local fileWrapper = require "bsrocks.lib.files"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"
local utils = require "bsrocks.lib.utils"

return {
	name = "dump-settings",
	help = "Dump all settings",
	syntax = "",
	description = "Dump all settings to a .bsrocks file. This can be changed to load various configuration options.",
	execute = function()
		local dumped = serialize.serialize(settings)
		utils.log("Dumping to .bsrocks")
		fileWrapper.write(".bsrocks", dumped)
	end,
}
