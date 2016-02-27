local term = {}
function term.isatty(file)
	return file == io.stdout
end
return term
