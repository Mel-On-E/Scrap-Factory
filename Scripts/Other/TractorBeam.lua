---A TractorBeam creates an areaTrigger when activated. It will pull items inside the trigger towards it. It can be controlled via logic.
---@class TractorBeam : ShapeClass
---@field powerUtil PowerUtility
---@field data TractorBeamData
---@field sv TractorBeamSv
---@field cl TractorBeamCl
TractorBeam = class()

TractorBeam.maxParentCount = 1
TractorBeam.maxChildCount = 0
TractorBeam.connectionInput = sm.interactable.connectionType.logic
TractorBeam.connectionOutput = sm.interactable.connectionType.none
TractorBeam.colorNormal = sm.color.new(0x2222ddff)
TractorBeam.colorHighlight = sm.color.new(0x4444ffff)

--------------------
-- #region Server
--------------------

function TractorBeam:server_onCreate()
    ---@diagnostic disable-next-line: param-type-mismatch
    PowerUtility.sv_init(self)

    self.sv = {
        trackedBodies = {},
        beamedBodies = {}
    }

    --create areaTrigger
    local size, offset = self:get_size_and_offset()
    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character)
    self.sv.trigger:bindOnEnter("sv_onEnter")
    self.sv.trigger:bindOnStay("sv_onStay")
end

function TractorBeam:sv_onEnter(trigger, results)
    for _, body in ipairs(self:sv_getValidBodies(results)) do
        self.sv.trackedBodies[#self.sv.trackedBodies + 1] = body
    end
end

function TractorBeam:sv_onStay(trigger, results)
    if not self.powerUtil.active then return end

    local oldBeamedBodies = self.sv.beamedBodies
    self.sv.beamedBodies = {}

    for _, body in ipairs(self:sv_getValidBodies(results)) do
        local beamDirection = -self.shape.up

        local strength = oldBeamedBodies[body.id] or 0
        strength = math.min(strength + 0.1, 10)

        ---@diagnostic disable-next-line: param-type-mismatch
        sm.physics.applyImpulse(body, beamDirection * strength, true)

        self.sv.beamedBodies[body.id] = strength
    end
end

function TractorBeam:server_onFixedUpdate()
    ---@diagnostic disable-next-line: param-type-mismatch
    PowerUtility.sv_fixedUpdate(self, "cl_toggleBeamEffect")

    if not self.powerUtil.active then
        self.sv.trackedBodies = {}
        self.sv.beamedBodies = {}
    else
        --push items towards the center of the beam
        for key, body in pairs(self.sv.trackedBodies) do
            if body and sm.exists(body) then
                local beamDirection = -self.shape.up
                local distance = (self.shape.worldPosition - body.centerOfMassPosition)

                if distance:length() < 5 then
                    local BeamCenterOffset = distance -
                        beamDirection * (distance:dot(beamDirection) / beamDirection:length2())

                    local force = BeamCenterOffset * 10
                    sm.physics.applyImpulse(body, force, true)
                else
                    print("too far", distance:length())
                    self.sv.trackedBodies[key] = nil
                end
            end
        end
    end
end

---@param results table table of boides to be validates
---@return table<integer, Body> bodies a list of bodies that are vaild
function TractorBeam:sv_getValidBodies(results)
    local bodies = {}
    for _, result in ipairs(results) do
        if sm.exists(result) then
            if type(result) ~= "Body" then goto continue end
            if result.id == self.shape.body.id then goto continue end

            bodies[#bodies + 1] = result
        end
        ::continue::
    end

    return bodies
end

-- #endregion

--------------------
-- #region Client
--------------------

function TractorBeam:client_onCreate()
    self.cl = {}

    self:cl_createBeamEffect()
end

function TractorBeam:cl_createBeamEffect()
    local size, offset = self:get_size_and_offset()

    self.cl.beamEffect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.cl.beamEffect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
    self.cl.beamEffect:setScale(size)
    self.cl.beamEffect:setOffsetPosition(offset)
    self.cl.beamEffect:setParameter("color", sm.color.new(1, 0.3, 0.3))
    self.cl.beamEffect:start()
end

---toggle the effects depending on the current power state
function TractorBeam:cl_toggleBeamEffect(active)
    if active and not self.cl.beamEffect:isPlaying() then
        self.cl.beamEffect:start()
    else
        self.cl.beamEffect:stop()
    end
end

-- #endregion

---get the size and offset for the areaTrigger based on the script data
---@return Vec3 size
---@return Vec3 offset
function TractorBeam:get_size_and_offset()
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
    return size, offset
end

--------------------
-- #region Types
--------------------

---@class TractorBeamSv
---@field trigger AreaTrigger areaTrigger of the beam that pulls items
---@field trackedBodies table<integer, Body> list of bodies that have entered the beam and need to be pushed towards it
---@field beamedBodies type<integer, integer> list of bodies which are currently inside the beam. <bodyId, beamStrength>

---@class TractorBeamData
---@field box {x: number, y: number, z: number} dimensions of the beam
---@field offset {x: number, y: number, z: number} offset of where the beam begins

---@class TractorBeamCl
---@field beamEffect Effect effect that visualizes the beam

-- #endregion
