local install = require "bsrocks.rocks.install"
local printColoured = require "bsrocks.lib.utils".printColoured


local function execute()
	for _, data in pairs(install.getInstalled()) do
		print(data.package .. ": " .. data.version)
		if data.description and data.description.summary then
			printColoured("  " .. data.description.summary, colours.lightGrey)
		end
	end
end

return {
	name = "list",
	help = "List installed packages",
	syntax = "",
	execute = execute
}
