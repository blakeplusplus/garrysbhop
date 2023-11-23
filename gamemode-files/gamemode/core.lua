-- Gamemode Type Selection
local Servers = {
	["bhopeasy"] = { Base = "bhop", FastDL = "http://czarchasm.club/fastdl/maps" },
}

-- Attempt exact selection
local CurrentDL, ResolveType = GetConVar( "sv_downloadurl" ):GetString()
for gt,details in pairs( Servers ) do
	if details.FastDL == CurrentDL then
		ResolveType = gt
	end
end

ResolveType = "bhopeasy"

-- Alternative resolve types
if not Servers[ ResolveType ] then
	local map = game.GetMap()
	for gt,details in pairs( Servers ) do
		if details.Fixed or (details.Base and string.find( map, details.Base .. "_", 1, true )) then
			ResolveType = gt
		end
	end
	
	if not Servers[ ResolveType ] then
		if SERVER then
			timer.Simple( 1, function()
				RunConsoleCommand( "changelevel", game.GetMap() )
			end )
		end
		
		return print( "Unable to determine gamemode type!" )
	end
end

local _C = {}
_C.Version = 8.42
_C.GameType = ResolveType
_C.BaseType =_C.GameType:sub( 1, 4 )
_C.ServerName = "Jerry's Shithops"
_C.MaterialID = "prestige"
_C.DisplayNames = { ["bhopeasy"] = "", ["bhophard"] = "", ["surfmain"] = "Skill Surf" }
_C.DisplayName = _C.DisplayNames[ _C.GameType ]
_C.BasePath = _C.MaterialID .. "/"
_C.Identifier = _C.BasePath .. "pg-" .. _C.GameType
_C.IsSurf = _C.BaseType == "surf"
_C.IsBhop = _C.BaseType == "bhop"
_C.IsPack = _C.IsSurf and true
_C.PageSize = 25
_C.BusyTime = 24
_C.KickTime = 28
_C.NetReceive = 0

_C.Team = { Players = 1, Spectator = TEAM_SPECTATOR }
_C.Style = {
	Normal = 1,
	SW = 2,
	HSW = 3,
	["W-Only"] = 4,
	["A-Only"] = 5,
	Legit = 6,
	["Easy Scroll"] = 7,
	Bonus = 8,
	Unreal = 10,
	["Low Gravity"] = 11,
	Crazy = 12,
	["D-Only"] = 13,
	["S-Only"] = 14,
	["High Gravity"] = 15,
	[_C.IsPack and "Jump Pack" or "Stamina"] = 16,
	Swift = 21,
	["M.L.G"] = 24,
	["Moon Man"] = 26,
	SHSW = 27,
	Backwards = 28,
	Prespeed = 29,
	Cancer = 30,
	Cheater = 42,
	Extreme = 43,
}
_C.RankColumns = { 3, 5, 5, 5, 5, 5, 5, 3, 3, 3, 3, 5, 3, 4 }
_C.MaxStyle, _C.PracticeStyle = _C.Style[table.GetWinningKey(_C.Style)], -10

_C.Player = {
	DefaultModel = "models/player/group01/male_01.mdl",
	DefaultBot = "models/player/kleiner.mdl",
	DefaultWeapon = "weapon_glock",
	JumpPower = _C.IsSurf and math.sqrt( 2 * 800 * 57.0 ) or 290,
	ScrollPower = 268.4,
	StepSize = 18,
	LowGravity = 0.6,
	JumpPack = 250,
	StartSpeed = _C.IsSurf and 355 or 278,
	LegitSpeed = 480,
	TopSpeed = 999999,
	AirAcceleration = _C.IsBhop and 500 or 120,
	StrafeMultiplier = _C.IsBhop and 32.8 or 32.4,
	HullMin = Vector( -16, -16, 0 ),
	HullDuck = Vector( 16, 16, 45 ),
	HullStand = Vector( 16, 16, 62 ),
	ViewDuck = Vector( 0, 0, 47 ),
	ViewStand = Vector( 0, 0, 64 )
}

_C.Prefixes = {
	["Timer"] = Color( 52, 152, 219 ),
	["General"] = Color( 46, 204, 113 ),
	["Admin"] = Color( 76, 60, 231 ),
	["Notification"] = Color( 231, 76, 60 ),
	["Radio"] = Color( 230, 126, 34 ),
	[_C["ServerName"]] = Color( 52, 73, 94 )
}

