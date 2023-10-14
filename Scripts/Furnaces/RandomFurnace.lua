dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A RandomFurnace sells drops with a random multiplier
---@class RandomFurnace : Furnace
RandomFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function RandomFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value
    local multi = self.data.multiplierMin + math.random() * (self.data.multiplierMax - self.data.multiplierMin)

    return value * multi
end

-- #endregion
