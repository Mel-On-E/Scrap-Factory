---@diagnostic disable: lowercase-global

--------------------
-- #region Daytime
--------------------

SUNRISE_START = 0.16
SUNRISE_END = 0.24
SUNSET_START = 0.76
SUNSET_END = 0.84

---Check if it's currently daytime
---@return boolean day true during daytime
function isDay()
    local time = sm.game.getTimeOfDay()
    return time > SUNRISE_END and time < SUNSET_START
end

---Check if it's currently sunrise
---@return boolean sunrise true during sunrise
function isSunrise()
    local time = sm.game.getTimeOfDay()
    return time > SUNRISE_START and time < SUNRISE_END
end

---Check if it's currently sunset
---@return boolean sunrise true during sunset
function isSunset()
    local time = sm.game.getTimeOfDay()
    return time > SUNSET_START and time < SUNSET_END
end

-- #endregion

--------------------
-- #region NetworkData
--------------------

---packs data for network usage by converting all numbers to string if possible
---@param data table network data to pack
---@return table data packed network data
function packNetworkData(data)
    local function packData(t)
        local newTable = {}
        for k, v in pairs(t) do
            if type(v) == "number" then
                v = tostring(v)
            elseif type(v) == "table" then
                v = packData(v)
            end

            newTable[k] = v
        end
        return newTable
    end

    return data and packData(data) or nil
end

---unpacks data from network usage by converting all strings to numbers if possible
---@param data table network data to unpack
---@return table data unpacked network data
function unpackNetworkData(data)
    local function unpackData(t)
        local newTable = {}
        for k, v in pairs(t) do
            if type(v) == "string" then
                v = tonumber(v) or v
            elseif type(v) == "table" then
                v = unpackData(v)
            end

            newTable[k] = v
        end
        return newTable
    end

    return data and unpackData(data) or nil
end

-- #endregion

--------------------
-- #region Formatting
--------------------

---@class FormatNumberParams
---@field format "power" | "pollution" | "prestige" | "money" standard formatting options
---@field color string A hex color (#rrggbb) that will be the text color
---@field unit string The symbol after the number (postfix)
---@field suffixes string[] The suffixes of the numbers for each 3 orders of magnitude
---@field value number The number to format

---Formats a number value to a nice string for fancy display e.g. `"#00dd00$1.69k"`
---@param params FormatNumberParams
---@return string text the formatted number
function format_number(params)
    local numeralSuffixes = { "", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No" }
    local metricSuffixes = { "", "k", "M", "G", "T", "P", "E", "Z", "Y" }

    if params.format == "money" then
        params.color = params.color or "#00dd00"
        params.prefix = "$"
        params.suffixes = numeralSuffixes
    elseif params.format == "power" then
        params.color = params.color or "#dddd00"
        params.unit = params.unit or "W"
    elseif params.format == "pollution" then
        params.color = params.color or "#bb00dd"
        params.unit = params.unit or " CO₂"
    elseif params.format == "prestige" then
        params.color = params.color or "#dd6e00"
        params.unit = params.unit or " ◊"
    end

    local function number_suffix(value, suffixes)
        -- shamelessly stolen from: BlueFlame
        local scientific = string.format("%.16e", value)
        local negate, truncatedNumber, digits = string.match(scientific, "(-?)(%d.%d%d)%d*e([+-]%d+)")
        truncatedNumber = tonumber(truncatedNumber)
        digits = tonumber(digits)

        local orderOfMagnitude = digits % 3
        local suffixIndex = (digits - orderOfMagnitude) / 3 + 1

        if suffixIndex < 1 then
            return string.match(string.format("%.16f", value), "(%d.%d%d)%d*")
        else
            local suffix = suffixes[suffixIndex]
            if suffix then
                local format = "%s%." .. 2 - orderOfMagnitude .. "f%s"
                return string.format(format, negate, truncatedNumber * 10 ^ orderOfMagnitude, suffix)
            else -- Format if suffix does not exist (3 digits scientific).
                scientific = string.format("%.2e", value)
                return scientific:gsub("+", "")
            end
        end
    end

    return params.color ..
        (params.prefix or "") .. number_suffix(params.value, (params.suffixes or metricSuffixes)) .. (params.unit or "")
end

-- #endregion

--------------------
-- #region Utility Functions
--------------------

---Example usage
---```lua
---for case = 1,4 do
---  switch(case) {
---    [1] = function() print("one") end,
---    [2] = print,
---    default = function(x) print("default",x) end,
---  }
---end
---```
function switch(case)
    return function(codetable)
        local f
        f = codetable[case] or codetable.default
        if f then
            if type(f) == "function" then
                return f(case)
            else
                error("case " .. tostring(case) .. " not a function")
            end
        end
    end
end

---Reverses an array table
---@param arr table The array table to be reversed
---@return table arr The reversed array table
function array_reverse(arr)
    local length = #arr
    local midpoint = length / 2
    for i = 1, midpoint do
        arr[i], arr[length - i + 1] = arr[length - i + 1], arr[i]
    end
    return arr
end

---create a deep copy of a table
---@param t table table to be copied
---@return table copied table
function table.copy(t)
    local t2 = {};
    for k, v in pairs(t) do
        if type(v) == "table" then
            t2[k] = table.copy(v);
        else
            t2[k] = v;
        end
    end
    return t2;
end

---check wheter a table `t` contains element `e`
---@param t table the table to search
---@param e any the element to search for
---@return boolean
function table.contains(t, e)
    for _, e2 in pairs(t) do
        if e == e2 then
            return true
        end
    end

    return false
end

---returns the angle between two vectors in radians
---@param v1 Vec3
---@param v2 Vec3
function angle(v1, v2)
    local dot = v1:dot(v2)
    local cos = dot / (v1:length() * v2:length())
    acos = math.acos(cos)
    return acos > 1e-3 and acos or 0
end

-- #endregion
