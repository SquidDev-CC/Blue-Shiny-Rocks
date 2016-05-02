local function read(file)
	local handle = fs.open(file, "r")
	local contents = handle.readAll()
	handle.close()
	return contents
end

local function readLines(file)
	local handle = fs.open(file, "r")
	local out, n = {}, 0

	for line in handle.readLine do
		n = n + 1
		out[n] = line
	end

	handle.close()

	-- Trim trailing lines
	while out[n] == "" do
		out[n] = nil
		n = n - 1
	end

	return out
end

local function write(file, contents)
	local handle = fs.open(file, "w")
	handle.write(contents)
	handle.close()
end

local function writeLines(file, contents)
	local handle = fs.open(file, "w")
	for i = 1, #contents do
		handle.writeLine(contents[i])
	end
	handle.close()
end

local function assertExists(file, name, level)
	if not fs.exists(file) then
		error("Cannot find " .. name .. " (Looking for " .. file .. ")", level or 1)
	end
end

local function readDir(directory, reader)
	reader = reader or read
	local offset = #directory + 2
	local stack, n = { directory }, 1

	local files = {}

	while n > 0 do
		local top = stack[n]
		n = n - 1

		if fs.isDir(top) then
			for _, file in ipairs(fs.list(top)) do
				n = n + 1
				stack[n] = fs.combine(top, file)
			end
		else
			files[top:sub(offset)] = reader(top)
		end
	end

	return files
end

local function writeDir(dir, files, writer)
	writer = writer or write
	for file, contents in pairs(files) do
		writer(fs.combine(dir, file), contents)
	end
end

return {
	read = read,
	readLines = readLines,
	readDir = readDir,

	write = write,
	writeLines = writeLines,
	writeDir = writeDir,

	assertExists = assertExists,
}
