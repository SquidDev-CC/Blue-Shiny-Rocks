local commands = { }

local function addCommand(command)
	commands[command.name] = command
	if command.alias then
		for _, v in ipairs(command.alias) do
			commands[v] = command
		end
	end
end

local utils = require "bsrocks.lib.utils"
local printColoured, printIndent = utils.printColoured, utils.printIndent
local patchDirectory = require "bsrocks.lib.settings".patchDirectory

-- Primary packages
addCommand(require "bsrocks.commands.desc")
addCommand(require "bsrocks.commands.dumpsettings")
addCommand(require "bsrocks.commands.exec")
addCommand(require "bsrocks.commands.install")
addCommand(require "bsrocks.commands.list")
addCommand(require "bsrocks.commands.remove")
addCommand(require "bsrocks.commands.repl")
addCommand(require "bsrocks.commands.search")

-- Install admin packages if we have a patch directory
if fs.exists(patchDirectory) then
	addCommand(require "bsrocks.commands.admin.addpatchspec")
	addCommand(require "bsrocks.commands.admin.addrockspec")
	addCommand(require "bsrocks.commands.admin.apply")
	addCommand(require "bsrocks.commands.admin.fetch")
	addCommand(require "bsrocks.commands.admin.make")
end

local function getCommand(command)
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
		return foundCommand
	end
end

addCommand({
	name = "help",
	help = "Provide help for a command",
	syntax = "[command]",
	description = "  [command]  The command to get help for. Leave blank to get some basic help for all commands.",
	execute = function(cmd)
		if cmd then
			local command = getCommand(cmd)
			print(command.help)

			if command.syntax ~= "" then
				printColoured("Synopsis", colours.orange)
				printColoured("  " .. command.name .. " " .. command.syntax, colours.lightGrey)
			end

			if command.description then
				printColoured("Description", colours.orange)
				local description = command.description:gsub("^\n+", ""):gsub("\n+$", "")

				if term.isColor() then term.setTextColour(colours.lightGrey) end
				for line in (description .. "\n"):gmatch("([^\n]*)\n") do
					local _, indent = line:find("^(%s*)")
					printIndent(line:sub(indent + 1), indent)
				end
				if term.isColor() then term.setTextColour(colours.white) end
			end
		else
			printColoured("bsrocks <command> [args]", colours.cyan)
			printColoured("Available commands", colours.lightGrey)
			for _, command in pairs(commands) do
				print("  " .. command.name .. " " .. command.syntax)
				printColoured("    " .. command.help, colours.lightGrey)
			end
		end
	end
})

-- Default to printing help messages
local cmd = ...
if not cmd or cmd == "-h" or cmd == "--help" then
	cmd = "help"
elseif select(2, ...) == "-h" or select(2, ...) == "--help" then
	return getCommand("help").execute(cmd)
end

local foundCommand = getCommand(cmd)
local args = {...}
return foundCommand.execute(select(2, unpack(args)))
