Bot = {}
Bot.Count = 2
Bot.RecordingMultiplier = 1.5
Bot.AverageStart = 150
Bot.StartFrames = 200
Bot.HistoryID = 1000
Bot.BaseID = { TAS = 50, Stage = 100 }
Bot.Benchmark = false

-- Bot playback helpers
local BotPlayer = {}
local BotFrame = {}
local BotFrames = {}
local BotInfo = {}
local BotForceRuns = {}

-- Bot playback content tables
local BotOriginX, BotOriginY, BotOriginZ = {}, {}, {}
local BotAngleP, BotAngleY = {}, {}
local BotButtons = {}

-- Bot playback access tables
local BotPosition = {}
local BotAngle = {}

-- Player recording helpers
local Frame = {}
local Active = {}

-- Player recording tables
local OriginX, OriginY, OriginZ = {}, {}, {}
local AngleP, AngleY = {}, {}
local Buttons = {}

-- Localized items
local CleanTable, Styles = Core.CleanTable, Core.Config.Style
local st, vON = SysTime, von
local BotType = { Main = 1, Multi = 2 }
local BasePath = Core.Config.BaseType .. "/bots/"
local PLAYER = FindMetaTable( "Player" )

--[[
	Description: Bot initialization
	Notes: Checking for a deeper directory still creates all previous folders
--]]
function Core.EnableBots()
	if not file.Exists( BasePath .. "revisions", "DATA" ) then
		file.CreateDir( BasePath .. "revisions" )
	end
	
	Bot.PerStyle = {}
	Bot.Load()
end

--[[
	Description: Loads data from the database and uses that to load data from the stored text files
--]]
function Bot.Load()
	local Result = sql.Query( "SELECT * FROM game_bots WHERE szMap = '" .. game.GetMap() .. "' ORDER BY nStyle ASC" )
	if Core.Assert( Result, "nTime" ) then
		for _,Info in pairs( Result ) do
			local name = BasePath .. game.GetMap()
			local style = tonumber( Info["nStyle"] )
			local botstart = tonumber( Core.Null( Info["nStartFrame"], Bot.AverageStart ) ) or Bot.AverageStart
			
			-- For different styles, add an underscore
			if style != Styles.Normal then
				name = name .. "_" .. style
			end
			
			-- Check if we have a valid files
			print(name .. ".txt")
			if not file.Exists( name .. ".txt", "DATA" ) then continue end
			print("yes")

			-- Read our content
			local Start = SysTime()
			local BinaryData = file.Read( name .. ".txt", "DATA" )

			if Bot.Benchmark then
				Check = st()
				print( "Time taken to read all binary data", Check - Start )
				Start = st()
			end
			
			-- Deserialize the data
			local Merged = vON.deserialize( BinaryData )
			BotOriginX[ style ] = Merged[ 1 ]
			BotOriginY[ style ] = Merged[ 2 ]
			BotOriginZ[ style ] = Merged[ 3 ]
			BotAngleP[ style ] = Merged[ 4 ]
			BotAngleY[ style ] = Merged[ 5 ]
			BotButtons[ style ] = Merged[ 6 ]
			
			if Bot.Benchmark then
				Check = st()
				print( "Time taken to deserialize and assign tables", Check - Start )
				Start = st()
			end
			
			BotFrames[ style ] = #BotOriginX[ style ]
			BotInfo[ style ] = { Name = Info["szPlayer"], Time = tonumber( Info["nTime"] ), Style = style, SteamID = Info["szSteam"], Date = Info["szDate"], StartFrame = botstart, Saved = true, Start = st(), CompletedRun = true }
		end
	end
end

