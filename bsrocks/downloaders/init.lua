local downloaders = {
	require "bsrocks.downloaders.github"
	-- TODO: tar.gz and zip
}

return function(source, files, settings)
	for _, downloader in ipairs(downloaders) do
		local files = downloader(source, files, settings)
		if files then return files end
	end

	return false
end
