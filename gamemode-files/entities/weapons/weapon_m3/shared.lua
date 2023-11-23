if CLIENT then
	SWEP.PrintName			= "Pump Shotgun"			
	SWEP.Author				= "Counter-Strike"
	SWEP.Slot				= 2
	SWEP.SlotPos			= 0
	SWEP.IconLetter			= "k"
	
	killicon.AddFont( "weapon_m3", "CSKillIcons", SWEP.IconLetter, Color( 255, 80, 0, 255 ) )
elseif SERVER then
	AddCSLuaFile()
end

SWEP.HoldType			= "ar2"
SWEP.Base				= "weapon_cs_base"
SWEP.Category			= "Counter-Strike"

SWEP.Spawnable			= true
SWEP.AdminSpawnable		= true

SWEP.ViewModel			= "models/weapons/v_shot_m3super90.mdl"
SWEP.WorldModel			= "models/weapons/w_shot_m3super90.mdl"

SWEP.Weight				= 5
SWEP.AutoSwitchTo		= false
SWEP.AutoSwitchFrom		= false

SWEP.Primary.Sound			= Sound( "Weapon_M3.Single" )
SWEP.Primary.Recoil			= 5
SWEP.Primary.Damage			= 8
SWEP.Primary.NumShots		= 8
SWEP.Primary.Cone			= 0.1
SWEP.Primary.ClipSize		= 8
SWEP.Primary.Delay			= 0.95
SWEP.Primary.DefaultClip	= 16
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "buckshot"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

SWEP.IronSightsPos 		= Vector( 5.7, -3, 3 )

function SWEP:Reload()
	self:SetIronsights( false )
	
	if ( self.Weapon:GetObj( "Reloading", false, nil, true ) ) then return end
	if ( self.Weapon:Clip1() < self.Primary.ClipSize && self.Owner:GetAmmoCount( self.Primary.Ammo ) > 0 ) then
		if SERVER then
			self.Weapon:SetObj( "Reloading", true, self.Owner, true )
		end
		
		self.Weapon.ReloadTimer = CurTime() + 0.3
		self.Weapon:SendWeaponAnim( ACT_VM_RELOAD )
		self.Owner:DoReloadEvent()
	end
end

function SWEP:Think()
	if ( self.Weapon:GetObj( "Reloading", false, nil, true ) ) then
		if ( self.Weapon.ReloadTimer or 0 < CurTime() ) then
			if ( self.Weapon:Clip1() >= self.Primary.ClipSize || self.Owner:GetAmmoCount( self.Primary.Ammo ) <= 0 ) then
				if SERVER then
					self.Weapon:SetObj( "Reloading", false, self.Owner, true )
				end
				
				return
			end

			self.Weapon.ReloadTimer = CurTime() + 0.3
			self.Weapon:SendWeaponAnim( ACT_VM_RELOAD )
			self.Owner:DoReloadEvent()
			
			self.Owner:RemoveAmmo( 1, self.Primary.Ammo, false )
			self.Weapon:SetClip1(  self.Weapon:Clip1() + 1 )
			
			if ( self.Weapon:Clip1() >= self.Primary.ClipSize || self.Owner:GetAmmoCount( self.Primary.Ammo ) <= 0 ) then
				self.Weapon:SendWeaponAnim( ACT_SHOTGUN_RELOAD_FINISH )
				self.Owner:DoReloadEvent()
			end
		end
	end
end