--[[
	Description: Saves all bots (instant or not)
--]]
function Core.SaveBots( bInstant, szRequestee )
	-- By default we're not going to save
	local count = 0
	
	-- Check if there are normal bots that aren't yet saved
	for _,info in pairs( BotInfo ) do
		if not info.Saved then
			count = count + 1
		end
	end
	
	-- Check if there's any history bots to be saved
	for _,info in pairs( BotForceRuns ) do
		count = count + 1
	end
	
	-- If there's players online, we'll drop them a message
	if count == 0 then return end
	if not bInstant and #player.GetHumans() > 0 then
		timer.Simple( 1, function() Core.SaveBots( true, szRequestee ) end )
		return Core.Print( nil, "General", Core.Text( "BotSaving", count, count != 1 and "s" or "", szRequestee and "as requested by " .. szRequestee or "prepare for some lag!" ) )
	end
	
	local Fulltime, Fullcount = st(), 0
	for style,info in pairs( BotInfo ) do
		if not info.Saved then
			if not BotOriginX[ style ] or not BotFrames[ style ] or BotFrames[ style ] < 2 then continue end
			if style >= Bot.HistoryID then continue end
			
			local Exist = sql.Query( "SELECT * FROM game_bots WHERE szMap = '" .. game.GetMap() .. "' AND nStyle = " .. info.Style )
			if Core.Assert( Exist, "nTime" ) and tonumber( Exist[ 1 ]["nTime"] ) then
				sql.Query( "UPDATE game_bots SET szPlayer = " .. sql.SQLStr( info.Name ) .. ", nTime = " .. info.Time .. ", nStartFrame = " .. info.StartFrame .. ", szSteam = '" .. info.SteamID .. "', szDate = '" .. info.Date .. "' WHERE szMap = '" .. game.GetMap() .. "' AND nStyle = " .. info.Style )
			else
				sql.Query( "INSERT INTO game_bots VALUES ('" .. game.GetMap() .. "', " .. sql.SQLStr( info.Name ) .. ", " .. info.Time .. ", " .. info.Style .. ", " .. info.StartFrame .. ", '" .. info.SteamID .. "', '" .. info.Date .. "')" )
			end
			
			local name = BasePath .. game.GetMap()
			if style != Styles.Normal then
				name = name .. "_" .. style
			end
			
			if file.Exists( name .. ".txt", "DATA" ) then
				local id = 1
				local fp = string.gsub( name, "bots/", "bots/revisions/" ) .. "_v"
				
				while file.Exists( fp .. id .. ".txt", "DATA" ) do
					id = id + 1
				end
				
				local rinfo = { Date = "Unknown", Name = "Unknown", SteamID = "Unknown", Style = 0, Time = 0, Saved = true, Start = 0, StartFrame = Bot.AverageStart }
				if Exist and Exist[ 1 ] and Exist[ 1 ]["szSteam"] then
					local ed = Exist[ 1 ]
					rinfo = {}
					rinfo.Date = ed.szDate
					rinfo.Name = ed.szPlayer
					rinfo.SteamID = ed.szSteam
					rinfo.Style = tonumber( ed.nStyle ) or 1
					rinfo.Time = tonumber( ed.nTime ) or 1
					rinfo.Saved = true
					rinfo.Start = st()
					rinfo.StartFrame = tonumber( ed.nStartFrame ) or Bot.AverageStart
				end
				
				local existing = file.Read( name .. ".txt", "DATA" )
				file.Write( fp .. id .. ".txt", util.TableToJSON( rinfo ) .. "\n" )
				file.Append( fp .. id .. ".txt", existing )
			end
			
			-- Create a new table with data
			local Merged = {}
			Merged[ 1 ] = BotOriginX[ style ]
			Merged[ 2 ] = BotOriginY[ style ]
			Merged[ 3 ] = BotOriginZ[ style ]
			Merged[ 4 ] = BotAngleP[ style ]
			Merged[ 5 ] = BotAngleY[ style ]
			Merged[ 6 ] = BotButtons[ style ]
			
			-- Do the REAL intensive work now
			local Start, Check = st()
			local BinaryData = vON.serialize( Merged )
			
			if Bot.Benchmark then
				Check = st()
				print( "Time taken for vON serialization", Check - Start )
				Start = st()
			end
			
			-- Create new files
			local fn = name .. ".txt"
			if file.Exists( fn, "DATA" ) then
				file.Delete( fn )
			end
			
			-- Write this massive chunk of data
			file.Write( fn, BinaryData )
			
			if Bot.Benchmark then
				Check = st()
				print( "Time taken for writing data to file", Check - Start )
				Start = st()
			end
			
			-- Make sure it doesn't save twice
			BotInfo[ style ].Saved = true
			Fullcount = Fullcount + 1
		end
	end
	
	for index,info in pairs( BotForceRuns ) do
		local style = info.Style
		local name = BasePath .. game.GetMap()
		
		if style != Styles.Normal then
			name = name .. "_" .. style
		end
		
		local id = 1
		local fp = string.gsub( name, "bots/", "bots/revisions/" ) .. "_v"
		
		while file.Exists( fp .. id .. ".txt", "DATA" ) do
			id = id + 1
		end
		
		-- Copy over the important details
		local Merged = info.Data
		info.Data = nil
		info.Saved = true
		info.Start = st()
		
		-- Do the REAL intensive work now
		local Start, Check = st()
		local BinaryData = vON.serialize( Merged )
		
		if Bot.Benchmark then
			Check = st()
			print( "Time taken for vON serialization", Check - Start )
			Start = st()
		end
		
		-- Create new files
		file.Write( fp .. id .. ".txt", util.TableToJSON( info ) .. "\n" )
		file.Append( fp .. id .. ".txt", BinaryData )
		
		if Bot.Benchmark then
			Check = st()
			print( "Time taken for writing data to file", Check - Start )
			Start = st()
		end
		
		-- Remove the entry
		BotForceRuns[ index ] = nil
		Fullcount = Fullcount + 1
	end
	
	if Fullcount > 0 then
		local szCount = Fullcount > 1 and "All " .. Fullcount or Fullcount
		local szRun = Fullcount > 1 and "runs have" or "run has"
		Core.Print( nil, "General", Core.Text( "BotSaved", szCount, szRun, Core.ConvertTime( st() - Fulltime ) ) )
	end
end


-- Player part

--[[
	Description: Ends a bot run and saves it if appropriate
--]]
function PLAYER:EndBotRun( nTime, nID )
	if not IsValid( self ) then return false end
	
	-- Security checks
	if not Frame[ self ] or not OriginX[ self ] then return false end
	if Frame[ self ] < 2 or #OriginX[ self ] < 2 then return false end
	if (not self.Tn and not self.Tb) or (not self.TnF and not self.TbF) then return false end
	
	-- Check if we're good with overwriting the existing bot or no
	local style = self.Style
	if BotInfo[ style ] and BotInfo[ style ].Time and nTime >= BotInfo[ style ].Time then
		-- Only show the message if we're talking about a top 10 finish
		if nID <= 10 then
			Core.Print( self, "Timer", Core.Text( "BotSlow", Core.ConvertTime( nTime - BotInfo[ style ].Time ) ) )
		end
		
		return false
	end
	
	-- Set the tables directly and give the player new table addresses
	BotOriginX[ style ] = OriginX[ self ]
	BotOriginY[ style ] = OriginY[ self ]
	BotOriginZ[ style ] = OriginZ[ self ]
	BotAngleP[ style ] = AngleP[ self ]
	BotAngleY[ style ] = AngleY[ self ]
	BotButtons[ style ] = Buttons[ self ]

	-- Assign the new tables
	OriginX[ self ] = {}
	OriginY[ self ] = {}
	OriginZ[ self ] = {}
	AngleP[ self ] = {}
	AngleY[ self ] = {}
	Buttons[ self ] = {}
	
	BotFrames[ style ] = #BotOriginX[ style ]
	BotInfo[ style ] = { Name = self:Name(), Time = nTime, Style = style, SteamID = self.UID, Date = os.date( "%Y-%m-%d %H:%M:%S", os.time() ), StartFrame = self.BotFrameStart, Saved = false, Start = st() }
	
	-- Change the bot display
	Bot.SetMultiBot( style )
	
	-- Pre-expand and clean up
	self:CleanFrames()
	
	return true
end

--[[
	Description: Setup the bot tables
	Used by: Player connection
--]]
function PLAYER:BotAdd( force )
	-- Since this only gets called once every now and then, check if the bots are present
	Bot.CheckStatus()

	local count = #player.GetHumans()
	if count < Core.Config.BusyTime or force then
		-- Initialize the tables once
		OriginX[ self ] = {}
		OriginY[ self ] = {}
		OriginZ[ self ] = {}
		AngleP[ self ] = {}
		AngleY[ self ] = {}
		Buttons[ self ] = {}
		
		-- Let them know we're good
		return true
	end
end

--[[
	Description: Change if recording is active on the player
--]]
function PLAYER:SetBotActive( value )
	if not OriginX[ self ] then
		Active[ self ] = nil
		return false
	end
	
	Active[ self ] = value
end

