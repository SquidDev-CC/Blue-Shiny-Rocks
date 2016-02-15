local deltas = {
	scm =    1100,
	cvs =    1000,
	rc =    -1000,
	pre =   -10000,
	beta =  -100000,
	alpha = -1000000
}

local versionMeta = {
	--- Equality comparison for versions.
	-- All version numbers must be equal.
	-- If both versions have revision numbers, they must be equal;
	-- otherwise the revision number is ignored.
	-- @param v1 table: version table to compare.
	-- @param v2 table: version table to compare.
	-- @return boolean: true if they are considered equivalent.
	__eq = function(v1, v2)
		if #v1 ~= #v2 then
			return false
		end
		for i = 1, #v1 do
			if v1[i] ~= v2[i] then
				return false
			end
		end
		if v1.revision and v2.revision then
			return (v1.revision == v2.revision)
		end
		return true
	end,
	--- Size comparison for versions.
	-- All version numbers are compared.
	-- If both versions have revision numbers, they are compared;
	-- otherwise the revision number is ignored.
	-- @param v1 table: version table to compare.
	-- @param v2 table: version table to compare.
	-- @return boolean: true if v1 is considered lower than v2.
	__lt = function(v1, v2)
		for i = 1, math.max(#v1, #v2) do
			local v1i, v2i = v1[i] or 0, v2[i] or 0
			if v1i ~= v2i then
				return (v1i < v2i)
			end
		end
		if v1.revision and v2.revision then
			return (v1.revision < v2.revision)
		end
		return false
	end
}

--- Parse a version string, converting to table format.
-- A version table contains all components of the version string
-- converted to numeric format, stored in the array part of the table.
-- If the version contains a revision, it is stored numerically
-- in the 'revision' field. The original string representation of
-- the string is preserved in the 'string' field.
-- Returned version tables use a metatable
-- allowing later comparison through relational operators.
-- @param vstring string: A version number in string format.
-- @return table or nil: A version table or nil
-- if the input string contains invalid characters.
local function parseVersion(vstring)
	vstring = vstring:match("^%s*(.*)%s*$")
	local main, revision = vstring:match("(.*)%-(%d+)$")

	local version = {}
	local i = 1

	if revision then
		vstring = main
		version.revision = tonumber(revision)
	end

	while #vstring > 0 do
		-- extract a number
		local token, rest = vstring:match("^(%d+)[%.%-%_]*(.*)")
		if token then
			local number = tonumber(token)
			version[i] = version[i] and version[i] + number/100000 or number
			i = i + 1
		else
			-- extract a word
			token, rest = vstring:match("^(%a+)[%.%-%_]*(.*)")
			if not token then
				util.printerr("Warning: version number '"..vstring.."' could not be parsed.")

				if not version[i] then version[i] = 0 end
				break
			end
			local number = deltas[token] or (token:byte() / 1000)
			version[i] = version[i] and version[i] + number/100000 or number
		end
		vstring = rest
	end

	return setmetatable(version, versionMeta)
end

local operators = {
	["=="] = "==", ["~="] = "~=",
	[">"] = ">",   ["<"] = "<",
	[">="] = ">=", ["<="] = "<=", ["~>"] = "~>",

	-- plus some convenience translations
	[""] = "==", ["="] = "==", ["!="] = "~="
}

--- Consumes a constraint from a string, converting it to table format.
-- For example, a string ">= 1.0, > 2.0" is converted to a table in the
-- format {op = ">=", version={1,0}} and the rest, "> 2.0", is returned
-- back to the caller.
-- @param input string: A list of constraints in string format.
-- @return (table, string) or nil: A table representing the same
-- constraints and the string with the unused input, or nil if the
-- input string is invalid.
local function parseConstraint(constraint)
	assert(type(constraint) == "string")

	local no_upgrade, op, version, rest = constraint:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
	local _op = operators[op]
	version = parseVersion(version)
	if not _op then
		return nil, "Encountered bad constraint operator: '" .. tostring(op) .. "' in '" .. input .. "'"
	end
	if not version then
		return nil, "Could not parse version from constraint: '" .. input .. "'"
	end

	return { op = _op, version = version, no_upgrade = no_upgrade=="@" and true or nil }, rest
end

--- Convert a list of constraints from string to table format.
-- For example, a string ">= 1.0, < 2.0" is converted to a table in the format
-- {{op = ">=", version={1,0}}, {op = "<", version={2,0}}}.
-- Version tables use a metatable allowing later comparison through
-- relational operators.
-- @param input string: A list of constraints in string format.
-- @return table or nil: A table representing the same constraints,
-- or nil if the input string is invalid.
function parseConstraints(input)
	assert(type(input) == "string")

	local constraints, constraint, oinput = {}, nil, input
	while #input > 0 do
		constraint, input = parseConstraint(input)
		if constraint then
			table.insert(constraints, constraint)
		else
			return nil, "Failed to parse constraint '"..tostring(oinput).."' with error: ".. input
		end
	end
	return constraints
end

--- Convert a dependency from string to table format.
-- For example, a string "foo >= 1.0, < 2.0"
-- is converted to a table in the format
-- {name = "foo", constraints = {{op = ">=", version={1,0}},
-- {op = "<", version={2,0}}}}. Version tables use a metatable
-- allowing later comparison through relational operators.
-- @param dep string: A dependency in string format
-- as entered in rockspec files.
-- @return table or nil: A table representing the same dependency relation,
-- or nil if the input string is invalid.
local function parseDependency(dep)
	assert(type(dep) == "string")

	local name, rest = dep:match("^%s*([a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*(.*)")
	if not name then return nil, "failed to extract dependency name from '" .. tostring(dep) .. "'" end
	local constraints, err = parseConstraints(rest)
	if not constraints then return nil, err end
	return { name = name, constraints = constraints }
end

--- A more lenient check for equivalence between versions.
-- This returns true if the requested components of a version
-- match and ignore the ones that were not given. For example,
-- when requesting "2", then "2", "2.1", "2.3.5-9"... all match.
-- When requesting "2.1", then "2.1", "2.1.3" match, but "2.2"
-- doesn't.
-- @param version string or table: Version to be tested; may be
-- in string format or already parsed into a table.
-- @param requested string or table: Version requested; may be
-- in string format or already parsed into a table.
-- @return boolean: True if the tested version matches the requested
-- version, false otherwise.
local function partialMatch(version, requested)
	assert(type(version) == "string" or type(version) == "table")
	assert(type(requested) == "string" or type(version) == "table")

	if type(version) ~= "table" then version = parseVersion(version) end
	if type(requested) ~= "table" then requested = parseVersion(requested) end
	if not version or not requested then return false end

	for i, ri in ipairs(requested) do
		local vi = version[i] or 0
		if ri ~= vi then return false end
	end
	if requested.revision then
		return requested.revision == version.revision
	end
	return true
end

--- Check if a version satisfies a set of constraints.
-- @param version table: A version in table format
-- @param constraints table: An array of constraints in table format.
-- @return boolean: True if version satisfies all constraints,
-- false otherwise.
function matchConstraints(version, constraints)
	assert(type(version) == "table")
	assert(type(constraints) == "table")

	local ok = true
	setmetatable(version, versionMeta)
	for _, constraint in pairs(constraints) do
		if type(constraint.version) == "string" then
			constraint.version = parseVersion(constraint.version)
		end

		local constraintVersion, constraintOp = constraint.version, constraint.op
		setmetatable(constraintVersion, versionMeta)
		if     constraintOp == "==" then ok = version == constraintVersion
		elseif constraintOp == "~=" then ok = version ~= constraintVersion
		elseif constraintOp == ">"  then ok = version >  constraintVersion
		elseif constraintOp == "<"  then ok = version <  constraintVersion
		elseif constraintOp == ">=" then ok = version >= constraintVersion
		elseif constraintOp == "<=" then ok = version <= constraintVersion
		elseif constraintOp == "~>" then ok = partialMatch(version, constraintVersion)
		end
		if not ok then break end
	end
	return ok
end

--- Attempt to match a dependency to an installed rock.
-- @param dep table: A dependency parsed in table format.
-- @param blacklist table: Versions that can't be accepted. Table where keys
-- are program versions and values are 'true'.
-- @return table or nil: A table containing fields 'name' and 'version'
-- representing an installed rock which matches the given dependency,
-- or nil if it could not be matched.
function matchDependency(dependency, constraints)
	assert(type(dep) == "table")

	local versions = cfg.rocks_provided[dep.name]
	if cfg.rocks_provided[dep.name] then
		-- provided rocks have higher priority than manifest's rocks
		versions = { cfg.rocks_provided[dep.name] }
	else
		versions = manif_core.get_versions(dep.name, deps_mode)
	end
	if not versions then
		return nil
	end
	if blacklist then
		local i = 1
		while versions[i] do
			if blacklist[versions[i]] then
				table.remove(versions, i)
			else
				i = i + 1
			end
		end
	end
	local candidates = {}
	for _, vstring in ipairs(versions) do
		local version = parseVersion(vstring)
		if matchConstraints(version, constraints) then
			table.insert(candidates, version)
		end
	end
	if #candidates == 0 then
		return nil
	else
		table.sort(candidates)
		return {
			name = dep.name,
			version = candidates[#candidates].string
		}
	end
end

return {
	parseVersion = parseVersion,
	parseConstraints = parseConstraints,
	parseDependency = parseDependency,
	matchConstraints = matchConstraints,
	matchDependency = matchDependency,
}
