dofile("$CONTENT_DATA/Scripts/Droppers/Dropper.lua")


---@class AutoDropper : Dropper
AutoDropper = class(Dropper)
AutoDropper.maxParentCount = 1
AutoDropper.maxChildCount = 0
AutoDropper.connectionInput = sm.interactable.connectionType.logic
AutoDropper.connectionOutput = sm.interactable.connectionType.none
AutoDropper.colorNormal = sm.color.new(0x00dd6fff)
AutoDropper.colorHighlight = sm.color.new(0x00ff80ff)

function AutoDropper:server_onCreate()
    Dropper.server_onCreate(self)
    self.prevActive = true
    self.lastDrop = -1
end

function AutoDropper:server_onFixedUpdate()
    local parent = self.interactable:getSingleParent()
    if not parent then
        self.active = true
    else
        self.active = parent:isActive()
    end

    if self.active and self.lastDrop + self.data.interval < sm.game.getCurrentTick() then
        self:sv_drop()
        self.lastDrop = sm.game.getCurrentTick()
    end
end
