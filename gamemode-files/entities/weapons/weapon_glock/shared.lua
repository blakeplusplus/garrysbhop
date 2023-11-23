if CLIENT then
	SWEP.PrintName			= "Glock"			
	SWEP.Author				= "Counter-Strike"
	SWEP.Slot				= 1
	SWEP.SlotPos			= 0
	SWEP.IconLetter			= "c"
	
	killicon.AddFont( "weapon_glock", "CSKillIcons", SWEP.IconLetter, Color( 255, 80, 0, 255 ) )
elseif SERVER then
	AddCSLuaFile()
end

SWEP.PrintName = "Glock"
SWEP.HoldType			= "pistol"
SWEP.Base				= "weapon_cs_base"
SWEP.Category			= "Counter-Strike"

SWEP.Spawnable			= true
SWEP.AdminSpawnable		= true

SWEP.ViewModel			= "models/weapons/v_pist_glock18.mdl"
SWEP.WorldModel			= "models/weapons/w_pist_glock18.mdl"

SWEP.Weight				= 5
SWEP.AutoSwitchTo		= false
SWEP.AutoSwitchFrom		= false

SWEP.Primary.Sound			= Sound( "Weapon_Glock.Single" )
SWEP.Primary.Recoil			= 0 --1.8
SWEP.Primary.Damage			= 16
SWEP.Primary.NumShots		= 1
SWEP.Primary.Cone			= 0.03
SWEP.Primary.ClipSize		= 16
SWEP.Primary.Delay			= 0.05
SWEP.Primary.DefaultClip	= 21
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "pistol"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

SWEP.IronSightsPos 		= Vector( 4.3, -2, 2.7 )

-- For faster identification of the weapon
function SWEP:Initialize()
	self.IsGlock = true
end

-- Custom bullet code to make stuff easier
function SWEP:CSSGlockShoot( dmg, recoil, numbul, cone, anim )
	numbul 	= numbul 	or 1
	cone 	= cone 		or 0.01

	local bullet = {}
	bullet.Num 		= numbul
	bullet.Src 		= self.Owner:GetShootPos()
	bullet.Dir 		= self.Owner:GetAimVector()
	bullet.Spread 	= Vector( 0, 0, 0 )
	bullet.Tracer	= 4
	bullet.Force	= 5
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
	
	if anim then
		-- Make sure the glock model animates when required
		if self:GetObj( "Type", 0, nil, true ) == 1 then
			self.Weapon:SendWeaponAnim( ACT_VM_SECONDARYATTACK )
		else	
			self.Weapon:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
		end
	end
	
	if CLIENT then
		self.Owner:MuzzleFlash()
	end
	
	self.Owner:SetAnimation( PLAYER_ATTACK1 )
end

-- Called from the hook - Only fires extra bullets when it can
function SWEP:FireExtraBullets()
	if self:GetObj( "Type", 0, nil, true ) == 1 and self.ShootNext and self.NextShoot < CurTime() and self.ShotsLeft > 0 then
		self:GlockShoot( false )
	end
end

-- Actually bullet firing code
function SWEP:GlockShoot( showanim )
	if self:GetObj( "Type", 0, nil, true ) == 1 then self.ShootNext = false end
	if not self:CanPrimaryAttack() then return end
	
	if CLIENT and not GunSoundsDisabled then
		self.Weapon:EmitSound( self.Primary.Sound, 1 )
	end
	
	self:CSSGlockShoot( self.Primary.Damage, self.Primary.Recoil, self.Primary.NumShots, self.Primary.Cone, showanim )
	self:TakePrimaryAmmo( 1 )
	
	if self.Owner:IsNPC() then return end
	
	self.Weapon.LastFireTime = CurTime()
	
	if self:GetObj( "Type", 0, nil, true ) == 1 and self.ShotsLeft > 0 and not self.ShootNext then
		self.ShootNext = true
		self.ShotsLeft = self.ShotsLeft - 1
	end
	
	self.NextShoot = CurTime() + 0.04
end

-- Called when left mouse is clicked - Fires
function SWEP:PrimaryAttack()
	self.Weapon:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
	
	if self:GetObj( "Type", 0, nil, true ) == 1 then
		-- After it's fired 3 shots, it'll have a .5 second delay
		self.Weapon:SetNextPrimaryFire( CurTime() + 0.5 )
		self.ShotsLeft = 3
		self.NextShoot = CurTime() + 0.04
	else
		self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
	end
	
	if IsValid( self.Owner ) then
		self.Owner.IsGlock = true
		timer.Simple( 0.5, function()
			if IsValid( self ) and IsValid( self.Owner ) then
				self.Owner.IsGlock = nil
			end
		end )
	end
	
	self:GlockShoot( true ) -- Yey animation
end

-- Called when right mouse is clicked - Toggles the firing type (Same as CS:S)
function SWEP:SecondaryAttack()
	if CLIENT or self.NextSecondaryAttack > CurTime() or not IsValid( self.Owner ) then return end
	
	if self:GetObj( "Type", 0, nil, true ) == 1 then
		self:SetObj( "Type", 0, self.Owner, true )
		self.Owner:PrintMessage( HUD_PRINTCENTER, "Switched to semi-automatic" )
	else
		self:SetObj( "Type", 1, self.Owner, true )
		self.Owner:PrintMessage( HUD_PRINTCENTER, "Switched to burst-fire mode" )
	end
	
	self.NextSecondaryAttack = CurTime() + 0.3
end
