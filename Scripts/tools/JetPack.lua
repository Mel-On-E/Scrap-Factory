---A Jetpack that can be used to fly around the world
---@class Jetpack : ToolClass
---@field cl JetpackCl
---@field sv JetpackSv
Jetpack = class()

---factor for the movementSpeed appplied by the Jetpack
local movementSpeedBoost = 16
---maximum velocity at which a player gets boosted
local speedBoostLimit = 25

--------------------
-- #region Server
--------------------

function Jetpack:server_onCreate()
	self.sv = {
		active = false,
	}
end

function Jetpack:server_onFixedUpdate()
	if not self.sv.active then
		return
	end

	local character = self.tool:getOwner():getCharacter()
	local vel = character:getVelocity()
	vel.z = 0

	if vel:length() < speedBoostLimit then
		sm.physics.applyImpulse(character, vel * movementSpeedBoost)
	end
end

function Jetpack:sv_toggleJetpack()
	self.sv.active = not self.sv.active

	local character = self.tool:getOwner():getCharacter()
	character:setSwimming(self.sv.active)
end

function Jetpack:sv_createEffect(params)
	Effects.sv_createEffect(self, params)
end

function Jetpack:sv_toggleEffect(params)
	Effects.sv_toggleEffect(self, params)
end

-- #endregion

--------------------
-- #region Client
--------------------

local maxFuel = 100
local fuel = maxFuel
local fuelBurnRatePerSecond = 10
local fuelRestoreRatePerSecond = 25
---timet to wait before fuel can recharge
local fuelRechargeCooldown = 0.5

function Jetpack:client_onCreate()
	self.cl = {
		alwaysOn = false,
		active = false,
		fuelRechargeCooldown = 0,
	}

	Effects.cl_init(self)

	self.network:sendToServer("sv_createEffect", {
		key = "Jetpack" .. tostring(self.tool:getOwner().id),
		effect = "Jetpack Thruster",
		host = self.tool:getOwner():getCharacter(),
		boneName = "jnt_hips",
		notStart = true,
	})
end

function Jetpack:client_onEquippedUpdate(primaryState, secondaryState)
	if self.tool:isLocal() then
		if primaryState == sm.tool.interactState.start then
			if not (not self.cl.active and fuel == 0) then
				self:cl_toggleJetpack()
			end
		end

		if secondaryState == sm.tool.interactState.start then
			self.cl.alwaysOn = not self.cl.alwaysOn
			sm.gui.displayAlertText(language_tag("JetpackAlwaysOn") .. language_tag(self.cl.alwaysOn and "ON" or "OFF"))
		end
	end

	return true, true
end

function Jetpack:client_onFixedUpdate()
	if not self.tool:isLocal() or not self.cl.active then
		return
	end
	if fuel > 0 then
		local character = self.tool:getOwner():getCharacter()
		local vel = character:getVelocity()
		vel.z = 0

		if vel:length() < speedBoostLimit and not sm.isHost then
			sm.physics.applyImpulse(character, vel * movementSpeedBoost)
		end
	else
		self:cl_toggleJetpack()
	end
end

function Jetpack:client_onUpdate(dt)
	if not self.tool:isLocal() then
		return
	end

	self.cl.fuelRechargeCooldown = math.max(self.cl.fuelRechargeCooldown - dt, 0)
	local char = self.tool:getOwner():getCharacter()
	---@diagnostic disable-next-line: missing-parameter
	if char:isSwimming() then
		self.cl.fuelRechargeCooldown = fuelRechargeCooldown
	end

	if self.cl.active then
		fuel = math.max(fuel - fuelBurnRatePerSecond * dt, 0)
		---@diagnostic disable-next-line: missing-parameter
	elseif self.tool:isOnGround() and self.cl.fuelRechargeCooldown == 0 and not char:isSwimming() and not char:isTumbling() then
		fuel = math.min(fuel + fuelRestoreRatePerSecond * dt, maxFuel)
	end

	if fuel < maxFuel then
		sm.gui.setProgressFraction(fuel / maxFuel)
	end
end

function Jetpack:cl_toggleJetpack()
	---@diagnostic disable-next-line: missing-parameter
	if not self.cl.active and self.tool:getOwner():getCharacter():isSwimming() then
		-- only one Jetpack can be used at a time
		return
	end
	self.cl.active = not self.cl.active

	--remove some fuel to prevent bugs and limit spamming
	fuel = math.max(fuel - fuelBurnRatePerSecond * 0.5, 0)

	self.network:sendToServer("sv_toggleJetpack")

	self.network:sendToServer("sv_toggleEffect", "Jetpack" .. tostring(self.tool:getOwner().id))
end

function Jetpack:client_onUnequip()
	if not self.cl.alwaysOn and self.cl.active then
		self:cl_toggleJetpack()
	end
end

function Jetpack:cl_createEffect(params)
	Effects.cl_createEffect(self, params)
end

function Jetpack:cl_toggleEffect(params)
	Effects.cl_toggleEffect(self, params)
end

--- #endregion

--------------------
-- #region Types
--------------------

---@class JetpackCl
---@field alwaysOn boolean whether the Jetpack should be always active when equipped
---@field active boolean whether the Jetpack is currently on
---@field fuel number amount of fuel in the Jetpack
---@field fuelRechargeCooldown number seconds to wait before fuel can recharge

---@class JetpackSv
---@field active boolean whether the Jetpack is active for the owner

-- #endregion
