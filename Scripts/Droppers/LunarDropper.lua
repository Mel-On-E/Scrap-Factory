dofile("$CONTENT_DATA/Scripts/Droppers/AutoDropper.lua")

---A LunarDropper only spawns drops at night
---@class LunarDropper : AutoDropper
LunarDropper = class(AutoDropper)

--------------------
-- #region Server
--------------------

function LunarDropper:server_onFixedUpdate()
    local parent = self.interactable:getSingleParent()
    local active = not parent or parent:isActive()

    if active and not isDay() and self.sv.lastDropTick + self.sv.data.interval < sm.game.getCurrentTick() then
        --create drop
        self:sv_consumePowerAndDrop()
        self.sv.lastDropTick = sm.game.getCurrentTick()
    end
end

--------------------
-- #endregion
--------------------