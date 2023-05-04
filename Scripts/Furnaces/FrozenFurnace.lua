dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A FrozenFurnace sells drops set on fire for more
---@class FrozenFurnace : Furnace
FrozenFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function FrozenFurnace:sv_upgrade(shape)
    local publicData = shape.interactable.publicData

    if publicData.burnTime then
        publicData.value = publicData.value * self.data.burnMultiplier
    else
        publicData.value = publicData.value * self.data.multiplier
    end

    return publicData.value
end

-- #endregion
