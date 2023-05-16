dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")

---A type of generator that will produce power when spun.
---@class Spiny : Generator
---@field active boolean weather it is producing power
---@field pvActive boolean previus frame active
Spiny = class(Generator)

--------------------
-- #region Server
--------------------

function Spiny:sv_getPower()
    if not self.active then return 0 end
    return math.floor(self.shape.body.angularVelocity:length()/120 *4)
end

function Spiny:server_onFixedUpdate(dt)
    Generator.server_onFixedUpdate(self)
    self.active = false
    local reason = 0
    for _,joint in ipairs(self.shape.body:getCreationJoints()) do
        joint=joint ---@type Joint
        if joint.shapeB == self.shape then
            self.active = true
            if not joint.shapeA.body:isStatic() then
                self.active = false
                reason = 1
            end
            break
        end
    end
    if self.active ~= self.pvActive then
        self.network:setClientData({active=self.active, reason=reason})
    end
    self.pvActive = self.active
end

-- #endregion


--------------------
-- #region Client
--------------------

function Spiny:client_onCreate()
    Generator.client_onCreate(self)
    Effects.cl_init(self)
end
function Spiny:client_onDestroy()
    Generator.client_onDestroy(self)
    Effects.cl_destroyAllEffects(self)
end

function Spiny:client_onClientDataUpdate(data)
    if data.active ~= nil then
        self.active = data.active
        self.reason = data.reason
        if data.active then
            Effects.cl_createEffect(self, { key = "afct", effect = "Spiny Power", host = self.interactable })
        end
    else
        Generator.client_onClientDataUpdate(self, data)
    end
end

function Spiny:client_canInteract()
    if self.active then
        return Generator.client_canInteract(self)
    end
    local s = self.reason==1 and language_tag('SpinyGeneratorStatic') or language_tag('SpinyGeneratorBearing')
    sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_orange' color='#db2a16' spacing='9'>"..s.."</p>")
    return true
end

-- #endregion
