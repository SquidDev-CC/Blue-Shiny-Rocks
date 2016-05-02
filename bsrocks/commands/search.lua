local match = require "bsrocks.lib.match"
local rockspec = require "bsrocks.rocks.rockspec"
local manifest = require "bsrocks.rocks.manifest"

local function execute(search)
	if not search then error("Expected <name>", 0) end
	search = search:lower()

	local names, namesN = {}, 0
	local all, allN = {}, 0
	for server, manifest in pairs(manifest.fetchAll()) do
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

local description = [[
  <name>  The name of the package to search for.

If the package cannot be found, it will query for packages with similar names.
]]
return {
	name = "search",
	help = "Search for a package",
	description = description,
	syntax = "<name>",
	execute = execute,
}
