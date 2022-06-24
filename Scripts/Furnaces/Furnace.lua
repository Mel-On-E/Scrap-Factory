dofile("$CONTENT_DATA/Scripts/util.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")
dofile("$CONTENT_DATA/Scripts/util/stonks.lua")


Furnace = class(Power)
Furnace.maxParentCount = 1
Furnace.maxChildCount = 0
Furnace.connectionInput = sm.interactable.connectionType.logic
Furnace.connectionOutput = sm.interactable.connectionType.none
Furnace.colorNormal = sm.color.new( 0x8000ddff )
Furnace.colorHighlight = sm.color.new( 0x8000ffff )

function Furnace:server_onCreate()
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.trigger:bindOnEnter("sv_onEnter")
    self.trigger:bindOnStay("sv_onEnter")

    Power.server_onCreate(self)
end

function Furnace:sv_onEnter(trigger, results)
    if not self.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        for k, shape in pairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then goto continue end
            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end
            shape:destroyPart(0)
            self.network:sendToClients("cl_stonks", { pos = shape:getWorldPosition(), value = data.value })
            sm.event.sendToGame("sv_e_addMoney", data.value)
        end
        ::continue::
    end
end

function Furnace:client_onCreate()
    --[[
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
	self.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
	self.effect:setParameter("color", sm.color.new(1,1,1))
    self.effect:setScale(size)
    self.effect:setOffsetPosition(offset)
	self.effect:start()
    ]]

    Stonks.client_onCreate(self)
end

function Furnace:client_onUpdate(dt)
    Stonks.client_onUpdate(self, dt)
end

function Furnace:client_onFixedUpdate()
    Stonks.client_onFixedUpdate(self)
end

function Furnace:cl_stonks(params)
    Stonks.cl_stonks(self, params)
end
