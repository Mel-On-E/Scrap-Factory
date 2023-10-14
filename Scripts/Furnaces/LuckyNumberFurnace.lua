dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A LuckyNumberFurnace sells every x-th drop with a special multiplier
---@class LuckyNumberFurnace : Furnace
---@field sv LuckyNumberFurnaceSv
LuckyNumberFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function LuckyNumberFurnace:server_onCreate()
    Furnace.server_onCreate(self, {})

    self.sv.dropCount = 0
end

function LuckyNumberFurnace:sv_upgrade(shape)
    self.sv.dropCount = self.sv.dropCount + 1
    local value = shape.interactable.publicData.value

    if self.sv.dropCount > 1 and self.sv.dropCount % self.data.luckyNumber == 0 then
        value = value * self.data.luckyMultiplier
    else
        value = value * self.data.multiplier
    end

    return value
end

-- #endregion

--------------------
-- #region Server
--------------------

---@class LuckyNumberFurnaceSv : FurnaceSv
---@field dropCount integer how many drops the furnace sold so far

-- #endregion
