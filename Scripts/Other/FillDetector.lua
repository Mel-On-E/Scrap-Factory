dofile "$CONTENT_DATA/Scripts/util/uuids.lua"

---@class FillDetector : ShapeClass
---@field container Container
---@field ops FillDetectorOps
---A logic gate that outputs a signal based on the contents of a connected container
FillDetector = class()
FillDetector.connectionInput = sm.interactable.connectionType.logic
FillDetector.connectionOutput = sm.interactable.connectionType.logic
FillDetector.maxParentCount = 1
FillDetector.maxChildCount = -1
FillDetector.colorNormal = sm.color.new( "#4eb337" )
FillDetector.colorHighlight = sm.color.new( "#62d149" )

--Todo asg nor for filldetector screen

--------------------
-- #region Server
--------------------

function FillDetector:server_onCreate()
    self.container = nil
    self.ops = {
        minVal = 0,
        maxVal = 62
    }
end

function FillDetector:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    if parent then
        if parent.shape.uuid == obj_dropcontainer then
            self.container = parent:getContainer(0)
        else
            parent:disconnect(self.interactable)
        end
    else
        self.container = nil
    end

    local active = false
    if self.container then
        local count = self:sv_countContents(self.container)
        active = count>=self.ops.minVal and count<=self.ops.maxVal
    end
    self.interactable:setActive(active)
end

---@param container Container
function FillDetector:sv_countContents(container)
	for i = 0, container.size - 1, 1 do
		local item = container:getItem(i)
		if item.uuid:isNil() then return i end
    end
    return container.size
end

function FillDetector:sv_onOptionChange(data)
    if data.name == 'MIN_VAL' then
        self.ops.minVal = data.val
    else
        self.ops.maxVal = data.val
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

function FillDetector:client_onCreate()
    self.gui = sm.gui.createGuiFromLayout('$CONTENT_DATA/Gui/Layouts/FillDetector.layout')
    self.gui:setTextChangedCallback("MIN_VAL", 'cl_onValChange')
    self.gui:setTextChangedCallback("MAX_VAL", 'cl_onValChange')
    self.gui:setText('MIN_VAL', '0')
    self.gui:setText('MAX_VAL', '62')
end

function FillDetector:client_onFixedUpdate()
    self.interactable:setUvFrameIndex(self.interactable.active and 1 or 0)
end

function FillDetector:client_onInteract(_, state)
    if not state then return end
    self.gui:open()
end

function FillDetector:cl_onValChange(name, val)
    val = tonumber(val)

    if not val then
        sm.audio.play('RaftShark')
        return
    end

    sm.audio.play("Button on", self.shape.worldPosition)
    self.network:sendToServer('sv_onOptionChange', { name=name, val=val })
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class FillDetectorOps
---@field minVal number
---@field maxVal number

-- #endregion
