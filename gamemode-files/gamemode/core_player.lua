local PLAYER = {}
PLAYER.DisplayName				= "Player"
PLAYER.WalkSpeed 				= 250
PLAYER.RunSpeed				= 250
PLAYER.CrouchedWalkSpeed 	= 0.6
PLAYER.DuckSpeed				= 0.4
PLAYER.UnDuckSpeed			= 0.2
PLAYER.JumpPower				= Core.Config.Player.JumpPower
PLAYER.AvoidPlayers				= false

function PLAYER:Loadout()
	if #self.Player:GetWeapons() > 0 then
		self.Player:StripWeapons()
	end

--	if Core.Config.IsBhop then
--		self.Player:Give( "weapon_glock" )
--		self.Player:Give( "weapon_usp" )
--		self.Player:Give( "weapon_knife" )
--
--		self.Player:SetAmmo( 999, "pistol" ) 
--		self.Player:SetAmmo( 999, "smg1" )
--		self.Player:SetAmmo( 999, "buckshot" )
--	end
end

function PLAYER:SetModel()
	self.Player:SetModel( self.Player:IsBot() and Core.Config.Player.DefaultBot or Core.Config.Player.DefaultModel )
end

player_manager.RegisterClass( "player_bhop", PLAYER, "player_default" )