Options:Default "trace"

local files = Files()
	:Include "wild:bsrocks/*.lua"
	:Startup "bsrocks/bin/bsrocks.lua"

Tasks:Clean("clean", "build")
Tasks:AsRequire("develop", files, "build/bsrocksD.lua"):Link()
	:Description "Generates a bootstrap file for development"

Tasks:AsRequire("main", files, "build/bsrocks.un.lua")
Tasks:Minify("minify", "build/bsrocks.un.lua", "build/bsrocks.min.un.lua")

-- Add licenses. We kinda require this because diffmatchpatch
local function readFile(path)
	local handle = fs.open(path, "r")
	local contents = handle.readAll()
	handle.close()
	return contents
end

Tasks:Task "license" (function(_, _, file, dest)
	local contents = table.concat {
		"--[[\n",
		readFile(File "LICENSE"),
		"\n\n",
		readFile(File "LICENSE-DMP"),
		"\n]]\n",
		readFile(File(file)),
	}

	local handle = fs.open(File(dest), "w")
	handle.write(contents)
	handle.close()

end):Maps("wild:*.un.lua", "wild:*.lua")
	:Description "Append a license to a file"

Tasks:Task "licenses" {}
	:Requires { "build/bsrocks.lua", "build/bsrocks.min.lua" }
	:Description "Generate licensed files"

Tasks:Task "cleanup" (function()
	fs.delete(File "build/bsrocks.un.lua")
	fs.delete(File "build/bsrocks.min.un.lua")
end):Description "Destory unlicensed files"


Tasks:Task "build" {"clean", "licenses", "cleanup"} :Description "Main build task"
Tasks:Default "build"
