dofile("$CONTENT_DATA/Scripts/Droppers/Dropper.lua")

---An AutoDropper automatically creates a `Drop` between a specified interval.
---@class AutoDropper : Dropper
---@field sv AutoDropperSv
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
AutoDropper = class(Dropper)
AutoDropper.maxParentCount = 1
AutoDropper.maxChildCount = 0
AutoDropper.connectionInput = sm.interactable.connectionType.logic
AutoDropper.connectionOutput = sm.interactable.connectionType.none
AutoDropper.colorNormal = sm.color.new(0x00dd6fff)
AutoDropper.colorHighlight = sm.color.new(0x00ff80ff)

--------------------
-- #region Server
--------------------

function AutoDropper:server_onCreate()
    Dropper.server_onCreate(self)

    self.sv.prevActive = true
    self.sv.lastDropTick = sm.game.getCurrentTick()
end

function AutoDropper:server_onFixedUpdate()
    local parent = self.interactable:getSingleParent()
    local active = not parent or parent:isActive()

    if active and self.sv.lastDropTick + self.sv.data.interval < sm.game.getCurrentTick() then
        --create drop
        self:sv_consumePowerAndDrop()
        self.sv.lastDropTick = sm.game.getCurrentTick()
    end
end

-- #endregion

--------------------
-- #region Server
--------------------

---@class AutoDropperSv
---@field data AutoDropperData
---@field prevActive boolean
---@field lastDropTick number the last tick during which a drop should have been dropped

---@class AutoDropperData : DropperData
---@field interval number the number of ticks between each drop

-- #endregion
