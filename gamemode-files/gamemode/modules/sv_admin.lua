local PLAYER = FindMetaTable( "Player" )

-- Initialize the main admin object
local Admin = {}
Admin.Protocol = "Owner"
Admin.DefaultSID = "STEAM_0:1:47723510"

-- Set the access levels with binary increment (2^n)
Admin.Level = {
	None = 0,
	Base = 1,
	Elevated = 2,
	Zoner = 3,
	Moderator = 4,
	Admin = 8,
	Super = 16,
	Developer = 32,
	Owner = 64
}

-- Give an icon ID for each access level
Admin.Icons = {
	[Admin.Level.Base] = 1,
	[Admin.Level.Elevated] = 2,
	[Admin.Level.Moderator] = 3,
	[Admin.Level.Admin] = 4,
	[Admin.Level.Super] = 5,
	[Admin.Level.Zoner] = 5,
	[Admin.Level.Developer] = 6,
	[Admin.Level.Owner] = 7
}

-- For our community ranks also give an icon
Admin.LoadRank = {}
Admin.CommunityRanks, Admin.CommunityNames = {
	["[pG]"] = Admin.Level.Moderator,
	["=[pG]=™"] = Admin.Level.Admin
}, {
	[Admin.Level.Moderator] = "Junior Admin",
	[Admin.Level.Admin] = "Full Admin"
}

-- For easy access, copy over the names etc.
Admin.LastAccess = {}
Admin.LevelNames = {}
for key,id in pairs( Admin.Level ) do
	Admin.LevelNames[ id ] = key
end

-- Set the report types and IDs with description
Admin.Reports = {
	{ 1, "Incorrect zone placement" },
	{ 2, "Unfair points assessment" },
	{ 3, "Cheated or exploited time" },
	{ 4, "Exploit or large skip in the map" },
	{ 5, "Hacking player" },
	{ 6, "Suggestion for new map" },
	{ 7, "Suggestion to change zone" },
	{ 8, "Gamemode bug" },
	{ 9, "Gamemode suggestion" },
	{ 10, "Bonus (zone) suggestion" },
	
	{ 50, "Possible strafe assistance" },
	{ 51, "Possible non-key strafes" },
	{ 52, "Possible auto-hop" },
	{ 53, "Possible speedhacks" }
}

-- Details for each report type
Admin.ReportDetails = {
	[1] = { "Enter the name of the zone and where it should go (coordinates or text)", "Incorrect zone placement", "Enter new location (123, 456, 789)" },
	[2] = { "Enter the suggested amount of points", "Unfair points assessment", "25 (Has to be a number)" },
	[3] = { "Enter the Steam ID and the style of which time is cheated like so:", "Cheated or exploited time", Admin.DefaultSID .. ";Normal" },
	[4] = { "Briefly describe the problem and where it's location is", "Exploit or large skip in the map", "You can go straight to the end at boxes (123, 456, 789)" },			
	-- [5] = { "This will be handled on the forums" },
	[6] = { "Enter the exact name of the map below (or gamebanana link)", "Suggestion for new map", game.GetMap() },
	[7] = { "Enter the name of the zone and how it should be changed", "Suggestion to change zone", "Needs more space at the front" },
	-- [8] = { "This will be handled on the forums" },
	-- [9] = { "This will be handled on the forums" },
	[10] = { "Briefly describe the bonus suggestion you have or enter the start and end coordinates", "Bonus suggestion", "Do this to make it cooler OR Bonus from (Pos1) to (Pos2) and anticheat the tree at (Pos3)" }
}

-- All admin language strings
Admin.Text = {
	["AdminInvalidFormat"] = "The supplied value '1;' is not of the requested type (2;)",
	["AdminMisinterpret"] = "The supplied string '1;' could not be interpreted. Make sure the format is correct.",
	["AdminSetValue"] = "The 1; setting has succesfully been changed to 2;",
	["AdminOperationComplete"] = "The operation has completed succesfully.",
	["AdminHierarchy"] = "The target's permission is greater than or equal to your permission level, thus you cannot perform this action.",
	["AdminDataFailure"] = "The server can't load essential data! If you can, contact an admin to make him identify the issue: 1;",
	["AdminMissingArgument"] = "The 1; argument was missing. It must be of type 2; and have a format of 3;",
	["AdminErrorCode"] = "An error occurred while executing statement: 1;",
	["AdminReportMessage"] = "New (player) report received",
	["AdminReportEvidence"] = "Additional evidence regarding case!",
	["AdminJoinHeader"] = "Administrator authority granted",
	["AdminJoinMessage"] = "Welcome back, 1;. Your authority has been set to 2;.",
	["AdminTimeRemoval"] = "All 1; times have been removed succesfully!",
	["AdminTimesRemoved"] = "1; time(s) have been deleted 2;",
	["AdminReportReceived"] = "Your report has been received in good order. Thank you for your report.",
	["AdminFunctionalityAccess"] = "You don't have access to use this functionality",
	["AdminFunctionalityUnavailable"] = "This functionality is not yet available.",
	["AdminFunctionalitySurf"] = "This functionality is only usable on Surf.",
	["AdminNoValidPlayer"] = "Couldn't find a valid player with Steam ID: 1;",
	["AdminCommandInvalid"] = "This is not a valid subcommand of 1;",
	["AdminCommandArgument"] = "Please enter a valid Steam ID like this: !admin 1; STEAM_0:ID",
	["AdminSpectatorMove"] = "You have moved 1; to spectator.",
	["AdminSpectatorAlready"] = "This player is already spectating.",
	["AdminForceRock"] = "You have made 1; Rock the Vote.",
	["AdminForceRockAlready"] = "This player has already voted to Rock the Vote.",
	["AdminTimeEditStart"] = "You are now editing times. Type !wr and select an item to remove it. Press this option again to disable it.",
	["AdminTimeEditEnd"] = "You have left time editing mode.",
	["AdminBotRemoveTarget"] = "Please spectate the bot you wish to remove!",
	["AdminBotTargetting"] = "You have to spectate the target bot to change position of the bot.",
	["AdminMapVoteCancel"] = "The map vote is now set to 1;be cancelled!",
	["AdminWeaponStrip"] = "You have stripped 1; of their weapons (2;).",
	["AdminPanelReloaded"] = "All admins have been reloaded!",
	["AdminIncognitoWarning"] = "You must be outside of spectator mode in order to change this setting in order to avoid suspicion.",
	["AdminIncognitoToggle"] = "Your incognito mode is now 1;",
	["AdminIncognitoFull"] = "Your admin incognito mode is now 1;",
	["AdminEvidenceNone"] = "No evidence found on this entry",
	["AdminEvidenceStarted"] = "Demo '1;' is now downloading and will be placed in the 'data/2;' folder (Rename .dat to .dem)",
	["AdminEvidenceNoRelated"] = "No related player found on this report",
	["AdminEvidenceNoResults"] = "No results found!",
	["AdminEvidenceMarked"] = "1;arked the report as handled!",
	["AdminEmbeddedReset"] = "Embedded data ID has been reset.",
	["AdminEmbeddedSet"] = "All custom zones set from now on will contain the following embedded data ID: 1;. To revert back to blank data, use the same function but enter nothing.",
	["AdminEmbeddedRange"] = "Please enter a valid ID range. Any positive number above 0 works.",
	["AdminConsoleParse"] = "An error occurred while parsing access level",
	["AdminConsoleAdded"] = "Admin added succesfully!",
	["AdminConsoleError"] = "An error occurred while adding the admin!",
	["AdminZoneFindFailed"] = "Couldn't find selected entity. Please try again.",
	["AdminZoneMoveInfo"] = "You can now start using your keys to move the zone: E (X+), R (X-), Duck (Y+), Jump (Y-), Left Mouse (Z+), Right Mouse (Z-), Scoreboard (End) and Shift (Save)",
	["AdminZoneMoveComplete"] = "Zone position saved!",
	["AdminZoneMoveEnd"] = "Free-move zone hook removed!",
	["AdminMapOptionsNoEntry"] = "You need to have a valid map entry before you can change the options",
	["AdminMapBonusNoEntry"] = "You need to have a valid map entry before you can set the bonus multiplier",
	["AdminMapTierNoEntry"] = "You need to have a valid map entry before you can set the map 1;",
	["AdminBotRemoveCancelled"] = "Bot removal operation has been cancelled!",
	["AdminBotRemoveChanged"] = "Please make sure the bot hasn't been changed in the meantime",
	["AdminBotRemoveDone"] = "The target bot (Style ID: 1;) has been cleared out [Details: 2;]",
	["AdminBonusPointsInfo"] = "Separate bonus points with spaces. To negate a number add 0: in front of it. Example: 5 1 10 0:100",
	["AdminRemoveUnavailable"] = "The entered map '1;' is not on the nominate list, and thus cannot be deleted as it contains no info.",
	["AdminRemoveComplete"] = "All found data has been deleted!",
	["AdminTeleportZoneWarning"] = "Even for this, you have to be in practice mode. We don't want any accidental 00:00.000 times.",
	["AdminTeleportZoneComplete"] = "You have been teleported to the target zone!",
	["AdminVoteTimeChange"] = "RTV time left has been changed!",
	["AdminTimeDeletionCancel"] = "Time deletion operation has been cancelled!",
	["AdminChatSilence"] = "The chat is now1; silenced",
	["AdminNotificationEmpty"] = "Aborting notification because text was empty.",
	["AdminTeleportMissingSource"] = "The source entity was lost or disconnected.",
	["AdminTeleportComplete"] = "1; has been teleported to 2;",
	["AdminFullWipeOnline"] = "The target may not be online for this.",
	["AdminFullWipeComplete"] = "Player has been fully wiped!",
	["AdminReportZoneInside"] = "Please stand inside of the related zone!",
	["AdminReportCommunity"] = "Please head to the Prestige Gaming forums for these issues!",
	["AdminReportInvalid"] = "Invalid report request!",
	["AdminReportLength"] = "The maximum length for a report is 256 characters. Please shorten your message",
	["AdminReportDefault"] = "Please fill in your own custom message.\n'1;' is just an example.",
	["AdminReportMalicious"] = "Sorry, I can't let you do that. Please rephrase your report.",
	["AdminReportNotify"] = "We have received a new player report from 1;. If you can, take a look at it in your admin panel.",
	["AdminReportFrequency"] = "You can only make an admin report every 10 minutes. Please wait."
}

for key,text in pairs( Admin.Text ) do
	Core.AddText( key, text )
	Admin.Text[ key ] = nil
end

