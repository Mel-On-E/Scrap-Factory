dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Interface.lua")

---The perksshop is a submenu of the Prestige interface. Which really makes it kinda cursed. But eh, just ignore it.
---@class Perks : Interface
---@field cl PerksCl
Perks = class(Interface)

--------------------
-- #region Server
--------------------

function Perks:sv_buyPerk(perk, player)
	if PrestigeManager.sv_trySpendPrestige(perk.price) then
		PerkManager.sv_addPerk(perk)
		self.network:sendToClient(player, "cl_openPerkGui")
	end
end

-- #endregion

--------------------
-- #region Client
--------------------

---@type integer number of items each page of the gui can show at max
local ITEMS_PER_PAGE = 32
local IMAGE_PATH = "$CONTENT_DATA/Gui/Images/Perks/"

function Perks:client_onCreate()
	self.cl.curPage = 1
	self.cl.curItem = 1
	self.cl.category = "All"
	self.cl.sortHighest = false
	self.cl.sortedPerks = {}
	self.cl.renderedPages = {}
	self.cl.perkGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PerkShop.layout")
	self:cl_setupSortedPerks()

	local tabs = { "AllTab", "OwnedTab", "UnlockedTab", "LockedTab" }
	Interface.setupButtons(self.cl.perkGui, tabs, "cl_changeCategory")
	Interface.setupButtons(self.cl.perkGui, { "NextPage", "LastPage" }, "cl_changePage")

	self.cl.perkGui:setButtonCallback("SortBtn", "changeSort")
	self.cl.perkGui:setButtonCallback("BuyButton", "cl_buyPerk")

	for i = 1, ITEMS_PER_PAGE do
		self.cl.perkGui:setButtonCallback("Item_" .. i, "cl_changeItem")
	end
end

---Create a list of perks sorted by price in `self.cl.sortedPerks`
function Perks:cl_setupSortedPerks()
	local perksJson = unpackNetworkData(sm.json.open("$CONTENT_DATA/Scripts/perks.json"))
	for name, perk in pairs(perksJson) do
		perk.name = name
		table.insert(self.cl.sortedPerks, perk)
	end

	table.sort(self.cl.sortedPerks, function(a, b)
		return a.price > b.price
	end)
end

function Perks:client_onFixedUpdate()
	if self.cl.perkGui:isActive() then
		Perks.update_gui(self)
	end
end

function Perks:cl_openPerkGui()
	---language stuff
	self.cl.perkGui:setText("Title", language_tag("Perks"))
	self.cl.perkGui:setText("AllTab", language_tag("AllTab"))
	self.cl.perkGui:setText("OwnedTab", language_tag("PerksOwned"))
	self.cl.perkGui:setText("UnlockedTab", language_tag("PerksUnlocked"))
	self.cl.perkGui:setText("LockedTab", language_tag("PerksLocked"))
	self.cl.perkGui:setText("Requirements", language_tag("PerkRequirements"))
	self.cl.perkGui:setText("BuyButton", language_tag("Buy"))

	Perks.update_gui(self)
	self:gui_renderPages()
	self:gui_displayPage()

	self.cl.perkGui:open()
end

