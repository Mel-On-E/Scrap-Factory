dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A CellFurnace sells unupgraded drops for a lot
---@class CellFurnace : Furnace
CellFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function CellFurnace:sv_upgrade(shape)
    local publicData = shape.interactable.publicData

    if not next(publicData.upgrades) then
        if self.data.cellMultiplier then
            publicData.value = publicData.value * self.data.cellMultiplier
        end

        if self.data.cellExponent then
            publicData.value = publicData.value ^ self.data.cellExponent
        end
    else
        publicData.value = publicData.value * self.data.multiplier
    end

    return publicData.value
end

-- #endregion
