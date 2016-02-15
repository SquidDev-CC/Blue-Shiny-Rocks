--- Download individual files
-- @tparam string prefix The url prefix to use
-- @tparam table files The list of files to download
-- @tparam int tries Number of times to attempt to download
-- @tparam (success:boolean, path:string, count:int, total:int)->nil callback Function to call on download progress
return function(prefix, files, tries, callback)
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
