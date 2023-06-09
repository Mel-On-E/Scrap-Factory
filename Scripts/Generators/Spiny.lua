dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")

---A type of generator that will produce power when spun.
---@class Spiny : Generator
---@field valid boolean weather it is producing power
Spiny = class(Generator)

--------------------
-- #region Server
--------------------

function Spiny:server_onCreate()
    Generator.server_onCreate(self)
    self.valid = false
    -- 0 means placed on block   
    -- 1 means non static
    local reason = 0

    --this check will see if you placed it on a nonstatic shape or not on a bearing
    for _,joint in ipairs(self.shape.body:getCreationJoints()) do
        if joint.shapeB == self.shape then
            self.valid = true
            if not joint.shapeA.body:isStatic() then
                self.valid = false
                reason = 1
            end
            break
        end
    end
    self.network:setClientData({valid=self.valid, reason=reason})
end

function Spiny:sv_getPower()
    if not self.valid then return 0 end
    -- 120 is just the biggest number i found the engine can produce
    return math.min(math.floor(self.shape.body.angularVelocity:length()/120 *self.data.power), self.data.power)
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
    if data.power then
        Generator.client_onClientDataUpdate(self, data)
    else
        self.valid = data.valid
        self.reason = data.reason
        if data.valid then
            Effects.cl_createEffect(self, { key = "afct", effect = "Spiny Power", host = self.interactable })
        end
    end
end

function Spiny:client_canInteract()
    if self.valid then
        return Generator.client_canInteract(self)
    end
    local s = self.reason==1 and language_tag('SpinyGeneratorStatic') or language_tag('SpinyGeneratorBearing')
    sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg_orange' color='#db2a16' spacing='9'>"..s.."</p>")
    return true
end

-- #endregion
