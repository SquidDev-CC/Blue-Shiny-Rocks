local tree = require "bsrocks.downloaders.tree"

local downloaders = {
	-- GitHub
	function(source, files)
		local url = source.url
		if not url then return end

		local repo = url:match("git://github%.com/(.*)")
		local branch = source.branch or source.tag or "master"
		if not repo then
			-- If we have the archive then we can also fetch from GitHub
			repo, branch = url:match("https?://github%.com/(.*)/archive/(.*).tar.gz")
			if not repo then return end
		end

		if not files then
			return true
		end

		print("Downloading " .. repo .. "@" .. branch)
		return tree('https://raw.github.com/'..repo..'/'..branch..'/', files)
	end,

}

return function(source, files)
	for _, downloader in ipairs(downloaders) do
		local result = downloader(source, files)
		if result then
			return result
		end
	end

	return false
end
