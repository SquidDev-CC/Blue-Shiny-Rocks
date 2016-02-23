--- Check if a Lua source is either invalid or incomplete

local setmeta = setmetatable
local function createLookup(tbl)
	for _, v in ipairs(tbl) do tbl[v] = true end
	return tbl
end

--- List of white chars
local whiteChars = createLookup { ' ', '\n', '\t', '\r' }

--- Lookup of escape characters
local escapeLookup = { ['\r'] = '\\r', ['\n'] = '\\n', ['\t'] = '\\t', ['"'] = '\\"', ["'"] = "\\'" }

--- Lookup of lower case characters
local lowerChars = createLookup {
	'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
	'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
}

--- Lookup of upper case characters
local upperChars = createLookup {
	'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
	'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
}

--- Lookup of digits
local digits = createLookup { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' }

--- Lookup of hex digits
local hexDigits = createLookup {
	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
	'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'E', 'e', 'F', 'f'
}

--- Lookup of valid symbols
local symbols = createLookup { '+', '-', '*', '/', '^', '%', ',', '{', '}', '[', ']', '(', ')', ';', '#' }

--- Lookup of valid keywords
local keywords = createLookup {
	'and', 'break', 'do', 'else', 'elseif',
	'end', 'false', 'for', 'function', 'goto', 'if',
	'in', 'local', 'nil', 'not', 'or', 'repeat',
	'return', 'then', 'true', 'until', 'while',
}

--- Keywords that end a block
local statListCloseKeywords = createLookup { 'end', 'else', 'elseif', 'until' }

--- Unary operators
local unops = createLookup { '-', 'not', '#' }

--- Stores a list of tokens
-- @type TokenList
-- @tfield table tokens List of tokens
-- @tfield number pointer Pointer to the current
-- @tfield table savedPointers A save point
local TokenList = {}
do
	--- Get this element in the token list
	-- @tparam int offset The offset in the token list
	function TokenList:Peek(offset)
		local tokens = self.tokens
		offset = offset or 0
		return tokens[math.min(#tokens, self.pointer + offset)]
	end

	--- Get the next token in the list
	-- @tparam table tokenList Add the token onto this table
	-- @treturn Token The token
	function TokenList:Get(tokenList)
		local tokens = self.tokens
		local pointer = self.pointer
		local token = tokens[pointer]
		self.pointer = math.min(pointer + 1, #tokens)
		if tokenList then
			table.insert(tokenList, token)
		end
		return token
	end

	--- Check if the next token is of a type
	-- @tparam string type The type to compare it with
	-- @treturn bool If the type matches
	function TokenList:Is(type)
		return self:Peek().Type == type
	end

	--- Check if the next token is a symbol and return it
	-- @tparam string symbol Symbol to check (Optional)
	-- @tparam table tokenList Add the token onto this table
	-- @treturn [ 0 ] ?|token If symbol is not specified, return the token
	-- @treturn [ 1 ] boolean If symbol is specified, return true if it matches
	function TokenList:ConsumeSymbol(symbol, tokenList)
		local token = self:Peek()
		if token.Type == 'Symbol' then
			if symbol then
				if token.Data == symbol then
					self:Get(tokenList)
					return true
				else
					return nil
				end
			else
				self:Get(tokenList)
				return token
			end
		else
			return nil
		end
	end

	--- Check if the next token is a keyword and return it
	-- @tparam string kw Keyword to check (Optional)
	-- @tparam table tokenList Add the token onto this table
	-- @treturn [ 0 ] ?|token If kw is not specified, return the token
	-- @treturn [ 1 ] boolean If kw is specified, return true if it matches
	function TokenList:ConsumeKeyword(kw, tokenList)
		local token = self:Peek()
		if token.Type == 'Keyword' and token.Data == kw then
			self:Get(tokenList)
			return true
		else
			return nil
		end
	end

	--- Check if the next token matches is a keyword
	-- @tparam string kw The particular keyword
	-- @treturn boolean If it matches or not
	function TokenList:IsKeyword(kw)
		local token = self:Peek()
		return token.Type == 'Keyword' and token.Data == kw
	end

	--- Check if the next token matches is a symbol
	-- @tparam string symbol The particular symbol
	-- @treturn boolean If it matches or not
	function TokenList:IsSymbol(symbol)
		local token = self:Peek()
		return token.Type == 'Symbol' and token.Data == symbol
	end

	--- Check if the next token is an end of file
	-- @treturn boolean If the next token is an end of file
	function TokenList:IsEof()
		return self:Peek().Type == 'Eof'
	end
end

--- Create a list of @{Token|tokens} from a Lua source
-- @tparam string src Lua source code
-- @treturn TokenList The list of @{Token|tokens}
local function lex(src)
	--token dump
	local tokens = {}

	do -- Main bulk of the work
		--line / char / pointer tracking
		local pointer = 1
		local line = 1
		local char = 1

		--get / peek functions
		local function get()
			local c = src:sub(pointer,pointer)
			if c == '\n' then
				char = 1
				line = line + 1
			else
				char = char + 1
			end
			pointer = pointer + 1
			return c
		end
		local function peek(n)
			n = n or 0
			return src:sub(pointer+n,pointer+n)
		end
		local function consume(chars)
			local c = peek()
			for i = 1, #chars do
				if c == chars:sub(i,i) then return get() end
			end
		end

		--shared stuff
		local function generateError(err, resumable)
			if resumable == true then
				resumable = 1
			else
				resumable = 0
			end
			error(line..":"..char..":"..resumable..":"..err, 0)
		end

		local function tryGetLongString()
			local start = pointer
			if peek() == '[' then
				local equalsCount = 0
				local depth = 1
				while peek(equalsCount+1) == '=' do
					equalsCount = equalsCount + 1
				end
				if peek(equalsCount+1) == '[' then
					--start parsing the string. Strip the starting bit
					for _ = 0, equalsCount+1 do get() end

					--get the contents
					local contentStart = pointer
					while true do
						--check for eof
						if peek() == '' then
							generateError("Expected `]"..string.rep('=', equalsCount).."]` near <eof>.", true)
						end

						--check for the end
						local foundEnd = true
						if peek() == ']' then
							for i = 1, equalsCount do
								if peek(i) ~= '=' then foundEnd = false end
							end
							if peek(equalsCount+1) ~= ']' then
								foundEnd = false
							end
						else
							if peek() == '[' then
								-- is there an embedded long string?
								local embedded = true
								for i = 1, equalsCount do
									if peek(i) ~= '=' then
										embedded = false
										break
									end
								end
								if peek(equalsCount + 1) == '[' and embedded then
									-- oh look, there was
									depth = depth + 1
									for i = 1, (equalsCount + 2) do
										get()
									end
								end
							end
							foundEnd = false
						end

						if foundEnd then
							depth = depth - 1
							if depth == 0 then
								break
							else
								for i = 1, equalsCount + 2 do
									get()
								end
							end
						else
							get()
						end
					end

					--get the interior string
					local contentString = src:sub(contentStart, pointer-1)

					--found the end. Get rid of the trailing bit
					for i = 0, equalsCount+1 do get() end

					--get the exterior string
					local longString = src:sub(start, pointer-1)

					--return the stuff
					return contentString, longString
				else
					return nil
				end
			else
				return nil
			end
		end

		--main token emitting loop
		while true do
			--get leading whitespace. The leading whitespace will include any comments
			--preceding the token. This prevents the parser needing to deal with comments
			--separately.
			local longStr = false
			while true do
				local c = peek()
				if c == '#' and peek(1) == '!' and line == 1 then
					-- #! shebang for linux scripts
					get()
					get()
					while peek() ~= '\n' and peek() ~= '' do
						get()
					end
				end
				if c == ' ' or c == '\t' or  c == '\n' or c == '\r' then
					get()
				elseif c == '-' and peek(1) == '-' then
					--comment
					get() get()
					local _, wholeText = tryGetLongString()
					if not wholeText then
						while peek() ~= '\n' and peek() ~= '' do
							get()
						end
					end
				else
					break
				end
			end

			--get the initial char
			local thisLine = line
			local thisChar = char
			local errorAt = ":"..line..":"..char..":> "
			local c = peek()

			--symbol to emit
			local toEmit = nil

			--branch on type
			if c == '' then
				--eof
				toEmit = { Type = 'Eof' }

			elseif upperChars[c] or lowerChars[c] or c == '_' then
				--ident or keyword
				local start = pointer
				repeat
					get()
					c = peek()
				until not (upperChars[c] or lowerChars[c] or digits[c] or c == '_')
				local dat = src:sub(start, pointer-1)
				if keywords[dat] then
					toEmit = {Type = 'Keyword', Data = dat}
				else
					toEmit = {Type = 'Ident', Data = dat}
				end

			elseif digits[c] or (peek() == '.' and digits[peek(1)]) then
				--number const
				local start = pointer
				if c == '0' and peek(1) == 'x' then
					get();get()
					while hexDigits[peek()] do get() end
					if consume('Pp') then
						consume('+-')
						while digits[peek()] do get() end
					end
				else
					while digits[peek()] do get() end
					if consume('.') then
						while digits[peek()] do get() end
					end
					if consume('Ee') then
						consume('+-')

						if not digits[peek()] then generateError("Expected exponent") end
						repeat get() until not digits[peek()]
					end

					local n = peek():lower()
					if (n >= 'a' and n <= 'z') or n == '_' then
						generateError("Invalid number format")
					end
				end
				toEmit = {Type = 'Number', Data = src:sub(start, pointer-1)}

			elseif c == '\'' or c == '\"' then
				local start = pointer
				--string const
				local delim = get()
				local contentStart = pointer
				while true do
					local c = get()
					if c == '\\' then
						get() --get the escape char
					elseif c == delim then
						break
					elseif c == '' or c == '\n' then
						generateError("Unfinished string near <eof>")
					end
				end
				local content = src:sub(contentStart, pointer-2)
				local constant = src:sub(start, pointer-1)
				toEmit = {Type = 'String', Data = constant, Constant = content}

			elseif c == '[' then
				local content, wholetext = tryGetLongString()
				if wholetext then
					toEmit = {Type = 'String', Data = wholetext, Constant = content}
				else
					get()
					toEmit = {Type = 'Symbol', Data = '['}
				end

			elseif consume('>=<') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = c..'='}
				else
					toEmit = {Type = 'Symbol', Data = c}
				end

			elseif consume('~') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = '~='}
				else
					generateError("Unexpected symbol `~` in source.")
				end

			elseif consume('.') then
				if consume('.') then
					if consume('.') then
						toEmit = {Type = 'Symbol', Data = '...'}
					else
						toEmit = {Type = 'Symbol', Data = '..'}
					end
				else
					toEmit = {Type = 'Symbol', Data = '.'}
				end

			elseif consume(':') then
				if consume(':') then
					toEmit = {Type = 'Symbol', Data = '::'}
				else
					toEmit = {Type = 'Symbol', Data = ':'}
				end

			elseif symbols[c] then
				get()
				toEmit = {Type = 'Symbol', Data = c}

			else
				local contents, all = tryGetLongString()
				if contents then
					toEmit = {Type = 'String', Data = all, Constant = contents}
				else
					generateError("Unexpected Symbol `"..c.."` in source.")
				end
			end

			--add the emitted symbol, after adding some common data
			toEmit.line = thisLine
			toEmit.char = thisChar
			tokens[#tokens+1] = toEmit

			--halt after eof has been emitted
			if toEmit.Type == 'Eof' then break end
		end
	end

	--public interface:
	local tokenList = setmetatable({
		tokens = tokens,
		pointer = 1
	}, {__index = TokenList})

	return tokenList
end

--- Create a AST tree from a Lua Source
-- @tparam TokenList tok List of tokens from @{lex}
-- @treturn table The AST tree
local function parse(tok)
	--- Generate an error
	-- @tparam string msg The error message
	-- @raise The produces error message
	local function GenerateError(msg) error(msg, 0) end

	local ParseExpr,
	      ParseStatementList,
	      ParseSimpleExpr

	--- Parse the function definition and its arguments
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node A function Node
	local function ParseFunctionArgsAndBody()
		if not tok:ConsumeSymbol('(') then
			GenerateError("`(` expected.")
		end

		--arg list
		while not tok:ConsumeSymbol(')') do
			if tok:Is('Ident') then
				tok:Get()
				if not tok:ConsumeSymbol(',') then
					if tok:ConsumeSymbol(')') then
						break
					else
						GenerateError("`)` expected.")
					end
				end
			elseif tok:ConsumeSymbol('...') then
				if not tok:ConsumeSymbol(')') then
					GenerateError("`...` must be the last argument of a function.")
				end
				break
			else
				GenerateError("Argument name or `...` expected")
			end
		end

		ParseStatementList()

		if not tok:ConsumeKeyword('end') then
			GenerateError("`end` expected after function body")
		end
	end

	--- Parse a simple expression
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node the resulting node
	local function ParsePrimaryExpr()
		if tok:ConsumeSymbol('(') then
			ParseExpr()
			if not tok:ConsumeSymbol(')') then
				GenerateError("`)` Expected.")
			end
			return { AstType = "Paren" }
		elseif tok:Is('Ident') then
			tok:Get()
		else
			GenerateError("primary expression expected")
		end
	end

	--- Parse some table related expressions
	-- @tparam boolean onlyDotColon Only allow '.' or ':' nodes
	-- @treturn Node The resulting node
	function ParseSuffixedExpr(onlyDotColon)
		--base primary expression
		local prim = ParsePrimaryExpr() or { AstType = ""}

		while true do
			local tokenList = {}

			if tok:ConsumeSymbol('.') or tok:ConsumeSymbol(':') then
				if not tok:Is('Ident') then
					GenerateError("<Ident> expected.")
				end
				tok:Get()

				prim = { AstType = 'MemberExpr' }
			elseif not onlyDotColon and tok:ConsumeSymbol('[') then
				ParseExpr()
				if not tok:ConsumeSymbol(']') then
					GenerateError("`]` expected.")
				end

				prim = { AstType = 'IndexExpr' }
			elseif not onlyDotColon and tok:ConsumeSymbol('(') then
				while not tok:ConsumeSymbol(')') do
					ParseExpr()
					if not tok:ConsumeSymbol(',') then
						if tok:ConsumeSymbol(')') then
							break
						else
							GenerateError("`)` Expected.")
						end
					end
				end

				prim = { AstType = 'CallExpr' }
			elseif not onlyDotColon and tok:Is('String') then
				--string call
				tok:Get()
				prim = { AstType = 'StringCallExpr' }
			elseif not onlyDotColon and tok:IsSymbol('{') then
				--table call
				ParseSimpleExpr()
				prim = { AstType   = 'TableCallExpr' }
			else
				break
			end
		end
		return prim
	end

	--- Parse a simple expression (strings, numbers, booleans, varargs)
	-- @treturn Node The resulting node
	function ParseSimpleExpr()
		if tok:Is('Number') or tok:Is('String') then
			tok:Get()
		elseif tok:ConsumeKeyword('nil') or tok:ConsumeKeyword('false') or tok:ConsumeKeyword('true') or tok:ConsumeSymbol('...') then
		elseif tok:ConsumeSymbol('{') then
			while true do
				if tok:ConsumeSymbol('[') then
					--key
					ParseExpr()

					if not tok:ConsumeSymbol(']') then
						GenerateError("`]` Expected")
					end
					if not tok:ConsumeSymbol('=') then
						GenerateError("`=` Expected")
					end

					ParseExpr()
				elseif tok:Is('Ident') then
					--value or key
					local lookahead = tok:Peek(1)
					if lookahead.Type == 'Symbol' and lookahead.Data == '=' then
						--we are a key
						local key = tok:Get()

						if not tok:ConsumeSymbol('=') then
							GenerateError("`=` Expected")
						end

						ParseExpr()
					else
						--we are a value
						ParseExpr()

					end
				elseif tok:ConsumeSymbol('}') then
					break

				else
					ParseExpr()
				end

				if tok:ConsumeSymbol(';') or tok:ConsumeSymbol(',') then
					--all is good
				elseif tok:ConsumeSymbol('}') then
					break
				else
					GenerateError("`}` or table entry Expected")
				end
			end
		elseif tok:ConsumeKeyword('function') then
			return ParseFunctionArgsAndBody()
		else
			return ParseSuffixedExpr()
		end
	end

	local unopprio = 8
	local priority = {
		['+'] = {6,6},
		['-'] = {6,6},
		['%'] = {7,7},
		['/'] = {7,7},
		['*'] = {7,7},
		['^'] = {10,9},
		['..'] = {5,4},
		['=='] = {3,3},
		['<'] = {3,3},
		['<='] = {3,3},
		['~='] = {3,3},
		['>'] = {3,3},
		['>='] = {3,3},
		['and'] = {2,2},
		['or'] = {1,1},
	}

	--- Parse an expression
	-- @tparam int level Current level (Optional)
	-- @treturn Node The resulting node
	function ParseExpr(level)
		level = level or 0
		--base item, possibly with unop prefix
		if unops[tok:Peek().Data] then
			local op = tok:Get().Data
			ParseExpr(unopprio)
		else
			ParseSimpleExpr()
		end

		--next items in chain
		while true do
			local prio = priority[tok:Peek().Data]
			if prio and prio[1] > level then
				local tokenList = {}
				tok:Get()
				ParseExpr(prio[2])
			else
				break
			end
		end
	end

	--- Parse a statement (if, for, while, etc...)
	-- @treturn Node The resulting node
	local function ParseStatement()
		if tok:ConsumeKeyword('if') then
			--clauses
			repeat
				ParseExpr()

				if not tok:ConsumeKeyword('then') then
					GenerateError("`then` expected.")
				end

				ParseStatementList()
			until not tok:ConsumeKeyword('elseif')

			--else clause
			if tok:ConsumeKeyword('else') then
				ParseStatementList()
			end

			--end
			if not tok:ConsumeKeyword('end') then
				GenerateError("`end` expected.")
			end
		elseif tok:ConsumeKeyword('while') then
			--condition
			ParseExpr()

			--do
			if not tok:ConsumeKeyword('do') then
				return GenerateError("`do` expected.")
			end

			--body
			ParseStatementList()

			--end
			if not tok:ConsumeKeyword('end') then
				GenerateError("`end` expected.")
			end
		elseif tok:ConsumeKeyword('do') then
			--do block
			ParseStatementList()
			if not tok:ConsumeKeyword('end') then
				GenerateError("`end` expected.")
			end
		elseif tok:ConsumeKeyword('for') then
			--for block
			if not tok:Is('Ident') then
				GenerateError("<ident> expected.")
			end
			tok:Get()
			if tok:ConsumeSymbol('=') then
				--numeric for
				ParseExpr()
				if not tok:ConsumeSymbol(',') then
					GenerateError("`,` Expected")
				end
				ParseExpr()
				if tok:ConsumeSymbol(',') then
					ParseExpr()
				end
				if not tok:ConsumeKeyword('do') then
					GenerateError("`do` expected")
				end

				ParseStatementList()
				if not tok:ConsumeKeyword('end') then
					GenerateError("`end` expected")
				end
			else
				--generic for
				while tok:ConsumeSymbol(',') do
					if not tok:Is('Ident') then
						GenerateError("for variable expected.")
					end
					tok:Get(tokenList)
				end
				if not tok:ConsumeKeyword('in') then
					GenerateError("`in` expected.")
				end
				ParseExpr()
				while tok:ConsumeSymbol(',') do
					ParseExpr()
				end

				if not tok:ConsumeKeyword('do') then
					GenerateError("`do` expected.")
				end

				ParseStatementList()
				if not tok:ConsumeKeyword('end') then
					GenerateError("`end` expected.")
				end
			end
		elseif tok:ConsumeKeyword('repeat') then
			ParseStatementList()

			if not tok:ConsumeKeyword('until') then
				GenerateError("`until` expected.")
			end

			ParseExpr()
		elseif tok:ConsumeKeyword('function') then
			if not tok:Is('Ident') then
				GenerateError("Function name expected")
			end
			ParseSuffixedExpr(true) --true => only dots and colons
			ParseFunctionArgsAndBody()
		elseif tok:ConsumeKeyword('local') then
			if tok:Is('Ident') then
				tok:Get()
				while tok:ConsumeSymbol(',') do
					if not tok:Is('Ident') then
						GenerateError("local var name expected")
					end
					tok:Get()
				end

				if tok:ConsumeSymbol('=') then
					repeat
						ParseExpr()
					until not tok:ConsumeSymbol(',')
				end

			elseif tok:ConsumeKeyword('function') then
				if not tok:Is('Ident') then
					GenerateError("Function name expected")
				end

				tok:Get(tokenList)
				ParseFunctionArgsAndBody()
			else
				GenerateError("local var or function def expected")
			end
		elseif tok:ConsumeSymbol('::') then
			if not tok:Is('Ident') then
				GenerateError('Label name expected')
			end
			tok:Get()
			if not tok:ConsumeSymbol('::') then
				GenerateError("`::` expected")
			end
		elseif tok:ConsumeKeyword('return') then
			local exList = {}
			local token = tok:Peek()
			if token.Type == "Eof" or token.Type ~= "Keyword" or not statListCloseKeywords[token.Data] then
				ParseExpr()
				local token = tok:Peek()
				while tok:ConsumeSymbol(',') do
					ParseExpr()
				end
			end
		elseif tok:ConsumeKeyword('break') then
		elseif tok:ConsumeKeyword('goto') then
			if not tok:Is('Ident') then
				GenerateError("Label expected")
			end
			tok:Get(tokenList)
		else
			--statementParseExpr
			local suffixed = ParseSuffixedExpr()

			--assignment or call?
			if tok:IsSymbol(',') or tok:IsSymbol('=') then
				--check that it was not parenthesized, making it not an lvalue
				if suffixed.AstType == "Paren" then
					GenerateError("Can not assign to parenthesized expression, is not an lvalue")
				end

				--more processing needed
				while tok:ConsumeSymbol(',') do
					ParseSuffixedExpr()
				end

				--equals
				if not tok:ConsumeSymbol('=') then
					GenerateError("`=` Expected.")
				end

				--rhs
				ParseExpr()
				while tok:ConsumeSymbol(',') do
					ParseExpr()
				end
			elseif suffixed.AstType == 'CallExpr' or
				   suffixed.AstType == 'TableCallExpr' or
				   suffixed.AstType == 'StringCallExpr'
			then
				--it's a call statement
			else
				GenerateError("Assignment Statement Expected")
			end
		end

		tok:ConsumeSymbol(';')
	end

	--- Parse a a list of statements
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	function ParseStatementList()
		while not statListCloseKeywords[tok:Peek().Data] and not tok:IsEof() do
			ParseStatement()
		end
	end

	return ParseStatementList()
end

return {
	lex = lex,
	parse = parse,
}
