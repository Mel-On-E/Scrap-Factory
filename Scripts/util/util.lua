---@diagnostic disable: lowercase-global

local numeralPrefixes = {"", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No"}
local metricPrefixes = {"", "k", "M", "G", "T", "P", "E", "Z", "Y"}

local function format_number(value, suffixes)
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

function format_money(params)
    if not params.color then
        params.color = "#00dd00"
    end

    return params.color .. "$" .. format_number(params.money, numeralPrefixes)
end

function format_energy(params)
    if not params.color then
        params.color = "#dddd00"
    end
    if not params.unit then
        params.unit = "W"
    end

    return params.color .. format_number(params.power, metricPrefixes) .. params.unit
end