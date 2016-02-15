local downloaders = {
	require "bsrocks.downloaders.github",
}

local tries = require "bsrocks.lib.settings".tries

local settings = {
	tries = tries,
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
}
return function(source, files)
	for _, downloader in ipairs(downloaders) do
		local files = downloader(source, files, settings)
		if files then return files end
	end

	return false
end
