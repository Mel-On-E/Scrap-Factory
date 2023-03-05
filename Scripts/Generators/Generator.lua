dofile("$CONTENT_DATA/Scripts/util/util.lua")

---A Generator produces power. Additionally it can also provide power storage capacity.
---@class Generator : ShapeClass
---@field data GeneratorData script data from the json file
---@field cl GeneratorCl
Generator = class(nil)

--------------------
-- #region Server
--------------------

function Generator:server_onCreate()
    if self.data.power then
        ---@diagnostic disable-next-line: assign-type-mismatch
        self.data.power = tonumber(self.data.power)
    end

    if self.data.powerLimit then
        ---@diagnostic disable-next-line: assign-type-mismatch
        self.data.powerLimit = tonumber(self.data.powerLimit)
        PowerManager.sv_changePowerLimit(self.data.powerLimit)
    end
end

function Generator:server_onDestroy()
    if self.data.powerLimit then
        PowerManager.sv_changePowerLimit(-self.data.powerLimit)
    end
end

function Generator:server_onFixedUpdate()
    if self.data.power and sm.game.getCurrentTick() % 40 == 0 then
        local power = self:sv_getPower()
        PowerManager.sv_changePower(power)
        self.network:setClientData({ power = tostring(power) })
    end
end

---How much power the Generator is producing currently
---@return number
function Generator:sv_getPower()
    return self.data.power
end

--#endregion

--------------------
-- #region Client
--------------------

function Generator:client_onCreate()
    self.cl = {}
    self.cl.power = 0
end

function Generator:client_onClientDataUpdate(data)
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.cl.power = tonumber(data.power)
end

function Generator:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    sm.gui.setInteractionText(language_tag("PowerOutput"),
        o1 .. format_number({ format = "energy", value = self.cl.power, color = "#4f4f4f" }) .. o2)
    return true
end

--#endregion

--------------------
-- #region Types
--------------------

---@class GeneratorSv
---@field data GeneratorData

---@class GeneratorData
---@field power number how much power is produced by default
---@field powerLimit number the power storage capacity of the Generator

---@class GeneratorCl
---@field power number current power output set by clientData

--#endregion
