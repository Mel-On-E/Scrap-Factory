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
    --TODO: write lootTable generation code
    local prestigeGain = PrestigeManager.cl_e_getLastPrestigeGain()
    print("Generating prestige loot table for: " .. prestigeGain .. " prestige")
    local workInProgress = {}

    --TEST: only contains a normal lootcrate
    workInProgress[#workInProgress + 1] = obj_lootcrate

    return workInProgress
end

-- #endregion

--------------------
-- #region LootTable
--------------------

---@class PrestigeLootCrateCl : LootCrateCl
---@field iconGui GuiInterface worldIcon that makes the crate extra special

-- #endregion
