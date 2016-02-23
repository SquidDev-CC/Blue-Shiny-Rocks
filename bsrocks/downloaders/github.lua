--- A downloader for GitHub repositories

local tree = require "bsrocks.downloaders.tree"

return function(source, files)
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
	return tree('https://raw.github.com/'..repo..'/'..branch..'/', files)
end