--[[
	Description: Gets the current frame the player is at
--]]
function PLAYER:GetCurrentFrame( bypass )
	if not Active[ self ] and not bypass then return 0 end
	return Frame[ self ] or 0
end

--[[
	Description: Checks whether or not the player has been dequeued
--]]
function PLAYER:IsPlayerDequeued()
	return not OriginX[ self ] and not Active[ self ], not not OriginX[ self ], Active[ self ]
end

--[[
	Description: Clean all stored frame data on the player
--]]
function PLAYER:CleanFrames( bRemove )
	if not OriginX[ self ] then return end

	-- Clean all tables
	CleanTable( OriginX[ self ] )
	CleanTable( OriginY[ self ] )
	CleanTable( OriginZ[ self ] )
	CleanTable( AngleP[ self ] )
	CleanTable( AngleY[ self ] )
	CleanTable( Buttons[ self ] )

	-- Reset the frame to the beginning
	Frame[ self ] = 1
	
	-- Remove if we need to
	if bRemove then
		self:SetBotActive( nil )
	end
end

--[[
	Description: Chop! Chop! This removes the excessive starting bit of the run
	Notes: This is what allows recording in the start zone. It's more intense on the server, but way cooler
--]]
function PLAYER:ChopFrames( bStart )
	if not OriginX[ self ] then return end
	if not Frame[ self ] then return end
	
	-- See if chops are appropriate
	local FrameDifference = Frame[ self ] - Bot.StartFrames
	if FrameDifference >= 0 then
		-- Move the end to the begin of the array
		for i = 1, Bot.StartFrames do
			OriginX[ self ][ i ] = OriginX[ self ][ FrameDifference + i ]
			OriginY[ self ][ i ] = OriginY[ self ][ FrameDifference + i ]
			OriginZ[ self ][ i ] = OriginZ[ self ][ FrameDifference + i ]
			AngleP[ self ][ i ] = AngleP[ self ][ FrameDifference + i ]
			AngleY[ self ][ i ] = AngleY[ self ][ FrameDifference + i ]
			Buttons[ self ][ i ] = Buttons[ self ][ FrameDifference + i ]
		end
		
		-- And wipe the remaining parts of the array
		for i = Bot.StartFrames + 1, #OriginX[ self ] do
			OriginX[ self ][ i ] = nil
			OriginY[ self ][ i ] = nil
			OriginZ[ self ][ i ] = nil
			AngleP[ self ][ i ] = nil
			AngleY[ self ][ i ] = nil
			Buttons[ self ][ i ] = nil
		end
		
		-- Finally set the frame to where we chopped
		Frame[ self ] = Bot.StartFrames
	end
	
	-- If we're starting, save the frame on the player
	if bStart then
		self.BotFrameStart = Frame[ self ]
	end
end

-- More bot functions

--[[
	Description: Clears out ALL data we have on a bot
--]]
function Core.ClearBot( bot, nStyle )
	BotFrame[ nStyle ] = nil
	BotFrames[ nStyle ] = nil
	BotInfo[ nStyle ] = nil
	
	CleanTable( BotOriginX[ nStyle ] )
	CleanTable( BotOriginY[ nStyle ] )
	CleanTable( BotOriginZ[ nStyle ] )
	CleanTable( BotAngleP[ nStyle ] )
	CleanTable( BotAngleY[ nStyle ] )
	CleanTable( BotButtons[ nStyle ] )
	
	CleanTable( BotPosition[ nStyle ] )
	CleanTable( BotAngle[ nStyle ] )
	
	-- If we have a bot just turn it into an idle bot
	if IsValid( bot ) then
		if not BotPlayer[ bot ] then return end
		
		BotPlayer[ bot ] = nil
		Bot.SetInfo( bot, nStyle )
		
		bot:ResetSpawnPosition()
	end
end

--[[
	Description: Prepares all vectors for bot playback
--]]
local CreateVec, CreateAng = Vector, Angle
function Bot.PrepareVectors( ply, style )
	if not BotOriginX[ style ] then return end
	BotPosition[ ply ] = {}
	BotAngle[ ply ] = {}
	
	for i = 1, #BotOriginX[ style ] do
		BotPosition[ ply ][ i ] = CreateVec( BotOriginX[ style ][ i ], BotOriginY[ style ][ i ], BotOriginZ[ style ][ i ] )
		BotAngle[ ply ][ i ] = CreateAng( BotAngleP[ style ][ i ], BotAngleY[ style ][ i ], 0 )
	end
end

--[[
	Description: Spawns a bot and sets the details on them
--]]
function Bot.Spawn( tab )
	-- Loop over the bots
	for _,bot in pairs( player.GetBots() ) do
		if bot.Temporary then
			bot.Temporary = nil
			bot:SetMoveType( 0 )
			bot:SetCollisionGroup( 1 )
			
			bot.BotType = tab.Type
			bot:StripWeapons()
			bot:SetFOV( 90, 0 )
			bot:SetGravity( 0 )
			
			return Bot.SetInfo( bot, tab.Style )
		end
	end
	
	-- If we don't have enough bots yet, spawn an extra one
	if #player.GetBots() < 2 then
		RunConsoleCommand( "bot" )
		
		timer.Simple( 1, function()
			Bot.Spawn( tab )
		end )
	end
end

--[[
	Description: Checks the status of the bots
	Used by: Internally to check if all bots are still there
--]]
function Bot.CheckStatus()
	if Bot.IsStatusCheck then
		return true
	else
		Bot.IsStatusCheck = true
	end
	
	local nCount = 0
	local bNormal, bMulti
	
	-- Get the count and check which types are alive
	for _,bot in pairs( player.GetBots() ) do
		nCount = nCount + 1
		
		if not bot.BotType then
			continue
		elseif bot.BotType == BotType.Main then
			bNormal = true
		elseif bot.BotType == BotType.Multi then
			bMulti = true
		end
	end
	
	-- Check if there's even a need to spawn another bot
	if nCount < 2 then
		if not bNormal then
			Bot.Spawn( { Type = BotType.Main, Style = Styles.Normal } )
		end
		
		if not bMulti then
			local nStyle = 0
			for style,_ in pairs( BotOriginX ) do
				if style != Styles.Normal then
					nStyle = style
					break
				end
			end
			
			timer.Simple( not bNormal and 2 or 0, function()
				Bot.Spawn( { Type = BotType.Multi, Style = nStyle } )
			end )
		end
	end
	
	timer.Simple( 5, function()
		Bot.IsStatusCheck = nil
	end )
