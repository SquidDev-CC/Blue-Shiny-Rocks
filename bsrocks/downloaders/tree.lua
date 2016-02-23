local function callback(success, path, count, total)
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

local tries = require "bsrocks.lib.settings".tries

--- Download individual files
-- @tparam string prefix The url prefix to use
-- @tparam table files The list of files to download
-- @tparam int tries Number of times to attempt to download
local function tree(prefix, files)
	local result = {}

	local count = 0
	local total = #files

	-- Download a file and store it in the tree
	local errored = false
	local function download(path)
		local contents

		-- Attempt to download the file
		for i = 1, tries do
			local url = (prefix .. path):gsub(' ','%%20')
			local f = http.get(url)

			if f then
				count = count + 1
				result[path] = f.readAll()
				callback(true, path, count, total)
				return
			elseif errored then
				-- Just abort
				return
			end
		end

		errored = true
		callback(false, path, count, total)
	end

	local callbacks = {}

	for i, file in ipairs(files) do
		callbacks[i] = function() download(file) end
	end

	parallel.waitForAll(unpack(callbacks))
	if errored then
		error("Cannot download " .. repo .. "@" .. branch)
	end

	return result
end

return tree