_C.Colors = {
	Color( 168, 230, 161 ),
	Color( 161, 203, 230 ),
	Color( 230, 188, 161 ),
	Color( 223, 161, 230 )
}

_C.Ranks = {
	{ "New", Color( 255, 255, 255 ) },
	{ "Noob", Color( 200, 200, 200 ) },
	{ "Idiot", Color( 96, 96, 96 ) },
	{ "Learning", Color( 255, 228, 181 ) },
	{ "Mediocre", Color( 160, 82, 45 ) },
	{ "Sub-Par", Color( 216, 175, 216 ) },
	{ "Rookie", Color( 211, 0, 85 ) },
	{ "Casual", Color( 	51, 153, 255 ) },
	{ "Decent", Color( 205, 92, 92 ) },
	{ "Good", Color( 	255, 153, 51 ) },
	{ "Excellent", Color( 135, 206, 250 ) },
	{ "Semi-Pro", Color( 178, 102, 255 ) },
	{ "Advanced", Color( 128, 117, 51 ) },
	{ "Pro", Color( 229, 204, 255 ) },
	{ "Expert", Color( 45, 45, 255 ) },
	{ "Monk", Color( 255, 255, 51 ) },
	{ "Master", Color( 255, 182, 193 ) },
	{ "Grandmaster", Color( 178, 34, 34 ) },
	{ "Pioneer", Color( 255, 69, 0 ) },
	{ "Innovator", Color( 153, 76, 15 ) },
	{ "Extraordinary", Color( 0, 206, 209 ) },
	{ "Genius", Color( 0, 102, 102 ) },
	{ "Hero", Color( 173, 255, 47 ) },
	{ "Legend", Color( 127, 0, 255 ) },
	{ "Mythic", Color( 255, 215, 0 ) },	
	{ "Noble", Color( 178, 255, 102 ) },
	{ "Eclipse", Color( 139, 0, 0 ) },
	{ "Nova", Color( 0, 125, 0 ) },
	{ "Supernova", Color( 127, 255, 212 ) },
	{ "Forerunner", Color( 153, 0, 76 ) },
	{ "Reclaimer", Color( 	216, 191, 216 ) },
	{ "Inheritor", Color( 255, 255, 225) },
}

_C.Modes = {
	[-10] = { "Practice", Color( 255, 255, 255 ) },
	[-20] = { "TAS", Color( 82, 123, 188 ) }
}

Core = {}
Core.Config = _C

GM.Name = _C.IsBhop and "Bunny Hop" or (_C.IsSurf and "Surf")
GM.DisplayName = "Jerry's Shithops"
GM.Author = "Gravious"
GM.Email = ""
GM.Website = ""
GM.TeamBased = true

local PLAYER = FindMetaTable( "Player" ), DeriveGamemode( "base" ), util.PrecacheModel( _C.Player.DefaultModel ), util.PrecacheModel( _C.Player.DefaultBot )
local mc, mad, bn, ba, bo, sl, mf, ib, paa, pmv, pjp, plg = math.Clamp, math.AngleDifference, bit.bnot( 2 ), bit.band, bit.bor, string.lower, math.floor, _C.IsBhop, _C.Player.AirAcceleration, _C.Player.StrafeMultiplier, _C.Player.JumpPack, _C.Player.LowGravity
local lp, Iv, Ip, ft, ic, is, isl, ct, gf, ds, du, pj, og = LocalPlayer, IsValid, IsFirstTimePredicted, FrameTime, CLIENT, SERVER, MOVETYPE_LADDER, CurTime, {}, {}, {}, {}, {}

function GM:CreateTeams()
	team.SetUp( _C.Team.Players, "Players", Color( 255, 50, 50, 255 ), false )
	team.SetUp( _C.Team.Spectator, "Spectators", Color( 50, 255, 50, 255 ), true )
	team.SetSpawnPoint( _C.Team.Players, { "info_player_terrorist", "info_player_counterterrorist" } )
end

function GM:PlayerNoClip( ply )
	if not ply:Alive() then return false end
--	if ply:xAdminHasPermission("noclip") then return true end
	if ply:Team() == _C.Team.Spectator then return false end
	
	if not ply.Practice then
		if SERVER then
			Core.Print( ply, "Timer", Core.Text( "StyleNoclip" ) )
		end
		
		return false
	end
	
	return not not ply.Practice
