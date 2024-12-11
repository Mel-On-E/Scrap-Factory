SusEffect = class( nil )
SusEffect.maxParentCount = 1
SusEffect.connectionInput = sm.interactable.connectionType.logic
SusEffect.colorNormal = sm.color.new( 0x5D0092ff )
SusEffect.colorHighlight = sm.color.new( 0x8600D4ff )

local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end

    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 0.5 then return q end
	if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end

    return p
end

local function hsl2rgb(h, s, l)
	local r, g, b
	if s == 0 then
		r = l
		g = l
		b = l
	else
		local q = l < 0.5 and (l * (1 + s)) or (l + s - l * s)
		local p = 2 * l - q

		r = hue2rgb(p, q, h + 1/3)
		g = hue2rgb(p, q, h)
		b = hue2rgb(p, q, h - 1/3)
	end

	return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end

local function rgb2hex(r, g, b)
    return string.format("%02X%02X%02XFF", r, g, b)
end

function SusEffect.client_onCreate( self )
--	sm.effect.playEffect( "Sky - Cloud1", self.interactable.shape.worldPosition, nil, sm.quat.new( 0, 0, 0, 1 ), sm.vec3.new( 2, 2, 2 ) )

	self.h = 0
	self.s = 0
	self.effect = sm.effect.createEffect( "Drops - Pollution", self.interactable )
	self.effect:setParameter( "Color", self.shape:getColor() )
	--self.effect:setOffsetRotation( sm.quat.new( 0, 0, 0, 0 ) )
	self.rgb_switch = false
	self.prevColor = self.shape:getColor()
	self.reverse = false
end

function SusEffect.client_onUpdate( self, dt )
	local parent = self.interactable:getSingleParent()
	if not parent then return end
	if self.effect ~= nil and sm.exists(self.effect) then
		if parent:isActive() then
			if self.rgb_switch then
				self.effect:stop()
				if ( self.h >= 1 or self.s >= 1 ) or ( self.h <= -0.01 or self.s <= -0.01 ) then
					self.reverse = not self.reverse
				end
				if self.reverse then
					self.effect:setParameter( "Color", sm.color.new(rgb2hex(hsl2rgb(self.h, self.s, 0.5))) )
					self.h = self.h - 0.01
 					self.s = self.s - 0.01
				else
					self.effect:setParameter( "Color", sm.color.new(rgb2hex(hsl2rgb(self.h, self.s, 0.5))) )
					self.h = self.h + 0.01
 					self.s = self.s + 0.01
				end
				self.effect:start()
			else
				if not self.effect:isPlaying() then
					self.effect:setParameter( "Color", self.shape:getColor() )
					self.effect:start()
				end
				if self.prevColor ~= self.shape:getColor() then
					self.effect:stop()
					self.effect:setParameter( "Color", self.shape:getColor() )
					self.effect:start()
					self.prevColor = self.shape:getColor()
				end
			end
		else
			self.effect:stop()
		end
	else--[[
		self.effect = sm.effect.createEffect( "SUS", self.interactable )
		self.effect:setParameter( "Color", self.shape:getColor() )]]--
	end
end
--[[
function SusEffect.client_onInteract( self, character, state )
	if not state then return end
	self.rgb_switch = not self.rgb_switch
	if self.rgb_switch == false then
		self.effect:stop()
		self.effect:setParameter( "Color", self.shape:getColor() )
		self.effect:stop()
	end
end]]--

function SusEffect.client_onDestroy( self )
	self.effect:stop()
end

function SusEffect.client_onRefresh( self )
	print("--------------------------------------------------------")
	self:client_onCreate()
	self.effect:stop()
	sm.gui.displayAlertText( "SusEffect refreshed successfully!", 5 )
end