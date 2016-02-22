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
		bit32 = "5.2.2-1", -- https://luarocks.org/modules/siffiejoe/bit32
	},
	libPath = "/rocks/lib/?.lua;/rocks/lib/?;/rocks/lib/?/init.lua",
	binPath = "/rocks/bin/?.lua;/rocks/bin/?",
	logFile = "bsrocks.log"
}

if fs.exists(".bsrocks") then
	local serialize = require "bsrocks.lib.serialize"

	local handle = fs.open(".bsrocks", "r")
	local contents = handle.readAll()
	handle.close()

	for k, v in pairs(serialize.unserialize(contents)) do
		currentSettings[k] = v
	end
end

if settings then
	if fs.exists(".settings") then settings.load(".settings") end

	for k, v in pairs(currentSettings) do
		currentSettings[k] = settings.get("bsrocks." .. k, v)
	end
end

--- Add trailing slashes to servers
local function patchServers(servers)
	for i, server in ipairs(servers) do
		if server:sub(#server) ~= "/" then
			servers[i] = server .. "/"
		end
	end
end

patchServers(currentSettings.patchServers)
patchServers(currentSettings.servers)

return currentSettings
