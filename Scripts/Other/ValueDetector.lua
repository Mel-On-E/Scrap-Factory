
---@class ValueDetector : ShapeClass
---@field trigger AreaTrigger
---@field gui GuiInterface
---@field options table
ValueDetector = class()

ValueDetector.connectionInput = sm.interactable.connectionType.none
ValueDetector.connectionOutput = sm.interactable.connectionType.logic
ValueDetector.maxParentCount = 0
ValueDetector.maxChildCount = -1
ValueDetector.colorNormal = sm.color.new( "#4cde35" )
ValueDetector.colorHighlight = sm.color.new( "#4bf230" )


-- Server

function ValueDetector:server_onCreate()
    self.options = nil
    --TODO create based on rotation of object and create effect.
    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, sm.vec3.new(3,3,1), sm.vec3.new(-1.5,-1.5,0))
    self.trigger:bindOnStay('sv_onStay')
end

function ValueDetector:sv_onStay(_, results)
    for _,result in ipairs(results) do
        if sm.exists(result) then
            if type(result) == "Body" then
                for _,shape in ipairs(result:getShapes()) do
                    local interactable = shape:getInteractable()
                    interactable = interactable ---@type Interactable
                    if interactable and interactable:getType() == "scripted" then
                        local data = interactable:getPublicData()
                        if data and data.value then
                            self:sv_checkValue(data.value)
                        end
                    end
                end
            end
        end
    end
end

function ValueDetector:sv_checkValue(value)
    if self.options.mode == '<' then
        self.interactable:setActive(value < self.options.value)
    elseif self.options.mode == '>' then
        self.interactable:setActive(value > self.options.value)
    end
end

function ValueDetector:sv_optionChanged(options)
    self.options = options
end


-- Client

function ValueDetector:client_onCreate()
    self.gui = sm.gui.createGuiFromLayout('$CONTENT_DATA/Gui/Layouts/ValueDetectorMenu.layout')
    self.gui:createDropDown('ModeDropdown', 'cl_modeChanged', {'<', '>'})
    self.gui:setTextAcceptedCallback('ValueEdit', 'cl_valueChanged')

    self.options = {
        mode = '<',
        value = 0
    }
    self.gui:setText('ValueEdit', tostring(self.options.value))
    self.gui:setSelectedDropDownItem('ModeDropdown', self.options.mode)
end

function ValueDetector:client_onInteract(_, state)
    if not state then return end
    self.gui:open()
end

function ValueDetector:cl_modeChanged(mode)
    self.options.mode = mode
    self:cl_optionChanged()
end
function ValueDetector:cl_valueChanged(_, value)
    local val = tonumber(value)
    if val ~= nil then
        self.options.value = val
        self:cl_optionChanged()
    end
end

function ValueDetector:cl_optionChanged()
    self.network:sendToServer('sv_optionChanged', self.options)
end
