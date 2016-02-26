local function completeMultipleChoice(text, options)
    local results = {}
    for n=1, #options do
        local option = options[n]
        if #option > #text and option:sub(1, #text) == text then
            local result = option:sub(#text + 1)
            table.insert(results, result .. " ")
        end
    end
    return results
end

local options = {
	"dest", "dump-settings", "exec", "install", "list",
	"remove", "repl", "search",

	"add-patchspec", "add-rockspec", "apply-patches", "fetch", "make-patches"
}

local function completeBsRocks(shell, index, text, previous)
    if index == 1 then
        return completeMultipleChoice(text, options)
    elseif nIndex == 2 then
        if previous[2] == "exec" then
            return fs.complete(sText, shell.dir(), true, false )
        end
    end
end

shell.setCompletionFunction(shell.resolve(...), completeBsRocks)
