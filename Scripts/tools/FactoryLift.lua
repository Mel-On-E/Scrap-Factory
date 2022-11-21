dofile "$GAME_DATA/Scripts/game/Lift.lua"
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/MoneyManager.lua")
dofile "$SURVIVAL_DATA/Scripts/util.lua"

---@class FactoryLift : ToolClass
FactoryLift = class(Lift)

local specialCharacters = {
    "~", "`", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
    --[["-", "_",]] "+", "=", "{", "}", "[", "]", "|", "\\", "/", ":",
    ";", '"', "'", "<", ">", ",", ".", "?"
}

function FactoryLift:sv_exportCreation(args)
    local path = string.format("$CONTENT_DATA/UserData/ExportedCreations/%s.json", args.name)
    sm.json.save(
        sm.creation.exportToTable(args.creation, false, true),
        path
    )

    local exp = "$CONTENT_DATA/UserData/ExportedCreationMap.json"
    if not sm.json.fileExists(exp) then sm.json.save({}, exp) end

    local map = sm.json.open(exp)
    if not isAnyOf(path, map) then
        map[#map + 1] = path
        sm.json.save(map, exp)
    end
end

function FactoryLift:sv_importCreation(args, caller)
    local inv = caller:getInventory()
    sm.container.beginTransaction()
    for uuid, amount in pairs(args.items) do
        sm.container.spend(inv, sm.uuid.new(uuid), amount)
    end
    sm.container.endTransaction()

    MoneyManager.sv_spendMoney(args.money)

    sm.creation.importFromFile(
        caller.character:getWorld(),
        string.format("$CONTENT_DATA/UserData/ExportedCreations/%s.json", args.name),
        args.pos + sm.vec3.new(0, 0, 10)
    )
end

function FactoryLift:client_onCreate()
    self:client_init()

    self.exportGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Factory_export.layout")
    self.exportGui:setTextChangedCallback("name", "cl_export_setName")
    self.exportGui:setButtonCallback("cancel", "cl_export_cancel")
    self.exportGui:setButtonCallback("ok", "cl_export_ok")
    self.exportGui:setOnCloseCallback("cl_export_cancel")
    self.exportName = ""
    self.exportCreation = nil

    self.importCreation = nil
    local options = self:cl_import_createUI()
    if #options > 0 then
        local option = options[1]
        self.importCreation = option
        self:cl_import_updateItemGrid(option, true)
    end
end

function FactoryLift:client_onEquippedUpdate(lmb, rmb, f)
    if self.tool:isLocal() and self.tool:isEquipped() then
        local hit, result = sm.localPlayer.getRaycast(7.5)
        self:client_interact(lmb, rmb, result)

        if hit then
            if result.type == "body" then
                sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), language_tag("ExportInteraction"))
                if f and not self.exportGui:isActive() then
                    self.exportCreation = result:getBody()
                    self.exportGui:setText("title", language_tag("ExportTitle"))
                    self.exportGui:open()
                end
            elseif result.type == "lift" then
                if f and not self.importGui:isActive() then
                    self:cl_import_updateItemGrid(self.importCreation, false)
                    --self.importGui:setText("title", language_tag("ImportTitle"))
                    self.importGui:open()
                end
            end
        end
    end

    return true, false
end

function FactoryLift:client_onUpdate()
    --Dont know why, but the use interaction doesnt appear, so I made it myself
    if not self.tool:isLocal() then return end

    local hit, result = sm.localPlayer.getRaycast(7.5)
    if hit and result.type == "lift" then
        local import = sm.localPlayer.getActiveItem() == tool_lift and
            "\t" .. sm.gui.getKeyBinding("ForceBuild", true) .. language_tag("ImportInteraction") or ""
        sm.gui.setInteractionText(
            sm.gui.getKeyBinding("Use", true) .. "#{INTERACTION_USE}",
            import,
            ""
        )
    end
end

function FactoryLift:cl_export_setName(widget, text)
    local stripped = text
    for k, v in pairs(specialCharacters) do
        stripped = stripped:gsub("%" .. v, "")
    end

    self.exportGui:setText("name", stripped)
    self.exportName = stripped
end

function FactoryLift:cl_export_cancel()
    self.exportGui:close()
    self.exportGui:setText("name", "")

    --we do a little jank
    if self.confirmClearGui then return end
    self.exportName = ""
    self.exportCreation = nil
end

function FactoryLift:cl_export_ok(widget, override)
    if self.exportName == "" then
        sm.gui.chatMessage("#ff0000" .. language_tag("InvalidName"))
        sm.audio.play("RaftShark")
        return
    end

    if not override and
        sm.json.fileExists(string.format("$CONTENT_DATA/UserData/ExportedCreations/%s.json", self.exportName)) then
        self.confirmClearGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout")
        self.confirmClearGui:setButtonCallback("Yes", "cl_onClearConfirmButtonClick")
        self.confirmClearGui:setButtonCallback("No", "cl_onClearConfirmButtonClick")
        self.confirmClearGui:setText("Title", "#{MENU_YN_TITLE_ARE_YOU_SURE}")
        self.confirmClearGui:setText("Message", language_tag("ExportBlueprintExists"):format(self.exportName))

        self.exportGui:close()
        self.confirmClearGui:open()

        return
    end

    self.network:sendToServer("sv_exportCreation", { name = self.exportName, creation = self.exportCreation })
    self:cl_export_cancel()
    sm.gui.displayAlertText(language_tag("ExportedCreation"))
    sm.audio.play("Blueprint - Save")
