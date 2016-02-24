local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local patchspec = require "bsrocks.rocks.patchspec"
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory

local function execute(...)
	local patched, force
	if select("#", ...) == 0 then
		force = false
		patched = patchspec.getAll()
	else
		force = true
		patched = {}
		for _, name in pairs({...}) do
			name = name:lower()
			local file = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
			if not fs.exists(file) then error("No such patchspec " .. name, 0) end

			patched[name] = serialize.unserialize(fileWrapper.read(file))
		end
	end

	local changed = false
	for name, patchspec in pairs(patched) do
		local dir = fs.combine(patchDirectory, "rocks-original/" .. name)
		if force or not fs.isDir(dir) then
			changed = true
			log("Fetching " .. name)

			fs.delete(dir)

			local version = patchspec.version
			if not patchspec.version then
				error("Patchspec" .. name .. " has no version", 0)
			end

			local manifest = rockspec.findRockspec(name)
			if not manifest then
				error("Cannot find '" .. name .. "'", 0)
			end

			local rock = rockspec.fetchRockspec(manifest.server, name, patchspec.version)

			local files = rockspec.extractFiles(rock)
			if #files == 0 then error("No files for " .. name .. "-" .. version, 0) end

			local downloaded = download(rock.source, files)

			if not downloaded then error("Cannot find downloader for " .. rock.source.url, 0) end

			for name, contents in pairs(downloaded) do
				fileWrapper.write(fs.combine(dir, name), contents)
			end

			fs.delete(fs.combine(patchDirectory, "rocks-changes/" .. name))
		end
	end

	if not changed then
		error("No packages to fetch", 0)
	end

	print("Run 'apply-patches' to apply")
end

local description = [[
  [name] The name of the package to fetch. Otherwise all un-fetched packages will be fetched.
]]
return {
	name = "fetch",
	help = "Fetch a package for patching",
	syntax = "[name]...",
	description = description,
	execute = execute,
}
