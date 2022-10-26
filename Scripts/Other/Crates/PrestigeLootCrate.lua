dofile("$CONTENT_DATA/Scripts/Other/Crates/LootCrate.lua")

---@class PrestigeLootCrate : LootCrate
PrestigeLootCrate = class(LootCrate)

function PrestigeLootCrate:client_onCreate()
    LootCrate.client_onCreate(self)
    
    self.cl = {}
    self.cl.iconGui = sm.gui.createWorldIconGui( 32, 32, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
	self.cl.iconGui:setImage( "Icon", "gui_icon_popup_alert.png" )
	self.cl.iconGui:setHost( self.shape )
	self.cl.iconGui:setRequireLineOfSight( false )
	self.cl.iconGui:open()
end

function PrestigeLootCrate:client_onDestroy()
    self.cl.iconGui:destroy()
end

function PrestigeLootCrate:get_loot_table()
    local prestigeGain = PrestigeManager.cl_e_getLastPrestigeGain()
    print("Generating prestige loot table for: " .. prestigeGain .. " prestige")
    local workInProgress = {}

    workInProgress[#workInProgress+1] = obj_lootcrate --TEST

    return workInProgress
end