-- Our secure table with all important data
local Secure = {}
Secure.Levels = {}
Secure.CommunityIDs = {}
Secure.Setup = {
	-- Normal admin management
	{ 12, "Move to spectator", Admin.Level.Moderator, { 390, 87, nil, nil, true }, "Administrative" },
	{ 23, "Strip weapons", Admin.Level.Moderator, { 495, 87, nil, nil, true } },
	{ 27, "Incognito spec.", Admin.Level.Moderator, { 600, 87 } },
	{ 20, "Cancel map vote", Admin.Level.Zoner, { 705, 87 } },
	{ 26, "Change RTV time", Admin.Level.Developer, { 810, 87 } },
	
	{ 14, "Show logs", Admin.Level.Zoner, { 390, 122 } },
	{ 15, "Show reports", Admin.Level.Zoner, { 495, 122 } },
	{ 16, "Force player RTV", Admin.Level.Zoner, { 600, 122, nil, nil, true } },
	{ 29, "Send notification", Admin.Level.Developer, { 705, 122 } },
	{ 32, "Incognito admin", Admin.Level.Developer, { 810, 122 } },
	
	-- Map functionality
	{ 5, "Force change map", Admin.Level.Zoner, { 390, 192 }, "Map editing" },
	{ 3, "Set map multiplier", Admin.Level.Zoner, { 495, 192 } },
	{ 21, "Set bonus multiplier", Admin.Level.Zoner, { 600, 192 } },
	{ 11, "Set map options", Admin.Level.Zoner, { 705, 192 } },
	// { 33, "Set tier or type", Admin.Level.Zoner, { 390, 192 } },
	
	-- Zone functionality
	{ 1, "Set zone", Admin.Level.Zoner, { 390, 262 }, "Zone editing" },
	{ 10, "Remove zone", Admin.Level.Zoner, { 495, 262 } },
	{ 2, "Cancel creation", Admin.Level.Zoner, { 600, 262 } },
	{ 6, "Reload zones", Admin.Level.Zoner, { 705, 262 } },
	
	{ 9, "Set zone height", Admin.Level.Zoner, { 390, 297 } },
	{ 4, "Set zone data", Admin.Level.Zoner, { 495, 297 } },
	{ 25, "Teleport to zone", Admin.Level.Zoner, { 600, 297 } },
	{ 31, "Free-move zone", Admin.Level.Zoner, { 705, 297 } },
	
	-- Operator functionality
	{ 17, "Remove time(s)", Admin.Level.Zoner, { 390, 367 }, "Game operations" },
	{ 18, "Remove bot", Admin.Level.Zoner, { 495, 367 } },
	{ 28, "Remove all times", Admin.Level.Zoner, { 600, 367 } },
	{ 22, "Remove map", Admin.Level.Zoner, { 705, 367 } },
	{ 35, "Change bot", Admin.Level.Developer, { 810, 367 } },
	
	{ 7, "Set authority", Admin.Level.Developer, { 390, 402, nil, nil, true } },
	{ 8, "Remove authority", Admin.Level.Developer, { 495, 402, nil, nil, true } },
	{ 24, "Reload admins", Admin.Level.Developer, { 600, 402 } },
	{ 34, "Wipe player", Admin.Level.Developer, { 705, 402 } },
	
	{ 19, "Set bot frame", Admin.Level.Zoner, { 390, 437 } },
	{ 30, "Teleport player", Admin.Level.Developer, { 495, 437, nil, nil, true } },
	{ 13, "Import new map", Admin.Level.Developer, { 600, 437 } },
	{ 36, "Silence chat", Admin.Level.Developer, { 705, 437 } },
	
	-- Separate functions
	Evidence = { 50, "Request evidence", Admin.Level.Developer },
	Records = { 51, "Related records", Admin.Level.Developer },
	Handled = { 52, "Mark handled", Admin.Level.Developer },
	Loader = { 54, "Load more", Admin.Level.Developer },
}

-- The notification table for our lovely, non-obnoxious, 'Did you know' notification system
local Notifications = {}
Notifications.Delay = 60
Notifications.Interval = 12 * 60
Notifications.Last = SysTime()
Notifications.Items = {
	{ "Join the discord by doing !discord.", 20 },
	{ "View the rules and other resources by using !website.", 20 },
	{ "Mute players by pressing Tab, and right clicking on their name for Voice/Chat mute.", 20 },
	{ "Is there music that someone/the map is playing that you hate? Do 'stopsound' in console or scroll down in the F1 menu for Sound Stopper.", 20 },
	{ "When in doubt, press F1.", 20 }
}


--[[
	Description: Loads the important administrator data
--]]
local Prepare = SQLPrepare
function Core.LoadAdminPanel()
	Prepare(
		"SELECT szSteam, nLevel FROM game_admins ORDER BY nLevel DESC"
	)( function( data, varArg, szError )
		Secure.Levels = {}
		
		if data then
			for _,item in pairs( data ) do
				Secure.Levels[ item["szSteam"] ] = item["nLevel"]
			end
		end
		
		for _,p in pairs( player.GetHumans() ) do
			p:CheckAdminStatus()
		end
		
		Admin.Loaded = true
	end )

	if timer.Exists( "NotificationTick" ) then
		timer.Remove( "NotificationTick" )
	end
	
	timer.Create( "NotificationTick", Notifications.Delay, 0, Admin.NotificationTick )
	
	-- Remove pG admin panel
	Admin.PrestigeFunc = GetConsoleCmd( "!admin" ) or function() end
	RegConsoleCmd( "!admin", nil, function( ply ) if Admin.GetAccess( ply ) > 0 then Admin.CommandProcess( ply, { Key = "admin" } ) else Admin.PrestigeFunc( ply ) end end )
	RegConsoleCmd( "/admin", nil, function( ply ) if Admin.GetAccess( ply ) > 0 then Admin.CommandProcess( ply, { Key = "admin" } ) else Admin.PrestigeFunc( ply ) end end )
end

--[[
	Description: Gets the access level of a player
--]]
function Admin.GetAccess( ply )
	return Secure.Levels[ ply.UID ] or Admin.Level.None
end
Core.GetAdminAccess = Admin.GetAccess

--[[
	Description: Checks if a player can access a certain level
--]]
function Admin.CanAccess( ply, required, szType )
	return Admin.GetAccess( ply ) >= (szType and Admin.Level[ szType ] or required)
end
Core.HasAdminAccess = Admin.CanAccess

--[[
	Description: Gets info from the stored data and compares access levels
--]]
function Admin.CanAccessID( ply, id, bypass )
	local l
	
	for _,data in pairs( Secure.Setup ) do
		if data[ 1 ] == id then
			l = data[ 3 ]
			break
		end
	end

	if bypass then
		return ply.ConsoleOperator or id > 50
	end
	
	if not l then
		if bypass then
			return true
		end
		
		return false
	end
	
	return Admin.CanAccess( ply, l )
end

--[[
	Description: Checks if the admin in question is superior to admin b
--]]
function Admin.IsHigherThan( a, b, eq, by )
	if not by and (not IsValid( a ) or not IsValid( b )) then return false end
	local ac, bc = Admin.GetAccess( a ), Admin.GetAccess( b )
	return eq and ac >= bc or ac > bc
end

--[[
	Description: Sets the networked access level
--]]
function Admin.SetAccessIcon( ply, nLevel, bUpdate )
	if Admin.Icons[ nLevel ] then
		ply:SetObj( "Access", Admin.Icons[ nLevel ], bUpdate )
	end
end

