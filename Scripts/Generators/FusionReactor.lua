---A type of `Generator` that produces power when supplied by deuterium and tritium.
---@class FusionReactor : Generator
---@field sv FusionReactorSv
---@field cl FusionReactorCl
FusionReactor = class(nil)

local powerUpSeconds = 10
local powerUpEnergy = 1e6
local powerFactor = 1e9
local fuelCostPerReaction = 0.01
local heliumValue = 69
local gears = 10

--------------------
-- #region Server
--------------------

function FusionReactor:server_onCreate()
    Generator.server_onCreate(self)

    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.sv.trigger = sm.areaTrigger.createAttachedBox(
        self.interactable,
        size / 2,
        offset,
        sm.vec3.getRotation(self.shape.at, self.shape.up),
        sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character
    )
    self.sv.trigger:bindOnEnter("sv_onEnter")
    self.sv.trigger:bindOnStay("sv_onEnter")

    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.saved = {
            gearIdx = 2,
            fuel = {
                deuterium = 0,
                tritium = 0
            },
            powered = false,
            powerUpProgress = 0,
            heliumWaste = 0
        }
        self.storage:save(self.sv.saved)
    end


    local fuelPoints = self.sv.saved.fuel.deuterium + self.sv.saved.fuel.tritium
    self.network:setClientData({
        powered = self.sv.saved.powered,
        fuelPoints = fuelPoints,
        DT_ratio = fuelPoints == 0 and 0 or self.sv.saved.fuel.deuterium / fuelPoints,
        gearIdx = self.sv.saved.gearIdx
    })
end

function FusionReactor:sv_powerUpclicked()
    if self.sv.saved.powerUpProgress == 0 then
        self:sv_powerUp()
    end
end

function FusionReactor:sv_powerUp()
    if PowerManager.sv_changePower(-powerUpEnergy) then
        self.sv.saved.powerUpProgress = self.sv.saved.powerUpProgress + 1

        sm.effect.playEffect("GlowstickProjectile - Bounce", self.shape.worldPosition)

        if self.sv.saved.powerUpProgress >= powerUpSeconds then
            self.sv.saved.powerUpProgress = 0
            self.sv.saved.powered = true
            self.network:setClientData({
                powered = true
            })
        end

        self.storage:save(self.sv.saved)
    else
        self.sv.saved.powerUpProgress = 0
        self.storage:save(self.sv.saved)

        sm.effect.playEffect("PowerSocket - Activate", self.shape.worldPosition)
    end

    self.network:setClientData({
        powerUpProgress = self.sv.saved.powerUpProgress,
        power = tostring(-powerUpEnergy)
    })
end

function FusionReactor:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        if self.sv.saved.powered then
            local powerOutput = -powerUpEnergy
            local fuelPoints = (self.sv.saved.fuel.deuterium + self.sv.saved.fuel.tritium)
            if PowerManager.sv_changePower(-powerUpEnergy) then
                if fuelPoints > 0 then
                    local gearFactor = math.max(0, 1.5 ^ (self.sv.saved.gearIdx - 1) - 0.5)
                    local ratio = self.sv.saved.fuel.deuterium / fuelPoints
                    local ratioFactor = math.min(ratio, 1 - ratio)
                    ratioFactor = ratioFactor ^ 2 * 4

                    local power = gearFactor * ratioFactor * powerFactor
                    PowerManager.sv_changePower(power)
                    powerOutput = powerOutput + power

                    local fuelCost = gearFactor * fuelCostPerReaction
                    self.sv.saved.fuel.deuterium = math.max(0, self.sv.saved.fuel.deuterium - fuelCost * ratio)
                    self.sv.saved.fuel.tritium = math.max(0, self.sv.saved.fuel.tritium - fuelCost * (1 - ratio))

                    self.sv.saved.heliumWaste = self.sv.saved.heliumWaste + fuelCost / 2
                    if self.sv.saved.heliumWaste >= 1 then
                        self.sv.saved.heliumWaste = self.sv.saved.heliumWaste - 1
                        ---@diagnostic disable-next-line: param-type-mismatch
                        local shape = sm.shape.createPart(obj_drop_helium,
                            self.shape.worldPosition + self.shape.at * 1.25,
                            self.shape:getWorldRotation())

                        shape.color = sm.color.new(math.random(), math.random(), math.random())

                        local publicData = {
                            value = heliumValue,
                        }
                        shape.interactable:setPublicData(publicData)
                    end

                    self.storage:save(self.sv.saved)

                    fuelPoints = self.sv.saved.fuel.deuterium + self.sv.saved.fuel.tritium



                    self.network:setClientData({
                        fuelPoints = fuelPoints,
                        DT_ratio = fuelPoints == 0 and 0 or self.sv.saved.fuel.deuterium / fuelPoints
                    })
                end
            else
                self.sv.saved.powered = false
                sm.effect.playEffect("PowerSocket - Activate", self.shape.worldPosition)
                self.storage:save(self.sv.saved)
                self.network:setClientData({
                    powered = false,
                })
            end

            self.network:setClientData({
                power = tostring(powerOutput),
            })
        end

        if self.sv.saved.powerUpProgress > 0 then
            self:sv_powerUp()
        end
    end
