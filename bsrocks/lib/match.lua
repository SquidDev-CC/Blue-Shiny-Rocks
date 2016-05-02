--[[
* Diff Match and Patch
*
* Copyright 2006 Google Inc.
* http://code.google.com/p/google-diff-match-patch/
*
* Based on the JavaScript implementation by Neil Fraser.
* Ported to Lua by Duncan Cross.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*	 http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
--]]

local band, bor, lshift = bit32.band, bit32.bor, bit32.lshift
local error = error
local strsub, strbyte, strchar, gmatch, gsub = string.sub, string.byte, string.char, string.gmatch, string.gsub
local strmatch, strfind, strformat = string.match, string.find, string.format
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local max, min, floor, ceil, abs = math.max, math.min, math.floor, math.ceil, math.abs

local Match_Distance = 1000
local Match_Threshold = 0.3
local Match_MaxBits = 32

local function indexOf(a, b, start)
	if (#b == 0) then
		return nil
	end
	return strfind(a, b, start, true)
end

-- ---------------------------------------------------------------------------
--	MATCH API
-- ---------------------------------------------------------------------------

local _match_bitap, _match_alphabet

--[[
* Locate the best instance of 'pattern' in 'text' near 'loc'.
* @param {string} text The text to search.
* @param {string} pattern The pattern to search for.
* @param {number} loc The location to search around.
* @return {number} Best match index or -1.
--]]
local function match_main(text, pattern, loc)
	-- Check for null inputs.
	if text == nil or pattern == nil then error('Null inputs. (match_main)') end

	if text == pattern then
		-- Shortcut (potentially not guaranteed by the algorithm)
		return 1
	elseif #text == 0 then
		-- Nothing to match.
		return -1
	end
	loc = max(1, min(loc or 0, #text))
	if strsub(text, loc, loc + #pattern - 1) == pattern then
		-- Perfect match at the perfect spot!	(Includes case of null pattern)
		return loc
	else
		-- Do a fuzzy compare.
		return _match_bitap(text, pattern, loc)
	end
end

--[[
* Initialise the alphabet for the Bitap algorithm.
* @param {string} pattern The text to encode.
* @return {Object} Hash of character locations.
* @private
--]]
function _match_alphabet(pattern)
	local s = {}
	local i = 0
	for c in gmatch(pattern, '.') do
		s[c] = bor(s[c] or 0, lshift(1, #pattern - i - 1))
		i = i + 1
	end
	return s
end

--[[
* Locate the best instance of 'pattern' in 'text' near 'loc' using the
* Bitap algorithm.
* @param {string} text The text to search.
* @param {string} pattern The pattern to search for.
* @param {number} loc The location to search around.
* @return {number} Best match index or -1.
* @private
--]]
function _match_bitap(text, pattern, loc)
	if #pattern > Match_MaxBits then
		error('Pattern too long.')
	end

	-- Initialise the alphabet.
	local s = _match_alphabet(pattern)

	--[[
	* Compute and return the score for a match with e errors and x location.
	* Accesses loc and pattern through being a closure.
	* @param {number} e Number of errors in match.
	* @param {number} x Location of match.
	* @return {number} Overall score for match (0.0 = good, 1.0 = bad).
	* @private
	--]]
	local function _match_bitapScore(e, x)
		local accuracy = e / #pattern
		local proximity = abs(loc - x)
		if (Match_Distance == 0) then
			-- Dodge divide by zero error.
			return (proximity == 0) and 1 or accuracy
		end
		return accuracy + (proximity / Match_Distance)
	end

	-- Highest score beyond which we give up.
	local score_threshold = Match_Threshold
	-- Is there a nearby exact match? (speedup)
	local best_loc = indexOf(text, pattern, loc)
	if best_loc then
		score_threshold = min(_match_bitapScore(0, best_loc), score_threshold)
		-- LUANOTE: Ideally we'd also check from the other direction, but Lua
		-- doesn't have an efficent lastIndexOf function.
	end

	-- Initialise the bit arrays.
	local matchmask = lshift(1, #pattern - 1)
	best_loc = -1

	local bin_min, bin_mid
	local bin_max = #pattern + #text
	local last_rd
	for d = 0, #pattern - 1, 1 do
		-- Scan for the best match; each iteration allows for one more error.
		-- Run a binary search to determine how far from 'loc' we can stray at this
		-- error level.
		bin_min = 0
		bin_mid = bin_max
		while (bin_min < bin_mid) do
			if (_match_bitapScore(d, loc + bin_mid) <= score_threshold) then
				bin_min = bin_mid
			else
				bin_max = bin_mid
			end
			bin_mid = floor(bin_min + (bin_max - bin_min) / 2)
		end
		-- Use the result from this iteration as the maximum for the next.
		bin_max = bin_mid
		local start = max(1, loc - bin_mid + 1)
		local finish = min(loc + bin_mid, #text) + #pattern

		local rd = {}
		for j = start, finish do
			rd[j] = 0
		end
		rd[finish + 1] = lshift(1, d) - 1
		for j = finish, start, -1 do
			local charMatch = s[strsub(text, j - 1, j - 1)] or 0
			if (d == 0) then	-- First pass: exact match.
				rd[j] = band(bor((rd[j + 1] * 2), 1), charMatch)
			else
				-- Subsequent passes: fuzzy match.
				-- Functions instead of operators make this hella messy.
				rd[j] = bor(
					band(
						bor(
							lshift(rd[j + 1], 1),
							1
						),
						charMatch
					),
					bor(
						bor(
							lshift(bor(last_rd[j + 1], last_rd[j]), 1),
							1
						),
						last_rd[j + 1]
					)
				)
			end
			if (band(rd[j], matchmask) ~= 0) then
				local score = _match_bitapScore(d, j - 1)
				-- This match will almost certainly be better than any existing match.
				-- But check anyway.
				if (score <= score_threshold) then
					-- Told you so.
					score_threshold = score
					best_loc = j - 1
					if (best_loc > loc) then
						-- When passing loc, don't exceed our current distance from loc.
						start = max(1, loc * 2 - best_loc)
					else
						-- Already passed loc, downhill from here on in.
						break
					end
				end
			end
		end
		-- No hope for a (better) match at greater error levels.
		if (_match_bitapScore(d + 1, loc) > score_threshold) then
			break
		end
		last_rd = rd
	end
	return best_loc
end

return match_main
