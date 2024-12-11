dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A NuclearFurnace sells radioactive drops for more
---@class NuclearFurnace : Furnace
NuclearFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function NuclearFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value
    local scripted = g_drops[tostring(shape.uuid)].scripted

    if scripted.data and scripted.data.halfLife then
        value = value * self.data.nuclearMultiplier
    else
        value = value * self.data.multiplier
    end

    return value
end

-- #endregion
