include( "modules/sv_boosterfix.lua")

-- These words are completely cancelled (the text behind just indicates what it USED to be filtered to)
local CancelWords = {
}

-- Anything containing this is completely cancelled (the text behind just indicates what it USED to be filtered to)
local CancelText = {
}

-- The words here will be changed to what it says if it's a SINGLE word
local FilterWords = {
}

-- This is globally filtered over everything
local FilterText = {
}

local Styles = Core.Config.Style
local Teams = Core.Config.Team
local DefaultWeapon = Core.Config.Player.DefaultWeapon

local Command = {}
Command.Func = {}
Command.Limit = 0.8
Command.Limiter = {}
Command.Timer = SysTime
Command.Pause = {}
Command.Restore = {}

local HelpData, HelpLength
local CommandMisc = Core.ContentText( "MiscCommandLimit" )

local _sub, _find, _low, _up, _gs, _len = string.sub, string.find, string.lower, string.upper, string.gsub, string.len
local _rand, _ceil = math.random, math.ceil
local _pairs, _insert = pairs, table.insert

--[[
	Description: Replaces occurrences in the text by a pattern
--]]
local function _rep( s, pat, repl, n )
    pat = _gs( pat, '(%a)', function( v ) return '[' .. _up( v ) .. _low( v ) .. ']' end )
    if n then return _gs( s, pat, repl, n ) else return _gs( s, pat, repl ) end
end

--[[
	Description: Loops over the chat filter items and replaces them
--]]
local function _filter( text )
	for input,output in _pairs( FilterText ) do
		text = _rep( text, input, output )
	end
	
	return text
end

--[[
	Description: Executes multiple chat filters
--]]
local function FilterAnyText( ply, text )
	if Command.Silenced then
		if Core.GetAdminAccess( ply ) == 0 then
			return ""
		end
	end
	
	local low = _low( text )
	if CancelWords[ low ] then
		Core.Print( ply, "General", Core.Text( "MiscIllegalChat", low ) )
		
		return ""
	elseif FilterWords[ low ] then
		return FilterWords[ low ]
	else
		for input,_ in _pairs( CancelText ) do
			if _find( low, input, 1, true ) then
				Core.Print( ply, "General", Core.Text( "MiscIllegalChat", input ) )
				
				return ""
			end
		end
		
		return _filter( text )
	end
end

--[[
	Description: Resets the command timer
--]]
local function RemoveLimit( ply )
	Command.Limiter[ ply ] = nil
end

