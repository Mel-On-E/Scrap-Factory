dofile("$CONTENT_DATA/Scripts/Generators/SolarMirror.lua")

---A Generator that produces power by flying to the sun with big energy.
---@class DysonSphere : Generator
---@field sv DysonSphereSv
---@field cl DysonSphereCl
---@diagnostic disable-next-line: param-type-mismatch
DysonSphere = class(Generator)

local launchingSpeed = 10
local sunPos = sm.vec3.new(-140, -1300, 1100)

--------------------
-- #region Server
--------------------

function DysonSphere:server_onCreate()
    Generator.server_onCreate(self)

    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.saved = {
            inOrbit = false,
            launching = false,
            dysonPos = self.shape.worldPosition + self.shape.at * 2
        }
        self.storage:save(self.sv.saved)
    end

    self:sv_updateClientData()
end

function DysonSphere:sv_updateClientData()
    self.network:setClientData(
        {
            inOrbit = self.sv.saved.inOrbit,
            launching = self.sv.saved.launching,
            dysonPos = self.sv.saved.dysonPos
        }
    )
end

function DysonSphere:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        if self.sv.saved.inOrbit then
            local power = self:sv_getPower()
            PowerManager.sv_changePower(power)
            self.network:setClientData({ power = tostring(power) })
        elseif self.sv.saved.launching then
            local pos = self.update_dysonPos(self.sv.saved.dysonPos, 1)
            self.sv.saved.dysonPos = pos
            if pos.x < sunPos.x or pos.y < sunPos.y or pos.z > sunPos.z then
                self.sv.saved.launching = false
                self.sv.saved.inOrbit = true
                self:sv_updateClientData()
            end
            self.storage:save(self.sv.saved)

            local sunDistance = (pos - sunPos):length2()
            local power = self:sv_getPower() * (1 / math.max(1, sunDistance))
            PowerManager.sv_changePower(power)
            self.network:setClientData({ power = tostring(power) })
        end
    end
end

function DysonSphere:sv_tryLaunch()
    if PowerManager.sv_changePower(-self.data.launchPower) then
        self.sv.saved.launching = true
        self.storage:save(self.sv.saved)
        self:sv_updateClientData()
    else
        sm.effect.playEffect("PowerSocket - Activate", self.shape.worldPosition)
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

local thrusterOffset = sm.vec3.new(0, -0.5, -2)

function DysonSphere:client_onCreate()
    Generator.client_onCreate(self)
    self.cl.launching = false
    self.cl.inOrbit = false
    self.cl.dysonPos = self.shape.worldPosition
    self.cl.orbitAngle = math.random() * 360

    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", obj_duckson_sphere_effect)
    effect:setScale(sm.vec3.one() * 4)
    self.cl.dysonSphereEffect = effect
    self.cl.dysonSphereEffect:start()

    self.cl.thrusterEffect = sm.effect.createEffect("Thruster - Level 5")

    self.cl.iconGui = self:cl_createIconGui(32)
end

function DysonSphere:cl_createIconGui(size)
    local gui = sm.gui.createWorldIconGui(size, size, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false)
    gui:setImage("Icon", "$CONTENT_DATA/Gui/Images/duck.png")
    gui:setRequireLineOfSight(false)
    gui:setMaxRenderDistance(50000000)
    gui:open()
    return gui
end

function DysonSphere:client_onClientDataUpdate(data)
    Generator.client_onClientDataUpdate(self, data)

    if data.inOrbit ~= nil then
        self.cl.inOrbit = data.inOrbit
        if self.cl.inOrbit then
            self.cl.dysonSphereEffect:stop()
            self.cl.thrusterEffect:stop()
            self.cl.iconGui = self:cl_createIconGui(16)
        end
    end
    if data.launching ~= nil then
        if not self.cl.launching and data.launching then
            self.cl.dysonPos = self.shape.worldPosition
            self.cl.dysonSphereEffect:setPosition(self.cl.dysonPos)
            local rot = sm.vec3.getRotation(sm.vec3.new(0, -1, 0), -SolarMirror.sunDir)
            self.cl.dysonSphereEffect:setRotation(rot)
            self.cl.dysonSphereEffect:start()

            rot = sm.vec3.getRotation(sm.vec3.new(0, 0, -1), -SolarMirror.sunDir)
            self.cl.thrusterEffect:setPosition(self.cl.dysonPos + thrusterOffset)
            self.cl.thrusterEffect:setRotation(rot)
            self.cl.thrusterEffect:start()
        end
        self.cl.launching = data.launching
    end
    if data.dysonPos then
        self.cl.dysonPos = data.dysonPos
        self.cl.dysonSphereEffect:setPosition(self.cl.dysonPos)
        self.cl.iconGui:setWorldPosition(self.cl.dysonPos)
    end
end

function DysonSphere:client_onUpdate(dt)
    if self.cl.launching then
        self.cl.dysonPos = self.update_dysonPos(self.cl.dysonPos, dt)
        self.cl.dysonSphereEffect:setPosition(self.cl.dysonPos)
        self.cl.thrusterEffect:setPosition(self.cl.dysonPos + thrusterOffset)
        self.cl.iconGui:setWorldPosition(self.cl.dysonPos)
    elseif self.cl.inOrbit then
        --rtoate icons around the sun

        local n = -SolarMirror.sunDir
        local v = sm.vec3.one():normalize()
        local p1 = v - n * (v:dot(n))
        local p2 = n:cross(p1)

        local x1 = (math.sin(self.cl.orbitAngle))
        local x2 = (math.cos(self.cl.orbitAngle))

        local dir = (-SolarMirror.sunDir + (p1 * x1 + p2 * x2):normalize() * 0.075):normalize()
        local pos = dir * 100000
        self.cl.iconGui:setWorldPosition(pos)

        self.cl.orbitAngle = self.cl.orbitAngle + dt / 5
    end
end

function DysonSphere:client_canInteract()
    local canInteract = false
    if not (self.cl.launching or self.cl.inOrbit) then
        local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
        local o2 = "</p>"
        sm.gui.setInteractionText(
            sm.gui.getKeyBinding("Use", true) ..
            language_tag("DysonSphereLaunch") ..
            o1 .. format_number({ format = "power", value = self.data.launchPower, color = "#4f4f4f" }) .. o2, "", "")
        canInteract = true
    elseif self.cl.launching then
        sm.gui.setInteractionText(language_tag("DysonSphereLaunching"))
    elseif self.cl.inOrbit then
        sm.gui.setInteractionText("#00dd00" .. language_tag("DysonSphereInOrbit"))
    end

    Generator.client_canInteract(self)

    return canInteract
end

function DysonSphere:client_onInteract(character, state)
    if state == true then
        self.network:sendToServer("sv_tryLaunch")
    end
end

function DysonSphere:client_onDestroy()
    self.cl.dysonSphereEffect:destroy()
    self.cl.thrusterEffect:destroy()
    self.cl.iconGui:close()
end

-- #endregion

function DysonSphere.update_dysonPos(pos, time)
    return pos - SolarMirror.sunDir * launchingSpeed * time
end

--------------------
-- #region Types
--------------------

---@class DysonSphereSv : GeneratorSv
---@field saved DysonSphereSvSaved

---@class DysonSphereSvSaved
---@field launching boolean
---@field inOrbit boolean
---@field dysonPos Vec3

---@class DysonSphereCl : GeneratorCl
---@field launching boolean
---@field inOrbit boolean
---@field dysonPos Vec3
---@field orbitAngle number
---@field dysonSphereEffect Effect
---@field thrusterEffect Effect
---@field iconGui GuiInterface

-- #endregion
