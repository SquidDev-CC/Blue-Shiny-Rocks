--[[
The MIT License (MIT)

Copyright (c) 2013 Daurnimator

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local strformat = string.format
local floor = math.floor
local function idiv(n, d)  return floor(n / d) end

local mon_lengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
-- Number of days in year until start of month; not corrected for leap years
local months_to_days_cumulative = { 0 }
for i = 2, 12 do
	months_to_days_cumulative [ i ] = months_to_days_cumulative [ i-1 ] + mon_lengths [ i-1 ]
end
-- For Sakamoto's Algorithm (day of week)
local sakamoto = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};

local function is_leap ( y )
	if (y % 4) ~= 0 then
		return false
	elseif (y % 100) ~= 0 then
		return true
	else
		return (y % 400) == 0
	end
end

local function year_length ( y )
	return is_leap ( y ) and 366 or 365
end

local function month_length ( m, y )
	if m == 2 then
		return is_leap ( y ) and 29 or 28
	else
		return mon_lengths [ m ]
	end
end

local function leap_years_since ( year )
	return idiv ( year, 4 ) - idiv ( year, 100 ) + idiv ( year, 400 )
end

local function day_of_year ( day, month, year )
	local yday = months_to_days_cumulative [ month ]
	if month > 2 and is_leap ( year ) then
		yday = yday + 1
	end
	return yday + day
end

local function day_of_week ( day, month, year )
	if month < 3 then
		year = year - 1
	end
	return ( year + leap_years_since ( year ) + sakamoto[month] + day ) % 7 + 1
end

local function borrow ( tens, units, base )
	local frac = tens % 1
	units = units + frac * base
	tens = tens - frac
	return tens, units
end

local function carry ( tens, units, base )
	if units >= base then
		tens  = tens + idiv ( units, base )
		units = units % base
	elseif units < 0 then
		tens  = tens - 1 + idiv ( -units, base )
		units = base - ( -units % base )
	end
	return tens, units
end

-- Modify parameters so they all fit within the "normal" range
local function normalise ( year, month, day, hour, min, sec )
	-- `month` and `day` start from 1, need -1 and +1 so it works modulo
	month, day = month - 1, day - 1

	-- Convert everything (except seconds) to an integer
	-- by propagating fractional components down.
	year,  month = borrow ( year,  month, 12 )
	-- Carry from month to year first, so we get month length correct in next line around leap years
	year,  month = carry ( year, month, 12 )
	month, day   = borrow ( month, day,   month_length ( floor ( month + 1 ), year ) )
	day,   hour  = borrow ( day,   hour,  24 )
	hour,  min   = borrow ( hour,  min,   60 )
	min,   sec   = borrow ( min,   sec,   60 )

	-- Propagate out of range values up
	-- e.g. if `min` is 70, `hour` increments by 1 and `min` becomes 10
	-- This has to happen for all columns after borrowing, as lower radixes may be pushed out of range
	min,   sec   = carry ( min,   sec,   60 ) -- TODO: consider leap seconds?
	hour,  min   = carry ( hour,  min,   60 )
	day,   hour  = carry ( day,   hour,  24 )
	-- Ensure `day` is not underflowed
	-- Add a whole year of days at a time, this is later resolved by adding months
	-- TODO[OPTIMIZE]: This could be slow if `day` is far out of range
	while day < 0 do
		year = year - 1
		day  = day + year_length ( year )
	end
	year, month = carry ( year, month, 12 )

	-- TODO[OPTIMIZE]: This could potentially be slow if `day` is very large
	while true do
		local i = month_length (month + 1, year)
		if day < i then break end
		day = day - i
		month = month + 1
		if month >= 12 then
			month = 0
			year = year + 1
		end
	end

	-- Now we can place `day` and `month` back in their normal ranges
	-- e.g. month as 1-12 instead of 0-11
	month, day = month + 1, day + 1

	return year, month, day, hour, min, sec
end

local function create(ts)
	local year, month, day, hour, min, sec = normalise (1970, 1, 1, 0 , 0, ts)

	return {
		day = day,
		month = month,
		year = year,
		hour = hour,
		min = min,
		sec = sec,
		yday  = day_of_year ( day , month , year ),
		wday  = day_of_week ( day , month , year )
	}
end

local leap_years_since_1970 = leap_years_since ( 1970 )

local function timestamp(year, month, day, hour, min, sec )
	year, month, day, hour, min, sec = normalise(year, month, day, hour, min, sec)

	local days_since_epoch = day_of_year ( day, month, year )
		+ 365 * ( year - 1970 )
		-- Each leap year adds one day
		+ ( leap_years_since ( year - 1 ) - leap_years_since_1970 ) - 1

	return days_since_epoch * (60*60*24)
		+ hour  * (60*60)
		+ min   * 60
		+ sec
end

local function timestampTbl(tbl)
	return timestamp(tbl.year, tbl.month, tbl.day, tbl.hour or 0, tbl.min or 0, tbl.sec or 0)
end

local c_locale = {
	abday = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" } ;
	day = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" } ;
	abmon = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" } ;
	mon = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" } ;
	am_pm = { "AM", "PM" } ;
}

--- ISO-8601 week logic
-- ISO 8601 weekday as number with Monday as 1 (1-7)
local function iso_8601_weekday ( wday )
	if wday == 1 then
		return 7
	else
		return wday - 1
	end
end
local iso_8601_week do
	-- Years that have 53 weeks according to ISO-8601
	local long_years = { }
	for _, v in ipairs {
		  4,   9,  15,  20,  26,  32,  37,  43,  48,  54,  60,  65,  71,  76,  82,
		 88,  93,  99, 105, 111, 116, 122, 128, 133, 139, 144, 150, 156, 161, 167,
		172, 178, 184, 189, 195, 201, 207, 212, 218, 224, 229, 235, 240, 246, 252,
		257, 263, 268, 274, 280, 285, 291, 296, 303, 308, 314, 320, 325, 331, 336,
		342, 348, 353, 359, 364, 370, 376, 381, 387, 392, 398
	} do
		long_years [ v ] = true
	end
	local function is_long_year ( year )
		return long_years [ year % 400 ]
	end
	function iso_8601_week ( self )
		local wday = iso_8601_weekday ( self.wday )
		local n = self.yday - wday
		local year = self.year
		if n < -3 then
			year = year - 1
			if is_long_year ( year ) then
				return year, 53, wday
			else
				return year, 52, wday
			end
		elseif n >= 361 and not is_long_year ( year ) then
			return year + 1, 1, wday
		else
			return year, idiv ( n + 10, 7 ), wday
		end
	end
end

--- Specifiers
local t = { }
function t:a ( locale )
	return "%s", locale.abday [ self.wday ]
end
function t:A ( locale )
	return "%s", locale.day [ self.wday ]
end
function t:b ( locale )
	return "%s", locale.abmon [ self.month ]
end
function t:B ( locale )
	return "%s", locale.mon [ self.month ]
end
function t:c ( locale )
	return "%.3s %.3s%3d %.2d:%.2d:%.2d %d",
		locale.abday [ self.wday ], locale.abmon [ self.month ],
		self.day, self.hour, self.min, self.sec, self.year
end
-- Century
function t:C ( )
	return "%02d", idiv ( self.year, 100 )
end
function t:d ( )
	return "%02d", self.day
end
-- Short MM/DD/YY date, equivalent to %m/%d/%y
function t:D ( )
	return "%02d/%02d/%02d", self.month, self.day, self.year % 100
end
function t:e ( )
	return "%2d", self.day
end
-- Short YYYY-MM-DD date, equivalent to %Y-%m-%d
function t:F ( )
	return "%d-%02d-%02d", self.year, self.month, self.day
end
-- Week-based year, last two digits (00-99)
function t:g ( )
	return "%02d", iso_8601_week ( self ) % 100
end
-- Week-based year
function t:G ( )
	return "%d", iso_8601_week ( self )
end
t.h = t.b
function t:H ( )
	return "%02d", self.hour
end
function t:I ( )
	return "%02d", (self.hour-1) % 12 + 1
end
function t:j ( )
	return "%03d", self.yday
end
function t:m ( )
	return "%02d", self.month
end
function t:M ( )
	return "%02d", self.min
end
-- New-line character ('\n')
function t:n ( ) -- luacheck: ignore 212
	return "\n"
end
function t:p ( locale )
	return self.hour < 12 and locale.am_pm[1] or locale.am_pm[2]
end
-- TODO: should respect locale
function t:r ( locale )
	return "%02d:%02d:%02d %s",
		(self.hour-1) % 12 + 1, self.min, self.sec,
		self.hour < 12 and locale.am_pm[1] or locale.am_pm[2]
end
-- 24-hour HH:MM time, equivalent to %H:%M
function t:R ( )
	return "%02d:%02d", self.hour, self.min
end
function t:s ( )
	return "%d", timestamp(self)
end
function t:S ( )
	return "%02d", self.sec
end
-- Horizontal-tab character ('\t')
function t:t ( ) -- luacheck: ignore 212
	return "\t"
end
-- ISO 8601 time format (HH:MM:SS), equivalent to %H:%M:%S
function t:T ( )
	return "%02d:%02d:%02d", self.hour, self.min, self.sec
end
function t:u ( )
	return "%d", iso_8601_weekday ( self.wday )
end
-- Week number with the first Sunday as the first day of week one (00-53)
function t:U ( )
	return "%02d", idiv ( self.yday - self.wday + 7, 7 )
end
-- ISO 8601 week number (00-53)
function t:V ( )
	return "%02d", select ( 2, iso_8601_week ( self ) )
end
-- Weekday as a decimal number with Sunday as 0 (0-6)
function t:w ( )
	return "%d", self.wday - 1
end
-- Week number with the first Monday as the first day of week one (00-53)
function t:W ( )
	return "%02d", idiv ( self.yday - iso_8601_weekday ( self.wday ) + 7, 7 )
end
-- TODO make t.x and t.X respect locale
t.x = t.D
t.X = t.T
function t:y ( )
	return "%02d", self.year % 100
end
function t:Y ( )
	return "%d", self.year
end
-- TODO timezones
function t:z ( ) -- luacheck: ignore 212
	return "+0000"
end
function t:Z ( ) -- luacheck: ignore 212
	return "GMT"
end
-- A literal '%' character.
t["%"] = function ( self ) -- luacheck: ignore 212
	return "%%"
end

local function strftime ( format_string, timetable )
	return ( string.gsub ( format_string, "%%([EO]?)(.)", function ( locale_modifier, specifier )
		local func = t [ specifier ]
		if func then
			return strformat ( func ( timetable, c_locale ) )
		else
			error ( "invalid conversation specifier '%"..locale_modifier..specifier.."'", 3 )
		end
	end ) )
end

local function asctime ( timetable )
	-- Equivalent to the format string "%c\n"
	return strformat ( t.c ( timetable, c_locale ) )
end

return {
	create = create,
	timestamp = timestampTbl,
	strftime = strftime,
	asctime = asctime,
}