--[[
	Description: Checks if the command is possible
	Notes: This is also called for console commands, which are far more spammable than chat commands (hence the negative time checking)
--]]
local function CommandPossible( ply )
	if not Command.Limiter[ ply ] then
		Command.Limiter[ ply ] = Command.Timer()
	else
		local dt = Command.Timer() - Command.Limiter[ ply ]
		if dt < -10 then
			return false
		elseif dt < -5 then
			Core.Print( ply, "General", Core.Text( "CommandBan" ) )
			Command.Limiter[ ply ] = Command.Limiter[ ply ] + 30
			return false
		end
		
		if dt < Command.Limit then
			Core.Print( ply, "General", Core.Text( "CommandLimiter", CommandMisc[ _rand( 1, #CommandMisc ) ], _ceil( Command.Limit - (Command.Timer() - Command.Limiter[ ply ]) ) ) )
			Command.Limiter[ ply ] = Command.Limiter[ ply ] + 0.5
			return false
		end
		
		Command.Limiter[ ply ] = Command.Timer()
	end
	
	return true
end
Core.CanExecuteCommand = CommandPossible

--[[
	Description: Quick function for adding a command (optionally with aliases)
--]]
local function AddCmd( varCommand, varFunc )
	local MainCommand, CommandList = "undefined", { "undefined" }
	if type( varCommand ) == "table" then
		MainCommand = varCommand[ 1 ]
		CommandList = varCommand
	elseif type( varCommand ) == "string" then
		MainCommand = varCommand
		CommandList = { varCommand }
	end

	Command.Func[ MainCommand ] = { CommandList, varFunc }
end
Core.AddCmd = AddCmd

--[[
	Description: Gets a function method by passing the main command name
--]]
local function GetCmd( szMain )
	if Command.Func[ szMain ] then
		return Command.Func[ szMain ][ 2 ]
	else
		return function() end
	end
end
Core.GetCmd = GetCmd

--[[
	Description: Quick function for adding an alias to an existing command
--]]
local function AddAlias( szMain, szAlias )
	if Command.Func[ szMain ] then
		if not table.HasValue( Command.Func[ szMain ][ 1 ], szAlias ) then
			Command.Func[ szMain ][ 1 ][ #Command.Func[ szMain ][ 1 ] + 1 ] = szAlias
			return true
		end
	end
end
Core.AddAlias = AddAlias

--[[
	Description: Counts all active commands and the assigned aliases
	Used by: Statistics for F1 window in Core.LoadRecords
--]]
local function CountCommands()
	-- Loop over the command table
	local total, alias = 0, 0
	for cmd,data in pairs( Command.Func ) do
		total = total + 1
		alias = alias + #data[ 1 ] - 1
	end
	
	-- Return both the values
	return total, alias
end
Core.CountCommands = CountCommands

--[[
	Description: Triggers the callback bundled to a chat command providing the arguments passed
	Used by: PlayerSay hook inside the gamemode
--]]
local function TriggerCmd( ply, szCommand, szText )
	if not CommandPossible( ply ) then return nil end

	local szFunc = nil
	local mainCommand, commandArgs = szCommand, {}
	
	if _find( szCommand, " ", 1, true ) then
		local splitData = string.Explode( " ", szCommand )
		mainCommand = splitData[ 1 ]

		local splitDataUpper = string.Explode( " ", szText )
		commandArgs.Upper = {}
		
		for i = 2, #splitData do
			_insert( commandArgs, splitData[ i ] )
			_insert( commandArgs.Upper, splitDataUpper[ i ] )
		end
	end
	
	if Command.Func[ mainCommand ] then
		szFunc = mainCommand
	else
		for _,data in _pairs( Command.Func ) do
			for __,alias in _pairs( data[ 1 ] ) do
				if mainCommand == alias then
					szFunc = data[ 1 ][ 1 ]
					break
				end
			end
		end
	end

	if not szFunc then szFunc = "invalid" end
	commandArgs.Key = mainCommand

	local varFunc = Command.Func[ szFunc ]
	if varFunc then
		varFunc = varFunc[ 2 ]
		return varFunc( ply, commandArgs )
	end
end


--[[
	Description: Resets the player if they're not spectating
--]]
local function Restart( ply, _, varArgs )
	if varArgs and varArgs != "bypass" then
		if not CommandPossible( ply ) then return end
	end
	
	if ply.Practice and (not varArgs or varArgs != "bypass") then
		Core.Print( ply, "Timer", Core.Text( "StylePracticeEnabled" ) )
	end
	
	-- All we have to check is if they're spectating or not
	if ply:Team() != Teams.Spectator then
		if ply.TAS and ply.TAS.IsPaused( ply ) then
			return Core.Print( ply, "Timer", Core.Text( "TASCommandResetPause" ) )
		end
		
		ply:ResetSpawnPosition()
		
		local tt = ply.TryTrack
		if tt then
			tt.Amount = tt.Amount - 1
			
			if tt.Type == "count" then
				Core.Print( ply, "General", Core.Text( "CommandTriesLeft", tt.Amount, tt.Amount == 1 and "try" or "tries" ) )
				
				if tt.Amount == 0 then
					ply.TryTrack = nil
					Core.Print( ply, "General", Core.Text( "CommandTriesStopped" ) )
				end
			elseif tt.Type == "kick" then
				if tt.Amount <= 0 then
					ply:Kick( "You exceeded the amount of tries!" )
				elseif tt.Amount == 1 then
					Core.Print( ply, "General", Core.Text( "CommandTriesLeft", tt.Amount, "try" ) )
				end
			end
		end
	else
		Core.Print( ply, "Timer", Core.Text( "SpectateRestart" ) )
	end
end
concommand.Add( "reset", Restart )

--[[
	Description: Changes the style
	Notes: Checks if they're trying to change to bonus without a valid bonus
--]]
local function SetStyle( ply, _, varArgs, __, nBonus )
	local bypassed
	if varArgs and type( varArgs ) != "string" then
		if not CommandPossible( ply ) then return end
	elseif type( varArgs ) == "string" then
		varArgs = { tonumber( varArgs ) }
		bypassed = true
	end

	-- Check if they put a valid style that's not already set
	local val = tonumber( varArgs[ 1 ] )
	if not val or (val < Styles.Normal and not Core.Config.Modes[ val ]) or val > Core.Config.MaxStyle then return end
	
	if tonumber( varArgs[ 1 ] ) == ply.Style or (Core.IsValidBonus( ply.Style ) and nBonus and ply.Style == Styles.Bonus + nBonus) then
		if nBonus and ply.Style == Styles.Bonus + nBonus then
			return Restart( ply, nil, "bypass" )
		elseif nBonus then
			if bypassed then return end
		else
			if bypassed then return end
			
			local add = ""
			if ply.Practice then add = " (Type !p again to leave practice mode)"
			elseif ply.TAS then add = " (Type !tasmenu and press 5 to leave TAS mode)" end
			
			return Core.Print( ply, "Timer", Core.Text( "StyleEqual", Core.StyleName( ply.Style ), add ) )
		end
	end
	
	-- Parse the provided ID
	local nStyle = tonumber( varArgs[ 1 ] ) or Styles.Normal
	local bMissingBonus = ply:ResetSpawnPosition( { nStyle, nBonus } )
	
	-- If we're in a race, de-queue them
	if ply.Race and not ply.Race.Prestyle then
		ply.Race:Abandon( ply )
	end
	
	-- If we're rocking TAS, make sure they don't do cheeky stuff
	if ply.TAS then
		if nStyle == Core.Config.PracticeStyle then
			return Core.Print( ply, "Timer", Core.Text( "TASChangeStylePractice" ) )
		end
		
		if not ply.InSpawn then
			return Core.Print( ply, "Timer", Core.Text( "TASChangeStyleSpawn" ) )
		else
			ply.TAS.ResetTimer( ply, true )
		end
	end
	
	-- Check if we have a valid bonus
	if bMissingBonus then
		return Core.Print( ply, "Timer", Core.Text( "StyleBonusNone", nStyle > Styles.Bonus and " for this ID." or "" ) )
	elseif nBonus then
		ply:ResetTimer()
	elseif Core.IsValidBonus( ply.Style ) then
		ply:BonusReset()
	elseif nStyle == Core.Config.PracticeStyle then
		ply.InSpawn = nil
		ply.Tn = nil
		ply:Spectator( "PlayerRestart" )
		
		local ar = Core.Prepare( "Timer/Start" )
		ar:UInt( 0, 2 )
		ar:Send( ply )
	end

	-- Finally load in their data for the style
	ply:LoadStyle( nStyle, nBonus )
end
concommand.Add( "style", SetStyle )

--[[
	Description: Spectate console command
	Notes: Takes arguments to spectate by ID (for the scoreboard)
--]]
local function DoSpectate( ply, _, varArgs )
	if varArgs and varArgs != "bypass" then
		if not CommandPossible( ply ) then return end
	end
	
	if ply.Spectating and varArgs and type( varArgs ) == "table" and varArgs[ 1 ] then
		return ply:Spectator( "NewById", { varArgs[ 1 ], true, varArgs[ 2 ] } )
	elseif ply.Spectating then
		local target = ply:GetObserverTarget()
		ply:SetTeam( Teams.Players )
		ply:KillSilent()
		ply:Spawn()
		ply:ResetTimer()
		ply.Spectating = false
		ply:SetObj( "Spectating", false, true )
		ply:ToggleSyncState( nil, true )
		
		-- Clear their list
		Core.Send( ply, "Spectate/Clear" )
		
		-- Clear out sync
		local ar = Core.Prepare( "Timer/SetSync" )
		ar:String( "" )
		ar:Bit( false )
		ar:Send( ply )
		
		ply:Spectator( "End", { target } )
	else
		-- Set a published variable
		ply:SetObj( "Spectating", true, true )
		Core.Send( ply, "Spectate/Clear" )
		
		-- Actually spawn them as spectator
		ply.Spectating = true
		ply:KillSilent()
		ply:StopAnyTimer()
		GAMEMODE:PlayerSpawnAsSpectator( ply )
		ply:SetTeam( TEAM_SPECTATOR )
		
		-- If we're in a race, de-queue them
		if ply.Race then
			ply.Race:Abandon( ply )
		end

		-- Also enable key tracker if they have it enabled
		if ply.ShowKeys then
			Core.EnableKeyTrack()
		end
		
		if varArgs and type( varArgs ) == "table" and varArgs[ 1 ] then
			return ply:Spectator( "NewById", { varArgs[ 1 ], nil, varArgs[ 2 ] } )
		end
		
		ply:Spectator( "New" )
	end
end
concommand.Add( "spectate", DoSpectate )

--[[
	Description: Nominates a map IF everything is valid and okay
--]]
local function Nominate( ply, _, varArgs )
	if not CommandPossible( ply ) then return end
	if not varArgs[ 1 ] then return end
	if varArgs[ 1 ] == "none" or varArgs[ 1 ] == "blank" or varArgs[ 1 ] == "wipe" then return ply:RTV( "Denominate" ) end
	if varArgs[ 1 ] == game.GetMap() then return Core.Print( ply, "Notification", Core.Text( "NominateOnMap" ) ) end
	if not Core.MapCheck( varArgs[ 1 ] ) then return Core.Print( ply, "Notification", Core.Text( "MapInavailable", varArgs[ 1 ] ) ) end
	if not Core.MapCheck( varArgs[ 1 ], true ) then return Core.Print( ply, "Notification", Core.Text( "MapMissing" ) ) end
	
	ply:RTV( "Nominate", varArgs[ 1 ] )
end
concommand.Add( "nominate", Nominate )

--[[
	Description: Noclip by command
	Notes: Strips weapons so people are less likely to start shooting	
--]]
local function DoNoclip( ply, _, varArgs )
	if not CommandPossible( ply ) then return end
	if not ply:xAdminHasPermission("noclip") then
		if ply.Practice then
			if ply:GetMoveType() != MOVETYPE_NOCLIP then
				ply:SetMoveType( MOVETYPE_NOCLIP )
				ply:StripWeapons()
			else
				ply:SetMoveType( MOVETYPE_WALK )
			end
		else
			Core.Print( ply, "General", Core.Text( "StyleNoclip" ) )
		end
	else
		Core.Print( ply, "General", Core.Text( "StyleNoclip" ) )
	end
end
concommand.Add( "pnoclip", DoNoclip )

--[[
	Description: An alias/bindable console command for the checkpoint commands
--]]
local function Checkpoint( ply, szCmd, varArgs )
	if not CommandPossible( ply ) then return end
	if ply.Practice then
		local func = GetCmd( "cp" )
		func( ply, { Key = szCmd } )
	else
		Core.Print( ply, "General", Core.Text( "StyleTeleport" ) )
	end
end
concommand.Add( "cpload", Checkpoint )
concommand.Add( "cpsave", Checkpoint )

-- Table containing server commands and their functionality
local ServerCommands = {
	["gg"] = function( args )
		GAMEMODE:UnloadGamemode( "Change" )
		RunConsoleCommand( "changelevel", #args > 0 and args[ 1 ] or game.GetMap() )
	end,
	["savebot"] = function()
		GAMEMODE:UnloadGamemode( "Bot Save" )
	end,
	["stop"] = function()
		GAMEMODE:UnloadGamemode( "Change" )
		RunConsoleCommand( "exit" )
	end,
	["control"] = function( args )
		if #args > 0 then
			if string.find( string.Implode( "", args ), ":", 1, true ) then
				local szJoined = string.Implode( " :", args )
				szJoined = string.gsub( szJoined, " :: ", "" )
				szJoined = string.gsub( szJoined, " :", " " )
				args = string.Explode( " ", szJoined )
			end
			
			local szCmd = args[ 1 ]
			if szCmd == "debug" then
				print( "Debug", "Used memory: " .. collectgarbage("count") )
			elseif szCmd == "admin" then
				if #args != 3 then return print( "Invalid parameters supplied!" ) end
				Core.Trigger( "Global/Admin", { -1, 7, args[ 3 ] }, nil, { ConsoleOperator = true, AdminTarget = args[ 2 ], SteamID = function() return "CONSOLE" end, Name = function() return "CONSOLE" end } )
				print( "Control", "Admin authority change submitted" )
			elseif szCmd == "lockdown" then
				if Core.Lockdown then
					Core.Lockdown = nil
					file.Delete( "lockdown.txt" )
					return print( "Lockdown has been ended" )
				end
				
				local szName, plyNoKick = "Operator"
				if #args >= 2 then
					table.remove( args, 1 )
					
					local szName = string.Implode( " ", args )
					
					for _,p in pairs( player.GetHumans() ) do
						if string.find( p:Name(), szName, 1, true ) then
							szName = p:Name()
							plyNoKick = p
							
							break
						end
					end
				end
				
				Core.Lockdown = "A lockdown has been issued by " .. szName .. ", you can rejoin later"
				Core.LockExclude = plyNoKick and plyNoKick.UID or ""
				
				file.Write( "lockdown.txt", Core.Lockdown .. ";" .. Core.LockExclude )
				
				for _,p in pairs( player.GetHumans() ) do
					if p != plyNoKick then
						p:Kick( Core.Lockdown )
					end
				end
				
				print( "Control", "Lockdown is now active!" )
			elseif szCmd == "rtv" then
				Core.ClearWaitPeriod()
				print( "Control", "RTV wait period has been cleared!" )
			elseif szCmd == "mbot" then
				Core.SetBotFrame( nil, -1, "Multi" )
			elseif szCmd == "dumpcmds" then
				local missing = {}
				local commands = Core.ContentText( "Commands" )
				
				for _,set in pairs( Command.Func ) do
					if not commands[ set[ 1 ][ 1 ] ] then
						missing[ #missing + 1 ] = set[ 1 ][ 1 ]
					end
					
					print( unpack( set[ 1 ] ) )
				end
				
				print( "Commands that do not have documentation:" )
				
				for _,cmd in pairs( missing ) do
					print( "- " .. cmd )
				end
			elseif szCmd == "pos" then
				local szPath = Core.Config.BaseType .. "/gamepostransfer.txt"
				
				if args[ 2 ] == "save" then
					local data = {}
					for _,p in pairs( player.GetHumans() ) do
						if p.InSpawn or p.Practice or p.TAS or not p.Tn or p.TnF then continue end
						
						local a, b, t = p:GetSync( true )
						local strafes = p:GetStrafes()
						
						data[ p:SteamID() ] = { p.Style, p:GetPos(), Command.Timer() - p.Tn, p:GetJumps(), strafes, { a, b, t }, p:EyeAngles() }
					end
					
					file.Write( szPath, util.TableToJSON( { game.GetMap(), data } ) )
					print( "Control", "Progress has been saved" )
				elseif args[ 2 ] == "load" or args[ 2 ] == "dump" then
					if not file.Exists( szPath, "DATA" ) then
						return print( "Control", "No progress to restore" )
					end
					
					local content = file.Read( szPath, "DATA" )
					if not content or content == "" then return end
					
					local json = util.JSONToTable( content )
					if not json or #json != 2 or json[ 1 ] != game.GetMap() then
						return print( "Control", "Invalid progress file" )
					end
					
					if args[ 2 ] == "dump" then
						return print( "Control", "Position file for map: " .. json[ 1 ] .. "\nAmount of players saved: " .. table.Count( json[ 2 ] ) .. "\nRaw data:\n\n" .. content )
					end
					
					json.Count = 0
					
					local data = json[ 2 ]
					for _,p in pairs( player.GetHumans() ) do
						if p.TAS then continue end
						
						local tab = data[ p:SteamID() ]
						if tab then
							if p.Practice then
								RemoveLimit( p )
								SetStyle( p, nil, { Core.Config.PracticeStyle } )
							end
							
							RemoveLimit( p )
							SetStyle( p, nil, { tab[ 1 ] } )
							
							RemoveLimit( p )
							Restart( p )
							
							p:CleanFrames()
							p:SetBotActive( nil )
							p.InSpawn = nil
							p.SkipValidation = true
							
							p:SetJumps( tab[ 4 ] )
							p:SetStrafes( tab[ 5 ] )
							p:SetSync( tab[ 6 ][ 1 ] or 0, tab[ 6 ][ 2 ] or 0, tab[ 6 ][ 3 ] or 0 )
							
							p:SetPos( tab[ 2 ] )
							p:SetEyeAngles( tab[ 7 ] )
							p:SetLocalVelocity( Vector( 0, 0, 0 ) )
							
							p.Tn = Command.Timer() - tab[ 3 ]
							p.TnF = nil
							
							local ar = Core.Prepare( "Timer/Start" )
							ar:UInt( 2, 2 )
							ar:Double( tab[ 3 ] or 0 )
							ar:Send( p )
							
							Core.Print( p, "Timer", Core.Text( "TimerRestoreServer" ) )
							
							json.Count = json.Count + 1
						end
					end
					
					file.Delete( szPath )
					print( "Control", "Restored locations of " .. json.Count .. " players" )
				else
					print( "Control", "Available sub-commands of 'pos': save/load/dump\nStorage point: ", szPath )
				end
			elseif szCmd == "collision" then
				for _,p in pairs( player.GetHumans() ) do
					if string.find( string.lower( p:Name() ), string.lower( args[ 2 ] or "" ), 1, true ) then
						if p:GetCollisionGroup() == COLLISION_GROUP_PLAYER then
							p:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
							print( "Collision disabled on", p:Name() )
						else
							p:SetCollisionGroup( COLLISION_GROUP_PLAYER )
							print( "Collision re-enabled on", p:Name() )
						end
					end
				end
			elseif szCmd == "resync" then
				Core.AddMaplistVersion()
			elseif szCmd == "packets" then
				print( "Control", "Received socket packets:", Core.GetPacketsReceived() )
			elseif szCmd == "silence" then
				Command.Silenced = not Command.Silenced
				Core.ChatSilence = Command.Silenced
				
				print( "Control", "Chat silencing", Command.Silenced )
			end
		else
			print( "Valid control functions: debug, admin [steam - String] [level - String], lockdown, rtv, mbot, dumpcmds, pos [save / load / dump], collision [player], resync, packets, silence" )
		end
	end
}

--[[
	Description: The console command for
	Notes: Kind of a hacky method of finding a console player
--]]
local function ServerCommand( ply, szCmd, varArgs )
	if not ply or ply:IsValid() or ply:IsPlayer() or ply.Name or ply.Team then return end
	
	local fExec = ServerCommands[ szCmd ]
	if fExec then
		fExec( varArgs )
	else
		print( "Server command", "Invalid command entered:", szCmd )
	end
end

-- Add all server commands
for command,_ in pairs( ServerCommands ) do
	concommand.Add( command, ServerCommand )
end


-- Command helpers

--[[
	Description: Loads all commands into a table together with their description
	Notes: Compressed since it's only sent once and quite large
--]]
local function LoadHelp( bForce )
	if not HelpData or not HelpLength or bForce then
		local tab = { HelpText = Core.ContentText( "HelpText" ) }
		local commands = Core.ContentText( "Commands" )
		local content = Core.ContentText( "StyleLookup" )
		
		for command,data in _pairs( Command.Func ) do
			if not commands[ command ] then continue end
			
			local out = data[ 1 ]
			if #out > 20 then
				local _,rnd1 = table.Random( content )
				local _,rnd2 = table.Random( content )
				
				out = { out[ 1 ], "Works with any style prefix: [" .. rnd1 .. "]" .. out[ 1 ] .. " or " .. out[ 1 ] .. "[" .. rnd2 .. "]" }
			end
			
			_insert( tab, { commands[ command ], out } )
		end
		
		HelpData = util.Compress( util.TableToJSON( tab ) )
		HelpLength = #HelpData
	end
end

--[[
	Description: Loads all bonus related data and enables the commands for it
	Used by: Entity initialization, zone reloading
--]]
local function LoadBonusAdditions()
	-- Also add commands for bonus
	local bonuses = Core.GetBonusIDs()
	for _,id in pairs( bonuses ) do
		local real = id + 1
		AddAlias( "b", "b" .. real )
		AddAlias( "normtop", "b" .. real .. "top" )
		AddAlias( "normtop", "topb" .. real )
		AddAlias( "wrtop", "b" .. real .. "wrtop" )
		AddAlias( "wrtop", "b" .. real .. "wrtoplist" )
		AddAlias( "wrtop", "wrtopb" .. real )
		
		local cmds = Core.ContentText( "Commands" )
		cmds[ "wrb" .. real ] = "Open Bonus " .. real .. " record list"
		
		local style = Core.ContentText( "StyleLookup" )
		style[ "b" .. real ] = Core.Config.Style.Bonus + id
		
		AddCmd( { "wrb" .. real, "wrbonus" .. real, "b" .. real .. "wr", "bwr" .. real }, function( ply, args )
			local nStyle = (tonumber( string.match( args.Key, "%d+" ) ) or 0) + Core.Config.Style.Bonus - 1
			if #args > 0 then
				Core.DoRemoteWR( ply, args[ 1 ], nStyle )
			else
				GAMEMODE:ShowSpare2( ply, { Core.GetRecordList( nStyle, 1, Core.Config.PageSize ), Core.GetRecordCount( nStyle ), nStyle } )
			end
		end )
		
		Core.Config.RankColumns[ Core.Config.Style.Bonus + id ] = 4
		Core.EnsureStyleRecords( Core.Config.Style.Bonus + id )
		Core.SetStyle( 50 + Core.Config.Style.Bonus + id, Core.StyleName( Core.Config.Style.Bonus + id ) .. " TAS" )
	end
	
	-- Update command count
	Core.UpdateCommandCount()
	
	-- Update Sync manager valid styles
	Core.InitializeSMgrAPI()
	
	-- Load the help properly now
	if not Command.Helped then
		LoadHelp( true )
		Command.Helped = true
	end
end
Core.BonusEntitySetup = LoadBonusAdditions


-- Start of multi-usage commands

--[[
	Description: Sets the style so that it always works (no command limit check)
--]]
local function CommandStyleSet( ply, style )
	RemoveLimit( ply )
	SetStyle( ply, nil, { style } )
end

--[[
	Description: Changes the style of the user to bonus X depending on the entered command
--]]
local function CommandStyleBonus( ply, args )
	local IsHigher = tonumber( _sub( args.Key, 2, 2 ) )
	if #args > 0 or IsHigher then
		local id = IsHigher or tonumber( args[ 1 ] )
		local keys = {}
		
		for _,val in pairs( Core.GetBonusIDs() ) do
			keys[ val ] = true
		end
		
		if id and keys[ id - 1 ] then
			RemoveLimit( ply )
			SetStyle( ply, nil, { Styles.Bonus }, nil, id - 1 )
			
			RemoveLimit( ply )
			Restart( ply )
		else
			Core.Print( ply, "Timer", Core.Text( "CommandBonusID" ) )
		end
	else
		RemoveLimit( ply )
		SetStyle( ply, nil, { Styles.Bonus }, nil, 0 )
	end
end

--[[
	Description: Shows the WR window by the provided data
--]]
local function CommandShowWR( ply, args, style )
	if #args > 0 then
		Core.DoRemoteWR( ply, args[ 1 ], style )
	else
		GAMEMODE:ShowSpare2( ply, { Core.GetRecordList( style, 1, Core.Config.PageSize ), Core.GetRecordCount( style ), style } )
	end
end


--[[
	Description: Loads all base commands and sets the function for it
	Used by: Initialization
--]]
function Core.LoadCommands()
	-- General timer commands
	AddCmd( { "r", "restart", "respawn", "kill" }, function( ply )
		RemoveLimit( ply )
		Restart( ply )
		ply.ssj_data.jumps = {}
		ply.ssj_data.gains = {}
	end )

	AddCmd( { "ssj" }, function( ply )
		// Core.Send( ply, "GUI/Create", { ID = "TAS", Dimension = { x = 200, y = 240, px = 20 }, Args = { Title = "TAS Menu" } } )
		Core.Send( ply, "GUI/Create", { ID = "SSJ", Dimension = { x = 260, y = 220, px = 20 }, Args = { Title = "SSJ Menu", Custom = ply.ssj_data } } )
	end )
	
	AddCmd( { "spec", "spectate", "watch", "view" }, function( ply, args )
		RemoveLimit( ply )
		if #args > 0 then
			if type( args[ 1 ] ) == "string" then
				local ar, target, tname = ply:Spectator( "GetAlive" ), nil, nil
				for id,p in pairs( ar ) do
					if string.find( string.lower( p:Name() ), string.lower( args[1] ), 1, true ) then
						target = p.UID
						tname = p:Name()
						break
					end
				end
				if target then
					if ply.Spectating then
						return ply:Spectator( "NewById", { target, true, tname } )
					else
						args[ 1 ] = target
					end
				end
			end

			DoSpectate( ply, nil, args )
		else
			DoSpectate( ply )
		end
	end )
	
	AddCmd( { "noclip", "freeroam", "clip", "wallhack" }, function( ply )
		RemoveLimit( ply )
		DoNoclip( ply )
	end )
	
	AddCmd( { "stats", "rts", "realtime", "realtimestats", "js", "jumpstats" }, function( ply, args )
		-- You can set py to 0.015 to show it in the top left corner
		Core.Send( ply, "GUI/Create", { ID = "Realtime", Dimension = { x = 200, y = 170, px = 20 }, Args = { Title = "Real-Time Stats", Custom = string.sub( args.Key, 1, 1 ) == "j" } } )
	end )
	
	AddCmd( { "tp", "tpto", "goto", "teleport", "tele" }, function( ply, args )
		if not ply.Practice then
			return Core.Print( ply, "General", Core.Text( "CommandPractice" ) )
		end
		
		if #args > 0 then
			local target
			for _,p in pairs( player.GetAll() ) do
				if string.find( string.lower( p:Name() ), string.lower( args[ 1 ] ), 1, true ) then
					target = p
					break
				end
			end
			if IsValid( target ) then
				if target.Spectating then
					return Core.Print( ply, "General", Core.Text( "CommandTeleportInvalid" ) )
				end
				
				ply:SetPos( target:GetPos() )
				ply:SetEyeAngles( target:EyeAngles() )
				ply:SetLocalVelocity( Vector( 0, 0, 0 ) )
				Core.Print( ply, "General", Core.Text( "CommandTeleportGo", target:Name() ) )
			else
				return Core.Print( ply, "General", Core.Text( "CommandTeleportNoTarget", args[ 1 ] ) )
			end
		else
			Core.Print( ply, "General", Core.Text( "CommandTeleportBlank" ) )
		end
	end )
	
	AddCmd( { "timescale", "ts", "slowmotion", "slowmo", "slomo" }, function( ply, args )
		if not ply.Practice then
			return Core.Print( ply, "General", Core.Text( "CommandPractice" ) )
		end
		
		local num = tonumber( args[ 1 ] )
		if #args == 0 or not num or num < 0.2 or num > 1.0 then
			return Core.Print( ply, "General", Core.Text( "CommandArgumentNum", args.Key, "Number 0.2 - 1.0" ) )
		end
		
		if ply:GetLaggedMovementValue() != num then
			ply:SetLaggedMovementValue( num )
			
			Core.Print( ply, "General", Core.Text( "CommandArgumentChange", "timescale", num ) )
		end
	end )
	
	AddCmd( { "gravity", "setgravity" }, function( ply, args )
		if not ply.Practice then
			return Core.Print( ply, "General", Core.Text( "CommandPractice" ) )
		end
		
		local num = tonumber( args[ 1 ] )
		if #args == 0 or not num or num < 0.1 or num > 5.0 then
			return Core.Print( ply, "General", Core.Text( "CommandArgumentNum", args.Key, "Number 0.1 - 5.0" ) )
		end
		
		Core.Print( ply, "General", Core.Text( "CommandArgumentChange", "gravity", num ) )
		
		ply:SetGravity( num )
	end )
	
	AddCmd( { "kz", "friction", "highfriction" }, function( ply )
		if not ToggleStamina then
			return Core.Print( ply, "General", Core.Text( "CommandFrictionNotAvailable" ) )
		end
		
		Core.Print( ply, "General", Core.Text( ToggleStamina( ply ) ) )
	end )
	
	AddCmd( { "listspecs", "listspec", "listspectators", "speclist", "specs", "myspec", "amifamous" }, function( ply )
		local w = {}
		for _,p in pairs( player.GetHumans() ) do
			if p:GetObserverTarget() == ply and not p.Incognito then
				w[ #w + 1 ] = p:Name()
			end
		end
		
		if #w > 0 then
			Core.Print( ply, "General", Core.Text( "CommandSpectatorList", #w, string.Implode( ", ", w ) ) )
		else
			Core.Print( ply, "General", Core.Text( "CommandSpectatorNone" ) )
		end
	end )
	
	AddCmd( { "end", "goend", "gotoend", "tpend" }, function( ply )
		if ply.Practice then
			local vPoint = Core.GetZoneCenter()
			if vPoint then
				ply:SetPos( vPoint )
				Core.Print( ply, "Timer", Core.Text( "PlayerTeleport", "the normal end zone!" ) )
			else
				Core.Print( ply, "Timer", Core.Text( "MiscZoneNotFound", "normal end" ) )
			end
		else
			Core.Print( ply, "Timer", Core.Text( "StyleTeleport" ) )
		end
	end )
	
	AddCmd( { "endbonus", "endb", "bend", "gotobonus", "tpbonus" }, function( ply, args )
		if ply.Practice then
			local vPoint = Core.GetZoneCenter( true, nil, #args > 0 and tonumber( args[ 1 ] ) )
			if vPoint then
				ply:SetPos( vPoint )
				Core.Print( ply, "Timer", Core.Text( "PlayerTeleport", "the bonus end zone!" ) )
			else
				Core.Print( ply, "Timer", Core.Text( "MiscZoneNotFound", "bonus end" ) )
			end
		else
			Core.Print( ply, "Timer", Core.Text( "StyleTeleport" ) )
		end
	end )
	
	AddCmd( { "pause", "break", "pausetimer", "save", "savetimer" }, function( ply )
		return Core.Print( ply, "Timer", "Pause and resume functions are disabled.")
		--[[if not ply.IsPauseWarned then
			ply.IsPauseWarned = true
			
			Core.Print( ply, "Timer", Core.Text( "TimerPauseHelp" ) )
		else
			if not ply.Tn or ply.TnF or ply.Practice or ply.TAS or ply.InSpawn then
				return Core.Print( ply, "Timer", Core.Text( "TimerInvalidPause" ) )
			end
			
			local tn = Command.Timer() - ply.Tn
			if not Command.Pause[ ply.UID ] then
				Core.Print( ply, "Timer", Core.Text( "TimerPause", Core.ConvertTime( tn ) ) )
			else
				Core.Print( ply, "Timer", Core.Text( "TimerPauseOverwrite", Core.ConvertTime( tn ) ) )
			end
			
			local a, b, t = ply:GetSync( true )
			local strafes = ply:GetStrafes()
			
			Command.Pause[ ply.UID ] = { ply.Style, ply:GetPos(), tn, ply:GetJumps(), strafes, { a, b, t }, ply:EyeAngles() }
		end]]
	end )
	
	Core.AddCmd({"boosterfix", "fixboosters", "booster"}, function(ply, arguments)
		ply.noboosterfix = ply.noboosterfix or false 
		ply.noboosterfix = (not ply.noboosterfix)
		Core.Print( ply, "Timer", "jewsta's boosterfix has been " .. (ply.noboosterfix and "enabled" or "disabled") .. ".")
	end)
	
	AddCmd( { "restore", "continue", "lunchtimeisover", "unpause", "resume" }, function( ply )
		return Core.Print( ply, "Timer", "Pause and resume functions are disabled.")
		--[[if not Command.Pause[ ply.UID ] then
			Core.Print( ply, "Timer", Core.Text( "TimerRestoreNone" ) )
		else
			local data = Command.Pause[ ply.UID ]
			if not ply.Tn or ply.Practice or ply.Style != data[ 1 ] or ply.InSpawn or ply.TAS then
				return Core.Print( ply, "Timer", Core.Text( "TimerInvalidRestore", Core.StyleName( data[ 1 ] ) ) )
			end

			if not Command.Restore[ ply.UID ] then
				Command.Restore[ ply.UID ] = 1
			else
				Command.Restore[ ply.UID ] = Command.Restore[ ply.UID ]
				
				if Command.Restore[ ply.UID ] > 3 then
					return Core.Print( ply, "Timer", Core.Text( "TimerRestoreLimit" ) )
				end
			end

			ply:CleanFrames()
			ply:SetBotActive( nil )
			ply.InSpawn = nil
			
			ply:SetJumps( data[ 4 ] )
			ply:SetStrafes( data[ 5 ] )
			ply:SetSync( data[ 6 ][ 1 ] or 0, data[ 6 ][ 2 ] or 0, data[ 6 ][ 3 ] or 0 )
			
			ply:SetPos( data[ 2 ] )
			ply:SetEyeAngles( data[ 7 ] )
			ply:SetLocalVelocity( Vector( 0, 0, 0 ) )

			ply.Tn = Command.Timer() - data[ 3 ] - 5 * 60
			ply.TnF = nil

			local ar = Core.Prepare( "Timer/Start" )
			ar:UInt( 2, 2 )
			ar:Double( data[ 3 ] + 5 * 60 )
			ar:Send( ply )
			
			Core.Print( ply, "Timer", Core.Text( "TimerRestore" ) )
			Core.CleanTable( data )
			
			Command.Pause[ ply.UID ] = nil
		end]]
	end )
	
	AddCmd( { "undo", "undor", "ru", "restartundo", "ifuckedup" }, function( ply )
		local data = ply.LastResetData
		if data then
			if Command.Timer() - data[ 1 ] > 60 then
				return Core.Print( ply, "Timer", Core.Text( "CommandUndoTime" ) )
			elseif ply.Practice or ply.TAS or ply.Style != data[ 2 ] or data[ 3 ] or not data[ 4 ] then
				return Core.Print( ply, "Timer", Core.Text( "CommandUndoFail" ) )
			elseif ply.InSpawn then
				return Core.Print( ply, "Timer", Core.Text( "CommandUndoSpawn" ) )
			end
			
			ply:CleanFrames()
			ply:SetBotActive( nil )
			ply.InSpawn = nil
			
			ply:SetJumps( data[ 7 ] or 0 )
			ply:SetStrafes( data[ 8 ] )
			ply:SetSync( data[ 9 ][ 1 ] or 0, data[ 9 ][ 2 ] or 0, data[ 9 ][ 3 ] or 0 )
			
			ply:SetPos( data[ 5 ] )
			ply:SetEyeAngles( data[ 6 ] )
			ply:SetLocalVelocity( Vector( 0, 0, 0 ) )
			
			ply.Tn = data[ 4 ]
			ply.TnF = nil
			ply.LastResetData = nil
			
			local ar = Core.Prepare( "Timer/Start" )
			ar:UInt( 2, 2 )
			ar:Double( Command.Timer() - data[ 4 ] )
			ar:Send( ply )
			
			Core.Print( ply, "Timer", Core.Text( "CommandUndoSucceed" ) )
		else
			Core.Print( ply, "Timer", Core.Text( "CommandUndoEmpty" ) )
		end
	end )
	
	-- RTV commands
	AddCmd( { "rtv", "vote", "votemap", "revote" }, function( ply, args )
		if #args > 0 then
			if args[ 1 ] == "revoke" then
				ply:RTV( "Revoke" )
			elseif args[ 1 ] == "check" or args[ 1 ] == "left" then
				ply:RTV( "Check" )
			elseif args[ 1 ] == "who" or args[ 1 ] == "list" then
				ply:RTV( "Who" )
			elseif args[ 1 ] == "time" then
				ply:RTV( "Left" )
			elseif args[ 1 ] == "revote" or args[ 1 ] == "again" or args[ 1 ] == "vote" then
				ply:RTV( "Revote" )
			elseif args[ 1 ] == "which" then
				ply:RTV( "Which" )
			elseif args[ 1 ] == "nominations" then
				ply:RTV( "Nominations" )
			elseif args[ 1 ] == "unnominate" or args[ 1 ] == "denominate" then
				ply:RTV( "Denominate" )
			elseif args[ 1 ] == "extend" then
				ply:RTV( "Extend" )
			else
				Core.Print( ply, "Notification", args[ 1 ] .. " is an invalid subcommand of the rtv command. Valid: who, list, check, left, revoke, time, revote, again, vote, which, nominations, unnominate" )
			end
		else
			if ply:RTV( "Revote", true ) then
				ply:RTV( "Revote" )
			else
				ply:RTV( "Vote" )
			end
		end
	end )
	
	AddCmd( { "revoke", "retreat", "revokertv" }, function( ply )
		ply:RTV( "Revoke" )
	end )

	AddCmd( { "checkvotes", "votecount" }, function( ply )
		ply:RTV( "Check" )
	end )
	
	AddCmd( { "votelist", "listrtv" }, function( ply )
		ply:RTV( "Who" )
	end )
	
	AddCmd( { "timeleft", "time", "remaining" }, function( ply )
		ply:RTV( "Left" )
	end )
	
	AddCmd( { "extend", "autoextend", "voteextend" }, function( ply )
		ply:RTV( "Extend" )
	end )
	
	-- GUI Functionality
	AddCmd( { "showgui", "showhud", "hidegui", "hidehud", "togglegui", "togglehud", "hud", "hudhide", "hudshow", "gui", "guihide", "guishow" }, function( ply, args )
		local interchange = {
			["hud"] = "togglehud",
			["hudhide"] = "hidehud",
			["hudshow"] = "showhud",
			["gui"] = "togglegui",
			["guihide"] = "hidegui",
			["guishow"] = "showgui"
		}
		
		if interchange[ args.Key ] then
			args.Key = interchange[ args.Key ]
		end
		
		if _sub( args.Key, 1, 4 ) == "show" or _sub( args.Key, 1, 4 ) == "hide" then
			Core.Send( ply, "Client/GUIVisibility", _sub( args.Key, 1, 4 ) == "hide" and 0 or 1 )
		else
			Core.Send( ply, "Client/GUIVisibility", -1 )
		end
	end )
	
	AddCmd( { "sync", "showsync", "sink", "strafe", "monitor" }, function( ply )
		ply:ToggleSyncState()
	end )
	
	-- Windows
	AddCmd( { "settings", "setting", "options", "config", "bhop", "surf", "menu", "mainmenu" }, function( ply )
		GAMEMODE:ShowHelp( ply )
	end )
	
	AddCmd( { "style", "mode", "styles", "modes" }, function( ply )
		RemoveLimit( ply )
		Core.Send( ply, "GUI/Create", { ID = "Style", Dimension = { x = 215, y = 360 }, Args = { Title = "Choose Style", Mouse = true, Blur = true, Custom = Core.GetStyleRecords( ply ) } } )
	end )
	
	AddCmd( { "nominate", "nom", "rtvmap", "playmap", "addmap", "maps" }, function( ply, args )
		if #args > 0 then
			if args[ 1 ] == "extend" then
				ply:RTV( "Extend" )
			else
				RemoveLimit( ply )
				Nominate( ply, nil, args )
			end
		else
			Core.Send( ply, "GUI/Create", { ID = "Nominate", Dimension = { x = 300, y = 400 }, Args = { Title = "Nominate a map", Mouse = true, Blur = true, Custom = Core.GetMaplistVersion(), Server = Core.GetMapVariable( "Plays" ), Previous = ply.NominatedMap } } )
		end
	end )
	
	AddCmd( { "wr", "wrlist", "records" }, function( ply, args )
		if #args > 0 then
			Core.DoRemoteWR( ply, args[ 1 ], ply.Style or Styles.Normal )
		else
			GAMEMODE:ShowSpare2( ply )
		end
	end )
	
	AddCmd( { "rank", "ranks", "ranklist" }, function( ply )
		Core.Send( ply, "GUI/Create", { ID = "Ranks", Dimension = { x = 195, y = 270 }, Args = { Title = "Rank List", Mouse = true, Blur = true, Custom = { ply.Rank or 1, ply.CurrentPointSum, ply.Style } } } )
	end )
	
	AddCmd( { "top", "toplist", "top100", "bestplayers", "besties" }, function( ply, args )
		local nStyle = ply.Style or Styles.Normal
		
		if #args > 0 then
			local lookup = Core.ContentText( "StyleLookup" )
			local style = lookup[ args[ 1 ] ]
			
			if style then
				nStyle = style
			end
		end
		
		if Core.IsValidBonus( nStyle ) then
			nStyle = Styles.Bonus
		end
		
		local data = Core.GetPlayerTop( nStyle )
		if #data == 0 then
			return Core.Print( ply, "Timer", Core.Text( "CommandTopListBlank", Core.StyleName( nStyle ) ) )
		else
			Core.Prepare( "GUI/Build", {
				ID = "Top",
				Title = Core.StyleName( nStyle ) .. " Top List (#" .. #data .. ")",
				X = 400,
				Y = 370,
				Mouse = true,
				Blur = true,
				Data = { data, ViewType = 0 }
			} ):Send( ply )
		end
	end )

	AddCmd( { "mapsbeat", "beatlist", "listbeat", "mapsdone", "mapscompleted", "beat", "done", "completed", "howgoodami" }, function( ply, args )
		Core.HandlePlayerMaps( "Beat", ply, args )
	end )
	
	AddCmd( { "mapsleft", "left", "leftlist", "listleft", "notbeat", "howbadami" }, function( ply, args )
		Core.HandlePlayerMaps( "Left", ply, args )
	end )
	
	AddCmd( { "mywr", "mywrs", "wr1", "wr#1", "wrcount", "wrcounter", "countwr", "wramount", "wrsby" }, function( ply, args )
		Core.HandlePlayerMaps( "Mine", ply, args )
	end )
	
	AddCmd( { "mapsnowr", "nowr", "nowrs", "mapswithoutwr", "withoutwr" }, function( ply, args )
		Core.HandlePlayerMaps( "NoWR", ply, args )
	end )
	
	AddCmd( { "allwrs", "stylewrs", "mapwrs" }, function( ply )
		local tab = Core.GetTopTimes()
		if Core.CountHash( tab ) > 0 then
			local send = {}
			for style,data in pairs( tab ) do
				send[ #send + 1 ] = { szUID = data.szUID, szPrepend = "[" .. Core.StyleName( style ) .. "] ", nTime = data.nTime }
			end
			
			Core.Prepare( "GUI/Build", {
				ID = "Top",
				Title = "Number 1 times on all styles",
				X = 400,
				Y = 370,
				Mouse = true,
				Blur = true,
				Data = { send, ViewType = 6 }
			} ):Send( ply )
		else
			Core.Print( ply, "Timer", Core.Text( "CommandWRAllNone" ) )
		end
	end )
	
	AddCmd( { "profile", "player", "playerprofile", "pp" }, function( ply, args )
		if #args > 0 then
			if string.find( string.lower( args[ 1 ] ), "steam" ) and util.SteamIDTo64( args.Upper[ 1 ] ) != "0" then
				local get = player.GetBySteamID( args.Upper[ 1 ] )
				if IsValid( get ) then
					local ipport = get:IPAddress()
					local ip = string.sub( ipport, 1, string.find( ipport, ":" ) - 1 )
					args.IP = ip
				end
				
				Core.ShowProfile( ply, args.Upper[ 1 ], args.IP )
			elseif string.find( args[ 1 ], "@", 1, true ) then
				local at = tonumber( string.match( args[ 1 ], "%d+" ) ) or 0
				local found = Core.GetSteamAtID( ply.Style, at )
				
				if found then
					args[ 1 ] = found
					args.Upper[ 1 ] = found
					
					local cmd = GetCmd( "profile" )
					cmd( ply, args )
				else
					Core.Print( ply, "General", Core.Text( "CommandProfileNoneAt", at, Core.StyleName( ply.Style ) ) )
				end
			elseif string.find( args[ 1 ], "#", 1, true ) then
				local found
				for _,p in pairs( player.GetHumans() ) do
					if string.find( string.lower( p:Name() ), string.sub( args[ 1 ], 2 ), 1, true ) then
						found = p
						break
					end
				end
				
				if IsValid( found ) then
					args[ 1 ] = found:SteamID()
					args.Upper[ 1 ] = args[ 1 ]
					
					local cmd = GetCmd( "profile" )
					cmd( ply, args )
				else
					Core.Print( ply, "General", Core.Text( "CommandProfileNoneName", args[ 1 ] ) )
				end
			else
				Core.Print( ply, "General", Core.Text( "CommandProfileIdentifier" ) )
			end
		else
			local ipport = ply:IPAddress()
			local ip = string.sub( ipport, 1, string.find( ipport, ":" ) - 1 )
			Core.ShowProfile( ply, ply:SteamID(), ip )
		end
	end )
	
	AddCmd( { "showkeys", "sk", "keys", "displaykeys" }, function( ply, args )
		ply.ShowKeys = true
		
		if ply.Spectating then
			Core.EnableKeyTrack()
		end
		
		Core.Send( ply, "GUI/Create", { ID = "Keys", Dimension = { x = 200, y = 130, px = 20 }, Args = { Title = "Keys" } } )
	end )
	
	AddCmd( { "close", "closewindow", "hidewindow", "destroy" }, function( ply, args )
		Core.Send( ply, "GUI/Close" )
	end )
	
	-- Weapon functionality
	AddCmd( { "crosshair", "cross", "togglecrosshair", "togglecross", "setcross" }, function( ply, args )
		if #args > 0 then
			local szType = args[ 1 ]
			if szType == "length" then
				if not #args == 2 or not tonumber( args[ 2 ] ) then
					return Core.Print( ply, "General", Core.Text( "CommandParameterMissing", "crosshair length", "[number]" ) )
				end
				
				Core.Send( ply, "Client/Crosshair", { ["pg_cross_length"] = args[ 2 ] } )
			elseif szType == "gap" then
				if not #args == 2 or not tonumber( args[ 2 ] ) then
					return Core.Print( ply, "General", Core.Text( "CommandParameterMissing", "crosshair gap", "[number]" ) )
				end
				
				Core.Send( ply, "Client/Crosshair", { ["pg_cross_gap"] = args[ 2 ] } )
			elseif szType == "thick" then
				if not #args == 2 or not tonumber( args[ 2 ] ) then
					return Core.Print( ply, "General", Core.Text( "CommandParameterMissing", "crosshair thick", "[number]" ) )
				end
				
				Core.Send( ply, "Client/Crosshair", { ["pg_cross_thick"] = args[ 2 ] } )
			elseif szType == "opacity" then
				if not #args == 2 or not tonumber( args[ 2 ] ) then
					return Core.Print( ply, "General", Core.Text( "CommandParameterMissing", "crosshair opacity", "[number: between 0 and 255]" ) )
				end
				
				Core.Send( ply, "Client/Crosshair", { ["pg_cross_opacity"] = args[ 2 ] } )
			elseif szType == "default" then
				Core.Send( ply, "Client/Crosshair", { ["pg_cross_length"] = 1, ["pg_cross_gap"] = 1, ["pg_cross_thick"] = 0, ["pg_cross_opacity"] = 255 } )
			elseif szType == "random" then
				Core.Send( ply, "Client/Crosshair", { ["pg_cross_length"] = math.random( 1, 50 ), ["pg_cross_gap"] = math.random( 1, 35 ), ["pg_cross_thick"] = math.random( 0, 10 ), ["pg_cross_opacity"] = math.random( 70, 255 ) } )
			else
				Core.Print( ply, "General", Core.Text( "CommandSubList", args.Key, "color [red green blue], length [scalar], gap [scalar], thick [scalar], opacity [alpha], default, random" ) )
			end
		else
			Core.Send( ply, "Client/Crosshair" )
		end
	end )
	
	AddCmd( { "glock", "usp", "knife", "p90", "mp5", "crowbar", "deagle", "fiveseven", "m4a1", "ump45", "scout", "weapon", "weapons" }, function( ply, args )
		if ply.Spectating or ply:Team() == TEAM_SPECTATOR then
			return Core.Print( ply, "General", Core.Text( "SpectateWeapon" ) )
		else
			if args.Key == "weapon" or args.Key == "weapons" then
				local func = Command.Func["glock"]
				local list = table.Copy( func[ 1 ] )
				
				table.remove( list )
				table.remove( list )
				
				if #args == 0 or not table.HasValue( list, args[ 1 ] ) then
					return Core.Print( ply, "General", Core.Text( "CommandWeaponList", string.Implode( ", ", list ) ) )
				else
					args.Key = args[ 1 ]
				end
			end
			
			if Core.Config.IsSurf then
				local valids = Core.ContentText( "SurfWeapons" )
				if not valids[ "weapon_" .. args.Key ] then
					return Core.Print( ply, "General", Core.Text( "CommandWeaponLimited" ) )
				end
			end
			
			local bFound = false
			for _,ent in pairs( ply:GetWeapons() ) do
				if ent:GetClass() == "weapon_" .. args.Key then
					bFound = true
					break
				end
			end
			if not bFound then
				ply:Give( "weapon_" .. args.Key )
				ply:SelectWeapon( "weapon_" .. args.Key )
				Core.Print( ply, "General", Core.Text( "PlayerGunObtain", args.Key ) )
			else
				Core.Print( ply, "General", Core.Text( "PlayerGunFound", args.Key ) )
			end
		end
	end )
	
	AddCmd( { "remove", "strip", "stripweapons" }, function( ply )
		if not ply.Spectating then
			ply:StripWeapons()
		else
			return Core.Print( ply, "General", Core.Text( "SpectateWeapon" ) )
		end
	end )
	
	AddCmd( { "flip", "leftweapon", "leftwep", "lefty", "flipwep", "flipweapon" }, function( ply )
		Core.Send( ply, "Client/WeaponFlip" )
	end )
	
	AddCmd( { "noguns", "nogun", "nogunpickup", "noweaponpickup", "noweps", "noweapons", "nopickup" }, function( ply )
		ply.WeaponPickupProhibit = not ply.WeaponPickupProhibit
		Core.Print( ply, "General", Core.Text( "CommandWeaponPickup", ply.WeaponPickupProhibit and "disabled" or "enabled" ) )
	end )
	
	-- Client functionality
	AddCmd( { "hide", "show", "showplayers", "hideplayers", "toggleplayers", "seeplayers", "noplayers" }, function( ply, args )
		if _sub( args.Key, 1, 4 ) == "show" or _sub( args.Key, 1, 4 ) == "hide" then
			Core.Send( ply, "Client/PlayerVisibility", _sub( args.Key, 1, 4 ) == "hide" and 0 or 1 )
		else
			Core.Send( ply, "Client/PlayerVisibility", -1 )
		end
	end )
	
	AddCmd( { "hidespec", "showspec", "togglespec" }, function( ply, args )
		local key = _sub( args.Key, 1, 1 )
		if key == "s" then
			Core.Send( ply, "Client/SpecVisibility", 1 )
		elseif key == "h" then
			Core.Send( ply, "Client/SpecVisibility", 0 )
		elseif key == "t" then
			Core.Send( ply, "Client/SpecVisibility" )
		end
	end )
	
	AddCmd( { "zones", "showzones", "showzone", "hidezones", "hidezone", "togglezones" }, function( ply, args )
		local key = _sub( args.Key, 1, 1 )
		if key == "s" then
			Core.Send( ply, "Client/ZoneVisibility", 1 )
		elseif key == "h" then
			Core.Send( ply, "Client/ZoneVisibility", 0 )
		elseif key == "t" or key == "z" then
			Core.Send( ply, "Client/ZoneVisibility" )
		end
	end )
	
	AddCmd( { "chat", "togglechat", "hidechat", "showchat" }, function( ply )
		Core.Send( ply, "Client/Chat" )
	end )
	
	AddCmd( { "muteall", "muteplayers", "unmuteall", "unmuteplayers" }, function( ply, args )
		Core.Send( ply, "Client/MuteAll", _sub( args.Key, 1, 1 ) == "m" and true or nil )
	end )
	
	AddCmd( { "voicemute", "voicegag", "chatmute", "chatgag", "unvoicemute", "unvoicegag", "unchatmute", "unchatgag" }, function( ply, args )
		if #args != 1 then
			return Core.Print( ply, "General", Core.Text( "CommandMuteArguments", args.Key ) )
		end
		
		local key, force = _sub( args.Key, 1, 1 )
		if key == "u" then
			force = false
		end
		
		Core.Send( ply, "Client/MuteSingle", { Type = string.find( args.Key, "voice" ) and "Voice" or "Chat", Find = args[ 1 ], Force = force } )
	end )
	
	AddCmd( { "playernames", "playername", "playertag", "playerids", "targetids", "targetid", "labels" }, function( ply )
		Core.Send( ply, "Client/TargetIDs" )
	end )
	
	AddCmd( { "water", "fixwater", "reflection", "refraction", "fuckicantsee", "myeyes!" }, function( ply )
		Core.Send( ply, "Client/Water" )
	end )
	
	AddCmd( { "decals", "blood", "shots", "removedecals", "imonmyperiod" }, function( ply )
		Core.Send( ply, "Client/Decals" )
	end )
	
	AddCmd( { "sky", "3dsky", "skybox", "fpsboost" }, function( ply )
		Core.Send( ply, "Client/Sky3D" )
	end )
	
	AddCmd( { "space", "spacetoggle", "holdtoggle", "auto", "lazymode" }, function( ply )
		ply.SpaceEnabled = not ply.SpaceEnabled
		Core.Send( ply, "Timer/Space" )
	end )
	
	AddCmd( { "thirdperson", "thirdp", "third", "aerial", "birdseye", "doilookfatinthisdress" }, function( ply )
		GAMEMODE:ShowSpare1( ply )
	end )
	
	-- Bot commands
	AddCmd( { "bot", "wrbot", "mbot" }, function( ply, args )
		args.Help = "set/style/play, info/details, save, force, who, add, check, demo, trail, route"
		
		if args.Key == "mbot" then
			if #args > 0 then
				if args[ 1 ] == "change" and tonumber( args[ 2 ] ) and ply.FinalizeBotChange then
					return ply:FinalizeBotChange( tonumber( args[ 2 ] ) )
				end
				
				local id = tonumber( args[ 1 ] )
				if id and Core.IsValidStyle( id ) then
					local subid = tonumber( args[ 2 ] )
					if subid and ply.BotHistoryData and #ply.BotHistoryData > 0 and ply.BotHistoryData[ subid ] then
						return Core.ChangeHistoryBot( ply, id, ply.BotHistoryData[ subid ] )
					end
					
					local data, forces = Core.LoadBotHistory( id )
					if #data > 0 then
						for _,list in pairs( forces ) do
							local id = list[ 1 ]
							local item = list[ 2 ]
							
							data[ #data + 1 ] = { ItemID = id, Name = item.Name, Time = item.Time, Style = item.Style, SteamID = item.SteamID, Date = item.Date }
						end
						
						ply.BotHistoryData = data
						
						local useful = { ["Name"] = true, ["Time"] = true, ["Style"] = true, ["SteamID"] = true, ["Date"] = true }
						local send = table.Copy( data )
						
						for i = 1, #send do
							for k,v in pairs( send[ i ] ) do
								if not useful[ k ] then
									send[ i ][ k ] = nil
								end
							end
						end
						
						Core.Send( ply, "GUI/UpdateBot", { 0, send, Core.GetMultiBotDetail(), "Left click shows more info. Replay a run with right click!\nUse BACKSPACE to go back to the previous page.\nALL previously saved runs on this style:" } )
					else
						Core.Send( ply, "GUI/UpdateBot", { 1, Core.Text( "CommandBotNoStyle" ) } )
					end
				else
					Core.Send( ply, "GUI/UpdateBot", { 1, Core.Text( "CommandBotValidStyle" ) } )
				end
			else
				local styles, details = Core.GetMultiBots( true )
				if #styles > 0 then
					Core.Send( ply, "GUI/Create", { ID = "Bot", Dimension = { x = 400, y = 370 }, Args = { Title = "Multi Bots", Mouse = true, Blur = true, Custom = { styles, details, Core.GetMultiBotDetail() } } } )
				else
					Core.Print( ply, "General", Core.Text( "CommandBotMultiNone" ) )
				end
			end
			
			return false
		end
		
		if #args == 0 then
			Core.Print( ply, "General", Core.Text( "CommandSubList", args.Key, args.Help ) )
		else
			local szType = tostring( args[ 1 ] )
			if szType == "set" or szType == "style" or szType == "play" then
				if not args[ 2 ] then
					local list = Core.GetMultiBots()
					if #list > 0 then
						return Core.Print( ply, "General", Core.Text( "CommandBotRecordList", string.Implode( ", ", list ), szType ) )
					else
						return Core.Print( ply, "General", Core.Text( "CommandBotNoPlayback" ) )
					end
				end
				
				local nStyle = tonumber( args[ 2 ] )
				if not nStyle then
					table.remove( args.Upper, 1 )
					local szStyle = string.Implode( " ", args.Upper )
					
					local nGet = Core.GetStyleID( szStyle )
					if not Core.IsValidStyle( nGet ) then
						return Core.Print( ply, "General", Core.Text( "MiscInvalidStyle" ) )
					else
						nStyle = nGet
					end
				end
				
				local Change = Core.ChangeMultiBot( nStyle )
				Core.Send( ply, "GUI/UpdateBot", { 3, string.len( Change ) > 10, string.len( Change ) > 10 and Change or Core.Text( "BotMulti" .. Change ) } )
			elseif szType == "info" or szType == "details" then
				local nStyle = nil
				if not args[ 2 ] or not tonumber( args[ 2 ] ) then
					if args[ 2 ] then
						table.remove( args.Upper, 1 )
						local szStyle = string.Implode( " ", args.Upper )
					
						local a = Core.GetStyleID( szStyle )
						if not Core.IsValidStyle( a ) then
							return Core.Print( ply, "General", Core.Text( "MiscInvalidStyle" ) )
						else
							nStyle = a
						end
					else
						local ob = ply:GetObserverTarget()
						if IsValid( ob ) and ob:IsBot() then
							nStyle = ob.Style
						else
							return Core.Print( ply, "General", Core.Text( "CommandBotNoTarget", szType ) )
						end
					end
				else
					nStyle = tonumber( args[ 2 ] )
					if not Core.IsValidStyle( nStyle ) then
						return Core.Print( ply, "General", Core.Text( "CommandStyleInvalid" ) )
					end
				end
				
				if nStyle then
					local info = Core.GetBotInfo( nStyle )
					if info then
						Core.Print( ply, "General", Core.Text( "BotDetails", info.Name, info.SteamID, Core.StyleName( info.Style ), Core.ConvertTime( info.Time ), info.Date ) )
					else
						Core.Print( ply, "General", Core.Text( "BotDetailsNone", Core.StyleName( nStyle ) ) )
					end
				end
			elseif szType == "save" then
				Core.TryBotSave( ply )
			elseif szType == "force" then
				if ply.Spectating then
					local ob = ply:GetObserverTarget()
					if IsValid( ob ) then
						ob.BotForce = ply
						Core.Print( ply, "General", Core.Text( "CommandBotForce" ) )
					end
				else
					if Core.IsInsideZone( ply, Core.GetZoneID( "Normal End" ) ) or (Core.IsValidBonus( ply.Style ) and Core.IsInsideZone( ply, Core.GetZoneID( "Bonus End" ) )) then
						Core.ForceBotSave( ply, true )
					else
						if ply.BotForce == ply then
							Core.Print( ply, "General", Core.Text( "CommandBotForceAlready" ) )
						else
							ply.BotForce = ply
							Core.Print( ply, "General", Core.Text( "CommandBotForceSelf" ) )
						end
					end
				end
			elseif szType == "who" then
				local ps = {}
				for _,p in pairs( player.GetHumans() ) do
					if p:IsPlayerDequeued() then
						ps[ #ps + 1 ] = p:Name()
					end
				end
				
				if #ps > 0 then
					Core.Print( ply, "General", Core.Text( "CommandBotWhoList", #ps, string.Implode( ", ", ps ) ) )
				else
					Core.Print( ply, "General", Core.Text( "CommandBotWhoAll" ) )
				end
			elseif szType == "add" then
				if not ply:IsPlayerDequeued() then
					return Core.Print( ply, "General", Core.Text( "CommandBotRecordAlready" ) )
				end
				
				if not ply.InSpawn then
					Core.Print( ply, "General", Core.Text( "CommandBotRecordSpawn" ) )
				else
					ply:BotAdd( true )
					
					ply:CleanFrames()
					ply:SetBotActive( true )
					
					Core.Print( ply, "General", Core.Text( "CommandBotRecordSuccess" ) )
				end
			elseif szType == "check" then
				local _,isrec = ply:IsPlayerDequeued()
				Core.Print( ply, "General", Core.Text( "CommandBotRecordDisplay", isrec and "" or "not " ) )
			elseif szType == "demo" then
				if not ply.DemoTarget then
					local ob = ply:GetObserverTarget()
					if IsValid( ob ) and ob:IsBot() then
						ply.DemoStarted = nil
						ply.DemoTarget = ob
						Core.Print( ply, "General", Core.Text( "CommandBotDemoStarted" ) )
					else
						Core.Print( ply, "General", Core.Text( "CommandBotDemoNone" ) )
					end
				else
					ply.DemoStarted = nil
					ply.DemoTarget = nil
					Core.Print( ply, "General", Core.Text( "CommandBotDemoDisable" ) )
				end
			elseif szType == "trail" or szType == "route" then
				table.remove( args, 1 )
				table.remove( args.Upper, 1 )
				args.Key = "bot " .. szType
				
				local cmd = GetCmd( "trail" )
				cmd( ply, args )
			else
				Core.Print( ply, "General", Core.Text( "CommandSubList", args.Key, args.Help ) )
			end
		end
	end )
	
	AddCmd( { "botsave", "savebot", "savemybot", "iwantmybotsaved", "keepbots" }, function( ply )
		Core.TryBotSave( ply )
	end )
	
	-- Info commands
	AddCmd( { "help", "commands", "command", "alias", "aliases" }, function( ply, args )
		local FromSettings = false
		if #args > 0 then
			if args[ 1 ] == "fs" then
				FromSettings = true
				args = {}
			end
		end
		
		if #args > 0 then
			local mainArg, th, own = "", table.HasValue, string.lower( args[ 1 ] )
			for main,data in pairs( Command.Func ) do
				if th( data[ 1 ], own ) then
					mainArg = main
					break
				end
			end
			
			if mainArg != "" then
				local commands = Core.ContentText( "Commands" )
				local data = commands[ mainArg ]
				if data then
					local alias = ""
					local tab = table.Copy( Command.Func[ mainArg ][ 1 ] )
					table.RemoveByValue( tab, own )
					
					if #tab > 0 then
						alias = "\nAdditional aliases for the command are: " .. string.Implode( ", ", tab )
					end
					
					Core.Print( ply, "General", Core.Text( "CommandHelpDisplay", own, data:gsub( "%a", string.lower, 1 ) .. alias ) )
				else
					Core.Print( ply, "General", Core.Text( "CommandHelpNone", own ) )
				end
			else
				Core.Print( ply, "General", Core.Text( "CommandHelpInavailable", args[ 1 ] ) )
			end
		else
			net.Start( "BinaryTransfer" )
			net.WriteString( "Help" )
			net.WriteBit( FromSettings )
			
			if ply.HelpReceived then
				net.WriteUInt( 0, 32 )
			else
				net.WriteUInt( HelpLength, 32 )
				net.WriteData( HelpData, HelpLength )
				ply.HelpReceived = true
			end
			
			net.Send( ply )
		end
	end )
	
	AddCmd( { "map", "points", "mapdata", "mapinfo", "difficulty", "tier", "mi" }, function( ply, args )
		if Core.Config.IsSurf then
			Core.AddText( "MapInfo", "The map '1;' has a weight of 2; points 3;4;5;" )
		end
		
		if #args > 0 then
			if not args[ 1 ] then return end
			if Core.MapCheck( args[ 1 ] ) then
				local data = Core.MapCheck( args[ 1 ], nil, true )
				local last = Core.GetLastPlayed( args[ 1 ] )
				Core.Print( ply, "General", Core.Text( "MapInfo", data[ 1 ], data[ 2 ] or 1, "Played " .. data[ 3 ] .. " times" .. (last and ", last on " .. last or ""), "", Core.Config.IsSurf and " (Tier " .. data[ 4 ] .. " - " .. (data[ 5 ] == 1 and "Staged" or "Linear") .. ")" or "" ) )
			else
				Core.Print( ply, "General", Core.Text( "MapInavailable", args[ 1 ] ) )
			end
		else
			local nMult, bMult = Core.GetMapVariable( "Multiplier" ) or 1, Core.GetMapVariable( "Bonus" ) or 1
			local szBonus, szPoints, szAdditional = "", ""
			
			if not ply.OutputSock then
				local nPoints = Core.GetPointsForMap( ply, ply.Record, ply.Style )
				
				if Core.IsValidBonus( ply.Style ) then
					szPoints = "(For the bonuses, you obtained " .. math.Round( nPoints, 2 ) .. " / " .. Core.GetMultiplier( ply.Style, true ) .. " pts)"
				else
					szPoints = "(Obtained " .. math.Round( nPoints, 2 ) .. " / " .. nMult .. " pts)"
				end
			end
			
			if #Core.GetBonusIDs() > 0 then
				if type( bMult ) == "table" then
					local tab = {}
					for i = 1, #bMult do
						tab[ i ] = "[Bonus " .. i .. "]: " .. bMult[ i ]
					end
					
					szBonus = " (Bonus points for " .. string.Implode( ", ", tab ) .. ")"
				else
					szBonus = " (Bonus has a multiplier of " .. bMult .. ")"
				end
			end
			
			if Core.Config.IsSurf then
				szAdditional = " and is of type Tier " .. (Core.GetMapVariable( "Tier" ) or 1) .. " - " .. ((Core.GetMapVariable( "Type" ) or 0) == 1 and "Staged" .. (Core.GetStageCount() > 0 and " (Amount: " .. Core.GetStageCount() .. ")" or "") or "Linear")
			end
			
			local text = Core.Text( "MapInfo", game.GetMap(), nMult, szPoints, szBonus, szAdditional )
			if ply.OutputSock then
				return text
			else
				Core.Print( ply, "General", text )
			end
		end
	end )
	
	AddCmd( { "plays", "playcount", "timesplayed", "howoften" }, function( ply, args )
		local thismap = game.GetMap()
		local map = #args > 0 and args[ 1 ] or thismap
		local played, data = Core.GetLastPlayed( map )
		
		if data then
			local plays = map == thismap and Core.GetMapVariable( "Plays" ) or (data.nPlays or 0)
			Core.Print( ply, "General", Core.Text( "MapPlayed", map == thismap and "This map" or "'" .. map .. "'", plays, played and " It has last been played on " .. played or "" ) )
		else
			Core.Print( ply, "General", Core.Text( "MapInavailable", map ) )
		end
	end )
	
	AddCmd( { "playinfo", "leastplayed", "mostplayed", "overplayed", "lastplayed", "randommap", "lastmaps" }, function( ply, args )
		ply:RTV( "MapFunc", args.Key )
	end )
	
	AddCmd( { "wrpos", "mypos", "ladderpos", "leaderboardpos", "mytime" }, function( ply, args )
		if #args > 0 and args[ 1 ] != game.GetMap() and not tonumber( args[ 1 ] ) then
			ply.OutputSock = true
			ply.OutputFull = true
			
			local data, check = Core.DoRemoteWR( ply, args[ 1 ], ply.Style )
			ply.OutputSock = nil
			ply.OutputFull = nil
			
			local found
			if data and check == "Full" then
				for i = 1, #data do
					if data[ i ].szUID == ply.UID then
						found = { i, data[ i ].nTime }
					end
				end
			end
			
			if found then
				Core.Print( ply, "General", Core.Text( "CommandWRPosInfo", found[ 1 ], Core.ConvertTime( found[ 2 ] ), " on '" .. args[ 1 ] .. "'" ) )
			elseif data then
				Core.Print( ply, "General", Core.Text( "CommandWRPosMissing", "'" .. args[ 1 ] .. "'" ) )
			end
		else
			local t,i = Core.GetPlayerRecord( ply, ply.Style )
			if i > 0 then
				Core.Print( ply, "General", Core.Text( "CommandWRPosInfo", i, Core.ConvertTime( t ), "!" ) )
			else
				Core.Print( ply, "General", Core.Text( "CommandWRPosMissing", "the map" ) )
			end
		end
	end )
	
	AddCmd( { "getwr", "showwr", "stylewr", "thiswr" }, function( ply, args )
		local tab = Core.GetTopTimes()
		local style = tonumber( args[ 1 ] ) or ply.Style
		local item = tab[ style ]
		
		if item then
			Core.Send( ply, "Client/SteamText", { "General", Core.Text( "CommandWRInfo", Core.StyleName( style ), Core.ConvertTime( item.nTime or 0 ), item.szUID and "{STEAM}" or "Unknown" ), item.szUID or "Unknown" } )
		else
			Core.Print( ply, "General", Core.Text( "CommandWRNone" ) )
		end
	end )
	
	AddCmd( { "average", "getaverage", "timeaverage", "averagetime", "avg" }, function( ply, args )
		local style = tonumber( args[ 1 ] ) or ply.Style
		local avg = Core.GetAverage( style )
		
		if avg > 0 then
			Core.Print( ply, "General", Core.Text( "CommandTimeAvgValue", Core.StyleName( style ), Core.ConvertTime( avg ) ) )
		else
			Core.Print( ply, "General", Core.Text( "CommandTimeAvgNone" ) )
		end
	end )
	
	AddCmd( { "hop", "goeasy", "gohard", "gomixed", "gosurf", "swap", "swapserver", "server", "servers" }, function( ply, args )
		local Active = Core.ContentText( "ActiveServers" )
		local CustomGo
		
		local function FindByShort( tab, short )
			for _,data in pairs( tab ) do
				for __,name in pairs( data[ 3 ] ) do
					if name == short then
						return data
					end
				end
			end
		end
		
		if args.Key == "hop" or args.Key == "swap" or args.Key == "swapserver" then
			if #args > 0 and FindByShort( Active, args[ 1 ] ) then
				CustomGo = args[ 1 ]
			else
				local tabQuery = {
					Caption = "What server do you want to connect to?",
					Title = "Connect to another server"
				}
				
				for _,data in pairs( Active ) do
					table.insert( tabQuery, { data[ 2 ], { data[ 1 ] } } )
				end
				
				table.insert( tabQuery, { "[[Close", {} } )
				
				Core.Send( ply, "Client/Redirect", { true, tabQuery } )
			end
		end
		
		if not CustomGo then
			if FindByShort( Active, _sub( args.Key, 3 ) ) then
				CustomGo = _sub( args.Key, 3 )
			end
		end
		
		if CustomGo then
			local data = FindByShort( Active, CustomGo )
			if not data then return end
			
			Core.Send( ply, "Client/Redirect", { false, data[ 1 ], data[ 2 ] } )
		end
	end )
	
	AddCmd( { "about", "info", "credits", "author", "owner", "whomadethis" }, function( ply )
		Core.Print( ply, "General", Core.Text( "MiscAbout" ) )
	end )
	
	AddCmd( { "tutorial", "tut", "howto", "helppls", "plshelp", "imhopeless" }, function( ply )
		Core.Send( ply, "Client/URL", { Core.ContentText( "TutorialLink" ) } )
	end )
	
	AddCmd( { "website", "web", "rules", "motd" }, function( ply )
		Core.Send( ply, "Client/URL", { Core.ContentText( "WebsiteLink" ) } )
	end )
	
	AddCmd( { "textures", "error", "css", "pinkandblack" }, function( ply )
		Core.Send( ply, "Client/URL", { Core.ContentText( "ChannelLink" ) } )
	end )
	
	AddCmd( { "forum", "discord", "community" }, function( ply )
		Core.Send( ply, "Client/URL", { Core.ContentText( "ForumLink" ) } )
	end )
	
	AddCmd( {  "donate", "donation", "sendmoney", "givemoney", "gibepls" }, function( ply )
		Core.Send( ply, "Client/URL", { Core.ContentText( "ThreadLink" ) } )
	end )
	
	AddCmd( { "version", "lastchange", "changelog", "changes", "info", "whatdidgravdonow" }, function( ply )
		Core.Send( ply, "Client/URL", { Core.ContentText( "ChangeLink" ) } )
	end )
	
	-- Quick style commands
	AddCmd( { "n", "normal", "default", "standard" }, function( ply ) CommandStyleSet( ply, Styles.Normal ) end )
	AddCmd( { "sw", "sideways" }, function( ply ) CommandStyleSet( ply, Styles.SW ) end )
	AddCmd( { "hsw", "halfsideways", "halfsw", "h" }, function( ply ) CommandStyleSet( ply, Styles.HSW ) end )
	AddCmd( { "w", "wonly" }, function( ply ) CommandStyleSet( ply, Styles["W-Only"] ) end )
	AddCmd( { "a", "aonly" }, function( ply ) CommandStyleSet( ply, Styles["A-Only"] ) end )
	AddCmd( { "d", "donly" }, function( ply ) CommandStyleSet( ply, Styles["D-Only"] ) end )
	AddCmd( { "s", "sonly" }, function( ply, args ) if args.Key == "s" and #args > 0 and tonumber( args[ 1 ] ) then local func = GetCmd( "stage" ) func( ply, args ) else CommandStyleSet( ply, Styles["S-Only"] ) end end )
	AddCmd( { "l", "legit" }, function( ply ) CommandStyleSet( ply, Styles.Legit ) end )
	AddCmd( { "shsw" }, function( ply ) CommandStyleSet( ply, Styles.SHSW ) end )
	AddCmd( { "ca", "cancer" }, function( ply ) CommandStyleSet( ply, Styles.Cancer ) end )
	AddCmd( { "mlg" }, function( ply ) CommandStyleSet( ply, Styles["M.L.G"] ) end )
	AddCmd( { "mm", "moonman" }, function( ply ) CommandStyleSet( ply, Styles["Moon Man"] ) end )
	AddCmd( { "ps", "prespeed" }, function( ply ) CommandStyleSet( ply, Styles.Prespeed ) end )
	AddCmd( { "hg", "highgrav", "highgravity" }, function( ply ) CommandStyleSet( ply, Styles["High Gravity"] ) end )
	AddCmd( { "c", "crazy" }, function( ply ) CommandStyleSet( ply, Styles.Crazy ) end )
	AddCmd( { "e", "scroll", "easy", "easyscroll", "ez" }, function( ply ) CommandStyleSet( ply, Styles["Easy Scroll"] ) end )
	AddCmd( { "u", "unreal" }, function( ply ) CommandStyleSet( ply, Styles.Unreal ) end )
	AddCmd( { "bw", "backwards", "back" }, function( ply ) CommandStyleSet( ply, Styles.Backwards ) end )
	AddCmd( { "lg", "lowgrav" }, function( ply ) CommandStyleSet( ply, Styles["Low Gravity"] ) end )
	AddCmd( { "ch", "cheater" }, function( ply ) CommandStyleSet( ply, Styles.Cheater ) end )
	AddCmd( { "ex", "extreme" }, function( ply ) CommandStyleSet( ply, Styles.Extreme ) end )
	AddCmd( { "swift" }, function( ply ) CommandStyleSet( ply, Styles.Swift) end )
	AddCmd( { "p", "practice", "try", "free" }, function( ply, args ) if args.Key == "p" and #args > 0 then local func = GetCmd( "profile" ) args.Key = "profile" func( ply, args ) else CommandStyleSet( ply, Core.Config.PracticeStyle ) end end )
	AddCmd( { "b", "bonus", "extra" }, CommandStyleBonus )
	
	-- Quick WR list commands
	AddCmd( { "wrn", "wrnormal", "nwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Normal ) end )
	AddCmd( { "wrsw", "wrsideways", "swwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.SW ) end )
	AddCmd( { "wrhsw", "wrhalf", "wrhalfsw", "wrhalfsideways", "hswwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.HSW ) end )
	AddCmd( { "shswwr", "wrshsw"}, function( ply, args ) CommandShowWR( ply, args, Styles.SHSW ) end )
	AddCmd( { "wrca", "wrcancer", "cancerwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Cancer ) end )
	AddCmd( { "mlgwr", "wrmlg" }, function( ply, args ) CommandShowWR( ply, args, Styles["M.L.G"] ) end )
	AddCmd( { "mmwr", "wrmm", "moonmanwr", "wrmoonman" }, function( ply, args ) CommandShowWR( ply, args, Styles["Moon Man"] ) end )
	AddCmd( { "pswr", "prespeedwr", "wrps", "wrprespeed" }, function( ply, args ) CommandShowWR( ply, args, Styles.Prespeed ) end )
	AddCmd( { "hgwr", "highgravwr", "highgravitywr", "wrhg", "wrhighgrav", "wrhighgravity" }, function( ply, args ) CommandShowWR( ply, args, Styles["High Gravity"] ) end )
	AddCmd( { "wrc", "wrcrazy", "crazywr", "cwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Crazy ) end )
	AddCmd( { "wrw", "wrwonly", "wwr", "wonlywr" }, function( ply, args ) CommandShowWR( ply, args, Styles["W-Only"] ) end )
	AddCmd( { "wra", "wraonly", "awr", "aonlywr" }, function( ply, args ) CommandShowWR( ply, args, Styles["A-Only"] ) end )
	AddCmd( { "wrd", "wrdonly", "dwr", "donlywr" }, function( ply, args ) CommandShowWR( ply, args, Styles["D-Only"] ) end )
	AddCmd( { "wrs", "wrsonly", "swr", "sonlywr" }, function( ply, args ) CommandShowWR( ply, args, Styles["S-Only"] ) end )
	AddCmd( { "wrex", "wrextreme", "exwr", "extremewr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Extreme ) end )
	AddCmd( { "chwr", "cheaterwr", "wrch", "wrcheater" }, function( ply, args ) CommandShowWR( ply, args, Styles.Cheater ) end )
	AddCmd( { "wrl", "wrlegit", "lwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Legit ) end )
	AddCmd( { "wre", "wrscroll", "scrollwr", "ewr", "ezwr", "wrez" }, function( ply, args ) CommandShowWR( ply, args, Styles["Easy Scroll"] ) end )
	AddCmd( { "wru", "wrunreal", "uwr", "unrealwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Unreal ) end )
	AddCmd( { "wrbw", "wrbackwards", "bwwr", "backwardswr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Backwards ) end )
	AddCmd( { "wrlg", "wrlowgrav", "wrlowgravity", "lgwr", "lowgravwr", "lowgravitywr" }, function( ply, args ) CommandShowWR( ply, args, Styles["Low Gravity"] ) end )
	AddCmd( { "wrb", "wrbonus", "bwr" }, function( ply, args ) if not args[ 2 ] and tonumber( args[ 1 ] ) then args[ 2 ] = tonumber( args[ 1 ] ) args[ 1 ] = game.GetMap() end CommandShowWR( ply, args, Styles.Bonus + ((tonumber( args[ 2 ] ) and args[ 1 ]) and math.Clamp( tonumber( args[ 2 ] ) - 1, 0, 50 - Styles.Bonus ) or 0) ) end )
	
	-- Stamina commands
	if Core.Config.IsPack then
		AddCmd( { "j", "jump", "jumppack", "jp", "easymode", "noobmode", "imbad" }, function( ply ) CommandStyleSet( ply, Styles["Jump Pack"] ) end )
		AddCmd( { "wrj", "wrjp", "wrjump", "wrjumppack", "jwr", "jumpwr", "jumppackwr" }, function( ply, args ) CommandShowWR( ply, args, Styles["Jump Pack"] ) end )
	else
		AddCmd( { "stam", "stamina" }, function( ply ) CommandStyleSet( ply, Styles.Stamina ) end )
		AddCmd( { "wrstam", "wrstamina", "stamwr" }, function( ply, args ) CommandShowWR( ply, args, Styles.Stamina ) end )
	end
	
	-- Main top list command (gets filled with aliases according to lookup table)
	AddCmd( { "normtop" }, function( ply, args )
		local lookup = Core.ContentText( "StyleLookup" )
		local key = _gs( args.Key, "top", "" )
		local style = lookup[ key ] or ply.Style or Styles.Normal
		
		if Core.IsValidBonus( style ) then
			style = Styles.Bonus
		end
		
		local data = Core.GetPlayerTop( style )
		if #data == 0 then
			return Core.Print( ply, "Timer", Core.Text( "CommandTopListBlank", Core.StyleName( style ) ) )
		else
			Core.Prepare( "GUI/Build", {
				ID = "Top",
				Title = Core.StyleName( style ) .. " Top List (#" .. #data .. ")",
				X = 400,
				Y = 370,
				Mouse = true,
				Blur = true,
				Data = { data, ViewType = 0 }
			} ):Send( ply )
		end
	end )
	
	-- Main WR top list command (gets filled with aliases according to lookup table)
	AddCmd( { "wrtop", "normwrtop" }, function( ply, args )
		local lookup = Core.ContentText( "StyleLookup" )
		local key = _gs( args.Key, "wrtop", "" )
		local style = lookup[ key ] or ply.Style or Styles.Normal
		
		if Core.IsValidBonus( style ) then
			style = Styles.Bonus
		end
		
		local data = Core.GetPlayerWRTop( style )
		local count = Core.CountHash( data )
		
		if count == 0 then
			return Core.Print( ply, "Timer", Core.Text( "CommandWRTopBlank", Core.StyleName( style ) ) )
		else
			Core.Prepare( "GUI/Build", {
				ID = "Top",
				Title = Core.StyleName( style ) .. " WR Top List",
				X = 400,
				Y = 370,
				Mouse = true,
				Blur = true,
				Data = { data, ViewType = 7, Count = count }
			} ):Send( ply )
		end
	end )
	
	-- Miscellaneous
	AddCmd( "jiggy", function( ply )
		local path = GetConVarString( "sv_downloadurl" ) .. "/sound/" .. Core.Config.MaterialID .. "/wr_jiggy.mp3"
		ply:SendLua( "sound.PlayURL(\"" .. path .. "\",\"\",function(o) if not IsValid(o) then return end if IsValid(JSC) then JSC:SetVolume(0) JSC:Stop() JSC = nil end JSC = o JSC:Play() end)" )
	end )
	
	AddCmd( { "model", "setmodel", "looks", "changemylooks", "iwanttobesexy" }, function( ply, args )
		if args.Key == "iwanttobesexy" then
			args[ 1 ] = "alyx"
		end
		
		if #args > 0 then
			local models, found = Core.ContentText( "ValidModels" )
			for _,model in pairs( models ) do
				if model == args[ 1 ] then
					found = true
					break
				end
			end
			
			if not found and args[ 1 ] != "" then
				return Core.Print( ply, "General", Core.Text( "CommandModelInvalid", args[ 1 ] ) )
			end
			
			local path = "models/player/" .. args[ 1 ] .. ".mdl"
			if args[ 1 ] == "default" or args[ 1 ] == "" then
				args[ 1 ] = "default"
				path = Core.Config.Player.DefaultModel
			end
			
			ply:SetModel( path )
			
			if not args.SkipMessage then
				Core.Print( ply, "General", Core.Text( "CommandModelChange", args[ 1 ] ) )
			end
		else
			Core.Print( ply, "General", Core.Text( "CommandModelBlank" ) )
		end
	end )
	
	AddCmd( { "female", "givemetits", "avaginawilldotoo" }, function( ply )
		ply:SetModel( "models/player/" .. table.Random( Core.ContentText( "FemaleModels" ) ) .. ".mdl" )
		Core.Print( ply, "General", Core.Text( "CommandModelChange", "a random female model" ) )
	end )
	
	AddCmd( { "remainingtries", "triesleft", "tries", "killmeafter", "icantstop", "pleasehelpmequit", "imaddictedhalp" }, function( ply, args )
		if #args > 0 then
			if #args > 1 and (((args[ 1 ] == "kick" or args[ 1 ] == "count") and tonumber( args[ 2 ] )) or (args[ 1 ] == "time" and string.find( args[ 2 ], ":", 1, true ))) then
				if ply.TryTrack and ply.TryTrack.Type == "time" then
					Core.Send( ply, "Timer/Kicker" )
				end
				
				local add = "."
				ply.TryTrack = { Type = args[ 1 ], Amount = math.abs( tonumber( args[ 2 ] ) or 1 ) }
				
				if ply.TryTrack.Type == "time" then
					ply.TryTrack.Time = args[ 2 ]
					add = ". You will be kicked at " .. args[ 2 ] .. ". To cancel this, type !" .. args.Key .. " stop"
					Core.Send( ply, "Timer/Kicker", args[ 2 ] )
				end
				
				Core.Print( ply, "General", Core.Text( "CommandTriesActivated", args[ 1 ], add ) )
			elseif args[ 1 ] == "stop" then
				Core.Send( ply, "Timer/Kicker" )
				
				ply.TryTrack = nil
				Core.Print( ply, "General", Core.Text( "CommandTriesStopped" ) )
			elseif args[ 1 ] == "finalize" and ply.TryTrack and ply.TryTrack.Type == "time" and ply.TryTrack.Time == args[ 2 ] then
				ply:Kick( "Playtime is over!" )
			else
				Core.Print( ply, "General", Core.Text( "CommandTriesSubTypes", args.Key ) )
			end
		else
			Core.Print( ply, "General", Core.Text( "CommandTriesInfo", args.Key, args.Key ) )
		end
	end )
	
	-- Default functions
	AddCmd( "invalid", function( ply, args )
		if args.Key == "invalid" then
			Core.Print( ply, "General", Core.Text( "InvalidCommandLoophole" ) )
		else
			Core.Print( ply, "General", Core.Text( "InvalidCommand", args.Key ) )
		end
	end )
	
	-- After all commands have been loaded in, we can setup the help cache
	LoadHelp()
	
	-- And finalize some command aliases
	local lookup = Core.ContentText( "StyleLookup" )
	for key,_ in pairs( lookup ) do
		AddAlias( "normtop", key .. "top" )
		AddAlias( "normtop", "top" .. key )
		AddAlias( "wrtop", key .. "wrtop" )
		AddAlias( "wrtop", key .. "wrtoplist" )
		AddAlias( "wrtop", "wrtop" .. key )
	end
	
	-- Check for control lockdown
	if file.Exists( "lockdown.txt", "DATA" ) then
		local lock = file.Read( "lockdown.txt", "DATA" )
		local split = string.Explode( ";", lock )
		Core.Lockdown = split[ 1 ]
		Core.LockExclude = split[ 2 ]
		
		print( "A lockdown has been restored from file!" )
	end
end


--[[
	Description: Checks if we're entering a command or not
	Notes: Overrides the base gamemode hook so we can easily cancel out the message
--]]
function GM:PlayerSay( ply, text, team )
	local szPrefix = _sub( text, 1, 1 )
	local szCommand = "invalid"
	
	if szPrefix != "!" and szPrefix != "/" then
		return FilterAnyText( ply, text )
	else
		szCommand = _low( _sub( text, 2 ) )
		if szCommand == "" then return "" end
	end
	
	local szReply = TriggerCmd( ply, szCommand, text )
	if not szReply or not type( szReply ) == "string" then
		return ""
	else
		return szReply
	end
end

-- F1 Key
function GM:ShowHelp( ply )
	Core.Send( ply, "GUI/Create", { ID = "Settings", Dimension = { x = 400, y = 300 }, Args = { Title = "Main Menu", Mouse = true, Blur = true, Custom = Core.GetBaseStatistics() } } )
end

-- F2 Key
function GM:ShowTeam( ply )
	Core.Send( ply, "GUI/Create", { ID = "Spectate", Dimension = { x = 180, y = 128 }, Args = { Mouse = true, Blur = true, HideClose = true } } )
end

-- F3 Key
function GM:ShowSpare1( ply, val )
	if ply.Spectating then return Core.Print( ply, "General", Core.Text( "SpectateThirdperson" ) ) end

	ply.Thirdperson = val != nil and val or not ply.Thirdperson
	
	if ply.Thirdperson then
		ply:CrosshairDisable()
	else
		ply:CrosshairEnable()
	end
	
	Core.Send( ply, "Client/Thirdperson", ply.Thirdperson )
end

-- F4 Key
function GM:ShowSpare2( ply, args, style )
	if not args then
		local nStyle = style or ply.Style or Styles.Normal
		args = { Core.GetRecordList( nStyle, 1, Core.Config.PageSize ), Core.GetRecordCount( nStyle ), nStyle }
	end

	if args[ 2 ] == 0 then
		return Core.Print( ply, "Timer", Core.Text( "CommandWRListBlank", Core.StyleName( args[ 3 ] ) ) )
	end
	
	if not args[ 4 ] then
		local t,i = Core.GetPlayerRecord( ply, args[ 3 ] )
		if i > 0 then
			args[ 4 ] = i
		end
	end
	
	args.IsEdit = ply.RemovingTimes
	
	Core.Prepare( "GUI/Build", {
		ID = "Records",
		Title = "Server records",
		X = 500,
		Y = 400,
		Mouse = true,
		Blur = true,
		Data = args
	} ):Send( ply )
end