local downloaders = {
	require "bsrocks.downloaders.github",
}

return function(source, files)
	for _, downloader in ipairs(downloaders) do
		local files = downloader(source, files)
		if files then
			print()
			return files
		end
	end

	return false
end
