local commands = { }

local function addCommand(command)
	commands[command.name] = command
end

local printColoured
if term.isColour() then
	printColoured = function(text, colour)
		term.setTextColour(colour)
		print(text)
		term.setTextColour(colours.white)
	end
else
	printColoured = function(text) print(text) end
end

-- Primary packages
addCommand(require "bsrocks.commands.search")
addCommand(require "bsrocks.commands.install")

-- Admin packages
addCommand(require "bsrocks.commands.fetch")
addCommand(require "bsrocks.commands.makepatches")
addCommand(require "bsrocks.commands.applypatches")
addCommand(require "bsrocks.commands.exec")

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
				print("Did you mean: ")
				printDid = true
			end

			print(cmd)
		end
	end
	error("No such command", 0)
else
	foundCommand.execute(select(2, ...))
end