end

function FusionReactor:sv_onEnter(trigger, results)
    for _, drop in ipairs(getDrops(results)) do
        local d = drop.uuid == obj_drop_deuterium
        local t = drop.uuid == obj_drop_tritium
        if not (d or t) then goto continue end

        self.sv.saved.fuel.deuterium = self.sv.saved.fuel.deuterium + (d and 1 or 0)
        self.sv.saved.fuel.tritium = self.sv.saved.fuel.tritium + (t and 1 or 0)
        self.storage:save(self.sv.saved)

        local fuelPoints = self.sv.saved.fuel.deuterium + self.sv.saved.fuel.tritium
        self.network:setClientData({
            powered = self.sv.saved.powered,
            fuelPoints = fuelPoints,
            DT_ratio = fuelPoints == 0 and 0 or self.sv.saved.fuel.deuterium / fuelPoints
        })

        local color = d and "#00ddff" or "#00dd00"
        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect", {
            pos = drop:getWorldPosition(),
            value = color .. (d and "D" or "T"),
            format = nil,
            color = "",
            effect = "GlowstickProjectile - Bounce",
        })

        drop:destroyShape(0)
        ::continue::
    end
end

function FusionReactor:sv_setGear(gearIdx, player)
    self.sv.saved.gearIdx = gearIdx

    self.storage:save(self.sv.saved)
    self.network:setClientData({
        gearIdx = self.sv.saved.gearIdx
    })
end

-- #endregion


--------------------
-- #region Client
--------------------