function Perks:update_gui()
	self.cl.perkGui:setText("Balance", language_tag("PerksBalance") ..
		format_number({ format = "prestige", value = PrestigeManager.cl_getPrestige() }))
	self.cl.perkGui:setText("PageNum", tostring(self.cl.curPage) .. "/" .. tostring(#self.cl.renderedPages))
end

function Perks:cl_changePage(widgetName)
	if widgetName == "NextPage" then
		self.cl.curPage = math.min(self.cl.curPage + 1, #self.cl.renderedPages)
	elseif widgetName == "LastPage" then
		self.cl.curPage = math.max(self.cl.curPage - 1, 1)
	else
		return
	end

	self:gui_displayPage()
end

function Perks:cl_changeCategory(categoryName)
	local category = string.sub(categoryName, 1, -4)
	self.cl.category = category

	self:gui_renderPages()
	self:gui_displayPage()
end

function Perks:cl_changeItem(widgetName)
	self.cl.perkGui:setButtonState("Item_" .. self.cl.curItem, false)

	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.curItem = tonumber(widgetName:sub(6))

	local item = self.cl.renderedPages[self.cl.curPage][self.cl.curItem]
	self.cl.perkGui:setVisible("BuyButton", item and true)

	if not item then
		self.cl.perkGui:setVisible("Preview", false)
		self.cl.perkGui:setText("ItemName", "")
		self.cl.perkGui:setText("ItemDesc", "")
		self.cl.perkGui:setText("Requires", "")
		return
	end

	self.cl.perkGui:setButtonState(widgetName, true)
	self.cl.perkGui:setVisible("Preview", true)
	self.cl.perkGui:setImage("Preview", IMAGE_PATH .. item.name .. ".png")
	self.cl.perkGui:setText("ItemName", language_tag(item.name .. "Name"))
	self.cl.perkGui:setText("ItemDesc", language_tag(item.name .. "Desc"))
	local requirements = ""
	for _, requirement in ipairs(item.requires) do
		local color = (PerkManager.isPerkOwned(requirement) and "#00aa00") or "#aa0000"
		requirements = requirements .. color .. "- " .. language_tag(requirement .. "Name") .. "\n"
	end
	self.cl.perkGui:setText("Requires", requirements)

	local buyText = "Buy"
	if PerkManager.isPerkOwned(item.name) then
		buyText = "PerksOwned"
	elseif not PerkManager.isPerkUnlocked(item.name) then
		buyText = "PerksLocked"
	end

	self.cl.perkGui:setText("BuyButton", language_tag(buyText))
end

function Perks:changeSort()
	self.cl.sortHighest = not self.cl.sortHighest

	self.cl.perkGui:setText("SortText",
		not self.cl.sortHighest and language_tag("SortHighest") or language_tag("SortLowest"))

	self:gui_renderPages()
	self:gui_displayPage()
end

function Perks:cl_buyPerk()
	local item = self.cl.renderedPages[self.cl.curPage][self.cl.curItem]

	if PerkManager.isPerkOwned(item.name) then
		return
	elseif not PerkManager.isPerkUnlocked(item.name) then
		return
	end

	if item.price < PrestigeManager.cl_getPrestige() then
		self.network:sendToServer("sv_buyPerk", item)
	else
		sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_playAudio", "RaftShark")
	end
end

-- #endregion

---Render all pages based on tiers, sort and category
function Perks:gui_renderPages()
	self.cl.curPage = 1

	self.cl.renderedPages = { {} }

	--Clear the blocked tier items and different category items
	local availablePerks = {}

	for _, perk in pairs(self.cl.sortedPerks) do
		local check = true

		if self.cl.category == "Owned" then
			check = PerkManager.isPerkOwned(perk.name)
		elseif self.cl.category == "Locked" then
			check = not PerkManager.isPerkUnlocked(perk.name)
		elseif self.cl.category == "Unlocked" then
			check = PerkManager.isPerkUnlocked(perk.name) and not PerkManager.isPerkOwned(perk.name)
		end

		if check then
			table.insert(availablePerks, perk)
		end
	end

	--Sort
	if not self.cl.sortHighest then
		availablePerks = array_reverse(availablePerks)
	end

	--Generate pages
	local page = 1
	local i = 1
	for _, perk in pairs(availablePerks) do
		table.insert(self.cl.renderedPages[page], perk)

		i = i + 1
		if i % (ITEMS_PER_PAGE + 1) == 0 then --new page
			page = page + 1
			table.insert(self.cl.renderedPages, {})
		end
	end
end

function Perks:gui_displayPage()
	self:cl_changeItem("Item_1")

	local page = self.cl.renderedPages[self.cl.curPage]

	for i = 1, ITEMS_PER_PAGE do
		if page[i] == nil then
			self.cl.perkGui:setVisible("Item_" .. tostring(i), false)
			self.cl.perkGui:setVisible("ItemPrice_" .. tostring(i), false)
			self.cl.perkGui:setVisible("ItemLock_" .. tostring(i), false)

			goto continue
		end
		self.cl.perkGui:setVisible("Item_" .. tostring(i), true)
		self.cl.perkGui:setVisible("ItemPrice_" .. tostring(i), true)

		local perk = page[i]
		self.cl.perkGui:setImage("ItemPic_" .. tostring(i),
			IMAGE_PATH .. perk.name .. ((PerkManager.isPerkOwned(perk.name) and "") or "_locked") .. ".png")
		self.cl.perkGui:setText("ItemPrice_" .. tostring(i), format_number({ format = "prestige", value = perk.price }))
		self.cl.perkGui:setVisible("ItemLock_" .. tostring(i), not PerkManager.isPerkUnlocked(perk.name))

		::continue::
	end

	self.cl.perkGui:setText("PageNum", self.cl.curPage .. " / " .. #self.cl.renderedPages)
end

--------------------
-- #region Types
--------------------

---@class PerksCl
---@field curPage integer current page
---@field curItem integer the currently selected item in the perk shop
---@field category "All"|"Owned"|"Unlocked"|"Locked" current category of the perk shop
---@field sortHighest boolean wheter the shop is sorted ascending or descending
---@field perkGui GuiInterface the gui that shows the perk shop
---@field sortedPerks table<integer, PerkData> perks sorted by price descending
---@field renderedPages PerkData[] The rendered pages

---@class PerkData
---@field name string name of the perk
---@field price number price of the perk
---@field requires table<integer, string> array of perk names required
---@field effects table effects of the effect

-- #endregion
