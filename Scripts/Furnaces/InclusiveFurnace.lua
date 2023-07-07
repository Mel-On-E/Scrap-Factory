dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A InclusiveFurnace sells every drop multplied by how many different drops were sold before
---@class InclusiveFurnace : Furnace
---@field sv InclusiveFurnaceSv
InclusiveFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function InclusiveFurnace:server_onCreate()
    Furnace.server_onCreate(self)

    self.sv.dropsSold = {}
end

function InclusiveFurnace:sv_upgrade(shape)
    local uuid = tostring(shape.uuid)
    if self.sv.dropsSold[uuid] then
        self.sv.dropsSold = {}
    end
    self.sv.dropsSold[uuid] = true

    local value = shape.interactable.publicData.value

    local multiplier = 0
    for _,_ in pairs(self.sv.dropsSold) do
        multiplier = multiplier + 1
    end

    return value * multiplier
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class InclusiveFurnaceSv : FurnaceSv
---@field dropsSold table<string, boolean> list of drops that have been sold before

-- #endregion
