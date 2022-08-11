dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")

Belt = class( nil )
Belt.maxParentCount = 1
Belt.maxChildCount = 0
Belt.connectionInput = sm.interactable.connectionType.logic
Belt.connectionOutput = sm.interactable.connectionType.none
Belt.colorNormal = sm.color.new( 0xdddd00ff )
Belt.colorHighlight = sm.color.new( 0xffff00ff )

function Belt:server_onCreate()
    local size = sm.vec3.new(self.data.belt.box.x, self.data.belt.box.y, self.data.belt.box.z)
    local offset = sm.vec3.new(self.data.belt.offset.x, self.data.belt.offset.y, self.data.belt.offset.z)

    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size/2, offset, sm.quat.identity(), sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character )
    self.trigger:bindOnStay( "sv_onStay" )

    Power.server_onCreate(self)
end

function Belt:server_onFixedUpdate()
    Power.server_onFixedUpdate(self, nil)
end

function Belt:sv_onStay( trigger, results )
    if not self.active then return end
    for _,result in ipairs( results ) do
		if sm.exists( result ) then
            local direction = self.shape.at * self.data.belt.direction.at + self.shape.right * self.data.belt.direction.right + self.shape.up * self.data.belt.direction.up
            local force = direction*self.data.belt.speed*10
            if type(result) == "character" then      
                sm.physics.applyImpulse(result, force)
            elseif result:getVelocity():length() < 2 then
                sm.physics.applyImpulse(result, force, true)
            end
		end
	end
end