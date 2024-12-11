dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A MultiFurnace sells drops depending on how many drops are sold at once
---@class MultiFurnace : Furnace
---@field sv MultiFurnaceSv
MultiFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function MultiFurnace:server_onCreate()
    Furnace.server_onCreate(self, {})

    self.sv.multiUpgrader = 0
end

function MultiFurnace:sv_onEnter(_, results)
    if not self.powerUtil.active then return end

    local drops = getDrops(results)
    self.sv.multiUpgrader = #drops

    for _, drop in ipairs(drops) do
        self:sv_onEnterDrop(drop)
    end
end

function MultiFurnace:sv_upgrade(shape)
    return shape.interactable.publicData.value * self.sv.multiUpgrader
end

-- #endregion

--------------------
-- #region Typings
--------------------

---@class MultiFurnaceSv : FurnaceSv
---@field multiUpgrader integer multiplier to be applied onto all drops when sold at the same time

-- #endregion
