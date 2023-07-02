dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---An ExplosiveDrop is a Drop that can explode. While about to explode it massively increases value.
---@class ExplosiveDrop : Drop
---@field sv ExplosiveDropSv
---@field cl ExplosiveDropCl
---@field data ExplosiveDropData
ExplosiveDrop = class(Drop)
ExplosiveDrop.poseWeightCount = 1

ExplosiveDrop.fireDelay = 80 --ticks (2 seconds)
ExplosiveDrop.fuseDelay = 0.0625

--ERROR fix idk, check console

--------------------
-- #region Server
--------------------

function ExplosiveDrop:sv_init()
    Drop.sv_init(self)
    self.sv = {
        exploded = false,
        counting = false,
        fireDelayProgress = 0
    }
end

function ExplosiveDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    if self.sv.counting then
        self.sv.fireDelayProgress = self.sv.fireDelayProgress + 1
        if self.sv.fireDelayProgress >= self.fireDelay then
            self:sv_tryExplode()
        end
    end
end

function ExplosiveDrop:sv_tryExplode()
    if not self.sv.exploded then
        self.sv.exploded = false
        self.sv.counting = false
        self.sv.fireDelayProgress = 0

        -- Create explosion
        sm.physics.explode(self.shape.worldPosition, self.data.destructionLevel, self.data.destructionRadius,
            self.data.impulseRadius, self.data.impulseMagnitude, self.data.effectExplosion, self.shape)
        sm.shape.destroyShape(self.shape, 0)
    end
end

function ExplosiveDrop:server_onProjectile(hitPos) self:sv_onHit(hitPos) end

function ExplosiveDrop:server_onMelee(hitPos) self:sv_onHit(hitPos) end

function ExplosiveDrop:sv_onHit(hitPos)
    if self.sv.exploded then return end

    if self.sv.counting then
        self.sv.fireDelayProgress = self.sv.fireDelayProgress + self.fireDelay * 0.5
    else
        -- Trigger explosion countdown
        self:sv_startCountdown()
        self.network:sendToClients("cl_hitActivation", hitPos)
    end
end

function ExplosiveDrop:server_onExplosion()
    -- Explode within a few ticks
    if not self.sv.exploded then
        self.fireDelay = 5
        self.sv.counting = true
    end
end

function ExplosiveDrop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if not (type(other) == "Character" and other:isPlayer()) and not self.sv.exploded then
        local collisionDirection = (selfPointVelocity - otherPointVelocity):normalize()
        local diffVelocity = (selfPointVelocity - otherPointVelocity):length()
        local scaleFraction = 1.0 - (self.sv.fireDelayProgress / self.fireDelay)
        local dotFraction = math.abs(collisionDirection:dot(normal))

        local hardTrigger = diffVelocity * dotFraction >= 10 * scaleFraction
        local lightTrigger = diffVelocity * dotFraction >= 6 * scaleFraction

        if hardTrigger then
            -- Trigger explosion immediately
            self.sv.counting = true
            self.sv.fireDelayProgress = self.sv.fireDelayProgress + self.fireDelay
        elseif lightTrigger then
            -- Trigger explosion countdown
            if not self.sv.counting then
                self:sv_startCountdown()
                self.network:sendToClients("cl_hitActivation", position)
            else
                self.sv.fireDelayProgress = self.sv.fireDelayProgress + self.fireDelay * (1.0 - scaleFraction)
            end
        end
    end

    if not self.sv.counting then
        Drop.server_onCollision(self, other)
    end
end

---Start countdown and update clients
function ExplosiveDrop:sv_startCountdown()
    self.interactable.publicData.value = self.interactable.publicData.value * 100
    self.sv.counting = true
    self.network:sendToClients("cl_startCountdown")
end

-- #endregion

--------------------
-- #region Client
--------------------

function ExplosiveDrop:cl_init()
    Drop.cl_init(self)

    self.cl.counting = false
    self.cl.fuseDelayProgress = 0
    self.cl.fireDelayProgress = 0
    self.cl.poseScale = 0
    self.cl.effectDoOnce = true

    self.cl.singleHitEffect = sm.effect.createEffect("PropaneTank - SingleActivate", self.interactable)
    self.cl.activateEffect = sm.effect.createEffect(self.data.effectActivate, self.interactable)
end

function ExplosiveDrop:client_onDestroy()
    Drop.client_onDestroy(self)

    self.cl.singleHitEffect:stopImmediate()
    self.cl.activateEffect:stopImmediate()
end

function ExplosiveDrop:client_onUpdate(dt)
    if self.cl.counting then
        self.interactable:setPoseWeight(0, (self.cl.fuseDelayProgress * 1.5) + self.cl.poseScale)
        self.cl.fuseDelayProgress = self.cl.fuseDelayProgress + dt
        self.cl.poseScale = self.cl.poseScale + (0.25 * dt)

        if self.cl.fuseDelayProgress >= self.fuseDelay then
            self.cl.fuseDelayProgress = self.cl.fuseDelayProgress - self.fuseDelay
        end

        self.cl.fireDelayProgress = self.cl.fireDelayProgress + dt
        self.cl.activateEffect:setParameter("progress", self.cl.fireDelayProgress / (self.fireDelay * (1 / 40)))
    end
end

-- Called from server upon getting triggered by a hit
function ExplosiveDrop:cl_hitActivation(hitPos)
    local localPos = self.shape:transformPoint(hitPos)

    local smokeDirection = (hitPos - self.shape.worldPosition):normalize()
    local worldRot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), smokeDirection)
    local localRot = self.shape:transformRotation(worldRot)

    self.cl.singleHitEffect:start()
    self.cl.singleHitEffect:setOffsetRotation(localRot)
    self.cl.singleHitEffect:setOffsetPosition(localPos)
end

-- Called from server upon countdown start
function ExplosiveDrop:cl_startCountdown()
    self.cl.counting = true
    self.cl.activateEffect:start()

    local offsetRotation = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0)) *
        sm.vec3.getRotation(sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0))
    self.cl.activateEffect:setOffsetRotation(offsetRotation)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class ExplosiveDropSv
---@field exploded boolean whether the explosive has already exploded
---@field counting boolean if the bomb is ticking
---@field fireDelayProgress integer number of ticks since the explosive has been activated

---@class ExplosiveDropData
---@field destructionLevel integer destruction level of the explosion
---@field destructionRadius number radius of the sphere in which shapes are destroyed
---@field impulseRadius number radius of the spehere in which impulse is applied
---@field impulseMagnitude number strength of the impulse applied to objects in the blast radius
---@field effectExplosion string name of the effect for the explosion
---@field effectActivate string name of the effect played once the explosive is activated

---@class ExplosiveDropCl
---@field counting boolean
---@field fuseDelayProgress number
---@field fireDelayProgress number
---@field poseScale number
---@field effectDoOnce boolean
---@field singleHitEffect Effect
---@field activateEffect Effect

-- #endregion
