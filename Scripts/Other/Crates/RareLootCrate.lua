dofile("$CONTENT_DATA/Scripts/Other/Crates/LootCrate.lua")

---A RareLootCrate can contain special and more valueable items than a `LootCrate`.
---@class RareLootCrate : LootCrate
RareLootCrate = class(LootCrate)

--------------------
-- #region LootTable
--------------------

function RareLootCrate:get_loot_table()
    local tier = ResearchManager.cl_getCurrentTier()
    local itemPool = {}
    for uuid, item in pairs(g_shop) do
        --25% chance to include items of a higher research tier
        if (item.tier < tier) or
            (item.tier == tier and math.random() > 0.75) then
            --items that are cheaper than 2*money earned + 5000
            if item.price <= MoneyManager.cl_moneyEarned() * 2 + 5000 then
                itemPool[#itemPool + 1] = { price = item.price, uuid = uuid }
            end
        end
    end

    --only keep the 5 most expensive items
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

    return sortedPool
end

-- #endregion
