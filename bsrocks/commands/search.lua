local match = require "bsrocks.lib.diffmatchpatch".match_main
local rockspec = require "bsrocks.rocks.rockspec"
local settings = require "bsrocks.lib.settings"

local servers = settings.servers

local function execute(search)
	if not search then error("Expected <name>", 0) end

	local names, namesN = {}, 0
	local all, allN = {}, 0
	for _, server in ipairs(servers) do
		local manifest = rockspec.fetchManifest(server)

		for name, _ in pairs(manifest.repository) do
			-- First try a loose search
			local version = rockspec.latestVersion(manifest, name)
			if name:find(search, 1, true) then
				namesN = namesN + 1
				names[namesN] = { name, version }
				all = nil
			elseif namesN == 0 then
				allN = allN + 1
				all[allN] = { name, version }
			end
		end
	end

	-- Now try a fuzzy search
	if namesN == 0 then
		printError("Could not find '" .. search .. "', trying a fuzzy search")
		for _, name in ipairs(all) do
			if match(name[1], search) > 0 then
				namesN = namesN + 1
				names[namesN] = name
			end
		end
	end

	-- Print out all found items + version
	if namesN == 0 then
		error("Cannot find " .. search, 0)
	else
		for i = 1, namesN do
			local item = names[i]
			print(item[1] .. ": " .. item[2])
		end
	end
end

return {
	name = "search",
	help = "Search for a package",
	syntax = "<name>",
	execute = execute,
}
