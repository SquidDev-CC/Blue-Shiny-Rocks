local tree = require "bsrocks.downloaders.tree"

local downloaders = {
	-- GitHub
	function(source, files)
		local url = source.url
		if not url then return end

		local repo = url:match("git://github%.com/(.*)$")
		local branch = source.branch or source.tag or "master"
		if repo then
			repo = repo:gsub("%.git$", "")
		else
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
	function(source, files)
		local url = source.single
		if not url then return end

		if not files then
			return true
		end

		if #files ~= 1 then error("Expected 1 file for single, got " .. #files, 0) end

		local handle, msg = http.get(url)
		if not handle then
			error(msg or "Cannot download " .. url, 0)
		end

		local contents = handle.readAll()
		handle.close()
		return { [files[1]] = contents }
	end

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