end

function GM:PlayerUse( ply )
	if not ply:Alive() then return false end
	if ply:Team() == _C.Team.Spectator then return false end
	if ply:GetMoveType() != MOVETYPE_WALK then return false end
	
	return true
end

local function GravityMeme( ply, grav )
	local g = ply:GetGravity()
	if ply.Freestyle then
		ply:SetGravity( 0 )
	elseif mf( g * 10 ) / 10 != grav then
		if g == 0 then
			ply:SetGravity( grav )
		elseif g == 1 then
			timer.Simple( 0.1, function()
				ply:SetGravity( grav )
			end )
		end
	end
end

local function IsNormalStyle(s)
	local _ = _C.Style
	return ({
		[_.Normal] = 1,
		[_.Legit] = 1,
		[_["Easy Scroll"]] = 1,
		[_.Bonus] = 1,
		[_.Crazy] = 1,
		[_.Unreal] = 1,
		[_["Low Gravity"]] = 1,
		[_["High Gravity"]] = 1,
		[_.Stamina] = 1,
		[_["M.L.G"]] = 1,
		[_.Prespeed] = 1,
		[_.Cancer] = 1,
		[_.Cheater] = 1,
		[_["Moon Man"]] = 1,
		[_.Extreme] = 1,
	})[s]
end

function GM:Move( ply, data )
	if ply:IsOnGround() or not ply:Alive() then return end
	
	local aa, mv = paa, pmv
	local aim = data:GetMoveAngles()
	local forward, right = aim:Forward(), aim:Right()
	local fmove = data:GetForwardSpeed()
	local smove = data:GetSideSpeed()
	
	local st = ply.Style
	if IsNormalStyle(st) then
		if data:KeyDown( 1024 ) then smove = smove + 500 end
		if data:KeyDown( 512 ) then smove = smove - 500 end
	end
	if st == 2 then
		if data:KeyDown( 8 ) then fmove = fmove + 500 end
		if data:KeyDown( 16 ) then fmove = fmove - 500 end
	elseif st == _C.Style.Legit then
		aa, mv = ply:Crouching() and 20 or 50, 32.4
	elseif st == _C.Style["Easy Scroll"] or st == _C.Style[_C.IsPack and "Jump Pack" or "Stamina"] then
		aa, mv = 120, 32.4
	elseif st == _C.Style.Swift then
		aa, mv = 2000, 50
	elseif st == _C.Style.Unreal or st == _C.Style.Crazy then
		aa, mv = 2000, 50
		
		if data:KeyDown( 512 ) or data:KeyDown( 1024 ) then
			smove = smove * 500
		end
	elseif st == _C.Style["M.L.G"] then
		aa, mv = 6900, 420

		if is then
			GravityMeme( ply, 0.25 )
		end
	elseif st == _C.Style["Low Gravity"] and is then
		GravityMeme( ply, plg )
	elseif st == _C.Style["High Gravity"] and is then
		GravityMeme( ply, 1.4 )
	elseif ( st == _C.Style["Cancer"] or st == _C.Style["Moon Man"] ) then
		if st == _C.Style["Cancer"] then
			aa, mv = 10000, 1000
		end

		if is then
			GravityMeme( ply, 0.1 )
		end
	elseif st == _C.Style.Extreme then
		aa, mv = 2000, 50

		if data:KeyDown( 512 ) or data:KeyDown( 1024 ) then
			smove = smove * 500
		end
	end
	
	forward.z, right.z = 0,0
	forward:Normalize()
	right:Normalize()

	local wishvel = forward * fmove + right * smove
	wishvel.z = 0

	local wishspeed = wishvel:Length()
	if wishspeed > data:GetMaxSpeed() then
		wishvel = wishvel * (data:GetMaxSpeed() / wishspeed)
		wishspeed = data:GetMaxSpeed()
	end

	local wishspd = wishspeed
	wishspd = mc( wishspd, 0, mv )

	local wishdir = wishvel:GetNormal()
	local vel = data:GetVelocity()
	local current = vel:Dot( wishdir )

	local addspeed = wishspd - current
	if addspeed <= 0 then return end

	local accelspeed = aa * ft() * wishspeed
	if accelspeed > addspeed then
		accelspeed = addspeed
	end
	
	vel = vel + (wishdir * accelspeed)
	data:SetVelocity( vel )
	
	return false
