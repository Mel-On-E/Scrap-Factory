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
        --exclude prestige items
        if item.prestige then goto nextItem end

        --25% chance to include items of a higher research tier
        if item.tier > tier or (item.tier == tier and math.random() <= 0.75) then
            goto nextItem
        end

        --items that are cheaper than 2*money earned + 5000
        if item.price > MoneyManager.cl_moneyEarned() * 2 + 5000 then goto nextItem end

        --50% chance to include non special items
        if not item.special and math.random() > 0.50 then goto nextItem end


        itemPool[#itemPool + 1] = sm.uuid.new(uuid)
        ::nextItem::
    end

    return itemPool
end

-- #endregion
