dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---@class ValueDetector : Upgrader
---@field cl ValueDetectorCl
---@field sv ValueDetectorSv
---@diagnostic disable-next-line: param-type-mismatch
ValueDetector = class(Upgrader)

ValueDetector.connectionInput = sm.interactable.connectionType.logic
ValueDetector.connectionOutput = sm.interactable.connectionType.logic
ValueDetector.maxParentCount = 1
ValueDetector.maxChildCount = -1
ValueDetector.colorNormal = sm.color.new("#8fe625")
ValueDetector.colorHighlight = sm.color.new("#96f522")

--------------------
-- #region Server
--------------------

function ValueDetector:server_onCreate()
    Upgrader.server_onCreate(self)

    self.sv = self.sv or {}
    self.sv.lastButtonTick = false
    self.sv.options = self.storage:load()
    if not self.sv.options then
        self.sv.options = {
            mode = 'greater',
            value = 1,
            outputMode = 'switch'
        }
    end
    self.network:setClientData(self.sv.options)
end

function ValueDetector:sv_onUpgrade(shape, data)
    local active = false
    if self.sv.options.mode == 'lesser' then
        active = data.value < self.sv.options.value
    elseif self.sv.options.mode == 'greater' then
        active = data.value > self.sv.options.value
    end

    if self.sv.options.outputMode == "switch" then
        if self.interactable.active ~= active then
            self.interactable:setActive(active)
            self.network:sendToClients("cl_playSound", "Sensor " .. (active and "on" or "off"))
        end
    elseif self.sv.options.outputMode == "button" then
        if active then
            self.interactable:setActive(true)
            if self.interactable.active ~= true then
                self.network:sendToClients("cl_playSound", "Sensor on")
            end
            self.sv.lastButtonTick = true
        end
    end
end

function ValueDetector:server_onFixedUpdate()
    Upgrader.server_onFixedUpdate(self)

    if self.sv.options.outputMode == "button" then
        if self.interactable.active and not self.sv.lastButtonTick then
            self.interactable:setActive(false)
            self.network:sendToClients("cl_playSound", "Sensor off")
        end
    end
    self.sv.lastButtonTick = false
end

function ValueDetector:sv_onOptionsChange(data)
    if data.value then
        self.sv.options.value = data.value
    elseif data.mode then
        self.sv.options.mode = data.mode
    elseif data.outputMode then
        self.sv.options.outputMode = data.outputMode
    end
    self.storage:save(self.sv.options)
    self.network:setClientData(self.sv.options)

    self.interactable:setActive(false)
end

--------------------
-- #region Client
--------------------

function ValueDetector:client_onCreate()
    Upgrader.client_onCreate(self)

    self.cl.gui = sm.gui.createGuiFromLayout('$CONTENT_DATA/Gui/Layouts/ValueDetectorMenu.layout')
    self.cl.gui:setButtonCallback('lesser', 'cl_onModeChange')
    self.cl.gui:setButtonCallback('greater', 'cl_onModeChange')
    self.cl.gui:setTextAcceptedCallback('ValueEdit', 'cl_onValueChange')
    self.cl.gui:setButtonCallback('LogicMode', 'cl_onOutputModeChange')
end

function ValueDetector:client_onClientDataUpdate(data)
    self.cl.options = data
    self:cl_updateGuiData()
end

function ValueDetector:client_onInteract(_, state)
    if not state then return end

    self.cl.gui:setText("Title", sm.shape.getShapeTitle(self.shape.uuid))
    self.cl.gui:setText("CompareModeTitle", language_tag("ValueDetectorCompareMode"))
    self.cl.gui:setText("ValueTitle", language_tag("ValueDetectorCompareValue"))
    self.cl.gui:setText("LogicOutputTitle", language_tag("ValueDetectorOutputMode"))

    self:cl_updateGuiData()
    self.cl.gui:open()
end

function ValueDetector:cl_updateGuiData()
    self.cl.gui:setText('ValueEdit', tostring(self.sv.options.value))
    self:cl_highlightButtons()
    self:cl_setOutputModeButtonName()
end

function ValueDetector:cl_onValueChange(_, val)
    val = tonumber(val)
    if val == nil then return end

    self.network:sendToServer('sv_onOptionsChange', { value = val })
end

function ValueDetector:cl_onModeChange(buttonName)
    self.cl.options.mode = buttonName
    self:cl_highlightButtons()

    self.network:sendToServer('sv_onOptionsChange', { mode = self.cl.options.mode })
end

function ValueDetector:cl_onOutputModeChange()
    local invert = {
        switch = "button",
        button = "switch"
    }

    self.cl.options.outputMode = invert[self.cl.options.outputMode]
    self.network:sendToServer('sv_onOptionsChange', { outputMode = self.cl.options.outputMode })

    self:cl_setOutputModeButtonName()
end

function ValueDetector:cl_highlightButtons()
    self.cl.gui:setButtonState('lesser', self.cl.options.mode == 'lesser')
    self.cl.gui:setButtonState('greater', self.cl.options.mode == 'greater')
end

function ValueDetector:cl_setOutputModeButtonName()
    self.cl.gui:setText("LogicModeText", language_tag("ValueDetectorOutputMode_" .. self.cl.options.outputMode))
end

function ValueDetector:cl_playSound(soundName)
    sm.audio.play(soundName)
end

--------------------
-- #region Types
--------------------

---@class ValueDetectorSv
---@field options ValueDetectorOptions
---@field lastButtonTick boolean whether the detector was active during the last tick. Used for button mode only.

---@class ValueDetectorCl
---@field gui GuiInterface gui to change the options
---@field options ValueDetectorOptions

---@class ValueDetectorOptions
---@field mode "lesser"|"greater" how the detector compares the value of a drop
---@field value number the number to compare the value of a drop to
---@field outputMode "switch"|"button" whether the logic output behaves like a button or switch

-- #endregion
