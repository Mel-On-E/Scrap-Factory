dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Interface.lua")

---@class Perks
Perks = class(Interface)

local IMAGE_PATH = "$CONTENT_DATA/Gui/Images/Perks/"

function Perks:client_onCreate()
	self.cl.perkGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PerkShop.layout")

	self.cl.perkGui:setButtonCallback("NextPage", "changePage")
	self.cl.perkGui:setButtonCallback("LastPage", "changePage")
	self.cl.perkGui:setButtonCallback("SortBtn", "changeSort")

	self.cl.perkGui:setButtonCallback("AllTab", "changeCategory")
	self.cl.perkGui:setButtonCallback("OwnedTab", "changeCategory")
	self.cl.perkGui:setButtonCallback("UnlockedTab", "changeCategory")
	self.cl.perkGui:setButtonCallback("LockedTab", "changeCategory")

	for i = 1, 32 do
		self.cl.perkGui:setButtonCallback("Item_" .. i, "changeItem")
	end

	self.cl.curPage = 1
	self.cl.curItem = 1
	self.cl.category = "All"
	self.cl.sortLowest = true

	self.perks = sm.json.open("$CONTENT_DATA/Scripts/perks.json")

	self.cl.pageNum = math.floor(#self.perks / 32) == 0 and 1 or
		math.floor(#self.perks / 32)
end

function Perks:client_onFixedUpdate()
	if self.cl.perkGui:isActive() then
		Perks.update_gui(self)
	end
end

function Perks:cl_openPerkGui()
	self.cl.perkGui:setText("Title", language_tag("Perks"))
	self.cl.perkGui:setText("AllTab", language_tag("AllTab"))
	self.cl.perkGui:setText("OwnedTab", language_tag("PerksOwned"))
	self.cl.perkGui:setText("UnlockedTab", language_tag("PerksUnlocked"))
	self.cl.perkGui:setText("LockedTab", language_tag("PerksLocked"))
	self.cl.perkGui:setText("Requirements", language_tag("PerkRequirements"))
	self.cl.perkGui:setText("BuyButton", language_tag("Buy"))

	self:sort()

	Perks.update_gui(self)

	self.cl.perkGui:open()
end

function Perks:update_gui()
	self.cl.perkGui:setText("Balance", language_tag("PerksBalance") .. 
		format_number({ format = "prestige", value = PrestigeManager.cl_getPrestige()}))
	self.cl.perkGui:setText("PageNum", tostring(self.cl.curPage) .. "/" .. tostring(self.cl.pageNum))
end



function Perks:gen_page(num)
	local pageLen = #self.cl.filteredPages[num]
	for i = 1, 32 do
		self.cl.perkGui:setVisible("Item_" .. tostring(i), true)
		self.cl.perkGui:setVisible("ItemPrice_" .. tostring(i), true)
	end
	for i, v in pairs(self.cl.filteredPages[num]) do
		self.cl.perkGui:setImage("ItemPic_" .. tostring(i), IMAGE_PATH .. v.image)
		self.cl.perkGui:setText("ItemPrice_" .. tostring(i), format_number({ format = "prestige", value = v.price }))
	end
	if pageLen == 32 then return end
	for i = pageLen + 1, 32 do
		self.cl.perkGui:setVisible("Item_" .. tostring(i), false)
		self.cl.perkGui:setVisible("ItemPrice_" .. tostring(i), false)
	end
end

function Perks:gui_filter(category)
	--TODO use a table with functions for each filter instead of duplication here
	self.cl.filteredPages = { {} }
	local page = 1
	if category == "All" then
		for i, v in pairs(self.cl.itemPages) do
			for _, v in pairs(v) do
				table.insert(self.cl.filteredPages[page], v)
			end
			if i % 32 then
				page = page + 1
			end
		end
		return
	elseif category == "Owned" then
		for i, v in pairs(self.cl.itemPages) do
			for _, v in pairs(v) do
				if PerkManager.isPerkOwned(v.name) then
					table.insert(self.cl.filteredPages[page], v)
				end
			end
			if i % 32 then
				page = page + 1
			end
		end
		return
	elseif category == "Unlocked" then
		for i, v in pairs(self.cl.itemPages) do
			for _, v in pairs(v) do
				if self.isUnlocked(v) then
					table.insert(self.cl.filteredPages[page], v)
				end
			end
			if i % 32 then
				page = page + 1
			end
		end
		return
	elseif category == "Locked" then
		for i, v in pairs(self.cl.itemPages) do
			for _, v in pairs(v) do
				if not self.isUnlocked(v) then
					table.insert(self.cl.filteredPages[page], v)
				end
			end
			if i % 32 then
				page = page + 1
			end
		end
		return
	end


	for i, v in pairs(self.cl.itemPages) do
		for _, v in pairs(v) do

			if (v.category == category) and (tier == 0 and true or (v.tier == tier)) then
				table.insert(self.cl.filteredPages[page], v)
			end
		end
		if i % 32 then
			page = page + 1
		end
	end
end

function Perks.isUnlocked(perk)
	local unlocked = true
	for _, requirement in ipairs(perk.requires) do
		if not PerkManager.isPerkOwned(requirement) then
			unlocked = false
		end
	end
	return unlocked
end

function Perks:changePage()
	return
end

function Perks:changeCategory(categoryName)
	local category = string.sub(categoryName, 1, -4)
	self:gui_filter(category)
	self.cl.category = category

	self.cl.curPage = 1
	self:changeItem("Item_1")
	self:gen_page(self.cl.curPage)
end

function Perks:changeItem(itemName)
	if #self.cl.filteredPages[self.cl.curPage] > 0 then
		self.cl.perkGui:setButtonState("Item_" .. self.cl.curItem, false)
		---@diagnostic disable-next-line: assign-type-mismatch
		self.cl.curItem = tonumber(string.reverse(string.sub(string.reverse(itemName), 1, #itemName - 5)))

		local item = self.cl.filteredPages[self.cl.curPage][self.cl.curItem]
		--print(item)

		self.cl.perkGui:setButtonState(itemName, true)
		self.cl.perkGui:setText("ItemName", language_tag(item.name .. "Name"))
		self.cl.perkGui:setText("ItemDesc", language_tag(item.name .. "Desc"))
		local requirements = ""
		for _, requirement in ipairs(item.requires) do
			local color = PerkManager.isPerkOwned(item.name) and "#00aa00" or "#aa0000"
			requirements = requirements .. color .. "- " .. language_tag(requirement .. "Name") .. "\n"
		end
		self.cl.perkGui:setText("Requires", requirements)
	end
end

function Perks:changeSort()
	self.cl.sortLowest = not self.cl.sortLowest

	self:sort()
end

function Perks:sort()
	local pages = {}
	self.cl.itemPages = { {} }
	for k, v in pairs(self.perks) do
		table.insert(pages, {name = k, price = v.price, image = v.image, requires = v.requires})
	end
	table.sort(pages, function(a, b)
		if self.cl.sortLowest then
			return a.price < b.price
		end
		return a.price > b.price
	end)
	local page = 1;
	for i, v in pairs(pages) do
		table.insert(self.cl.itemPages[page], v)
		if i % 32 == 0 then
			page = page + 1
		end
	end

	self.cl.perkGui:setText("SortText", language_tag(self.cl.sortLowest and "SortLowest" or "SortHighest"))

	self:gui_filter(self.cl.category)
	self:gen_page(self.cl.curPage)
	self:changeItem("Item_1")
end