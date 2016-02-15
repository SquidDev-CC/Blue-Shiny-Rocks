local currentSettings = {
	patchDirectory = "/rocks-patch",
	installDirectory = "/rocks",
	servers = {
		'http://luarocks.org/repositories/rocks/',
	},
	patchServers = {
		'https://raw.githubusercontent.com/SquidDev-CC/Blue-Shiny-Rocks/rocks/'
	},
	tries = 3,
	existing = {
		lua = "5.1",
		bit32 = "999",
	},
	libPath = { "/rocks/lib/" },
	binPath = { "/rocks/bin/" },
	logFile = "bsrocks.log"
}

if fs.exists(".bsrocks") then
	local serialize = require "bsrocks.lib.serialize"
	local fileWrapper = require "bsrocks.lib.files"

	for k, v in pairs(serialize.unserialize(fileWrapper.read(".bsrocks"))) do
		currentSettings[k] = v
	end
end

if settings then
	if fs.exists(".settings") then settings.load(".settings") end

	for k, v in pairs(currentSettings) do
		currentSettings[k] = settings.get("bsrocks." .. k, v)
	end
end

return currentSettings
