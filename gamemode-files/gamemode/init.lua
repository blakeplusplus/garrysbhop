-- Make the files downloadable by the client
AddCSLuaFile( "core.lua" )
AddCSLuaFile( "core_move.lua" )
AddCSLuaFile( "core_player.lua" )
AddCSLuaFile( "cl_gui.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_score.lua" )
AddCSLuaFile( "cl_timer.lua" )
AddCSLuaFile( "cl_view.lua" )
AddCSLuaFile( "modules/cl_admin.lua" )
AddCSLuaFile( "modules/cl_playercenter.lua" )

-- Include the core of the gamemode
include( "core.lua" )

-- Check if the gamemode has loaded
if not Core then
	return print( "The server will automatically reload to determine the correct game type when players join!" )
end

-- Include all files for the server in correct order
include( "core_lang.lua" )
include( "core_data.lua" )
include( "sv_view.lua" )
include( "sv_command.lua" )
include( "sv_timer.lua" )
include( "modules/sv_von.lua" )
include( "modules/sv_admin.lua" )
include( "modules/sv_bot.lua" )
include( "modules/sv_playercenter.lua" )
include( "modules/sv_spectator.lua" )
include( "modules/sv_smgr.lua" )
include( "modules/sv_boosterfix.lua" )
include( "modules/sv_ssj.lua")
include( "modules/sv_vip.lua")
--include( "modules/sv_trigger.lua")

-- Makes BaseClass accessible
DEFINE_BASECLASS( "gamemode_base" )
gameevent.Listen( "player_connect" )
Core.AddResources()

local Styles, PlayerData, Teams = Core.Config.Style, Core.Config.Player, Core.Config.Team
local DefaultStyle, DefaultStep, CustomStyleFunc = Styles.Normal, PlayerData.StepSize
local ResetClass, SurfWeapons = player_manager.SetPlayerClass, Core.ContentText( "SurfWeapons" )

--[[
	Description: Loads the essential data from the database
	Notes: Calls as soon as the gamemode is ready
--]]
local function Startup()
	-- Loads all important game data
	Core.LoadCommands()
	Core.LoadRecords()
	Core.LoadAdminPanel()
end
hook.Add( "Initialize", "Startup", Startup )

--[[
	Description: Proceeds with all entity initialization and the rest of the gamemode loading mechanism
	Notes: Removing hooks only here since they might not yet have been initialized when doing it in the file directly
--]]
local function LoadEntities()
	-- Load all main entities
	Core.SetupMapEntities()
	Core.EnableBots()
end
hook.Add( "InitPostEntity", "LoadEntities", LoadEntities )


--[[
	Description: Fully resets the player
	Used by: Spawning, resetting
	Notes: Friendly respawning (no player entity respawning, just changing position and variables)
--]]
local function PlayerSpawnSetting( ply, bWeapons )
	if not ply:IsBot() then
		-- Reset LJ stats if we have a valid player
		if ply.IsLJ then
			ply:LJResetStats()
		end
		
		-- Enable strafe manager
		ply:SetStrafeStats()
		
		-- Reset their timer appropriately
		if Core.IsValidBonus( ply.Style ) then
			ply:BonusReset()
		else
			ply:ResetTimer()
		end
		
		-- Set normal movement settings for the player
		ply:SetMoveType( 2 )
		ply:SetJumpPower( PlayerData.JumpPower )
		ply:SetStepSize( DefaultStep )
		ply:SetJumps( 0 )

		if bWeapons then
			GAMEMODE:PlayerLoadout( ply )
		end
		
		-- Reset the player to a random location
		ply:ResetSpawnPosition() 
	else
		-- Disallow bots to do anything and set their default values accordingly
		ply:SetMoveType( 0 )
		ply:SetCollisionGroup( 1 )
		ply:SetFOV( 90, 0 )
		ply:SetGravity( 0 )
		
		ply:DrawShadow( false )
		ply:StripWeapons()
		
		-- Reset the player to their default position
		ply:ResetSpawnPosition()	
	end
end

--[[
	Description: Fully resets the player
	Notes: Base gamemode override
--]]
function GM:PlayerSpawn( ply )
	-- Inherit data from the player_bhop class
	ResetClass( ply, "player_bhop" )
	BaseClass:PlayerSpawn( ply )
	
	-- Spawn the player on the first spot and set variables
	PlayerSpawnSetting( ply )
end

