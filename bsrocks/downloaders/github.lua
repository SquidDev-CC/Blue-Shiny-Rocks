--- A downloader for GitHub repositories

local download = require "bsrocks.downloaders.download"

return function(source, files, settings)
	local url = source.url
	if not url then return end

	local repo = url:match("git://github%.com/(.*)")
	local branch = source.branch or "master"
	if not repo then
		-- If we have the archive then we can also fetch from GitHub
		repo, branch = url:match("https?://github%.com/(.*)/archive/(.*).tar.gz")
		if not repo then return end
	end

	print("Downloading " .. repo .. "@" .. branch)
	return download('https://raw.github.com/'..repo..'/'..branch..'/', files, settings.tries, settings.callback)
end
