local commands = { }

local function addCommand(command)
	commands[command.name] = command
end

local printColoured = require "bsrocks.lib.utils".printColoured
local patchDirectory = require "bsrocks.lib.settings".patchDirectory

-- Primary packages
addCommand(require "bsrocks.commands.dumpsettings")
addCommand(require "bsrocks.commands.install")
addCommand(require "bsrocks.commands.list")
addCommand(require "bsrocks.commands.search")
addCommand(require "bsrocks.commands.exec")
addCommand(require "bsrocks.commands.repl")

-- Install admin packages if we have a patch directory
if fs.exists(patchDirectory) then
	addCommand(require "bsrocks.commands.admin.applypatches")
	addCommand(require "bsrocks.commands.admin.fetch")
	addCommand(require "bsrocks.commands.admin.makepatches")
end

addCommand({
	name = "help",
	help = "Print this text",
	syntax = "",
	execute = function()
		printColoured("bsrocks <command> [args]", colours.cyan)
		printColoured("Available commands", colours.lightGrey)
		for _, command in pairs(commands) do
			print("  " .. command.name .. " " .. command.syntax)
			printColoured("    " .. command.help, colours.lightGrey)
		end
	end,
})

-- Default to printing help messages
local command = ... or "help"

local foundCommand = commands[command]

if not foundCommand then
	-- No such command, print a list of suggestions
	printError("Cannot find '" .. command .. "'.")
	local match = require "bsrocks.lib.diffmatchpatch".match_main

	local printDid = false
	for cmd, _ in pairs(commands) do
		if match(cmd, command) > 0 then
			if not printDid then
				printColoured("Did you mean: ", colours.yellow)
				printDid = true
			end

			printColoured("  " .. cmd, colours.orange)
		end
	end
	error("No such command", 0)
else
	return foundCommand.execute(select(2, ...))
end
