---NuclearWaste is produced by NuclearReactor. It can't be deleted. It slowly releases pollution over time and is radioactive. It can be stored in DropContainer. It can be destroyed with a hammer, releasing all its pollution.
---@class NuclearWaste : ShapeClass
NuclearWaste = class(nil)
NuclearWaste.maxPollution = 1e6

--------------------
-- #region Server
--------------------

local pollutionChance = 4000
local pollutionFraction = 0.05
local dmgRadius = 5
local dmgChance = 20

function NuclearWaste:server_onCreate()
    if not self.storage:load() then
        self.storage:save(self.interactable.publicData)
    else
        self.interactable.publicData = self.storage:load()
    end

    local body = self.shape.body
    body:setLiftable(false)
    body:setErasable(false)
    body:setBuildable(false)
    body:setPaintable(false)

    self.radioactiveTrigger = sm.areaTrigger.createAttachedSphere(self.interactable, dmgRadius, nil, nil,
        sm.areaTrigger.filter.character)
    self.radioactiveTrigger:bindOnStay("sv_onStay")
end

function NuclearWaste:server_onFixedUpdate()
    if math.random(0, pollutionChance) == 0 then
        local pollution = self.interactable.publicData.pollution * pollutionFraction
        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect",
            { pos = self.shape.worldPosition, value = tostring(pollution), format = "pollution", effect = "Pollution" })
        PollutionManager.sv_addPollution(pollution)

        self.interactable.publicData.pollution = self.interactable.publicData.pollution - pollution
        self.storage:save(self.interactable.publicData)
    end

    if sm.game.getCurrentTick() % 40 == 0 then
        ---@diagnostic disable-next-line: param-type-mismatch
        Drop.sv_setClientData(self)
    end
end

function NuclearWaste:sv_onStay(trigger, results)
    for _, character in ipairs(results) do
        if sm.exists(character) then
            local characterOwner = character:getPlayer() or character:getUnit()
            if type(characterOwner) == "Player" and math.random(0, dmgChance) == 0 then
                local source = (math.random(2) == 2 and "poison") or "drown"

                local distance = math.max((self.shape.worldPosition - character:getWorldPosition()):length(), 0)
                local distanceFactor = ((dmgRadius - distance) / dmgRadius) ^ 0.5
                local pollutionFactor = self.interactable.publicData.pollution / NuclearWaste.maxPollution
                local dmg = distanceFactor * pollutionFactor * 10

                sm.event.sendToPlayer(characterOwner, "sv_e_takeDamage", { damage = dmg, source = source })
            end
        end
    end
end

function NuclearWaste:server_onMelee()
    local pollution = self.interactable.publicData.pollution
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect",
        { pos = self.shape.worldPosition, value = tostring(pollution), format = "pollution", effect = "Pollution" })
    PollutionManager.sv_addPollution(pollution)

    self.shape:destroyShape(0)
end

-- #endregion

--------------------
-- #region Client
--------------------

function NuclearWaste:client_onCreate()
    self.cl = {
        data = {
            pollution = 0
        }
    }

    Effects.cl_init(self)
    Effects.cl_createEffect(self,
        { key = "default", effect = self.data.effect, host = self.interactable, autoPlay = self.data.autoPlay })
end

function NuclearWaste:client_onClientDataUpdate(data)
    ---@diagnostic disable-next-line: param-type-mismatch
    Drop.client_onClientDataUpdate(self, data)
end

function NuclearWaste:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"

    local pollution = format_number({
        format = "pollution",
        value = self.cl.data.pollution or (sm.isServerMode() and self.interactable.publicData.pollution),
        color = "#9f4f9f",
    })
    sm.gui.setInteractionText("", o1 .. pollution .. o2)

    return true
end

-- #endregion