end

local function ChangeMove( ply, data )
	if not ply:IsOnGround() then
		if not du[ ply ] then
			gf[ ply ] = 0
			ds[ ply ] = nil
			du[ ply ] = true
			
			ply:SetDuckSpeed( 0 )
			ply:SetUnDuckSpeed( 0 )
		end
		
		local st = ply.Style
		if not ply.Freestyle and ply:GetMoveType() != 8 then
			if st == _C.Style["SW"] or st == _C.Style["W-Only"] or st == _C.Style["S-Only"] then
				data:SetSideSpeed( 0 )
				
				if st == _C.Style["W-Only"] and data:GetForwardSpeed() < 0 then
					data:SetForwardSpeed( 0 )
				elseif st == _C.Style["S-Only"] and data:GetForwardSpeed() > 0 then
					data:SetForwardSpeed( 0 )
				end
			elseif st == _C.Style["A-Only"] then
				data:SetForwardSpeed( 0 )
					
				if data:GetSideSpeed() > 0 then
					data:SetSideSpeed( 0 )
				end
			elseif st == _C.Style["D-Only"] then
				data:SetForwardSpeed( 0 )
					
				if data:GetSideSpeed() < 0 then
					data:SetSideSpeed( 0 )
				end
			elseif st == _C.Style["HSW"] then
				if ib and ba( data:GetButtons(), 16 ) > 0 then
					local bd = data:GetButtons()
					if ba( bd, 512 ) > 0 or ba( bd, 1024 ) > 0 then
						data:SetForwardSpeed( 0 )
						data:SetSideSpeed( 0 )
					end
				end
				
				if data:GetForwardSpeed() == 0 or data:GetSideSpeed() == 0 then
					data:SetForwardSpeed( 0 )
					data:SetSideSpeed( 0 )
				end
			elseif st == _C.Style["SHSW"] then
				if ( data:GetForwardSpeed() >= 0 and data:GetSideSpeed() >= 0 ) then
					data:SetSideSpeed( 0 )
					data:SetForwardSpeed( 0 )
				end
				
				
				if ( data:GetForwardSpeed() <= 0 and data:GetSideSpeed() <= 0 ) then
					data:SetSideSpeed( 0 )
					data:SetForwardSpeed( 0 )
				end
			end
		end
		
		if ic and ply.Gravity != nil then
			if ply.Gravity or ply.Freestyle then
				ply:SetGravity( 0 )
			else
				ply:SetGravity( plg )
			end
		end
	else
		if not gf[ ply ] then
			gf[ ply ] = 0
		else
			local st = ply.Style
			if gf[ ply ] > 12 then
				if not ds[ ply ] then
					if st == _C.Style["Easy Scroll"] then
						ply:SetJumpPower( _C.Player.JumpPower )
					end
					
					ply:SetDuckSpeed( 0.4 )
					ply:SetUnDuckSpeed( 0.2 )
					
					ds[ ply ] = true
				end
			else
				gf[ ply ] = gf[ ply ] + 1
				
				if gf[ ply ] == 1 then
					du[ ply ] = nil
					
					if st == _C.Style["Easy Scroll"] then
						ply:SetJumpPower( _C.Player.ScrollPower )
					end
					
					if pj[ ply ] then
						pj[ ply ] = pj[ ply ] + 1
					end
				elseif gf[ ply ] > 1 and data:KeyDown( 2 ) and st != _C.Style["Legit"] and st != _C.Style["Easy Scroll"] then
					if ic and gf[ ply ] < 4 then return end
					
					local vel = data:GetVelocity()
					vel.z = ply:GetJumpPower()
					
					ply:SetDuckSpeed( 0 )
					ply:SetUnDuckSpeed( 0 )
					gf[ ply ] = 0
					
					data:SetVelocity( vel )
				end
			end
		end
	end
end
hook.Add( "SetupMove", "ChangeMove", ChangeMove )

local PlayerJumps = {}

