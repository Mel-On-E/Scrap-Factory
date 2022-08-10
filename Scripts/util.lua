---@diagnostic disable: lowercase-global

--TODO fix duplication in format methods

function format_money(params)
    if not params.color then
        params.color = "#00dd00"
    end

    local suffixes = {}
    local funnyLetters = {"k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No"}
    for k, letter in ipairs(funnyLetters) do
        suffixes[k*3] = letter
    end

    moneyStr = tostring(math.floor(params.money))
    local length = #moneyStr
    local suffix = ""

    if length < 3 then
        return string.format(params.color .. "$%.2f", params.money)
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
    return params.color .. "$" .. leadingDigits .. separator .. followingDigits .. suffix
end

function format_energy(params)
    if not params.color then
        params.color = "#dddd00"
    end
    if not params.unit then
        params.unit = "W"
    end

    local suffixes = {}
    local funnyLetters = {"k", "M", "G", "T", "P", "E", "Z", "Y"}
    for k, letter in ipairs(funnyLetters) do
        suffixes[k*3] = letter
    end

    powerStr = tostring(math.floor(params.power))
    local length = #powerStr
    local suffix = ""

    if length < 3 then
        return string.format(params.color .. params.power .. params.unit)
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
    return params.color .. leadingDigits .. separator .. followingDigits .. suffix .. params.unit
end

function change_power(power)
    g_power = g_power + power
    return g_powerStored + g_power > 0
end

function change_power_storage(capactiy)
    g_powerLimit = g_powerLimit + capactiy
    if g_powerLimit < 0 then
        sm.gui.chatMessage("#ff0000IF YOU ARE SEEING THIS PLS REPORT TO THE DEVS: POWERLIMIT < 0")
    end
end