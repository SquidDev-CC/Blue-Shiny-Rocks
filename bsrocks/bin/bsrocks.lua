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

addCommand(require "bsrocks.commands.install")
addCommand(require "bsrocks.commands.makepatches")
addCommand(require "bsrocks.commands.search")

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
	end
})

local command = ...
if not command then
	command = "help"
end

local foundCommand = commands[command]

if not foundCommand then
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
end

foundCommand.execute(select(2, ...))