local function PlayerGround( ply, bWater )
	if PlayerJumps[ ply ] then
		PlayerJumps[ ply ] = PlayerJumps[ ply ] + 1

		if ply.ssj_data and ply.ssj_data.holdingspace then
			table.insert(ply.ssj_data.jumps, SSJ_GetStatistics(ply))
		end
	else
		PlayerJumps[ ply ] = 1
	end

	if ply.ssj_data and ply.ssj_data.enabled then
		ShowSixthJump( ply )
	end
end
hook.Add( "OnPlayerHitGround", "HitGround", PlayerGround )

local function ChangePlayerAngle( ply, cmd )
	if ply.Style == _C.Style.Backwards and not ply:IsOnGround() then
        local d = mad( cmd:GetViewAngles().y, ply:GetVelocity():Angle().y )
		if d > -100 and d < 100 then
			cmd:SetForwardMove( 0 )
			cmd:SetSideMove( 0 )
		end
	end
end
hook.Add( "StartCommand", "ChangeAngles", ChangePlayerAngle )

local function AutoHop( ply, data )
	if ply.Style != _C.Style["Easy Scroll"] and ply.Style != _C.Style["Legit"] then
		local bd = data:GetButtons()
		if ba( bd, 2 ) > 0 then
			if not ply:IsOnGround() and ply:WaterLevel() < 2 and ply:GetMoveType() != 9 then
				data:SetButtons( ba( bd, bn ) )
				
				if _C.IsPack and ply.Style == 10 then
					local jpv = data:GetVelocity()
					jpv.z = jpv.z + pjp * ft()
					data:SetVelocity( jpv )
				end
			end
		end
	end
end
hook.Add( "SetupMove", "AutoHop", AutoHop )

local function ProcessFire( ply )
	if not ply.IsGlock then return end
	
	local weapon = ply:GetActiveWeapon()
	if Iv( weapon ) and weapon.IsGlock then
		weapon:FireExtraBullets()
	end
end
hook.Add( "PlayerPostThink", "ProcessFire", ProcessFire )

function GM:CreateMove() end
function GM:SetupMove() end
function GM:FinishMove() end


local StyleNames = {}
local CustomNames = { [2] = "Sideways", [3] = "Half Sideways" }
local rand, n, pair = math.random, next, pairs

for name,id in pair( _C.Style ) do
	StyleNames[ id ] = CustomNames[ id ] or name
end

function Core.StyleName( nID )
	return StyleNames[ nID ] or (Core.IsValidBonus( nID ) and "Bonus " .. (nID - _C.Style.Bonus + 1) or "Invalid")
end

function Core.IsValidStyle( nStyle )
	if not nStyle then return false end
	if Core.IsValidBonus( nStyle ) then return true end
	return not not StyleNames[ nStyle ]
end

function Core.IsValidBonus( nStyle )
	if not nStyle then return false end
	return nStyle == 8
end

function Core.GetStyleID( szStyle )
	for id,s in pair( StyleNames ) do
		if sl( s ) == sl( szStyle ) then
			return id
		end
	end
	
	return 0
end

function Core.SetStyle( nID, data )
	StyleNames[ nID ] = data
end

function Core.GetStyles()
	local tab = {}
	for name,id in pairs( _C.Style ) do
		tab[ id ] = StyleNames[ id ]
	end
	return tab
end

function Core.ObtainRank( nID, nStyle, bScore )
	local mode = _C.Modes[ nID ]
	local data = mode or _C.Ranks[ nID ]
	
	if not data then
		return "Retrieving...", color_white
	end
	
	local rank = data[ 1 ]
	if mode then
		if nID == -20 and nStyle > 50 then nStyle = nStyle - 50 end
		rank = rank .. " - " .. Core.StyleName( nStyle )
	elseif nStyle != _C.Style.Normal then
		rank = Core.StyleName( nStyle ) .. " - " .. rank
	end
	
	return bScore and data[ 1 ] or rank, data[ 2 ]
end

function Core.CleanTable( tab )
	if not tab then return end
	for k in n,tab do
		tab[ k ] = nil
	end
end

function Core.CountHash( tab )
	local c = 0
	for _,v in pair( tab ) do c = c + 1 end
	return c
end

function Core.GetRandomColor()
	return Color( rand( 0, 255 ), rand( 0, 255 ), rand( 0, 255 ) )
end

function Core.ParseBytes( b )
	local mb = b / 1024
	if mb > 1024 then
		return math.Round( mb / 1024, 2 ) .. " GB"
	else
		return math.Round( mb, 2 ) .. " MB"
	end
