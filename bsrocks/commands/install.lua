local install = require "bsrocks.rocks.install"

local description = [[
  <name>    The name of the package to install
  [version] The version of the package to install

Installs a package and all dependencies. This will also
try to upgrade a package if required.
]]
return {
	name = "install",
	help = "Install a package",
	syntax = "<name> [version]",
	description = description,
	execute = function(name, version)
		if not name then error("Expected name", 0) end
		install.install(name, version)
	end
}
