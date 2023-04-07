dofile("$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua")

---@class OldUnitManager : ScriptableObjectClass
---@diagnostic disable-next-line: param-type-mismatch
OldUnitManager = class(UnitManager)

---@class UnitManager : OldUnitManager
---@field cl UnitManagerCl
---@field sv table
---@diagnostic disable-next-line: param-type-mismatch
UnitManager = class(UnitManager)

--------------------
-- #region Server
--------------------

function UnitManager.sv_onWorldFixedUpdate(self, worldSelf)
	--Inform player of incoming raids
	if self.cl.loadTick then
		for _, player in ipairs(self.newPlayers) do
			print("Informing player", player.id, "about incoming raids.")
			for _, cropAttackCell in pairs(self.sv.cropAttackCells) do
				if cropAttackCell.saved.attackTick then
					print("Sending info about raid at (" .. cropAttackCell.x .. "," .. cropAttackCell.y .. ") to player",
						player.id)
					worldSelf.network:sendToClient(player, "cl_n_unitMsg",
						{
							fn = "cl_n_detected",
							tick = cropAttackCell.saved.attackTick,
							pos = cropAttackCell.saved.attackPos
						})
				end
			end
		end
		self.newPlayers = {}

		---@diagnostic disable-next-line: undefined-field
		OldUnitManager.sv_onWorldFixedUpdate(self, worldSelf)
	end
end

--------------------
-- #region Client
--------------------

function UnitManager.cl_n_detected(self, msg)
	sm.gui.displayAlertText(language_tag("RaidWarning"), 10)

	-- #region COPIED

	local gui = sm.gui.createNameTagGui()
	gui:setWorldPosition(msg.pos + sm.vec3.new(0, 0, 0.5))
	gui:setRequireLineOfSight(false)
	gui:open()
	gui:setMaxRenderDistance(500)
	gui:setText("Text", "#ff0000" .. formatCountdown((msg.tick - sm.game.getServerTick()) / 40))

	self.cl.attacks[#self.cl.attacks + 1] = { gui = gui, tick = msg.tick }
	-- #endregion
end

function UnitManager:cl_setloadTick(tick)
	--This only handles a few raid counters. May need to improve system if more raids are desired.
	self.cl.loadTick = tick
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class UnitManagerCl
---@field loadTick number the tick at which the game was loaded
---@field attacks table

-- #endregion
