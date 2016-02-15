local install = require "bsrocks.rocks.install"

return {
	name = "install",
	help = "Install a package",
	syntax = "<name> [version]",
	execute = function(name, version)
		if not name then error("Expected name", 0) end
		install.install(name, version)
	end
}