end

function FactoryLift:cl_onClearConfirmButtonClick(name)
    if name == "Yes" then
        self.confirmClearGui:close()
        self:cl_export_ok("", true)
    elseif name == "No" then
        self.confirmClearGui:close()
        self.exportGui:open()
    end

    self.confirmClearGui:destroy()
    self.confirmClearGui = nil
end

function FactoryLift:cl_import_createUI()
    self.importGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Factory_import.layout")
    self.importGui:setButtonCallback("import", "cl_import_importCreation")

    local options = {}
    local map = sm.json.open("$CONTENT_DATA/UserData/ExportedCreationMap.json")
    for k, path in pairs(map) do
        options[#options + 1] = path:gsub("$CONTENT_DATA/UserData/ExportedCreations/", ""):gsub(".json", "")
    end
    self.importGui:createDropDown(
        "creation",
        "cl_import_select",
        options
    )

    self.importGui:setText("title", language_tag("ImportTitle"))

    return options
end

function FactoryLift:cl_import_select(option)
    if self.importCreation ~= option then
        self.importCreation = option
        self.importGui:close()

        self:cl_import_createUI()
        self:cl_import_updateItemGrid(option, true)
        self.importGui:setSelectedDropDownItem("creation", option)
        self.importGui:open()
    end
end

function FactoryLift:cl_import_updateItemGrid(name, createGrid)
    local inv = sm.localPlayer.getInventory()
    self.importGui:setContainer("", inv)

    local items = self:cl_getBlueprintItems(name)
    if createGrid then
        self.importGui:createGridFromJson(
            "inventory",
            {
                type = "materialGrid",
                layout = "$GAME_DATA/Gui/Layouts/Interactable/Interactable_CraftBot_IngredientItem.layout",
                itemWidth = 44,
                itemHeight = 60,
                itemCount = GetActualLength(items),
            }
        )
    end

    local count = 1
    for uuid, amount in pairs(items) do
        self.importGui:setGridItem(
            "inventory",
            count - 1,
            {
                itemId = uuid,
                quantity = amount,
            }
        )

        count = count + 1
    end

    --[[
    local missingItems, missingMoney = self:cl_getImportStats(items)
    local canImport = GetActualLength(missingItems) == 0 or missingMoney == 0
    self.importGui:setVisible("import", canImport)

    self.importGui:setText("money",
        language_tag("ImportNeededMoney") .. format_number({ format = "money", value = missingMoney }))
    ]]

    local canImport, missingMoney, ownedItems = self:cl_getImportStats(items)
    self.importGui:setVisible("import", canImport)
    self.importGui:setText("money",
        language_tag("ImportNeededMoney") .. format_number({ format = "money", value = missingMoney }))
end

function FactoryLift:cl_import_importCreation()
    local canImport, missingMoney, ownedItems = self:cl_getImportStats(self:cl_getBlueprintItems(self.importCreation))

    self.network:sendToServer("sv_importCreation",
        { name = self.importCreation, pos = sm.localPlayer.getOwnedLift():getWorldPosition(),
            items = ownedItems, money = missingMoney })
    sm.gui.displayAlertText(language_tag("ImportedCreation"))
    sm.audio.play("Blueprint - Open")
    self.importGui:close()
end

function FactoryLift:cl_getBlueprintItems(name)
    local blueprint = sm.json.open(string.format("$CONTENT_DATA/UserData/ExportedCreations/%s.json", name))
    local items = {}
    for k, body in pairs(blueprint.bodies) do
        for i, child in pairs(body.childs) do
            local id = child.shapeId
            if items[id] == nil then
                items[id] = 0
            end

            local bounds = child.bounds
            local amount = bounds and bounds.x * bounds.y * bounds.z or 1
            items[id] = items[id] + amount
        end
    end

    return items
end

function FactoryLift:cl_getImportStats(items)
    local ownedItems = {}
    local neededMoney = 0
    local inv = sm.localPlayer.getInventory()

    for uuid, amount in pairs(items) do
        local owned = sm.container.totalQuantity(inv, sm.uuid.new(uuid))
        ownedItems[uuid] = sm.util.clamp(owned, 0, amount)

        if owned < amount then
            local shopItem = g_shop[uuid]
            neededMoney = neededMoney + (shopItem and tonumber(shopItem.price) or 1) * (amount - owned)
        end
    end

    return neededMoney == 0 or MoneyManager.cl_getMoney() >= neededMoney, neededMoney, ownedItems

    --[[
    local missingItems = {}
    local blueprintWorth = 0
    local inv = sm.localPlayer.getInventory()
    for uuid, amount in pairs(items) do
        local difference = sm.container.totalQuantity(inv, sm.uuid.new(uuid)) - amount
        if difference < 0 then
            if missingItems[uuid] == nil then
                missingItems[uuid] = 0
            end

            missingItems[uuid] = missingItems[uuid] + math.abs(difference)
        end

        local shopItem = g_shop[uuid]
        blueprintWorth = blueprintWorth + (shopItem and tonumber(shopItem.price) or 1)
    end

    local playerMoney = MoneyManager.cl_getMoney()
    return missingItems, playerMoney >= blueprintWorth and 0 or blueprintWorth - playerMoney, blueprintWorth
    ]]
end

function GetActualLength(table)
    local count = 0
    for k, v in pairs(table) do
        count = count + 1
    end

    return count
end
