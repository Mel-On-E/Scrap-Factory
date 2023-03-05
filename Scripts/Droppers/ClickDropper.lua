dofile("$CONTENT_DATA/Scripts/Droppers/Dropper.lua")
---A ClickDropper is a `Dropper` that will create a `Drop` and consume power when the player clicks (interacts) with it.
---@class ClickDropper : Dropper
---@field cl ClickDropperCl
---@field sv ClickDropperSv
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
ClickDropper = class(Dropper)
ClickDropper.poseWeightCount = 1

--------------------
-- #region Server
--------------------

function ClickDropper:server_onFixedUpdate()
    local state = self.interactable:isActive()
    if state and state ~= self.sv.prevState then
        self:sv_consumePowerAndDrop()
    end
    self.sv.prevState = state
end

function ClickDropper:sv_toggleActive()
    self.interactable:setActive(not self.interactable.active)
    self.network:sendToClients("client_playSound", "Button " .. (self.interactable.active and "off" or "on"))
end

-- #endregion

--------------------
-- #region Client
--------------------

function ClickDropper:client_onCreate()
    self.cl = {}
end

function ClickDropper:client_onFixedUpdate()
    --update state
    local state = self.interactable:isActive()
    if state ~= self.cl.prevState then
        self.interactable:setPoseWeight(0, state and 1 or 0)
    end
    self.cl.prevState = state

    --check if the player doesn't look at the dropper anymore
    local char = sm.localPlayer.getPlayer().character
    if char and not self.cl.look and char:getLockingInteractable() == self.interactable then
        ---@diagnostic disable-next-line: param-type-mismatch
        char:setLockingInteractable(nil)
        self.network:sendToServer("sv_toggleActive")
    end
    self.cl.look = false
end

function ClickDropper:client_onInteract(character, state)
    if state == true then
        --when the player presses the button
        self.network:sendToServer("sv_toggleActive")
        character:setLockingInteractable(self.interactable)
    end
end

function ClickDropper:client_onAction(controllerAction, state)
    if not state and controllerAction == 15 then
        --when the player releases the button
        ---@diagnostic disable-next-line: param-type-mismatch
        sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
        self.network:sendToServer("sv_toggleActive")
    end

    return false
end

function ClickDropper:client_canInteract(character, state)
    --check if the player is looking at the dropper
    self.cl.look = true
    return true
end

function ClickDropper:client_playSound(name)
    sm.audio.play(name, self.shape.worldPosition)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class ClickDropperSv : DropperSv
---@field prevState boolean the state of the dropper 1 tick earlier

---@class ClickDropperCl
---@field cl table
---@field look boolean whehter the player is looking at the dropper
---@field prevState boolean the state of the dropper 1 tick earlier

-- #endregion
