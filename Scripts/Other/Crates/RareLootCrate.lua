dofile("$CONTENT_DATA/Scripts/Other/Crates/LootCrate.lua")

---@class RareLootCrate : LootCrate
RareLootCrate = class(LootCrate)

function RareLootCrate:get_loot_table()
    local tier = ResearchManager.cl_getCurrentTier()
    local itemPool = {}
    for uuid, item in pairs(g_shop) do
        if (item.tier < tier) or
            (item.tier == tier and math.random()) > 0.75 then
            if item.price <= MoneyManager.cl_moneyEarned() * 2 + 5000 then
                itemPool[#itemPool + 1] = { price = item.price, uuid = uuid }
            end
        end
    end

    local sortedPool = {}
    while #itemPool > 1 and #sortedPool < 5 do
        local mostExpensiveItem
        local highestPrice = 0

        for k, item in ipairs(itemPool) do
            if item.price > highestPrice then
                highestPrice = item.price
                mostExpensiveItem = k
            end
        end

        sortedPool[#sortedPool + 1] = sm.uuid.new(itemPool[mostExpensiveItem].uuid)
        table.remove(itemPool, mostExpensiveItem)
    end

    sortedPool[#sortedPool + 1] = sm.uuid.new("f08d772f-9851-400f-a014-d847900458a7")

    return sortedPool
end