--[[
	Description: Makes the player ready for combat. I mean uh, playing...
	Notes: Base gamemode override
--]]
function GM:PlayerInitialSpawn( ply )
	-- Set default shmook
	ply:SetTeam( Teams.Players )
	ply:SetJumpPower( PlayerData.JumpPower )
	ply:SetHull( PlayerData.HullMin, PlayerData.HullStand )
	ply:SetHullDuck( PlayerData.HullMin, PlayerData.HullDuck )
	ply:SetNoCollideWithTeammates( true )
	ply:SetAvoidPlayers( false )
	
	-- Set default data
	ply.Style = DefaultStyle
	ply.Record = 0
	ply.Leaderboard = 0
	ply.Rank = -1
	ply.UID = ply:SteamID()
	
	-- Set the most important network variable, the rest will load later and is set to default anyway
	ply:SetObj( "Style", ply.Style )
	ply:InitSSJ()
	
	if not ply:IsBot() then
		-- First do a lockdown check
		if Core.Lockdown and ply.UID != Core.LockExclude then
			return ply:Kick( Core.Lockdown )
		end
		
		-- Force a custom collision check
		ply:SetCustomCollisionCheck( true )
		ply:SetModel( PlayerData.DefaultModel )
		ply:DrawShadow( false )
		
		-- Load the player's details
		ply:LoadTime()
		ply:LoadRank( true )
		ply:NotifyBeatenTimes()
		
		-- Send the top times for displaying
		Core.SendTopTimes( ply )
		
		-- Check if the player is an admin or not
		ply:CheckAdminStatus()
		
		-- Set the connection time
		ply.ConnectedAt = SysTime()
		
		-- Check map type
		if Core.GetMapVariable( "IsBindBypass" ) then
			Core.Send( ply, "Timer/BypassBind", true, true )
		end
		
		-- Set custom style if applicable
		if CustomStyleFunc then
			ply.CustomStyleFunc = CustomStyleFunc
		end
		
		-- Publish the player to the rest
		ply:PublishObj()
		
		-- Make sure the player is recorded by the bot
		if not ply:BotAdd() then
			Core.Print( ply, "Notification", Core.Text( "BotQueue" ) )
		end
	else
		-- For the system to identify new bots
		ply.Temporary = true
		
		-- Disallow bots to do anything and set their default values accordingly
		ply:SetModel( PlayerData.DefaultBot )
		ply:SetMoveType( 0 )
		ply:SetCollisionGroup( 1 )
		ply:SetFOV( 90, 0 )
		ply:SetGravity( 0 )
		
		ply:DrawShadow( false )
		ply:SetPlayerColor( Vector( 1, 0, 0 ) )
		ply:StripWeapons()
	end
end

--[[
	Description: Collection of functions that we want to return a fixed value
	Notes: Base gamemode override
--]]
function GM:CanPlayerSuicide() return false end
function GM:PlayerShouldTakeDamage() return false end
function GM:GetFallDamage() return false end
function GM:PlayerCanHearPlayersVoice() return true end
function GM:IsSpawnpointSuitable() return true end
function GM:PlayerDeathThink( ply ) end
function GM:PlayerSetModel( ply ) end

--[[
	Description: Makes sure stripped players can't do anything as well as to avoid weapon pickup lag
	Notes: Base gamemode override
--]]
function GM:PlayerCanPickupWeapon( ply, weapon )
	if SurfWeapons and not SurfWeapons[ weapon:GetClass() ] then return false end
	
	if ply.WeaponStripped or ply.WeaponPickupProhibit then return false end
	if ply:HasWeapon( weapon:GetClass() ) then return false end
	if ply:IsBot() then return false end
	
	-- For Bhop we'll want to stock up their ammo to the max
	if Core.Config.IsBhop then
		timer.Simple( 0.1, function()
			if IsValid( ply ) and IsValid( weapon ) then
				ply:SetAmmo( 999, weapon:GetPrimaryAmmoType() )
			end
		end )
	end
	
	return true
end

--[[
	Description: Disallows players to take damage
	Notes: Base gamemode override
--]]
function GM:EntityTakeDamage( ent, dmg )
	if ent:IsPlayer() then return false end
	return BaseClass:EntityTakeDamage( ent, dmg )
end

--[[
	Description: Changes the default spawning style and/or the default step size
	Used by: Included Lua files in maps/
	Notes: Uses prints because I think it's cool
--]]
function GM:SetDefaultStyle( nStyle, nStepSize )
	if nStyle then
		GAMEMODE.CustomStyle = nStyle
		
		CustomStyleFunc = function( ply )
			concommand.Run( ply, "style", tostring( GAMEMODE.CustomStyle ), "" )
		end
		
		print( "Default style changed to", Core.StyleName( nStyle ) .. " - ID: " .. nStyle )
	end
	
	if nStepSize then
		DefaultStep = nStepSize
		print( "Default step size changed to", nStepSize )
	end
end

--[[
	Description: Central unloading function from which we destruct the game step by step
	Used by: RTV, Server commands
	Notes: Created so we can have this in a central place
--]]
function GM:UnloadGamemode( szReason )
	-- Change the points entry in the database
	if szReason == "Change" then
		Core.RecalculatePoints()
	end
	
	-- Now save the bots
	Core.SaveBots( szReason != "VoteEnd" )
end

hook.Add("Think", "Unlimtitedaddmmdo", function()
	for _, ply in pairs(player.GetHumans()) do
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) then continue end
		local max = wep:GetMaxClip1()
		if max > 0 then
			wep:SetClip1(max)
		end
	end
end)
