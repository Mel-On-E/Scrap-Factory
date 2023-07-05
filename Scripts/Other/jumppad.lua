
---a pad that will launch drops and players into the air
---@class JumpPad : ShapeClass
---@field powerUtil PowerUtility
JumpPad = class()
JumpPad.maxParentCount = 1
JumpPad.connectionInput = sm.interactable.connectionType.logic
JumpPad.colorNormal = sm.color.new(0x2222ddff)
JumpPad.colorHighlight = sm.color.new(0x4444ffff)

--------------------
-- #region Server
--------------------

function JumpPad:server_onCreate()
    PowerUtility.sv_init(self)

    self.sv = {}

    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character)
    self.sv.trigger:bindOnEnter("sv_onEnter")
end

function JumpPad:sv_onEnter(_, results)
    if not self.powerUtil.active then return end

    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end

        local force = self.shape.at * 10 * result.mass
        if type(result) == "Character" then
            ---@cast result Character
            if not result:isPlayer() then goto continue end
            sm.physics.applyImpulse(result, force)
        else
            ---@cast result Body
            for _,shape in ipairs(result:getShapes()) do
                --make sure shape is a drop
                local interactable = shape:getInteractable()
                if not interactable or interactable.type ~= "scripted"  then goto continue end
                local publicData = interactable:getPublicData()
                if not (publicData and publicData.value) then goto continue end

                sm.physics.applyImpulse(result, force, true)
            end
        end
        ::continue::
    end
end

function JumpPad:server_onFixedUpdate(dt)
    PowerUtility.sv_fixedUpdate(self, "cl_toggleEffect")
end

-- #endregion

--------------------
-- #region Client
--------------------

function JumpPad:client_onCreate()
    self.cl = {}

    local size = sm.vec3.new(self.data.box.x, self.data.box.y * 7.5, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.cl.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.cl.effect:setParameter("uuid", sm.uuid.new("f74a0354-05e9-411c-a8ba-75359449f770"))
    self.cl.effect:setParameter("color", sm.color.new('#f0580c'))
    self.cl.effect:setScale(size / 4.5)
    self.cl.effect:setOffsetPosition(offset)

    local rot1 = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0))
    --really fucking weird rotation offset thingy bc epic shader doesn't work on all rotations. WTF axolot why?
    local rot2 = self.shape.xAxis.y ~= 0 and
        sm.vec3.getRotation(sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0))
        or sm.quat.identity()
    self.cl.effect:setOffsetRotation(rot1 * rot2)

    self.cl.effect:start()
end

function JumpPad:cl_toggleEffect(active)
    if active and not self.cl.effect:isPlaying() then
        self.cl.effect:start()
    else
        self.cl.effect:stop()
    end
end

-- #endregion
