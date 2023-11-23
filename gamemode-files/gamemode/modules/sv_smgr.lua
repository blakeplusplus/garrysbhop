local SMgrAPI = {}
SMgrAPI.Debugging = false
SMgrAPI.DefaultDetail = 1
SMgrAPI.ViewDetail = 7
SMgrAPI.MaxDetail = 12
SMgrAPI.AcceptableLimit = 5000

-- Get the PLAYER meta table
local PLAYER, ValidStyles = FindMetaTable( "Player" ), {}

-- All data collection tables
local Monitored = {}
local MonitorAngle = {}
local MonitorLast = {}
local MonitorLastS = {}
local MonitorSimple = {}
local MonitorSet = {}

local SyncTotal = {}
local SyncAlignA = {}
local SyncAlignB = {}
local SyncStrafes = {}


--[[
	Description: Sets the standard validity tables
--]]
function SMgrAPI.Init()
	-- Reset the table
	ValidStyles = {}
	
	-- Loop over all styles with 3 or 4 as ranking style (Normal + Bonus)
	for at,t in pairs( Core.Config.RankColumns ) do
		if t != 5 then
			ValidStyles[ at ] = true
		end
	end
end
Core.InitializeSMgrAPI = SMgrAPI.Init


--[[
	Description: Enables stats monitoring
	Used by: Player initialization
--]]
function PLAYER:SetStrafeStats()
	Monitored[ self ] = true
	MonitorAngle[ self ] = self:EyeAngles().y
	SyncTotal[ self ] = 0
	SyncAlignA[ self ] = 0
	SyncAlignB[ self ] = 0
	SyncStrafes[ self ] = 0
end

--[[
	Description: Clears out the saved data for the player
	Used by: Player disconnection
--]]
function PLAYER:ClearStrafeStats()
	Monitored[ self ] = nil
	MonitorAngle[ self ] = nil
	SyncTotal[ self ] = nil
	SyncAlignA[ self ] = nil
	SyncAlignB[ self ] = nil
	SyncStrafes[ self ] = nil
end

--[[
	Description: Changes displaying state
	Used by: Command
--]]
function PLAYER:ToggleSyncState( bForce, bUnspec )
	if bUnspec then
		if MonitorSet[ self ] != not not self.SyncDisplay then
			self.SyncDisplay = MonitorSet[ self ]
		end
		
		return false
	end
	
	if bForce == nil then
		if not self.SyncDisplay then
			self.SyncDisplay = ""
		else
			self.SyncDisplay = nil
		end
		
		MonitorSet[ self ] = not not self.SyncDisplay
		
		Core.Print( self, "General", Core.Text( "PlayerSyncStatus", self.SyncDisplay and "now" or "no longer" ) )
	else
		if bForce then
			self.SyncDisplay = ""
		else
			self.SyncDisplay = nil
		end
		
		MonitorSet[ self ] = not not self.SyncDisplay
	end
end

--[[
	Description: Gets the sync value in readable format
--]]
function PLAYER:GetSync( bFull )
	-- Only send something when we're on a valid style
	if ValidStyles[ self.Style ] then
		if bFull then
			return SyncAlignA[ self ], SyncAlignB[ self ], SyncTotal[ self ]
		else
			return SMgrAPI:GetSync( self, SMgrAPI.DefaultDetail )
		end
	else
		return 0.0
	end
end

--[[
	Description: Sets the sync value on a player
	Used by: Pause and restore commands
--]]
function PLAYER:SetSync( a, b, t )
	SyncAlignA[ self ], SyncAlignB[ self ], SyncTotal[ self ] = a, b, t
end

--[[
	Description: Gets the amount of strafes on a player
--]]
function PLAYER:GetStrafes()
	return SyncStrafes[ self ] or 0
end

--[[
	Description: Sets the amount of strafes on a player
	Used by: Pause and restore commands
--]]
function PLAYER:SetStrafes( n )
	SyncStrafes[ self ] = n
end


--[[
	Description: Local rounding function to fix the .0 decimal disappearing
--]]
function SMgrAPI.Round( value, deci )
	return string.format( "%." .. deci .. "f", value )
end

--[[
	Description: Internally get the sync with a lot of decimals
--]]
function SMgrAPI:GetSync( ply, nRound )
	if SyncTotal[ ply ] == 0 then
		return 0.0
	end
	
	return self.Round( (SyncAlignA[ ply ] / SyncTotal[ ply ]) * 100.0, nRound or self.DefaultDetail )
end

--[[
	Description: Get the other sync value
--]]
function SMgrAPI:GetSyncEx( ply, nRound )
	if SyncTotal[ ply ] == 0 then
		return 0.0
	end

	return self.Round( (SyncAlignB[ ply ] / SyncTotal[ ply ]) * 100.0, nRound or self.DefaultDetail )
