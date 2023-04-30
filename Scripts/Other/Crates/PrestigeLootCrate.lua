dofile("$CONTENT_DATA/Scripts/Other/Crates/LootCrate.lua")

---A PrestigeLootCrate contains special prestige items that can only be obtained this way.
---@class PrestigeLootCrate : LootCrate
---@field cl PrestigeLootCrateCl
PrestigeLootCrate = class(LootCrate)

--------------------
-- #region Client
--------------------

function PrestigeLootCrate:client_onCreate()
    LootCrate.client_onCreate(self)

    --create worldIcon
    self.cl.iconGui = sm.gui.createWorldIconGui(32, 32, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false)
    self.cl.iconGui:setImage("Icon", "gui_icon_popup_alert.png")
    self.cl.iconGui:setHost(self.shape, nil)
    self.cl.iconGui:setRequireLineOfSight(false)
    self.cl.iconGui:open()
end

function PrestigeLootCrate:client_onDestroy()
    self.cl.iconGui:destroy()
end

-- #endregion

--------------------
-- #region LootTable
--------------------

function PrestigeLootCrate:get_loot_table()
    local tier = ResearchManager.cl_getCurrentTier()
    local itemPool = {}
    for uuid, item in pairs(g_shop) do
        --exclude non-prestige items
        if not item.prestige then goto nextItem end

        --include items up to current tier
        if item.tier >= tier then goto nextItem end

        --items that are cheaper than lastPrestigeGain
        if item.price > PrestigeManager.cl_e_getLastPrestigeGain() then goto nextItem end


        itemPool[#itemPool + 1] = sm.uuid.new(uuid)
        ::nextItem::
    end

    return itemPool
end

-- #endregion

--------------------
-- #region LootTable
--------------------

---@class PrestigeLootCrateCl : LootCrateCl
---@field iconGui GuiInterface worldIcon that makes the crate extra special

-- #endregion
