local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local repo = require "bsrocks.rocks.repository"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"

local installDirectory = settings.installDirectory

local fetched = false
local installed = {}

local function save(rockspec)
	print(rockspec.package .. "-" .. rockspec.version)
	error("Not actually installing", 0)
	local files = repo.extractFiles(rockspec)
	if #files == 0 then
		error("No files for " .. rockspec.package .. "-" .. rockspec.version)
	end

	local downloaded = download(rockspec.source, files)

	if not downloaded then
		error("Cannot find downloader for " .. rockspec.source.url)
	end

	repo.saveFiles(rockspec, downloaded, installDirectory)
	fileWrapper.write(fs.combine(installDirectory, rockspec.package .. ".rockspec"), serialize.serialize(rockspec))
	installed[rockspec.package] = rockspec
end

local function getInstalled()
	if not fetched then
		fetched = true
		if fs.exists(installDirectory) then
			for _, file in ipairs(fs.list(installDirectory)) do
				if file:match("%.rockspec") then
					local data = serialize.unserialize(fileWrapper.read(fs.combine(installDirectory, file)))
					installed[data.package] = data
				end
			end
		end
	end

	return installed
end

return {
	save = save,
	getInstalled = getInstalled,
}