end

function Core.ToDate( n, s )
	return os.date( s and "%Y-%m-%d" or "%Y-%m-%d %H:%M:%S", n or os.time() )
end


local CacheFunctions = {}
local CacheSplit = string.Explode
local CacheFind = string.find

local function CallFunction( szIdentifier, varArgs, bGlobal, varParam )
	if CacheFind( szIdentifier, "/", 1, true ) then
		local Matches = CacheSplit( "/", szIdentifier )
		if #Matches > 1 and CacheFunctions[ Matches[ 1 ] ] then
			local Executor = CacheFunctions[ Matches[ 1 ] ][ Matches[ 2 ] ]
			if Executor then
				if varParam then
					Executor( varParam, varArgs )
				else
					Executor( varArgs )
				end
			end
		end
	else
		if not bGlobal then
			CallFunction( "Global/" .. szIdentifier, varArgs, true, varParam )
		end
	end
end

function Core.Register( szIdentifier, fExecutable )
	if CacheFind( szIdentifier, "/", 1, true ) then
		local Matches = CacheSplit( "/", szIdentifier )
		if #Matches > 1 then
			if not CacheFunctions[ Matches[ 1 ] ] then
				CacheFunctions[ Matches[ 1 ] ] = {}
			end
			
			CacheFunctions[ Matches[ 1 ] ][ Matches[ 2 ] ] = fExecutable
		end
	end
end

include( "core_player.lua" )
include( "core_move.lua" )

function PLAYER:GetJumps()
	return pj[ self ] or 0
end

function PLAYER:SetJumps( nValue )
	if self.RTSF then self:RTSF() end
	pj[ self ] = nValue
end


if SERVER then

function Core.Trigger( ... )
	CallFunction( ... )
end

local function CoreReceive( _, ply )
	local szAction = net.ReadString()
	local varArgs = net.ReadBit() == 1 and net.ReadTable() or {}
	
	if Iv( ply ) and ply:IsPlayer() then
		CallFunction( "Global/" .. szAction, varArgs, true, ply )
	end
end
net.Receive( "SecureTransfer", CoreReceive )

elseif CLIENT then

Core.ClientEnts = {}

local NetObj = {}
NetObj.Int = function( t, b ) return net.ReadInt( b ) end
NetObj.UInt = function( t, b ) return net.ReadUInt( b ) end
NetObj.String = function() return net.ReadString() end
NetObj.Bit = function() return net.ReadBit() == 1 end
NetObj.Double = function() return net.ReadDouble() end
NetObj.Color = function() return net.ReadColor() end
NetObj.ColorText = function( t ) local d = {} for i = 1, t:UInt( 8 ) do d[ #d + 1 ] = t:Bit() and Core.TranslateColor( t:Color() ) or t:String() end return d end

function Core.Send( szAction, varArgs )
	net.Start( "SecureTransfer" )
	net.WriteString( szAction )
	
	if varArgs and type( varArgs ) == "table" then
		net.WriteBit( true )
		net.WriteTable( varArgs )
	else
		net.WriteBit( false )
	end
	
	net.SendToServer()
end

local function CoreReceive( l )
	_C.NetReceive = _C.NetReceive + l
	CallFunction( net.ReadString(), net.ReadBit() == 1 and net.ReadTable() or {} )
end
net.Receive( "SecureTransfer", CoreReceive )

local function ManualReceive( l )
	_C.NetReceive = _C.NetReceive + l
	CallFunction( net.ReadString(), NetObj )
end
net.Receive( "QuickNet", ManualReceive )

local ManualCall, Bytes = net.Incoming, 0
local function ManualOverride( l )
	ManualCall( l )
	Bytes = Bytes + l
end
net.Incoming = ManualOverride

local function NetworkChecker()
	_C.NetRate = math.Round( Bytes / 1024, 2 ) .. " kbps"
	Bytes = 0
end
timer.Create( "NetworkStats", 1, 0, NetworkChecker )

function Core.Trigger( szType, varArgs )
	CallFunction( "Inner/" .. szType, varArgs )
end

for i = 1, _C.Style.Bonus + 10 do
	StyleNames[ 50 + i ] = Core.StyleName( i ) .. " TAS"
end

for i = 1, 100 do
	StyleNames[ 100 + i ] = "Stage " .. i
end

end