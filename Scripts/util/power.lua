---@class Power : ShapeClass
Power = class(nil)

function Power:server_onCreate()
    self.data.power = tonumber(self.data.power)

    self.powerUtil = {}
    self.powerUtil.prevActive = true
    self.powerUtil.active = false
    self.powerUtil.powerUpdate = 1
    self.powerUtil.hasPower = false
end

function Power:server_onFixedUpdate(effect)
    self.powerUtil.powerUpdate = self.powerUtil.powerUpdate - 1

    local parent = self.interactable:getSingleParent()
    if not parent then
        self.powerUtil.active = true
    else
        self.powerUtil.active = parent:isActive()
    end

    if self.powerUtil.powerUpdate == 0 then
        self.powerUtil.powerUpdate = 40
        if not PowerManager.sv_changePower(-self.data.power) then
            self.powerUtil.hasPower = false
        else
            self.powerUtil.hasPower = true
        end
    end

    self.powerUtil.active = self.powerUtil.active and self.powerUtil.hasPower

    if self.powerUtil.active ~= self.powerUtil.prevActive then
        if effect and type(effect) == "string" then
            self.network:sendToClients(effect, self.powerUtil.active)
        end
    end

    self.powerUtil.prevActive = self.powerUtil.active
end
