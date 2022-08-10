---@diagnostic disable: lowercase-global
---@param money number
function format_money(money, color)
    if not color then
        color = "#00dd00"
    end

    local suffixes = {}
    local funnyLetters = {"k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No"}
    for k, letter in ipairs(funnyLetters) do
        suffixes[k*3] = letter
    end

    moneyStr = tostring(math.floor(money))
    local length = #moneyStr
    local suffix = ""

    if length < 3 then
        return string.format(color .. "$%.2f", money)
    end

    for len, suf in pairs(suffixes) do
        if length > len then
            suffix = suf
        else
            break
        end
    end

    local leadingDigits = string.sub(moneyStr, 1, length % 3)
    local followingDigits = string.sub(moneyStr, length % 3 + 1, 3)

    local separator = "."
    if #leadingDigits == 0 then
        separator = ""
    end
    return color .. "$" .. leadingDigits .. separator .. followingDigits .. suffix
end

function format_energy( power, color)
    if not color then
        color = "#dddd00"
    end

    local suffixes = {}
    local funnyLetters = {"k", "M", "G", "T", "P", "E", "Z", "Y"}
    for k, letter in ipairs(funnyLetters) do
        suffixes[k*3] = letter
    end

    powerStr = tostring(math.floor(power))
    local length = #powerStr
    local suffix = ""

    if length < 3 then
        return string.format(color .. power .. "Wh")
    end

    for len, suf in pairs(suffixes) do
        if length > len then
            suffix = suf
        else
            break
        end
    end

    local leadingDigits = string.sub(powerStr, 1, length % 3)
    local followingDigits = string.sub(powerStr, length % 3 + 1, 3)

    local separator = "."
    if #leadingDigits == 0 then
        separator = ""
    end
    return color .. leadingDigits .. separator .. followingDigits .. suffix .. "W"
end

function consume_power(power)
    if g_power >= power then
        g_power = g_power - power
        return true
    else
        g_power = 0
        return false
    end
end