end

--[[
	Description: Gets the Player of a bot
--]]
function Bot.GetPlayer( nStyle, szType )
	for _,ply in pairs( player.GetBots() ) do
		if szType then
			if ply.BotType and ply.BotType == BotType[ szType ] then
				return ply
			end
		else
			if (nStyle == Styles.Normal and ply.BotType == BotType.Main) or (nStyle != Styles.Normal and ply.BotType == BotType.Multi) then
				return ply
			end
		end
	end
end
Core.GetBot = Bot.GetPlayer

--[[
	Description: Changes the multi bot to another style
--]]
function Bot.SetMultiBot( nStyle )
	local ply = Bot.GetPlayer( nStyle )
	if not IsValid( ply ) then return end
	
	Bot.SetInfo( ply, nStyle )
end

--[[
	Description: Gets the style of the multi bot
--]]
function Core.GetMultiBotDetail()
	for _,ply in pairs( player.GetBots() ) do
		if ply.BotType == BotType.Multi then
			local style = ply.Style
			return { style >= Bot.HistoryID and ply.TrueStyle or style, BotInfo[ style ] and BotInfo[ style ].SteamID, BotInfo[ style ] and BotInfo[ style ].Time }
		end
	end
	
	return { 0 }
end

--[[
	Description: Get details about the multi bots
	Used by: Commands (mbot)
--]]
function Core.GetMultiBots( bDetail )
	local tab, detail = {}, {}
	local useful = { ["Name"] = true, ["Time"] = true, ["Style"] = true, ["SteamID"] = true, ["Date"] = true }
	
	for style,data in pairs( BotInfo ) do
		if style >= Bot.HistoryID then continue end
		
		local id = #tab + 1
		tab[ id ] = Core.StyleName( style )
		
		if bDetail then
			detail[ id ] = table.Copy( data )
			
			for k,v in pairs( detail[ id ] ) do
				if not useful[ k ] then
					detail[ id ][ k ] = nil
				end
			end
		end
	end
	
	return tab, detail
end

--[[
	Description: Change the multi bot to another style
--]]
function Core.ChangeMultiBot( nStyle )
	local ply = Bot.GetPlayer( nil, "Multi" )
	if not IsValid( ply ) then return "None" end
	if not Core.IsValidStyle( nStyle ) or nStyle >= Bot.HistoryID then return "Invalid" end
	if nStyle == Styles.Normal then return "Exclude" end
	if ply.Style == nStyle then return "Same" end
	
	if BotInfo[ nStyle ] and BotOriginX[ nStyle ] then
		if not BotInfo[ ply.Style ] or BotInfo[ ply.Style ].CompletedRun or (BotInfo[ ply.Style ].Start and st() - BotInfo[ ply.Style ].Start > 60) then
			Bot.SetInfo( ply, nStyle )
			
			return Core.Text( "BotChangeMultiDone", BotInfo[ nStyle ].Name, Core.StyleName( BotInfo[ nStyle ].Style ), Core.ConvertTime( BotInfo[ nStyle ].Time ) )
		else
			return "Wait"
		end
	else
		return "Error"
	end
end

--[[
	Description: Try to save the bots if necessary (bots owned by the calling player)
	Used by: Command (bot save)
--]]
function Core.TryBotSave( ply )
	local bSave, szSteam, szType = false, ply.UID, "BotAllSaved"
	
	-- Loop over normal bots
	for style,data in pairs( BotInfo ) do
		if not data.Saved and data.SteamID == szSteam then
			bSave = true
			break
		end
	end
	
	-- Check additional bots
	for _,data in pairs( BotForceRuns ) do
		if data.SteamID == szSteam then
			szType = "BotSaveForced"
			break
		end
	end
	
	-- Let them know what we did
	if not bSave then
		Core.Print( ply, "General", Core.Text( szType ) )
	else
		Core.SaveBots( nil, ply:Name() )
	end
end

--[[
	Description: Tries to save a bot at the given moment
--]]
function Core.ForceBotSave( ply, bSelf )
	-- Security checks
	if not Frame[ ply ] or not OriginX[ ply ] or Active[ ply ] or #OriginX[ ply ] < 2 then return Core.Print( ply, "Timer", Core.Text( "BotAdditionalNotEligible", "Please make sure you are recorded properly." ) ) end
	
	-- Check bonus validity
	local style, bonus = ply.Style
	if Core.IsValidBonus( style ) then
		if not ply.Tb or not ply.TbF then return Core.Print( ply, "Timer", Core.Text( "BotAdditionalNotEligible", "Make sure you are recorded and at the end of the map with a stopped timer." ) ) end
		
		bonus = true
	else
		if not ply.Tn or not ply.TnF then return Core.Print( ply, "Timer", Core.Text( "BotAdditionalNotEligible", "Make sure you are recorded and at the end of the map with a stopped timer." ) ) end
	end
	
	-- Check saved data
	local tab = ply.LastObtainedFinish
	if not tab then return Core.Print( ply, "Timer", Core.Text( "BotAdditionalNotEligible", "You have to stand in the end zone after improving your time." ) ) end
	
	local nTime = tab[ 1 ]
	local nStyle = tab[ 2 ]
	local nFinish = tab[ 3 ]
	local nFrame = tab[ 4 ]
	
	-- Check if all is valid
	local t, tf = (bonus and ply.Tb or ply.Tn) or 0, (bonus and ply.TbF or ply.TnF) or 0
	if nTime != ply.Record or nTime != tf - t or nStyle != style or nFinish != tf then
		return Core.Print( ply, "Timer", Core.Text( "BotAdditionalInvalid" ) )
	end
	
	-- Check if we're good with the time
	if not BotInfo[ style ] or not BotInfo[ style ].Time then
		return Core.Print( ply, "Timer", Core.Text( "BotAdditionalNoTimes" ) )
	end
	
	-- Additional check
	if nTime <= BotInfo[ style ].Time or nTime > BotInfo[ style ].Time * Bot.RecordingMultiplier then
		return Core.Print( ply, "Timer", Core.Text( "BotAdditionalTimeLimited", Core.ConvertTime( BotInfo[ style ].Time * Bot.RecordingMultiplier ) ) )
	end
	
	-- Continue with saving
	return Core.HandleSpecialBot( ply, "Force", nTime, { Style = style, Frame = nFrame, Self = bSelf } )
end


-- Access functions

