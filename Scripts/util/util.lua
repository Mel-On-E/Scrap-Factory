---@diagnostic disable: lowercase-global

local numeralPrefixes = {"", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No"}
local metricPrefixes = {"", "k", "M", "G", "T", "P", "E", "Z", "Y"}

local function number_suffix(value, suffixes)
    local scientific = string.format("%.2e", value)
    local negate, roundedNumber, digits = string.match(scientific, "(-?)(%d%.%d+)e([+-]%d+)")
    roundedNumber = tonumber(roundedNumber)
    digits = tonumber(digits)

    local orderOfMagnitude = digits % 3
    local suffixIndex = (digits - orderOfMagnitude ) / 3 + 1

    if suffixIndex < 1 then
        return string.format("%.2f", value)
    else 
        local suffix = suffixes[suffixIndex]
        if suffix then
            local format = "%s%." .. 2 - orderOfMagnitude .. "f%s"
            return string.format(format, negate, roundedNumber * 10^orderOfMagnitude, suffix)
        else  -- Format if suffix does not exist (3 digits scientific).
            return scientific:gsub("+", "")
        end
    end
end

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
        params.prefix = "+ "
        params.unit = params.unit or " ◊"
    end

    return params.color .. (params.prefix or "") .. number_suffix(params.value, (params.prefixes or metricPrefixes)) .. (params.unit or "")
end