end

--[[
	Description: Get data for the Simple HUD
--]]
function SMgrAPI:GetSimple( ply )
	return self:GetSyncEx( ply, SMgrAPI.DefaultDetail ), ply:GetStrafes(), ply:GetJumps()
end

--[[
	Description: Get the amount of frames we're calculating over
--]]
function SMgrAPI:GetFrames( ply )
	return SyncTotal[ ply ] or 0
end

--[[
	Description: See if our measurement is valid
--]]
function SMgrAPI:IsRealistic( ply )
	return self:GetFrames( ply ) > self.AcceptableLimit
end

--[[
	Description: Returns whether or not the player is using a config
	Notes: This is actually somewhat accurate
--]]
function SMgrAPI:HasConfig( ply, bString )
	local SyncA, SyncB = self:GetSync( ply, self.MaxDetail ), self:GetSyncEx( ply, self.MaxDetail )
	return (SyncA == SyncB and SyncA + SyncB > 0 and self:IsRealistic( ply )) and (bString and "Yes" or true) or (bString and "No" or false)
end

--[[
	Description: Returns a value of whether it's possible the player hacks
	Notes: This is actually no longer reliable, except for the SyncA - SyncB method
--]]
function SMgrAPI:HasHack( ply, bString )
	local SyncA, SyncB = self:GetSync( ply, self.MaxDetail ), self:GetSyncEx( ply, self.MaxDetail )
	if (SyncA > 99 or SyncB > 99) and math.abs( SyncA - SyncB ) > 70 and self:IsRealistic( ply ) then
		return (bString and "Yes" or true)
	end
	
	-- Also check for extremely low sync
	if SyncA < 5 and SyncB < 5 and self:IsRealistic( ply ) then
		return (bString and "Yes" or true)
	end
	
	return (bString and "No" or false)
end

--[[
	Description: Get the data line to send to the admins
	Notes: Not in use at the moment
--]]
function SMgrAPI:GetDataLine( ply )
	return { ply:Name(), ply.UID, self:GetSync( ply, self.ViewDetail ), self:GetSyncEx( ply, self.ViewDetail ), self:GetFrames( ply ), self:HasConfig( ply, true ), self:HasHack( ply, true ) }
end

