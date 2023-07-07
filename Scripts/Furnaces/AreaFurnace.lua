dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---An AreaFurnace sells drops within an Area randomly.
---@class AreaFurnace : Furnace
AreaFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function AreaFurnace:sv_onEnter() end

function AreaFurnace:sv_onStay(_, results)
    if not self.powerUtil.active then return end

	for _, drop in ipairs(getDrops(results)) do
        if math.random() < self.data.sellChance then
		    self:sv_onEnterDrop(drop)
        end
	end
end

-- #endregion
