dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A CompoundingFurnace sells drops based on how many upgrade types they have
---@class CompoundingFurnace : Furnace
CompoundingFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function CompoundingFurnace:sv_upgrade(shape)
    local publicData = shape.interactable.publicData

    local multiplier = 0
    for key, value in pairs(publicData.upgrades) do
        multiplier = multiplier + 1
    end

    return publicData.value * multiplier
end

-- #endregion
