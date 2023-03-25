dofile("$GAME_DATA/Scripts/game/Lift.lua")

---A modified Lift that can export and import entire factories!
---@class FactoryLift : ToolClass
---@field cl FactoryLiftCl
---@field selectedBodies table<integer, Body> Lift.lua
---@field liftPos Vec3 Lift.lua
FactoryLift = class(Lift)

local exportedCreations = "$CONTENT_DATA/UserData/ExportedCreations.json"

--------------------
-- #region Server
--------------------

---@param args {name: string, creation: Body}
function FactoryLift:sv_exportCreation(args, caller)
    args.creation = sm.creation.exportToTable(args.creation, false, true)
    self.network:sendToClient(caller, "cl_exportCreation", args)
end

---@class ImportArgs
---@field items table<string, integer> items to be spent for the import
---@field money number price of the import
---@field name string name of the imported creation
---@field pos Vec3 spawn position of the creation
---@param args ImportArgs
function FactoryLift:sv_importCreation(args, caller)
    if not MoneyManager.sv_trySpendMoney(args.money) then return end

    local inv = caller:getInventory()
    sm.container.beginTransaction()
    for uuid, amount in pairs(args.items) do
        sm.container.spend(inv, sm.uuid.new(uuid), amount)
    end
    sm.container.endTransaction()

    local bodies = sm.creation.importFromFile(
        caller.character:getWorld(),
        self:getCreationPath(args.name),
        args.pos + sm.vec3.new(0, 0, 100)
    )

    local placeable, level = sm.tool.checkLiftCollision(bodies, args.pos, 1)
    if placeable then
        caller:placeLift(bodies, args.pos, level, 1)
    else
        self.network:sendToClient(caller, "cl_setSelectedBodies", bodies)
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

--characters to be avoided during export
local specialCharacters = {
    "~", "`", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
    "+", "=", "{", "}", "[", "]", "|", "\\", "/", ":", ";", '"',
    "'", "<", ">", ",", ".", "?"
}

function FactoryLift:client_onCreate()
    Lift.client_init(self)

    if not self.tool:isLocal() then return end

    self.cl = {}
    self.cl.exportGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Factory_export.layout")
    self.cl.exportGui:setTextChangedCallback("name", "cl_export_setName")
    self.cl.exportGui:setButtonCallback("cancel", "cl_export_cancel")
    self.cl.exportGui:setButtonCallback("ok", "cl_export_confirm")
    self.cl.exportGui:setOnCloseCallback("cl_export_cancel")

    self.cl.exportName = ""
    self.cl.exportCreation = nil
    self.cl.importCreation = nil

    self:cl_resetImportOptions()
end

---@param args {name: string, creation: table}
function FactoryLift:cl_exportCreation(args)
    local path = self:getCreationPath(args.name)
    sm.json.save(args.creation, path)

    local creations = sm.json.fileExists(exportedCreations) and sm.json.open(exportedCreations) or {}
    if not isAnyOf(path, creations) then
        creations[#creations + 1] = path
        sm.json.save(creations, exportedCreations)
    end

    self:cl_resetImportOptions()
end

---place a creation on the lift tool thingy
---@param bodies table<integer, Body>
function FactoryLift:cl_setSelectedBodies(bodies)
    self.selectedBodies = bodies
end

function FactoryLift:client_onEquippedUpdate(primaryState, secondaryState, forceBuild)
    if self.tool:isLocal() then
        local hit, result = sm.localPlayer.getRaycast(7.5)
        Lift.client_interact(self, primaryState, secondaryState, result)

        if hit then
            if result.type == "body" then
                --export gui
                sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), language_tag("ExportInteraction"))
                if forceBuild and not self.cl.exportGui:isActive() then
                    self.cl.exportCreation = result:getBody()
                    self.cl.exportGui:setText("title", language_tag("ExportTitle"))
                    self.cl.exportGui:open()
                end
            elseif result.type == "lift" then
                --import gui
                if forceBuild and not self.importGui:isActive() then
                    self:cl_import_updateItemGrid(self.cl.importCreation, false)
                    self.importGui:setText("nothing", language_tag("ImportNone"))
                    self.importGui:setText("title", language_tag("ImportTitle"))
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
        sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true) .. "#{INTERACTION_USE}", import, "")
    end
end

function FactoryLift:cl_resetImportOptions()
    local options = self:cl_import_createUI()
    if #options > 0 then
        self.cl.importCreation = options[1]
        self:cl_import_updateItemGrid(options[1])
    end
end

function FactoryLift:cl_export_setName(widget, text)
    local stripped = text
    for k, v in pairs(specialCharacters) do
        stripped = stripped:gsub("%" .. v, "")
    end

    self.cl.exportGui:setText("name", stripped)
    self.cl.exportName = stripped
end

function FactoryLift:cl_export_cancel()
    self.cl.exportGui:close()
    self.cl.exportGui:setText("name", "")

    --we do a little jank (in case of confirmClearGui we want to hold on to these dear variables a little longer)
    if self.confirmClearGui then return end
    self.cl.exportName = ""
    self.cl.exportCreation = nil
end