--[[
	Description: Send the sync to the player AND the spectators
--]]
function SMgrAPI.SendSyncPlayer( ply, data, sync, strafes, jumps )
	local viewers = ply:Spectator( "Get", { true } )
	viewers[ #viewers + 1 ] = ply
	
	local ar = Core.Prepare( "Timer/SetSync" )
	ar:String( data or "" )
	
	if sync and strafes and jumps then
		ar:Bit( true )
		ar:Double( sync )
		ar:UInt( strafes, 16 )
		ar:UInt( jumps, 16 )
	else
		ar:Bit( false )
	end
	
	ar:Send( viewers )
end

--[[
	Description: Dumps all data we have about all players
--]]
function SMgrAPI:DumpState()
	print( "[SMgrAPI] Dump started" )
	
	for ply,bMonitored in pairs( Monitored ) do
		if IsValid( ply ) and bMonitored then
			print( "\nData for player " .. ply:Name() )
			print( "> Sync A: " .. self:GetSync( ply, self.ViewDetail ) )
			print( "> Sync B: " .. self:GetSyncEx( ply, self.ViewDetail ) )
			print( "> Strafes: " .. ply:GetStrafes() )
			print( "> Total frames monitored: " .. SyncTotal[ ply ] )
			print( "> Likely to have hacks: " .. self:HasHack( ply, true ) )
		end
	end
	
	print( "\n[SMgrAPI] End of data dump" )
end

--[[
	Description: Adds a console command that allows us to dump the state via console
--]]
function SMgrAPI.Console( op, szCmd, varArgs )
	if not IsValid( op ) and not op.Name and not op.Team then
		if szCmd != "smgr" then return end
		
		local szSub = tostring( varArgs[1] )
		if szSub == "dump" then
			SMgrAPI:DumpState()
		else
			print( "[SMgrAPI] The command '" .. szSub .. "' is invalid!" )
			print( "[SMgrAPI] All available commands are: dump" )
		end
	end
end
concommand.Add( "smgr", SMgrAPI.Console )


--[[
	Description: Receives whether or not the user is using the simple HUD
	Used by: Client toggle
--]]
local function ReceiveSimple( ply, varArgs )
	MonitorSimple[ ply ] = varArgs[ 1 ]
end
Core.Register( "Global/Simple", ReceiveSimple )

--[[
	Description: Receives whether or not the user is using the permanent sync feature
	Used by: Client loading
--]]
local function ReceivePermSync( ply, varArgs )
	ply:ToggleSyncState( varArgs[ 1 ] )
end
Core.Register( "Global/PermSync", ReceivePermSync )

--[[
	Description: Receives the preferred default player model
	Used by: Client setting
--]]
local function ReceiveModel( ply, varArgs )
	Core.GetCmd( "model" )( ply, { varArgs[ 1 ], SkipMessage = varArgs[ 2 ] } )
end
Core.Register( "Global/Model", ReceiveModel )

--[[
	Description: Receives whether or not the user is using third person
	Used by: Client loading
--]]
local function ReceiveThirdperson( ply, varArgs )
	GAMEMODE:ShowSpare1( ply, varArgs[ 1 ] )
end
Core.Register( "Global/Thirdperson", ReceiveThirdperson )


--[[
	Description: Ticking function to distribute statistics to everyone
--]]
local function DistributeStatistics()
	for _,a in pairs( player.GetHumans() ) do
		if not a.Spectating then
			if a.SyncDisplay and ValidStyles[ a.Style ] then
				local szText = "Sync: " .. SMgrAPI:GetSync( a, SMgrAPI.DefaultDetail ) .. "%"
				if szText != a.SyncDisplay or MonitorSimple[ a ] then
					local s1, s2, s3
					if MonitorSimple[ a ] then
						s1, s2, s3 = SMgrAPI:GetSimple( a )
						if s3 == MonitorLastS[ a ] then continue end
						MonitorLastS[ a ] = s3
					end
					
					SMgrAPI.SendSyncPlayer( a, szText, s1, s2, s3 )
					a.SyncDisplay = szText
				end
				
				a.SyncVisible = true
			elseif a.SyncVisible then
				SMgrAPI.SendSyncPlayer( a, nil )
				a.SyncVisible = nil
			end
		else
			local t = a:GetObserverTarget()
			if not IsValid( t ) or not Monitored[ t ] then continue end
			
			if ValidStyles[ t.Style ] then
				local szText = "Sync: " .. SMgrAPI:GetSync( t, SMgrAPI.DefaultDetail ) .. "%"
				if szText != a.SyncDisplay then
					SMgrAPI.SendSyncPlayer( a, szText )
					a.SyncDisplay = szText
				end
				
				a.SyncVisible = true
			elseif a.SyncVisible then
				SMgrAPI.SendSyncPlayer( a, nil )
				a.SyncVisible = nil
			end
		end
	end
end
timer.Create( "SyncDistribute", 2, 0, DistributeStatistics )

-- Localized angle function
local function norm( i ) if i > 180 then i = i - 360 elseif i < -180 then i = i + 360 end return i end
local fb, ogiw, wa, ml, mr = bit.band, FL_ONGROUND + FL_INWATER, MOVETYPE_WALK, IN_MOVELEFT, IN_MOVERIGHT

--[[
	Description: Actually monitors the sync
--]]
local function MonitorInputSync( ply, data )
	if not Monitored[ ply ] then return end

	local buttons = data:GetButtons()
	local ang = data:GetAngles().y

	if not ply:IsFlagSet( ogiw ) and ply:GetMoveType() == wa then
		local difference = norm( ang - MonitorAngle[ ply ] )
		
		if difference != 0 then
			local l, r = fb( buttons, ml ) > 0, fb( buttons, mr ) > 0
			if l or r then
				SyncTotal[ ply ] = SyncTotal[ ply ] + 1
				
				if difference > 0 then
					if l and not r then
						SyncAlignA[ ply ] = SyncAlignA[ ply ] + 1
						
						if MonitorLast[ ply ] != ml then
							MonitorLast[ ply ] = ml
							SyncStrafes[ ply ] = SyncStrafes[ ply ] + 1
						end
					end
					
					if data:GetSideSpeed() < 0 then
						SyncAlignB[ ply ] = SyncAlignB[ ply ] + 1
					end
				elseif difference < 0 then
					if r and not l then
						SyncAlignA[ ply ] = SyncAlignA[ ply ] + 1
						
						if MonitorLast[ ply ] != mr then
							MonitorLast[ ply ] = mr
							SyncStrafes[ ply ] = SyncStrafes[ ply ] + 1
						end
					end
					
					if data:GetSideSpeed() > 0 then
						SyncAlignB[ ply ] = SyncAlignB[ ply ] + 1
					end
				end
			end
		end
	end
	
	MonitorAngle[ ply ] = ang
end
hook.Add( "SetupMove", "MonitorInputSync", MonitorInputSync )

SMgrAPI.Init()