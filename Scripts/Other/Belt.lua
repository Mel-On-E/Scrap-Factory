dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")

---@class Belt : ShapeClass
Belt = class()
Belt.maxParentCount = 1
Belt.maxChildCount = 0
Belt.connectionInput = sm.interactable.connectionType.logic
Belt.connectionOutput = sm.interactable.connectionType.none
Belt.colorNormal = sm.color.new(0xdddd00ff)
Belt.colorHighlight = sm.color.new(0xffff00ff)

local idsUpdated = {}

function Belt:server_onCreate()
    local size = sm.vec3.new(self.data.belt.box.x, self.data.belt.box.y, self.data.belt.box.z)
    local offset = sm.vec3.new(self.data.belt.offset.x, self.data.belt.offset.y, self.data.belt.offset.z)

    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character)
    self.trigger:bindOnStay("sv_onStay")

    Power.server_onCreate(self)
end

function Belt:server_onFixedUpdate()
    Power.server_onFixedUpdate(self, nil)
    idsUpdated = {}
end

function Belt:sv_onStay(trigger, results)
    if not self.active then return end
    local selfId = self.shape.body.id
    for _, result in ipairs(results) do
        if sm.exists(result) then
            if result.id == selfId then
                goto continue
            end
            for _, id in ipairs(idsUpdated) do
                if result.id == id then
                    goto continue
                end
            end

            local direction = self.shape.at * self.data.belt.direction.at +
                self.shape.right * self.data.belt.direction.right + self.shape.up * self.data.belt.direction.up
            local force = direction * (result.mass / 4) * self.data.belt.speed
            local dirVelocity = getDirectionalVelocity(result:getVelocity(), direction)
            if dirVelocity:length() < self.data.belt.speed then
                sm.physics.applyImpulse(result, force, true)
                table.insert(idsUpdated, result.id)
            end
        end
        ::continue::
    end
end

function getDirectionalVelocity(vel, dir)
    local dimensions = { "x", "y", "z" }
    local dirVelocity = sm.vec3.zero()

    for _, dim in ipairs(dimensions) do
        if dir[dim] > 0 and vel[dim] > 0 then
            dirVelocity[dim] = dir[dim] * vel[dim]
        elseif dir[dim] < 0 and vel[dim] < 0 then
            dirVelocity[dim] = dir[dim] * vel[dim]
        end
    end

    return dirVelocity
end
