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

function ClickDropper:sv_setActive(state)
    self.interactable.active = state
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
end

function ClickDropper:client_onInteract(character, state)
    self.network:sendToServer("sv_setActive", state)
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
---@field prevState boolean the state of the dropper 1 tick earlier

-- #endregion
