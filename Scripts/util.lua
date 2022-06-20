function format_money(money)
    moneyStr = tostring(math.floor(money))
    local length = #moneyStr

    local suffix = ""
    if length > 30 then
        suffix = "No"
    elseif length > 27 then
        suffix = "Oc"
    elseif length > 24 then
        suffix = "Sp"
    elseif length > 21 then
        suffix = "Sx"
    elseif length > 18 then
        suffix = "Qn"
    elseif length > 15 then
        suffix = "Qd"
    elseif length > 12 then
        suffix = "T"
    elseif length > 9 then
        suffix = "B"
    elseif length > 6 then
        suffix = "M"
    elseif length > 3 then
        suffix = "k"
    else
        return string.format("#00dd00$%.2f", money)
    end

    local leadingDigits = string.sub(moneyStr, 1, length%3)
    local followingDigits = string.sub(moneyStr, length%3 + 1, 3)

    local separator = "."
    if #leadingDigits == 0 then
        separator = ""
    end
    return "#00dd00$" .. leadingDigits .. separator .. followingDigits .. suffix
end

function consume_power(power)
    if g_power > power then
        g_power = g_power - power
        return true
    else
        return false
    end
end