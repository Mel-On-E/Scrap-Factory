dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---@class RadioactiveDrop : Drop
---@field sv RadioactiveDrop
---@field cl RadioactiveDrop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
RadioactiveDrop = class(Drop)

local dmgRadius = 5

function RadioactiveDrop:server_onCreate()
    Drop.server_onCreate(self)

    self.sv.halfLife = tonumber(self.data.halfLife)
    self.sv.dmgTick = sm.game.getCurrentTick() % 20
end

function RadioactiveDrop:server_onFixedUpdate()
    local publicData = self.interactable.publicData
    if not publicData or not publicData.value then return end

    if math.random(0, self.sv.halfLife) == self.sv.halfLife then
        self:sv_decay(publicData)
    end

    if sm.game.getCurrentTick() % 20 == self.sv.dmgTick then
        self:sv_dmgNearbyPlayers()
    end

    Drop.server_onFixedUpdate(self)
end

function RadioactiveDrop:sv_decay(publicData)
    publicData.value = publicData.value ^ 0.5

    local pollution = publicData.value ^ 0.5
    sm.event.sendToGame("sv_e_stonks",
        { pos = self.shape.worldPosition, value = tostring(pollution), format = "pollution", effect = "Pollution" })
    PollutionManager.sv_addPollution(pollution)

    self.network:sendToClients("cl_decreaseSize")
end

function RadioactiveDrop:sv_dmgNearbyPlayers()
    for _, character in ipairs(sm.physics.getSphereContacts(self.shape.worldPosition, dmgRadius).characters) do
        local characterOwner = character:getPlayer() or character:getUnit()

        if type(characterOwner) == "Player" then
            local source = (math.random(2) == 2 and "poison") or "drown"

            local distance = math.max((self.shape.worldPosition - character:getWorldPosition()):length(), 0)
            local dmg = math.max(((dmgRadius - distance) / 6.9420) ^ 2, 0.1)

            sm.event.sendToPlayer(characterOwner, "sv_e_takeDamage", { damage = dmg, source = source })
        end
    end
end

function RadioactiveDrop:client_onCreate()
    Drop.client_onCreate(self)

    self.cl.scale = sm.vec3.one() / 4

    self:cl_createEffect({
        key = "radioactive",
        effect = "ShapeRenderable",
        uuid = sm.uuid.new(self.data.effectShape),
        color = self.shape.color,
        scale = self.cl.scale
    })
end

function RadioactiveDrop:cl_decreaseSize()
    self.cl.scale = self.cl.scale * 0.5 ^ (1 / 3)
    self.cl.effects["radioactive"]:setScale(self.cl.scale)
end

--Types

---@class RadioactiveDrop : DropSv
---@field halfLife number
---@field dmgTick number

---@class RadioactiveDrop : DropCl
