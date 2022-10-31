dofile("$CONTENT_DATA/Scripts/Droppers/Dropper.lua")


---@class AutoDropper : Dropper
---@field sv AutoDropperSv
---@field data AutoDropperData
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
AutoDropper = class(Dropper)
AutoDropper.maxParentCount = 1
AutoDropper.maxChildCount = 0
AutoDropper.connectionInput = sm.interactable.connectionType.logic
AutoDropper.connectionOutput = sm.interactable.connectionType.none
AutoDropper.colorNormal = sm.color.new(0x00dd6fff)
AutoDropper.colorHighlight = sm.color.new(0x00ff80ff)

function AutoDropper:server_onCreate()
    Dropper.server_onCreate(self)
    self.sv.prevActive = true
    self.sv.lastDrop = -1
end

function AutoDropper:server_onFixedUpdate()
    local parent = self.interactable:getSingleParent()
    local active = not parent or parent:isActive()

    if active and self.sv.lastDrop + self.data.interval < sm.game.getCurrentTick() then
        self:sv_drop()
        self.sv.lastDrop = sm.game.getCurrentTick()
    end
end

---@class AutoDropperSv
---@field prevActive boolean
---@field lastDrop number

---@class AutoDropperData : DropperData
---@field interval number
