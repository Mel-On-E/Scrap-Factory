dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A TimeFurnace sells drops depending on how long they have existed
---@class TimeFurnace : Furnace
TimeFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function TimeFurnace:sv_upgrade(shape)
    local publicData = shape.interactable.publicData

    local multiplier = 0
    for _, upgrade in ipairs(self.data.upgradeTimes) do
        if sm.game.getCurrentTick() - publicData.creationTime >= upgrade.time then
            multiplier = upgrade.multiplier
        end
    end

    return publicData.value * multiplier
end

-- #endregion
