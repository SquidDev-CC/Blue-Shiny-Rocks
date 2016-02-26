local dependencies = require "bsrocks.rocks.dependencies"
local download = require "bsrocks.downloaders"
local install = require "bsrocks.rocks.install"
local patchspec = require "bsrocks.rocks.patchspec"
local printColoured = require "bsrocks.lib.utils".printColoured
local rockspec = require "bsrocks.rocks.rockspec"
local settings = require "bsrocks.lib.settings"

local servers = settings.servers

local function execute(name)
	if not name then error("Expected <name>", 0) end
	name = name:lower()

	local installed, installedPatches = install.getInstalled()

	local isInstalled = true
	local spec, patchS = installed[name], installedPatches[name]

	if not spec then
		isInstalled = false
		local manifest = rockspec.findRockspec(name)

		if not manifest then error("Cannot find '" .. name .. "'", 0) end

		local version = rockspec.latestVersion(manifest, name)
		spec = rockspec.fetchRockspec(manifest.server, name, version)


		local patchManifest = patchspec.findPatchspec(name)
		patchS = patchManifest and patchspec.fetchPatchspec(patchManifest.server, name)
	end

	write(name .. ": " .. spec.version .. " ")
	if spec.builtin then
		printColoured("Built In", colours.magenta)
	elseif isInstalled then
		printColoured("Installed", colours.green)
	else
		printColoured("Not installed", colours.red)
	end

	local desc = spec.description
	if desc then
		if desc.summary then printColoured(desc.summary, colours.cyan) end
		if desc.detailed then
			local detailed = desc.detailed
			local ident = detailed:match("^(%s+)")
			if ident then
				detailed = detailed:sub(#ident + 1):gsub("\n" .. ident, "\n")
			end

			-- Remove leading and trailing whitespace
			detailed = detailed:gsub("^\n+", ""):gsub("%s+$", "")
			printColoured(detailed, colours.lightGrey)
		end

		if desc.homepage then
			printColoured("URL: " .. desc.homepage, colours.lightBlue)
		end
	end

	if not isInstalled then
		local error, issues = install.findIssues(spec, patchS)
		if #issues > 0 then
			printColoured("Issues", colours.orange)
			if error then
				printColoured("This package is incompatible", colors.red)
			end

			for _, v in ipairs(issues) do
				local color = colors.yellow
				if v[2] then color = colors.red end

				printColoured(" " .. v[1], color)
			end
		end
	end

	if spec.dependencies and #spec.dependencies > 0 then
		printColoured("Dependencies", colours.orange)
		local len = 0
		for _, deps in ipairs(spec.dependencies) do len = math.max(len, #deps) end

		len = len + 1
		for _, deps in ipairs(spec.dependencies) do
			local dependency = dependencies.parseDependency(deps)
			local name = dependency.name
			local current = installed[name]

			write(" " .. deps .. (" "):rep(len - #deps))

			if current then
				local version = dependencies.parseVersion(current.version)
				if not dependencies.matchConstraints(version, dependency.constraints) then
					printColoured("Out of date", colours.yellow)
				elseif current.builtin then
					printColoured("Built In", colours.magenta)
				else
					printColoured("Installed", colours.green)
				end
			else
				printColoured("Not installed", colours.red)
			end
		end
	end
end

local description = [[
  <name>  The name of the package to search for.

Prints a description about the package, listing its description, dependencies and other useful information.
]]
return {
	name = "desc",
	help = "Print a description about a package",
	description = description,
	syntax = "<name>",
	execute = execute,
}
