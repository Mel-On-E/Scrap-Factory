dofile("$CONTENT_DATA/Scripts/util/uuids.lua")
dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A tpye of `Generator` that acts like a `Furnace`. It can sell a `Drop` for power, but will created a polluted `Drop`.
---@class Burner: ShapeClass
---@field cl BurnerCl
---@field powerUtil PowerUtility
Burner = class(nil)

--------------------
-- #region Server
--------------------

---chance a special effect plays when a drop is sold
local secretEffectChance = 0.15

function Burner:server_onCreate()
    Furnace.server_onCreate(self)
    Generator.server_onCreate(self)

    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "BurnerTutorial")
end

function Burner:server_onDestroy()
    Generator.server_onDestroy(self)
end

function Burner:sv_onEnter(trigger, results)
    self.powerUtil.active = true
    Furnace.sv_onEnter(self, trigger, results)
end

---@param shape Shape
function Burner:sv_onEnterDrop(shape)
    local publicData = shape.interactable.publicData
    local powerFunc = function () end

    if shape.uuid == obj_drop_biomass_gas then
        powerFunc = function (x)
            return x ^ (1/2)
        end

        Drop:Sv_dropStored(shape.id)

    elseif shape.uuid == obj_drop_scrap_wood or shape.uuid == obj_drop_scrap_wood then
        if publicData.pollution then return end

        powerFunc = function (x)
            return x ^ (1/3)
        end
    else
        return
    end

    local power = powerFunc(publicData.value)
    local pollution = math.sqrt(power)

    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect", {
        pos = shape.worldPosition,
        value = tostring(power),
        effect = math.random() < secretEffectChance and "Sellpoints - CampfireSecret" or
            "Sellpoints - CampfireOnsell",
        format = "power"
    })
    PowerManager.sv_changePower(power)

    --create pollution drop
    local smoke = sm.shape.createPart(obj_drop_smoke, shape.worldPosition, shape.worldRotation)
    smoke.interactable:setPublicData({
        value = 0,
        pollution = pollution,
        upgrades = {},
        impostor = false
    })

    --destory drop
    shape.interactable.publicData.value = nil
    shape:destroyPart(0)
end

-- #endregion

--------------------
-- #region Client
--------------------

function Burner:client_onCreate()
    Furnace.client_onCreate(self)

    self.cl.effect:setParameter("color", sm.color.new(1, 0, 0))
end

-- #endregion

--------------------
-- #region Client
--------------------

---@class BurnerCl : FurnaceCl

-- #endregion
