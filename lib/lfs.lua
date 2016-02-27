--- Lua implementation of LuaFileSystem
-- @url http://keplerproject.github.io/luafilesystem/manual.html
-- Not yet implemented:
-- - lock_dir
-- - lock
-- - link
-- - unlock
-- - symlinkattributes

local M = {}
M._VERSION = "1.6.3-1"

local function nyi(name)
	M[name] = function() error(name .. " is not implemented", 2) end
end

nyi("lock_dir")
nyi("lock")
function M.link() return nil, "Not implemented" end
nyi("unlock")
nyi("symlinkattributes")

local const0 = function() return 0 end

local function dev(name)
	local d = fs.getDrive(name)
	if d == "rom" then
		return 0
	elseif d == "hdd" then
		return 1
	else
		return 2
	end
end

local attributeProviders = {
	dev = dev,

	-- No clue
	ino = const0,

	-- Can only be directory or file in CC
	mode = function(name)
		if fs.isDir(name) then
			return "directory"
		else
			return "file"
		end
	end,

	-- File only exists once
	nlink = function() return 1 end,

	-- No users
	uid = const0,
	gid = const0,

	rdev = dev,

	-- No file tracking
	access = const0,
	modification = const0,
	change = const0,

	size = fs.getSize,
	permissions = function() return "rwxrwxrwx" end
}


function M.attributes(path, name)
	path = shell.resolve(path)

	if not fs.exists(path) then
		return nil, ("cannot obtain information from file `%s'"):format(path)
	end

	if type(name) == "string" then
		local provider = attributeProviders[name]
		if not provider then
			error("invalid attribute name", 2)
		end

		return provider(path)
	end

	local out = {}
	for k, v in pairs(attributeProviders) do
		out[k] = v(path)
	end

	return out
end

function M.chdir(path)
	path = shell.resolve(path)

	if fs.exists(path) and fs.isDir(path) then
		shell.setDir(path)
		return true
	else
		return nil
	end
end

function M.currentdir()
	return "/" .. shell.dir()
end

local function closeDir(item)
	if type(item) ~= "table" or not item.items or not item.pointer then
		error("bad argument #1 (directory metatable expected, got " .. type(item) .. ")", 2)
	else
		item.closed = true
	end
end

local function iterDir(item)
	if type(item) ~= "table" or not item.items or not item.pointer then
		error("bad argument #1 (directory metatable expected, got " .. type(item) .. ")", 2)
	elseif item.closed then
		error("closed directory", 2)
	else
		local pointer = item.pointer + 1
		item.pointer = pointer
		local value = item.items[pointer]
		if not value then closeDir(item) end
		return value
	end
end

local dirMeta = { __call = iterDir, __metatable = false }

function M.dir(path)
	path = shell.resolve(path)

	if fs.exists(path) and fs.isDir(path) then
		local items = fs.list(path)
		local len = #items
		items[len + 1] = "."
		items[len + 2] = ".."
		return iterDir, setmetatable({
			pointer = 0,
			items = items,
			closed = false,

			close = closeDir,
			next = iterDir,
		}, dirMeta)
	else
		error("cannot open " .. path, 2)
	end
end

function M.mkdir(path)
	path = shell.resolve(path)

	if fs.isReadOnly(path) then
		return nil, "Permission denied"
	elseif fs.exists(path) then
		return nil, "File exists"
	elseif not fs.exists(fs.getDir(path)) then
		return nil, "No such file or directory"
	else
		fs.makeDir(path)
		return true
	end
end

function M.rmdir(path)
	path = shell.resolve(path)

	if fs.isReadOnly(path) then
		return nil, "Permission denied"
	elseif not fs.exists(path) then
		return nil, "No such file or directory"
	elseif not fs.isDir(path) then
		return nil, "Not a directory"
	else
		fs.delete(path)
		return true
	end
end

function M.setmode(path, mode)
	return true, "binary" -- Lies, lies
end

function M.touch(path)
	path = shell.resolve(path)

	if fs.isReadOnly(path) then
		return nil, "Permission denied"
	elseif not fs.exists(path) then
		fs.open(path, "w").close()
		return true
	end
end

return M
