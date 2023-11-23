local Iv, Spec = IsValid, TEAM_SPECTATOR
local MStart = 0
local MEnd = 1
local BStart = 2
local BEnd = 3
local AnyCheat = 4
local Freestyle = 5
local NormalCheat = 6
local BonusCheat = 7
local SStart = 8
local SEnd = 9
local Restart = 10
local Velocity = 11

function ENT:Initialize()
	local BBOX = (self.max - self.min) / 2

	self:SetSolid( SOLID_BBOX )
	self:PhysicsInitBox( -BBOX, BBOX )
	self:SetCollisionBoundsWS( self.min, self.max )

	self:SetTrigger( true )
	self:DrawShadow( false )
	self:SetNotSolid( true )
	self:SetNoDraw( false )

	self.Phys = self:GetPhysicsObject()
	if Iv( self.Phys ) then
		self.Phys:Sleep()
		self.Phys:EnableCollisions( false )
	end
end

function ENT:StartTouch( ent )
	if not Iv( self ) or not Iv( ent ) then return end
	if ent:IsPlayer() and ent:Team() != Spec then
		local og = ent:IsOnGround()
		local zone = self.zonetype
		if zone == MStart and og then
			ent:ResetTimer( true, self )
		elseif zone == MEnd then
			ent:StopTimer( self )
		elseif zone == BStart and og then
			ent:BonusReset( true, self )
		elseif zone == BEnd then
			ent:BonusStop( self )
		elseif zone == SEnd then
			ent:StageEnd( self )
		elseif zone == SStart then
			ent:StageEnter( self )
		elseif zone == AnyCheat and ent.Style != Core.Config.Style.Cheater then
			ent:StopAnyTimer( self )
		elseif zone == Freestyle then
			ent:StartFreestyle()
		elseif zone == NormalCheat and ent.Style != Core.Config.Style.Cheater then
			ent:ResetTimer()
		elseif zone == BonusCheat and ent.Style != Core.Config.Style.Cheater then
			ent:BonusReset()
		elseif zone == Restart then
			ent:ResetSpawnPosition( nil, self )
		elseif zone == Velocity then
			ent:ProcessVelocityZone( self )
		end
	end
end

function ENT:Touch( ent )
	if not Iv( self ) or not Iv( ent ) then return end
	if ent:IsPlayer() and ent:Team() != Spec then
		local zone = self.zonetype
		if zone == MStart then
			if ent:IsOnGround() then
				ent:ResetTimer( true, self )
			elseif not ent.Tn then
				ent:StartTimer( self )
			end
		elseif zone == BStart then
			if ent:IsOnGround() then
				ent:BonusReset( true, self )
			elseif not ent.Tb then
				ent:BonusStart( self )
			end
		end
	end
end

function ENT:EndTouch( ent )
	if not Iv( self ) or not Iv( ent ) then return end
	if ent:IsPlayer() and ent:Team() != Spec then
		local zone = self.zonetype
		local og = ent:IsOnGround()
		if zone == MStart and not ent.Tn then
			ent:StartTimer( self )
		elseif zone == BStart and not ent.Tb then
			ent:BonusStart( self )
		elseif zone == SStart then
			ent:StageBegin( self )
		elseif zone == SEnd and og then
			ent:StageReset( true )
		elseif zone == Freestyle then
			ent:StopFreestyle()
		elseif zone == AnyCheat and ent.Style != Core.Config.Style.Cheater then
			ent:StopAnyTimer( self )
		elseif zone == NormalCheat and ent.Style != Core.Config.Style.Cheater then
			ent:ResetTimer()
		elseif zone == BonusCheat and ent.Style != Core.Config.Style.Cheater then
			ent:BonusReset()
		elseif zone == Restart then
			ent:ResetSpawnPosition( nil, self, true )
		elseif zone == Velocity then
			ent:ProcessVelocityZone( self, true )
		end
	end
end