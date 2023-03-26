Spline = class( nil )

--------------------
-- #region Old function but still really good and looks visually different so keep it
--------------------

--[[local function create_arch(p0, p1, fraction)
    local spline = {}
    local cycles = fraction - 1

    local distance = (p1 - p0):length()
    local center = (p0 + p1) / 2
    local radius = distance / 2
    local height = math.sqrt((radius * radius) - ((distance / 2) * (distance / 2)))

    local axis = (p1 - p0):normalize()
    local up = sm.vec3.new(1, 0, 0)
    local rotation = sm.vec3.getRotation(up, axis)

    for i = 0, cycles do
        local t = i / cycles
        local angle = t * math.pi
        local x = center.x + (radius * math.cos(angle))
        local y = center.y + (radius * math.sin(angle))
        local z = center.z + height
        local point = sm.vec3.new(x, y, z)
        spline[#spline + 1] = rotation * (point - center) + center
    end

    return spline
end]]

-- #endregion

--------------------
-- #region Custom functions
--------------------

--Takes 2 positions and a fraction value and returns a table of positions along a spline between given points, amount of points along the spline is determined by farction value
local function create_arch(p0, p1, fraction)
    local distance = (p1 - p0):length()
    local multiplier = distance * 0.3
    local step = 1 / fraction
    local spline = {}

    for i = 0, fraction do
        local t = step * i
        local x = p0.x + (p1.x - p0.x) * t
        local y = p0.y + (p1.y - p0.y) * t
        local z = p0.z + (p1.z - p0.z) * t + math.sin(t * math.pi) * multiplier
        spline[#spline + 1] = sm.vec3.new(x, y, z)
    end

    return spline
end

-- #endregion

--------------------
-- #region Client
--------------------

function Spline.client_onCreate( self )
    self.areaTrigger = sm.areaTrigger.createAttachedSphere( self.interactable, 5, sm.vec3.zero(), sm.quat.identity(), 1 )
end

function Spline.client_onUpdate( self, dt )
    local contents = self.areaTrigger:getContents()
    if #contents > 0 then
        for k, body in pairs(contents) do
            if sm.exists(body) then
                for i, shape in pairs(body:getShapes()) do
                    if shape:getMaterial() == "Wood" then
                        local spline = create_arch( self.shape:getWorldPosition(), shape:getWorldPosition(), 20 )
                        for d, position in pairs(spline) do
                            sm.effect.playEffect( "Laser - Test", position, sm.vec3.zero(), sm.quat.identity(), sm.vec3.new( 0.1, 0.1, 0.1 ) )
                        end
                    end
                end
            end
        end
    end
end

-- #endregion