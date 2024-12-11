dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---A value detector has a belt and trigger. Once drops enter the trigger it will output a logic signal based on the value of the drop. It has a gui which can be used to control when a logic output is triggered.
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
    self.sv.options = self.storage:load()
    if not self.sv.options then
        self.sv.options = {
            mode = 'Greater',
            value = 1,
            outputMode = 'switch'
        }
    end
    self.network:setClientData(self.sv.options)
end

function ValueDetector:sv_onUpgrade(shape, data)
    local active = false
    if self.sv.options.mode == 'Smaller' then
        active = data.value < self.sv.options.value
    elseif self.sv.options.mode == 'Greater' then
        active = data.value > self.sv.options.value
    elseif self.sv.options.mode == 'Equal' then
        active = data.value == self.sv.options.value
    elseif self.sv.options.mode == "SmallerOrEqual" then
        active = data.value <= self.sv.options.value
    elseif self.sv.options.mode == "GreaterOrEqual" then
        active = data.value >= self.sv.options.value
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
        end
    end
end

function ValueDetector:server_onFixedUpdate()
    Upgrader.server_onFixedUpdate(self)

    if self.sv.options.outputMode == "button" and self.interactable:isActive() then
        self.interactable:setActive(false)
        self.network:sendToClients("cl_playSound", "Sensor off")
    end
end

function ValueDetector:sv_onOptionsChange(data)
    if data.value then
        self.sv.options.value = tonumber(data.value)
    elseif data.mode then
        self.sv.options.mode = data.mode
    elseif data.outputMode then
        self.sv.options.outputMode = data.outputMode
    end
    self.storage:save(self.sv.options)
    self.network:setClientData(self.sv.options)

    self.interactable:setActive(false)
end

-- #endregion

--------------------
-- #region Client
--------------------

function ValueDetector:client_onCreate()
    Upgrader.client_onCreate(self)

    self.cl.gui = sm.gui.createGuiFromLayout('$CONTENT_DATA/Gui/Layouts/ValueDetectorMenu.layout')
    self.cl.gui:setButtonCallback('Smaller', 'cl_onModeChange')
    self.cl.gui:setButtonCallback('Greater', 'cl_onModeChange')
    self.cl.gui:setButtonCallback('GreaterOrEqual', 'cl_onModeChange')
    self.cl.gui:setButtonCallback('SmallerOrEqual', 'cl_onModeChange')
    self.cl.gui:setButtonCallback('Equal', 'cl_onModeChange')
    self.cl.gui:setTextChangedCallback('ValueEdit', 'cl_onValueChange')
    self.cl.gui:setButtonCallback('LogicMode', 'cl_onOutputModeChange')
end

function ValueDetector:client_onClientDataUpdate(data)
    self.cl.options = data
    self:cl_updateGuiData()
end

function ValueDetector:client_onInteract(_, state)
    if not state then return end

    self.cl.gui:setText("Title", sm.shape.getShapeTitle(self.shape.uuid))

    self:cl_updateGuiData()
    self.cl.gui:open()
end

function ValueDetector:cl_updateGuiData()
    if not self.cl.gui:isActive() then
        self.cl.gui:setText('ValueEdit', tostring(self.sv.options.value))
    end
    self:cl_highlightButtons()
    self:cl_setOutputModeButtonName()
end

function ValueDetector:cl_onValueChange(_, val)
    val = tonumber(val)

    sm.audio.play((val and "Button on" or "RaftShark"), self.shape.worldPosition)
    if not val then return end

    self.network:sendToServer('sv_onOptionsChange', { value = tostring(val) })
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
    self.cl.gui:setButtonState('Smaller', self.cl.options.mode == 'Smaller')
    self.cl.gui:setButtonState('Greater', self.cl.options.mode == 'Greater')
    self.cl.gui:setButtonState('SmallerOrEqual', self.cl.options.mode == 'SmallerOrEqual')
    self.cl.gui:setButtonState('GreaterOrEqual', self.cl.options.mode == 'GreaterOrEqual')
    self.cl.gui:setButtonState('Equal', self.cl.options.mode == 'Equal')
end

function ValueDetector:cl_setOutputModeButtonName()
    self.cl.gui:setText("LogicModeText", language_tag("ValueDetectorOutputMode_" .. self.cl.options.outputMode))
end

function ValueDetector:cl_playSound(soundName)
    sm.audio.play(soundName)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class ValueDetectorSv
---@field options ValueDetectorOptions

---@class ValueDetectorCl
---@field gui GuiInterface gui to change the options
---@field options ValueDetectorOptions

---@class ValueDetectorOptions
---@field mode "Smaller"|"Greater" | "SmallerOrEqual" | "GreaterOrEqual" | "Equal" how the detector compares the value of a drop
---@field value number the number to compare the value of a drop to
---@field outputMode "switch"|"button" whether the logic output behaves like a button or switch

-- #endregion
