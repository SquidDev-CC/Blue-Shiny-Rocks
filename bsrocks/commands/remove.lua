local install = require "bsrocks.rocks.install"
local rockspec = require "bsrocks.rocks.rockspec"

local description = [[
  <name>    The name of the package to install

Removes a package. This does not remove its dependencies
]]
return {
	name = "remove",
	help = "Removes a package",
	syntax = "<name>",
	description = description,
	execute = function(name, version)
		if not name then error("Expected name", 0) end
		name = name:lower()

		local installed, installedPatches = install.getInstalled()
		local rock, patch = installed[name], installedPatches[name]
		if not rock then error(name .. " is not installed", 0) end

		install.remove(rock, patch)
	end
}
