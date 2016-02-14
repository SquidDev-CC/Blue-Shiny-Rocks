--- A downloader for GitHub repositories

--- Download individual files
-- @tparam string repo The name of the repo
-- @tparam string branch The name of the branch
-- @tparam table files The list of files to download
-- @tparam int tries Number of times to attempt to download
-- @tparam (success:boolean, path:string, count:int, total:int)->nil callback Function to call on download progress
local function download(repo, branch, files, tries, callback)
	local getRaw = 'https://raw.github.com/'..repo..'/'..branch..'/'
	local result = {}

	local count = 0
	local total = #files

	-- Download a file and store it in the tree
	local errored = false
	local function download(path)
		local contents

		-- Attempt to download the file
		for i = 1, tries do
			local url = (getRaw .. path):gsub(' ','%%20')
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

return function(source, files, settings)
	local url = source.url
	if not url then return end

	local repo = url:match("git://github.com/(.*)")
	if not repo then return end

	local branch = source.branch or "master"

	print("Downloading " .. repo .. "@" .. branch)
	return download(repo, branch, files, settings.tries, settings.callback)
end
