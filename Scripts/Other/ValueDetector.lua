dofile("$CONTENT_DATA/Scripts/Other/Belt.lua")

---@class ValueDetector : Belt
---@field data ValueDetectorData
---@field powerUtil PowerUtility
ValueDetector = class(Belt)

ValueDetector.connectionInput = sm.interactable.connectionType.logic
ValueDetector.connectionOutput = sm.interactable.connectionType.logic
ValueDetector.maxParentCount = 1
ValueDetector.maxChildCount = -1
ValueDetector.colorNormal = sm.color.new( "#8fe625" )
ValueDetector.colorHighlight = sm.color.new( "#96f522" )

-- Server

function ValueDetector:server_onCreate()
    Belt.server_onCreate(self)
    self.options = self.storage:load()
    if self.options == nil then
        self.options = {
            mode = 'Great',
            value = 1
        }
    end
    self.network:setClientData(self.options)

    local size,offset = self:get_size_and_offset()

    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(), sm.areaTrigger.filter.dynamicBody)
    self.trigger:bindOnEnter("sv_onEnter")
end

function ValueDetector:sv_onEnter(_, results)
    if not self.powerUtil.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        if type(result) ~= "Body" then goto continue end

        for k, shape in ipairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then return end
            local data = interactable:getPublicData()
            if not data or not data.value then return end

            --valid drop
            self:sv_evalDrop(data.value)
        end
        ::continue::
    end
end

function ValueDetector:sv_evalDrop(val)
    local active = false
    if self.options.mode == 'Less' then active = val < self.options.value
    elseif self.options.mode == 'Great' then active = val > self.options.value end
    self.interactable:setActive(active)
end

function ValueDetector:sv_onDataChange(data)
    if data.value then self.options.value = data.value
    elseif data.mode then self.options.mode = data.mode end
    self.storage:save(self.options)
end

-- Client

function ValueDetector:client_onCreate()
    Belt.client_onCreate(self)
    self.gui = sm.gui.createGuiFromLayout('$CONTENT_DATA/Gui/Layouts/ValueDetectorMenu.layout')
    self.gui:setButtonCallback('Less', 'cl_onModeChange')
    self.gui:setButtonCallback('Great', 'cl_onModeChange')
    self.gui:setTextAcceptedCallback('ValueEdit', 'cl_onValueChange')
end
function ValueDetector:client_onClientDataUpdate(data)
    self.options = data
    self.gui:setText('ValueEdit', tostring(self.options.value))
    self:cl_onModeChange(data.mode, true)
end

function ValueDetector:client_onInteract(_, state)
    if not state then return end
    self.gui:open()
end

function ValueDetector:cl_onValueChange(_, val)
    local n = tonumber(val)
    if n == nil then return end
    self.options.value = n
    self.network:sendToServer('sv_onDataChange', { value = n })
end
function ValueDetector:cl_onModeChange(val, dont_send)
    self.gui:setButtonState('Less', val == 'Less')
    self.gui:setButtonState('Great', val == 'Great')
    self.options.mode = val
    if not dont_send then
        self.network:sendToServer('sv_onDataChange', { mode = val })
    end
end


---get the size and offset for the areaTrigger based on the script data
---@return Vec3 size
---@return Vec3 offset
function ValueDetector:get_size_and_offset()
    local size = sm.vec3.new(self.data.detect.box.x, self.data.detect.box.y, self.data.detect.box.z)
    local offset = sm.vec3.new(self.data.detect.offset.x, self.data.detect.offset.y, self.data.detect.offset.z)
    return size, offset
end

---@class ValueDetectorData : BeltData
---@field detect ValueDetectorDetection

---@class ValueDetectorDetection
---@field box table<string, number> dimensions x, y, z for the areaTrigger
---@field offset table<string, number> offset x, y, z for the areaTrigger
