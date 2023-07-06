dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A VelocityFurnace sells drops depending on how fast they are
---@class VelocityFurnace : Furnace
VelocityFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function VelocityFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value

    local multiplier = math.sqrt(shape.velocity:length())

    return value * multiplier
end

-- #endregion
