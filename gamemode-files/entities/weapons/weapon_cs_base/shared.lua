if SERVER then
	AddCSLuaFile()
	
	SWEP.Weight				= 5
	SWEP.AutoSwitchTo		= false
	SWEP.AutoSwitchFrom		= false
elseif CLIENT then
	SWEP.DrawAmmo			= true
	SWEP.DrawCrosshair		= false
	SWEP.ViewModelFOV		= 82
	SWEP.ViewModelFlip		= true
	SWEP.CSMuzzleFlashes	= true
	
	surface.CreateFont("CSKillIcons", { font="csd", weight="500", size=ScreenScale(30),antialiasing=true,additive=true })
	surface.CreateFont("CSSelectIcons", { font="csd", weight="500", size=ScreenScale(60),antialiasing=true,additive=true })
end

SWEP.Author			= "Counter-Strike"
SWEP.Contact		= ""
SWEP.Purpose		= ""
SWEP.Instructions	= ""

SWEP.Spawnable			= false
SWEP.AdminSpawnable		= false

SWEP.Primary.Sound			= Sound( "Weapon_AK47.Single" )
SWEP.Primary.Recoil			= 0 --1.5
SWEP.Primary.Damage			= 40
SWEP.Primary.NumShots		= 1
SWEP.Primary.Cone			= 0.02
SWEP.Primary.Delay			= 0.15

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

function SWEP:Initialize()
	if SERVER then
		self:SetNPCMinBurst( 30 )
		self:SetNPCMaxBurst( 30 )
		self:SetNPCFireRate( 0.01 )
	end
	
	self:SetWeaponHoldType( self.HoldType )
end

function SWEP:Reload()
	self.Weapon:DefaultReload( ACT_VM_RELOAD )
	self:SetIronsights( false )
end

function SWEP:Think()	
end

function SWEP:PrimaryAttack()
	self.Weapon:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
	self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
	
	if not self:CanPrimaryAttack() then return end
	
	if CLIENT and not GunSoundsDisabled then
		self.Weapon:EmitSound( self.Primary.Sound, 1 )
	end

	self:CSShootBullet( self.Primary.Damage, self.Primary.Recoil, self.Primary.NumShots, self.Primary.Cone )
	self:TakePrimaryAmmo( 1 )
	
	if self.Owner:IsNPC() then return end
	
	self.Weapon.LastFireTime = CurTime()
end

function SWEP:CSShootBullet( dmg, recoil, numbul, cone )
	numbul 	= numbul 	or 1
	cone 	= cone 		or 0.01

	local bullet = {}
	bullet.Num 		= numbul
	bullet.Src 		= self.Owner:GetShootPos()			// Source
	bullet.Dir 		= self.Owner:GetAimVector()			// Dir of bullet
	bullet.Spread 	= Vector( cone, cone, 0 )			// Aim Cone
	bullet.Tracer	= 4									// Show a tracer on every x bullets 
	bullet.Force	= 5									// Amount of force to give to phys objects
	bullet.Damage	= dmg
	
	local owner = self.Owner
	local slf = self

	bullet.Callback = function( a, b, c )
		if SERVER and b.HitPos then
			local tracedata = {}
			tracedata.start = b.StartPos
			tracedata.endpos = b.HitPos + (b.Normal * 2)
			tracedata.filter = a
			tracedata.mask = MASK_PLAYERSOLID
			
			local trace = util.TraceLine( tracedata )
			if IsValid( trace.Entity ) then
				if trace.Entity:GetClass() == "func_button" then
					trace.Entity:TakeDamage( dmg, a, c:GetInflictor() )
					trace.Entity:TakeDamage( dmg, a, c:GetInflictor() )
				elseif trace.Entity:GetClass() == "func_physbox_multiplayer" then
					trace.Entity:TakeDamage( dmg, a, c:GetInflictor() )
				end
			end
		end
	end

	if Core and Core.Config and Core.Config.IsBhop then
		self.Owner:FireBullets( bullet )
	end
	
	self.Weapon:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	
	if CLIENT then
		self.Owner:MuzzleFlash()
	end
	
	self.Owner:SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )
	draw.SimpleText( self.IconLetter, "CSSelectIcons", x + wide/2, y + tall*0.2, Color( 255, 210, 0, 255 ), TEXT_ALIGN_CENTER )
	
	// try to fool them into thinking they're playing a Tony Hawks game
	draw.SimpleText( self.IconLetter, "CSSelectIcons", x + wide/2 + math.Rand(-4, 4), y + tall*0.2+ math.Rand(-14, 14), Color( 255, 210, 0, math.Rand(10, 120) ), TEXT_ALIGN_CENTER )
	draw.SimpleText( self.IconLetter, "CSSelectIcons", x + wide/2 + math.Rand(-4, 4), y + tall*0.2+ math.Rand(-9, 9), Color( 255, 210, 0, math.Rand(10, 120) ), TEXT_ALIGN_CENTER )
end

function SWEP:GetViewModelPosition( pos, ang )
	return pos, ang
end

function SWEP:SetIronsights( b )
end

SWEP.NextSecondaryAttack = 0
SWEP.LastFireTime = 0

local CCrosshair = CreateClientConVar( "pg_crosshair", "1", true, false )
local CGap = CreateClientConVar( "pg_cross_gap", "1", true, false )
local CThick = CreateClientConVar( "pg_cross_thick", "0", true, false )
local CLength = CreateClientConVar( "pg_cross_length", "1", true, false )
local COpacity = CreateClientConVar( "pg_cross_opacity", "255", true, false )

function SWEP:DrawHUD()
	if not CCrosshair:GetBool() then return end
	
	local x, y
	if self.Owner == LocalPlayer() && self.Owner:ShouldDrawLocalPlayer() then

		local tr = util.GetPlayerTrace( self.Owner )
		tr.mask = bit.bor( CONTENTS_SOLID,CONTENTS_MOVEABLE,CONTENTS_MONSTER,CONTENTS_WINDOW,CONTENTS_DEBRIS,CONTENTS_GRATE,CONTENTS_AUX )
		local trace = util.TraceLine( tr )
		
		local coords = trace.HitPos:ToScreen()
		x, y = coords.x, coords.y

	else
		x, y = ScrW() / 2.0, ScrH() / 2.0
	end
	
	local scale = 10 * self.Primary.Cone
	local LastShootTime = self.Weapon.LastFireTime or 0
	scale = scale * (2 - math.Clamp( (CurTime() - LastShootTime) * 5, 0.0, 1.0 ))

	surface.SetDrawColor( 0, 255, 0, COpacity:GetInt() )

	local gap = 40 * (scale * CGap:GetInt())
	local length = gap + 20 * (scale * CLength:GetInt())
	local thick = CThick:GetInt()
	if thick > 0 then
		for i = -thick, thick do
			surface.DrawLine( x - length, y + i, x - gap, y + i )
			surface.DrawLine( x + length, y + i, x + gap, y + i )
			surface.DrawLine( x + i, y - length, x + i, y - gap )
			surface.DrawLine( x + i, y + length, x + i, y + gap )
		end
	else
		surface.DrawLine( x - length, y, x - gap, y )
		surface.DrawLine( x + length, y, x + gap, y )
		surface.DrawLine( x, y - length, x, y - gap )
		surface.DrawLine( x, y + length, x, y + gap )
	end
end

function SWEP:OnRestore()
	self.NextSecondaryAttack = 0
	self:SetIronsights( false )
end

function SWEP:OnFireLocal( t )
	if self.Clip1 and self:Clip1() > 0 then
		self.LastFireTime = t
	end
end