dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A type of `Generator` that acts like a `Furnace`. It can sell a `Drop` for power, but will created a polluted `Drop`.
---@class Burner : ShapeClass
---@field cl FurnaceCl
---@field powerUtil PowerUtility
Burner = class()

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

function Burner:sv_onEnterDrop(shape)
    --exclude non-burnable drops
    if not self.data.drops[tostring(shape.uuid)] then return end
    --REMAKE allow better system for burnable items (see fire upgrader)

    --exclude polluted drops
    local publicData = shape.interactable.publicData
    if publicData.pollution then return end

    --create power
    local power = publicData.value
    if self.data.powerFunction == "root" then
        power = (power ^ (1 / (4 / 3)))
    end
    power = power + 1

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
    local newPublicData = {
        value = 1,
        pollution = power,
        upgrades = {}
    }
    smoke.interactable:setPublicData(newPublicData)

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
