dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
local renderables = { "$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook.rend" }
local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_tp_animlist.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_fp_animlist.rend" }
dofile("$CONTENT_DATA/Scripts/util/util.lua")
sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

---@class page
---@field uuid string
---@field price number
---@field category string

---@class client;
---@field gui GuiInterface
---@field filteredPages page[][]
---@field itemPages page[][]
---amount of pages
---@field pageNum number
---current page
---@field curPage number
---current item
---@field curItem number
---current quantity
---@field quantity number


---@class Shop : ScriptableObjectClass
---@field cl client

Shop = class()

function Shop:client_onCreate()
	if not g_cl_shop then
		g_cl_shop = self
	end

	self.cl = {}
	self.cl.shopGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/shop.layout")
	self.cl.shopGui:setOnCloseCallback("cl_onGuiClosed")

	self.cl.pageNum = math.floor(#g_shop / 32) == 0 and 1 or
		math.floor(#g_shop / 32)
	self.cl.curPage = 1
	self.cl.curItem = 1
	self.cl.quantity = 1
	self.cl.shopGui:setButtonState("Buy_x1", true)
	self.cl.shopGui:setText("PageNum", tostring(self.cl.curPage) .. "/" .. tostring(self.cl.pageNum))
	self.cl.shopGui:setButtonCallback("BuyBtn", "cl_buyItem")
	self.cl.shopGui:setButtonCallback("Buy_x1", "changeQuantity")
	self.cl.shopGui:setButtonCallback("Buy_x10", "changeQuantity")
	self.cl.shopGui:setButtonCallback("Buy_x100", "changeQuantity")
	self.cl.shopGui:setButtonCallback("Buy_x999", "changeQuantity")
	self.cl.shopGui:setButtonCallback("AllTab", "changeCategory")
	self.cl.shopGui:setButtonCallback("DroppersTab", "changeCategory")
	self.cl.shopGui:setButtonCallback("UpgradesTab", "changeCategory")
	self.cl.shopGui:setButtonCallback("FurnacesTab", "changeCategory")
	self.cl.shopGui:setButtonCallback("GeneratorsTab", "changeCategory")
	self.cl.shopGui:setButtonCallback("UtilitiesTab", "changeCategory")
	self.cl.shopGui:setButtonCallback("DecorTab", "changeCategory")
	self.cl.shopGui:setButtonCallback("NextPage", "changePage")
	self.cl.shopGui:setButtonCallback("LastPage", "changePage")
	--self.cl.shopGui:setButtonCallback("research", "openReserch")
	self:changeQuantity("Buy_x1")
	self.cl.itemPages = { {} }
	self.cl.filteredPages = { {} }
	local pages = {}
	for k, v in pairs(g_shop) do
		table.insert(pages, { uuid = k, price = v.price, category = v.category })
	end
	table.sort(pages, function(a, b)
		return a.price < b.price
	end)
	local page = 1;
	for i, v in pairs(pages) do
		table.insert(self.cl.itemPages[page], v)
		if i % 32 == 0 then
			page = page + 1
		end
	end
	for i = 1, 32 do
		self.cl.shopGui:setButtonCallback("Item_" .. i, "changeItem")
	end
	self:gui_filter("All")
	self:gen_page(self.cl.curPage)
	self:changeItem("Item_" .. self.cl.curItem)
end

function Shop:gen_page(num)
	print("Page Gen")
	local pageLen = #self.cl.filteredPages[num]
	for i = 1, 32 do
		self.cl.shopGui:setVisible("Item_" .. tostring(i), true)
		self.cl.shopGui:setVisible("ItemPrice_" .. tostring(i), true)
	end
	for i, v in pairs(self.cl.filteredPages[num]) do
		self.cl.shopGui:setIconImage("ItemPic_" .. tostring(i), sm.uuid.new(v.uuid))
		self.cl.shopGui:setText("ItemPrice_" .. tostring(i), format_money({money = v.price}))
	end
	if pageLen == 32 then return end
	for i = pageLen + 1, 32 do
		self.cl.shopGui:setVisible("Item_" .. tostring(i), false)
		self.cl.shopGui:setVisible("ItemPrice_" .. tostring(i), false)
	end

end

---@param category string
function Shop:gui_filter(category)
	self.cl.filteredPages = { {} }
	if category == "All" then
		self.cl.filteredPages = self.cl.itemPages
		return
	end
	local page = 1
	for i, v in pairs(self.cl.itemPages) do
		for i, v in pairs(v) do
			if v.category == category then
				table.insert(self.cl.filteredPages[page], v)
			end
		end
		if i % 32 then
			page = page + 1
		end
	end
end

---@param itemName string
function Shop:changeItem(itemName)
	self.cl.shopGui:setButtonState("Item_" .. self.cl.curItem, false)
	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.curItem = tonumber(string.reverse(string.sub(string.reverse(itemName), 1, #itemName - 5)))
	local uuid = sm.uuid.new(self.cl.filteredPages[self.cl.curPage][self.cl.curItem].uuid)
	self.cl.shopGui:setButtonState(itemName, true)
	self.cl.shopGui:setMeshPreview("Preview", uuid)
	self.cl.shopGui:setText("ItemName", sm.shape.getShapeTitle(uuid))
	self.cl.shopGui:setText("ItemDesc", sm.shape.getShapeDescription(uuid))
end

function Shop:changePage(wigetName)
	if wigetName == "NextPage" then
		if self.cl.curPage == self.cl.pageNum then
			return
		end
		self.cl.curPage = self.cl.curPage + 1
	elseif wigetName == "LastPage" then
		if self.cl.curPage == 1 then
			return
		end
		self.cl.curPage = self.cl.curPage - 1
	end
	self.cl.curItem = 1
	self:gen_page(self.cl.curPage)
	self:changeItem("Item_1")
end

---@param wigetName string
function Shop:changeQuantity(wigetName)
	self.cl.shopGui:setButtonState("Buy_x" .. tostring(self.cl.quantity), false)
	self.cl.shopGui:setText("Buy_x" .. tostring(self.cl.quantity), "#ffffffx" .. self.cl.quantity)
	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.quantity = tonumber(string.reverse(string.sub(string.reverse(wigetName), 1, #wigetName - 5)))
	self.cl.shopGui:setButtonState(wigetName, true)
	self.cl.shopGui:setText(wigetName, "#4f4f4fx" .. self.cl.quantity)
end

function Shop:cl_buyItem()
	self.network:sendToServer("sv_buyItem",
		{ price = tostring(self.cl.filteredPages[self.cl.curPage][self.cl.curItem].price),
			uuid = self.cl.filteredPages[self.cl.curPage][self.cl.curItem].uuid, quantity = self.cl.quantity })
end

function Shop:changeCategory(categoryName)
	local category = string.sub(categoryName, 1, -4)
	self:gui_filter(category)
	self.cl.curPage = 1
	self:changeItem("Item_1")
	self:gen_page(self.cl.curPage)
end

function Shop:sv_buyItem(params, player)
	params.player = player
	local price = tonumber(params.price) * params.quantity

	if MoneyManager.sv_spendMoney(price) then
		sm.event.sendToGame("sv_giveItem", { player = params.player, item = sm.uuid.new(params.uuid), quantity = params.quantity })
	else
		--TODO Inform player that they poor (also use language tag)
		sm.event.sendToPlayer(player, "sv_e_onMsg", "You are very poor")
	end
end

function Shop:cl_onGuiClosed()
	g_cl_shop.guiActive = false
end

function Shop:cl_e_open_gui()
	g_cl_shop.guiActive = true
	g_cl_shop.cl.shopGui:open()
end

function Shop:cl_e_isGuiOpen()
	return g_cl_shop.guiActive
end