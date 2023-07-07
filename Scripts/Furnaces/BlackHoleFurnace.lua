dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A BlackHoleFurnace randomly generates implosions, pulling drops towards it
---@class BlackHoleFurnace : Furnace
BlackHoleFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

local ImplosionChance = 0.025


function BlackHoleFurnace:server_onFixedUpdate(dt)
    Furnace.server_onFixedUpdate(self)

    if math.random() <= ImplosionChance then
        sm.physics.explode(self.shape.worldPosition, 0, 0, 20, -50, "PowerSocket - Activate")
    end
end

-- #endregion
