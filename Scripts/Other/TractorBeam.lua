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
        beamedShapes = {}
    }

    --create areaTrigger
    local size, offset = self:get_size_and_offset()
    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.sv.trigger:bindOnEnter("sv_onEnter")
    self.sv.trigger:bindOnStay("sv_onStay")
end

function TractorBeam:sv_onEnter(trigger, results)
    for _, shape in ipairs(self:sv_getValidShapes(results)) do
        shape.interactable.publicData.tractorBeam = sm.game.getCurrentTick()
    end
end

function TractorBeam:sv_onStay(trigger, results)
    if not self.powerUtil.active then return end

    local oldBeamedShapes = self.sv.beamedShapes
    self.sv.beamedShapes = {}

    for _, shape in ipairs(self:sv_getValidShapes(results)) do
        --pull items towards the beam
        shape.interactable.publicData.tractorBeam = sm.game.getCurrentTick()
        local beamDirection = -self.shape.up

        local strength = oldBeamedShapes[shape.id] or 0
        strength = math.min(strength + 0.01, 1)
        self.sv.beamedShapes[shape.id] = strength

        local force = beamDirection * strength * shape.mass * 1.25

        --push items towards the center of the beam
        local distance = (self.shape.worldPosition - shape:getBody().centerOfMassPosition)
        local BeamCenterOffset = distance -
            beamDirection * (distance:dot(beamDirection) / beamDirection:length2())

        local relVel = shape.velocity - self.shape.velocity
        local beamCenterVel = relVel -
            beamDirection * (relVel:dot(beamDirection) / beamDirection:length2())
        local beamDirectionVel = relVel - beamCenterVel

        if beamDirectionVel:length() > 0.1 and beamDirectionVel:length() < BeamCenterOffset:length() * 1 then
            force = force + BeamCenterOffset * shape.mass
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        sm.physics.applyImpulse(shape:getBody(), force, true)
    end
end

function TractorBeam:server_onFixedUpdate()
    ---@diagnostic disable-next-line: param-type-mismatch
    PowerUtility.sv_fixedUpdate(self, "cl_toggleBeamEffect")

    if not self.powerUtil.active then
        self.sv.beamedShapes = {}
    end
end

---@param results table table of shapes to be validated
---@return table<integer, Shape> shapes a list of shapes that are vaild
function TractorBeam:sv_getValidShapes(results)
    local shapes = {}
    for _, result in ipairs(results) do
        if sm.exists(result) then
            if type(result) ~= "Body" then goto continue end
            if result.id == self.shape.body.id then goto continue end

            if #result:getShapes() > 1 then goto continue end

            local shape = result:getShapes()[1]
            local interactable = shape:getInteractable()

            if not interactable then goto continue end
            if interactable.type ~= "scripted" then goto continue end

            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end

            shapes[#shapes + 1] = shape
        end
        ::continue::
    end

    return shapes
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
---@field beamedShapes type<integer, integer> list of shapes which are currently inside the beam. <shapeId, beamStrength>

---@class TractorBeamData
---@field box {x: number, y: number, z: number} dimensions of the beam
---@field offset {x: number, y: number, z: number} offset of where the beam begins

---@class TractorBeamCl
---@field beamEffect Effect effect that visualizes the beam

-- #endregion
