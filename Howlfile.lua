Options:Default "trace"

local fs = require "howl.platform".fs
local Source = require "howl.files.Source"

local main = {
	include = { "bsrocks/*.lua" },
	exclude = { "bsrocks/bin/completions.lua", "bsrocks/bin/repl.lua" },
	startup = "bsrocks/bin/bsrocks.lua",
	api = true,
}

Tasks:clean()
Tasks:require "develop" (main) {
	link = true,
	output = "build/bsrocksD.lua",
	description = "Generates a bootstrap file for development"
}

Tasks:require "main" (main) { output = "build/bsrocks.un.lua" }

Tasks:require "repl" {
	include = {
		"bsrocks/bin/repl.lua",
		"bsrocks/lib/parse.lua",
		"bsrocks/commands/repl.lua",
		"bsrocks/lib/dump.lua",
	},
	output = "build/repl.lua",
	startup = "bsrocks/bin/repl.lua",
}

Tasks:minify "minify" { input = "build/bsrocks.un.lua", output = "build/bsrocks.min.un.lua" }
Tasks:minify "replMin" { input = "build/repl.lua", output = "build/repl.min.lua" }

-- Add licenses. We kinda require this because diffmatchpatch
Tasks:Task "license" (function(_, _, file, dest)
	local contents = table.concat {
		"--[[\n",
		fs.read(File "LICENSE"),
		"\n\n",
		fs.read(File "LICENSE-DMP"),
		"\n]]\n",
		fs.read(File(file)),
	}

	fs.write(File(dest), contents)
end)
	:Maps("wild:build/*.un.lua", "wild:build/*.lua")
	:description "Append a license to a file"

Tasks:Task "licenses" {}
	:requires { "build/bsrocks.lua", "build/bsrocks.min.lua" }
	:description "Generate licensed files"

Tasks:Task "cleanup" (function()
	fs.delete(File "build/bsrocks.un.lua")
	fs.delete(File "build/bsrocks.min.un.lua")
end):description "Destory unlicensed files"

Tasks:Task "build" {"clean", "licenses", "replMin", "cleanup"} :description "Main build task"
Tasks:Default "build"

Tasks:gist "upload" (function(spec)
	spec:summary "Vanilla Lua emulation and package manager (http://www.computercraft.info/forums2/index.php?/topic/26032- and https://github.com/SquidDev-CC/Blue-Shiny-Rokcs)"
	spec:gist "6ced21eb437a776444aacef4d597c0f7"
	spec:from "build" {
		include = { "bsrocks.lua", "bsrocks.min.lua", "repl.lua", "repl.min.lua" }
	}
end) :Requires { "build/bsrocks.lua", "build/bsrocks.min.lua", "build/repl.lua", "build/repl.min.lua" }