function FusionReactor:client_onCreate()
    Generator.client_onCreate(self)
    self.cl.gearIdx = 1
    self.cl.status = ""
    self.cl.statusGUI = sm.gui.createNameTagGui()
    self.cl.statusGUI:setMaxRenderDistance(100)
    self.cl.DT_ratio = 0
    self.cl.fuelPoints = 0
    self.cl.powerUpProgress = 0
    self.cl.plasmaEffect = sm.effect.createEffect("GlowstickProjectile - Hit", self.interactable)

    local size = sm.vec3.new(self.data.box.x, self.data.box.y * 7.5, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    effect:setParameter("uuid", sm.uuid.new("f74a0354-05e9-411c-a8ba-75359449f770"))
    effect:setParameter("color", sm.color.new("ff5c0aff"))
    effect:setScale(size / 4.5)
    effect:setOffsetPosition(offset)
    effect:start()

    ---@diagnostic disable-next-line: param-type-mismatch
    local rot = sm.vec3.getRotation(self.shape.up, -self.shape.up)
    effect:setOffsetRotation(rot)

    self.cl.triggerEffect = effect
end

function FusionReactor:client_onFixedUpdate()
    if not self.cl.couldInteract then
        self.cl.statusGUI:close()
    end
    self.cl.couldInteract = false
end

function FusionReactor:client_onClientDataUpdate(data)
    Generator.client_onClientDataUpdate(self, data)

    if data.gearIdx then
        self.cl.gearIdx = data.gearIdx
    end
    if data.status then
        if data.status == "NuclearReactorCritical" then
            self.cl.status = "#ff0000" .. language_tag(data.status)
        end
    end
    if data.DT_ratio then
        self.cl.DT_ratio = data.DT_ratio
    end
    if data.fuelPoints then
        self.cl.fuelPoints = data.fuelPoints
    end
    if data.powered ~= nil then
        self.cl.powered = data.powered
        if data.powered then
            self.cl.plasmaEffect:start()
        else
            self.cl.plasmaEffect:stopImmediate()
        end
    end
    if data.powerUpProgress then
        self.cl.powerUpProgress = data.powerUpProgress
    end

    self:cl_updateReactorGui()
end

function FusionReactor:client_onInteract(character, state)
    if state == true then
        if self.cl.powered then
            self.cl.reactorGUI = sm.gui.createEngineGui()

            self.cl.reactorGUI:setText("Name", sm.shape.getShapeTitle(self.shape.uuid))
            self.cl.reactorGUI:setSliderCallback("Setting", "cl_onSliderChange")
            ---@diagnostic disable-next-line: param-type-mismatch
            self.cl.reactorGUI:setSliderData("Setting", gears, self.cl.gearIdx - 1)
            self.cl.reactorGUI:setIconImage("Icon", self.shape:getShapeUuid())
            self.cl.reactorGUI:setText("Interaction", language_tag("FusionReactorReactionSpeedControl"))

            self:cl_updateReactorGui()

            self.cl.reactorGUI:open()
        else
            self.cl.powerUpGUI = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/FusionPowerUp.layout")

            self.cl.powerUpGUI:setText("title", sm.shape.getShapeTitle(self.shape.uuid))
            self.cl.powerUpGUI:setText("Desc",
                string.format(language_tag("FusionReactorPowerUpDescription"),
                    format_number({ format = "power", value = powerUpEnergy }) .. "#ffffff", tostring(powerUpSeconds)))
            self.cl.powerUpGUI:setText("PowerUpButtonText", language_tag("FusionReactorPowerUpButton"))
            self.cl.powerUpGUI:setButtonCallback("PowerUpButton", "cl_onPowerUpClicked")

            self.cl.powerUpGUI:open()
        end
    end
end

function FusionReactor:cl_onPowerUpClicked()
    self.network:sendToServer("sv_powerUpclicked")
end

function FusionReactor:cl_onSliderChange(sliderName, sliderPos)
    self.network:sendToServer("sv_setGear", sliderPos + 1)
    self.cl.gearIdx = sliderPos + 1
end

function FusionReactor:cl_updateReactorGui()
    if not self.cl.reactorGUI then return end
    self.cl.reactorGUI:setText("SubTitle",
        language_tag("PowerOutput") ..
        format_number({ format = "power", value = self.cl.power, color = nil }))
end

function FusionReactor:client_canInteract()
    self.cl.statusGUI:setWorldPosition(self.shape.worldPosition + sm.vec3.new(0, 0, 1))

    local powerText = ""
    if self.cl.powered then
        powerText = "#00dd00" .. language_tag("FusionReactorPoweredUp")
    elseif self.cl.powerUpProgress > 0 then
        powerText = "#00dddd" ..
            language_tag("FusionReactorPoweringUp") ..
            string.format("%.2f", self.cl.powerUpProgress / powerUpSeconds * 100) .. "%"
    else
        powerText = "#dd0000" .. language_tag("FusionReactorNotPoweredUp")
    end

    self.cl.statusGUI:setText("Text",
        language_tag("FusionReactorFuel") .. string.format("%.2f", self.cl.fuelPoints) ..
        "\n" .. language_tag("FusionReactorRatio") .. string.format("%.2f", self.cl.DT_ratio * 100) .. "%" ..
        "\n" .. powerText ..
        "")
    self.cl.statusGUI:open()
    self.cl.couldInteract = true

    sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true) .. "#{INTERACTION_USE}", "", "")

    return Generator.client_canInteract(self)
end

function FusionReactor:client_onDestroy()
    self.cl.plasmaEffect:destroy()
end

-- #endregion


--------------------
-- #region Types
--------------------

---@class FusionReactorSv : GeneratorSv
---@field saved FusionReactorSvSaved
---@field trigger AreaTrigger

---@class FusionReactorSvSaved
---@field gearIdx integer
---@field fuel {deuterium: number, tritium: number}
---@field powered boolean
---@field powerUpProgress integer
---@field heliumWaste number

---@class FusionReactorCl : GeneratorCl
---@field gearIdx integer
---@field status string
---@field powered boolean
---@field statusGUI GuiInterface
---@field DT_ratio number
---@field fuelPoints number
---@field couldInteract boolean
---@field plasmaEffect Effect
---@field powerUpGUI GuiInterface
---@field reactorGUI GuiInterface
---@field powerUpProgress integer

-- #endregion