--[[
	Description: Sets the bot # record
--]]
function Core.SetBotRecord( nStyle, nID )
	local p = Bot.PerStyle[ nStyle ] or 0
	if p > 0 and nID <= p then
		Bot.SetWRPosition( nStyle )
	end
end

--[[
	Description: Checks if a given bot exists
--]]
function Core.BotExists( nStyle )
	return BotFrame[ nStyle ] and BotFrames[ nStyle ] and BotInfo[ nStyle ] and BotInfo[ nStyle ].Start
end

--[[
	Description: Calls a restart notification on the bot
--]]
function Bot.NotifyRestart( nStyle )
	local ply = Bot.GetPlayer( nStyle )
	local info = BotInfo[ nStyle ]
	local bEmpty = false
	
	if IsValid( ply ) and not info then
		bEmpty = true
	elseif not IsValid( ply ) or not info then
		return false
	end
	
	local tab, watchers = { true, nil, "Idle bot", nil, true }, {}
	for _,p in pairs( player.GetHumans() ) do
		if not p.Spectating then continue end
		local ob = p:GetObserverTarget()
		if IsValid( ob ) and ob:IsBot() and ob == ply then
			table.insert( watchers, p )
		end
	end

	if not bEmpty then
		tab[ 2 ] = Core.GetBotTime( nStyle )
		tab[ 3 ] = info.Name
		tab[ 4 ] = info.Time
	end
	
	Core.Prepare( "Spectate/Timer", tab ):Send( watchers )
end
Core.NotifyBotRestart = Bot.NotifyRestart

--[[
	Description: Generates a notification table for the bot
--]]
function Core.GenerateBotNotify( ply, nStyle, varList )
	local info = BotInfo[ nStyle ]
	if not info then return end
	return { true, Core.GetBotTime( nStyle ), info.Name, info.Time, varList }
end

--[[
	Description: Function used to automatically start demo recording on bots
	Used by: Commands
--]]
function Bot.AutomaticDemoNotify( bot )
	for _,p in pairs( player.GetHumans() ) do
		if p.DemoTarget == bot then
			if p.DemoStarted then
				p.DemoStarted = nil
				p.DemoTarget = nil
				Core.Send( p, "Client/AutoDemo" )
				Core.Print( p, "General", Core.Text( "CommandBotDemoEnded" ) )
			else
				local info = BotInfo[ bot.Style ]
				if not info then return end
				
				local formattime = string.format( "_%.2d_%.2d_%.3d", math.floor( info.Time / 60 % 60 ), math.floor( info.Time % 60 ), math.floor( info.Time * 1000 % 1000 ) )
				local name = info.Name:gsub( "%W", "" ):lower()
				
				p.DemoStarted = true
				Core.Send( p, "Client/AutoDemo", { name .. formattime } )
			end
		end
	end
end

--[[
	Description: Sets the info on a bot and publishes that data
--]]
function Bot.SetInfo( ply, nStyle, nPublish )
	-- Set the style
	ply.ActiveInfo = nil
	ply.TrueStyle = nil
	ply.Style = nStyle
	
	-- If we don't have any data, set the bot to be idle
	local info = BotInfo[ nStyle ]
	if not info then
		ply:SetObj( "BotName", "" )
		ply:SetObj( "Style", 0 )
		return ply:PublishObj()
	end
	
	-- Set the info table on the bot for convenience
	ply.ActiveInfo = BotInfo[ nStyle ]
	
	-- We have bots!
	Bot.Initialized = true
	Bot.PrepareVectors( ply, nStyle )
	
	-- And set the bot details
	BotFrame[ nStyle ] = 1
	BotPlayer[ ply ] = nStyle
	
	-- Set defaults
	BotInfo[ nStyle ].Start = st()
	BotInfo[ nStyle ].CompletedRun = nil
	
	-- If we've got data to set
	if info.Time then
		ply:SetObj( "BotName", info.Name )
		ply:SetObj( "ProfileURI", util.SteamIDTo64( info.SteamID ) )
		ply:SetObj( "RunDate", string.Explode( " ", info.Date )[ 1 ] )
		ply:SetObj( "Record", info.Time )
		ply:SetObj( "Style", info.Style )
		ply:SetObj( "TrueStyle", nPublish )
		
		local pos = Core.GetRecordID( info.Time, info.Style )
		ply:SetObj( "WRPos", pos > 0 and pos or 0 )
		ply:PublishObj()
		
		Bot.PerStyle[ info.Style ] = pos
	end
	
	-- Notify a restart on the bot
	Bot.NotifyRestart( nStyle )
end

--[[
	Description: Sets the WR position of the bot and publishes it
--]]
function Bot.SetWRPosition( nStyle )
	local ply = Bot.GetPlayer( nStyle )
	if not IsValid( ply ) then return end
	
	local info = BotInfo[ nStyle ]
	if not info then
		ply:SetObj( "BotName", "" )
		ply:SetObj( "Style", 0 )
		return ply:PublishObj()
	end
	
	if info.Time then
		local pos = Core.GetRecordID( info.Time, info.Style )
		ply:SetObj( "WRPos", pos > 0 and pos or 0 )
		ply:PublishObj( "WRPos" )
		
		Bot.PerStyle[ info.Style ] = pos
	end
end

--[[
	Description: Changes playback frame of the bot
	Used by: Admin panel
--]]
function Core.SetBotFrame( nStyle, nFrame, szType )
	local ply = Bot.GetPlayer( not szType and nStyle, szType )
	if IsValid( ply ) then
		local style = nStyle or ply.Style
		if not BotFrame[ style ] then return end
		
		if nFrame < 0 then
			nFrame = BotFrames[ style ] - 100
		end
		
		if nFrame < BotFrames[ style ] then
			BotFrame[ style ] = nFrame
		end
		
		Bot.NotifyRestart( style )
	end
end

--[[
	Description: Gets the playback frame and the total frames of a bot
	Used by: Admin panel
--]]
function Core.GetBotFrame( nStyle )
	if IsValid( Bot.GetPlayer( nStyle ) ) and BotFrame[ nStyle ] and BotFrames[ nStyle ] then
		return { BotFrame[ nStyle ], BotFrames[ nStyle ] }
	end
	
	return { 0, 0 }
end

