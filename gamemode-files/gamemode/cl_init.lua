include( "core.lua" )
include( "cl_view.lua" )
include( "cl_timer.lua" )
include( "cl_gui.lua" )
include( "cl_score.lua" )
include( "modules/cl_admin.lua" )
include( "modules/cl_playercenter.lua" )

local SeePlayers = CreateClientConVar( "pg_showothers", "1", true, false )
local SeeTargetID = CreateClientConVar( "pg_targetids", "0", true, false )
local IsCrosshair = CreateClientConVar( "pg_crosshair", "1", true, false )
local ViewGUI = CreateClientConVar( "pg_showgui", "1", true, false )
local ViewSpec = CreateClientConVar( "pg_showspec", "1", true, false )
local ViewZones = CreateClientConVar( "pg_showzones", "0", true, false )

local HUDItems, Settings = { "CHudHealth", "CHudBattery", "CHudAmmo", "CHudSecondaryAmmo", "CHudSuitPower" }, {}
local lp, Iv, st, ft, ma, mc, PlayerData, Styles, CalcTab, Ducker, Thirdperson, CalcAdded, DrawAdded, Crossholder, SilentSave, ViewInterp, SteadyView = LocalPlayer, IsValid, SysTime, FrameTime, math.abs, math.ceil, Core.Config.Player, Core.Config.Style, { origin = { z = 0 }, wep = { z = 0 }, frames = 0, last = false }, IN_DUCK

function GM:HUDPaint() end
function GM:AdjustMouseSensitivity() end
function GM:CalcViewModelView() end
function GM:PreDrawViewModel() end
function GM:PostDrawViewModel() end

function GM:HUDShouldDraw( szApp )
	return not HUDItems[ szApp ]
end

function GM:ShouldDrawLocalPlayer( ply )
	return Thirdperson
end

function GM:CalcView( ply, pos, angles, fov )
	if not Thirdperson then
		angles.r = 0
		
		if not ply:IsOnGround() and ViewInterp then
			local duck = ply:KeyDown( Ducker )
			if duck != CalcTab.last then
				CalcTab.frames = mc( (1 / 30) / ft() )
			end
			
			if CalcTab.frames > 0 then
				local est = CalcTab.origin.z + ply:GetVelocity().z * ft()
				local diff = ma( pos.z - est )
				if diff > -0.01662 / ft() + 12.306 and diff < 100 then
					pos.z = est
				end
				
				CalcTab.frames = CalcTab.frames - 1
			end
			
			CalcTab.last = duck
		end
		
		CalcTab.origin = pos
		CalcTab.angles = angles
		CalcTab.fov = fov
		
		return CalcTab
	elseif ply:Alive() then
		CalcTab.origin = pos - (angles:Forward() * 100) + (angles:Up() * 40)
		CalcTab.angles = (ply:GetPos() + (angles:Up() * 30 )) - CalcTab.origin
		CalcTab.angles:Normalize()
		CalcTab.angles = CalcTab.angles:Angle()
		CalcTab.fov = fov
		
		return CalcTab
	end
end

function GM:CalcViewModelView( we, vm, op, oa, p, a )
	if SteadyView then
		return op, oa
	else
		if CalcTab.frames > 0 and not lp():IsOnGround() then
			local diff = ma( CalcTab.wep.z - p.z )
			if diff > -0.01662 / ft() + 12.306 and diff < 100 then
				p.z = CalcTab.wep.z
				
				if Iv( we ) and we.GetViewModelPosition then
					local vmx = we.GetViewModelPosition( we, vm, op, oa, p, a )
					if Iv( vmx ) then
						if ma( p.z - vmx:GetPos().z ) < 1 then
							p.z = vmx:GetPos().z
						end
					end
				end
			end
		end
		
		CalcTab.wep = p
		
		return p, a
	end
end

function GM:EntityEmitSound( data )
	if string.find( data.OriginalSoundName, "bulletimpact" ) and GunSoundsDisabled then
		return false
	elseif string.find( data.SoundName, "footstep" ) and Core.FootstepType then
		if Core.FootstepType == 1 then
			return false
		elseif IsValid( data.Entity ) then
			if data.Entity == lp() and Core.FootstepType != 2 then
				return false
			elseif data.Entity != lp() and Core.FootstepType != 3 then
				return false
			end
		end
	end
end


local function CV( nv ) return string.format( "%.0f", nv ) end
local function SetPlayerVisibility( varArgs )
	if type( varArgs ) == "boolean" then varArgs = { varArgs and 1 or 0 } end
	local nTarget, nNew = tonumber( varArgs[ 1 ] ), -1
	if SeePlayers:GetInt() == nTarget then
		RunConsoleCommand( "pg_showothers", CV( 1 - nTarget ) )
		timer.Simple( 1, function() RunConsoleCommand( "pg_showothers", nTarget ) end )
		nNew = nTarget
	elseif nTarget < 0 then
		nNew = 1 - SeePlayers:GetInt()
		RunConsoleCommand( "pg_showothers", CV( nNew ) )
	else
		nNew = nTarget
		RunConsoleCommand( "pg_showothers", CV( nNew ) )
	end
	
	if nNew >= 0 then
		Core.Print( "General", "You have set player visibility to " .. (nNew == 0 and "invisible" or "visible") )
	end
end
Core.Register( "Client/PlayerVisibility", SetPlayerVisibility )

