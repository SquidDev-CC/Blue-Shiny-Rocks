Options:Default "trace"

local files = Files()
	:Include "wild:bsrocks/*.lua"
	:Startup "bsrocks/bin/bsrocks.lua"

Tasks:Clean("clean", "build")
Tasks:AsRequire("build", files, "build/bsrocks.lua")
Tasks:AsRequire("develop", files, "build/bsrocksD.lua"):Link()
