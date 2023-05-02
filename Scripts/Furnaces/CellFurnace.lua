dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A CellFurnace sells unupgraded drops for a lot
---@class CellFurnace : Furnace
CellFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function CellFurnace:sv_upgrade(shape)
    local publicData = shape.interactable.publicData

    print(publicData.upgrades)

    if not next(publicData.upgrades) then
        publicData.value = publicData.value * self.data.cellMultiplier
    else
        publicData.value = publicData.value * self.data.multiplier
    end

    return publicData.value
end

-- #endregion
