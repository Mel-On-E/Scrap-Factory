---@diagnostic disable: lowercase-global

local numeralPrefixes = { "", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No" }
local metricPrefixes = { "", "k", "M", "G", "T", "P", "E", "Z", "Y" }

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

---@param params FNParams
function format_number(params)
    if params.format == "money" then
        params.color = params.color or "#00dd00"
        params.prefix = "$"
        params.prefixes = numeralPrefixes

    elseif params.format == "energy" then
        params.color = params.color or "#dddd00"
        params.unit = params.unit or "W"

    elseif params.format == "pollution" then
        params.color = params.color or "#bb00dd"
        params.unit = params.unit or " CO₂"

    elseif params.format == "prestige" then
        params.color = params.color or "#dd6e00"
        params.unit = params.unit or " ◊"
    end

    return params.color ..
        (params.prefix or "") .. number_suffix(params.value, (params.prefixes or metricPrefixes)) .. (params.unit or "")
end

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

---@param x table
function array_reverse(x)
    local n, m = #x, #x / 2
    for i = 1, m do
        x[i], x[n - i + 1] = x[n - i + 1], x[i]
    end
    return x
end

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

--------------------
--Types
--------------------

---@class FNParams
---@field format "energy" | "pollution" | "prestige" | "money"
---@field color string A hex color (#rrggbb) that will be the text color
---@field unit string The symbol after the number
---@field prefixes string[] The suffixes of the numbers changing every x % 1000 == 0 example { "", "k", "M", "G", "T", "P", "E", "Z", "Y" }
---@field value number The number to format
