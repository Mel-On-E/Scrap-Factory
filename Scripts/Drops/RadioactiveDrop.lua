dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A RadioactiveDrop is a `Drop` that will decay over time, releasing pollution and reducing its value in the process.
---@class RadioactiveDrop : Drop
---@field sv RadioactiveDrop
---@field cl RadioactiveDrop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
RadioactiveDrop = class(Drop)

--------------------
-- #region Server
--------------------

---@type number the radius in which Players are hurt by the radiation
local dmgRadius = 5
---@type number the interval between radiation damage
local dmgInterval = 20

function RadioactiveDrop:server_onCreate()
    Drop.server_onCreate(self)

    ---@diagnostic disable-next-line:assign-type-mismatch
    self.sv.halfLife = tonumber(self.data.halfLife)
    self.sv.dmgTick = sm.game.getCurrentTick() % dmgInterval
end

function RadioactiveDrop:server_onFixedUpdate()
    local publicData = self.interactable.publicData
    if not publicData or not publicData.value then return end

    --decay
    if math.random(0, self.sv.halfLife) == self.sv.halfLife then
        self:sv_decay(publicData)
    end

    --radiation
    if sm.game.getCurrentTick() % dmgInterval == self.sv.dmgTick then
        self:sv_dmgNearbyPlayers()
    end

    Drop.server_onFixedUpdate(self)
end

---Decay the drop. This will reduce its value and release pollution. It also makes it appear smaller in size.
function RadioactiveDrop:sv_decay(publicData)
    publicData.value = publicData.value ^ 0.5

    local pollution = publicData.value ^ 0.5
    sm.event.sendToGame("sv_e_stonks",
        { pos = self.shape.worldPosition, value = tostring(pollution), format = "pollution", effect = "Pollution" })
    PollutionManager.sv_addPollution(pollution)

    self.network:sendToClients("cl_decreaseSize")
end

---Finds nearby players and causes dmg
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

-- #endregion

--------------------
-- #region Client
--------------------

function RadioactiveDrop:client_onCreate()
    Drop.client_onCreate(self)

    ---@diagnostic disable-next-line:assign-type-mismatch
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
    ---@diagnostic disable-next-line:assign-type-mismatch
    self.cl.scale = self.cl.scale * 0.5 ^ (1 / 3)
    self.cl.effects["radioactive"]:setScale(self.cl.scale)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class RadioactiveDrop : DropSv
---@field halfLife number the number of ticks it takes ON AVERAGE for a drop to decay
---@field dmgTick number a tick interval so multiple drops don't cause damage all at once

---@class RadioactiveDrop : DropCl
---@field scale Vec3 the current size of the drop (will decrease after decay)

-- #endregion