local function SetGUIVisibility( varArgs )
	if type( varArgs ) == "boolean" then varArgs = { varArgs and 1 or 0 } end
	local nTarget, nNew = tonumber( varArgs[ 1 ] ), -1
	if nTarget < 0 then
		nNew = 1 - ViewGUI:GetInt()
		RunConsoleCommand( "pg_showgui", CV( nNew ) )
	else
		nNew = nTarget
		RunConsoleCommand( "pg_showgui", CV( nNew ) )
	end
	
	if nNew >= 0 then
		Core.Print( "General", "You have set GUI visibility to " .. (nNew == 0 and "invisible" or "visible") )
	end
end
Core.Register( "Client/GUIVisibility", SetGUIVisibility )

local function SetSpecVisibility( varArgs )
	if type( varArgs ) == "boolean" then varArgs = { varArgs and 1 or 0 } end
	local nNew = not varArgs[ 1 ] and 1 - ViewSpec:GetInt() or (tonumber( varArgs[ 1 ] ) or 1)
	if nNew then
		RunConsoleCommand( "pg_showspec", CV( nNew ) )
		Core.Print( "General", "You have set spectator list visibility to " .. (nNew == 0 and "invisible" or "visible") )
	end
end
Core.Register( "Client/SpecVisibility", SetSpecVisibility )

local function SetZoneVisibility( varArgs )
	if type( varArgs ) == "boolean" then varArgs = { varArgs and 1 or 0 } end
	local nNew = not varArgs[ 1 ] and 1 - ViewZones:GetInt() or (tonumber( varArgs[ 1 ] ) or 1)
	
	RunConsoleCommand( "pg_showzones", CV( nNew ) )
	if nNew == -1 then
		Core.Print( "General", "All zones are now fully hidden from view" )
	else
		Core.Print( "General", "All non-default zones will now appear as " .. (nNew == 0 and "invisible" or "visible") )
	end
end
Core.Register( "Client/ZoneVisibility", SetZoneVisibility )

local function SetCrosshair( varArgs )
	local c = 0
	for k,v in pairs( varArgs ) do c = c + 1 end
	if c > 0 then
		for cmd,target in pairs( varArgs ) do
			RunConsoleCommand( cmd, tostring( target ) )
		end
		Core.Print( "General", "Your crosshair options have been changed!" )
	else
		HUDItems["CHudCrosshair"] = not HUDItems["CHudCrosshair"]
		RunConsoleCommand( "pg_crosshair", CV( HUDItems["CHudCrosshair"] and 1 or 0 ) )
		Core.Print( "General", "Crosshair visibility has been toggled" .. (not Crossholder and ". You might have to do this twice the first time" or "") )
		Crossholder = true
	end
end
Core.Register( "Client/Crosshair", SetCrosshair )

local function ToggleTargetIDs( varArgs )
	local nNew = 1 - SeeTargetID:GetInt()
	if type( varArgs ) == "boolean" then nNew = varArgs and 1 or 0 end
	RunConsoleCommand( "pg_targetids", CV( nNew ) )
	Core.Print( "General", "You have " .. (nNew == 0 and "disabled" or "enabled") .. " player labels" )
end
Core.Register( "Client/TargetIDs", ToggleTargetIDs )

local function ToggleThirdperson( varArgs )
	Thirdperson = varArgs[ 1 ]
end
Core.Register( "Client/Thirdperson", ToggleThirdperson )

local function ToggleChat( to )
	local nTime = type( to ) != "table" and (to and 0 or 1) or GetConVar( "hud_saytext_time" ):GetInt()
	if nTime > 0 then
		Core.Print( "General", "The chat has been hidden." )
		RunConsoleCommand( "hud_saytext_time", "0" )
	else
		RunConsoleCommand( "hud_saytext_time", "12" )
		timer.Simple( 0.1, function()
			Core.Print( "General", "The chat has been restored." )
		end )
	end
end
Core.Register( "Client/Chat", ToggleChat )

local function ChangeWater()
	local target = 1 - GetConVar( "r_waterdrawrefraction" ):GetInt()
	local contarget = CV( target )
	RunConsoleCommand( "r_waterdrawrefraction", contarget )
	RunConsoleCommand( "r_waterdrawreflection", contarget )
	Core.Print( "General", "Water reflection and refraction have been " .. (target == 0 and "disabled" or "re-enabled") .. "!" )
end
Core.Register( "Client/Water", ChangeWater )

local function ClearDecals()
	RunConsoleCommand( "r_cleardecals" )
	Core.Print( "General", "All players decals have been cleared from your screen." )
end
Core.Register( "Client/Decals", ClearDecals )

local function ToggleSky()
	local target = 1 - GetConVar( "r_3dsky" ):GetInt()
	RunConsoleCommand( "r_3dsky", CV( target ) )
	Core.Print( "General", "3D Sky is now " .. (target == 1 and "enabled" or "disabled") .. "." )
end
Core.Register( "Client/Sky3D", ToggleSky )

local function ReceiveURL( varArgs )
	gui.OpenURL( varArgs[ 1 ] )
end
Core.Register( "Client/URL", ReceiveURL )

