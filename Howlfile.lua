Options:Default "trace"

Sources:Main "runner.lua"
	:Depends {"env", "utils"}

Sources:File "utils.lua"
	:Name "utils"
do -- Minification
	Sources:File "env/env.lua"
		:Name "env"
		:Depends {"debug", "io", "package", "os"}

	Sources:File "env/package.lua"
		:Name "package"
		:Depends "utils"

	Sources:File "env/io.lua"
		:Name "io"
		:Depends "utils"

	Sources:File "env/os.lua"
		:Name "os"
		:Depends "utils"

	Sources:File "env/debug.lua"
		:Name "debug"
		:Depends "utils"
end

Tasks:Clean("clean", "build")
Tasks:Combine("combine", Sources, "build/env.lua", {"clean"})
	:Verify()

Tasks:Minify("minify", "build/env.lua", "build/env.min.lua")
	:Description("Produces a minified version of the code")

Tasks:CreateBootstrap("boot", Sources, "build/Boot.lua", {"clean"})
	:Traceback()

Tasks:Task "build"{"minify", "boot"}
	:Description "Minify and bootstrap"