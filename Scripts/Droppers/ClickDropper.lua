dofile("$CONTENT_DATA/Scripts/Droppers/Dropper.lua")

ClickDropper = class(Dropper)
ClickDropper.poseWeightCount = 1

function ClickDropper:server_onCreate()
    Dropper.server_onCreate(self)
    self.sv = {}
end

function ClickDropper:server_onFixedUpdate()
    local state = self.interactable:isActive()
    if self.sv.prevState ~= nil and state ~= self.sv.prevState and state then
        self:sv_drop()
    end
    self.sv.prevState = state
end

function ClickDropper:sv_activate()
    self.interactable:setActive(not self.interactable:isActive())
    self.network:sendToClients("client_playSound", "Button " .. (self.interactable:isActive() and "off" or "on"))
end

function ClickDropper:client_onCreate()
    self.cl = {}
end

function ClickDropper:client_onFixedUpdate(character, state)
    local state = self.interactable:isActive()
    if state ~= self.cl.prevState then
        self.interactable:setPoseWeight(0, state and 1 or 0)
    end
    self.cl.prevState = state

    self.look = false
    if not self.look and sm.localPlayer.getPlayer().character:getLockingInteractable() == self.interactable then return end
    sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
end

function ClickDropper:client_onInteract(character, state)
    if state == false then return end
    self.network:sendToServer("sv_activate")
    character:setLockingInteractable(self.interactable)
end

function ClickDropper:client_onAction(controllerAction, state)
    if state and controllerAction ~= 15 then return end
    sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
    self.network:sendToServer("sv_activate")
    return false
end

function ClickDropper:client_canInteract(character, state)
    self.look = true
    return true
end

function ClickDropper:client_playSound(name)
    sm.audio.play(name, self.shape.worldPosition)
end
