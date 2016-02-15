local currentSettings = {
	patchDirectory = "/rocks-patch",
	installDirectory = "/rocks",
	servers = {
		'http://luarocks.org/repositories/rocks/',
	},
	tries = 3,
}

if settings then
	if fs.exists(".settings") then settings.load(".settings") end
	if fs.exists(".bsrocks") then settings.load(".bsrocks") end

	for k, v in pairs(currentSettings) do
		currentSettings[k] = settings.get("bsrocks." .. k, v)
	end
end

return currentSettings
