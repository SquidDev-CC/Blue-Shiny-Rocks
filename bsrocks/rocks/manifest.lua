local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local settings = require "bsrocks.lib.settings"
local unserialize = require "bsrocks.lib.serialize".unserialize

local manifestCache = {}
local servers = settings.servers
local patchDirectory = settings.patchDirectory

local function fetchManifest(server)
	local manifest = manifestCache[server]
	if manifest then return manifest end

	log("Fetching manifest " .. server)

	local handle = http.get(server .. "manifest-5.1")
	if not handle then
		error("Cannot fetch manifest: " .. server, 0)
	end

	local contents = handle.readAll()
	handle.close()

	manifest = unserialize(contents)
	manifest.server = server
	manifestCache[server] = manifest
	return manifest
end

local function fetchAll()
	local toFetch, n = {}, 0
	for _, server in ipairs(servers) do
		if not manifestCache[server] then
			n = n + 1
			toFetch[n] = function() fetchManifest(server) end
		end
	end

	if n > 0 then
		if n == 1 then
			toFetch[1]()
		else
			parallel.waitForAll(unpack(toFetch))
		end
	end

	return manifestCache
end

local function loadLocal()
	local path = fs.combine(patchDirectory, "rocks/manifest-5.1")
	if not fs.exists(path) then
		return {
			repository = {},
			commands = {},
			modules = {},
			patches = {},
		}, path
	else
		return unserialize(fileWrapper.read(path)), path
	end
end

return {
	fetchManifest = fetchManifest,
	fetchAll = fetchAll,
	loadLocal = loadLocal,
}