local function ReceiveHop( varArgs )
	local function SpawnConnect( arg )
		if Iv( lp() ) and arg[ 2 ] then
			Derma_Query( "Are you sure you want to connect to '" .. arg[ 3 ] .. "'?", "Switching server within pG", "Yes", function() if IsValid( LocalPlayer() ) then LocalPlayer():ConCommand( "connect " .. arg[ 2 ] ) end end, "No", function() end )
		end
	end
	
	if varArgs[ 1 ] == false then
		SpawnConnect( varArgs )
	elseif varArgs[ 1 ] == true then
		local tab, func, callback = varArgs[ 2 ], {}, function( addr, name )
			if addr == "" then return end
			SpawnConnect( { false, addr, name } )
		end
		
		for i = 1, #tab do
			func[ #func + 1 ] = tab[ i ][ 1 ]
			func[ #func + 1 ] = tab[ i ][ 2 ][ 1 ] or ""
			func[ #func + 1 ] = tab[ i ][ 2 ][ 2 ] or tab[ i ][ 1 ]
		end
		
		Core.SpawnWindow( { ID = "Query", Dimension = { x = 100, y = 100 }, Args = { Title = tab.Title, Mouse = true, Blur = true, Caption = tab.Caption, Custom = func, Count = #tab, Callback = callback } } )
	end
end
Core.Register( "Client/Redirect", ReceiveHop )

local function AutoDemo( varArgs )
	local name = varArgs[ 1 ]
	if name then
		local base = "pg_" .. game.GetMap() .. "_" .. name .. "_"
		for i = 1, 100 do
			if not file.Exists( base .. i .. ".dem", "GAME" ) then
				base = base .. i
				break
			end
		end
		
		Core.DemoData = { Map = game.GetMap(), Name = base, Ents = Core.ClientEnts or {}, Names = Core.EntNames or {}, Vars = Core.GetNetVars() }
		
		if varArgs[ 2 ] then
			hook.Remove( "HUDPaint", "DrawRecordingIcon" )
			timer.Simple( 30, function()
				AutoDemo( { Callback = true } )
			end )
		else
			local out = {}
			if file.Exists( Settings.Demos, Settings.Provider ) then
				local data = file.Read( Settings.Demos, Settings.Provider )
				if data and data != "" then
					out = util.JSONToTable( data ) or {}
				end
			end
			
			out[ base ] = Core.DemoData
			file.Write( Settings.Demos, util.TableToJSON( out, true ) )
		end
		
		RunConsoleCommand( "record", base )
	else
		RunConsoleCommand( "stop" )
		
		if varArgs.Callback and Core.DemoData then
			timer.Simple( 5, function()
				local dat = file.Read( Core.DemoData.Name .. ".dem", "GAME" )
				if not dat then return end
				
				Core.DemoData.Names = nil
				Core.SubmitAdmin( dat, util.TableToJSON( Core.DemoData ) )
			end )
		end
	end
end
Core.Register( "Client/AutoDemo", AutoDemo )

local WeaponFlip, FlipStyle
local function FlipWeapons( varArgs )
	if Iv( lp() ) then
		WeaponFlip = not WeaponFlip
		FlipStyle = not WeaponFlip
		
		local n = 0
		for _,wep in pairs( lp():GetWeapons() ) do
			if wep.ViewModelFlip != FlipStyle then
				wep.ViewModelFlip = FlipStyle
			end
			
			n = n + 1
		end
		
		if n > 0 then
			Core.Print( "General", "Your weapons have been flipped!" )
		else
			Core.Print( "General", "You had no weapons to flip. Flip again to revert back." )
		end
	end
end
Core.Register( "Client/WeaponFlip", FlipWeapons )

local function FormatSteamText( varArgs )
	Core.GetPlayerName( util.SteamIDTo64( varArgs[ 3 ] ), function( uid, name, arg )
		Core.Print( varArgs[ 1 ], string.gsub( varArgs[ 2 ], "{STEAM}", name ) )
	end, varArgs )
end
Core.Register( "Client/SteamText", FormatSteamText )

local function SetMuteAll( varArgs )
	local bMute = varArgs[ 1 ]
	for _,p in pairs( player.GetHumans() ) do
		if lp() and p != lp() then
			if bMute and not p:IsMuted() then
				p:SetMuted( true )
			elseif not bMute and p:IsMuted() then
				p:SetMuted( false )
			end
		end
	end
	
	Core.Print( "General", "All players have been " .. (bMute and "muted" or "unmuted") .. "." )
end
Core.Register( "Client/MuteAll", SetMuteAll )

function Core.MutePlayer( varArgs )
	if not varArgs.Player then
		local str, stm = tostring( varArgs.Find )
		if util.SteamIDTo64( string.upper( str ) ) != "0" then
			stm = string.upper( str )
		end
		
		for _,p in pairs( player.GetHumans() ) do
			if stm and p:SteamID() == stm then
				varArgs.Player = p
				break
			elseif not stm and string.find( string.lower( p:Name() ), str, 1, true ) then
				varArgs.Player = p
				break
			end
		end
	end
	
	local ply = varArgs.Player
	if IsValid( ply ) then
		if ply == lp() then
			return Core.Print( "General", "Congratulations! You did it! The most useful thing available in this gamemode!\n\n\n\nHa. Nope! Can't let you, buddy." )
		end
		
		if varArgs.Type == "Chat" then
			local to = not ply.ChatMuted
			if varArgs.Force != nil then to = varArgs.Force end
			
			ply.ChatMuted = to
			Core.Print( "General", ply:Name() .. " has been locally " .. (ply.ChatMuted and "chat muted" or "chat unmuted") )
		elseif varArgs.Type == "Voice" then
			local to = not ply:IsMuted()
			if varArgs.Force != nil then to = varArgs.Force end
			
			ply:SetMuted( to )
			Core.Print( "General", ply:Name() .. " has been locally " .. (ply:IsMuted() and "voice muted" or "voice unmuted") )
		end
		
		local bits = (ply.ChatMuted and 2 or 0) + (ply:IsMuted() and 1 or 0)
		Settings.Data.Mutes = Settings.Data.Mutes or {}
		Settings.Data.Mutes[ ply:SteamID() ] = bits > 0 and bits
		Settings:Save()
	elseif varArgs.Find then
		Core.Print( "General", "Couldn't find a player matching '" .. varArgs.Find .. "'" )
	end
end
Core.Register( "Client/MuteSingle", Core.MutePlayer )

local function PlatformEntities( ar )
	local more = ar:Bit()
	
	Core.ClientEnts = {}
	
	for i = 1, ar:UInt( 32 ) do
		local u = ar:UInt( 16 )
		local emb = ar:Bit() and ar:Int( 12 )
		
		Core.ClientEnts[ u ] = { ar:Int( 8 ), emb }
	end
	
	if more then
		Core.EntNames = {}
		
		for i = 1, ar:UInt( 8 ) do
			Core.EntNames[ ar:String() ] = ar:UInt( 8 )
		end
		
		local index = IndexPlatform
		for i = 1, ar:UInt( 16 ) do
			index( ar:UInt( 16 ) )
		end
		
		for i = 1, ar:UInt( 16 ) do
			index( ar:UInt( 16 ), ar:UInt( 20 ) )
		end
	end
end
Core.Register( "Client/Entities", PlatformEntities )

local HelpData, HelpText
local function SetHelp( varArgs )
	HelpData = varArgs
	HelpText = varArgs.HelpText
	varArgs.HelpText = nil
	
	table.sort( HelpData, function( a, b )
		if not a or not b or not a[ 2 ] or not a[ 2 ][ 1 ] then return false end
		return a[ 2 ][ 1 ] < b[ 2 ][ 1 ]
	end )
end
Core.Register( "Inner/SetHelp", SetHelp )

local function ShowHelp( varArgs )
	if varArgs then return Core.Trigger( "SettingsHelp" ) end
	
	print( "\n\nBelow is a list of all available commands and their aliases:\n\n" )
	
	for _,data in pairs( HelpData ) do
		local desc, alias = data[ 1 ], data[ 2 ]
		local main = table.remove( alias, 1 )
		
		MsgC( Color( 212, 215, 134 ), "\tCommand: " ) MsgC( color_white, main .. "\n" )
		MsgC( Color( 212, 215, 134 ), "\t\tAliases: " ) MsgC( color_white, (#alias > 0 and string.Implode( ", ", alias ) or "None") .. "\n" )
		MsgC( Color( 212, 215, 134 ), "\t\tDescription: " ) MsgC( color_white, desc .. "\n\n" )
		
		table.insert( alias, 1, main )
	end
	
	Core.Print( "General", "A list of commands and their descriptions has been printed in your console! Press ~ to open." )
end
Core.Register( "Inner/ShowHelp", ShowHelp )

function Core.ObtainHelp()
	return HelpData, HelpText
end

function Core.ToggleSound( value )
	local num = tonumber( string.sub( value, 1, #value - 1 ) )
	
	if timer.Exists( "SoundStopper" ) then
		timer.Remove( "SoundStopper" )
	end
	
	if not num then return end
	timer.Create( "SoundStopper", num, 0, function()
		RunConsoleCommand( "stopsound" )
	end )
end

function Core.ToggleGunSounds( value )
	GunSoundsDisabled = value
end

function Core.SetFootstepType( value )
	if value == "All" then
		Core.FootstepType = nil
	elseif value == "None" then
		Core.FootstepType = 1
	elseif value == "Only local" then
		Core.FootstepType = 2
	elseif value == "Only remote" then
		Core.FootstepType = 3
	end
end

function Core.SetPreferredModel( value )
	if not Core.StartSend.Departed then
		Core.StartSend.Model = value
	else
		Core.Send( "Model", { value } )
	end
end

function Core.SetViewInterp( value )
	ViewInterp = value
end

function Core.SetSteadyView( value )
	SteadyView = value
end

function Core.SetBackgroundBlur( bool )
	if not Core.BackgroundBlur then
		Core.BackgroundBlur = Derma_DrawBackgroundBlur
	end
	
	Derma_DrawBackgroundBlur = bool and function() end or Core.BackgroundBlur
end


local function EntityCheckPost()	
	if Settings:Get( "KickTime" ) then
		Core.StartSend.Kick = Core.SetKickFunc( { Settings:Get( "KickTime" ), true } )
	end
	
	Core.Send( "Entry", Core.StartSend )
	Core.StartSend.Departed = true

	hook.Remove( "PlayerTick", "TickWidgets" )
	hook.Remove( "PreDrawHalos", "PropertiesHover" )
	hook.Remove( "PostDrawEffects", "RenderHalos" )
	
	local ply = lp()
	if Iv( ply ) then
		ply.Style = Core.RequiredStyle or Styles.Normal
		ply:SetViewOffset( PlayerData.ViewStand )
		ply:SetViewOffsetDucked( PlayerData.ViewDuck )
	end
end
hook.Add( "InitPostEntity", "StartEntityCheck", EntityCheckPost )

local ShowPlayers = SeePlayers:GetBool()
local function SpawnPlayerCheck( ent )
	if not Iv( ent ) then return end
	if ent:IsPlayer() then
		for id,bits in pairs( Settings.Data.Mutes or {} ) do
			local data = tonumber( bits )
			if id == ent:SteamID() and data then
				if bit.band( data, 1 ) > 0 then ent:SetMuted( true ) end
				if bit.band( data, 2 ) > 0 then ent.ChatMuted = true end
			end
		end
	else
		if ent:GetClass() == "env_spritetrail" or ent:GetClass() == "beam" then
			ent:SetNoDraw( not ShowPlayers )
		end
	end
end
hook.Add( "OnEntityCreated", "SpawnPlayerCheck", SpawnPlayerCheck )

local function VisibilityCallback( CVar, Previous, New )
	local target = tonumber( New ) != 1 
	for _,ent in pairs( ents.FindByClass( "env_spritetrail" ) ) do
		ent:SetNoDraw( target )
	end
	for _,ent in pairs( ents.FindByClass( "beam" ) ) do
		ent:SetNoDraw( target )
	end
	for _,ply in pairs( player.GetAll() ) do
		ply:SetNoDraw( target )
		
		if not ply:IsBot() then
			ply:DrawShadow( not target )
		end
	end
	ShowPlayers = SeePlayers:GetBool()
	Core.SetSpecVis( tonumber( New ), true )
end
cvars.AddChangeCallback( "pg_showothers", VisibilityCallback )

local function PlayerVisiblityCheck( ply )
	if not ShowPlayers then return true end
end
hook.Add( "PrePlayerDraw", "PlayerVisiblityCheck", PlayerVisiblityCheck )


function Core.Print( szPrefix, varText )
	if type( varText ) != "table" then
		varText = { varText }
	end
	
	chat.AddText( color_white, "[", Core.TranslateColor( Core.Config.Prefixes[ szPrefix ], true ), szPrefix, color_white, "] ", unpack( varText ) )
end
Core.Register( "Global/Print", ChatPrint )

local function ChatReceive( l )
	Core.Config.NetReceive = Core.Config.NetReceive + l
	Core.Print( net.ReadString(), net.ReadString() )
end
net.Receive( "QuickPrint", ChatReceive )

local function ChatEdit( nIndex, szName, szText, szID )
	if szID == "joinleave" then return true end
end
hook.Add( "ChatText", "SuppressMessages", ChatEdit )

local hex = { A = 1, B = 1, C = 1, D = 1, E = 1, F = 1, ["0"] = 1, ["1"] = 1, ["2"] = 1, ["3"] = 1, ["4"] = 1, ["5"] = 1, ["6"] = 1, ["7"] = 1, ["8"] = 1, ["9"] = 1 }
local function ValidHexColor(col)
	if #col != 7 then return false end
	if col[1] != "#" then return false end
	for i, c in ipairs(col:Split("")) do
		if i == 1 then continue end
		if not hex[c:upper()] then return false end
	end
	return true
end

local function HexToColor(hex)
	local r = tonumber(hex[2] .. hex[3], 16)
	local g = tonumber(hex[4] .. hex[5], 16)
	local b = tonumber(hex[6] .. hex[7], 16)
	return Color(r, g, b)
end

function ParseColoredText(text, limitstart)
	local ret = {}
	local splote = text:Split("")

	local skip = 1
	for k, v in ipairs(splote) do
		if k < skip then continue end
		-- print(k, v, skip)
		if v == "#" then
			if limitstart then
				if k != 1 then continue end
			end

			local test = table.concat(splote, "", k, k + math.min(6, #splote - k))
			-- print(test)
			if ValidHexColor(test) then
				if k != 1 then
					table.insert(ret, table.concat(splote, "", skip, k - 1))
				end
				table.insert(ret, HexToColor(test))
				skip = k + 7
			end
		end
	end
	if skip <= #splote then
		table.insert(ret, table.concat(splote, "", skip))
	end

	return ret
end

local function ChatTag( ply, szText, bTeam, bDead )
	if ply.ChatMuted then
		print( "[CHAT MUTE] " .. ply:Name() .. ": " .. szText )
		return true
	end
	
	local tab = {}	
	if ply:GetObj( "Spectating", false ) then
		table.insert( tab, Color( 189, 195, 199 ) )
		table.insert( tab, "*SPEC* " )
	end
	
	if Iv( ply ) and ply:IsPlayer() then
		table.insert( tab, color_white )
		
		if ply:GetNW2Int("VIPLevel") > 0 then
			local tag = ply:GetNW2String("VIPTAG")
			if tag != "" then
				table.insert(tab, "[")
				for _, v in ipairs(ParseColoredText(tag, ply:GetNW2Int("VIPLevel") == 1)) do
					table.insert(tab, v)
				end
				table.insert(tab, color_white)
				table.insert(tab, "] ")
			else
				table.insert( tab, "[" )
		
				local rank, color = Core.ObtainRank( ply:GetObj( "Rank", -1 ), ply:GetObj( "Style", Styles.Normal ) )
				table.insert( tab, color )
				table.insert( tab, rank )
				table.insert( tab, color_white )
				table.insert( tab, "] " )
			end
		else
			table.insert( tab, "[" )
		
			local rank, color = Core.ObtainRank( ply:GetObj( "Rank", -1 ), ply:GetObj( "Style", Styles.Normal ) )
			table.insert( tab, color )
			table.insert( tab, rank )
			table.insert( tab, color_white )
			table.insert( tab, "] " )
		end

		table.insert( tab, Color( 98, 176, 255 ) )

		if ply:GetNW2Int("VIPLevel") > 0 then
			local name = ply:GetNW2String("VIPNAME")
			if name != "" then
				for _, v in ipairs(ParseColoredText(name, ply:GetNW2Int("VIPLevel") == 1)) do
					table.insert(tab, v)
				end
				table.insert(tab, color_white)
			else
				table.insert( tab, ply:Name() )
			end
		else
			table.insert( tab, ply:Name() )
		end
	else
		table.insert( tab, "Console" )
	end
	
	table.insert( tab, color_white )
	table.insert( tab, ": " )
	if IsValid(ply) and ply:GetNW2Int("VIPLevel") > 1 then
		local x = ply:GetNW2String("VIPCHAT")
		if x != "" then
			table.insert(tab, ParseColoredText(x, true)[1])
		end
	end
	table.insert( tab, szText )
	
	chat.AddText( unpack( tab ) )
	return true
end
hook.Add( "OnPlayerChat", "TaggedChat", ChatTag )


Settings.Data = {}
Settings.Provider = "DATA"
Settings.ConnectionStart = st()
Settings.Identifier = Core.Config.GameType
Settings.Base = Core.Config.BasePath .. "settings.txt"
Settings.Maps = Core.Config.Identifier .. "-list.txt"
Settings.Demos = Core.Config.BasePath .. "pg-demos.txt"
Settings.Extensions = Core.Config.BaseType .. "/gamemode/extensions/"
Settings.ToggleValues = {}
Settings.Toggles = {
	["CHAT_TIME"] = { ToggleChat, function() return GetConVar( "hud_saytext_time" ):GetInt() > 0 end, nil, "Chat visibility" },
	["GUI_VISIBILITY"] = { SetGUIVisibility, function() return GetConVar( "pg_showgui" ):GetInt() > 0 end, nil, "GUI visibility" },
	["HUD_SPECTATOR"] = { SetSpecVisibility, function() return GetConVar( "pg_showspec" ):GetInt() > 0 end, nil, "Spectator HUD" },
	["GAME_PLAYERS"] = { SetPlayerVisibility, function() return GetConVar( "pg_showothers" ):GetInt() > 0 end, nil, "See other players" },
	["GAME_PLAYER_IDS"] = { ToggleTargetIDs, function() return GetConVar( "pg_targetids" ):GetInt() > 0 end, nil, "Player name labels" },
	["GAME_ZONES"] = { SetZoneVisibility, function() return GetConVar( "pg_showzones" ):GetInt() > 0 end, nil, "Toggle hidden zones" },
	["GAME_NOZONES"] = { function( b ) SetZoneVisibility( { b and -1 or (Settings:ToggleValue( "GAME_ZONES" ) and 1 or 0) } ) end, function() return GetConVar( "pg_showzones" ):GetInt() == -1 end, nil, "Hide all zones" },
	["HUD_DEFTYPE"] = { "DefaultHud", true, Core.SetDefaultHud, "Default HUD" },
	["HUD_PLAINTYPE"] = { "SimpleHud", false, Core.SetSimpleHud, "Simple HUD" },
	["HUD_OLDTYPE"] = { "HudOldVersion", false, Core.SetSurflineHud, "Surfline HUD" },
	["HUD_OPACITY"] = { "HudOpacity", "Default", Core.SetHUDOpacity },
	["HUD_TYPE_FONT"] = { "SimpleHudFont", "Medium", Core.SetSimpleFont },
	["HUD_NOTIFICATION"] = { "HudNotify", "Both" },
	["HUD_CONTEXT"] = { "HudContext", "C", Core.SetContextKey },
	["HUD_DECIMAL"] = { "HudDecimal", "3", Core.SetDecimalCount },
	["HUD_PERMSYNC"] = { "HudPermSync", false, Core.SetPermSync, "Always show sync" },
	["HUD_VEL3D"] = { "HudVelocity3D", false, Core.SetVelocityType, "Show 3D velocity" },
	["HUD_NOVEL"] = { "HudNoVelocity", false, Core.SetShowVelocity, "Show no velocity" },
	["HUD_NOBLUR"] = { "NoBlurDraw", false, Core.SetBackgroundBlur, "Don't blur backgrounds" },
	["HUD_DATETIME"] = { "ShowDateTime", false, Core.SetShowDateTime, "Show time of day" },
	["HUD_STAGE"] = { "ShowStageTimer", false, Core.SetShowStage, "HUD stage timer" },
	["NOTIFY_WRSOUND"] = { "SoundWR", true, nil, "WR Sounds" },
	["NOTIFY_SPECMSG"] = { "NotifySpecs", true, nil, "Notifications in spectator" },
	["NOTIFY_NOTHING"] = { "NotifyHideAll", false, nil, "Hide all notifications" },
	["NOTIFY_LJS"] = { "NotifyLJs", false, nil, "Show LJ messages" },
	["NOTIFY_LJMIN"] = { "NotifyLJMin", "260" },
	["NOTIFY_LJSTATS"] = { "NotifyLJStats", false, nil, "Show LJ strafes on GUI" },
	["NOTIFY_TAS"] = { "NotifyTAS", true, nil, "Show TAS messages" },
	["NOTIFY_STAGE"] = { "NotifyStage", true, nil, "Show stage messages" },
	["NOTIFY_STAGETOP"] = { "NotifyStageTopOnly", true, nil, "Only show #1 stage times" },
	["NOTIFY_STAGESPEC"] = { "NotifyStageSpec", false, nil, "Show stage differences in spectator" },
	["NOTIFY_COLORS"] = { "NotifyUseColors", false, Core.SetUseCustomColors, "Use custom colors" },
	["MISC_CP"] = { "CheckpointDelay", false },
	["MISC_NOSOUND"] = { "NoGameSound", "OFF", Core.ToggleSound },
	["MISC_FOOTSTEPS"] = { "NoFootsteps", "All", Core.SetFootstepType },
	["MISC_MODEL"] = { "PreferredModel", "", Core.SetPreferredModel },
	["MISC_NOGUNS"] = { "NoGunSound", false, Core.ToggleGunSounds, "Block gun sounds" },
	["MISC_SAVESTYLE"] = { "SaveLastStyle", false, nil, "Save last style" },
	["MISC_SHOWCONDIFF"] = { "ShowLastConnection", true, nil, "Show last connection time" },
	["MISC_SCORESPECS"] = { "SpecsScoreboard", false, nil, "List spectators" },
	["MISC_THIRDPERSON"] = { "Thirdperson", false, Core.SetThirdperson, "Third person mode" },
	["MISC_VIEWINTERP"] = { "ViewInterpolation", true, Core.SetViewInterp, "Enable view interpolation" },
	["MISC_STEADYVIEW"] = { "SteadyViewModel", false, Core.SetSteadyView, "No weapon sway" },
	["RADIO_MESSAGES"] = { "RadioMessages", false, nil, "Print title on song change" },
	["TRAIL_BLUE"] = { "TrailBlueSpeed", false, nil, "Blue when faster" },
	["TRAIL_RANGE"] = { "TrailFullRange", false, nil, "Increased view range" },
	["TRAIL_GROUND"] = { "TrailGroundOnly", false, nil, "Ground hits only" },
	["TRAIL_VAGUE"] = { "TrailVagueAlpha", false, nil, "More transparent" },
	["TRAIL_LABEL"] = { "TrailNoLabels", false, nil, "Hide landmarks" },
	["TRAIL_HUD"] = { "TrailNoHud", false, nil, "Hide trail HUD" }
}

local function SetMaps( varArgs )
	Settings.Data.Maps = varArgs[ 1 ]	
	Settings.Data[ Settings.Identifier ].MapVersion = varArgs[ 2 ]
	Settings.Data[ Settings.Identifier ].MapCount = varArgs[ 3 ]
	Settings.IsMapAltered = true
	
	Settings:Save()
	
	Core.SpawnWindow( { ID = "Nominate", Dimension = { x = 300, y = 400 }, Args = { Title = "Nominate a map", Mouse = true, Blur = true, Custom = varArgs[ 2 ] } } )
end
Core.Register( "Inner/SetMaps", SetMaps )

function Settings:Load()
	for _,str in pairs( HUDItems ) do
		if str == "CHudCrosshair" then
			HUDItems[ str ] = IsCrosshair:GetBool()
		else
			HUDItems[ str ] = true
		end
	end
	
	for id,data in pairs( self.Toggles ) do
		if type( data[ 2 ] ) != "function" then
			self.ToggleValues[ id ] = { data[ 1 ], data[ 2 ] }
			data[ 2 ] = function() return Settings:Get( unpack( Settings.ToggleValues[ id ] ) ) end
		end
	end
	
	Core.Config.RemoteURL = GetConVarString( "sv_downloadurl" )
	
	if GetConVarNumber( "fov_desired" ) < 90 then
		Core.Print( "General", "We noticed you are playing on a low FOV (" .. GetConVarNumber( "fov_desired" ) .. "), you can increase this by pressing F1 and scrolling down until you see 'Local FOV'. Try setting it to 90, you'll be able to see a lot better." )
	end
	
	if file.Exists( self.Base, self.Provider ) then
		local data = file.Read( self.Base, self.Provider )
		if data and data != "" then
			self.Data = util.JSONToTable( data ) or {}
		end
	else
		Core.Print( "General", "Welcome to " .. GAMEMODE.DisplayName .. " " .. GAMEMODE.Name .. "! Is there anything not to your liking? You can change a lot of settings in the F1 menu or by typing !settings. Still not satisfied? The !forums will always be able to help you out!" )
	end
	
	if file.Exists( self.Maps, self.Provider ) then
		local data = file.Read( self.Maps, self.Provider )
		if data and data != "" then
			local decomp = util.Decompress( data )
			if decomp then
				self.Data.Maps = util.JSONToTable( decomp ) or {}
			end
		end
	end
	
	local exts = file.Find( self.Extensions .. "*.lua", "LUA" )
	for _,f in pairs( exts ) do
		include( self.Extensions .. f )
	end
	
	if not self.Data[ self.Identifier ] then
		self.Data[ self.Identifier ] = {}
	end
	
	for _,data in pairs( self.Toggles ) do
		if data[ 3 ] then data[ 3 ]( data[ 2 ]() ) end
	end
	
	for key,data in pairs( self.Data ) do
		if string.sub( key, 1, 11 ) == "CustomColor" then
			Core.SetCustomColor( tonumber( string.sub( key, 12 ) ), data )
		end
	end
	
	if self:ToggleValue( "MISC_SAVESTYLE" ) then
		local style = self:Get( "LastStyle", 1 )
		if style != Core.Config.Style.Normal then
			Core.StartSend.Style = style
		end
	end
	
	local diff = os.time() - self:Get( "LastSaved", os.time() )
	if diff > 0 and self:ToggleValue( "MISC_SHOWCONDIFF", true ) then
		local pr = ""
		if diff > 3600 * 24 * 7 then pr = math.floor( diff / (3600 * 24 * 7) ) pr = pr .. (pr == 1 and " week" or " weeks")
		elseif diff > 3600 * 24 then pr = math.floor( diff / (3600 * 24) ) pr = pr .. (pr == 1 and " day" or " days")
		elseif diff > 3600 then pr = math.floor( diff / 3600 ) pr = pr .. (pr == 1 and " hour" or " hours")
		else pr = math.floor( diff / 60 ) pr = pr .. (pr == 1 and " minute" or " minutes")
		end
		
		Core.Print( "General", "You were last on our servers " .. pr .. " ago." )
	end
end

function Settings:Save( silent )
	if not file.Exists( Core.Config.BasePath, self.Provider ) then
		file.CreateDir( Core.Config.BasePath )
	end
	
	self:SetCommons()
	
	local mapAddr = self.Data.Maps
	if self.Data.Maps then
		if not silent and self.IsMapAltered then
			local raw = util.Compress( util.TableToJSON( self.Data.Maps ) )
			if raw then
				file.Write( self.Maps, raw )
			end
			self.IsMapAltered = nil
		end
		
		self.Data.Maps = nil
	end
	
	file.Write( self.Base, util.TableToJSON( self.Data, true ) )
	
	if mapAddr then
		self.Data.Maps = mapAddr
	end
end

function Settings:SetCommons()
	self.Data.ConnectionTime = self:Get( "ConnectionTime", 0 ) + math.Round( (st() - self.ConnectionStart) / 3600, 8 )
	self.Data.LastSaved = os.time()
	self.Data.TotalTransferred = self:Get( "TotalTransferred", 0 ) + math.Round( (Core.Config.NetReceive + Core.GetSessionBytes()) / 1024, 2 )
	self.ConnectionStart = st()
	
	local top = math.floor( Core.GetMaximumVel() )
	if top > self:Get( "MaximumVel", 0 ) then
		self.Data.MaximumVel = top
	end
end

function Settings:Misc( szType, varArgs )
	if szType == "Finish" then
		self:Set( "TotalJumps", self:Get( "TotalJumps", 0 ) + varArgs[ 1 ] )
		self:Set( "TotalStrafes", self:Get( "TotalStrafes", 0 ) + varArgs[ 2 ] )
		self:Set( "AverageSync", math.Round( (self:Get( "AverageSync", 0 ) * self:Get( "TotalFinishes", 0 ) + varArgs[ 3 ]) / (self:Get( "TotalFinishes", 0 ) + 1), 2 ) )
		self:Set( "TotalFinishes", self:Get( "TotalFinishes", 0 ) + 1 )
	elseif szType == "Reset" then
		self:Set( "TotalTransferred" )
		self:Set( "MaximumVel" )
		self:Set( "TotalJumps" )
		self:Set( "TotalStrafes" )
		self:Set( "AverageSync" )
		self:Set( "TotalFinishes" )
		self:Set( "ConnectionTime", nil, true )
	elseif szType == "MapCount" or szType == "MapVersion" then
		return self.Data[ self.Identifier ][ szType ] or varArgs
	end
end

function Settings:Get( szKey, varDefault )
	if self.Data[ szKey ] != nil then
		return self.Data[ szKey ]
	else
		return varDefault
	end
end

function Settings:Set( szKey, varObj, bSave )
	self.Data[ szKey ] = varObj
	
	if bSave then
		self:Save()
	end
end

function Settings.SetToggle( value, toggle )
	Settings:Set( toggle.Type, value, true )
	
	if toggle.Callback then
		toggle.Callback( value )
	end
end

function Settings:GetToggle( szKeyID )
	local tab = { ID = szKeyID }
	local data = self.Toggles[ szKeyID ]
	
	if data then
		local t = type( data[ 1 ] )
		if t == "function" then
			tab.Setter = data[ 1 ]
			tab.Default = data[ 2 ]
		elseif t == "string" then
			tab.Setter = self.SetToggle
			tab.Type = data[ 1 ]
			tab.Default = data[ 2 ]
			tab.Callback = data[ 3 ]
		end
		
		tab.Description = data[ 4 ]
	end
	
	return tab
end

function Settings:ToggleValue( szKey )
	return self.Toggles[ szKey ] and self.Toggles[ szKey ][ 2 ]()
end

function Core.GetSettings()
	return Settings
end


local function ClientTick()
	local ply = lp()
	if not Iv( ply ) then return timer.Simple( 1, ClientTick ) end
	timer.Simple( 5, ClientTick )
	
	ply:SetHull( PlayerData.HullMin, PlayerData.HullStand )
	ply:SetHullDuck( PlayerData.HullMin, PlayerData.HullDuck )
	
	local n = st()
	if not SilentSave then
		SilentSave = n
	else
		if n - SilentSave > 60 then
			SilentSave = n
			Settings:Save( true )
		end
	end
end

local function Initialize()
	Core.CreateFonts()
	Core.CreateHUD()
	Core.StartSend = { Platforms = true }
	
	Settings:Load()
	timer.Simple( 1, ClientTick )
	
	if engine.IsPlayingDemo() then
		if file.Exists( Settings.Demos, Settings.Provider ) then
			local data = file.Read( Settings.Demos, Settings.Provider )
			if data and data != "" then
				data = util.JSONToTable( data ) or {}
				
				for dem,dat in pairs( data ) do
					if dat.Map == game.GetMap() then
						Core.ClientEnts = dat.Ents
						Core.EntNames = dat.Names
						Core.GetNetVars( dat.Vars )
						
						break
					end
				end
			end
		end
	end
end
hook.Add( "Initialize", "ClientStartup", Initialize )