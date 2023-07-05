dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/Generators/Solar.lua")

---A type of `Generator` that produces power only during night time
---@class Lunar : Generator
Lunar = class(Generator)

--------------------
-- #region Server
--------------------

function Lunar:sv_getPower()
    return self.data.power - Solar.sv_getPower(self)
end

-- #endregion