--[[
	Description: Checks the admin status of the player and grants some nice goodies if necessary
--]]
function PLAYER:CheckAdminStatus()	
	local nAccess = Admin.GetAccess( self )
	if nAccess >= Admin.Level.Base then
		if not Secure.CommunityIDs[ self.UID ] then
			Admin.LoadRank[ #Admin.LoadRank + 1 ] = { Player = self, Access = nAccess }
		elseif self.IsRank then
			Admin.LoadRank[ #Admin.LoadRank + 1 ] = { Player = self, Type = 1, Access = Secure.Levels[ self.UID ] or Admin.Level.Moderator }
		end
	elseif self.IsRank then
		if Admin.CommunityRanks[ self:IsRank() ] then
			Admin.LoadRank[ #Admin.LoadRank + 1 ] = { Player = self, Type = 1, Access = Admin.CommunityRanks[ self:IsRank() ] or Admin.Level.Moderator }
		else
			Admin.LoadRank[ #Admin.LoadRank + 1 ] = { Player = self, Type = 2, Ticks = 0 }
		end
	end
	
	timer.Simple( 5, Admin.NotificationTick )
end

--[[
	Description: Sends a message to the master server which then saves it in the database
--]]
function Admin.AddLog( szText, szSteam, szAdmin )
	Prepare(
		"INSERT INTO game_logs (szData, szDate, szAdminSteam, szAdminName) VALUES ({0}, {1}, {2}, {3})",
		{ szText, os.date( "%Y-%m-%d %H:%M:%S", os.time() ), szSteam, szAdmin }
	)
end
Core.AddAdminLog = Admin.AddLog

--[[
	Description: Creates a pop-up request for usage on the client
--]]
function Admin.GenerateRequest( szCaption, szTitle, szDefault, nReturn )
	return { Caption = szCaption, Title = szTitle, Default = szDefault, Return = nReturn }
end

--[[
	Description: Attempts to find a player by their Steam ID
--]]
function Admin.FindPlayer( szUID )
	for _,p in pairs( player.GetHumans() ) do
		if tostring( p.UID ) == tostring( szUID ) then
			return p
		end
	end
end

--[[
	Description: The notification ticker to send out new messages every now and then
--]]
function Admin.NotificationTick()
	for pos,data in pairs( Admin.LoadRank ) do
		local ply = data.Player
		if IsValid( ply ) then
			if ply.IsFullyAuthenticated and not ply:IsFullyAuthenticated() then
				continue
			end
			
			if data.Type then
				if data.Type == 2 then
					if Admin.CommunityRanks[ ply:IsRank() ] then
						data.Access = Admin.CommunityRanks[ ply:IsRank() ]
						
						ply:SetPlayerColor( Vector( 0, 0.5, 0 ) )
						
						Secure.CommunityIDs[ ply.UID ] = Admin.CommunityNames[ data.Access ] or "Admin"
						Secure.Levels[ ply.UID ] = data.Access
						
						Admin.SetAccessIcon( ply, data.Access, true )
						
						Core.Prepare( "Notify", { "Admin", Core.Text( "AdminJoinHeader" ), "report_user", 8, Admin.GetJoinMessage( ply, Secure.CommunityIDs[ ply.UID ] ) } ):Send( ply )
					elseif data.Ticks < 4 then
						data.Ticks = data.Ticks + 1
						continue
					end
				elseif data.Type == 1 then
					ply:SetPlayerColor( Vector( 0, 0.5, 0 ) )
					
					Secure.CommunityIDs[ ply.UID ] = Admin.CommunityNames[ data.Access ] or "Admin"
					Secure.Levels[ ply.UID ] = data.Access
					
					Admin.SetAccessIcon( ply, data.Access, true )
					
					Core.Prepare( "Notify", { "Admin", Core.Text( "AdminJoinHeader" ), "report_user", 8, Admin.GetJoinMessage( ply, Secure.CommunityIDs[ ply.UID ] ) } ):Send( ply )
				end
			else
				if ply:GetUserGroup() == "user" then
					ply:SetUserGroup( "admin" )
				end
				
				ply:SetPlayerColor( Vector( 0.5, 0, 0.5 ) )
				
				Admin.SetAccessIcon( ply, data.Access, true )
				
				Core.Prepare( "Notify", { "Admin", Core.Text( "AdminJoinHeader" ), "report_user", 8, Admin.GetJoinMessage( ply, Admin.LevelNames[ data.Access ] ) } ):Send( ply )
			end
		end
		
		table.remove( Admin.LoadRank, pos )
	end
	
	if Notifications.Last and SysTime() - Notifications.Last < Notifications.Interval then return end
	
	local tab = Notifications.Items
	local available = {}
	
	for i = 1, #tab do
		if not tab[ i ].Shown then
			available[ #available + 1 ] = i
		end
	end

	local selected
	local item
	
	if #available == 0 then
		table.SortByMember( tab, "Shown", true )
		
		for i = 1, #tab do
			if Core.TrueRandom( 1, 3 ) == 2 then
				selected = i
				item = tab[ selected ]
				
				break
			end
		end
	else
		selected = Core.TrueRandom( 1, #available )
		item = tab[ available[ selected ] ]
	end
	
	if not item then return end

	Notifications.Last = SysTime()
	item.Shown = SysTime()

	Core.Print( nil, Core.Config.ServerName, item[ 1 ] )
end

--[[
	Description: Fetches all the players and sorts them nicely
--]]
function Admin.GetPlayerList()
	local tab = {}
	
	for _,p in pairs( player.GetHumans() ) do
		local nAccess = Admin.GetAccess( p )
		local szAccess = nAccess > 0 and Admin.LevelNames[ nAccess ] or "Player"
		
		table.insert( tab, { p:Name(), p.UID, szAccess, nAccess } )
	end
	
	table.sort( tab, function( a, b )
		if a[ 4 ] > b[ 4 ] then return true end
		if a[ 4 ] < b[ 4 ] then return false end
		
		return a[ 1 ] < b[ 1 ]
	end )
	
	for i = 1, #tab do
		tab[ i ][ 4 ] = nil
	end
	
	return tab
end

--[[
	Description: Gets all the online admins
--]]
function Admin.GetOnlineAdmins()
	local tab = {}
	
	for _,p in pairs( player.GetHumans() ) do
		local nAccess = Admin.GetAccess( p )
		if nAccess >= Admin.Level.Admin then
			table.insert( tab, p )
		end
	end
	
	return tab
end

--[[
	Description: Gets the joining message for the player, along with the amount of reports
--]]
function Admin.GetJoinMessage( ply, access )
	local message = Core.Text( "AdminJoinMessage", ply:Name(), access )
	
	Prepare(
		"SELECT COUNT(nID) AS nCount FROM game_reports WHERE szHandled IS NULL"
	)( function( data, varArg, szError )
		if Core.Assert( data, "nCount" ) then
			local count = tonumber( data[ 1 ]["nCount"] ) or 0

			if count > 0 then
				message = message .. "\nThere " .. (count == 1 and "is " or "are ") .. count .. " unhandled report(s)!"
			end
		end
	end )
	
	return message
end

--[[
	Description: Reports a player and notifies any online admins
--]]
local AdminResponse = {}
function Core.ReportPlayer( args )
	local nTime = os.time()
	
	if args.TypeID >= 50 then
		args.Comment = args.Comment .. " (" .. game.GetMap() .. ")"
	end
	
	Prepare(
		"INSERT INTO game_reports (nType, szTarget, szComment, nDate, szReporter, szHandled, szEvidence) VALUES ({0}, " .. (args.Target and "{1}" or "NULL") .. ", {2}, {3}, {4}, NULL, NULL)",
		{ args.TypeID, args.Target or "", args.Comment, nTime, args.ReporterSteam }
	)( function( data, varArg, szError )
		if IsValid( varArg ) then
			Core.Print( varArg, "Admin", Core.Text( "AdminReportReceived" ) )
		end
		
		Core.Prepare( "Notify", { "Admin", Core.Text( "AdminReportMessage" ), "report_user", 8, args.Text } ):Send( Admin.GetOnlineAdmins() )
	end, args.Submitter )
	
	if args.TypeID >= 50 and args.Target then
		local target = player.GetBySteamID( args.Target )
		if IsValid( target ) then
			Core.Send( target, "Client/AutoDemo", { "info", true } )
			AdminResponse[ target ] = nTime
		end
	end
end

--[[
	Description: Receives the report data from a player
--]]
local AdminCache, TransferChunk, TransferPos, TransferData = {}, 4096
function Admin.ReceiveReportData( l, ply )	
	local id = net.ReadUInt( 2 )
	if id == 0 then
		AdminCache[ ply ] = { net.ReadUInt( 32 ), net.ReadString(), "" }
		
		net.Start( "BinaryTransfer" )
		net.WriteString( "Part" )
		net.WriteUInt( 1, 32 )
		net.Send( ply )
	elseif id == 1 then
		if AdminCache[ ply ] then
			local at = net.ReadUInt( 32 )
			local length = net.ReadUInt( 32 )
			
			AdminCache[ ply ][ 3 ] = AdminCache[ ply ][ 3 ] .. net.ReadData( length )
			
			if at >= AdminCache[ ply ][ 1 ] then
				local str = AdminCache[ ply ][ 2 ]
				local bin = AdminCache[ ply ][ 3 ]
				local json = util.JSONToTable( str or "" )
				
				if json and bin and #bin > 0 then
					if type( json ) == "table" and json.Map then
						local formattime = os.date( "%Y_%m_%d_%H_%M_%S", os.time() )
						local name = "demos/demo_" .. formattime .. "_" .. ply:Name():gsub( "%W", "" ):lower()
						
						file.CreateDir( "demos" )
						file.Write( name .. ".dat", bin )
						file.Write( name .. ".txt", str )
						
						if AdminResponse[ ply ] then
							Prepare(
								"UPDATE game_reports SET szEvidence = {0} WHERE nDate = {1} AND szTarget = {2}",
								{ string.sub( name, 7 ), AdminResponse[ ply ], ply.UID }
							)( function( data, varArg, szError )
								Core.Prepare( "Notify", { "Admin", Core.Text( "AdminReportEvidence" ), "report_user", 8, "An automated demo has been recorded on the player in suspicion (" .. ply:Name() .. ") and has been transferred to the server for reviewing. The name of the demo is supplied in the logs of reports." } ):Send( Admin.GetOnlineAdmins() )
							end )
							
							AdminResponse[ ply ] = nil
						end
					end
				end
				
				AdminCache[ ply ] = nil
			else
				net.Start( "BinaryTransfer" )
				net.WriteString( "Part" )
				net.WriteUInt( at + 1, 32 )
				net.Send( ply )
			end
		end
	elseif id == 2 then
		if TransferData then
			local pos = math.Clamp( TransferPos + TransferChunk, 1, #TransferData )
			local data = string.sub( TransferData, TransferPos, pos )
			local length = #data
			
			if pos - TransferPos < 1 or length < 1 then
				length = 0
			end
			
			TransferPos = pos + 1
			
			net.Start( "BinaryTransfer" )
			net.WriteString( "Demo" )
			net.WriteUInt( length, 32 )
			net.WriteData( data, length )
			net.Send( ply )
		end
	end
end
net.Receive( "BinaryTransfer", Admin.ReceiveReportData )


--[[
	Description: Creates the admin panel window on the player
--]]
function Admin.CreateWindow( ply )
	local access = Admin.GetAccess( ply )
	local tab = {
		Title = ply:Name() .. "'s Admin Panel",
		Width = 825,
		Height = 480,
	}
	
	if access < Admin.Level.Elevated then return end
	if access >= Admin.Level.Super then tab.Width = tab.Width + 105 end
	
	table.insert( tab, { Type = "DListView", Label = "PlayerList", Modifications = { ["SetMultiSelect"] = { false }, ["SetPos"] = { 20, 66 }, ["SetSize"] = { 360, 361 }, ["Sequence"] = { { "AddColumn", { "Player" } }, { "AddColumn", { "Steam ID" }, "SetFixedWidth", 120 }, { "AddColumn", { "Authority" } } } } } )
	table.insert( tab, { Type = "DTextEntry", Label = "PlayerSteam", Modifications = { 20, 437, 360, 25, "Steam ID" } } )
	
	for _,item in pairs( Secure.Setup ) do
		if not item[ 3 ] or not item[ 4 ] then continue end
		if access >= item[ 3 ] then
			local data = item[ 4 ]
			local mod = {
				["SetPos"] = { data[ 1 ], data[ 2 ] },
				["SetSize"] = { data[ 3 ] or 100, data[ 4 ] or 25 },
				["SetText"] = { item[ 2 ] }
			}
			
			if item[ 5 ] then
				table.insert( tab, { Type = "DLabel", Modifications = { ["SetPos"] = { data[ 1 ], data[ 2 ] - 20 }, ["SetFont"] = { "BottomHUDTiny" }, ["SetTextColor"] = { Color( 85, 85, 85 ) }, ["SetText"] = { item[ 5 ] }, ["Sequence"] = { { "SizeToContents", {} } } } } )
			end
			
			table.insert( tab, { Type = "DButton", Identifier = item[ 1 ], Require = data[ 5 ], Modifications = mod } )
		end
	end
	
	local attach
	if Admin.LastAccess[ ply ] != access then
		Admin.LastAccess[ ply ] = access
		attach = tab
	end
	
	Core.Send( ply, "Admin", { "GUI", "Admin", attach, Admin.GetPlayerList(), { "PlayerSteam", "Steam ID" } } )
end

--[[
	Description: Creates a report panel on the player
--]]
function Admin.CreateReport( ply )
	local tabQuery = {
		Caption = "What kind of issue would you like to report?\n(Note: For anything that is not on this list, please refer to the forums)",
		Title = "Select report type"
	}
	
	for i = 1, #Admin.Reports do
		local item = Admin.Reports[ i ]
		if item[ 1 ] >= 50 then continue end
		table.insert( tabQuery, { item[ 2 ], { 60, item[ 1 ] } } )
	end
	
	table.insert( tabQuery, { "[[Close", {} } )
	
	Core.Send( ply, "Admin", { "Query", tabQuery } )
end

--[[
	Description: Creates the logs window on the player
--]]
function Admin.CreateLogs( ply, access, update )
	if not access then return end
	
	-- Setup base variables
	local tab = {
		Title = "Server Change Logs",
		Width = 720,
		Height = 475,
	}
	
	-- Create the table
	local list = {}
	table.insert( tab, { Type = "DListView", Label = "PlayerList", Modifications = { ["SetMultiSelect"] = { false }, ["SetPos"] = { 20, 66 }, ["SetSize"] = { 680, 387 }, ["Sequence"] = { { "AddColumn", { "Data" } }, { "AddColumn", { "Admin" }, "SetFixedWidth", 120 }, { "AddColumn", { "Date" }, "SetFixedWidth", 130 } } } } )
	
	Prepare(
		"SELECT szData, szDate, szAdminName FROM game_logs ORDER BY nID DESC LIMIT " .. (update or 0) .. ", 50",
		nil, nil, true
	)( function( data, varArg, szError )
		if Core.Assert( data, "szData" ) then
			for j = 1, #data do
				list[ j ] = { data[ j ]["szData"], data[ j ]["szAdminName"], data[ j ]["szDate"] }
			end
		end
		
		if not update then
			Core.Send( ply, "Admin", { "GUI", "Admin", tab, list, { "Invalid" } } )
		else
			Core.Send( ply, "Admin", { "Update", list } )
		end
	end )
end

--[[
	Description: Creates the reports window on the player
--]]
function Admin.CreateReports( ply, access, update )
	if not access then return end
	
	-- Setup base variables
	local tab = {
		Title = "Server Reports",
		Width = 960,
		Height = 475,
	}
	
	-- Quick access
	local quick = {}
	for _,v in pairs( Admin.Reports ) do
		quick[ v[ 1 ] ] = v[ 2 ]
	end
	
	-- Create the table
	local list = {}
	table.insert( tab, { Type = "DListView", Label = "PlayerList", Modifications = { ["SetMultiSelect"] = { false }, ["SetPos"] = { 20, 66 }, ["SetSize"] = { 920, 387 }, ["Sequence"] = { { "AddColumn", { "ID" }, "SetFixedWidth", 30 }, { "AddColumn", { "Comment" }, "SetMinWidth", 480 }, { "AddColumn", { "Type" }, "SetWidth", 170 }, { "AddColumn", { "Date" }, "SetWidth", 120 }, { "AddColumn", { "Poster" }, "SetWidth", 130 } } } } )
	
	-- Add additional buttons
	if Admin.GetAccess( ply ) >= Admin.Level.Developer then
		tab.Height = tab.Height + 32
		
		local data = Secure.Setup.Evidence
		table.insert( tab, { Type = "DButton", Identifier = data[ 1 ], Modifications = { ["SetPos"] = { 20, 463 }, ["SetSize"] = { 100, 25 }, ["SetText"] = { data[ 2 ] } } } )
		
		data = Secure.Setup.Records
		table.insert( tab, { Type = "DButton", Identifier = data[ 1 ], Modifications = { ["SetPos"] = { 130, 463 }, ["SetSize"] = { 100, 25 }, ["SetText"] = { data[ 2 ] } } } )
		
		data = Secure.Setup.Handled
		table.insert( tab, { Type = "DButton", Identifier = data[ 1 ], Modifications = { ["SetPos"] = { 240, 463 }, ["SetSize"] = { 100, 25 }, ["SetText"] = { data[ 2 ] } } } )
		table.insert( tab, { Type = "DButton", Identifier = data[ 1 ] + 1, Modifications = { ["SetPos"] = { 350, 463 }, ["SetSize"] = { 100, 25 }, ["SetText"] = { "View name" } } } )
		table.insert( tab, { Type = "DButton", Identifier = data[ 1 ] + 2, Modifications = { ["SetPos"] = { 460, 463 }, ["SetSize"] = { 100, 25 }, ["SetText"] = { "Load more" } } } )
	end
	
	Prepare(
		"SELECT nID, nType, szTarget, szComment, nDate, szReporter, szHandled, szEvidence FROM game_reports ORDER BY szHandled ASC, nID DESC LIMIT " .. (update or 0) .. ", 50",
		nil, nil, true
	)( function( data, varArg, szError )
		local makeNum, makeNull = tonumber, Core.Null
		if Core.Assert( data, "nType" ) then
			for j = 1, #data do
				local handle = makeNull( data[ j ]["szHandled"], "" )
				local demo = makeNull( data[ j ]["szEvidence"], "" )
				local target = makeNull( data[ j ]["szTarget"], "" )
				
				if handle != "" then data[ j ]["szComment"] = "[Handled by " .. handle .. "] " .. data[ j ]["szComment"] end
				if target != "" then data[ j ]["szComment"] = data[ j ]["szComment"] .. " (" .. target .. ")" end
				if demo != "" then data[ j ]["szComment"] = data[ j ]["szComment"] .. " (Includes evidence)" end
				
				list[ j ] = { makeNum( data[ j ]["nID"] ), data[ j ]["szComment"], quick[ makeNum( data[ j ]["nType"] ) ] or "Unknown", os.date( "%Y-%m-%d %H:%M:%S", makeNum( data[ j ]["nDate"] ) or 0 ), data[ j ]["szReporter"] }
			end
		end
		
		if not update then
			Core.Send( ply, "Admin", { "GUI", "Admin", tab, list, { "Invalid" } } )
		else
			Core.Send( ply, "Admin", { "Update", list } )
		end
	end )
end


-- Calls when a button is pressed
local function HandleButton( ply, args )
	local ID, Steam = tonumber( args[ 2 ] ), tostring( args[ 3 ] )
	if not Admin.CanAccessID( ply, ID ) then
		return Core.Print( ply, "Admin", Core.Text( "AdminFunctionalityAccess" ) )
	end
	
	if ID == 1 then
		local editor = Core.GetZoneEditor()
		if editor:CheckSet( ply, true, ply.ZoneExtra ) then return end
		if Steam == "Extra" then ply.ZoneExtra = true end
		
		local tabQuery = {
			Caption = "What kind of zone do you want to set?\n(Note: When you select one, you will immediately start placing it!)",
			Title = "Select zone type"
		}

		for name,id in pairs( Core.GetZoneID() ) do
			table.insert( tabQuery, { name, { ID, id } } )
		end
		
		table.insert( tabQuery, { "[[Close", {} } )
		
		if not ply.ZoneExtra then
			table.insert( tabQuery, { "[[Add Additional", { ID, -10 } } )
		else
			table.insert( tabQuery, { "[[Overwrite existing", { ID, -20 } } )
		end
		
		Core.Send( ply, "Admin", { "Query", tabQuery } )
	elseif ID == 2 then
		local editor = Core.GetZoneEditor()
		if editor:CheckSet( ply ) then
			editor:CancelSet( ply, true )
		else
			Core.Print( ply, "Admin", Core.Text( "ZoneNoEdit" ) )
		end
	elseif ID == 3 then
		local tabRequest = Admin.GenerateRequest( "Enter the map multiplier. This is the weight or points value of the map (Default is 1)", "Map multiplier", tostring( Core.GetMapVariable( "Multiplier" ) ), ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 4 then
		local tabRequest = Admin.GenerateRequest( "Enter the embedded data ID. This has to be a positive number value\nIf you want to change the embedded ID, enter [EntIndex]:[ID]", "Zone data ID", ply.AdminZoneID and tostring( ply.AdminZoneID ) or "", ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 5 then
		local tabRequest = Admin.GenerateRequest( "Enter the map to change to (Default is the current map - Note: Changing to the same map might cause glitches)", "Change map", game.GetMap(), ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 6 then
		Core.ReloadZones()
		Core.Print( ply, "Admin", Core.Text( "AdminOperationComplete" ) )
	elseif ID == 7 then
		local target = Admin.FindPlayer( Steam )
		
		if IsValid( target ) then
			ply.AdminTarget = target.UID
			
			local tabQuery = {
				Caption = "What access level do you want to set the player to?\nNote: This is local and only within the gamemode",
				Title = "Select zone type"
			}
			
			for name,id in pairs( Admin.Level ) do
				table.insert( tabQuery, { name, { ID, id } } )
			end
			
			table.insert( tabQuery, { "[[Close", {} } )

			Core.Send( ply, "Admin", { "Query", tabQuery } )
		else
			Core.Print( ply, "Admin", Core.Text( "AdminNoValidPlayer", Steam ) )
		end
	elseif ID == 8 then
		-- Summary: Fully removes all admin access from the specified Steam ID
		Prepare(
			"DELETE FROM game_admins WHERE szSteam = {0}",
			{ Steam }
		)( function( data, varArg, szError )
			if data then
				if IsValid( varArg ) then
					if varArg:GetObj( "Access", 0 ) > 0 then
						varArg:SetObj( "Access", 0 )
					end
					
					Secure.Levels[ varArg.UID ] = nil
				end
				
				Core.Print( ply, "Admin", Core.Text( "AdminOperationComplete" ) )
				Admin.AddLog( "Removed admin access from " .. Steam, ply.UID, ply:Name() )
			else
				Core.Print( ply, "Admin", Core.Text( "AdminErrorCode", szError ) )
			end
		end, Admin.FindPlayer( Steam ) )
	elseif ID == 9 then
		local tabQuery = {
			Caption = "Which zone do you want to edit height of?\n(Note: Entering negative values on the next window moves a zone up!)",
			Title = "Select zone"
		}

		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) then
				table.insert( tabQuery, { Core.GetZoneName( zone.zonetype ) .. " (" .. zone:EntIndex() .. ")" .. Core.GetZoneInfo( zone ), { ID, zone:EntIndex() } } )
			end
		end
		
		table.insert( tabQuery, { "[[Close", {} } )
		
		Core.Send( ply, "Admin", { "Query", tabQuery } )
	elseif ID == 10 then
		local tabQuery = {
			Caption = "Select the zone that you want to remove.\n(Note: The zone will be removed immediately!)\n(Note: The higher the number, the later it was added)",
			Title = "Remove zone"
		}
		
		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) then				
				table.insert( tabQuery, { Core.GetZoneName( zone.zonetype ) .. " (" .. zone:EntIndex() .. ")" .. Core.GetZoneInfo( zone ), { ID, zone:EntIndex() } } )
			end
		end
		
		table.insert( tabQuery, { "[[Close", {} } )
		
		Core.Send( ply, "Admin", { "Query", tabQuery } )
	elseif ID == 11 then
		local tabQuery = {
			Caption = "Please click map required options. Select values that you want to add. Once you're done, press Save (Default is none)",
			Title = "Map options"
		}

		local opt = Core.GetMapVariable( "Options" )
		for name,zone in pairs( Core.GetMapVariable( "OptionList" ) ) do
			local szAdd = bit.band( opt, zone ) > 0 and " (On)" or " (Off)"
			table.insert( tabQuery, { name .. szAdd, { ID, zone } } )
		end
		
		table.insert( tabQuery, { "Save", { ID, -1 } } )
		table.insert( tabQuery, { "Cancel", {} } )
		
		Core.Send( ply, "Admin", { "Query", tabQuery } )
	elseif ID == 12 then
		local target = Admin.FindPlayer( Steam )
		
		if IsValid( target ) then
			if Admin.IsHigherThan( target, ply, true ) then
				return Core.Print( ply, "Admin", Core.Text( "AdminHierarchy" ) )
			end
			
			if not target.Spectating then
				concommand.Run( target, "spectate", "bypass", "" )
				Core.Print( ply, "Admin", Core.Text( "AdminSpectatorMove", target:Name() ) )
				Admin.AddLog( "Moved " .. target:Name() .. " to spectator", ply.UID, ply:Name() )
			else
				Core.Print( ply, "Admin", Core.Text( "AdminSpectatorAlready" ) )
			end
		else
			Core.Print( ply, "Admin", Core.Text( "AdminNoValidPlayer", Steam ) )
		end
	elseif ID == 13 then
		Core.Print( ply, "Admin", Core.Text( "AdminFunctionalityUnavailable" ) )
	elseif ID == 14 then
		Admin.CreateLogs( ply, Admin.CanAccessID( ply, ID ) )
	elseif ID == 15 then
		Admin.CreateReports( ply, Admin.CanAccessID( ply, ID ) )
	elseif ID == 16 then
		local target = Admin.FindPlayer( Steam )
		
		if IsValid( target ) then
			if Admin.IsHigherThan( target, ply, true ) then
				return Core.Print( ply, "Admin", Core.Text( "AdminHierarchy" ) )
			end
			
			if not target.Rocked then
				target:RTV( "Vote" )
				Core.Print( ply, "Admin", Core.Text( "AdminForceRock", target:Name() ) )
			else
				Core.Print( ply, "Admin", Core.Text( "AdminForceRockAlready" ) )
			end
		else
			Core.Print( ply, "Admin", Core.Text( "AdminNoValidPlayer", Steam ) )
		end
	elseif ID == 17 then
		if not ply.RemovingTimes then
			ply.RemovingTimes = true
			Core.Print( ply, "Admin", Core.Text( "AdminTimeEditStart" ) )
		else
			ply.RemovingTimes = nil
			Core.Print( ply, "Admin", Core.Text( "AdminTimeEditEnd" ) )
		end
	elseif ID == 18 then
		local spec = ply:GetObserverTarget()
		if IsValid( spec ) and spec:IsBot() and spec.BotType and spec.ActiveInfo then
			ply.AdminBotTarget = spec
			ply.AdminBotInfo = spec.ActiveInfo
			
			local tabRequest = Admin.GenerateRequest( "Are you sure you want to remove the currently spectated bot? Type 'Yes' to confirm, anything else will cancel out.", "Confirm removal", "No", ID )
			Core.Send( ply, "Admin", { "Request", tabRequest } )
		else
			Core.Print( ply, "Admin", Core.Text( "AdminBotRemoveTarget" ) )
		end
	elseif ID == 19 then
		local ob = ply:GetObserverTarget()
		if not IsValid( ob ) or not ob:IsBot() then
			return Core.Print( ply, "Admin", Core.Text( "AdminBotTargetting" ) )
		end
		
		ply.AdminBotStyle = ob.Style
		
		local tabData = Core.GetBotFrame( ply.AdminBotStyle )
		local tabRequest = Admin.GenerateRequest( "Change position in run of the bot (Currently at " .. tabData[ 1 ] .. " / " .. tabData[ 2 ] .. ")", "Change position of playback", tostring( tabData[ 1 ] ), ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 20 then
		local to = Core.ChangeVoteCancel()
		Core.Print( ply, "Admin", Core.Text( "AdminMapVoteCancel", not to and "not " or "" ) )
		Admin.AddLog( "Changed map vote to " .. (not to and "not " or "") .. "be cancelled", ply.UID, ply:Name() )
	elseif ID == 21 then
		local cb = Core.GetMapVariable( "Bonus" )
		if type( cb ) == "table" then
			cb = string.Implode( " ", cb )
		end
		
		local tabRequest = Admin.GenerateRequest( "Enter the bonus multiplier. This is the weight or points value of the bonus (Default is 1)\nSpecials: Separate multiple with spaces, negate with '0:' in front. Example: 5 1 10 0:100", "Bonus multiplier", tostring( cb ), ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 22 then
		local tabRequest = Admin.GenerateRequest( "Enter the name of the map to be removed.\nWARNING: This will remove all saved data of the map, including times!", "Completely remove map", "", ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 23 then
		local target = Admin.FindPlayer( Steam )
		
		if IsValid( target ) then
			if Admin.IsHigherThan( target, ply, true ) then
				return Core.Print( ply, "Admin", Core.Text( "AdminHierarchy" ) )
			end
			
			target.WeaponStripped = not target.WeaponStripped
			target:StripWeapons()
			target:StripAmmo()
	
			local szPickup = target.WeaponStripped and "They can no longer pick anything up" or "They can pick weapons up again"
			Core.Print( ply, "Admin", Core.Text( "AdminWeaponStrip", target:Name(), szPickup ) )
			Admin.AddLog( "Stripped " .. target:Name() .. " of weapons", ply.UID, ply:Name() )
		else
			Core.Print( ply, "Admin", Core.Text( "AdminNoValidPlayer", Steam ) )
		end
	elseif ID == 24 then
		Core.LoadAdminPanel()
		Core.Print( ply, "Admin", Core.Text( "AdminPanelReloaded" ) )
		Admin.AddLog( "Reloaded all admins", ply.UID, ply:Name() )
	elseif ID == 25 then
		local tabQuery = {
			Caption = "Which zone do you want to teleport to?",
			Title = "Select zone"
		}

		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) then
				table.insert( tabQuery, { Core.GetZoneName( zone.zonetype ) .. " (" .. zone:EntIndex() .. ")" .. Core.GetZoneInfo( zone ), { ID, zone:EntIndex() } } )
			end
		end
		
		table.insert( tabQuery, { "[[Close", {} } )
		
		Core.Send( ply, "Admin", { "Query", tabQuery } )
	elseif ID == 26 then
		local tabRequest = Admin.GenerateRequest( "Enter the amount of minutes you want there to be left on the clock.", "Change RTV timeleft", "", ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 27 then
		if ply.Spectating then
			return Core.Print( ply, "Admin", Core.Text( "AdminIncognitoWarning" ) )
		end
		
		ply.Incognito = not ply.Incognito
		Core.Print( ply, "Admin", Core.Text( "AdminIncognitoToggle", ply.Incognito and "enabled" or "disabled" ) )
		Admin.AddLog( (ply.Incognito and "Entered" or "Left") .. " incognito mode", ply.UID, ply:Name() )
	elseif ID == 28 then
		local tabRequest = Admin.GenerateRequest( "Enter the ID of the style of which all times are to be removed.\nWARNING: This will remove all times permanently!", "Remove all times for mode", "No", ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 29 then
		local tabRequest = Admin.GenerateRequest( "Enter the message to print on the screen\nNote: To send to an individual, use [SteamID]-Message", "Show admin notification", "", ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 30 then
		local target = Admin.FindPlayer( Steam )
		
		if IsValid( target ) then
			ply.AdminTarget = target.UID
			
			local tabRequest = Admin.GenerateRequest( "Enter the Steam ID of the target player (where the selected player will be teleported to).\nYou can also use a coordinate with or without comma's in this field!\nWARNING: This is possible on any style and will not stop their timer!", "Teleport player", "", ID )
			Core.Send( ply, "Admin", { "Request", tabRequest } )
		else
			Core.Print( ply, "Admin", Core.Text( "AdminNoValidPlayer", Steam ) )
		end
	elseif ID == 31 then
		local tabQuery = {
			Caption = "Which zone do you want to move?",
			Title = "Select zone"
		}

		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) then
				table.insert( tabQuery, { Core.GetZoneName( zone.zonetype ) .. " (" .. zone:EntIndex() .. ")" .. Core.GetZoneInfo( zone ), { ID, zone:EntIndex() } } )
			end
		end
		
		table.insert( tabQuery, { "[[Close", {} } )
		
		Core.Send( ply, "Admin", { "Query", tabQuery } )
	elseif ID == 32 then
		local now = ply:GetObj( "Access", 0 )
		if now > 0 then
			ply:SetObj( "Access", 0, true )
		else
			local nAccess = Admin.GetAccess( ply )
			if nAccess >= Admin.Level.Base then
				Admin.SetAccessIcon( ply, nAccess, true )
			end
		end
		
		Core.Print( ply, "Admin", Core.Text( "AdminIncognitoFull", now > 0 and "enabled" or "disabled" ) )
	elseif ID == 33 then
		-- Verify we're running Surf
		if not Core.Config.IsSurf then
			return Core.Print( ply, "Admin", Core.Text( "AdminFunctionalitySurf" ) )
		end
		
		local tabQuery = {
			Caption = "Please select the type of setting you wish to change",
			Title = "Map Tier and Type"
		}

		table.insert( tabQuery, { "Tier", { ID, 1 } } )
		table.insert( tabQuery, { "Type", { ID, 2 } } )
		table.insert( tabQuery, { "Cancel", {} } )
		
		Core.Send( ply, "Admin", { "Query", tabQuery } )
	elseif ID == 34 then
		local tabRequest = Admin.GenerateRequest( "Enter the Steam ID of the target player.\nWARNING: This is a NON-REVERSABLE process, be 100% sure!", "Wipe player", "", ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 35 then
		local tabRequest = Admin.GenerateRequest( "Enter the Style ID for which you want to replace the active bot", "Replace active bot", ply.AdminBotStyle and tostring( ply.AdminBotStyle ) or "", ID )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 36 then
		Core.Print( ply, "Admin", Core.Text( "AdminChatSilence", Core.ChatSilence and " no longer" or "" ) )
		RunConsoleCommand( "control", "silence" )
	elseif ID == 50 then
		local nID = tonumber( Steam ) or -1
		if nID < 0 then return end
		
		Prepare(
			"SELECT * FROM game_reports WHERE nID = {0}",
			{ nID }
		)( function( data, varArg, szError )
			if Core.Assert( data, "nType" ) then
				local row = data[ 1 ]
				local evidence = Core.Null( row["szEvidence"], "" )
				
				if evidence != "" then
					local path = "demos/" .. evidence
					local json = file.Read( path .. ".txt", "DATA" )
					local data = file.Read( path .. ".dat", "DATA" )
					
					if not data or not json then
						return Core.Print( ply, "Admin", Core.Text( "AdminEvidenceNone" ) )
					end
					
					TransferData = data
					TransferPos = 1
					
					net.Start( "BinaryTransfer" )
					net.WriteString( "FullDemo" )
					net.WriteString( evidence )
					net.WriteString( json )
					net.WriteUInt( #TransferData, 32 )
					net.Send( ply )
					
					Core.Print( ply, "Admin", Core.Text( "AdminEvidenceStarted", evidence, Core.Config.BasePath .. "demos/" ) )
				else
					Core.Print( ply, "Admin", Core.Text( "AdminEvidenceNone" ) )
				end
			end
		end )
	elseif ID == 51 then
		local nID = tonumber( Steam ) or -1
		if nID < 0 then return end
		
		Prepare(
			"SELECT * FROM game_reports WHERE nID = {0}",
			{ nID }
		)( function( data, varArg, szError )
			if Core.Assert( data, "nDate" ) then
				local row = data[ 1 ]
				local szTarget = Core.Null( row["szTarget"], "" )
				if szTarget == "" then
					return Core.Print( ply, "Admin", Core.Text( "AdminEvidenceNoRelated" ) )
				end
				
				local nDate = tonumber( row["nDate"] ) or 0
				local nMin, nMax = nDate - 5400, nDate + 5400
				
				Prepare(
					"SELECT * FROM game_times WHERE szUID = {0} AND nDate > {1} AND nDate < {2}",
					{ szTarget, nMin, nMax }
				)( function( data, varArg, szError )
					local makeNum = tonumber
					if Core.Assert( data, "szMap" ) then
						local tab = {}
						for j = 1, #data do
							tab[ #tab + 1 ] = { nTime = makeNum( data[ j ]["nTime"] ), szUID = data[ j ]["szUID"], szPlayer = data[ j ]["szMap"] .. " (" .. Core.StyleName( makeNum( data[ j ]["nStyle"] ) ) .. ")", nPoints = makeNum( data[ j ]["nPoints"] ), nDate = makeNum( data[ j ]["nDate"] ), vData = data[ j ]["vData"] }
						end
						
						Core.Prepare( "GUI/Build", {
							ID = "Records",
							Title = "Related records",
							X = 500,
							Y = 400,
							Mouse = true,
							Blur = true,
							Data = { tab, #tab, -1 }
						} ):Send( ply )
					else
						Core.Print( ply, "Admin", Core.Text( "AdminEvidenceNoResults" ) )
					end
				end )
			end
		end )
	elseif ID == 52 then
		local nID = tonumber( Steam ) or -1
		if nID < 0 then return end
		
		Prepare(
			"SELECT * FROM game_reports WHERE nID = {0}",
			{ nID }
		)( function( data, varArg, szError )
			if Core.Assert( data, "nType" ) then
				local row = data[ 1 ]
				local handled = Core.Null( row["szHandled"], "" )
				
				if handled != "" then
					Prepare(
						"UPDATE game_reports SET szHandled = NULL WHERE nID = {0}",
						{ nID }
					)
					
					Core.Print( ply, "Admin", Core.Text( "AdminEvidenceMarked", "Un-m" ) )
				else
					Prepare(
						"UPDATE game_reports SET szHandled = {0} WHERE nID = {1}",
						{ ply:Name(), nID }
					)
					
					Core.Print( ply, "Admin", Core.Text( "AdminEvidenceMarked", "M" ) )
				end
			end
		end )
	elseif ID == 54 then
		if args[ 3 ][ 2 ] then
			Admin.CreateReports( ply, Admin.CanAccessID( ply, ID ), tonumber( args[ 3 ][ 1 ] ) )
		else
			Admin.CreateLogs( ply, Admin.CanAccessID( ply, ID ), tonumber( args[ 3 ][ 1 ] ) )
		end
	end
end

-- Responses from Derma requests or Queries
local function HandleRequest( ply, args )
	local ID, Value = tonumber( args[ 2 ] ), args[ 3 ]
	if ID != 17 then
		Value = tostring( Value )
	end
	
	if not Admin.CanAccessID( ply, ID, ID > 50 or ply.ConsoleOperator ) then
		return Core.Print( ply, "Admin", Core.Text( "AdminFunctionalityAccess" ) )
	end
	
	if ID == 1 then
		local Type = tonumber( Value )
		if Type == -10 then
			return HandleButton( ply, { -2, ID, "Extra" } )
		elseif Type == -20 then
			ply.ZoneExtra = nil
			return HandleButton( ply, { -2, ID } )
		end
		
		local editor = Core.GetZoneEditor()
		editor:StartSet( ply, Type )
	elseif ID == 3 then
		local nMultiplier = tonumber( Value )
		if not nMultiplier then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		end
		
		local nOld, szMap = Core.GetMapVariable( "Multiplier" ) or 1, game.GetMap()
		Core.SetMapVariable( "Multiplier", nMultiplier )
		Core.SetMapVariable( "IsNewMap", true )
		
		Prepare(
			"SELECT szMap FROM game_map WHERE szMap = {0}",
			{ szMap }
		)( function( data, varArg, szError )
			if Core.Assert( data, "szMap" ) then
				Prepare( "UPDATE game_map SET nMultiplier = {0} WHERE szMap = {1}", { nMultiplier, szMap } )
			else
				if Core.Config.IsSurf then
					Prepare( "INSERT INTO game_map VALUES ({0}, {1}, 1, 0, NULL, 0, NULL, NULL)", { szMap, nMultiplier } )
				else
					Prepare( "INSERT INTO game_map VALUES ({0}, {1}, 0, 0, NULL, 0, NULL, NULL)", { szMap, nMultiplier } )
				end
			end
		end )
		
		-- Reload all maps
		Core.LoadRecords()
		Core.AddMaplistVersion()
		
		-- Reload the ranks
		for _,p in pairs( player.GetHumans() ) do
			p:LoadRank( nil, true )
		end
		
		Core.Print( ply, "Admin", Core.Text( "AdminSetValue", "Multiplier", nMultiplier .. " (You should reload the map now to avoid invalid ranks)" ) )
		Admin.AddLog( "Changed map multiplier on " .. szMap .. " from " .. nOld .. " to " .. nMultiplier, ply.UID, ply:Name() )
	elseif ID == 4 then
		local nID = tonumber( Value )
		if not nID then
			if string.find( Value, ":", 1, true ) then
				local split = string.Explode( ":", Value )
				local zid, emid = tonumber( split[ 1 ] ), tonumber( split[ 2 ] )
				if not zid then
					return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
				end
				
				local zt
				for _,zone in pairs( Core.GetZoneEntities() ) do
					if IsValid( zone ) and zone:EntIndex() == zid then
						zt = { zone.zonetype, zone.truetype, zone.basemin or zone.min, zone.basemax or zone.max }
						break
					end
				end
				
				if zt then
					local editor = Core.GetZoneEditor()
					local nid = emid and zt[ 1 ] + editor.EmbeddedOffsets[ zt[ 1 ] ] + emid or zt[ 1 ]
					sql.Query( "UPDATE game_zones SET nType = " .. nid .. " WHERE szMap = '" .. game.GetMap() .. "' AND nType = " .. zt[ 2 ] .. " AND vPos1 = '" .. util.TypeToString( zt[ 3 ] ) .. "' AND vPos2 = '" .. util.TypeToString( zt[ 4 ] ) .. "'" )
					Admin.AddLog( "Changed embedded id of " .. editor.Embedded[ zt[ 1 ] ] .. " (" .. zid .. ") to " .. (emid or "blank") .. " on " .. game.GetMap(), ply.UID, ply:Name() )
					
					Core.ReloadZones()
					Core.Print( ply, "Admin", Core.Text( "AdminOperationComplete" ) )
				else
					Core.Print( ply, "Admin", Core.Text( "AdminZoneFindFailed" ) )
				end
				
				return
			else
				ply.AdminZoneID = nil
				return Core.Print( ply, "Admin", Core.Text( "AdminEmbeddedReset" ) )
			end
		end
		
		if nID <= 0 then
			return Core.Print( ply, "Admin", Core.Text( "AdminEmbeddedRange" ) )
		end
		
		ply.AdminZoneID = nID
		Core.Print( ply, "Admin", Core.Text( "AdminEmbeddedSet", nID and nID or "1" ) )
	elseif ID == 5 then
		Admin.AddLog( "Changed level to " .. Value, ply.UID, ply:Name() )
		GAMEMODE:UnloadGamemode( "Change" )
		RunConsoleCommand( "changelevel", Value )
	elseif ID == 7 then
		local nValue = tonumber( Value )
		local szSteam = ply.AdminTarget
		local nAccess, szLevel = Admin.Level.None, "Error"
		
		for name,level in pairs( Admin.Level ) do
			if nValue == level then
				szLevel = name
				nAccess = level
				break
			end
		end
		
		if nAccess == Admin.Level.None then
			if ply.ConsoleOperator then
				print( Core.Text( "AdminConsoleParse" ) )
			else
				Core.Print( ply, "Admin", Core.Text( "AdminMisinterpret", szLevel ) )
			end
			
			return false
		end
		
		local function UpdateAdminStatus( bUpdate, sqlArg, adminPly )	
			local function UpdateAdminCallback( data, varArg, szError )
				local targetAdmin, targetData = varArg[ 1 ], varArg[ 2 ]
				
				if data then
					Core.LoadAdminPanel()
					Admin.AddLog( "Updated admin with identifier " .. targetData[ 1 ] .. " to level " .. targetData[ 2 ], targetAdmin.UID, targetAdmin:Name() )
					
					if targetAdmin.ConsoleOperator then
						print( Core.Text( "AdminConsoleAdded" ) )
					else
						Core.Print( targetAdmin, "Admin", Core.Text( "AdminOperationComplete" ) )
					end
				else
					if targetAdmin.ConsoleOperator then
						print( Core.Text( "AdminConsoleError" ) )
					else
						Core.Print( targetAdmin, "Admin", Core.Text( "AdminErrorCode", szError ) )
					end
				end
			end
			
			-- Summary: Adds a new admin whether they exist or not with the specified details
			if bUpdate then
				Prepare(
					"UPDATE game_admins SET nLevel = {0} WHERE nID = {1}",
					{ sqlArg[ 2 ], sqlArg[ 1 ] }
				)( UpdateAdminCallback, { adminPly, sqlArg } )
			else
				Prepare(
					"INSERT INTO game_admins (szSteam, nLevel) VALUES ({0}, {1})",
					{ sqlArg[ 1 ], sqlArg[ 2 ] }
				)( UpdateAdminCallback, { adminPly, sqlArg } )
			end
		end
		
		-- Summary: Checks if the entered Steam ID has any existing admin powers, and see whether we promote or demote him
		Prepare(
			"SELECT nID FROM game_admins WHERE szSteam = {0} ORDER BY nLevel DESC LIMIT 1",
			{ szSteam }
		)( function( data, varArg, szError )
			local adminPly, sqlArg = varArg[ 2 ], varArg[ 3 ]
			local bUpdate = false

			if Core.Assert( data, "nID" ) then
				bUpdate = true
				sqlArg[ 1 ] = data[ 1 ]["nID"]
			end

			local updateFunc = varArg[ 1 ]
			updateFunc( bUpdate, sqlArg, adminPly )
		end, { UpdateAdminStatus, ply, { szSteam, nAccess } } )
	elseif ID == 9 then
		local nIndex, bFind = tonumber( Value ), false
		
		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) and zone:EntIndex() == nIndex then
				ply.ZoneData = { zone.truetype, zone.basemin or zone.min, zone.basemax or zone.max, zone:EntIndex() }
				bFind = true
				break
			end
		end
		
		if not bFind then
			Core.Print( ply, "Admin", Core.Text( "AdminZoneFindFailed" ) )
		else
			local nHeight = math.Round( ply.ZoneData[ 3 ].z - ply.ZoneData[ 2 ].z )
			local tabRequest = Admin.GenerateRequest( "Enter new desired height (Default is 128)\nNote: To change embedded data, add a : in front", "Change height", tostring( nHeight ), 90 )
			Core.Send( ply, "Admin", { "Request", tabRequest } )
		end
	elseif ID == 90 then
		local nValue = tonumber( Value )
		if not nValue then
			if string.sub( Value, 1, 1 ) == ":" then
				return HandleRequest( ply, { nil, 4, ply.ZoneData[ 4 ] .. Value } )
			else
				return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
			end
		end

		local OldPos1 = util.TypeToString( ply.ZoneData[ 2 ] )
		local OldPos2 = util.TypeToString( ply.ZoneData[ 3 ] )
		
		local nMin = ply.ZoneData[ 2 ].z
		ply.ZoneData[ 3 ].z = nMin + nValue
		
		sql.Query( "UPDATE game_zones SET vPos1 = '" .. util.TypeToString( ply.ZoneData[ 2 ] ) .. "', vPos2 = '" .. util.TypeToString( ply.ZoneData[ 3 ] ) .. "' WHERE szMap = '" .. game.GetMap() .. "' AND nType = " .. ply.ZoneData[ 1 ] .. " AND vPos1 = '" .. OldPos1 .. "' AND vPos2 = '" .. OldPos2 .. "'" )
		Admin.AddLog( "Changed zone height of " .. ply.ZoneData[ 1 ] .. " to " .. nValue .. " on " .. game.GetMap(), ply.UID, ply:Name() )
		
		Core.ReloadZones()
		Core.Print( ply, "Admin", Core.Text( "AdminOperationComplete" ) )
	elseif ID == 10 then
		local nIndex, bFind, nType = tonumber( Value ), false, nil
		
		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) and zone:EntIndex() == nIndex then
				sql.Query( "DELETE FROM game_zones WHERE szMap = '" .. game.GetMap() .. "' AND nType = " .. zone.truetype .. " AND vPos1 = '" .. util.TypeToString( zone.basemin or zone.min ) .. "' AND vPos2 = '" .. util.TypeToString( zone.basemax or zone.max ) .. "'" )
				
				nType = zone.zonetype
				bFind = true
				break
			end
		end
		
		if not bFind then
			Core.Print( ply, "Admin", Core.Text( "AdminZoneFindFailed" ) )
		else
			Core.ReloadZones()
			Core.Print( ply, "Admin", Core.Text( "AdminOperationComplete" ) )
			
			Admin.AddLog( "Removed zone of type " .. Core.GetZoneName( nType ) .. " on " .. game.GetMap(), ply.UID, ply:Name() )
		end
	elseif ID == 11 then
		local nValue = tonumber( Value )
		if not nValue then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		end
		
		local opt = Core.GetMapVariable( "Options" )
		if nValue > 0 then
			local has = bit.band( opt, nValue ) > 0
			Core.SetMapVariable( "Options", has and bit.band( opt, bit.bnot( nValue ) ) or bit.bor( opt, nValue ) )
			Core.ReloadMapOptions()
			HandleButton( ply, { -2, ID } )
		else
			local szValue = opt == 0 and "NULL" or opt
			local szMap = game.GetMap()
			local szPrev, bCont = "", true
			
			Prepare(
				"SELECT szMap, nOptions FROM game_map WHERE szMap = {0}",
				{ szMap }
			)( function( data, varArg, szError )
				if Core.Assert( data, "szMap" ) then
					local val = tonumber( data[ 1 ]["nOptions"] )
					if val then
						szPrev = tostring( val )
					end
					
					Prepare( "UPDATE game_map SET nOptions = " .. (szValue == "NULL" and "NULL" or "{1}") .. " WHERE szMap = {0}", { szMap, szValue } )
				else
					bCont = false
					Core.Print( ply, "Admin", Core.Text( "AdminMapOptionsNoEntry" ) )
				end
			end )
			
			if not bCont then return end
			
			Admin.AddLog( "Changed map options of " .. game.GetMap() .. (szPrev != "" and " from " .. szPrev or "") .. " to " .. szValue, ply.UID, ply:Name() )
			Core.Print( ply, "Admin", Core.Text( "AdminSetValue", "Options", szValue ) )
		end
	elseif ID == 17 then
		ply.TimeRemoveData = Value
		local tabRequest = Admin.GenerateRequest( "Are you sure you want to remove " .. Value[ 4 ] .. "'s #" .. Value[ 2 ] .. " time? (Type Yes to confirm)", "Confirm removal", "No", 170 )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 18 then
		local bot = ply.AdminBotTarget
		if Value != "Yes" or not IsValid( bot ) then
			return Core.Print( ply, "Admin", Core.Text( "AdminBotRemoveCancelled" ) )
		end
		
		local info, dels = bot.ActiveInfo, {}
		if ply.AdminBotInfo != info then
			return Core.Print( ply, "Admin", Core.Text( "AdminBotRemoveChanged" ) )
		end
		
		if info.Style != bot.Style and bot.Style >= 1000 and bot.TrueStyle and info.FilePath then
			if file.Exists( info.FilePath, "DATA" ) then
				file.Delete( info.FilePath )
				dels[ #dels + 1 ] = "History file deleted"
				
				local str = info.FilePath
				local index = str:match( "^.*()_" )
				local id = tonumber( string.match( string.sub( str, index + 1, #str ), "%d+" ) ) + 1
				local base = string.sub( str, 1, index ) .. "v"
				
				-- Find all existing files
				while file.Exists( base .. id .. ".txt", "DATA" ) do
					file.Write( base .. (id - 1) .. ".txt", file.Read( base .. id .. ".txt", "DATA" ) )
					file.Delete( base .. id .. ".txt" )
					id = id + 1
				end
			end
		else
			local szStyle = info.Style == Core.Config.Style.Normal and ".txt" or ("_" .. info.Style .. ".txt")
			if file.Exists( Core.Config.BaseType .. "/bots/" .. game.GetMap() .. szStyle, "DATA" ) then
				file.Delete( Core.Config.BaseType .. "/bots/" .. game.GetMap() .. szStyle )
				dels[ #dels + 1 ] = "File deleted"
			end
			
			sql.Query( "DELETE FROM game_bots WHERE szMap = '" .. game.GetMap() .. "' AND nStyle = " .. info.Style .. " AND szSteam = '" .. info.SteamID .. "'" )
			dels[ #dels + 1 ] = "Database entries removed"
		end
		
		ply.AdminBotStyle = bot.Style
		
		Core.ClearBot( bot, bot.Style )
		Core.Print( ply, "Admin", Core.Text( "AdminBotRemoveDone", bot.Style, string.Implode( ", ", dels ) ) )
		Admin.AddLog( "Removed the " .. Core.StyleName( bot.Style ) .. " bot on " .. game.GetMap(), ply.UID, ply:Name() )
	elseif ID == 19 then
		local nFrame = tonumber( Value )
		if not nFrame then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		end
		
		local tabData = Core.GetBotFrame( ply.AdminBotStyle )
		if nFrame >= tabData[ 2 ] then
			nFrame = tabData[ 2 ] - 2
		elseif nFrame < 1 then
			nFrame = 1
		end
		
		local info = Core.GetBotInfo( ply.AdminBotStyle )
		local current = (nFrame / tabData[ 2 ]) * info.Time
		info.Start = SysTime() - current
		
		Core.SetBotFrame( ply.AdminBotStyle, nFrame )
	elseif ID == 21 then
		local nMultiplier = tonumber( Value )
		if not nMultiplier then
			if not string.find( Value, " " ) then
				return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
			else
				if string.find( Value, " " ) then
					local szNums = string.Explode( " ", Value )
					for i = 1, #szNums do
						if string.find( szNums[ i ], ":", 1, true ) then
							local szSplit = string.Explode( ":", szNums[ i ] )
							szNums[ i ] = { tonumber( szSplit[ 2 ] ) }
						else
							szNums[ i ] = tonumber( szNums[ i ] ) or 0
						end
					end
					
					nMultiplier = szNums
				else
					return Core.Print( ply, "Admin", Core.Text( "AdminBonusPointsInfo" ) )
				end
			end
		end

		local nOld, szMap = Core.GetMapVariable( "Bonus" ) or 1, game.GetMap()
		if not tonumber( nMultiplier ) then nMultiplier = Value end
		if type( nOld ) == "table" then nOld = string.Implode( " ", nOld ) end
		
		Core.SetMapVariable( "BonusMultiplier", nMultiplier )
		
		local IsComplete = false
		Prepare(
			"SELECT szMap FROM game_map WHERE szMap = {0}",
			{ szMap }
		)( function( data, varArg, szError )
			if Core.Assert( data, "szMap" ) then
				IsComplete = true
				Prepare( "UPDATE game_map SET nBonusMultiplier = {0} WHERE szMap = {1}", { nMultiplier, szMap } )
			end
		end )

		if IsComplete then
			-- Reload all maps
			Core.LoadRecords()
			Core.AddMaplistVersion()
			
			-- Reload all ranks
			for _,p in pairs( player.GetHumans() ) do
				p:LoadRank( nil, true )
			end
			
			Admin.AddLog( "Changed bonus multiplier on " .. szMap .. " from " .. nOld .. " to " .. nMultiplier, ply.UID, ply:Name() )
			Core.Print( ply, "Admin", Core.Text( "AdminSetValue", "Bonus multiplier", nMultiplier ) )
		else
			return Core.Print( ply, "Admin", Core.Text( "AdminMapBonusNoEntry" ) )
		end
	elseif ID == 22 then
		if not Core.MapCheck( Value ) then
			Core.Print( ply, "Admin", Core.Text( "AdminRemoveUnavailable", Value ) )
		else
			sql.Query( "DELETE FROM game_bots WHERE szMap = '" .. Value .. "'" )
			sql.Query( "DELETE FROM game_map WHERE szMap = '" .. Value .. "'" )
			sql.Query( "DELETE FROM game_times WHERE szMap = '" .. Value .. "'" )
			sql.Query( "DELETE FROM game_zones WHERE szMap = '" .. Value .. "'" )
			
			local files = file.Find( Core.Config.BaseType .. "/bots/" .. Value .. "_*.txt", "DATA" )
			for i = 1, #files do
				file.Delete( Core.Config.BaseType .. "/bots/" .. files[ i ] )
			end
			
			Core.Print( ply, "Admin", Core.Text( "AdminRemoveComplete" ) )
			Admin.AddLog( "Fully removed map " .. Value, ply.UID, ply:Name() )
		end
	elseif ID == 25 then
		local nIndex, bFind = tonumber( Value )
		
		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) and zone:EntIndex() == nIndex then
				bFind = zone
				break
			end
		end
		
		if not IsValid( bFind ) then
			Core.Print( ply, "Admin", Core.Text( "AdminZoneFindFailed" ) )
		else
			if not ply.Practice then
				return Core.Print( ply, "Admin", Core.Text( "AdminTeleportZoneWarning" ) )
			end
			
			ply:SetPos( bFind:GetPos() )
			Core.Print( ply, "Admin", Core.Text( "AdminTeleportZoneComplete" ) )
			Admin.AddLog( "Teleported to zone (" .. bFind.zonetype .. ") on " .. game.GetMap(), ply.UID, ply:Name() )
		end
	elseif ID == 26  then
		local nValue = tonumber( Value )
		if not nValue then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		end
		
		Core.RTVChangeTime( nValue )
		Core.Print( ply, "Admin", Core.Text( "AdminVoteTimeChange" ) )
		Admin.AddLog( "Changed the remaining time to " .. nValue .. " on " .. game.GetMap(), ply.UID, ply:Name() )
		
		ply:RTV( "Left" )
	elseif ID == 28 then
		local nStyle = tonumber( Value )
		if not nStyle then
			return Core.Print( ply, "Admin", Core.Text( "AdminTimeDeletionCancel" ) )
		end
		
		if not Core.IsValidStyle( nStyle ) then
			return Core.Print( ply, "Admin", Core.Text( "MiscInvalidStyle" ) )
		end

		sql.Query( "DELETE FROM game_times WHERE szMap = '" .. game.GetMap() .. "' AND nStyle = " .. nStyle )
		Core.LoadRecords()
		Admin.AddLog( "Deleted all times on " .. Core.StyleName( nStyle ) .. " for " .. game.GetMap(), ply.UID, ply:Name() )
		
		for _,p in pairs( player.GetHumans() ) do
			if IsValid( p ) then
				p:LoadTime( true )
				break
			end
		end
	elseif ID == 29 then
		if Value == "" then
			return Core.Print( ply, "Admin", Core.Text( "AdminNotificationEmpty" ) )
		end
		
		ply.AdminTarget = nil
		
		if string.find( Value, "-", 1, true ) then
			local split = string.Explode( "-", Value )
			local target = Admin.FindPlayer( split[ 1 ] )
			if IsValid( target ) then
				ply.AdminTarget = target
				Value = split[ 2 ]
			end
		end
		
		local tab = { "Admin", Value, "shield", 10, (ply.AdminTarget and "Private" or "Global") .. " message from " .. ply:Name() .. " -> " .. Value }
		if IsValid( ply.AdminTarget ) then
			Core.Prepare( "Notify", tab ):Send( ply.AdminTarget )
		else
			Core.Prepare( "Notify", tab ):Broadcast()
		end
		
		Admin.AddLog( "Sent admin message " .. Value, ply.UID, ply:Name() )
		ply.AdminTarget = nil
	elseif ID == 30 then
		local target = Admin.FindPlayer( Value )
		if not IsValid( target ) then
			local str = string.gsub( Value, ", ", "" )
			local vec = util.StringToType( str, "Vector" )
			if vec != Vector( 0, 0, 0 ) then
				target = { IsValid = function() return true end, GetPos = function( s ) return s.Pos end, Name = function( s ) return tostring( s.Pos ) end, Pos = vec }
			end
		end
		
		if IsValid( target ) then
			local source = Admin.FindPlayer( ply.AdminTarget )
			if not IsValid( source ) then
				return Core.Print( ply, "Admin", Core.Text( "AdminTeleportMissingSource" ) )
			end
			
			source:SetPos( target:GetPos() )
			Core.Print( ply, "Admin", Core.Text( "AdminTeleportComplete", source:Name(), target:Name() ) )
			Admin.AddLog( "Teleported " .. source:Name() .. " to " .. target:Name(), ply.UID, ply:Name() )
		else
			Core.Print( ply, "Admin", Core.Text( "AdminNoValidPlayer", Value ) )
		end
	elseif ID == 31 then
		local nIndex, bFind = tonumber( Value )
		
		local zones = Core.GetZoneEntities()
		for _,zone in pairs( zones ) do
			if IsValid( zone ) and zone:EntIndex() == nIndex then
				bFind = zone
				break
			end
		end
		
		if not IsValid( bFind ) then
			Core.Print( ply, "Admin", Core.Text( "AdminZoneFindFailed" ) )
		else
			ply.AdminTargetZone = { bFind.basemin or bFind.min, bFind.basemax or bFind.max, { bFind.basemin or bFind.min, bFind.basemax or bFind.max, bFind.truetype } }
			Core.Print( ply, "Admin", Core.Text( "AdminZoneMoveInfo" ) )
			
			hook.Add( "KeyPress", "AdminMove_KP", function( ply, key )
				local pdata = ply.AdminTargetZone
				if not pdata then return end
				
				local move = Vector( 0, 0, 0 )
				if key == IN_USE then move = Vector( 1, 0, 0 )
				elseif key == IN_RELOAD then move = Vector( -1, 0, 0 )
				elseif key == IN_DUCK then move = Vector( 0, 1, 0 )
				elseif key == IN_JUMP then move = Vector( 0, -1, 0 )
				elseif key == IN_ATTACK then move = Vector( 0, 0, 1 )
				elseif key == IN_ATTACK2 then move = Vector( 0, 0, -1 )
				elseif key == IN_SCORE then
					ply.AdminTargetZone = nil
					hook.Remove( "KeyPress", "AdminMove_KP" )
					
					Core.Print( ply, "Admin", Core.Text( "AdminZoneMoveEnd" ) )
					Core.ReloadZones()
				elseif key == IN_SPEED then
					sql.Query( "UPDATE game_zones SET vPos1 = '" .. util.TypeToString( pdata[ 1 ] ) .. "', vPos2 = '" .. util.TypeToString( pdata[ 2 ] ) .. "' WHERE szMap = '" .. game.GetMap() .. "' AND nType = " .. pdata[ 3 ][ 3 ] .. " AND vPos1 = '" .. util.TypeToString( pdata[ 3 ][ 1 ] ) .. "' AND vPos2 = '" .. util.TypeToString( pdata[ 3 ][ 2 ] ) .. "'" )
					Admin.AddLog( "Completed free-move of zone (" .. pdata[ 3 ][ 3 ] .. ") on " .. game.GetMap(), ply.UID, ply:Name() )
					
					ply.AdminTargetZone = nil
					hook.Remove( "KeyPress", "AdminMove_KP" )
					
					Core.Print( ply, "Admin", Core.Text( "AdminZoneMoveComplete" ) )
					Core.ReloadZones()
				else return end
				
				local zone = nil
				local zones = Core.GetZoneEntities()
				for _,z in pairs( zones ) do
					if pdata[ 1 ] == (z.basemin or z.min) and pdata[ 2 ] == (z.basemax or z.max) then
						zone = z
						break
					end
				end
				
				if not IsValid( zone ) then return end
				
				local cache = Core.GetZoneEntities( true )
				for _,data in pairs( cache ) do
					if data.vPos1 == (zone.basemin or zone.min) and data.vPos2 == (zone.basemax or zone.max) then
						data.vPos1 = data.vPos1 + move
						data.vPos2 = data.vPos2 + move
						
						ply.AdminTargetZone = { data.vPos1, data.vPos2, pdata[ 3 ] }
						
						break
					end
				end
				
				Core.GetZoneEntities( true, cache )
				Core.ReloadZones( true )
			end )
		end
	elseif ID == 33 then
		local tabRequest = Admin.GenerateRequest( "Enter new desired value\n(Linear: 0, Staged: 1 - Tier: Num 1 - 6):", "Change value", "", 70 )
		ply.AdminTarget = tonumber( Value )
		Core.Send( ply, "Admin", { "Request", tabRequest } )
	elseif ID == 34 then
		local target = Admin.FindPlayer( Value )
		
		if IsValid( target ) then
			return Core.Print( ply, "Admin", Core.Text( "AdminFullWipeOnline" ) )
		end
		
		Prepare(
			"SELECT * FROM game_bots WHERE szSteam = {0}",
			{ Value }
		)( function( data, varArg, szError )
			if Core.Assert( data, "szMap" ) then
				local makeNum = tonumber
				for j = 1, #data do
					local style = makeNum( data[ j ]["nStyle"] )
					local name = Core.Config.BaseType .. "/bots/" .. data[ j ]["szMap"]
					if style != Core.Config.Style.Normal then
						name = name .. "_" .. style
					end
					
					if file.Exists( name .. ".txt", "DATA" ) then
						file.Delete( name .. ".txt" )
					end
				end
			end
		end )
		
		Prepare( "DELETE FROM game_bots WHERE szSteam = {0}", { Value } )
		Prepare( "DELETE FROM game_notifications WHERE szUID = {0}", { Value } )
		Prepare( "DELETE FROM game_racers WHERE szUID = {0}", { Value } )
		Prepare( "DELETE FROM game_stagetimes WHERE szUID = {0}", { Value } )
		Prepare( "DELETE FROM game_tas WHERE szUID = {0}", { Value } )
		Prepare( "DELETE FROM game_times WHERE szUID = {0}", { Value } )
		
		Core.Print( ply, "Admin", Core.Text( "AdminFullWipeComplete" ) )
		Admin.AddLog( "Fully wiped " .. Value, ply.UID, ply:Name() )
	elseif ID == 35 then
		local style = tonumber( Value )
		if not style or not Core.IsValidStyle( style ) then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		end
		
		local root, runs = Core.Config.BaseType .. "/bots/revisions/", {}
		local gets = file.Find( root .. game.GetMap() .. "_*.txt", "DATA" )
		
		for i = 1, #gets do
			local fh = file.Open( root .. gets[ i ], "r", "DATA" )
			if not fh then continue end
			
			local data = fh:Read( 1024 )
			local newline = string.find( data, "\n", 1, true )
			if newline then
				local json = string.sub( data, 1, newline - 1 )
				local dec = util.JSONToTable( json )
				
				if dec and dec.Style and dec.Style == style then
					dec.BinaryOffset = newline
					dec.FilePath = root .. gets[ i ]
					runs[ #runs + 1 ] = dec
				end
			end
			
			fh:Close()
		end
		
		table.SortByMember( runs, "Time", true )
		
		local styles, details = {}, {}
		for i = 1, #runs do
			styles[ i ] = runs[ i ].Date
			details[ i ] = runs[ i ]
		end
		
		ply.BotChangeData = details
		ply.FinalizeBotChange = function( s, id )
			local data = s.BotChangeData
			local target = data[ id ]
			if not target then return end
			
			Core.HandleSpecialBot( s, "Import", target.Style, target )
			Admin.AddLog( "Changed active bot for " .. Core.StyleName( target.Style ) .. " on " .. game.GetMap(), s.UID, s:Name() )
			
			s.BotChangeData = nil
			s.FinalizeBotChange = nil
		end
		
		Core.Send( ply, "GUI/Create", { ID = "Bot", Dimension = { x = 400, y = 370 }, Args = { Title = "Multi Bots", Mouse = true, Blur = true, Custom = { styles, details, { 0 }, "This is the list of all bot revisions recorded on the given style.\nLeft click for more info, right click for selection\nAll applicable runs:" } } } )
	elseif ID == 60 then
		local Type = tonumber( Value )	
		local item = Admin.ReportDetails[ Type ]
		
		ply.AdminReport = nil
		ply.ReportEntity = nil
		
		if item then
			local gent
			if Type == 1 or Type == 7 then
				local list = ents.FindInSphere( ply:GetPos(), 10 )
				for _,e in pairs( list ) do
					if e:GetClass() == "game_timer" then
						gent = e
						break
					end
				end
				
				if not gent then
					return Core.Print( ply, "Admin", Core.Text( "AdminReportZoneInside" ) )
				else
					ply.ReportEntity = gent
				end
			end
			
			ply.AdminReport = Type
			
			local tabRequest = Admin.GenerateRequest( item[ 1 ], item[ 2 ], ply.LastAdminMessage or item[ 3 ], 61 )
			tabRequest.Special = true
			ply.LastAdminMessage = nil
			
			Core.Send( ply, "Admin", { "Request", tabRequest } )
		else
			Core.Print( ply, "Admin", Core.Text( "AdminReportCommunity" ) )
		end
	elseif ID == 61 then
		local Type = ply.AdminReport
		if not Type or not tonumber( Type ) then
			return Core.Print( ply, "Admin", Core.Text( "AdminReportInvalid" ) )
		end
		
		local l = string.len( Value )
		if l > 256 then
			ply.LastAdminMessage = Value
			return Core.Print( ply, "Admin", Core.Text( "AdminReportLength" ) )
		end
		
		if (Admin.ReportDetails[ Type ] and Admin.ReportDetails[ Type ][ 3 ]) == Value then
			return Core.Print( ply, "Admin", Core.Text( "AdminReportDefault", Admin.ReportDetails[ Type ][ 3 ] ) )
		end

		local low = string.lower( Value )
		if string.find( low, "insert into", 1, true ) or string.find( low, "game_", 1, true ) or string.find( low, "drop table", 1, true ) then
			return Core.Print( ply, "Admin", Core.Text( "AdminReportMalicious" ) )
		end
		
		local zone = (IsValid( ply.ReportEntity ) and ply.ReportEntity.truetype) or -1
		if zone >= 0 then
			Value = Value .. " [Zone (" .. zone .. ") " .. tostring( ply.ReportEntity:GetPos() ) .. "]"
		end
		
		if (Type >= 1 and Type <= 4) or Type == 7 or Type == 10 then
			Value = Value .. " (Map " .. game.GetMap() .. ")"
		end
		
		ply.ReportEntity = nil
		ply.LastAdminReport = SysTime()
		
		Core.ReportPlayer( {
			Submitter = ply,
			ReporterSteam = ply.UID,
			Text = Core.Text( "AdminReportNotify", ply:Name() ),
			TypeID = Type,
			Comment = Value
		} )
	elseif ID == 70 then
		local szType = ply.AdminTarget == 1 and "nTier" or "nType"
		local szNormal = string.sub( szType, 2 )
		
		local nValue = tonumber( Value )
		if not nValue then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		end
		
		if szType == "nType" and nValue != 1 and nValue != 0 then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		elseif szType == "nTier" and nValue < 1 or nValue > 7 then
			return Core.Print( ply, "Admin", Core.Text( "AdminInvalidFormat", Value, "Number" ) )
		end

		local nOld, szMap = Core.GetMapVariable( szNormal ) or (szType == "nTier" and 1 or 0), game.GetMap()
		Core.SetMapVariable( szNormal, nValue )

		local IsComplete = false
		Prepare(
			"SELECT szMap FROM game_map WHERE szMap = {0}",
			{ szMap }
		)( function( data, varArg, szError )
			if Core.Assert( data, "szMap" ) then
				IsComplete = true
				Prepare( "UPDATE game_map SET " .. szType .. " = {0} WHERE szMap = {1}", { nValue, szMap } )
			end
		end )
		
		if not IsComplete then
			return Core.Print( ply, "Admin", Core.Text( "AdminMapTierNoEntry", string.lower( szNormal ) ) )
		else
			Core.LoadRecords()
			Core.AddMaplistVersion()
			
			Admin.AddLog( "Changed map " .. string.lower( szNormal ) .. " on " .. szMap .. " from " .. nOld .. " to " .. nValue, ply.UID, ply:Name() )
			Core.Print( ply, "Admin", Core.Text( "AdminSetValue", szNormal, nValue ) )
		end
	end
end

local function AdminHandleClient( ply, varArgs )
	local nID = tonumber( varArgs[ 1 ] )
	if nID == -1 then
		HandleRequest( ply, varArgs )
	elseif nID == -2 then
		HandleButton( ply, varArgs )
	else
		print( "Invalid admin request by", ply, varArgs[ 1 ] )
	end
end
Core.Register( "Global/Admin", AdminHandleClient )

function Admin.CommandProcess( ply, args )
	if not Admin.CanAccess( ply, Admin.Level.Zoner ) or args.Key == "report" then
		if ply.LastAdminReport and SysTime() - ply.LastAdminReport < 600 then
			return Core.Print( ply, "Admin", Core.Text( "AdminReportFrequency" ) )
		end
		
		Admin.CreateReport( ply )
	else
		if #args == 0 then
			Admin.CreateWindow( ply )
		else
			local szID, nAccess = args[ 1 ], Admin.GetAccess( ply )
			if szID == "spectator" and nAccess >= Admin.Level.Moderator then
				if not args[ 2 ] then return Core.Print( ply, "Admin", Core.Text( "AdminCommandArgument", szID ) ) end
				HandleButton( ply, { -2, 12, args.Upper[ 2 ] } )
			elseif szID == "strip" and nAccess >= Admin.Level.Moderator then
				if not args[ 2 ] then return Core.Print( ply, "Admin", Core.Text( "AdminCommandArgument", szID ) ) end
				HandleButton( ply, { -2, 23, args.Upper[ 2 ] } )
			elseif szID == "zone" and nAccess >= Admin.Level.Super then
				HandleButton( ply, { -2, 1 } )
			else
				Core.Print( ply, "Admin", Core.Text( "AdminCommandInvalid", args.Key ) )
			end
		end
	end
end
Core.AddCmd( { "admin", "report" }, Admin.CommandProcess )