---@param override boolean if true will override existing creatons
function FactoryLift:cl_export_confirm(widget, override)
    if self.cl.exportName == "" then
        sm.gui.chatMessage("#ff0000" .. language_tag("InvalidName"))
        sm.audio.play("RaftShark")
        return
    end

    if not override and
        sm.json.fileExists(self:getCreationPath(self.cl.exportName)) then
        self.confirmClearGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout")
        self.confirmClearGui:setButtonCallback("Yes", "cl_export_overwriteButtonClick")
        self.confirmClearGui:setButtonCallback("No", "cl_export_overwriteButtonClick")
        self.confirmClearGui:setText("Title", "#{MENU_YN_TITLE_ARE_YOU_SURE}")
        self.confirmClearGui:setText("Message", language_tag("ExportBlueprintExists"):format(self.cl.exportName))

        self.cl.exportGui:close()
        self.confirmClearGui:open()

        return
    end

    self.network:sendToServer("sv_exportCreation", { name = self.cl.exportName, creation = self.cl.exportCreation })
    self:cl_export_cancel()
    sm.gui.displayAlertText(language_tag("ExportedCreation"))
    sm.audio.play("Blueprint - Save")
end

function FactoryLift:cl_export_overwriteButtonClick(name)
    if name == "Yes" then
        self.confirmClearGui:close()
        self:cl_export_confirm("", true)
    elseif name == "No" then
        self.confirmClearGui:close()
        self.cl.exportGui:open()
    end

    self.confirmClearGui:destroy()
    self.confirmClearGui = nil
end

function FactoryLift:cl_import_createUI()
    self.importGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Factory_import.layout")
    self.importGui:setButtonCallback("import", "cl_import_importCreation")

    local options = {}
    local creations = sm.json.fileExists(exportedCreations) and sm.json.open(exportedCreations) or {}
    local noBlueprints = #creations == 0
    self.importGui:setVisible("creation", not noBlueprints)
    self.importGui:setVisible("import", not noBlueprints)
    self.importGui:setVisible("nothing", noBlueprints)

    if not noBlueprints then
        for k, path in pairs(creations) do
            options[#options + 1] = string.gsub(string.match(path, "[^/]*$"), "%.json$", "")
        end

        self.importGui:createDropDown(
            "creation",
            "cl_import_select",
            options
        )
    end

    return options
end

function FactoryLift:cl_import_select(option)
    if self.cl.importCreation ~= option then
        self.cl.importCreation = option
        self.importGui:close()

        self:cl_import_createUI()
        self:cl_import_updateItemGrid(option)
        ---@diagnostic disable-next-line: redundant-parameter
        self.importGui:setSelectedDropDownItem("creation", option)
        self.importGui:open()
    end
end

function FactoryLift:cl_import_updateItemGrid(name, createGrid)
    local inv = sm.localPlayer.getInventory()
    self.importGui:setContainer("", inv)

    local items = {}
    if name then
        items = self:getBlueprintItems(name)
        if createGrid == nil then
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
    end

    local count = 0
    for uuid, amount in pairs(items) do
        self.importGui:setGridItem(
            "inventory",
            count,
            {
                itemId = uuid,
                quantity = amount,
            }
        )

        count = count + 1
    end

    local canImport, missingMoney, ownedItems = self:getImportStats(items)
    self.importGui:setVisible("import", canImport)
    self.importGui:setText("money",
        language_tag("ImportNeededMoney") .. format_number({ format = "money", value = missingMoney }))
end

function FactoryLift:cl_import_importCreation()
    if self.cl.importCreation == nil then return end

    local canImport, missingMoney, ownedItems = self:getImportStats(self:getBlueprintItems(self.cl.importCreation))

    self.network:sendToServer("sv_importCreation",
        {
            name = self.cl.importCreation,
            pos = self.liftPos,
            items = ownedItems,
            money = missingMoney
        }
    )
    sm.gui.displayAlertText(language_tag("ImportedCreation"))
    sm.audio.play("Blueprint - Open")
    self.importGui:close()
end

---@return table<string?, integer>
function FactoryLift:getBlueprintItems(name)
    local blueprint = sm.json.open(self:getCreationPath(name))
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

---returns info about the creation to be imported
---@param items table<string, integer> uuid, amount
---@return boolean canAfford whehter enough money is available to import
---@return integer price price to pay to "buy" the missing items
---@return table<string, integer> items items provided by the inventory for import
function FactoryLift:getImportStats(items)
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

    return (neededMoney == 0 or MoneyManager.getMoney() >= neededMoney) and GetActualLength(items) > 0, neededMoney,
        ownedItems
end

---returns the number of items in a table
function GetActualLength(table)
    local count = 0
    for k, v in pairs(table) do
        count = count + 1
    end

    return count
end

-- #endregion

---returns the path to a json file for a creation with that `name`
function FactoryLift:getCreationPath(name)
    return string.format("$CONTENT_DATA/UserData/ExportedCreations/%s.json", name)
end

--------------------
-- #region Types
--------------------

---@class FactoryLiftCl
---@field exportGui GuiInterface gui for exporting creations
---@field exportName string name of the creation to be exported
---@field exportCreation Body creation to be exported when looking at it via the lift
---@field importCreation string name of the creation to be imported via the lift

-- #endregion