--[[
	Description: Gets the time of the bot using the playback frame and total frames
	Used by: Spectating
--]]
function Core.GetBotTime( nStyle )
	if IsValid( Bot.GetPlayer( nStyle ) ) and BotFrame[ nStyle ] and BotFrames[ nStyle ] and BotFrames[ nStyle ] > 1 and BotInfo[ nStyle ] and BotInfo[ nStyle ].Time and BotInfo[ nStyle ].Start and BotInfo[ nStyle ].StartFrame then
		if BotInfo[ nStyle ].BotCooldown then return -10002 end
		
		local outframe = BotFrame[ nStyle ] - BotInfo[ nStyle ].StartFrame
		return (outframe / BotFrames[ nStyle ]) * BotInfo[ nStyle ].Time
	end
	
	return -10001
end

--[[
	Description: Get the bot info remotely
--]]
function Core.GetBotInfo( nStyle )
	return BotInfo[ nStyle ]
end

--[[
	Description: Checks if the time is a stoppable time, or whether we keep on recording
--]]
function Bot.IsStoppableTime( ply, nLimit )
	local nTime
	
	if Core.IsValidBonus( ply.Style ) then
		if ply.Tb and not ply.TbF then
			nTime = st() - ply.Tb
		end
	else
		if ply.Tn and not ply.TnF then
			nTime = st() - ply.Tn
		end
	end
	
	if nTime then
		return nTime > nLimit * Bot.RecordingMultiplier
	end
end

