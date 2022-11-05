dofile("$CONTENT_DATA/Scripts/Droppers/Dropper.lua")

---@class ClickDropper : Dropper
---@field cl ClickDropperCl
---@field sv ClickDropperSv
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
ClickDropper = class(Dropper)
ClickDropper.poseWeightCount = 1

function ClickDropper:server_onFixedUpdate()
    local state = self.interactable:isActive()
    if state ~= self.sv.prevState and state then
        self:sv_drop()
    end
    self.sv.prevState = state
end

function ClickDropper:sv_activate()
    self.interactable:setActive(not self.interactable.active)
    self.network:sendToClients("client_playSound", "Button " .. (self.interactable.active and "off" or "on"))
end

function ClickDropper:client_onFixedUpdate()
    local state = self.interactable:isActive()
    if state ~= self.cl.prevState then
        self.interactable:setPoseWeight(0, state and 1 or 0)
    end
    self.cl.prevState = state

    local char = sm.localPlayer.getPlayer().character
    if char and not self.cl.look and char:getLockingInteractable() == self.interactable then
        ---@diagnostic disable-next-line: param-type-mismatch
        char:setLockingInteractable(nil)
        self.network:sendToServer("sv_activate")
    end
    self.cl.look = false
end

function ClickDropper:client_onInteract(character, state)
    if state == true then
        self.network:sendToServer("sv_activate")
        character:setLockingInteractable(self.interactable)
    end
end

function ClickDropper:client_onAction(controllerAction, state)
    if not state and controllerAction == 15 then
        ---@diagnostic disable-next-line: param-type-mismatch
        sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
        self.network:sendToServer("sv_activate")
    end
    return false
end

function ClickDropper:client_canInteract(character, state)
    self.cl.look = true
    return true
end

function ClickDropper:client_playSound(name)
    sm.audio.play(name, self.shape.worldPosition)
end

--Types
---@class ClickDropperCl : DropperCl
---@field look boolean
---@field prevState boolean

---@class ClickDropperSv : DropperSv
---@field prevState boolean
