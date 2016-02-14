local command = ...

local repo = require "bsrocks.rocks.repository"
local download = require "bsrocks.downloaders"

if command == "download" then
	local _, name, version = ...
	if not name then error("Expected name") end

	local server = repo.servers[1]
	if not version then
		local manifest = repo.fetchManifest(server)

		local module = manifest.repository[name]
		if not module then error("Cannot find " .. name) end

		for name, dat in pairs(module) do
			version = name
		end

		if not version then error("Cannot find version for " .. name) end

	end
	print("Using " .. name .. "-" .. version)

	local rockspec = repo.fetchRockspec(server, name, version)

	local files = repo.extractFiles(rockspec)
	if #files == 0 then error("No files for " .. name .. "-" .. version) end

	local downloaded = download(rockspec.source, files, {
		tries = 3,
		callback = function(success, path, count, total)
			if not success then
				local x, y = term.getCursorPos()
				term.setCursorPos(1, y)
				term.clearLine()
				printError("Cannot download " .. path)
			end

			local x, y = term.getCursorPos()
			term.setCursorPos(1, y)
			term.clearLine()
			write(("Downloading: %s/%s (%s%%)"):format(count, total, count / total * 100))
		end
	})

	if not downloaded then error("Cannot find downloader for " .. rockspec.source.url) end
	print()

	repo.saveFiles(rockspec, downloaded, shell.resolve("rocks-original/" .. name))
	repo.saveFiles(rockspec, downloaded, shell.resolve("rocks/" .. name))
elseif command == "make-patches" then
	local _, name = ...
	if not name then error("Expected name") end

	local original = shell.resolve("rocks-original/" .. name)
	local changed = shell.resolve("rocks/" .. name)

	if not fs.exists(original) then error("Cannot find original sources") end
	if not fs.exists(changed) then error("Cannot find changed sources") end

	local patch = shell.resolve("rocks-patch/" .. name)
	fs.delete(patch)

	require "bsrocks.rocks.diff"(original, changed, patch)
else
	error("Unknown command")
end