--[[
	Description: Gets older bot runs
--]]
function Core.LoadBotHistory( nStyle )
	-- Set the base name
	local name = BasePath .. game.GetMap()
	if nStyle != Styles.Normal then
		name = name .. "_" .. nStyle
	end
	
	-- Create the ids
	local id, ids = 1, {}
	local fp = string.gsub( name, "bots/", "bots/revisions/" ) .. "_v"
	
	-- Find all existing files
	while file.Exists( fp .. id .. ".txt", "DATA" ) do
		ids[ id ] = fp .. id .. ".txt"
		id = id + 1
	end
	
	-- Open all files and read json data
	local runs, forces = {}, {}
	for i = 1, #ids do
		local fh = file.Open( ids[ i ], "r", "DATA" )
		if not fh then continue end
		
		local data = fh:Read( 1024 )
		local newline = string.find( data, "\n", 1, true )
		if newline then
			local json = string.sub( data, 1, newline - 1 )
			local dec = util.JSONToTable( json )
			
			if dec and dec.Style == nStyle then
				dec.BinaryOffset = newline
				dec.FilePath = ids[ i ]
				runs[ #runs + 1 ] = dec
			end
		end
		
		fh:Close()
	end
	
	-- Check forced runs
	for id,data in pairs( BotForceRuns ) do
		if data.Style == nStyle then
			forces[ #forces + 1 ] = { id, data }
		end
	end
	
	-- Sort by time
	table.SortByMember( runs, "Time", true )
	
	return runs, forces
end

--[[
	Description: Changes the multi bot to an older run
--]]
function Core.ChangeHistoryBot( ply, nStyle, data )
	ply.BotHistoryData = nil
	
	local bot = Bot.GetPlayer( nil, "Multi" )
	if not IsValid( bot ) then return Core.Send( ply, "GUI/UpdateBot", { 3, false, Core.Text( "BotNoValidBots" ) } ) end
	if not Core.IsValidStyle( nStyle ) then return Core.Send( ply, "GUI/UpdateBot", { 3, false, Core.Text( "BotInvalidStyle" ) } ) end
	
	local current = bot.Style
	if BotInfo[ current ] and (BotInfo[ current ].CompletedRun or (BotInfo[ current ].Start and st() - BotInfo[ current ].Start > 60)) then
		-- Make sure the fictional style is valid
		local style = Bot.HistoryID
		Core.SetStyle( style, "History" )
		
		if not data.ItemID then		
			-- Double check the file
			if not file.Exists( data.FilePath, "DATA" ) then return end

			-- Load data from the file
			local fh = file.Open( data.FilePath, "r", "DATA" )
			if not fh then return end
			
			-- Check if it's a different run
			if BotInfo[ current ].Style == data.Style and BotInfo[ current ].SteamID == data.SteamID and BotInfo[ current ].Time == data.Time then
				return Core.Send( ply, "GUI/UpdateBot", { 3, false, Core.Text( "BotDisplaySameRun" ) } )
			end
			
			-- Set pointer
			local remain = fh:Size() - data.BinaryOffset
			fh:Seek( data.BinaryOffset )
			
			-- Reset certain fields
			data.BinaryOffset = nil
			data.CompletedRun = nil
			data.Start = st()
			data.StartFrame = data.StartFrame or Bot.AverageStart
			data.Saved = true
			
			-- Read data
			local Merged = vON.deserialize( fh:Read( remain ) )
			BotOriginX[ style ] = Merged[ 1 ]
			BotOriginY[ style ] = Merged[ 2 ]
			BotOriginZ[ style ] = Merged[ 3 ]
			BotAngleP[ style ] = Merged[ 4 ]
			BotAngleY[ style ] = Merged[ 5 ]
			BotButtons[ style ] = Merged[ 6 ]
			
			BotFrames[ style ] = #BotOriginX[ style ]
			BotInfo[ style ] = data
			
			-- Set data on the bot itself
			Bot.SetInfo( bot, style, style )
			bot.TrueStyle = nStyle
			
			Core.Send( ply, "GUI/UpdateBot", { 3, true, Core.Text( "BotChangeMultiDone", data.Name, Core.StyleName( data.Style ), Core.ConvertTime( data.Time ) ) } )
			
			-- Close the file handle
			fh:Close()
		else
			-- Switch up the contents
			data = BotForceRuns[ data.ItemID ]
			
			-- Check if it's a different run
			if BotInfo[ current ].Style == data.Style and BotInfo[ current ].SteamID == data.SteamID and BotInfo[ current ].Time == data.Time then
				return Core.Send( ply, "GUI/UpdateBot", { 3, false, Core.Text( "BotDisplaySameRun" ) } )
			end
			
			-- Set certain fields
			data.Start = st()
			data.StartFrame = data.StartFrame or Bot.AverageStart
			data.Saved = true
			
			-- Set the bot data
			local Merged = data.Data
			BotOriginX[ style ] = Merged[ 1 ]
			BotOriginY[ style ] = Merged[ 2 ]
			BotOriginZ[ style ] = Merged[ 3 ]
			BotAngleP[ style ] = Merged[ 4 ]
			BotAngleY[ style ] = Merged[ 5 ]
			BotButtons[ style ] = Merged[ 6 ]
			
			BotFrames[ style ] = #BotOriginX[ style ]
			BotInfo[ style ] = data
			
			-- Set data on the bot itself
			Bot.SetInfo( bot, style )
			bot.TrueStyle = nStyle
			
			Core.Send( ply, "GUI/UpdateBot", { 3, true, Core.Text( "BotChangeMultiDone", data.Name, Core.StyleName( data.Style ), Core.ConvertTime( data.Time ) ) } )
		end
	else
		Core.Send( ply, "GUI/UpdateBot", { 3, false, Core.Text( "BotChangeMultiPlayback" ) } )
	end
end

--[[
	Description: Handles any extension related data
--]]
function Core.HandleSpecialBot( ply, szType, nTime, data )
	if szType == "TAS" then
		-- Base style ID
		local style = Bot.BaseID.TAS + ply.Style
		
		-- Cancel out if it's invalid
		if #data[ 1 ] < 2 then return end
		
		-- Set the tables directly
		BotOriginX[ style ] = data[ 1 ]
		BotOriginY[ style ] = data[ 2 ]
		BotOriginZ[ style ] = data[ 3 ]
		BotAngleP[ style ] = data[ 4 ]
		BotAngleY[ style ] = data[ 5 ]
		BotButtons[ style ] = data[ 6 ]
		
		BotFrames[ style ] = #BotOriginX[ style ]
		BotInfo[ style ] = { Name = ply:Name(), Time = nTime, Style = style, SteamID = ply.UID, Date = os.date( "%Y-%m-%d %H:%M:%S", os.time() ), StartFrame = 1, Saved = false, Start = st() }
		
		local bot = Bot.GetPlayer( nil, "Multi" )
		if IsValid( bot ) and bot.Style == style then
			Bot.SetInfo( bot, style )
		end
	elseif szType == "Stage" then
		if not data[ 3 ] then return end
		
		-- Base style ID
		local cstyle = ply.Style
		local wstyle = Bot.BaseID.Stage + data[ 3 ]
		local finish = data[ 4 ]
		
		-- Check if we really just set a bot
		if finish then
			if BotInfo[ cstyle ] and BotInfo[ cstyle ].SteamID == ply.UID and BotInfo[ cstyle ].Start and st() - BotInfo[ cstyle ].Start < 5 then
				data[ 2 ] = #BotOriginX[ cstyle ]
			else
				finish = nil
			end
		end
		
		-- Set new data containers
		local ox, oy, oz = {}, {}, {}
		local ap, ay = {}, {}
		local bt = {}
		
		-- Read containers
		local rox, roy, roz = finish and BotOriginX[ cstyle ] or OriginX[ ply ], finish and BotOriginY[ cstyle ] or OriginY[ ply ], finish and BotOriginZ[ cstyle ] or OriginZ[ ply ]
		local rap, ray = finish and BotAngleP[ cstyle ] or AngleP[ ply ], finish and BotAngleY[ cstyle ] or AngleY[ ply ]
		local rbt = finish and BotButtons[ cstyle ] or Buttons[ ply ]
		
		-- Validate arrays and indices
		if not rox or #rox == 0 then return end
		if data[ 2 ] - 1 == #rox then data[ 2 ] = #rox end		
		if data[ 1 ] < 1 or data[ 2 ] > #rox then return end
		
		-- Iterate over the table and copy each frame
		local j = 1
		for i = data[ 1 ], data[ 2 ] do
			ox[ j ] = rox[ i ]
			oy[ j ] = roy[ i ]
			oz[ j ] = roz[ i ]
			ap[ j ] = rap[ i ]
			ay[ j ] = ray[ i ]
			bt[ j ] = rbt[ i ]
			
			j = j + 1
		end
		
		-- Cancel out if it's invalid
		if #ox < 2 then return end
		
		-- Set the tables directly
		BotOriginX[ wstyle ] = ox
		BotOriginY[ wstyle ] = oy
		BotOriginZ[ wstyle ] = oz
		BotAngleP[ wstyle ] = ap
		BotAngleY[ wstyle ] = ay
		BotButtons[ wstyle ] = bt
		
		BotFrames[ wstyle ] = #BotOriginX[ wstyle ]
		BotInfo[ wstyle ] = { Name = ply:Name(), Time = nTime, Style = wstyle, SteamID = ply.UID, Date = os.date( "%Y-%m-%d %H:%M:%S", os.time() ), StartFrame = 1, Saved = false, Start = st() }
		
		local bot = Bot.GetPlayer( nil, "Multi" )
		if IsValid( bot ) and bot.Style == wstyle then
			Bot.SetInfo( bot, wstyle )
		end
		
		return true
	elseif szType == "Force" then
		local tab = {}
		tab[ 1 ] = OriginX[ ply ]
		tab[ 2 ] = OriginY[ ply ]
		tab[ 3 ] = OriginZ[ ply ]
		tab[ 4 ] = AngleP[ ply ]
		tab[ 5 ] = AngleY[ ply ]
		tab[ 6 ] = Buttons[ ply ]
		
		OriginX[ ply ] = {}
		OriginY[ ply ] = {}
		OriginZ[ ply ] = {}
		AngleP[ ply ] = {}
		AngleY[ ply ] = {}
		Buttons[ ply ] = {}
		
		BotForceRuns[ #BotForceRuns + 1 ] = { Name = ply:Name(), Time = nTime, Style = data.Style, SteamID = ply.UID, Date = os.date( "%Y-%m-%d %H:%M:%S", os.time() ), StartFrame = data.Frame or Bot.AverageStart, Data = tab }
		
		if data.Self then
			Core.Print( ply, "General", Core.Text( "CommandBotForceSaved" ) )
		end
		
		return true
	elseif szType == "Import" then
		local style = nTime
		if BotInfo[ style ] then
			return Core.Print( ply, "General", Core.Text( "BotImportOverride" ) )
		end
		
		-- Double check the file
		local output = BasePath .. game.GetMap() .. (style != Styles.Normal and "_" .. style or "") .. ".txt"
		if not file.Exists( data.FilePath, "DATA" ) then
			return Core.Print( ply, "General", Core.Text( "BotImportFiles" ) )
		end
		
		-- Load data from the file
		local fh = file.Open( data.FilePath, "r", "DATA" )
		if not fh then return end
		
		-- Set pointer
		local remain = fh:Size() - data.BinaryOffset
		fh:Seek( data.BinaryOffset )
		
		-- Reset certain fields
		data.BinaryOffset = nil
		data.CompletedRun = nil
		data.Start = st()
		data.StartFrame = data.StartFrame or Bot.AverageStart
		data.Saved = true
		
		-- Read the data		
		local binary = fh:Read( remain )
		file.Write( output, binary )
		
		-- Close the file handle
		fh:Close()
		file.Delete( data.FilePath )
		
		local str = data.FilePath
		local index = str:match( "^.*()_" )
		local id = tonumber( string.match( string.sub( str, index + 1, #str ), "%d+" ) ) + 1
		local base = string.sub( str, 1, index ) .. "v"
		
		-- Find all existing files
		while file.Exists( base .. id .. ".txt", "DATA" ) do
			file.Write( base .. (id - 1) .. ".txt", file.Read( base .. id .. ".txt", "DATA" ) )
			file.Delete( base .. id .. ".txt" )
			id = id + 1
		end
		
		-- Deserialize
		local Merged = vON.deserialize( binary )
		BotOriginX[ style ] = Merged[ 1 ]
		BotOriginY[ style ] = Merged[ 2 ]
		BotOriginZ[ style ] = Merged[ 3 ]
		BotAngleP[ style ] = Merged[ 4 ]
		BotAngleY[ style ] = Merged[ 5 ]
		BotButtons[ style ] = Merged[ 6 ]
		
		BotFrames[ style ] = #BotOriginX[ style ]
		BotInfo[ style ] = data

		-- Set data on the bot itself
		local bot = Bot.GetPlayer( nil, style == Styles.Normal and "Main" or "Multi" )
		if IsValid( bot ) then
			Bot.SetInfo( bot, style )
		end
		
		-- Finally write all data
		sql.Query( "INSERT OR REPLACE INTO game_bots (szMap, szPlayer, nTime, nStyle, nStartFrame, szSteam, szDate) VALUES ('" .. game.GetMap() .. "', " .. sql.SQLStr( data.Name ) .. ", " .. data.Time .. ", " .. data.Style .. ", " .. data.StartFrame .. ", '" .. data.SteamID .. "', '" .. data.Date .. "')" )
		
		-- And notify the player
		Core.Print( ply, "General", Core.Text( "BotImportSucceeded" ) )
	elseif szType == "Fetch" then
		return BotOriginX[ data ], BotOriginY[ data ], BotOriginZ[ data ], BotAngleP[ data ], BotAngleY[ data ], BotInfo[ data ]
	end
end


-- Main control

--[[
	Description: Actually records the players and plays back the bot
--]]
local function BotRecord( ply, data )
	if Active[ ply ] then
		local origin = data:GetOrigin()
		local eyes = data:GetAngles()
		local frame = Frame[ ply ]
		
		OriginX[ ply ][ frame ] = origin.x
		OriginY[ ply ][ frame ] = origin.y
		OriginZ[ ply ][ frame ] = origin.z
		AngleP[ ply ][ frame ] = eyes.p
		AngleY[ ply ][ frame ] = eyes.y
		
		Frame[ ply ] = frame + 1
	elseif BotPlayer[ ply ] then
		local style = BotPlayer[ ply ]
		local frame = BotFrame[ style ]
		
		if frame >= BotFrames[ style ] then
			if not BotInfo[ style ].BotCooldown then
				BotInfo[ style ].BotCooldown = st()
				BotInfo[ style ].Start = nil
				Bot.NotifyRestart( style )
			end
			
			local nDifference = st() - BotInfo[ style ].BotCooldown
			if nDifference >= 2 then
				BotFrame[ style ] = 1
				BotInfo[ style ].BotCooldown = nil
				BotInfo[ style ].Start = st()
				BotInfo[ style ].CompletedRun = true
				
				Bot.NotifyRestart( style )
				Bot.AutomaticDemoNotify( ply )
			elseif nDifference >= 0 then
				frame = BotFrames[ style ]
			end
			
			data:SetOrigin( BotPosition[ ply ][ frame ] )
			ply:SetEyeAngles( BotAngle[ ply ][ frame ] )
		else
			data:SetOrigin( BotPosition[ ply ][ frame ] )
			ply:SetEyeAngles( BotAngle[ ply ][ frame ] )
			
			BotFrame[ style ] = frame + 1
		end
	end
end
hook.Add( "SetupMove", "PositionRecord", BotRecord )

--[[
	Description: Records player keys and sets them on the bot
--]]
local function BotButtonRecord( ply, data )
	if Active[ ply ] then
		Buttons[ ply ][ Frame[ ply ] ] = data:GetButtons()
	elseif BotPlayer[ ply ] then
		data:ClearButtons()
		data:ClearMovement()
		
		local style = BotPlayer[ ply ]
		local frame = BotFrame[ style ]
		if BotButtons[ style ][ frame ] then
			data:SetButtons( BotButtons[ style ][ frame ] )
		end
	end
end
hook.Add( "StartCommand", "ButtonRecord", BotButtonRecord )

--[[
	Description: Ticks to check bot details and player progress
--]]
local function ControlBotPlayers()
	for ply,_ in pairs( BotPlayer ) do
		if IsValid( ply ) then
			if ply:GetMoveType() != 0 then ply:SetMoveType( 0 ) end
			if ply:GetCollisionGroup() != 1 then ply:SetCollisionGroup( 1 ) end
			if ply:GetFOV() != 90 then ply:SetFOV( 90, 0 ) end
		end
	end
	
	local humans = player.GetHumans()
	if #player.GetBots() != Bot.Count and #humans > 0 then
		Bot.EmptyTick = (Bot.EmptyTick or 0) + 1
		
		if Bot.EmptyTick > 2 then
			Bot.EmptyTick = nil
			Bot.CheckStatus()
		end
	end
	
	for i = 1, #humans do
		local p = humans[ i ]
		if not Active[ p ] then continue end
		
		if p.InSpawn then
			if p:GetCurrentFrame() > 500 then
				p:ChopFrames()
			end
		else
			if BotInfo[ p.Style ] and BotInfo[ p.Style ].Time and Bot.IsStoppableTime( p, BotInfo[ p.Style ].Time ) and Active[ p ] then
				p:CleanFrames()
				p:SetBotActive( nil )
			end
		end
	end
end
timer.Create( "BotController", 5, 0, ControlBotPlayers )