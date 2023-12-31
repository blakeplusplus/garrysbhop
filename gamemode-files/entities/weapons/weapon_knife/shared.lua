if SERVER then
	AddCSLuaFile()
	
	SWEP.Weight				= 5
	SWEP.AutoSwitchTo		= false
	SWEP.AutoSwitchFrom		= false
elseif CLIENT then
	SWEP.PrintName			= "Tactical Knife"	
	SWEP.Author				= "cheesylard" -- Works fine - I lost my own one because of update, since then I use this one with a minor edit
	SWEP.DrawAmmo			= false
	SWEP.ViewModelFOV		= 82
	SWEP.ViewModelFlip		= false
	SWEP.CSMuzzleFlashes	= false
	
	SWEP.Slot				= 2
	SWEP.SlotPos			= 1
	SWEP.IconLetter			= "j"

	SWEP.NameOfSWEP			= "weapon_knife" --always make this the name of the folder the SWEP is in.
	killicon.AddFont( SWEP.NameOfSWEP, "CSKillIcons", SWEP.IconLetter, Color( 255, 80, 0, 255 ) )
end

SWEP.IronSightsPos = Vector ( -15.6937, -10.1535, -1.0596 )
SWEP.IronSightsAng = Vector ( 46.9034, 9.0593, -90.2522 )

SWEP.Category				= "Counter-Strike"
SWEP.Base					= "weapon_cs_base"
SWEP.HoldType			= "melee"

SWEP.Spawnable				= true
SWEP.AdminSpawnable			= true

SWEP.ViewModel = "models/weapons/v_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl" 

SWEP.Weight					= 5
SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false
SWEP.CrossHairIronsight		= true --does crosshairs when ironsights are on

SWEP.Primary.ClipSize		= -1
SWEP.Primary.Damage			= 10
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Damage		= 60
SWEP.Secondary.Automatic	= true
SWEP.Secondary.Ammo			= "none"

SWEP.DeploySound			= Sound( "weapons/knife/knife_deploy1.wav" )
SWEP.MissSound 				= Sound( "weapons/knife/knife_slash1.wav" )
SWEP.WallSound 				= Sound( "weapons/knife/knife_hitwall1.wav" )
SWEP.FleshHit1 				= Sound( "weapons/knife/knife_hit1.wav" )
SWEP.FleshHit2 				= Sound( "weapons/knife/knife_hit2.wav" )
SWEP.FleshHit3 				= Sound( "weapons/knife/knife_hit3.wav" )
SWEP.FleshHit4 				= Sound( "weapons/knife/knife_hit4.wav" )
SWEP.SuperFleshHitSound		= Sound( "weapons/knife/knife_stab.wav" )
SWEP.ShootafterTakeout = 0
SWEP.IdleTimer = CurTime()

function SWEP:SecondaryAttack()
	if self.ShootafterTakeout > CurTime() then return end		
	self.Weapon:SetNextPrimaryFire( CurTime() + 0.5 )
	self.Weapon:SetNextSecondaryFire( CurTime() + 0.5 )

	if CLIENT and not GunSoundsDisabled then
		self.Weapon:EmitSound( self.MissSound, 100, math.random( 90, 120 ) )
	end
	
	self.Weapon:SendWeaponAnim( ACT_VM_HITCENTER )
	self.Owner:SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:PrimaryAttack()
	if self.ShootafterTakeout > CurTime() then return end		
	self.Weapon:SetNextPrimaryFire( CurTime() + 0.5 )
	self.Weapon:SetNextSecondaryFire( CurTime() + 0.5 )

	local trace = util.GetPlayerTrace( self.Owner )
 	local tr = util.TraceLine( trace )

	if (self.Owner:GetPos() - tr.HitPos):Length() < 75 then
		if tr.Entity:IsPlayer() or tr.Entity.MatType == "MAT_GLASS" then
			if self.hit == 1 then
				if CLIENT and not GunSoundsDisabled then self.Weapon:EmitSound( self.FleshHit1 ) end
				self.hit = 2
			elseif self.hit == 2 then
				if CLIENT and not GunSoundsDisabled then self.Weapon:EmitSound( self.FleshHit2 ) end
				self.hit = 3
			elseif self.hit == 3 then
				if CLIENT and not GunSoundsDisabled then self.Weapon:EmitSound( self.FleshHit3 ) end
				self.hit = 4
			else
				if CLIENT and not GunSoundsDisabled then self.Weapon:EmitSound( self.FleshHit4 ) end
				self.hit = 1
			end
			
			self.Owner:SetAnimation( PLAYER_ATTACK1 )
			self.Weapon:SendWeaponAnim( ACT_VM_HITCENTER )
		else
			if CLIENT then
				util.Decal( "ManhackCut", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal )
				
				if not GunSoundsDisabled then
					self.Weapon:EmitSound( self.WallSound, 100, math.random( 95, 110 ) )
				end
			end
			
			self.Weapon:SendWeaponAnim( ACT_VM_HITCENTER )
		end
	else
		if CLIENT and not GunSoundsDisabled then
			self.Weapon:EmitSound( self.MissSound, 100, math.random( 90, 120 ) )
		end
		
		self.Weapon:SendWeaponAnim( ACT_VM_HITCENTER )
	end
	
	self.Owner:SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:Reload()
	return false
end

function SWEP:Deploy()
	self:SendWeaponAnim( ACT_VM_DRAW )
	
	if CLIENT and not GunSoundsDisabled then
		self.Owner:EmitSound( self.DeploySound )
	end
	
	return true
end