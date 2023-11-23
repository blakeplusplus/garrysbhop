local PLAYER = FindMetaTable( "Player" )
local Timer, Zones, Player, RTV = { Spawns = {}, Teleports = {}, Top = {}, PostInitFunc = {} }, { SpecialDoorMaps = {}, MovingDoorMaps = {} }, {}, {}
local StylePoints, TopListCache, WRCache, WRTopCache, Checkpoints, BeatMaps, WRSounds, Popups = {}, {}, {}, {}, {}, {}, {}, {}
local MR, MA, MC, FL, FO, SU, OD, OT, ST, HAS = math.random, math.abs, math.ceil, math.floor, string.format, string.sub, os.date, os.time, SysTime, table.HasValue
local Config, NetPrepare = Core.Config, Core.Prepare
local Styles, Ranks, PlayerData = Config.Style, Config.Ranks, Config.Player
local ScrollStyles = { [Styles["Easy Scroll"]] = true, [Styles["Legit"]] = true }
local BoostTimer, BoostCooldown, BoostMultiplier = {}, { 30, 45, 20, 20 }, { 1.8, 2.4, 3.0, 3.0 }

--[[
	Description: Translates a zone box into usable coordinates and gets a random spawn point
	Used by: Respawning functionality
	Notes: Looks messy, but it works
--]]
local function GetSpawnPoint( data )
	if type( data ) != "table" or #data != 3 then
		return Vector( 0, 0, 0 )
	end
	
	local vx, vy, vz = 8, 8, 0
	local dx, dy, dz = data[ 2 ].x - data[ 1 ].x, data[ 2 ].y - data[ 1 ].y, data[ 2 ].z - data[ 1 ].z
	
	if dx > 96 then vx = dx - 32 - ((data[ 2 ].x - data[ 1 ].x) / 2) end
	if dy > 96 then vy = dy - 32 - ((data[ 2 ].y - data[ 1 ].y) / 2) end
	if dz > 32 then vz = 16 end
	
	local center = Vector( data[ 3 ].x, data[ 3 ].y, data[ 1 ].z )
	local out = center + Vector( MR( -vx, vx ), MR( -vy, vy ), vz )
	
	return out
end
Core.RandomizeSpawn = GetSpawnPoint

--[[
	Description: Checks if the player has a valid timer
	Used by: Timing functions (validation)
	Notes: Created a function for this to keep the timing functions cleaner
--]]
local function ValidTimer( ply, bBonus )
	if not IsValid( ply ) or not ply.Style then return false end
	if ply.Practice or ply.TAS then return false end
	if ply.SkipValidation then ply.SkipValidation = nil return false end
	
	if bBonus then
		if not Core.IsValidBonus( ply.Style ) then return false end
	else
		if Core.IsValidBonus( ply.Style ) then return false end
	end
	
	return true
end

--[[
	Description: Resets any game-changing attributes on the player
	Used by: Respawning and timer starting
--]]
local function ResetPlayerAttributes( ply, nPrevious, bStart )
	if ply:GetMoveType() != 2 then
		ply:SetMoveType( 2 )
	end
	
	if ply.LastObtainedFinish then
		ply.LastObtainedFinish = nil
	end
	
	if ply.TAS or ply.Practice then
		ply:SetStrafeStats()
	end
	
	if ply.TnId and not bStart then
		ply.TnId = nil
	end
	
	if nPrevious then
		ply:StageReset()
		
		if nPrevious == Styles.Unreal then
			BoostTimer[ ply ] = nil
			
			local ar = NetPrepare( "Timer/UnrealReset" )
			ar:UInt( 0, 6 )
			ar:Send( ply )
		end
		
		if ply.Style == Styles.Legit or ply.Style == Styles.Stamina then
			ply:EnableStamina( true )
		elseif ply.StaminaUse then
			ply:EnableStamina( false )
		end
	end
	
	if ply.Style == Styles["Low Gravity"] then
		ply:SetGravity( Config.Player.LowGravity )
	elseif ply.Style == Styles["M.L.G"] then
		ply:SetGravity( 0.25 )
	elseif ply.Style == Styles["High Gravity"] then
		ply:SetGravity( 1.4 )
	elseif ply.Style == Styles["Moon Man"] or ply.Style == Styles["Cancer"] then
		ply:SetGravity( 0.1 )
	elseif ply:GetGravity() != 0 then
		ply:SetGravity( 0 )
	end
	
	if ScrollStyles[ ply.Style ] and ply.RequestJumpRatio then
		ply:RequestJumpRatio( true )
	end
	
	if ply.Practice then return end
	if ply:GetLaggedMovementValue() != 1 then
		ply:SetLaggedMovementValue( 1 )
	end
end

--[[
	Description: Cleaning up of variables when the player resets or sets their timer
	Used by: Timing functionality
	Notes: It's quite a small function but could be expanded easily
--]]
local function PostTimerCleanup( ply, szType, varData )
	ply:Spectator( "PlayerRestart", varData )
	ply:SetStrafeStats()
	
	if szType == "Start" or szType == "Reset" then
		ResetPlayerAttributes( ply, nil, szType == "Start" )
	end
end


--[[
	Description: Attempts to start the player's timer
	Used by: Start zone entity
--]]
function PLAYER:StartTimer( ent )
	if self.TAS then return self.TAS.StartTimer( self, ent ) end
	if not ValidTimer( self ) then return end
	
	local vel2d = self:GetVelocity():Length2D()
	if self.Style != Core.Config.Style["Prespeed"] and vel2d > PlayerData.StartSpeed and not Zones.IsOption( Zones.Options.NoStartLimit ) then
		self:ResetSpawnPosition()
		return Player.Notification( self, "Popup", { "Timer", Core.Text( "ZoneSpeed", MC( vel2d ) .. " u/s" ), "lightning", 4 } )
	end /*elseif Config.IsBhop and self.Style != Core.Config.Style["Prespeed"] and vel2d > 0 and MA( self:GetPos().z - ent.min.z ) > 5 and ent.max.z - ent.min.z > 8 then
		self:ResetSpawnPosition()
		return Player.Notification( self, "Popup", { "Timer", Core.Text( "ZoneJumpExit" ), "error", 4 } )
	end*/
	
	-- Set the start speed value for surfers
	if Config.IsSurf then
		self.Tspeed = self:GetVelocity():Length()
	end
	
	self.Tn = ST()
	self:SetJumps( 0 )

	local ar = NetPrepare( "Timer/Start" )
	ar:UInt( 1, 2 )
	ar:Send( self )
	
	-- Make sure we don't have the FULL clip of this guy walking around in the start zone
	self:ChopFrames( true )
	self.InSpawn = nil
	
	-- Do some stage checking
	if self.TnB then
		self.TnB = self:GetCurrentFrame()
	end
	
	-- Check multiple start points
	if #Zones.StartPoints > 1 and IsValid( ent ) then
		local id
		for pos,data in pairs( Zones.StartPoints ) do
			if data[ 1 ] == ent.min then
				id = pos
			end
		end
		
		self.TzI = id
	end
	
	PostTimerCleanup( self, "Start" )
end

--[[
	Description: Resets a player's timer
	Used by: Start zone entity, spawning functions
--]]
function PLAYER:ResetTimer( bEntity, ent )
	if self.TAS then return self.TAS.ResetTimer( self, ent ) end
	if not ValidTimer( self ) then return end
	if not self.Tn and not bEntity then return end
	
	self.Tn = nil
	self.TnF = nil
	
	self:CleanFrames()
	self:SetBotActive( true )
	
	if bEntity then
		self.InSpawn = true
	end
	
	PostTimerCleanup( self, "Reset" )
	
	local ar = NetPrepare( "Timer/Start" )
	ar:UInt( 0, 2 )
	ar:Send( self )
end

--[[
	Description: Stops the timer and ends the run
	Used by: End zone entity
--]]
function PLAYER:StopTimer( ent )
	if self.TAS then return self.TAS.StopTimer( self, ent ) end
	if not ValidTimer( self ) then return end
	if not self.Tn or self.TnF then return end
	
	self.TnF = ST()
	self:SetBotActive( nil )
	
	-- Start making use of this time that the player got
	local nTime = self.TnF - self.Tn
	Timer.ProcessEnd( self, nTime )
	PostTimerCleanup( self, "Stop", { nTime } )
end

--[[
	Description: Attempts to start the player's bonus timer
	Used by: Bonus start zone entity
--]]
function PLAYER:BonusStart( ent )
	if IsValid( ent ) and not Zones.ValidateBonusStyle( self, ent.embedded ) then return end
	if self.TAS then return self.TAS.StartTimer( self, ent, true ) end
	if not ValidTimer( self, true ) then return end
	
	local vel2d = self:GetVelocity():Length2D()
	if vel2d > PlayerData.StartSpeed then
		self:ResetSpawnPosition()
		return Player.Notification( self, "Popup", { "Timer", Core.Text( "ZoneSpeed", MC( vel2d ) .. " u/s" ), "lightning", 4 } )
	end
	/*elseif Config.IsBhop and vel2d > 0 and MA( self:GetPos().z - ent.min.z ) > 5 and ent.max.z - ent.min.z > 8 then
		self:ResetSpawnPosition()
		return Player.Notification( self, "Popup", { "Timer", Core.Text( "ZoneJumpExit" ), "error", 4 } )
	end*/
	
	-- Set the start speed value for surfers
	if Config.IsSurf then
		self.Tspeed = self:GetVelocity():Length()
	end
	
	self.Tb = ST()
	self:SetJumps( 0 )
	
	local ar = NetPrepare( "Timer/Start" )
	ar:UInt( 1, 2 )
	ar:Send( self )
	
	-- Make sure we don't have the FULL clip of this guy walking around in the start zone
	self:ChopFrames( true )
	self.InSpawn = nil

	PostTimerCleanup( self, "Start" )
end

--[[
	Description: Resets a player's bonus timer
	Used by: Bonus start zone entity, spawning functions
--]]
function PLAYER:BonusReset( bEntity, ent )
	if bEntity and IsValid( ent ) and not Zones.ValidateBonusStyle( self, ent.embedded ) then return end
	if self.TAS then return self.TAS.ResetTimer( self, ent, true ) end
	if not ValidTimer( self, true ) then return end
	if not self.Tb and not bEntity then return end
	
	self.Tb = nil
	self.TbF = nil
	
	self:CleanFrames()
	self:SetBotActive( true )
	
	if bEntity then
		self.InSpawn = true
	end
	
	PostTimerCleanup( self, "Reset" )
	
	local ar = NetPrepare( "Timer/Start" )
	ar:UInt( 0, 2 )
	ar:Send( self )
end

--[[
	Description: Stops the bonus timer and ends the run
	Used by: Bonus end zone entity
--]]
function PLAYER:BonusStop( ent )
	if IsValid( ent ) and not Zones.ValidateBonusStyle( self, ent.embedded ) then return end
	if self.TAS then return self.TAS.StopTimer( self, ent, true ) end
	if not ValidTimer( self, true ) then return end
	if not self.Tb or self.TbF then return end
	
	self.TbF = ST()
	self:SetBotActive( nil )
	
	-- Start making use of this sexy bonus time
	local nTime = self.TbF - self.Tb
	Timer.ProcessEnd( self, nTime )
	PostTimerCleanup( self, "Stop", { nTime } )
end

--[[
	Description: Stops any timer (for cheating purposes)
	Used by: Anti-cheat zones, +left and +right checker
--]]
function PLAYER:StopAnyTimer( ent )
	if self:IsBot() or self.Practice then return false end
	if IsValid( ent ) and ent.embedded and self.Style != ent.embedded then return false end
	if self.TAS then return self.TAS.ResetTimer( self, ent ) end
	
	self.Tn = nil
	self.TnF = nil
	self.Tb = nil
	self.TbF = nil
	
	self:StageReset()
	self:SetBotActive( nil )
	self:CleanFrames()
	
	local ar = NetPrepare( "Timer/Start" )
	ar:UInt( 0, 2 )
	ar:Send( self )
	
	PostTimerCleanup( self, "Anticheat" )
	
	return true
end

--[[
	Description: Resets the player's position
	Used by: Spawning functions, zone limitations
--]]
function PLAYER:ResetSpawnPosition( tabCheck, bReset, bLeave )
	if self:IsBot() then
		self:SetLocalVelocity( Vector( 0, 0, 0 ) )
		return Zones.BotPoints and #Zones.BotPoints > 0 and self:SetPos( Zones.BotPoints[ RTV.TrueRandom( 1, #Zones.BotPoints ) ] )
	elseif tabCheck then
		if Core.IsValidBonus( tabCheck[ 1 ] ) then
			return not Zones.GetBonusPoint( tabCheck[ 2 ] )
		end
		
		return false
	end
	
	if not self.Style then return end
	
	if bReset then
		local dz = bReset.embedded
		if dz then
			if bLeave and self:GetVelocity():Length2D() > dz * 100 then
				self:SetLocalVelocity( Vector( 0, 0, 0 ) )
			end
			
			return
		end
	end
	
	self.LastResetData = not self.InSpawn and { ST(), self.Style, self.TnF, self.Tn, self:GetPos(), self:EyeAngles(), self:GetJumps(), self:GetStrafes(), { self:GetSync( true ) } }
	self:SetLocalVelocity( Vector( 0, 0, 0 ) )
	self:SetJumps( 0 )
	self:SetJumpPower( Config.Player.JumpPower )
	self:StageReset()
	
	ResetPlayerAttributes( self )
	
	if self.IsLJ then
		self:LJResetStats()
	end
	
	if self.SpaceEnabled then
		Core.Send( self, "Timer/Space", true )
	end
	
	if self.Style == Styles.Unreal then
		BoostTimer[ self ] = nil
		
		local ar = NetPrepare( "Timer/UnrealReset" )
		ar:UInt( 0, 6 )
		ar:Send( self )
	end
	
	local bonus = Core.IsValidBonus( self.Style )
	if bonus and self.Tb then
		self:BonusReset()
	elseif not bonus and self.Tn then
		self:ResetTimer()
	end
	
	if Timer.BaseAngles then
		if bonus then
			local ang = Timer.BonusAngles[ self.Style - Styles.Bonus ]
			if ang then
				self:SetEyeAngles( Angle( self:EyeAngles().p, ang.y, 0 ) )
			end
		else
			self:SetEyeAngles( Angle( self:EyeAngles().p, Timer.BaseAngles.y, 0 ) )
		end
	end
	
	if not bonus and Zones.StartPoints and #Zones.StartPoints > 0 then
		self:SetPos( GetSpawnPoint( Zones.StartPoints[ self.TzI or RTV.TrueRandom( 1, #Zones.StartPoints ) ] ) )
		self.InSpawn = true
	elseif bonus then
		self:SetPos( GetSpawnPoint( Zones.GetBonusPoint( self.Style - Styles.Bonus ) ) )
	else
		Core.Print( self, "Timer", Core.Text( "ZoneSetup" ) )
	end
	
	return true
end

--[[
	Description: Executes an unreal boost
	Used by: Movement and KeyPress hook
--]]
function PLAYER:DoUnrealBoost( nForce, nMultiplierOverride, nForceCooldown, vForceVelocity )
	if BoostTimer[ self ] and ST() < BoostTimer[ self ] then return end
	if self.TAS and self.TAS.UnrealBoost( self ) then return end
	
	-- Set the base cooldown to be non-existant
	local nCooldown, nMultiplier, nType = 0, 0, 1
	local vel = self:GetVelocity()
	
	-- Check which boost type we need
	if self:KeyDown( IN_FORWARD ) and not self:KeyDown( IN_BACK ) and not self:KeyDown( IN_MOVELEFT ) and not self:KeyDown( IN_MOVERIGHT ) then
		nType = 2
	elseif self:KeyDown( IN_JUMP ) and not self:KeyDown( IN_FORWARD ) and not self:KeyDown( IN_BACK ) and not self:KeyDown( IN_MOVELEFT ) and not self:KeyDown( IN_MOVERIGHT ) then
		nType = 3
	elseif self:KeyDown( IN_BACK ) and not self:KeyDown( IN_FORWARD ) and not self:KeyDown( IN_MOVELEFT ) and not self:KeyDown( IN_MOVERIGHT ) then
		nType = 4
	else
		nType = 1
	end
	
	-- See if we're forcing
	if nForce then
		nType = nForce
	end
	
	-- By default, for all different key combinations, we will simply amplify velocity
	if vForceVelocity then
		self:SetVelocity(vForceVelocity)
	elseif nType == 1 then
		nCooldown = BoostCooldown[ 1 ]
		if nMultiplierOverride then
			nMultiplier = nMultiplierOverride
		else
			nMultiplier = BoostMultiplier[ 1 ]
		end

		self:SetVelocity( vel * Vector( nMultiplier, nMultiplier, nMultiplier * 1.5 ) - vel )
		
	-- If we've only got W down, we will boost forward faster than normal omnidirectional boost
	elseif nType == 2 then
		nCooldown = BoostCooldown[ 2 ]
		if nMultiplierOverride then
			nMultiplier = nMultiplierOverride
		else
			nMultiplier = BoostMultiplier[ 2 ]
		end
		
		self:SetVelocity( vel * Vector( nMultiplier, nMultiplier, 1 ) - vel )
		
	-- If we've only got jump in, we will boost upwards strongly
	elseif nType == 3 then
		nCooldown = BoostCooldown[ 3 ]
		if nMultiplierOverride then
			nMultiplier = nMultiplierOverride
		else
			nMultiplier = BoostMultiplier[ 3 ]
		end
		
		if vel.z < 0 then
			nMultiplier = -0.5 * nMultiplier
		end
		
		self:SetVelocity( vel * Vector( 1, 1, nMultiplier ) - vel )
		
	-- If we've got S down and nothing else, we will boost downwards fast
	elseif nType == 4 then
		nCooldown = BoostCooldown[ 4 ]
		if nMultiplierOverride then
			nMultiplier = nMultiplierOverride
		else
			nMultiplier = BoostMultiplier[ 4 ]
		end
		
		if vel.z > 0 then
			nMultiplier = -nMultiplier
		end
		
		self:SetVelocity( vel * Vector( 1, 1, nMultiplier ) - vel )
	end
	
	if nForceCooldown != nil then
		nCooldown = nForceCooldown
	end

	if nCooldown != 0 then
		BoostTimer[ self ] = ST() + nCooldown
		if self.TAS then self.TAS.UnrealBoost( self, nCooldown ) end
		
		local ar = NetPrepare( "Timer/UnrealReset" )
		ar:UInt( nCooldown, 6 )
		ar:Send( self )
	end
end

--[[
	Description: Enables stamina on the given player
	Used by: Stamina styles
--]]
function PLAYER:EnableStamina( bool )
	EnableStamina( self, bool )
	self.StaminaUse = bool
	
	local ar = NetPrepare( "Timer/Stamina" )
	ar:Bit( bool )
	ar:Send( self )
	
	return bool
end

--[[
	Description: Enables freestyle movement for specific styles
	Used by: Freestyle zone entity (ENTER)
--]]
function PLAYER:StartFreestyle()
	if not ValidTimer( self ) then return end
	
	if self.Style >= Styles.SW and self.Style <= Styles["S-Only"] then
		self.Freestyle = true
		Core.Send( self, "Timer/Freestyle", { self.Freestyle } )
		Core.Print( self, "Timer", Core.Text( "StyleFreestyle", "entered a", " All key combinations are now possible." ) )
	elseif self.Style == Styles["Low Gravity"] then
		self.Freestyle = true
		Core.Send( self, "Timer/Freestyle", { self.Freestyle } )
		Core.Print( self, "Timer", Core.Text( "StyleFreestyle", "entered a", " Reverted gravity to normal values." ) )
	end
end

--[[
	Description: Disables freestyle movement for specific styles
	Used by: Freestyle zone entity (LEAVE)
--]]
function PLAYER:StopFreestyle()
	if not ValidTimer( self ) then return end
	
	if self.Style >= Styles.SW and self.Style <= Styles["S-Only"] then
		self.Freestyle = nil
		Core.Send( self, "Timer/Freestyle", { self.Freestyle } )
		Core.Print( self, "Timer", Core.Text( "StyleFreestyle", "left the", "" ) )
	elseif self.Style == Styles["Low Gravity"] then
		self.Freestyle = nil
		Core.Send( self, "Timer/Freestyle", { self.Freestyle } )
		Core.Print( self, "Timer", Core.Text( "StyleFreestyle", "left the", "" ) )
	end
end


-- Records

Timer.Multiplier = 1
Timer.BonusMultiplier = 1
Timer.Options = 0
Timer.Maps = 0

local Maps = {}
local Records = {}
local TopTimes = {}
local Averages = {}
local TimeCache = {}
local Prepare, InsertAt, RemoveAt = SQLPrepare, table.insert, table.remove


--[[
	Description: Gets the amount of records in a style
--]]
local function GetRecordCount( nStyle )
	return Records[ nStyle ] and #Records[ nStyle ] or 0
end

--[[
	Description: Gets the saves average for a specific style, returns 0 if none set
--]]
local function GetAverage( nStyle )
	return Averages[ nStyle ] or 0
end

--[[
	Description: Recalculate the average for a specific style
--]]
local function CalcAverage( nStyle )
	local nTotal, nCount = 0, 0

	-- Iterate over the top 50 times of this style and add the time values
	for i = 1, 50 do
		if Records[ nStyle ] and Records[ nStyle ][ i ] then
			nTotal = nTotal + Records[ nStyle ][ i ]["nTime"]
			nCount = nCount + 1
		else
			break
		end
	end
	
	-- Check the amount of times we have
	if nCount == 0 then
		Averages[ nStyle ] = 0
	else
		-- Save the average for later use
		Averages[ nStyle ] = nTotal / nCount
	end
	
	-- Return the saved average
	return Averages[ nStyle ]
end

--[[
	Description: Updates a player record accordingly
--]]
local function UpdateRecords( ply, nPos, nNew, nOld, nDate )
	local Entry = {}
	Entry.szUID = ply.UID
	Entry.nTime = nNew
	Entry.nPoints = 0 -- These will be inserted directly afterwards
	Entry.nDate = nDate
	Entry.vData = nil

	-- Set the details position
	ply.SpeedPos = nPos
	
	-- If there's no previous time, just insert a new entry at the correct position
	if nOld == 0 then
		InsertAt( Records[ ply.Style ], nPos, Entry )
	else
		local AtID = 0
		
		-- Obtain the player's location in the ladder
		for i = 1, #Records[ ply.Style ] do
			if Records[ ply.Style ][ i ]["szUID"] == Entry["szUID"] then
				AtID = i
				break
			end
		end
		
		-- Update the record at that position
		if AtID > 0 then
			RemoveAt( Records[ ply.Style ], AtID )
			InsertAt( Records[ ply.Style ], nPos, Entry )
		else
			print( "Records", "Unable to replace existing time. Please restart server immediately." )
		end
	end
end

--[[
	Description: Final function in the AddRecord chain; broadcasts messages and recalculates
--]]
local function AddRecord_End( ply, nTime, nOld, nID, nStyle, nPreviousWR, nPrevID, szPreviousWR )
	-- Setup data for notification
	local data = {}
	
	-- Give them a shiny medal when applicable
	if nID <= 3 then
		Player.SetRankMedal( ply, nID, true )
		
		if nID == 1 then
			-- Notify the previous WR holder
			if nPreviousWR > 0 and szPreviousWR and szPreviousWR != ply.UID then
				Player.NotifyBeatenWR( szPreviousWR, Timer:GetMap(), ply:Name(), nStyle, nPreviousWR - nTime )
			end
			
			-- (Re)load the full list if required
			if nStyle == Styles.Normal or GetRecordCount( nStyle ) >= 10 then
				if not Timer.SoundTracker or #Timer.SoundTracker == 0 then
					Timer.SoundTracker = {}
					
					for i = 1, #WRSounds do
						Timer.SoundTracker[ i ] = i
					end
				end
				
				-- WR Sounds, yey (only for the really cool people, though)
				local nSound = table.remove( Timer.SoundTracker, RTV.TrueRandom( 1, #Timer.SoundTracker ) )
				data.Sound = "/sound/" .. Config.MaterialID .. "/" .. WRSounds[ nSound ] .. ".mp3"
			end
			
			-- Set the top time
			Timer.ChangeTopTime( nStyle )
		end
	end
	
	-- Get the new WR position for the bot
	Core.SetBotRecord( nStyle, nID )
	
	-- Send the player his new time
	local ar = NetPrepare( "Timer/Record" )
	ar:Double( nTime )
	ar:Bit( false )
	ar:Bit( true )
	ar:Send( ply )
	
	-- End the bot run if there is any
	local bSucceed = ply:EndBotRun( nTime, nID )
	if bSucceed then
		data.Bot = true
	else
		ply.LastObtainedFinish = { nTime, nStyle, Core.IsValidBonus( nStyle ) and ply.TbF or ply.TnF, ply.BotFrameStart }
		
		-- Check if we are being force recorded
		if ply.BotForce then
			timer.Simple( 1, function()
				if IsValid( ply ) then
					if Core.ForceBotSave( ply ) then
						if IsValid( ply.BotForce ) then
							if ply.BotForce == ply then
								Core.Print( ply, "General", Core.Text( "CommandBotForceSaved" ) )
							else
								Core.Print( ply.BotForce, "General", Core.Text( "CommandBotForceFeedback", ply:Name() ) )
							end
							
							ply.BotForce = nil
						end
					end
				end
			end )
		end
	end
	
	-- Setup the variables
	data.Time = nTime
	data.Style = nStyle
	data.Pos = nID
	data.DifferenceWR = nID > 1 and "WR +" .. Timer.Convert( nTime - Timer.ChangeTopTime( nStyle, true ) ) or (nPreviousWR > 0 and "WR -" .. Timer.Convert( nPreviousWR - nTime ) or "")
	data.Improvement = nOld == 0 and -1 or Timer.Convert( nOld - nTime )
	data.MapRecord = nID == 1
	data.Rank = nID .. " / " .. GetRecordCount( nStyle )
	
	-- Send out the notification
	Player.Notification( ply, "ImproveFinish", data )
	
	-- Finally publish the changes made to the player
	ply:PublishObj()
end

--[[
	Description: First function in the AddRecord chain; Get the player's new rank
	Used by: SQL callback
--]]
local function AddRecord_Begin( data, varArg, szError )
	-- Get variables
	local ply, nTime, nOld, nDate, nStyle = varArg[ 1 ], varArg[ 2 ], varArg[ 3 ], varArg[ 4 ], varArg[ 5 ]
	
	-- Get the previous WR if there was any
	local nPrevious, szPrevious = Timer.ChangeTopTime( nStyle, true )
	
	-- Get the new position in the ladder
	local nID = Timer.GetRecordID( nTime, nStyle )
	
	-- Get the current position in the ladder
	local _,nPrevID = Timer.GetPlayerRecord( ply )
	
	-- Calculate the current average
	local nCurrentAverage = CalcAverage( nStyle )
	
	-- Insert the record into the internal table
	UpdateRecords( ply, nID, nTime, nOld, nDate )
	
	-- Obtain the new average
	CalcAverage( nStyle )
	
	-- Change the ID
	ply.Leaderboard = nID
	ply:SetObj( "Position", ply.Leaderboard )
	
	-- Reload everything
	ply:LoadRank() -- Reload the main player's rank
	ply:AddFrags( 1 ) -- This shows up on GameTracker, it's cool
	Player.ReloadRanks( ply, nStyle, nCurrentAverage ) -- Reload the ranks for other players
	
	-- End the AddRecord instance
	AddRecord_End( ply, nTime, nOld, nID, nStyle, nPrevious or 0, nPrevID, szPrevious )
end


--[[
	Description: Begins processing the obtained time and takes the next steps
	Used by: Timing functions
--]]
function Timer.ProcessEnd( ply, nTime )
	-- Get the difference between previous record
	local Difference = ply.Record > 0 and nTime - ply.Record
	local IsImproved = ply.Record == 0 or (ply.Record > 0 and nTime < ply.Record)
	local SelfDifference = Difference and "PB " .. (Difference < 0 and "-" or "+") .. Timer.Convert( MA( Difference ) ) or ""
	
	-- Check run details
	local CurrentSync, Strafes, Jumps = ply:GetSync(), ply:GetStrafes(), ply:GetJumps()
	if CurrentSync then
		-- Set their values for updating with speed
		ply.LastSync = CurrentSync
		ply.LastStrafes = Strafes
		ply.LastJumps = Jumps
		
		-- Get specific values
		if ScrollStyles[ ply.Style ] then
			ply.LastRatio = ply.RequestJumpRatio and ply:RequestJumpRatio( nil, { Core.StyleName( ply.Style ), Jumps, nTime, ply.Record } )
		end
	end
	
	-- Set start speed
	if Config.IsSurf then
		ply.LastStartSpeed = ply.Tspeed
		ply.Tspeed = nil
	end
	
	-- Check additional possibilities
	if ply.Race then
		ply.Race:Stop( ply )
	end
	
	-- Get the amount of points the user gets for completing the map
	local InterpAverage = Timer.InterpolateAverage( nTime, ply.Style )
	local InterpPoints = math.Round( Timer.GetPointsForMap( ply, nTime, ply.Style, InterpAverage, true ), 2 )
	
	-- Notify the player
	Player.Notification( ply, "BaseFinish", { Time = nTime, Difference = SelfDifference, Jumps = Jumps, Strafes = Strafes, Sync = CurrentSync, Points = IsImproved and InterpPoints } )
	
	-- Check if they have an old record
	local OldRecord = ply.Record or 0
	if ply.Record != 0 and nTime >= ply.Record then return end
	
	-- Update their stuff
	ply.SpeedRequest = ply.Style
	ply.Record = nTime
	ply:SetObj( "Record", ply.Record )

	-- Setup style variable
	local PlayerStyle = ply.Style
	
	-- Create a new object
	local QueryTime, QueryObject = Timer.GetCurrentDate()
	
	-- If we have something, update, otherwise, insert
	if OldRecord > 0 then
		QueryObject = Prepare(
			"UPDATE game_times SET nTime = {0}, nDate = {1}, vData = NULL WHERE szMap = {2} AND szUID = {3} AND nStyle = {4}",
			{ nTime, QueryTime, Timer:GetMap(), ply.UID, PlayerStyle }
		)
	else
		QueryObject = Prepare(
			"INSERT INTO game_times VALUES ({0}, {1}, {2}, {3}, 0, {4}, NULL)",
			{ ply.UID, Timer:GetMap(), PlayerStyle, nTime, QueryTime }
		)
	end
	
	-- Only proceed if we have valid object, proceed (which should be always, but OK)
	if QueryObject then
		QueryObject( AddRecord_Begin, { ply, nTime, OldRecord, QueryTime, PlayerStyle } )
	else
		print( "Records", "Something went wrong while adding time for", ply, nTime )
	end
end

--[[
	Description: Updates the run details if an existing entry exists
	Used by: SQL callback
--]]
function Timer.UpdateRunDetails( data, varArg, szError )
	local ply = varArg[ 1 ]
	
	-- Make sure that nothing went wrong and update in the given position
	if ply.SpeedPos and ply.SpeedPos > 0 and Records[ ply.Style ] and Records[ ply.Style ][ ply.SpeedPos ] and Records[ ply.Style ][ ply.SpeedPos ]["szUID"] == ply.UID then
		Records[ ply.Style ][ ply.SpeedPos ]["vData"] = Core.Null( varArg[ 2 ] )
	end
	
	-- Reset speed pos
	ply.SpeedPos = nil
end

--[[
	Description: Checks if it's a valid request and inserts the details if possible
	Used by: Client request
--]]
function Timer.SetRunDetails( ply, tab )
	-- Since we're getting a response from the client, double-validate that it's actually legit
	if ply.Record and ply.Record > 0 and ply.SpeedRequest then
		-- Also check that we're not being cheeky
		if ply.Practice or ply.TAS then
			ply.SpeedRequest = nil
			return
		end
		
		local function TabToString( tab )
			-- Validate all fields
			for i = 1, #tab do
				if not tab[ i ] then
					tab[ i ] = 0
				end
			end
			
			-- Concatenate the whole table and clean up
			local str = string.Implode( " ", tab )
			Core.CleanTable( tab )
			
			return str
		end
		
		-- Assemble all data into a simple string (Top speed, average speed, jumps, strafes, sync)
		local tabData = { FL( Config.IsBhop and tab[ 1 ] or ply.LastStartSpeed or 0 ), FL( tab[ 2 ] ), ply.LastJumps, ply.LastStrafes, ply.LastSync }
		
		-- Style specific extras
		if ScrollStyles[ ply.SpeedRequest ] then
			tabData[ 6 ] = ply.LastRatio
		end
		
		-- Create a writable entry
		local szData = TabToString( tabData )
		
		-- Update the vData column with all collected data
		Prepare(
			"UPDATE game_times SET vData = {0} WHERE szUID = {1} AND szMap = {2} AND nStyle = {3}",
			{ szData, ply.UID, Timer:GetMap(), ply.SpeedRequest }
		)( 
			Timer.UpdateRunDetails,
			{ ply, szData }
		)
		
		-- Reset their speed request
		ply.SpeedRequest = nil
	end
end
Core.Register( "Global/Details", Timer.SetRunDetails )

--[[
	Description: Sends the top times table
	Used by: Player connections
--]]
function Timer.SendTopTimes( ply )
	local ar = NetPrepare( "Timer/Initial" )
	ar:UInt( Core.CountHash( TopTimes ), 8 )
	
	for s,t in pairs( TopTimes ) do
		ar:UInt( s, 8 )
		ar:Double( t )
	end
	
	if ply then
		ar:Send( ply )
	else
		ar:Broadcast()
	end
end
Core.SendTopTimes = Timer.SendTopTimes

--[[
	Description: Forces a full recalculation on the database end
	Used by: Map cleanup, admin panel
--]]
function Timer.RecalculatePoints()
	local szMap = Timer:GetMap()
	
	for nStyle,_ in pairs( Records ) do
		local nMultiplier = Timer:GetMultiplier( nStyle )
		local nFourth, nDouble = nMultiplier / 4, nMultiplier * 2
		
		sql.Query( "UPDATE game_times SET nPoints = " .. nMultiplier .. " * (" .. GetAverage( nStyle ) .. " / nTime) WHERE szMap = '" .. szMap .. "' AND nStyle = " .. nStyle )
		sql.Query( "UPDATE game_times SET nPoints = " .. nDouble .. " WHERE szMap = '" .. szMap .. "' AND nStyle = " .. nStyle .. " AND nPoints > " .. nDouble )
		sql.Query( "UPDATE game_times SET nPoints = " .. nFourth .. " WHERE szMap = '" .. szMap .. "' AND nStyle = " .. nStyle .. " AND nPoints < " .. nFourth )
	end
end
Core.RecalculatePoints = Timer.RecalculatePoints

--[[
	Description: Updates the top time in the local table
--]]
function Timer.ChangeTopTime( nStyle, bGet, bAvoid )
	-- Check if the time is valid
	if Records[ nStyle ] and Records[ nStyle ][ 1 ] and Records[ nStyle ][ 1 ]["nTime"] then
		-- Insert it into the TopTimes cache
		TopTimes[ nStyle ] = Records[ nStyle ][ 1 ]["nTime"]
		
		-- Return it if we want to get it
		if bGet then
			return TopTimes[ nStyle ] or 0, Records[ nStyle ][ 1 ]["szUID"]
		end
	end
	
	-- Otherwise broadcast
	if not bGet and not bAvoid then
		Timer.SendTopTimes()
	end
end

--[[
	Description: Returns the multiplier for a given style
	Notes: All styles that follow the main course are given the base multiplier
--]]
function Timer:GetMultiplier( nStyle, bAll )
	if Core.IsValidBonus( nStyle ) then
		if type( self.BonusMultiplier ) == "table" then
			if bAll then
				local total = 0
				for i = 1, #self.BonusMultiplier do
					total = total + self.BonusMultiplier[ i ]
				end
				return total
			else
				return self.BonusMultiplier[ nStyle - Styles.Bonus + 1 ] or 0
			end
		else
			return self.BonusMultiplier
		end
	else
		return self.Multiplier
	end
end

--[[
	Description: Gets the amount of points you would have for a specific time on a style
--]]
function Timer.GetPointsForMap( ply, nTime, nStyle, nAverage, bSingle )
	local total = 0
	if Core.IsValidBonus( nStyle ) and not bSingle then
		local ids = Zones.GetBonusIDs()
		for i = 1, #ids do
			local style = Styles.Bonus + ids[ i ]
			local rec = Timer.GetPlayerRecord( ply, style )
			if rec == 0 then continue end
			
			local m = Timer:GetMultiplier( style )
			local p = m * (GetAverage( style ) / rec)
			
			if p > m * 2 then p = m * 2
			elseif p < m / 4 then p = m / 4
			end
			
			total = total + p
		end
	else
		if nTime == 0 then return 0 end
		if not nAverage then nAverage = GetAverage( nStyle ) end
		
		local m = Timer:GetMultiplier( nStyle )
		total = m * (nAverage / nTime)
		
		if total > m * 2 then total = m * 2
		elseif total < m / 4 then total = m / 4
		end
	end
	
	return total
end
Core.GetPointsForMap = Timer.GetPointsForMap

--[[
	Description: Gets the record ID you would have for a time
	Used by: Bots to show what record they're displaying
	Notes: Requested by Yeckoh on Surfline
--]]
function Timer.GetRecordID( nTime, nStyle )
	if Records[ nStyle ] then
		for i = 1, #Records[ nStyle ] do
			if nTime <= Records[ nStyle ][ i ]["nTime"] then
				return i
			end
		end

		return #Records[ nStyle ] + 1
	else
		return 1
	end
end
Core.GetRecordID = Timer.GetRecordID

--[[
	Description: Gets the steam ID of the player at the given position
	Used by: Profile command
--]]
function Timer.GetSteamAtID( nStyle, nID )
	if Records[ nStyle ] then
		for i = 1, #Records[ nStyle ] do
			if i == nID then
				return Records[ nStyle ][ i ]["szUID"]
			end
		end
	end
end
Core.GetSteamAtID = Timer.GetSteamAtID

--[[
	Description: Gets the record entry for a player currently in the table
--]]
function Timer.GetPlayerRecord( ply, nOverride )
	-- Set base variables
	local nStyle, szSteam = nOverride or ply.Style, ply.UID
	
	-- Check if we even have records for that style
	if Records[ nStyle ] then
		for i = 1, #Records[ nStyle ] do
			if Records[ nStyle ][ i ]["szUID"] == szSteam then
				return Records[ nStyle ][ i ]["nTime"], i
			end
		end
	end
	
	return 0, 0
end
Core.GetPlayerRecord = Timer.GetPlayerRecord

--[[
	Description: Gets the top X steam IDs
	Used by: Player medal setting
--]]
function Timer.GetTopSteam( nStyle, nAmount )
	local list = {}
	if Records[ nStyle ] then
		for i = 1, nAmount do
			if Records[ nStyle ][ i ] then
				list[ i ] = Records[ nStyle ][ i ]["szUID"]
			end
		end
	end
	
	return list
end

--[[
	Description: Gets the WR count on the player
--]]
function Timer.GetPlayerWRs( uid, style, all )
	local out = { 0, 0, 0 }
	
	if style and Core.IsValidBonus( style ) then
		style = Styles.Bonus
	end
	
	for _,data in pairs( WRTopCache[ uid ] or {} ) do
		local ts = data.nStyle
		if ts then
			out[ 1 ] = out[ 1 ] + 1
			
			if Core.IsValidBonus( ts ) then
				ts = Styles.Bonus
			end
			
			if ts == style then
				out[ 2 ] = out[ 2 ] + 1
			else
				out[ 3 ] = out[ 3 ] + 1
			end
			
			if all then
				if not out.Rest then out.Rest = {} end
				out.Rest[ ts ] = (out.Rest[ ts ] or 0) + 1
			end
		end
	end
	
	return out
end

--[[
	Description: Approximate points gained for map
	Notes: It's called Interpolate because it isn't exact, but very accurate
--]]
function Timer.InterpolateAverage( nTime, nStyle )
	local nTotal, nCount, nLast = 0, 0, 0

	-- Go through the top 50 and create an average from that
	for i = 1, 50 do
		if Records[ nStyle ] and Records[ nStyle ][ i ] then
			local nRec = Records[ nStyle ][ i ]["nTime"]
			nTotal = nTotal + nRec
			nCount = nCount + 1
			nLast = i
		else
			break
		end
	end
	
	-- Remove the lowest time and replace it with our (fictional) time
	if nLast > 0 and Records[ nStyle ] and Records[ nStyle ][ nLast ]["nTime"] > nTime then
		nTotal = nTotal - Records[ nStyle ][ nLast ]["nTime"]
		nTotal = nTotal + nTime
	elseif nLast == 0 and nCount == 0 then
		nTotal = nTime
		nCount = 1
	end

	-- Make sure we don't return a NaN
	if nCount == 0 then
		return 0
	else
		return nTotal / nCount
	end
end

--[[
	Description: Opens the WR list for any other map
	Notes: EVEN for when they entered the current map
--]]
function Timer.DoRemoteWRList( ply, szMap, nStyle, nUpdate )
	if not szMap then return end
	if tonumber( szMap ) then
		local nID = tonumber( szMap )
		local nLim = Core.GetRecordCount( nStyle )
		
		if nID <= 0 or nID > nLim then
			return Core.Print( ply, "General", Core.Text( "CommandWRListReach", nID, nLim ) )
		end
		
		local nBottom = math.floor( (nID - 1) / Config.PageSize ) * Config.PageSize + 1
		local nTop = nBottom + Config.PageSize - 1
		
		if nTop > nLim then
			nTop = nLim
		end
		
		local args = { Core.GetRecordList( nStyle, nBottom, nTop ), nLim, nStyle }
		args.Started = nBottom
		args.TargetID = nID
		
		return GAMEMODE:ShowSpare2( ply, args )
	end
	
	if szMap == Timer:GetMap() and not ply.OutputSock then
		return GAMEMODE:ShowSpare2( ply, nil, nStyle )
	end
	
	local SendData = {}
	local SendCount = 0
	
	local WRMap = WRCache[ szMap ]
	if not WRMap or (type( WRMap ) == "table" and not WRMap[ nStyle ]) then
		if RTV.MapExists( szMap ) then
			if not WRMap then
				WRCache[ szMap ] = {}
			end
			
			WRCache[ szMap ][ nStyle ] = {}
			
			-- Request the data
			Prepare(
				"SELECT * FROM game_times WHERE szMap = {0} AND nStyle = {1} ORDER BY nTime ASC",
				{ szMap, nStyle },
				nil, true
			)( function( data, varArg, szError )
				if Core.Assert( data, "szUID" ) then
					local makeNum, makeNull, nCount = tonumber, Core.Null, 1
					for j = 1, #data do
						data[ j ]["szMap"] = nil
						data[ j ]["nStyle"] = nil
						data[ j ]["nTime"] = makeNum( data[ j ]["nTime"] )
						data[ j ]["nPoints"] = makeNum( data[ j ]["nPoints"] )
						data[ j ]["nDate"] = makeNum( data[ j ]["nDate"] ) or 0
						data[ j ]["vData"] = makeNull( data[ j ]["vData"] )
						
						WRCache[ szMap ][ nStyle ][ nCount ] = data[ j ]
						nCount = nCount + 1
					end
				end
			end )
			
			if ply.OutputFull then
				return WRCache[ szMap ][ nStyle ], "Full"
			end
			
			local nStart, nMaximum = 1, Config.PageSize
			if nUpdate then
				nStart, nMaximum = nUpdate[ 1 ], nUpdate[ 2 ]
			end
			
			for i = nStart, nMaximum do
				if WRCache[ szMap ][ nStyle ][ i ] then
					SendData[ i ] = WRCache[ szMap ][ nStyle ][ i ]
				end
			end
			
			SendCount = #WRCache[ szMap ][ nStyle ]
		else
			return Core.Print( ply, "General", Core.Text( "MapInavailable", szMap ) )
		end
	else
		-- This means we already fetched the data
		local nStart, nMaximum = 1, Config.PageSize
		if nUpdate then
			nStart, nMaximum = nUpdate[ 1 ], nUpdate[ 2 ]
		end
		
		for i = nStart, nMaximum do
			if WRCache[ szMap ][ nStyle ][ i ] then
				SendData[ i ] = WRCache[ szMap ][ nStyle ][ i ]
			end
		end
	
		SendCount = #WRCache[ szMap ][ nStyle ]
	end
	
	-- Scan for data
	local bZero = true
	for i,data in pairs( SendData ) do
		if i and data then bZero = false break end
	end
	
	-- If we don't have anything, show only a print
	if bZero or SendCount == 0 then
		if nUpdate then return end
		return Core.Print( ply, "Timer", Core.Text( "CommandRemoteWRListBlank", szMap, Core.StyleName( nStyle ) ) )
	else
		if ply.OutputSock then
			return SendData, SendCount
		end
		
		if nUpdate then
			NetPrepare( "GUI/Update", {
				ID = "Records",
				Data = { SendData, SendCount }
			} ):Send( ply )
		else
			NetPrepare( "GUI/Build", {
				ID = "Records",
				Title = "Server records",
				X = 500,
				Y = 400,
				Mouse = true,
				Blur = true,
				Data = { SendData, SendCount, nStyle, IsEdit = ply.RemovingTimes, Map = szMap }
			} ):Send( ply )
		end
	end
end
Core.DoRemoteWR = Timer.DoRemoteWRList

--[[
	Description: Responds with an update to the request
	Notes: Much more efficient than what I used to do with paging
--]]
function Timer.WRListRequest( ply, varArgs )
	local nStyle = varArgs[ 1 ]
	local tabOffset = varArgs[ 2 ]
	local szMap = varArgs[ 3 ]
	
	-- If a map is provided, send a remote WR update
	if szMap then
		Timer.DoRemoteWRList( ply, szMap, nStyle, tabOffset )
	else
		NetPrepare( "GUI/Update", {
			ID = "Records",
			Data = { Core.GetRecordList( nStyle, tabOffset[ 1 ], tabOffset[ 2 ] ), Core.GetRecordCount( nStyle ) }
		} ):Send( ply )
	end
end
Core.Register( "Global/RetrieveList", Timer.WRListRequest )

--[[
	Description: Removes times by request of an admin
	Notes: Migrated from the admin panel to here
--]]
function Timer.RemoveListRequest( ply, varArgs )
	-- Not that people will, but people might
	if not ply.RemovingTimes then
		return Core.Print( ply, "Admin", Core.Text( "MiscIllegalAccess" ) )
	end

	local nStyle = tonumber( varArgs[ 1 ] )
	local tabContent = varArgs[ 2 ]
	local szMap = varArgs[ 3 ]
	local nView = tonumber( varArgs[ 4 ] )
	
	if nView then
		if nView == 1 then
			Core.RemoveRaceItems( ply, nStyle, szMap )
		elseif nView == 2 then
			Core.RemoveStageTimes( ply, nStyle, tonumber( tabContent ), szMap )
		elseif nView == 4 then
			Core.RemoveTASTimes( ply, nStyle, szMap )
		elseif nView == 8 then
			Core.RemoveStatsItems( ply, nStyle, szMap )
		end
		
		return
	end
	
	if not szMap then
		szMap = Timer:GetMap()
	end
	
	-- Delete the times
	local nAmount, bLocal, bMain, bHistory = 0, szMap == Timer:GetMap()
	local info = Core.GetBotInfo( nStyle )
	
	for i = 1, #tabContent do
		sql.Query( "DELETE FROM game_times WHERE szMap = '" .. szMap .. "' AND nStyle = " .. nStyle .. " AND szUID = '" .. tabContent[ i ].szUID .. "'" )
		nAmount = nAmount + 1
		
		if bLocal and info and info.Style == nStyle and info.SteamID == tabContent[ i ].szUID and info.Time == tabContent[ i ].nTime then
			bMain = true
			sql.Query( "DELETE FROM game_bots WHERE szMap = '" .. szMap .. "' AND nStyle = " .. info.Style .. " AND szSteam = '" .. info.SteamID .. "'" )
			
			local szStyle = nStyle == Styles.Normal and ".txt" or ("_" .. nStyle .. ".txt")
			if file.Exists( Config.BaseType .. "/bots/bot_" .. szMap .. szStyle, "DATA" ) then
				file.Delete( Config.BaseType .. "/bots/bot_" .. szMap .. szStyle )
			end
			
			local bot = Core.GetBot( nil, nStyle == Styles.Normal and "Main" or "Multi" )
			if IsValid( bot ) and bot.Style == nStyle then
				Core.ClearBot( bot, nStyle )
			end
		end
	end
	
	-- Check if it's the local map and not remote
	if bLocal then
		-- If local, reload everything
		Core.LoadRecords()
		
		-- Scan history runs
		local runs = Core.LoadBotHistory( nStyle )
		for i = 1, #tabContent do
			for j = 1, #runs do
				-- Required to limit this since the util.TableToJSON can't handle more decimals...
				local limited = tonumber( string.format( "%.4f", tabContent[ i ].nTime ) )
				if runs[ j ].Style == nStyle and runs[ j ].SteamID == tabContent[ i ].szUID and runs[ j ].Time == limited then
					if file.Exists( runs[ j ].FilePath, "DATA" ) then
						file.Delete( runs[ j ].FilePath )
						bHistory = true
						
						local str = runs[ j ].FilePath
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
				end
			end
		end
		
		for _,p in pairs( player.GetHumans() ) do
			for i = 1, #tabContent do
				-- Only reload their time if they match the style
				if p.UID == tabContent[ i ].szUID and p.Style == nStyle then
					p:LoadTime( true )
				end
			end
		end
	end
	
	local info, str = {}, ""
	if bLocal then info[ #info + 1 ] = "All records have been reloaded" end
	if bHistory then info[ #info + 1 ] = "History bot deleted" end
	if bMain then info[ #info + 1 ] = "Main bot deleted" end
	if #info > 0 then str = "[" .. string.Implode( "; ", info ) .. "]" end
	
	Core.Print( ply, "Admin", Core.Text( "AdminTimesRemoved", nAmount, str ) )
	Core.AddAdminLog( "Removed " .. nAmount .. " times on " .. Timer:GetMap() .. " (" .. Core.StyleName( nStyle ) .. ", " .. str .. ")", ply.UID, ply:Name() )
end
Core.Register( "Global/RemoveList", Timer.RemoveListRequest )

--[[
	Description: Sends the appropriate list to the player
	Notes: Houses Maps Left, Beat and My WR
--]]
function Core.HandlePlayerMaps( szID, ply, args )
	local nStyle, szUID = ply.Style
	if args and #args > 0 then
		if util.SteamIDTo64( args.Upper[ 1 ] ) != "0" then
			szUID = args.Upper[ 1 ]
		elseif szID == "Beat" or szID == "Left" then
			local szStyle = string.Implode( " ", args.Upper )
			local nGet = Core.GetStyleID( szStyle )
			
			if not Core.IsValidStyle( nGet ) then
				return Core.Print( ply, "General", Core.Text( "MiscInvalidStyle" ) )
			else
				nStyle = nGet
			end
		end
	end
	
	local IsRemote = szUID and szUID != ply.UID
	szUID = szUID or ply.UID
	
	if not BeatMaps[ szUID ] then
		BeatMaps[ szUID ] = {}
	end
	
	if szID == "Beat" or szID == "Left" or szID == "NoWR" then		
		if not BeatMaps[ szUID ][ nStyle ] then
			BeatMaps[ szUID ][ nStyle ] = true
			
			Prepare(
				"SELECT szMap, nTime, nPoints, nDate FROM game_times WHERE szUID = {0} AND nStyle = {1} ORDER BY nPoints ASC",
				{ szUID, nStyle },
				nil, true
			)( function( data, varArg, szError )
				if Core.Assert( data, "szMap" ) then
					local makeNum = tonumber
					for j = 1, #data do
						data[ j ]["nTime"] = makeNum( data[ j ]["nTime"] )
						data[ j ]["nPoints"] = makeNum( data[ j ]["nPoints"] )
						data[ j ]["nDate"] = makeNum( data[ j ]["nDate"] )
					end
					
					BeatMaps[ szUID ][ nStyle ] = data
				end
			end )
		end
		
		local count = BeatMaps[ szUID ][ nStyle ] and type( BeatMaps[ szUID ][ nStyle ] ) == "table" and #BeatMaps[ szUID ][ nStyle ] or -1
		if args and args.GetCount then
			if count < 0 then
				count = 0
			end
			
			return count
		end
		
		if szID == "NoWR" then
			if count <= 0 then
				return Core.Print( ply, "General", Core.Text( "CommandNoWRBeat", IsRemote and "This player hasn't" or "You haven't" ) )
			end
			
			local data, tab, cache = {}, BeatMaps[ szUID ][ nStyle ], WRTopCache[ szUID ] or {}
			for i = 1, #cache do
				for j = 1, count do
					if cache[ i ].nTime == tab[ j ].nTime then
						data[ #data + 1 ] = cache[ i ]
					end
				end
			end
			
			if #data == 0 then
				return Core.Print( ply, "General", Core.Text( "CommandNoWRNone", IsRemote and "This player doesn't" or "You don't" ) )
			elseif #data == Timer.Maps then
				return Core.Print( ply, "General", Core.Text( "CommandNoWRAll" .. (IsRemote and "Remote" or "") ) )
			end
			
			NetPrepare( "GUI/Build", {
				ID = "Maps",
				Title = "No WR maps on " .. Core.StyleName( nStyle ),
				X = 400,
				Y = 390,
				Mouse = true,
				Blur = true,
				Data = { data, Style = -1, Type = szID, Version = Core.GetMaplistVersion() }
			} ):Send( ply )
			
			return false
		end
		
		if count < 0 then
			return Core.Print( ply, "General", szID == "Left" and Core.Text( "CommandWRLeftNone", IsRemote and "This player still needs" or "You still need" ) or Core.Text( "CommandWRBeatNone", IsRemote and "This player hasn't" or "You haven't" ) )
		elseif szID == "Left" and count == Timer.Maps then
			return Core.Print( ply, "General", Core.Text( "CommandWRLeftAll", IsRemote and "This player has" or "You have" ) )
		elseif szID == "Beat" and count == 0 then
			return Core.Print( ply, "General", Core.Text( "CommandWRLeftNone", IsRemote and "This player still needs" or "You still need" ) )
		end
		
		if count > 0 and count <= Timer.Maps then
			NetPrepare( "GUI/Build", {
				ID = "Maps",
				Title = "Maps " .. szID,
				X = 400 + (szID == "Beat" and 100 or 0),
				Y = 390,
				Mouse = true,
				Blur = true,
				Data = { BeatMaps[ szUID ][ nStyle ], Style = nStyle, Type = szID, Version = Core.GetMaplistVersion() }
			} ):Send( ply )
		else
			Core.Print( ply, "General", Core.Text( "CommandWRListUnable", IsRemote and "the player hasn't" or "you haven't" ) )
		end
	elseif szID == "Mine" then
		if not BeatMaps[ szUID ][ 0 ] then
			BeatMaps[ szUID ][ 0 ] = true

			if WRTopCache[ szUID ] then
				BeatMaps[ szUID ][ 0 ] = WRTopCache[ szUID ]
			end
		end
		
		local count = BeatMaps[ szUID ][ 0 ] and type( BeatMaps[ szUID ][ 0 ] ) == "table" and #BeatMaps[ szUID ][ 0 ] or 0
		if count > 0 then
			NetPrepare( "GUI/Build", {
				ID = "Maps",
				Title = "#1 WRs (" .. count .. ")",
				X = 400,
				Y = 390,
				Mouse = true,
				Blur = true,
				Data = { BeatMaps[ szUID ][ 0 ], Style = 0, By = IsRemote and szUID }
			} ):Send( ply )
		else
			Core.Print( ply, "General", (IsRemote and "This player doesn't" or "You don't") .. " seem to have any #1 records" )
		end
	end
end

--[[
	Description: Get the keys pressed at the moment of request
	Notes: Used to see what keys to press when returning to a checkpoint with high velocity
--]]
function Timer.GetCheckpointKeys( ply )
	local szStr = ply:Crouching() and " C" or ""
	if ply:KeyDown( IN_MOVELEFT ) then
		szStr = szStr .. " A"
	elseif ply:KeyDown( IN_MOVERIGHT ) then
		szStr = szStr .. " D"
	end
	
	return szStr
end

--[[
	Description: The checkpoint request processing
--]]
function Timer.CheckpointRequest( ply, varArgs, IsForce )
	if not ply.Practice then return Core.Print( ply, "General", Core.Text( "TimerCheckpointMenuPractice" ) ) end
	if ply.CheckpointTeleport then return Core.Print( ply, "Timer", Core.Text( "TimerCheckpointWaiting" ) ) end

	local ID = varArgs[ 1 ]
	local IsDelay = varArgs[ 2 ]
	local IsDelete = varArgs[ 3 ]
	local IsWipe = varArgs[ 4 ]
	local IsFixedWrite = varArgs[ 5 ]
	local CanSave = true
	local Send = {}
	
	if not Checkpoints[ ply ] then
		Checkpoints[ ply ] = {}
	end
	
	-- This means load last loaded / load last saved
	if ID == 1 then
		ID = ply.LastCP
		CanSave, IsDelete, IsWipe = nil, nil, nil
	elseif ID == 2 then
		ID = ply.LastWriteCP
		CanSave, IsDelete, IsWipe = nil, nil, nil
	end
	
	-- Check if we're force writing
	if IsForce then
		local WriteAt = 3
		for i = 3, 9 do
			if not Checkpoints[ ply ][ i ] then
				WriteAt = i
				break
			end
		end
		
		ID = WriteAt
		Checkpoints[ ply ][ ID ] = nil
	
	-- Else find a valid ID
	elseif not ID then
		local IsAny
		for i = 3, 9 do
			if Checkpoints[ ply ][ i ] then
				IsAny = i
				break
			elseif IsFixedWrite then
				IsAny = i
				break
			end
		end
		
		if IsAny then
			ID = ply.LastCP or IsAny
			
			if not IsFixedWrite and (not ID or not Checkpoints[ ply ][ ID ]) then
				return Core.Print( ply, "Timer", Core.Text( "TimerCheckpointMissing" ) )
			end
		else
			return Core.Print( ply, "Timer", Core.Text( "TimerCheckpointLoadBlank" ) )
		end
	end
	
	if ID and IsFixedWrite then
		CanSave = true
	end
	
	-- If we have a checkpoint
	if Checkpoints[ ply ][ ID ] and not IsFixedWrite then
		if IsDelete then
			Checkpoints[ ply ][ ID ] = nil
			Send.Type = "Delete"
			Send.ID = ID
		elseif IsWipe then
			-- Iterate over all checkpoints
			for i = 3, 9 do
				Checkpoints[ ply ][ i ] = nil
			end
			
			-- Reset variables
			ply.LastCP = nil
			ply.LastWriteCP = nil
			
			Send.Type = "Wipe"
		else
			ply.LastCP = ID
			
			-- Setup the function
			local function MakeTeleport()
				if not IsValid( ply ) then return end
				if not ply.Practice or ply.Spectating then
					return Core.Print( ply, "General", Core.Text( "TimerCheckpointPractice" ) )
				end
				
				ply.CheckpointTeleport = nil
				
				local cp = Checkpoints[ ply ][ ply.LastCP ]
				ply:SetPos( cp[ 1 ] )
				ply:SetEyeAngles( cp[ 2 ] )
				ply:SetLocalVelocity( cp[ 3 ] )
			end
			
			if IsDelay then
				ply.CheckpointTeleport = true
				Send.Type = "Delay"
				
				timer.Simple( 1.5, MakeTeleport )
			else
				MakeTeleport()
			end
		end
	elseif CanSave then
		if IsDelete then
			Core.Print( ply, "Timer", Core.Text( "TimerCheckpointBlank" ) )
		elseif IsWipe then
			-- Iterate over all checkpoints
			for i = 3, 9 do
				Checkpoints[ ply ][ i ] = nil
			end
			
			-- Reset variables
			ply.LastCP = nil
			ply.LastWriteCP = nil
			
			Send.Type = "Wipe"
		else
			local pos, ang, vel = ply:GetPos(), ply:EyeAngles(), ply:GetVelocity()
			if ply.Spectating and IsValid( ply:GetObserverTarget() ) then
				local target = ply:GetObserverTarget()
				pos = target:GetPos()
				ang = target:EyeAngles()
				vel = target:GetVelocity()
			end
			
			Checkpoints[ ply ][ ID ] = { pos, ang, vel, ST() }
			Send.Type = "Add"
			Send.ID = ID
			Send.Details = string.format( "%.0f u/s%s", Checkpoints[ ply ][ ID ][ 3 ]:Length2D(), Timer.GetCheckpointKeys( ply ) )
			
			ply.LastWriteCP = ID
		end
	else
		return Core.Print( ply, "Timer", Core.Text( "TimerCheckpointLoadBlank" ) )
	end
	
	if Send.Type then
		Core.Send( ply, "GUI/UpdateCP", Send )
	end
end
Core.Register( "Global/Checkpoints", Timer.CheckpointRequest )

--[[
	Description: Handles the checkpoint commands
--]]
function Timer.CheckpointCommand( ply, args )
	-- Check if they're in practice mode or not
	if not ply.Practice and args.Key != "cphelp" then
		return Core.Print( ply, "General", Core.Text( "TimerCheckpointMenuPractice" ) )
	end
	
	-- Allocate them a spot in the checkpoint table
	if not Checkpoints[ ply ] then
		Checkpoints[ ply ] = {}
	end
	
	if args.Key == "cp" or args.Key == "cpmenu" then
		Core.Send( ply, "GUI/Create", { ID = "Checkpoints", Dimension = { x = 200, y = 332, px = 20 }, Args = { Title = "Checkpoint Menu" } } )
	elseif args.Key == "cpload" then
		Timer.CheckpointRequest( ply, {} )
	elseif args.Key == "cpsave" then
		Timer.CheckpointRequest( ply, {}, true )
	elseif args.Key == "cpset" then
		local ID = tonumber( args[ 1 ] )
		if not ID or ID < 3 or ID > 9 then
			Core.Print( ply, "Timer", Core.Text( "TimerCheckpointInvalidID" ) )
		else
			ply.LastCP = ID
			Core.Print( ply, "Timer", Core.Text( "TimerCheckpointManualSet", ID ) )
		end
	elseif args.Key == "cpwipe" or args.Key == "cpdelete" then
		local id
		if #args > 0 then
			id = tonumber( args[ 1 ] )
		end
		
		-- Iterate over all checkpoints
		for i = 3, 9 do
			if id == nil or id == i then
				Checkpoints[ ply ][ i ] = nil
			end
		end
		
		-- Reset variables
		if not id then
			ply.LastCP = nil
			ply.LastWriteCP = nil
		end
		
		Core.Send( ply, "GUI/UpdateCP", { Type = "Wipe", ID = id } )
	elseif args.Key == "cphelp" then
		Core.Print( ply, "General", Core.Text( "TimerCheckpointHelp" ) )
	end
end
Core.AddCmd( { "cp", "cpmenu", "cpload", "cpsave", "cpset", "cphelp", "cpwipe", "cpdelete" }, Timer.CheckpointCommand )

--[[
	Description: Loads everything we've got
	Used by: Gamemode initialization
--]]
function Core.LoadRecords()	
	-- Clean up Maps table for if it's a reload
	Core.CleanTable( Maps )
	
	-- Reset map count
	Timer.Maps = 0
	
	-- Set the base statistics variable
	Timer.BaseStatistics = { 0, 0 }
	
	-- Load all maps into the Maps table
	Prepare(
		"SELECT * FROM game_map ORDER BY szMap ASC",
		nil, nil, true
	)( function( data, varArg, szError )
		if Core.Assert( data, "szMap" ) then
			local makeNum, makeNull = tonumber, Core.Null
			for j = 1, #data do
				local map = data[ j ]["szMap"]
				data[ j ]["szMap"] = nil
				data[ j ]["nMultiplier"] = makeNum( makeNull( data[ j ]["nMultiplier"], 1 ) )
				data[ j ]["nBonusMultiplier"] = makeNull( data[ j ]["nBonusMultiplier"], 0 )
				data[ j ]["nPlays"] = makeNum( makeNull( data[ j ]["nPlays"], 0 ) )
				data[ j ]["nOptions"] = makeNum( makeNull( data[ j ]["nOptions"], 0 ) )
				data[ j ]["szDate"] = makeNull( data[ j ]["szDate"], "Unknown" )
				
				-- Check the bonus multiplier
				if data[ j ]["nBonusMultiplier"] != 0 then
					local nNum = makeNum( data[ j ]["nBonusMultiplier"] )
					if not nNum and string.find( data[ j ]["nBonusMultiplier"], " " ) then
						local szNums = string.Explode( " ", data[ j ]["nBonusMultiplier"] )
						for i = 1, #szNums do
							if string.find( szNums[ i ], ":", 1, true ) then
								local szSplit = string.Explode( ":", szNums[ i ] )
								szNums[ i ] = { makeNum( szSplit[ 2 ] ) }
							else
								szNums[ i ] = makeNum( szNums[ i ] ) or 0
							end
						end
						
						data[ j ]["nBonusMultiplier"] = szNums
					else
						data[ j ]["nBonusMultiplier"] = nNum or 0
					end
				else
					data[ j ]["nBonusMultiplier"] = makeNum( data[ j ]["nBonusMultiplier"] )
				end
				
				-- Load tier and type for surf
				if Config.IsSurf then
					data[ j ]["nTier"] = makeNum( makeNull( data[ j ]["nTier"], 1 ) )
					data[ j ]["nType"] = makeNum( makeNull( data[ j ]["nType"], 0 ) )
				end
				
				-- Add the map and increment
				Maps[ map ] = data[ j ]
				Timer.Maps = Timer.Maps + 1
				
				if data[ j ]["nPlays"] > Timer.BaseStatistics[ 2 ] then
					Timer.BaseStatistics[ 2 ] = data[ j ]["nPlays"]
					Timer.BaseStatistics[ 3 ] = map
				end
			end
		end
	end )
	
	-- Get the details for the current map
	local map = Timer:GetMap()
	if Maps[ map ] then
		Timer.Multiplier = Maps[ map ]["nMultiplier"] or 1
		Timer.BonusMultiplier = Maps[ map ]["nBonusMultiplier"] or 0
		Timer.Options = Maps[ map ]["nOptions"] or 0
		Timer.Plays = (Maps[ map ]["nPlays"] or 0) + 1
		Timer.Date = Maps[ map ]["szDate"] or ""
		
		-- Surf details
		Timer.Tier = Maps[ map ]["nTier"] or 1
		Timer.Type = Maps[ map ]["nType"] or 0
	else
		Timer.Multiplier = 1
		Timer.BonusMultiplier = 0
		Timer.Options = 0
		Timer.Plays = 0
		Timer.Date = ""
		
		-- Surf details
		Timer.Tier = 1
		Timer.Type = 0
	end
	
	-- When we're dealing with a new map, update its date
	if Timer.IsNewMap then
		Timer.IsNewMap = nil
		
		local szDate = Timer.GetCurrentDate( true )
		if Timer.Date == "" or Timer.Date == "Unknown" then
			Prepare( "UPDATE game_map SET szDate = {0} WHERE szMap = {1}", { szDate, map } )
			Timer.Date = szDate
			
			if Maps[ map ] and Maps[ map ]["szDate"] then
				Maps[ map ]["szDate"] = szDate
			end
		end

		return false
	end
	
	-- Add a single play to the map
	if not Timer.IsLoaded then
		Prepare( "UPDATE game_map SET nPlays = nPlays + 1, szDate = {0} WHERE szMap = {1}", { Timer.GetCurrentDate( true ), map } )
	end

	-- If the table was populated, clean out everything
	for _,v in pairs( Records ) do
		if v and type( v ) != "table" then continue end
		Core.CleanTable( v )
	end
	
	-- Pre-prepare all styles
	local StyleCounter = {}
	for _,n in pairs( Styles ) do
		if not Records[ n ] then
			Records[ n ] = {}
			StyleCounter[ n ] = 1
		end
	end
	
	-- Load all styles except for practice
	Prepare(
		"SELECT * FROM game_times WHERE szMap = {0} ORDER BY nTime ASC",
		{ Timer:GetMap() },
		nil, true
	)( function( data, varArg, szError )
		if Core.Assert( data, "szUID" ) then
			local makeNum, makeNull, styleId = tonumber, Core.Null
			for j = 1, #data do
				styleId = makeNum( data[ j ]["nStyle"] )
				data[ j ]["szMap"] = nil
				data[ j ]["nStyle"] = nil
				data[ j ]["nTime"] = makeNum( data[ j ]["nTime"] )
				data[ j ]["nPoints"] = makeNum( data[ j ]["nPoints"] )
				data[ j ]["nDate"] = makeNum( data[ j ]["nDate"] ) or 0
				data[ j ]["vData"] = makeNull( data[ j ]["vData"] )
				
				if not Records[ styleId ] then Records[ styleId ] = {} end
				if not StyleCounter[ styleId ] then StyleCounter[ styleId ] = 1 end
				
				Records[ styleId ][ StyleCounter[ styleId ] ] = data[ j ]
				StyleCounter[ styleId ] = StyleCounter[ styleId ] + 1
			end
		end
	end )
	
	if not Timer.IsLoaded then
		-- Set the statistics value
		for _,value in pairs( StyleCounter ) do
			Timer.BaseStatistics[ 1 ] = Timer.BaseStatistics[ 1 ] + value - 1
		end
		
		-- Get the total amount of times on the server
		Prepare(
			"SELECT COUNT(nTime) AS nCount FROM game_times"
		)( function( data, varArg, szError )
			if Core.Assert( data, "nCount" ) then
				Timer.BaseStatistics[ 4 ] = tonumber( data[ 1 ]["nCount"] ) or 0
			end
		end )
		
		-- Get command stats
		Timer.BaseStatistics[ 5 ], Timer.BaseStatistics[ 6 ] = Core.CountCommands()
	end
	
	-- Set all the #1 times for sending
	for style,_ in pairs( StyleCounter ) do
		Timer.ChangeTopTime( style, nil, true )
		CalcAverage( style )
	end
	
	-- Do the point sum caching
	if not Timer.IsLoaded then
		Timer.PlayerCount = {}
		Timer.PlayerLadderPos = {}
		
		Prepare(
			"SELECT nStyle, szUID, SUM(nPoints) AS nSum FROM game_times WHERE szMap != {0} GROUP BY nStyle, szUID",
			{ Timer:GetMap() },
			nil, true
		)( function( data, varArg, szError )
			local makeNum, out = tonumber, {}
			if Core.Assert( data, "nSum" ) then
				for j = 1, #data do
					local nStyle = makeNum( data[ j ]["nStyle"] )
					if not StylePoints[ nStyle ] then
						StylePoints[ nStyle ] = {}
						out[ nStyle ] = {}
					end
					
					local pts = makeNum( data[ j ]["nSum"] ) or 0
					StylePoints[ nStyle ][ data[ j ]["szUID"] ] = pts
					
					local into = out[ nStyle ]
					into[ #into + 1 ] = { UID = data[ j ]["szUID"], Pts = pts }
				end
			end
			
			for style,data in pairs( out ) do
				table.SortByMember( data, "Pts" )
				Timer.PlayerLadderPos[ style ] = {}
				
				for i = 1, #data do
					Timer.PlayerLadderPos[ style ][ data[ i ].UID ] = i
				end
			end
		end )
		
		Prepare(
			"SELECT nStyle, COUNT(DISTINCT(szUID)) AS nAmount FROM game_times GROUP BY nStyle"
		)( function( data, varArg, szError )
			local makeNum = tonumber
			if Core.Assert( data, "nAmount" ) then
				for j = 1, #data do
					Timer.PlayerCount[ makeNum( data[ j ]["nStyle"] ) ] = makeNum( data[ j ]["nAmount"] ) or 0
				end
			end
		end )
	end
	
	-- Loads all ranks and the top list
	Player:LoadRanks()
	
	-- Only do these things on first load
	if not Timer.IsLoaded then
		-- Load the zones from the database
		Zones.Load()
		
		-- Starts the RTV instance
		RTV:Start()
		
		-- Enable all extensions
		for i = 1, #Timer.PostInitFunc do
			Timer.PostInitFunc[ i ]()
		end
	end
	
	-- Set a variable to keep track of whether this has been loaded before
	Timer.IsLoaded = true
end





-- Player class
Player.LadderScalar = 1.20
Player.TopListLimit = 50

Player.MultiplierNormal = 1
Player.MultiplierBonus = 1
Player.MultiplierAngled = 1

Player.NormalScalar = 0.0001
Player.BonusScalar = 0.0001
Player.AngledScalar = 0.0001

Player.AveragePoints = 1
Player.AveragePointsCache = {}
Player.NotifyCache = {}


--[[
	Description: 
	Used by: Timer start-up, initialization
--]]
function Player:LoadRanks()
	local NormalSum, BonusSum = 0, 0
	
	-- Get the total sum of points
	for map,data in pairs( Maps ) do
		NormalSum = NormalSum + data["nMultiplier"]
		
		if type( data["nBonusMultiplier"] ) == "table" then
			for i = 1, #data["nBonusMultiplier"] do
				if type( data["nBonusMultiplier"][ i ] ) == "table" then
					data["nBonusMultiplier"][ i ] = data["nBonusMultiplier"][ i ][ 1 ]
				else
					BonusSum = BonusSum + data["nBonusMultiplier"][ i ]
				end
			end
			
			data["nBonusMultiplier"] = string.Implode( ", ", data["nBonusMultiplier"] )
		else
			BonusSum = BonusSum + data["nBonusMultiplier"]
		end
	end
	
	-- If there's no maps, we still need to be able to calculate simple ranks
	if NormalSum == 0 then NormalSum = 1 end
	if BonusSum == 0 then BonusSum = 1 end
	
	-- Set the multipliers
	self.MultiplierNormal = NormalSum
	self.MultiplierBonus = BonusSum
	self.MultiplierAngled = NormalSum / 2

	-- Set some local functionality
	local mp, c = math.pow, #Ranks
	local Exponential = function( c, n ) return c * mp( n, 2.9 ) end
	local FindScalar = function( s ) for i = 0, 50, 0.00001 do if Exponential( i, c ) > s then return i end end return 0 end
	
	-- Find scalars for the rank ladders
	local OutNormal = FindScalar( self.MultiplierNormal * self.LadderScalar )
	local OutBonus = FindScalar( self.MultiplierBonus * self.LadderScalar )
	local OutAngled = FindScalar( self.MultiplierAngled * self.LadderScalar )
	
	-- Validate them and set them
	if OutNormal > 0 and OutBonus > 0 and OutAngled > 0 then
		self.NormalScalar = OutNormal
		self.BonusScalar = OutBonus
		self.AngledScalar = OutAngled
	else
		print( "Ranking", "Couldn't calculate ranking scalar. Make sure you have at least ONE entry in your game_map!" )
	end
	
	-- Generate additional columns for the rank list
	for i = 1, c do
		Ranks[ i ][ 3 ] = Exponential( self.NormalScalar, i )
		Ranks[ i ][ 4 ] = Exponential( self.BonusScalar, i )
		Ranks[ i ][ 5 ] = Exponential( self.AngledScalar, i )
	end
	
	-- Continue with loading the top lists when we're doing the first load
	if not Timer.IsLoaded then
		self:LoadTopLists()
		self:LoadNotifyCache()
	end
end

--[[
	Description: Loads the full top list of players into a table
--]]
function Player:LoadTopLists()
	-- Get all styles to be ranked
	Prepare(
		"SELECT DISTINCT(nStyle) FROM game_times ORDER BY nStyle ASC"
	)( function( data, varArg, szError )
		if Core.Assert( data, "nStyle" ) then
			for j = 1, #data do
				local style = tonumber( data[ j ]["nStyle"] )
				
				-- Check if bonus
				if Core.IsValidBonus( style ) then
					style = Styles.Bonus
				end
				
				-- Create a blank table for this style
				if not TopListCache[ style ] then
					TopListCache[ style ] = {}
				elseif style == Styles.Bonus then
					continue
				end
				
				-- Get the top players for the selected style
				Prepare(
					"SELECT szUID, SUM(nPoints) as nSum FROM game_times WHERE nStyle " .. (style == Styles.Bonus and ">" or "") .. "= {0} GROUP BY szUID ORDER BY nSum DESC LIMIT {1}",
					{ style, self.TopListLimit },
					nil, true
				)( function( data, varArg, szError )
					if Core.Assert( data, "nSum" ) then
						local makeNum = tonumber
						for j = 1, #data do
							data[ j ]["nSum"] = makeNum( data[ j ]["nSum"] )
							
							-- Insert the entry to the total table
							TopListCache[ style ][ j ] = data[ j ]
						end
					end
				end )
				
				-- Check if there is any
				if TopListCache[ style ][ 1 ] and TopListCache[ style ][ 1 ].szUID then
					Timer.Top[ style ] = TopListCache[ style ][ 1 ].szUID
				end
			end
		end
	end )
	
	-- Set a variable to track most WRs
	local TopWRTrack = {}
	Timer.TopWRPlayer = {}
	
	-- Fetch all #1 WRs for each map on each style
	Prepare(
		"SELECT * FROM (SELECT * FROM game_times ORDER BY nTime DESC) GROUP BY szMap, nStyle ORDER BY nStyle ASC",
		nil, nil, true
	)( function( data, varArg, szError )
		if Core.Assert( data, "nTime" ) then
			local makeNum = tonumber
			for j = 1, #data do
				local id = data[ j ]["szUID"]
				local count = 1
				
				if not WRTopCache[ id ] then
					WRTopCache[ id ] = {}
				else
					count = #WRTopCache[ id ] + 1
				end
				
				data[ j ]["szUID"] = nil
				data[ j ]["nStyle"] = makeNum( data[ j ]["nStyle"] )
				data[ j ]["nTime"] = makeNum( data[ j ]["nTime"] )
				data[ j ]["nPoints"] = makeNum( data[ j ]["nPoints"] )
				data[ j ]["nDate"] = makeNum( data[ j ]["nDate"] )
				
				local style = data[ j ]["nStyle"]
				if not TopWRTrack[ style ] then
					TopWRTrack[ style ] = {}
				end
				
				TopWRTrack[ style ][ id ] = (TopWRTrack[ style ][ id ] or 0) + 1
				
				-- Insert the entry to the total table
				WRTopCache[ id ][ count ] = data[ j ]
			end
		end
	end )
	
	-- Compute the top WR players
	for style,data in pairs( TopWRTrack ) do
		local topn, topu = 0
		
		-- Loop over all data
		for uid,count in pairs( data ) do
			if count > topn then
				topn = count
				topu = uid
			end
		end
		
		-- Set the top WR player for the style
		Timer.TopWRPlayer[ style ] = topu
	end
	
	-- Copy over the tracking list for further usage
	Timer.TopWRList = TopWRTrack
	
	-- Compute data for total rank
	Prepare(
		"SELECT AVG(nPoints) AS nPoints FROM game_times"
	)( function( data, varArg, szError )
		if Core.Assert( data, "nPoints" ) then
			Player.AveragePoints = tonumber( data[ 1 ]["nPoints"] ) or 1
		end
	end )
end

--[[
	Description: Loads the WR beaten notifications
--]]
function Player:LoadNotifyCache()
	-- Determine the maximum age
	local nThreshold = os.time() - (3600 * 24 * 14)
	
	-- Delete all old entries
	Prepare(
		"DELETE FROM game_notifications WHERE nDate < {0}",
		{ nThreshold }
	)
	
	-- Fetch all valid notifications
	Prepare(
		"SELECT * FROM game_notifications"
	)( function( data, varArg, szError )
		if Core.Assert( data, "szUID" ) then
			for j = 1, #data do
				local id = data[ j ]["szUID"]
				if not Player.NotifyCache[ id ] then
					Player.NotifyCache[ id ] = {}
				end
				
				table.insert( Player.NotifyCache[ id ], data[ j ] )
			end
		end
	end )
end


--[[
	Description: Loads the player's rank according to their points
	Used by: Rank functions
--]]
function PLAYER:LoadTime( bReload, bPractice )
	-- For practice mode we don't really have to load a time
	if self.Practice then
		self.Record = 0
		self.Leaderboard = 0
		
		self:SetObj( "Record", self.Record, bReload )
		self:SetObj( "Position", self.Leaderboard, bReload )
		
		-- Only when it's actually changed
		if self.SpecialRank != nil then
			self.SpecialRank = nil
			self:SetObj( "SpecialRank", self.SpecialRank, bReload )
		end
		
		-- Send the record
		local ar = NetPrepare( "Timer/Record" )
		ar:Double( self.Record )
		
		ar:Bit( true )
		ar:UInt( self.Style, 8 )
		ar:Bit( not not bPractice )
		
		ar:Bit( false )
		ar:Send( self )
		
		return false
	end
	
	-- For TAS, we direct it elsewhere
	if self.TAS then return self.TAS.LoadRecord( self, self.Style ) end

	-- Obtain their position in the ladder for their style
	local t, r = Timer.GetPlayerRecord( self )
	self.Record = t
	self.Leaderboard = r
	self:SetObj( "Record", self.Record, bReload )
	self:SetObj( "Position", self.Leaderboard, bReload )
	
	-- Send the data for fast GUI drawing
	local ar = NetPrepare( "Timer/Record" )
	ar:Double( self.Record )
	
	ar:Bit( true )
	ar:UInt( self.Style, 8 )
	ar:Bit( false )
	
	ar:Bit( false )
	ar:Send( self )
	
	-- For the top 3, give them a medal
	if r <= 3 then
		Player.SetRankMedal( self, r, bReload )
	elseif self.SpecialRank then
		self.SpecialRank = nil
		self:SetObj( "SpecialRank", self.SpecialRank )
	end
end

--[[
	Description: Loads the player's rank according to their points
	Used by: Rank functions
--]]
function PLAYER:LoadRank( bJoin, bReload )
	local nStyle = self.Style
	
	-- When on Practice, we reset all data
	if self.Practice then
		self.Rank = -10
		self:SetObj( "Rank", self.Rank, bReload )
		
		self.SubRank = 0
		self:SetObj( "SubRank", self.SubRank, bReload )
		
		self.CurrentPointSum = 0
		self.CurrentMapSum = 0
	else
		-- For TAS, we direct it elsewhere
		if self.TAS then return self.TAS.LoadRank( self ) end
		
		-- Obtain the data from the cache and database
		Player.GetPointSum( self, nStyle, bJoin, function( ply, Points, MapPoints )
			-- Only update if the whole rank is actually different
			local Rank = Player.GetRank( Points, Player.GetRankType( nStyle ) )
			if Rank != ply.Rank then
				ply.Rank = Rank
				ply:SetObj( "Rank", ply.Rank, bReload )
			end
			
			-- Set the current values for later usage
			ply.CurrentPointSum = Points
			ply.CurrentMapSum = MapPoints
			
			-- Set their sub rank
			Player.SetSubRank( ply, Rank, Points, bReload )
		end )
	end
	
	-- On the first join, give them the scalars
	if bJoin then
		local ar = NetPrepare( "Timer/Ranks" )
		ar:Double( Player.NormalScalar )
		ar:Double( Player.BonusScalar )
		ar:Double( Player.AngledScalar )
		ar:Send( self )
	end
end

--[[
	Description: Loads the player into a new style and sets the appropriate values
	Used by: Commands
--]]
function PLAYER:LoadStyle( nStyle, nBonus )
	-- Validate the style again
	if not nStyle or (nStyle < Styles.Normal and not Config.Modes[ nStyle ]) or nStyle > Config.MaxStyle then return end

	-- If we're setting a bonus style, add the bonus ID to the style
	if nBonus then
		nStyle = nStyle + nBonus
	end
	
	-- Set the style variables
	local OldStyle, PreviousStyle, NextPractice = self.Style, self.Style
	if nStyle == Config.PracticeStyle then
		if not self.Practice then
			-- Clean the bot, of course
			self:CleanFrames()
			self:SetBotActive( nil )
			
			-- Set the style to the style we were on at first
			self.Style = OldStyle
			self:SetObj( "Style", self.Style )
			
			-- Enable practice mode on server and client
			self.Practice = true
			OldStyle = true
		else
			-- Set the style to the style we were on
			self.Style = OldStyle
			self:SetObj( "Style", self.Style )
			
			-- Disable the practice mode and update client
			self.Practice = nil
			OldStyle = nil
			NextPractice = true
		end
	else
		if self.Practice then
			if not Core.IsValidBonus( nStyle ) then
				-- Send a message about practice mode
				Core.Print( self, "Timer", Core.Text( "StylePracticeEnabled" ) )
			end
			
			-- Make sure we're good with the styles
			self.Style = nStyle
			self:SetObj( "Style", self.Style )
			
			-- Update on the client (just a double measure)
			OldStyle = true
		else
			-- Set the styles
			self.Style = nStyle
			self:SetObj( "Style", self.Style )
			
			-- Make sure we change style normally
			OldStyle = nil
		end
	end
	
	if not OldStyle then
		-- Reset without copying function addresses
		concommand.Run( self, "reset", "bypass", "" )
	end
	
	-- Reset attributes
	ResetPlayerAttributes( self, PreviousStyle )
	
	-- Now loads the actual values in
	self:LoadTime( nil, OldStyle )
	self:LoadRank()
	
	-- Publish all variable changes
	self:PublishObj()
	
	-- Let them know what happened
	local PracticeText = ""
	if OldStyle == true then
		PracticeText = " (With practice mode enabled)"
	elseif NextPractice then
		PracticeText = " (Disabled practice mode)"
	end
	
	Core.Print( self, "Timer", Core.Text( "StyleChange", Core.StyleName( self.Style ), PracticeText ) )
end


--[[
	Description: Gets the amount of points you have in a specific style
	Used by: Rank functions
--]]
function Player.GetPointSum( ply, nStyle, bJoin, fCall )
	-- Forces style to bonus
	if Core.IsValidBonus( nStyle ) then
		nStyle = Styles.Bonus
	end
	
	-- Fetch the data
	if (not StylePoints[ nStyle ] or not StylePoints[ nStyle ][ ply.UID ]) and not bJoin then
		Prepare(
			"SELECT SUM(nPoints) AS nSum FROM game_times WHERE szUID = {0} AND nStyle " .. (nStyle == Styles.Bonus and ">" or "") .. "= {1} AND szMap != {2}",
			{ ply.UID, nStyle, Timer:GetMap() }
		)( function( data, varArg, szError )
			local OtherPoints = 0
			if Core.Assert( data, "nSum" ) then
				OtherPoints = tonumber( data[ 1 ]["nSum"] ) or 0
				
				if StylePoints[ nStyle ] then
					StylePoints[ nStyle ][ ply.UID ] = OtherPoints
				end
			end
			
			local MapPoints = Timer.GetPointsForMap( ply, ply.Record, nStyle )
			fCall( ply, OtherPoints + MapPoints, MapPoints )
		end )
	else
		local MapPoints = Timer.GetPointsForMap( ply, ply.Record, nStyle )
		fCall( ply, (StylePoints[ nStyle ][ ply.UID ] or 0) + MapPoints, MapPoints )
	end
end

--[[
	Description: Gets your rank using a given amount of points against a certain ladder type
	Used by: Rank functions
--]]
function Player.GetRank( nPoints, nType )
	local Rank = 1
	
	for i = 1, #Ranks do
		if i > Rank and nPoints >= Ranks[ i ][ nType ] then
			Rank = i
		end
	end

	return Rank
end

--[[
	Description: Obtains the type of rank ladder for the style
	Used by: Rank functions
--]]
function Player.GetRankType( nStyle )
	return Config.RankColumns[ nStyle ] or 3
end

--[[
	Description: Reloads the rank and sub rank on all relevant players
	Used by: Time adding system
--]]
function Player.SetSubRank( ply, nRank, nPoints, bReload )
	-- Check if the player is the one with most WRs
	local nTarget
	if Timer.TopWRPlayer[ ply.Style ] == ply.UID then
		nTarget = ply.Style == Styles.Normal and 13 or 11
	end
	
	-- Checks if you're top rank or not
	if nRank >= #Ranks or nTarget then
		if not nTarget then
			-- Set the default value
			nTarget = 10
			
			-- Check if they are at the top
			local style = Core.IsValidBonus( ply.Style ) and Styles.Bonus or ply.Style
			if Timer.Top[ style ] == ply.UID then
				nTarget = 12
			end
		end
		
		-- Sets it to the custom rank icons
		if ply.SubRank != nTarget then
			ply.SubRank = nTarget
			ply:SetObj( "SubRank", ply.SubRank, bReload )
		end
	else
		-- Get the column id
		local ColID = Player.GetRankType( ply.Style )
		
		-- Calculate the step size over 10 steps in between
		local StepSize = (Ranks[ nRank + 1 ][ ColID ] - Ranks[ nRank ][ ColID ]) / 10
		
		-- Iterate over all steps and see in which they fall
		local nOut, nStep = 1, 1
		for i = Ranks[ nRank ][ ColID ], Ranks[ nRank + 1 ][ ColID ], StepSize do
			if nPoints >= i then
				nOut = nStep
			end
			
			nStep = nStep + 1
		end
		
		-- Only change sub rank if it's different
		if ply.SubRank != nOut then
			ply.SubRank = nOut
			ply:SetObj( "SubRank", ply.SubRank, bReload )
		end
	end
end

--[[
	Description: Reloads the rank and sub rank on all relevant players
	Used by: Time adding system
--]]
function Player.ReloadRanks( sender, nStyle, nOldAverage )
	-- Get the multiplier for the given style
	local nMultiplier = Timer:GetMultiplier( nStyle )
	if nMultiplier == 0 then return end
	
	-- Create a new table for changed players
	local plys = {}
	
	-- Get the new average
	local nAverage = GetAverage( nStyle )
	for _,p in pairs( player.GetHumans() ) do
		-- Only reload for relevant players
		if p == sender or p.Style != nStyle or p.Record == 0 or not p.CurrentPointSum then continue end

		local CurrentPoints = Timer.GetPointsForMap( p, p.Record, p.Style, nOldAverage )
		local NewPoints = Timer.GetPointsForMap( p, p.Record, p.Style, nAverage )
		local Points = p.CurrentPointSum - CurrentPoints + NewPoints
		
		local Rank = Player.GetRank( Points, Player.GetRankType( p.Style ) )
		if Rank != p.Rank then
			p.Rank = Rank
			p:SetObj( "Rank", p.Rank )
		end
		
		-- Set the new sum for future reloads
		p.CurrentPointSum = Points

		-- Also reload their sub rank
		Player.SetSubRank( p, p.Rank, p.CurrentPointSum )
		
		-- Get their new leaderboard id
		local t, r = Timer.GetPlayerRecord( p )
		if r != p.Leaderboard then
			p.Leaderboard = r
			p:SetObj( "Position", p.Leaderboard )
		end
		
		-- Add this player to the broadcast list
		plys[ #plys + 1 ] = p
	end
	
	-- Commit the changes
	Core.PublishPlayers( plys )
end

--[[
	Description: Sets the player's medal
	Used by: New record obtaining, joining functions
--]]
function Player.SetRankMedal( ply, nPos, bReload )
	if not bReload then
		ply.SpecialRank = nPos
		ply:SetObj( "SpecialRank", ply.SpecialRank )
	else
		local nStyle = ply.Style
		local list = Timer.GetTopSteam( nStyle, 3 ) -- Gets the top 3 steam ids
		
		local function HasValue( tab, v )
			for i = 1, #tab do
				if tab[ i ] == v  then
					return i
				end
			end
		end
		
		for _,p in pairs( player.GetHumans() ) do
			if p.Style != nStyle then continue end
			local AtID = HasValue( list, p.UID )
			if AtID then
				p.SpecialRank = AtID
				p:SetObj( "SpecialRank", p.SpecialRank, true )
			elseif p.SpecialRank then
				p.SpecialRank = nil
				p:SetObj( "SpecialRank", p.SpecialRank, true )
			end
		end
	end
end

--[[
	Description: Gets the details of a player and returns it to the requesting player
--]]
function Player.ReceiveScoreboard( ply, varArgs )
	local id, target = varArgs[ 1 ]
	for _,p in pairs( player.GetHumans() ) do
		if p.UID == id then
			target = p
			break
		end
	end
	
	if IsValid( target ) then
		local tab = { WRs = Timer.GetPlayerWRs( target.UID, target.Style ) }
		tab.Target = target.UID
		tab.Online = target.ConnectedAt and ST() - target.ConnectedAt or 0
		tab.Timer = (target.Tb and not target.TbF) and ST() - target.Tb or ((target.Tn and not target.TnF) and ST() - target.Tn or -1) or -1
		tab.Stage = not target.Practice and target.TnId
		tab.TAS = target.TAS and (target.TAS.GetTimer( target ) or 0)
		
		-- Fetch the average points
		if not Player.AveragePointsCache[ target ] then
			Prepare(
				"SELECT AVG(nPoints) AS nPoints FROM game_times WHERE szUID = {0}",
				{ target:SteamID() }
			)( function( data, varArg, szError )
				if Core.Assert( data, "nPoints" ) then
					Player.AveragePointsCache[ target ] = tonumber( data[ 1 ]["nPoints"] ) or 0
				else
					Player.AveragePointsCache[ target ] = 0
				end
			end )
		end
		
		tab.TotalRank = math.Round( (Player.AveragePointsCache[ target ] / Player.AveragePoints) * 100.0, 1 )
		tab.MapPoints = { math.Round( Timer.GetPointsForMap( target, target.Record, target.Style ), 2 ), Timer:GetMultiplier( target.Style ) }
		tab.MapsBeat = Core.HandlePlayerMaps( "Beat", target, { GetCount = true } ) or 0
		
		Core.Send( ply, "GUI/Scoreboard", tab )
	end
end
Core.Register( "Global/Scoreboard", Player.ReceiveScoreboard )

--[[
	Description: Gets geographic location of the IP
	Used: Player profiles
--]]
function Player.GetGeoLocation( ply, ip, callback )
	if not ip then
		return callback()
	end
	
	if not Player.GeoLocations then
		Player.GeoLocations = {}
	end
	
	if not Player.GeoLocations[ ip ] then
		Core.Print( ply, "General", Core.Text( "CommandProfileFetching" ) )
		
		http.Fetch(
			"http://www.geoplugin.net/json.gp?ip=" .. ip,
			function( body )
				local json = util.JSONToTable( body ) or {}
				if json.geoplugin_countryCode and json.geoplugin_countryName and json.geoplugin_countryCode != "" then
					Player.GeoLocations[ json.geoplugin_request ] = { Code = json.geoplugin_countryCode, Name = json.geoplugin_countryName }
					return callback( Player.GeoLocations[ json.geoplugin_request ] )
				end
				
				callback()
			end,
			function()
				callback()
			end
		)
	else
		callback( Player.GeoLocations[ ip ] )
	end
end

--[[
	Description: Shows the target player information on the given player
--]]
function Player.ShowProfile( ply, steam, ip )
	if ply.FetchingProfile then
		return Core.Print( ply, "General", Core.Text( "CommandProfileBusy" ) )
	end
	
	ply.FetchingProfile = true
	
	Player.GetGeoLocation( ply, ip, function( loc )
		local tab = {}
		tab.Steam = steam
		tab.Location = loc and loc.Name
		
		local wrs = Timer.GetPlayerWRs( steam, nil, true )
		local sortable = {}
		
		for style,count in pairs( wrs.Rest or {} ) do
			sortable[ #sortable + 1 ] = { Style = style, Count = count }
		end
		
		tab.WRs = wrs[ 1 ]
		table.SortByMember( sortable, "Count" )
		
		if #sortable > 0 then
			tab.PrimeWR = {}
			
			for i = 1, #sortable do
				tab.PrimeWR[ i ] = { Core.StyleName( sortable[ i ].Style ), sortable[ i ].Count }
			end
		end
		
		tab.Points = {}
		tab.TopPoints = {}
		tab.PlayerPos = {}
		tab.Players = Timer.PlayerCount or {}
		
		Prepare(
			"SELECT nStyle, SUM(nPoints) AS nSum FROM game_times WHERE szUID = {0} GROUP BY nStyle",
			{ steam }
		)( function( data, varArg, szError )
			if Core.Assert( data, "nSum" ) then
				for j = 1, #data do
					local style = tonumber( data[ j ]["nStyle"] )
					local points = tonumber( data[ j ]["nSum"] ) or 0
					
					if Core.IsValidBonus( style ) then
						tab.Points[ Styles.Bonus ] = (tab.Points[ Styles.Bonus ] or 0) + points
					else
						tab.Points[ style ] = points
					end
				end
			end
		end )
		
		for style,data in pairs( Timer.PlayerLadderPos ) do
			tab.PlayerPos[ style ] = data[ steam ] or 0
		end
		
		for style,data in pairs( TopListCache ) do
			if data[ 1 ] and data[ 1 ]["nSum"] then
				tab.TopPoints[ style ] = data[ 1 ]["nSum"]
			end
		end
		
		tab.MapsBeat = Core.HandlePlayerMaps( "Beat", { UID = steam, Style = 1 }, { "Filler", Upper = { steam }, GetCount = true } ) or 0
		tab.MapsTotal = Timer.Maps
		
		Prepare(
			"SELECT COUNT(szMap) AS nCount FROM game_stagetimes WHERE szUID = {0} AND nStyle = 1",
			{ steam }
		)( function( data, varArg, szError )
			if Core.Assert( data, "nCount" ) then
				tab.CPRs = tonumber( data[ 1 ]["nCount"] ) or 0
			end
		end )
		
		Prepare(
			"SELECT szMap, nStyle, nTime, nDate FROM game_times WHERE szUID = {0} ORDER BY nDate DESC LIMIT 10",
			{ steam }
		)( function( data, varArg, szError )
			if Core.Assert( data, "nDate" ) then
				tab.Recent = data
			end
		end )
		
		Core.Send( ply, "GUI/Create", { ID = "Profile", Dimension = { x = 200, y = 100, px = 20 }, Args = { Title = "Player Profile", Custom = tab } } )
		ply.FetchingProfile = nil
	end )
end
Core.ShowProfile = Player.ShowProfile

--[[
	Description: Handles a player's full connection
--]]
function Player.ReceiveEntry( ply, varArgs )
	-- Make sure the player also receives all player data
	ply:InitialObj()

	-- Sending the platforms
	if varArgs.Platforms then
		Zones.SendPlatforms( ply )
	end
	
	-- Check if we want the simple HUD
	if varArgs.Simple then
		Core.Trigger( "Global/Simple", { true }, nil, ply )
	end
	
	-- Check if we have perma sync on
	if varArgs.Sync then
		Core.Trigger( "Global/PermSync", { true }, nil, ply )
	end
	
	-- Check if we want a model
	if varArgs.Model then
		Core.Trigger( "Global/Model", { varArgs.Model, true }, nil, ply )
	end
	
	-- Check if we want the simple HUD
	if varArgs.Third then
		Core.Trigger( "Global/Thirdperson", { true }, nil, ply )
	end
	
	-- Check if we have the time kicker on
	if varArgs.Kick then
		local func = Core.GetCmd( "remainingtries" )
		func( ply, { "time", varArgs.Kick, Key = "remainingtries" } )
	end
	
	-- Check if there's a custom style to be applied
	if ply.CustomStyleFunc then
		ply:CustomStyleFunc()
	elseif varArgs.Style then
		if tonumber( varArgs.Style ) and ply.Style != varArgs.Style then
			concommand.Run( ply, "style", tostring( varArgs.Style ), "" )
		end
	end
	
	-- Check if something went wrong with the RTV system
	if ST() > RTV.End and (timer.TimeLeft( RTV.Identifier ) or 0) > 30 * 60 and not RTV.ResetBreak then
		RTV.ResetBreak = true
		RTV:ResetVote( "Yes", 1, false, "VoteFailure" )
	end
end
Core.Register( "Global/Entry", Player.ReceiveEntry )

--[[
	Description: Prints any type of message as a replacement to the regular notifications that used to be in place
--]]
function Player.Notification( ply, szType, details )
	local colors = Config.Colors
	
	if szType == "BaseFinish" then
		local viewers = ply:Spectator( "Get", { true } )
		local szMessage = Core.ColorText()
		local szMessageRemote = Core.ColorText()
		
		if Core.IsValidBonus( ply.Style ) then
			szMessage:Add( "You finished bonus [" )
			szMessage:Add( Core.StyleName( ply.Style ), colors[ 1 ], true )
			szMessage:Add( "] in " )
			szMessage:Add( Timer.Convert( details.Time ), colors[ 2 ], true )
			
			if details.Difference != "" then
				szMessage:Add( " (" )
				szMessage:Add( details.Difference, colors[ 1 ], true )
				szMessage:Add( ")" )
			end
			
			if #viewers > 0 then
				szMessageRemote:Copy( szMessage )
				szMessageRemote:Replace( 1, 4, ply:Name(), colors[ 1 ], true )
				szMessageRemote:Add( " (" .. details.Jumps .. " jumps, " .. details.Strafes .. " strafes with " .. details.Sync .. "% sync)" )
			end
		else
			szMessage:Add( "You finished" )
			
			if ply.Style > Styles.Normal then
				szMessage:Add( " " .. Core.StyleName( ply.Style ), colors[ 4 ], true )
			end
			
			szMessage:Add( " in " )
			szMessage:Add( Timer.Convert( details.Time ), colors[ 2 ], true )
			
			if details.Difference != "" then
				szMessage:Add( " (" )
				szMessage:Add( details.Difference, colors[ 1 ], true )
				szMessage:Add( ")" )
			end
			
			if #viewers > 0 then
				szMessageRemote:Copy( szMessage )
				szMessageRemote:Replace( 1, 4, ply:Name(), colors[ 1 ], true )
				szMessageRemote:Add( " (" .. details.Jumps .. " jumps, " .. details.Strafes .. " strafes with " .. details.Sync .. "% sync)" )
			end
		end
		
		local ar = NetPrepare( "Timer/Finish" )
		ar:Double( details.Time )
		ar:UInt( details.Jumps, 16 )
		ar:UInt( details.Strafes, 16 )
		ar:Double( details.Sync )
		
		if details.Points then
			ar:Bit( true )
			ar:Double( details.Points )
		else
			ar:Bit( false )
		end
		
		ar:ColorText( szMessage:Get() )
		ar:Send( ply )
		
		if #viewers > 0 and szMessageRemote:Count() > 0 then
			ar = NetPrepare( "NotifyMulti" )
			ar:String( szType )
			ar:ColorText( szMessageRemote:Get() )
			ar:Send( viewers )
		end
	elseif szType == "ImproveFinish" then
		local szMessage = Core.ColorText()
		local szMessageTop = Core.ColorText()
		
		if Core.IsValidBonus( details.Style ) then
			szMessage:Add( ply:Name(), colors[ 1 ], true )
			szMessage:Add( " finished bonus [" )
			szMessage:Add( Core.StyleName( details.Style ), colors[ 1 ], true )
			szMessage:Add( "] in " )
			szMessage:Add( Timer.Convert( details.Time ), colors[ 2 ], true )
			
			if details.DifferenceWR != "" then
				szMessage:Add( " (" )
				szMessage:Add( details.DifferenceWR, colors[ 1 ], true )
				
				if details.Improvement != -1 then
					szMessage:Add( ", " )
					szMessage:Add( "Improved by " .. details.Improvement, colors[ 3 ], true )
				end
				
				szMessage:Add( ")" )
			end
			
			szMessage:Add( " [Rank " .. details.Rank .. "]" )
			
			if details.MapRecord then
				szMessageTop:Add( ply:Name(), colors[ 1 ], true )
				szMessageTop:Add( " took the #1 place in the " )
				szMessageTop:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
				szMessageTop:Add( " leaderboards!" )
				
				if details.Bot then
					szMessageTop:Add( " The bot is now displaying this run!" )
				end
			else
				local space = ""
				
				if details.Bot then
					szMessageTop:Add( space .. "The bot is now displaying this run since it is the fastest run available!" )
				end
			end
			
			-- To make sure we don't have Bonus 2 showing up with Bonus disabled
			if details.Style != Styles.Bonus then
				details.Style = Styles.Bonus
			end
		else
			szMessage:Add( ply:Name(), colors[ 1 ], true )
			szMessage:Add( " finished " )
			
			if details.Style > Styles.Normal then
				szMessage:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
				szMessage:Add( " in " )
			else
				szMessage:Add( "in " )
			end
			
			szMessage:Add( Timer.Convert( details.Time ), colors[ 2 ], true )
			
			if details.DifferenceWR != "" then
				szMessage:Add( " (" )
				szMessage:Add( details.DifferenceWR, colors[ 1 ], true )
				
				if details.Improvement != -1 then
					szMessage:Add( ", " )
					szMessage:Add( "Improved by " .. details.Improvement, colors[ 3 ], true )
				end
				
				szMessage:Add( ")" )
			end
			
			szMessage:Add( " [Rank " .. details.Rank .. "]" )
			
			if details.MapRecord then
				szMessageTop:Add( ply:Name(), colors[ 1 ], true )
				
				if details.Style > Styles.Normal then
					szMessageTop:Add( " took the #1 place in the " )
					szMessageTop:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
					szMessageTop:Add( " leaderboards!" )
				else
					szMessageTop:Add( " took the #1 place in the Normal leaderboards!" )
				end
				
				if details.Bot then
					szMessageTop:Add( " The bot is now displaying this run!" )
				end
			else
				local space = ""
				
				if details.Bot then
					szMessageTop:Add( space .. "The bot is now displaying this run since it is the fastest run available!" )
				end
			end
		end
		
		local ar = NetPrepare( "NotifyMulti" )
		ar:String( szType )
		ar:ColorText( szMessage:Get() )
		ar:UInt( details.Pos, 16 )
		ar:UInt( details.Style, 8 )
		ar:UInt( ply:EntIndex(), 16 )
		
		if details.Sound then
			ar:Bit( true )
			ar:String( details.Sound )
		else
			ar:Bit( false )
		end
		
		if szMessageTop:Count() > 0 then
			ar:Bit( true )
			ar:ColorText( szMessageTop:Get() )
		else
			ar:Bit( false )
		end
		
		ar:Broadcast()
	elseif szType == "StageSlow" then
		local viewers = ply:Spectator( "Get", { true } )
		local szText = details.Linear and "Checkpoint " or "Stage "
		local szMessage = Core.ColorText()
		local szMessageRemote = Core.ColorText()
		
		szMessage:Add( "You finished [" )
		szMessage:Add( szText .. details.ID, colors[ 1 ], true )
		szMessage:Add( "]" )
		
		if details.Style > Styles.Normal then
			szMessage:Add( " on " )
			szMessage:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
		end
		
		szMessage:Add( " in " )
		szMessage:Add( Timer.Convert( details.Time ), colors[ 2 ], true )
		
		if details.DifferencePB != "" then
			szMessage:Add( " (" )
			szMessage:Add( details.DifferencePB, colors[ 3 ], true )
			
			if details.DifferenceWR != "" then
				szMessage:Add( ", " )
				szMessage:Add( details.DifferenceWR, colors[ 1 ], true )
			end
			
			szMessage:Add( ")" )
		end
		
		if #viewers > 0 then
			szMessageRemote:Copy( szMessage )
			szMessageRemote:Replace( 1, 4, ply:Name(), colors[ 1 ], true )
		end
		
		local ar = NetPrepare( "NotifyMulti" )
		ar:String( szType )
		ar:ColorText( szMessage:Get() )
		ar:Bit( false )
		ar:Send( ply )
		
		if #viewers > 0 and szMessageRemote:Count() > 0 then
			ar = NetPrepare( "NotifyMulti" )
			ar:String( szType )
			ar:ColorText( szMessageRemote:Get() )
			ar:Bit( true )
			ar:Send( viewers )
		end
	elseif szType == "StageFast" then
		local szText = details.Linear and "Checkpoint " or "Stage "
		local szMessage = Core.ColorText()
		local szMessageTop = Core.ColorText()
		local szMessageRemote = Core.ColorText()
		
		szMessage:Add( "You finished [" )
		szMessage:Add( szText .. details.ID, colors[ 1 ], true )
		szMessage:Add( "]" )
		
		if details.Style > Styles.Normal then
			szMessage:Add( " on " )
			szMessage:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
		end
		
		szMessage:Add( " in " )
		szMessage:Add( Timer.Convert( details.Time ), colors[ 2 ], true )
		
		if details.DifferenceWR != "" then
			szMessage:Add( " (" )
			szMessage:Add( details.DifferenceWR, colors[ 1 ], true )
			
			if details.DifferencePB != "" then
				szMessage:Add( ", " )
				szMessage:Add( details.DifferencePB, colors[ 3 ], true )
			end
			
			szMessage:Add( ")" )
		end
		
		szMessage:Add( " [Rank " .. details.Rank .. "]" )
		
		szMessageRemote:Copy( szMessage )
		szMessageRemote:Replace( 1, 4, ply:Name(), colors[ 1 ], true )
		
		if details.Pos == 1 then
			szMessageTop:Add( ply:Name(), colors[ 1 ], true )
			
			if details.Style > Styles.Normal then
				szMessageTop:Add( " took the " )
				szMessageTop:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
				szMessageTop:Add( " record for [" )
			else
				szMessageTop:Add( " took the record for [" )
			end
			
			szMessageTop:Add( szText .. details.ID, colors[ 1 ], true )
			szMessageTop:Add( "]" )
			
			if details.Bot then
				szMessageTop:Add( "\nThe bot can now display this run!" )
			end
		end
		
		local ar = NetPrepare( "NotifyMulti" )
		ar:String( szType )
		ar:ColorText( szMessage:Get() )
		ar:ColorText( szMessageRemote:Get() )
		
		if szMessageTop:Count() > 0 then
			ar:Bit( true )
			ar:ColorText( szMessageTop:Get() )
		else
			ar:Bit( false )
		end
		
		ar:UInt( details.Pos, 16 )
		ar:UInt( details.Style, 8 )
		ar:UInt( ply:EntIndex(), 16 )
		
		ar:Broadcast()
	elseif szType == "TAS" then
		Core.Print( ply, "Timer", Core.Text( "TASTimerWR", Core.StyleName( details.Style ) ) )
		
		local szMessageTop = Core.ColorText()
		szMessageTop:Add( "[TAS] " )
		szMessageTop:Add( ply:Name(), colors[ 1 ], true )
		szMessageTop:Add( " made a new " )
		szMessageTop:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
		szMessageTop:Add( " run, with a time of " )
		szMessageTop:Add( Timer.Convert( details.Time ), colors[ 2 ], true )
		
		local ar = NetPrepare( "NotifyMulti" )
		ar:String( szType )
		ar:ColorText( szMessageTop:Get() )
		ar:Broadcast()
	elseif szType == "Popup" then
		if Popups[ ply ] and ST() - Popups[ ply ] < 1 then return end
		
		NetPrepare( "Notify", details ):Send( ply )
		Popups[ ply ] = ST()
		
		local viewers = ply:Spectator( "Get", { true } )
		if #viewers > 0 then
			local ar = NetPrepare( "NotifyMulti" )
			ar:String( szType )
			ar:Pattern( "Notify", details )
			ar:Send( viewers )
		end
	elseif szType == "LJ" then
		local szMessage = Core.ColorText()
		
		szMessage:Add( details.Player, colors[ 1 ], true )
		szMessage:Add( " got a " )
		szMessage:Add( details.Distance .. " unit", colors[ 2 ], true )
		szMessage:Add( " LJ" )
		
		if details.Style > Styles.Normal then
			szMessage:Add( " on " )
			szMessage:Add( Core.StyleName( details.Style ), colors[ 4 ], true )
		end
		
		szMessage:Add( "!" )
		
		if details.Position then
			szMessage:Add( " A new personal best, bringing them to #" .. details.Position .. " in the LJ top list!" )
		end
		
		local ar = NetPrepare( "NotifyMulti" )
		ar:String( szType )
		ar:String( details.Player )
		ar:Double( details.Distance )
		ar:Double( details.Prestrafe )
		ar:Double( details.Sync )
		ar:UInt( details.Count, 8 )
		
		if details.Edge and details.Duck then
			ar:Bit( true )
			ar:Bit( details.Duck )
			ar:Double( details.Edge )
		else
			ar:Bit( false )
		end
		
		ar:ColorText( szMessage:Get() )
		ar:Broadcast()
	end
end
Core.PlayerNotification = Player.Notification

--[[
	Description: Lets the player know about any possibly beaten times
--]]
function Player.NotifyBeatenWR( szPreviousWR, szMap, szName, nStyle, nDifference )
	-- Check if the previous WR holder is online
	local bOnline = player.GetBySteamID( szPreviousWR )
	
	-- If this isn't the case, save it to our table
	if not bOnline then
		Prepare(
			"INSERT INTO game_notifications (szUID, szMap, szName, nStyle, nDifference, nDate) VALUES ({0}, {1}, {2}, {3}, {4}, {5})",
			{ szPreviousWR, szMap, szName, nStyle, nDifference, os.time() }
		)
	end
end

--[[
	Description: Lets the player know about any possibly beaten times
	Used by: Player initial spawn
--]]
function PLAYER:NotifyBeatenTimes()
	local data = Player.NotifyCache[ self.UID ]
	if data then
		-- Build the messages
		local msg = {}
		for j = 1, #data do
			msg[ #msg + 1 ] = "- [" .. os.date( "%Y-%m-%d", data[ j ]["nDate"] ) .. "] " .. data[ j ]["szMap"] .. " on " .. Core.StyleName( data[ j ]["nStyle"] ) .. " by " .. data[ j ]["szName"] .. " (-" .. Timer.Convert( data[ j ]["nDifference"] ) .. ")"
		end
		
		-- Send it to the player in the proper format
		if #msg > 0 then
			NetPrepare( "Notify", { "General", Core.Text( "PlayerBeatenPopup", #msg ), "time_delete", 8, #msg < 20 and Core.Text( "PlayerBeatenTime", self:Name(), string.Implode( "\n", msg ), data[ 1 ]["szMap"] ) } ):Send( self )
		end
		
		-- Clear the table to avoid seeing this again after a rejoin
		Player.NotifyCache[ self.UID ] = {}
		
		-- Get rid of the items in the database
		Prepare(
			"DELETE FROM game_notifications WHERE szUID = {0}",
			{ self.UID }
		)
	end
end


-- Connections and player handling

--[[
	Description: Called by the AFK kicker addon if available on the player
--]]
function PLAYER:AFKFunc( AFK )
	local nPoints = AFK.Points[ self ]
	if nPoints == 1 then
		Core.Print( self, "Timer", Core.Text( "MiscAFK", math.floor( ( (AFK.StartPoints - nPoints) * AFK.CheckInterval) / 60 ) ) )
		
		self.AFKTab = AFK
		
		if not self.Spectating then
			concommand.Run( self, "spectate", "bypass", "" )
		end
	elseif nPoints == 0 then
		if #player.GetHumans() >= Config.KickTime then
			Core.Print( self, "Timer", Core.Text( "MiscAFKKicked", math.floor( ( (AFK.StartPoints - nPoints) * AFK.CheckInterval) / 60 ) ) )
		else
			AFK.Points[ self ] = nPoints + 1
			
			local _x, _o, _a = self:IsPlayerDequeued()
			if _a then
				self:CleanFrames()
				self:SetBotActive( nil )
			end
			
			return true
		end
	end

	return false
end

--[[
	Description: Player disconnection hook to clean up the trash they made
--]]
local function PlayerDisconnect( ply )
	-- Bots don't need any other logic
	if ply:IsBot() then return end
	
	-- When we're all empty, unload the gamemode (save bots)
	if #player.GetHumans() - 1 < 1 then
		GAMEMODE:UnloadGamemode( "Change" )
	end
	
	-- Notify spectated players that their spectator is gone
	if ply.Spectating then
		ply:Spectator( "End", { ply:GetObserverTarget() } )
		ply.Spectating = nil
	end
	
	-- When they're racing, close the match
	if ply.Race then
		ply.Race:Abandon( ply )
	end
	
	-- Clear their bot and sync data
	ply:ClearStrafeStats()
	ply:CleanFrames()
	
	-- Check if a vote is going on
	if RTV.VotePossible then return end
	
	-- If not, remove their vote
	if ply.Rocked then
		RTV.Votes = RTV.Votes - 1
	end
	
	-- And check if the vote passes now
	local Count = RTV.GetVotable( ply )
	if Count > 0 then
		RTV.Required = math.ceil( Count * RTV.Fraction )
		
		if RTV.Votes >= RTV.Required then
			RTV.StartVote()
		end
	end
end
hook.Add( "PlayerDisconnected", "PlayerDisconnect", PlayerDisconnect )



-- RTV System
RTV.Identifier = "MapCountdown"
RTV.Version = 1
RTV.ListMax = 5
RTV.VoteCount = 7
RTV.Votes = 0
RTV.MapRepeat = 6
RTV.MinLimitations = 4
RTV.Fraction = 11 / 20
RTV.VoteList = {}
RTV.VotePossible = false
RTV.RandomizeTie = true

RTV.VoteTime = 30
RTV.VoteTimeEnd = 0
RTV.Extends = 0
RTV.Length = 45 * 60
RTV.DefaultExtend = 20 * 60
RTV.WaitPeriod = 5 * 60
RTV.CheckInterval = 0.5 * 60
RTV.BroadcastInterval = 30 / 10

if not RTV.Initialized then
	RTV.TimeNotify = { { 15 }, { 10 }, { 5 }, { 2 }, { 1 } }
	
	RTV.Initialized = ST()
	RTV.Begin = RTV.Initialized
	RTV.End = RTV.Begin + RTV.Length
end

RTV.Func = {}
RTV.AutoExtend = {}
RTV.Nominations = {}
RTV.LatestList = {}

--[[
	Description: Starts the RTV system
--]]
function RTV:Start()
	-- Make sure there's only one RTV timer running
	if timer.Exists( self.Identifier ) then
		timer.Remove( self.Identifier )
	end
	
	-- Create a timer
	timer.Create( self.Identifier, self.Length, 1, self.StartVote )
	timer.Create( self.Identifier .. "Hourglass", self.CheckInterval, 0, self.TimeCheck )
	
	-- Set initialization fields for lifetime calculation
	self.Begin = ST()
	self.End = self.Begin + self.Length
	
	-- Populate the vote list with 0 votes
	for i = 1, self.VoteCount do
		self.VoteList[ i ] = 0
	end
	
	-- Load all necessary data
	self:Load()
	
	-- Crack up the random generator to throw in a little less than pseudo-randoms
	RTV.TrueRandom( 1, 5 )
end

--[[
	Description: Loads data required for the RTV system
--]]
function RTV:Load()
	file.CreateDir( Config.BaseType .. "/" )
	
	-- Load in or write the map version
	if not file.Exists( Config.BaseType .. "/maplistversion.txt", "DATA" ) then
		file.Write( Config.BaseType .. "/maplistversion.txt", tostring( self.Version ) )
	else
		self.Version = tonumber( file.Read( Config.BaseType .. "/maplistversion.txt", "DATA" ) )
	end
	
	-- Create a dummy file if it's blank
	local dummy = {}
	for i = 1, RTV.MapRepeat do dummy[ i ] = "Dummy" end
	
	if not file.Exists( Config.BaseType .. "/maptracker.txt", "DATA" ) then
		file.Write( Config.BaseType .. "/maptracker.txt", util.TableToJSON( dummy ) )
	end
	
	-- Check file content
	local content = file.Read( Config.BaseType .. "/maptracker.txt", "DATA" )
	if not content or content == "" then return end
	
	-- Try to deserialize
	local tab = util.JSONToTable( content )
	if not tab or #tab != RTV.MapRepeat then
		return file.Write( Config.BaseType .. "/maptracker.txt", util.TableToJSON( dummy ) )
	end
	
	-- If we're going back to the same map, don't keep adding to the list
	if tab[ 1 ] == Timer:GetMap() then return end
	
	-- Insert at front and remove at the back
	table.insert( tab, 1, Timer:GetMap() )
	table.remove( tab, RTV.MapRepeat + 1 )
	
	-- Update the table
	self.LatestList = tab
	
	-- Finally write to file
	file.Write( Config.BaseType .. "/maptracker.txt", util.TableToJSON( self.LatestList ) )
end

--[[
	Description: Starts the vote
	Used by: RTV timer only
--]]
function RTV.StartVote()
	if RTV.VotePossible then return end
	
	-- Let everyone know we just started a vote
	RTV.VotePossible = true
	RTV.Selections = {}
	Core.Print( nil, "Notification", Core.Text( "VoteStart" ) )
	
	-- Iterate over the nomination table and categorize it by vote count
	local MapList, MaxCount = {}, 1
	for map,voters in pairs( RTV.Nominations ) do
		local amount = 0
		for _,v in pairs( voters ) do
			if IsValid( v ) then
				amount = amount + 1
			end
		end
		
		-- If we've got an entry already, expand, otherwise create it
		local count = MapList[ amount ] and #MapList[ amount ]
		if not count then
			MapList[ amount ] = { map }
		else
			MapList[ amount ][ count + 1 ] = map
		end
		
		-- Increase max count if necessary
		if amount > MaxCount then
			MaxCount = amount
		end
	end

	-- Loop over the most important nominations
	for i = MaxCount, 1, -1 do
		if MapList[ i ] then
			for j = 1, #MapList[ i ] do
				if #RTV.Selections >= RTV.ListMax then break end
				
				-- Add the nomination to the list
				RTV.Selections[ #RTV.Selections + 1 ] = MapList[ i ][ j ]
			end
		end
	end
	
	-- If we haven't had sufficient nominations, gather some random maps
	if #RTV.Selections < 5 and Timer.Maps > 0 then
		-- Copy the base table and remove already nominated entries
		local copy = table.Copy( Maps )
		for i = 1, #RTV.Selections do
			copy[ RTV.Selections[ i ] ] = nil
		end
		
		-- Gather all the maps in a sortable array
		local temp = {}
		for map,data in pairs( copy ) do
			temp[ #temp + 1 ] = { Map = map, Plays = data.nPlays or 0 }
		end
		
		-- Sort the table by plays
		table.SortByMember( temp, "Plays", true )
		
		-- Get the 25 least played maps in a separate table
		local limit = {}
		for i = 1, 25 do
			limit[ i ] = temp[ i ]
		end
		
		-- Finally add random entries
		for _,data in RandomPairs( limit ) do
			local map = data.Map
			if #RTV.Selections >= RTV.ListMax then break end
			if HAS( RTV.Selections, map ) or map == Timer:GetMap() then continue end
			if HAS( RTV.LatestList, map ) then continue end
			
			-- Add the random map to the list
			RTV.Selections[ #RTV.Selections + 1 ] = { map, RTV.GetMapData( map ) }
		end
	end
	
	-- Create a sortable table
	local sorted = {}
	for i = 1, #RTV.Selections do
		local item = RTV.Selections[ i ]
		if type( item ) == "table" then
			sorted[ #sorted + 1 ] = { Map = item[ 1 ], Plays = item[ 2 ][ 3 ], ListID = i }
		end
	end

	-- Check if we have maps to sort
	if #sorted > 0 then
		-- Sort the table with ascending plays
		table.SortByMember( sorted, "Plays", true )

		-- Reset the current table
		local offset
		for i = 1, #RTV.Selections do
			if type( RTV.Selections[ i ] ) == "table" then
				if not offset then offset = i end
				RTV.Selections[ i ] = nil
			end
		end
		
		-- Overwrite table entries with re-sorted entries
		for i = 1, #sorted do
			if not offset then break end
			RTV.Selections[ offset + i - 1 ] = sorted[ i ].Map
		end
	end

	-- Create a new table with only map data to be sent
	local RTVSend = {}
	for i = 1, #RTV.Selections do
		RTVSend[ #RTVSend + 1 ] = RTV.GetMapData( RTV.Selections[ i ] )
	end
	
	-- Make the list accessible from the RTV object and set the ending time
	RTV.VoteTimeEnd = ST() + RTV.VoteTime
	RTV.Sent = RTVSend
	RTV.Sent.Countdown = math.Clamp( RTV.VoteTimeEnd - ST(), 0, RTV.VoteTime )
	
	-- Broadcast the compiled list and start a timer
	timer.Simple( RTV.VoteTime + 1, RTV.EndVote )
	Core.Broadcast( "RTV/List", RTV.Sent )
	
	-- Distribute the instant votes
	timer.Simple( 0.5, function()
		local extend = {}
		for p,v in pairs( RTV.AutoExtend ) do
			if v then
				extend[ #extend + 1 ] = p
			end
		end
		
		if #extend > 0 then
			Core.Send( extend, "RTV/InstantVote", 6 )
		end
		
		for map,voters in pairs( RTV.Nominations ) do
			for id,data in pairs( RTV.Sent ) do
				if id == "Countdown" then continue end
				if data[ 1 ] == map then
					local out = {}
					for _,p in pairs( voters ) do
						if not RTV.AutoExtend[ p ] then
							out[ #out + 1 ] = p
						end
					end
					
					Core.Send( out, "RTV/InstantVote", id )
				end
			end
		end
	end )
	
	-- Check broadcast timer
	if timer.Exists( RTV.Identifier .. "Broadcast" ) then
		timer.Remove( RTV.Identifier .. "Broadcast" )
	end
	
	-- Create one with iterations that stop before the timer runs out
	timer.Create( RTV.Identifier .. "Broadcast", RTV.BroadcastInterval, RTV.VoteTime / RTV.BroadcastInterval - 1, function()
		NetPrepare( "RTV/VoteList", RTV.VoteList ):Broadcast()
	end )
end

--[[
	Description: Ends the vote and decides what won (a map or extend or even random)
--]]
function RTV.EndVote()
	if RTV.CancelVote then
		return RTV:ResetVote( "Yes", 2, false, "VoteCancelled" )
	end
	
	-- Trigger finalization (bots)
	GAMEMODE:UnloadGamemode( "VoteEnd" )
	
	local nMax, nTotal, nWin = 0, 0, -1
	for i = 1, 7 do
		if RTV.VoteList[ i ] and RTV.VoteList[ i ] > nMax then
			nMax = RTV.VoteList[ i ]
			nWin = i
		end
		
		nTotal = nTotal + RTV.VoteList[ i ]
	end
	
	-- If enabled, pick a random one if there's duplicates
	if RTV.RandomizeTie then
		local votes = {}
		for i = 1, 7 do
			if RTV.VoteList[ i ] == nMax then
				votes[ #votes + 1 ] = i
			end
		end
		
		if #votes > 1 then
			nWin = votes[ RTV.TrueRandom( 1, #votes ) ]
			Core.Print( nil, "Notification", Core.Text( "VoteSameVotes", "#" .. string.Implode( ", #", votes ), nWin ) )
		end
	end
	
	-- Execute winner function
	if nWin <= 0 then
		nWin = RTV.TrueRandom( 1, 5 )
	elseif nWin == 6 then
		Core.Print( nil, "Notification", Core.Text( "VoteExtend", RTV.DefaultExtend / 60 ) )
		return RTV:ResetVote( nil, 1, true, nil )
	elseif nWin == 7 then
		RTV.VotePossible = false
		
		if Timer.Maps > 0 then
			local ListMap, ListPlays = {}, {}
			for map,data in pairs( Maps ) do
				ListMap[ #ListMap + 1 ] = map
				ListPlays[ #ListPlays + 1 ] = data["nPlays"]
			end
			
			local minId, minValue, thisMap = ListMap[ 1 ], ListPlays[ 1 ], Timer:GetMap()
			for i = 2, #ListPlays do
				if ListPlays[ i ] < minValue and ListMap[ i ] != thisMap then
					minId = ListMap[ i ]
					minValue = ListPlays[ i ]
				end
			end
			
			if minId and minValue and Maps[ minId ] then
				nWin = 1
				RTV.Selections[ nWin ] = minId
			else
				nWin = RTV.TrueRandom( 1, 5 )
			end
		else
			nWin = RTV.TrueRandom( 1, 5 )
		end
	end
	
	-- Get the map from the selection table
	local szMap = RTV.Selections[ nWin ]
	if not szMap or not type( szMap ) == "string" then
		return Core.Print( nil, "Notification", Core.Text( "VoteMissing", szMap ) )
	end

	if not RTV.IsAvailable( szMap ) then
		Core.Print( nil, "Notification", Core.Text( "VoteMissing", szMap ) )
	else
		Core.Print( nil, "Notification", Core.Text( "VoteChange", szMap ) )
	end
	
	-- Backup reset for if we don't change
	timer.Simple( 10, function()
		RTV:ResetVote( "Yes", 1, false, "VoteFailure" )
	end )
	
	-- Finally change level
	Core.ChangeStarted = szMap
	timer.Simple( 5, function()
		GAMEMODE:UnloadGamemode( "Change" )
		RunConsoleCommand( "changelevel", Core.ChangeStarted )
		Core.ChangeStarted = nil
	end )
	
	-- Logging print
	print( "[RTV] Map changed to: " .. (Core.ChangeStarted or "Unknown") )
end

--[[
	Description: Resets the vote data according to the vote type
--]]
function RTV:ResetVote( szCancel, nMult, bExtend, szMsg )
	nMult = nMult or 1

	if szCancel and szCancel == "Yes" then
		self.CancelVote = nil
	end
	
	self.VotePossible = false
	self.Selections = {}
	
	self.Begin = ST()
	self.End = self.Begin + (nMult * self.DefaultExtend)
	
	self.Votes = 0
	for i = 1, self.VoteCount do
		self.VoteList[ i ] = 0
	end
	
	for _,d in pairs( self.TimeNotify ) do
		d[ 2 ] = nil
	end
	
	if bExtend then
		self.Extends = self.Extends + 1
	end
	
	for _,p in pairs( player.GetHumans() ) do
		p.Rocked = nil
		p.LastVotedID = nil
		p.ResentVote = nil
	end
	
	if timer.Exists( self.Identifier ) then
		timer.Remove( self.Identifier )
	end
	
	timer.Create( self.Identifier, nMult * self.DefaultExtend, 1, self.StartVote )

	if szMsg then
		Core.Print( nil, "Notification", Core.Text( szMsg ) )
	end
end

--[[
	Description: Changes the time left on the vote
--]]
function RTV.ChangeTime( nMins )
	-- Make sure there's only one RTV timer running
	if timer.Exists( RTV.Identifier ) then
		timer.Remove( RTV.Identifier )
	end
	
	timer.Create( RTV.Identifier, nMins * 60, 1, RTV.StartVote )
	
	RTV.End = ST() + nMins * 60
	
	for _,d in pairs( RTV.TimeNotify ) do
		d[ 2 ] = nil
	end
	
	for i = 1, #RTV.TimeNotify do
		local item = RTV.TimeNotify[ i ]
		if nMins * 60 < item[ 1 ] * 60 then
			item[ 2 ] = true
		end
	end
end
Core.RTVChangeTime = RTV.ChangeTime

--[[
	Description: Broadcasts a timeleft notification to every connected player
	Notes: Runs on a timer
--]]
function RTV.TimeCheck()
	local remaining = RTV.End - ST()
	for i = 1, #RTV.TimeNotify do
		local item = RTV.TimeNotify[ i ]
		if remaining < item[ 1 ] * 60 and not item[ 2 ] then
			local text = remaining < 60 and "Less than 1 minute remaining" or ((remaining >= 60 and remaining < 120) and "1 minute remaining" or math.floor( remaining / 60 ) .. " minutes remaining")
			NetPrepare( "Notify", { "Notification", text, "hourglass", 10, text } ):Broadcast()
			
			item[ 2 ] = true
			break
		end
	end
end

--[[
	Description: Get the amount of people that can actually vote in the server
--]]
function RTV.GetVotable( exclude, plys )
	local n, ps = 0, {}
	
	for _,p in pairs( player.GetHumans() ) do
		if p == exclude then
			continue
		elseif p.AFKTab and p.AFKTab.Points[ p ] < 2 then
			continue
		elseif StylePoints[ Styles.Normal ] and (not StylePoints[ Styles.Normal ][ p.UID ] or StylePoints[ Styles.Normal ][ p.UID ] == 0) then
			if p.Style != Styles.Normal then
				continue
			elseif p.Record == 0 and #player.GetHumans() > RTV.MinLimitations then
				continue
			end
		end
		
		n = n + 1
		ps[ #ps + 1 ] = p
	end
	
	return plys and ps or n
end


--[[
	Description: Triggers a vote on the player if possible
--]]
function RTV.Func.Vote( ply )
	if ply.RTVLimit and ST() - ply.RTVLimit < 60 then
		return Core.Print( ply, "Notification", Core.Text( "VoteLimit", math.ceil( 60 - (ST() - ply.RTVLimit) ) ) )
	elseif ply.Rocked then
		return Core.Print( ply, "Notification", Core.Text( "VoteAlready" ) )
	elseif RTV.VotePossible then
		return Core.Print( ply, "Notification", Core.Text( "VotePeriod" ) )
	--elseif ST() - RTV.Begin < RTV.WaitPeriod then
	--	return Core.Print( ply, "Notification", Core.Text( "VoteLimited", string.format( "%.1f", (RTV.WaitPeriod - (ST() - RTV.Begin)) / 60 ) ) )
	elseif StylePoints[ Styles.Normal ] and (not StylePoints[ Styles.Normal ][ ply.UID ] or StylePoints[ Styles.Normal ][ ply.UID ] == 0) then
		if ply.Style != Styles.Normal then
			return Core.Print( ply, "Notification", Core.Text( "VoteLimitPlay" ) )
		elseif ply.Record == 0 and #player.GetHumans() > RTV.MinLimitations then
			return Core.Print( ply, "Notification", Core.Text( "VoteLimitPlay" ) )
		end
	end
	
	ply.RTVLimit = ST()
	ply.Rocked = true
	
	RTV.Votes = RTV.Votes + 1
	RTV.Required = math.ceil( RTV.GetVotable() * RTV.Fraction )
	
	local nVotes = RTV.Required - RTV.Votes
	Core.Print( nil, "Notification", Core.Text( "VotePlayer", ply:Name(), nVotes, nVotes == 1 and "vote" or "votes", math.ceil( (RTV.Votes / RTV.Required) * 100 ) ) )
	
	if RTV.Votes >= RTV.Required then
		RTV.StartVote()
	end
end

--[[
	Description: Revokes a vote on the player if there is any
--]]
function RTV.Func.Revoke( ply )
	if RTV.VotePossible then
		return Core.Print( ply, "Notification", Core.Text( "VotePeriod" ) )
	end

	if ply.Rocked then
		ply.Rocked = false
		
		RTV.Votes = RTV.Votes - 1
		RTV.Required = math.ceil( RTV.GetVotable() * RTV.Fraction )
		
		local nVotes = RTV.Required - RTV.Votes
		Core.Print( nil, "Notification", Core.Text( "VoteRevoke", ply:Name(), nVotes, nVotes == 1 and "vote" or "votes" ) )
	else
		Core.Print( ply, "Notification", Core.Text( "VoteRevokeFail" ) )
	end
end

--[[
	Description: Nominates a map
	Notes: Whole lot of extra logic for sorting the maps
--]]
function RTV.Func.Nominate( ply, szMap )
	local szIdentifier = "Nomination"
	local varArgs = { ply:Name(), szMap }

	if #player.GetHumans() > RTV.MinLimitations and HAS( RTV.LatestList, szMap ) then
		local at = 1
		for id,map in pairs( RTV.LatestList ) do
			if map == szMap then
				at = id
				break
			end
		end
		
		return Core.Print( ply, "Notification", Core.Text( "NominateRecent", at - 1 ) )
	end
	
	if ply.NominatedMap and ply.NominatedMap != szMap then
		if RTV.Nominations[ ply.NominatedMap ] then
			for id,p in pairs( RTV.Nominations[ ply.NominatedMap ] ) do
				if p == ply then
					table.remove( RTV.Nominations[ ply.NominatedMap ], id )
					
					if #RTV.Nominations[ ply.NominatedMap ] == 0 then
						RTV.Nominations[ ply.NominatedMap ] = nil
					end
					
					szIdentifier = "NominationChange"
					varArgs = { ply:Name(), ply.NominatedMap, szMap }
					
					break
				end
			end
		end
	elseif ply.NominatedMap and ply.NominatedMap == szMap then
		return Core.Print( ply, "Notification", Core.Text( "NominationAlready" ) )
	end
	
	if not RTV.Nominations[ szMap ] then
		RTV.Nominations[ szMap ] = { ply }
		ply.NominatedMap = szMap
		Core.Print( nil, "Notification", Core.Text( szIdentifier, varArgs ) )
	elseif type( RTV.Nominations ) == "table" then
		local Included = false
		for _,p in pairs( RTV.Nominations[ szMap ] ) do
			if p == ply then Included = true break end
		end
		
		if not Included then
			table.insert( RTV.Nominations[ szMap ], ply )
			ply.NominatedMap = szMap
			Core.Print( nil, "Notification", Core.Text( szIdentifier, varArgs ) )
		else
			return Core.Print( ply, "Notification", Core.Text( "NominationAlready" ) )
		end
	end
end

--[[
	Description: Returns a list of who has voted and who hasn't voted
--]]
function RTV.Func.Who( ply )
	local Voted = {}
	local NotVoted = {}
	
	for _,p in pairs( RTV.GetVotable( nil, true ) ) do
		if p.Rocked then
			table.insert( Voted, p:Name() )
		else
			table.insert( NotVoted, p:Name() )
		end
	end
	
	RTV.Required = math.ceil( RTV.GetVotable() * RTV.Fraction )
	Core.Print( ply, "Notification", Core.Text( "VoteList", RTV.Required, #Voted, string.Implode( ", ", Voted ), #NotVoted, string.Implode( ", ", NotVoted ) ) )
end

--[[
	Description: Checks how many votes are left before the map changes
--]]
function RTV.Func.Check( ply )
	RTV.Required = math.ceil( RTV.GetVotable() * RTV.Fraction )
	
	local nVotes = RTV.Required - RTV.Votes
	Core.Print( ply, "Notification", Core.Text( "VoteCheck", nVotes, nVotes == 1 and "vote" or "votes" ) )
end

--[[
	Description: Returns the time remaining before a change of maps
--]]
function RTV.Func.Left( ply )
	Core.Print( ply, "Notification", Core.Text( "MapTimeLeft", Timer.Convert( RTV.End - ST() ) ) )
end

--[[
	Description: Resends the voting screen to the player
--]]
function RTV.Func.Revote( ply, bGet )
	if bGet then return RTV.VotePossible end
	if not RTV.VotePossible then return Core.Print( ply, "Notification", Core.Text( "VotePeriodActive" ) ) end
	ply.ResentVote = true
	
	RTV.Sent.Countdown = math.Clamp( RTV.VoteTimeEnd - ST(), 0, RTV.VoteTime )
	Core.Send( ply, "RTV/List", RTV.Sent )
end

--[[
	Description: Gets a type of map requested by the player
--]]
function RTV.Func.MapFunc( ply, key )
	if Timer.Maps == 0 then return end
	
	if key == "playinfo" then
		Core.Print( ply, "General", Core.Text( "TimerMapsInfo" ) )
	elseif key == "leastplayed" then
		local temp = {}
		for map,data in pairs( Maps ) do
			temp[ #temp + 1 ] = { Map = map, Plays = data.nPlays or 0 }
		end
		
		table.SortByMember( temp, "Plays", true )
		
		local str = {}
		for i = 1, 5 do
			str[ i ] = temp[ i ].Map .. " (" .. temp[ i ].Plays .. " plays)"
		end
		
		Core.Print( ply, "General", Core.Text( "TimerMapsDisplay", "Least", string.Implode( ", ", str ) ) )
	elseif key == "mostplayed" or key == "overplayed" then
		local temp = {}
		for map,data in pairs( Maps ) do
			temp[ #temp + 1 ] = { Map = map, Plays = data.nPlays or 0 }
		end
		
		table.SortByMember( temp, "Plays", false )
		
		local str = {}
		for i = 1, 5 do
			str[ i ] = temp[ i ].Map .. " (" .. temp[ i ].Plays .. " plays)"
		end
		
		Core.Print( ply, "General", Core.Text( "TimerMapsDisplay", "Most", string.Implode( ", ", str ) ) )
	elseif key == "lastplayed" or key == "lastmaps" then
		local temp = {}
		for map,data in pairs( Maps ) do
			temp[ #temp + 1 ] = { Map = map, Date = data.szDate }
		end
		
		table.SortByMember( temp, "Date", false )
		
		local str = {}
		for i = 1, 5 do
			str[ i ] = temp[ i ].Map .. " (" .. temp[ i ].Date .. ")"
		end
		
		Core.Print( ply, "General", Core.Text( "TimerMapsDisplay", "Last", string.Implode( ", ", str ) ) )
	elseif key == "randommap" then
		for map,data in RandomPairs( Maps ) do
			Core.Print( ply, "General", Core.Text( "TimerMapsRandom", map ) )
			break
		end
	end
end

--[[
	Description: Shows which map you have nominated
--]]
function RTV.Func.Which( ply )
	Core.Print( ply, "Notification", ply.NominatedMap and Core.Text( "MapNominated", "", ply.NominatedMap ) or Core.Text( "MapNominated", "n't", "a map" ) )
end

--[[
	Description: Shows all nominated maps
--]]
function RTV.Func.Nominations( ply )
	local MapList, MaxCount = {}, 1
	for map,voters in pairs( RTV.Nominations ) do
		local plys = { map }
		for _,v in pairs( voters ) do
			if IsValid( v ) then
				plys[ #plys + 1 ] = v:Name()
			end
		end
		
		-- If we've got an entry already, expand, otherwise create it
		local amount = #plys - 1
		local count = MapList[ amount ] and #MapList[ amount ]
		if not count then
			MapList[ amount ] = { plys }
		else
			MapList[ amount ][ count + 1 ] = plys
		end
		
		-- Increase max count if necessary
		if amount > MaxCount then
			MaxCount = amount
		end
	end
	
	-- Loop over the most important nominations
	local str, add = Core.Text( "MapNominations" )
	for i = MaxCount, 1, -1 do
		if MapList[ i ] then
			for j = 1, #MapList[ i ] do
				str = str .. "- " .. table.remove( MapList[ i ][ j ], 1 ) .. " (By " .. i .. " player(s): " .. string.Implode( ", ", MapList[ i ][ j ] ) .. ")\n"
				add = true
			end
		end
	end
	
	-- Print the message out
	Core.Print( ply, "Notification", add and (str .. Core.Text( "MapNominationChance" )) or Core.Text( "MapNominationsNone" ) )
end

--[[
	Description: Revokes a player map nomination
--]]
function RTV.Func.Denominate( ply )
	if not ply.NominatedMap then
		return Core.Print( ply, "Notification", Core.Text( "MapNominationNone" ) )
	end
	
	if RTV.Nominations[ ply.NominatedMap ] then
		for id,p in pairs( RTV.Nominations[ ply.NominatedMap ] ) do
			if p == ply then
				table.remove( RTV.Nominations[ ply.NominatedMap ], id )
				
				if #RTV.Nominations[ ply.NominatedMap ] == 0 then
					RTV.Nominations[ ply.NominatedMap ] = nil
				end
				
				break
			end
		end
	end
	
	ply.NominatedMap = nil
	
	Core.Print( ply, "Notification", Core.Text( "MapNominationRevoke" ) )
end

--[[
	Description: Sets the player to automatically vote extend
--]]
function RTV.Func.Extend( ply )
	RTV.AutoExtend[ ply ] = not RTV.AutoExtend[ ply ]
	
	Core.Print( ply, "Notification", Core.Text( "MapAutoExtend", not RTV.AutoExtend[ ply ] and "no longer " or "" ) )
end

--[[
	Description: The function that triggers the RTV.Func's
--]]
function PLAYER:RTV( szType, args )
	if RTV.Func[ szType ] then
		return RTV.Func[ szType ]( self, args )
	end
end


--[[
	Description: Process a received vote
	Used by: Called from network
--]]
function RTV.ReceiveVote( ply, varArgs )
    local nVote, nOld = varArgs[ 1 ], ply.RTVOldVote
    if not RTV.VotePossible or not nVote then return end
    if ply.LastVotedID == nVote then return end
    
    if not nOld and ply.ResentVote and ply.LastVotedID then
        nOld = ply.LastVotedID
        ply.ResentVote = nil
    end
    
    ply.LastVotedID = nVote
    
    local nAdd = 1
    if not nOld then
        if nVote < 1 or nVote > 7 then return end
        if not RTV.VoteList[ nVote ] then RTV.VoteList[ nVote ] = 0 end
        RTV.VoteList[ nVote ] = RTV.VoteList[ nVote ] + nAdd
        ply.RTVOldVote = nVote
    else
        if nVote < 1 or nVote > 7 or nOld < 1 or nOld > 7 then return end
        if not RTV.VoteList[ nVote ] then RTV.VoteList[ nVote ] = 0 end
        if not RTV.VoteList[ nOld ] then RTV.VoteList[ nOld ] = 0 end
        RTV.VoteList[ nVote ] = RTV.VoteList[ nVote ] + nAdd
        RTV.VoteList[ nOld ] = RTV.VoteList[ nOld ] - nAdd
        if RTV.VoteList[ nOld ] < 0 then RTV.VoteList[ nOld ] = 0 end
        ply.RTVOldVote = nVote
    end
    
    NetPrepare( "RTV/VoteList", RTV.VoteList ):Broadcast()
end
Core.Register( "Global/Vote", RTV.ReceiveVote )

--[[
	Description: Sends the map list to a player
	Notes: Encodes it here since it might take a while before anyone needs a new map list
--]]
local EncodedData, EncodedLength
function RTV.GetMapList( ply, varArgs )
	if varArgs[ 1 ] != RTV.Version then
		if not EncodedData or not EncodedLength then
			EncodedData = util.Compress( util.TableToJSON( { Maps, RTV.Version, Timer.Maps } ) )
			EncodedLength = #EncodedData
		end
		
		if not EncodedData or not EncodedLength then
			Core.Print( ply, "Notification", Core.Text( "MiscMissingMapList" ) )
		else
			net.Start( "BinaryTransfer" )
			net.WriteString( "List" )
			net.WriteUInt( EncodedLength, 32 )
			net.WriteData( EncodedData, EncodedLength )
			net.Send( ply )
		end
	end
end
Core.Register( "Global/MapList", RTV.GetMapList )

--[[
	Description: Update the version number and increment it
--]]
function RTV:UpdateVersion( nAmount )
	self.Version = self.Version + (nAmount or 1)
	file.Write( Config.BaseType .. "/maplistversion.txt", tostring( self.Version ) )
end

--[[
	Description: Checks if the map exists on the disk
--]]
function RTV.IsAvailable( szMap )
	return file.Exists( "maps/" .. szMap .. ".bsp", "GAME" )
end

--[[
	Description: Checks if the map exists in the loaded database table
--]]
function RTV.MapExists( szMap )
	return not not Maps[ szMap ]
end

--[[
	Description: Returns the loaded data about a map
	Notes: Could add more but this is only necessary to be on the client itself
--]]
function RTV.GetMapData( szMap )
	local tab = Maps[ szMap ]
	
	if tab then
		if Config.IsSurf then
			return { szMap, tab["nMultiplier"], tab["nPlays"], tab["nTier"] or 1, tab["nType"] or 0 }
		else
			return { szMap, tab["nMultiplier"], tab["nPlays"] }
		end
	else
		if Config.IsSurf then
			return { szMap, 1, 1, 1, 0 }
		else
			return { szMap, 1, 1 }
		end
	end
end


-- Zones
Zones.Type = {
	["Normal Start"] = 0,
	["Normal End"] = 1,
	["Bonus Start"] = 2,
	["Bonus End"] = 3,
	["Anticheat"] = 4,
	["Freestyle"] = 5,
	["Normal AC"] = 6,
	["Bonus AC"] = 7,
	["Stage Start"] = 8,
	["Stage End"] = 9,
	["Restart Zone"] = 10,
	["Velocity Zone"] = 11,
	["Solid AC"] = 12
}

-- The options that can be set
Zones.Options = {
	NoStartLimit = 1,
	NoSpeedLimit = 2,
	TelehopMap = 4,
	Checkpoints = 8
}

-- Base settings
Zones.Settings = {
	MaxVelocity = 3500,
	MaxVelocityHard = 5000,
	UnlimitedVelocity = 100000
}

-- Content tables
local ZoneCache = {}
local ZoneEnts = {}
local ClientEnts = {}


--[[
	Description: Loads all zones for this map from the database and parses them
--]]
function Zones.Load()
	Prepare(
		"SELECT nType, vPos1, vPos2 FROM game_zones WHERE szMap = {0}",
		{ Timer:GetMap() },
		nil, true
	)( function( data, varArg, szError )
		if Core.Assert( data, "nType" ) then
			local makeNum, makeType = tonumber, util.StringToType
			for j = 1, #data do
				data[ j ]["nType"] = makeNum( data[ j ]["nType"] )
				data[ j ]["vPos1"] = makeType( data[ j ]["vPos1"], "Vector" )
				data[ j ]["vPos2"] = makeType( data[ j ]["vPos2"], "Vector" )
				
				ZoneCache[ #ZoneCache + 1 ] = data[ j ]
			end
		end
	end )
end

--[[
	Description: Sets up the zone entities themselves
	Used by: Map initialization and reloading
--]]
function Zones.Setup()
	Zones.BotPoints = {}
	Zones.StartPoints = {}

	for i = 1, #ZoneCache do
		local zone = ZoneCache[ i ]
		local Type = zone["nType"]
		local P1, P2 = zone["vPos1"], zone["vPos2"]
		local M1 = (P1 + P2) / 2

		-- Check for custom functions
		if Zones.CustomEnts[ Type ] then
			ZoneEnts[ #ZoneEnts + 1 ] = Zones.CustomEnts[ Type ]( zone )
			
			continue
		end
		
		-- Creates the entity
		local ent = ents.Create( "game_timer" )
		ent:SetPos( M1 )
		ent.min = P1
		ent.max = P2
		ent.zonetype = Type
		ent.truetype = Type
		
		-- Sets start points for respawning
		if Type == Zones.Type["Normal Start"] then
			Zones.StartPoints[ #Zones.StartPoints + 1 ] = { P1, P2, M1 }
			Zones.BotPoints[ #Zones.BotPoints + 1 ] = Vector( M1.x, M1.y, P1.z )
		end
		
		-- Custom zones with embedded data
		if Type >= 700 and Type <= 799 then
			ent.zonetype = Zones.Type["Velocity Zone"]
			ent.embedded = Type - 699 -- 700 will be embedded type 1 as the lowest, allowing 100 combinations
		elseif Type >= 600 and Type <= 699 then
			ent.zonetype = Zones.Type["Restart Zone"]
			ent.embedded = Type - 599  -- 600 will be embedded type 1 as the lowest, allowing 100 * 100 velocities
		elseif Type >= 500 and Type <= 599 then
			ent.zonetype = Zones.Type["Anticheat"]
			ent.embedded = Type - 499 -- 500 will be embedded type 1 as the lowest, allowing 100 styles max
		elseif Type >= 400 and Type <= 499 then
			ent.zonetype = Zones.Type["Stage End"]
			ent.embedded = Type - 399 -- 400 will be embedded type 1 as the lowest, allowing 100 stages max
		elseif Type >= 300 and Type <= 399 then
			ent.zonetype = Zones.Type["Stage Start"]
			ent.embedded = Type - 299 -- 300 will be embedded type 1 as the lowest, allowing 100 stages max
		elseif Type >= 200 and Type <= 299 then
			ent.zonetype = Zones.Type["Bonus End"]
			ent.embedded = Type - 198 -- 200 will be embedded type 2 as the lowest, allowing 101 bonuses max
		elseif Type >= 100 and Type <= 199 then
			ent.zonetype = Zones.Type["Bonus Start"]
			ent.embedded = Type - 98 -- 100 will be embedded type 2 as the lowest, allowing 101 bonuses max
		end

		-- Create the entity
		ent:Spawn()
		
		ZoneEnts[ #ZoneEnts + 1 ] = ent
		ClientEnts[ ent:EntIndex() ] = { ent.zonetype, ent.embedded }
	end
end

--[[
	Description: Reloads all zone entities and re-broadcasts them
--]]
function Zones.Reload( nodb )
	for i = 1, #ZoneEnts do
		if IsValid( ZoneEnts[ i ] ) then
			ZoneEnts[ i ]:Remove()
			ZoneEnts[ i ] = nil
		end
	end
	
	if not nodb then
		Core.CleanTable( ZoneCache )
	end
	
	Core.CleanTable( ZoneEnts )

	if nodb then
		Zones.Setup()
		Zones.BroadcastClientEnts()
	else
		Zones.Load()
		Zones.Setup()
		Zones.BroadcastClientEnts()
		
		Core.BonusEntitySetup()
	end
end
Core.ReloadZones = Zones.Reload

--[[
	Description: Translates a zone ID to a zone name
--]]
function Zones.GetName( n )
	for name,id in pairs( Zones.Type ) do
		if id == n then
			return name
		end
	end
	
	return "Unknown"
end
Core.GetZoneName = Zones.GetName

--[[
	Description: Gets the center point of a given zone with this type
	Used by: Commands 'end' and 'bonusend'
	Notes: This will not work if the zone is double
--]]
function Zones.GetCenterPoint( nType, nEmbed )
	for i = 1, #ZoneEnts do
		local zone = ZoneEnts[ i ]
		if IsValid( zone ) and zone.zonetype == nType then
			if nEmbed and nEmbed != zone.embedded then continue end
			
			local pos = zone:GetPos()
			local height = zone.max.z - zone.min.z
			
			pos.z = pos.z - (height / 2)
			return pos
		end
	end
end

--[[
	Description: Checks if the player is inside of the given zone
	Used by: Bot forcing
--]]
function Zones.IsInside( ply, nType, nEmbed )
	for i = 1, #ZoneEnts do
		local zone = ZoneEnts[ i ]
		if IsValid( zone ) and zone.zonetype == nType then
			if nEmbed and nEmbed != zone.embedded then continue end
			
			if table.HasValue( ents.FindInBox( zone.min, zone.max ), ply ) then
				return true
			end
		end
	end
end
Core.IsInsideZone = Zones.IsInside

--[[
	Description: Gets the center point of a bonus zone if it exists
	Used by: Bonus resetting
--]]
function Zones.GetBonusPoint( nID )
	for i = 1, #ZoneEnts do
		local zone = ZoneEnts[ i ]
		if IsValid( zone ) then
			if zone.zonetype != Zones.Type["Bonus Start"] then continue end
			
			local embed = zone.embedded and zone.embedded - 1 or 0
			if embed == nID then
				return { zone.min, zone.max, zone:GetPos() }
			end
		end
	end
end

--[[
	Description: Gets all bonus ids
	Used by: Commands
--]]
function Zones.GetBonusIDs()
	local ids = {}
	
	for i = 1, #ZoneEnts do
		local zone = ZoneEnts[ i ]
		if IsValid( zone ) then
			if zone.zonetype != Zones.Type["Bonus Start"] then continue end
			
			ids[ #ids + 1 ] = zone.embedded and zone.embedded - 1 or 0
		end
	end
	
	return ids
end

--[[
	Description: Checks if the bonus is being done on the right style
--]]
function Zones.ValidateBonusStyle( ply, embedded )
	if not Core.IsValidBonus( ply.Style ) then return false end
	
	return ply.Style - Styles.Bonus == (embedded and embedded - 1 or 0)
end

--[[
	Description: Analyzes a zone and returns more data if available
--]]
function Zones:GetZoneInfo( zone )
	if not IsValid( zone ) then return "" end
	if self.Editor.Embedded[ zone.zonetype ] then
		return " (Data: " .. (zone.embedded or "Blank") .. ")"
	else
		return ""
	end
end

--[[
	Description: Checks if an option is applied to a map
--]]
function Zones.IsOption( opt )
	return bit.band( Timer.Options, opt ) > 0
end

--[[
	Description: Applies all options to the map
--]]
function Zones.CheckOptions()
	if Zones.IsOption( Zones.Options.NoSpeedLimit ) then
		RunConsoleCommand( "sv_maxvelocity", Zones.Settings.UnlimitedVelocity )
	else
		if Config.GameType == "bhophard" then
			Zones.Settings.MaxVelocity = Zones.Settings.MaxVelocityHard
		end
		
		RunConsoleCommand( "sv_maxvelocity", Zones.Settings.MaxVelocity )
	end
end

--[[
	Description: Finds the most appropriate spawn angle
--]]
function Zones.SetSpawnAngles()
	-- Set base value
	local top, selected = 0
	
	-- Loop over the spawns
	for value,num in pairs( Timer.Spawns ) do
		if num > top then
			top = num
			selected = value
		end
	end
	
	-- Get the top one
	if selected then
		Timer.BaseAngles = util.StringToType( selected, "Angle" )
	end
	
	-- Let's convert stored data
	local tps = {}
	for _,item in pairs( Timer.Teleports ) do
		tps[ #tps + 1 ] = { util.StringToType( item[ 1 ], "Vector" ), util.StringToType( item[ 2 ], "Angle" ) }
	end
	
	-- Create a temporary function
	local function FindNearestSpawn( at, tab )
		local order = {}
		for _,v in pairs( tab ) do
			local distance = (at - v[ 1 ]):Length()
			order[ #order + 1 ] = { Dist = distance, Vec = v[ 1 ], Ang = v[ 2 ] }
		end
		
		-- Sort by distance
		table.SortByMember( order, "Dist", true )
		
		-- Get the one that doesn't collide
		for i = 1, #order do
			local tr = util.TraceLine( { start = at, endpos = order[ i ].Vec } )
			if not tr.HitWorld then
				return order[ i ]
			end
		end
		
		-- Otherwise, return the top entry
		return order[ 1 ]
	end
	
	-- Now let's find the bonus zones
	Timer.BonusAngles = {}
	
	-- Get the list
	for _,i in pairs( Zones.GetBonusIDs() ) do
		local data = Zones.GetBonusPoint( i )
		
		if data then
			local near = FindNearestSpawn( data[ 3 ], tps )
			
			if near then
				Timer.BonusAngles[ i ] = near.Ang
			end
		end
	end
end

--[[
	Description: Processes a velocity zone touch
--]]
function PLAYER:ProcessVelocityZone( ent, endt )
	-- Validate whether the player is legit and in a bonus
	if not IsValid( self ) or not self.Style or not ent.embedded then return end
	
	-- Extract all useful data from the embedded data
	local vel, frac = math.modf( ent.embedded )
	local ang, bfrac = math.modf( frac * 1000 )
	local bits = math.Round( bfrac * 10 )
	
	-- See which EntityTouch event we want to handle
	if bit.band( bits, 1 ) > 0 then
		if endt then return end
	else
		if not endt then return end
	end
	
	-- Check if double-boosting is disabled
	if bit.band( bits, 2 ) > 0 then
		if self:GetVelocity():Length2D() * 2 > vel * 100 then return end
	end
	
	-- This means bonus only
	if bit.band( bits, 4 ) == 0 then
		if not self.Tb or not Core.IsValidBonus( self.Style ) then return end
	end
	
	-- Now create and transform the vector
	local vec = Vector( 1, 0, 0 )
	vec:Mul( vel * 100 )
	vec:Rotate( Angle( 0, ang, 0 ) )
	
	-- Apply the velocity to the player
	self:SetVelocity( vec )
end

-- Custom entity initialization
Zones.CustomEnts = {}
Zones.CustomEnts[ Zones.Type["Solid AC"] ] = function( zone )
	local Type = zone["nType"]
	local P1, P2 = zone["vPos1"], zone["vPos2"]
	local M1 = (P1 + P2) / 2
	
	-- Creates the entity
	local ent = ents.Create( "SolidBlockEnt" )
	ent:SetPos( P1 )
	ent.basemin = P1
	ent.basemax = P2
	ent.min = Vector( 0, 0, 0 )
	ent.max = P2 - P1
	ent.zonetype = Type
	ent.truetype = Type
	ent:Spawn()
	
	return ent
end


-- Zone editor
Zones.Editor = {}
Zones.Editor.List = {}

Zones.Editor.Embedded = {
	[2] = "Bonus Start",
	[3] = "Bonus End",
	[8] = "Stage Start",
	[9] = "Stage End",
	[4] = "Anticheat",
	[10] = "Restart Zone",
	[11] = "Velocity Zone"
}

Zones.Editor.EmbeddedOffsets = {
	[2] = 96, -- 2 + 96 + 2 = 100 minimum at bonus 2
	[3] = 195, -- 3 + 195 + 2 = 200 minimum at bonus 2
	[8] = 291, -- 8 + 291 + 1 = 300 minimum at stage 1
	[9] = 390, -- 9 + 390 + 1 = 400 minimum at stage 1
	[4] = 495, -- 4 + 495 + 1 = 500 minimum at style 1
	[10] = 589, -- 10 + 589 + 1 = 600 minimum at speed 100
	[11] = 688 -- 11 + 688 + 1 = 700 minimum at combination 1
}

Zones.Editor.Double = {
	[4] = "Anticheat",
	[5] = "Freestyle",
	[6] = "Normal AC",
	[7] = "Bonus AC",
	[8] = "Stage Start",
	[9] = "Stage End",
	[10] = "Restart Zone",
	[11] = "Velocity Zone"
}

--[[
	Description: Start setting a zone with the given ID
--]]
function Zones.Editor:StartSet( ply, ID )
	-- Set default params
	local params = { "None" }

	-- Avoid problems with people overriding zones they shouldn't be overriding
	if self.Double[ ID ] and not ply.ZoneExtra then
		ply.ZoneExtra = true
		params[ #params + 1 ] = "Additional"
	elseif ply.ZoneExtra then
		params[ #params + 1 ] = "Additional"
	end
	
	-- Check if it's embeddable
	if self.Embedded[ ID ] then
		params[ #params + 1 ] = "Embedded (" .. (ply.AdminZoneID and ply.AdminZoneID or "None") .. ")"
	end
	
	-- Remove blank embed ID
	if #params > 1 then
		table.remove( params, 1 )
	end

	-- Set the active session
	self.List[ ply ] = {
		Active = true,
		Start = ply:GetPos(),
		Type = ID
	}
	
	-- Let the client know we're setting a zone
	Core.Send( ply, "Admin", { "EditZone", self.List[ ply ] } )
	Core.Print( ply, "Admin", Core.Text( "ZoneStart", Zones.GetName( ID ), string.Implode( ", ", params ) ) )
end

--[[
	Description: Checks if we're setting something and finishes it if we're all good
--]]
function Zones.Editor:CheckSet( ply, finish, extra )
	-- Only finish if we have an active session
	if self.List[ ply ] then
		-- When we're finishing, actually set the zone
		if finish then
			if extra then
				ply.ZoneExtra = nil
			end
			
			-- Finalize the session
			self:FinishSet( ply, extra )
		end

		return true
	end
end

--[[
	Description: Cancels a zone placement session
--]]
function Zones.Editor:CancelSet( ply, force )
	-- Clean the list if it exists
	if self.List[ ply ] then
		Core.CleanTable( self.List[ ply ] )
	end
	
	-- Clear session and let the client know of this as well
	self.List[ ply ] = nil
	Core.Send( ply, "Admin", { "EditZone", self.List[ ply ] } )
	Core.Print( ply, "Admin", Core.Text( force and "ZoneCancel" or "ZoneFinish" ) )
end

--[[
	Description: Finishes the session and inserts the new entry straight into the database
--]]
function Zones.Editor:FinishSet( ply, extra )
	-- Get the active editor
	local editor = self.List[ ply ]
	if not editor then return end
	
	-- Custom zones
	if ply.AdminZoneID and Zones.Editor.EmbeddedOffsets[ editor.Type ] then
		local embed = editor.Type + Zones.Editor.EmbeddedOffsets[ editor.Type ] + ply.AdminZoneID
		
		if editor.Type == Zones.Type["Stage End"] then
			ply.AdminZoneID = ply.AdminZoneID + 1
			Core.Print( ply, "Admin", Core.Text( "ZoneIDIncrement", ply.AdminZoneID ) )
		end
		
		editor.Type = embed
	end
	
	-- If we haven't got an end set yet, set it to the current position
	if not editor.End then
		editor.End = ply:GetPos()
	end
	
	-- Obtain the coordinates
	local s, e = editor.Start, editor.End
	local Min = util.TypeToString( Vector( math.min( s.x, e.x ), math.min( s.y, e.y ), math.min( s.z, e.z ) ) )
	local Max = util.TypeToString( Vector( math.max( s.x, e.x ), math.max( s.y, e.y ), math.max( s.z + 128, e.z + 128 ) ) )
	
	-- Check if it's a new zone or an existing one and update it
	Prepare(
		"SELECT nType FROM game_zones WHERE szMap = {0} AND nType = {1}",
		{ Timer:GetMap(), editor.Type }
	)( function( data, varArg, szError )
		if Core.Assert( data, "nType" ) and not varArg then
			Prepare( "UPDATE game_zones SET vPos1 = {0}, vPos2 = {1} WHERE szMap = {2} AND nType = {3}", { Min, Max, Timer:GetMap(), editor.Type } )
		else
			Prepare( "INSERT INTO game_zones VALUES ({0}, {1}, {2}, {3})", { Timer:GetMap(), editor.Type, Min, Max } )
		end
	end, extra )
	
	-- Close the session and reload all zones
	self:CancelSet( ply )
	Zones.Reload()
end


--[[
	Description: Setups up all server entities
	Used by: Map initialization
--]]
local MapPlatforms, PlatformBoosters = {}, {}
function Core.SetupMapEntities()
	if Zones.IsSetup then return end
	
	-- Make sure it doesn't run twice
	Zones.IsSetup = true
	
	-- Load entities
	Zones.Setup()
	
	-- Execute map checks
	Zones.CheckOptions()
	
	-- Check the spawns
	Zones.SetSpawnAngles()
	
	-- Clean the table if there is anything in it
	if not MapPlatforms.NoWipe then
		Core.CleanTable( MapPlatforms )
		Core.CleanTable( PlatformBoosters )
	else
		MapPlatforms.NoWipe = nil
	end
	
	-- Remove extra pointless stuff that lags
	hook.Remove( "PlayerTick", "TickWidgets" )
	hook.Remove( "PreDrawHalos", "PropertiesHover" )
	
	-- Surfers hate bullets!
	if Config.IsSurf then
		hook.Remove( "PlayerPostThink", "ProcessFire" )
	end
	
	-- Check if we have additional functions to be executed
	if Core.BonusEntitySetup then
		Core.BonusEntitySetup()
	end
	
	-- Check if we have some custom PostInit hooks
	if Zones.CustomEntitySetup then
		Zones.CustomEntitySetup( Timer )
	end
	
	-- Pre-cache models
	for _,model in pairs( Core.ContentText( "ValidModels" ) ) do util.PrecacheModel( "models/player/" .. model .. ".mdl" ) end
	for _,model in pairs( Core.ContentText( "FemaleModels" ) ) do util.PrecacheModel( "models/player/" .. model .. ".mdl" ) end
	
	-- Enable fading platforms
	for _,ent in pairs( ents.FindByClass( "func_lod" ) ) do
		ent:SetRenderMode( RENDERMODE_TRANSALPHA )
	end
	
	-- Gets rid of the "Couldn't dispatch user message (21)" errors in console
	for _,ent in pairs( ents.FindByClass( "env_hudhint" ) ) do
		ent:Remove()
	end
	
	-- Enable fading non-platforms
	for _,ent in pairs( ents.GetAll() ) do
		if ent:GetRenderFX() != 0 and ent:GetRenderMode() == 0 then
			ent:SetRenderMode( RENDERMODE_TRANSALPHA )
		end
	end
	
	-- Since this might get called a lot, localize
	local index = IndexPlatform
	local inbox = ents.FindInBox
	local inmap = Timer:GetMap()
	
	-- Loop over all door platforms
	for _,ent in pairs( ents.FindByClass( "func_door" ) ) do
		if not ent.IsP then continue end
		
		local mins = ent:OBBMins()
		local maxs = ent:OBBMaxs()
		local h = maxs.z - mins.z

		if (h > 80 and not Zones.SpecialDoorMaps[ inmap ]) or Zones.MovingDoorMaps[ inmap ] then continue end
		local tab = inbox( ent:LocalToWorld( mins ) - Vector( 0, 0, 10 ), ent:LocalToWorld( maxs ) + Vector( 0, 0, 5 ) )
		
		if (tab and #tab > 0) or ent.BHSp > 100 then
			local teleport
			for i = 1, #tab do
				if IsValid( tab[ i ] ) and tab[ i ]:GetClass() == "trigger_teleport" then 
					teleport = tab[ i ]
				end
			end
			
			if teleport or ent.BHSp > 100 then
				ent:Fire( "Lock" )
				ent:SetKeyValue( "spawnflags", "1024" )
				ent:SetKeyValue( "speed", "0" )
				ent:SetRenderMode( RENDERMODE_TRANSALPHA )
				
				if ent.BHS then
					ent:SetKeyValue( "locked_sound", ent.BHS )
				else
					ent:SetKeyValue( "locked_sound", "DoorSound.DefaultMove" )
				end
				
				local nid = ent:EntIndex()
				index( nid )
				MapPlatforms[ #MapPlatforms + 1 ] = nid
				
				if ent.BHSp > 100 then
					index( nid, ent.BHSp )
					PlatformBoosters[ nid ] = ent.BHSp
				end
			end
		end
	end
	
	-- Loop over all button platforms
	for _,ent in pairs( ents.FindByClass( "func_button" ) ) do
		if not ent.IsP then continue end
		if ent.SpawnFlags == "256" then
			local mins = ent:OBBMins()
			local maxs = ent:OBBMaxs()
			local tab = inbox( ent:LocalToWorld( mins ) - Vector( 0, 0, 10 ), ent:LocalToWorld( maxs ) + Vector( 0, 0, 5 ) )
			
			if tab and #tab > 0 then
				local teleport
				for i = 1, #tab do
					if IsValid( tab[ i ] ) and tab[ i ]:GetClass() == "trigger_teleport" then
						teleport = tab[ i ]
					end
				end
				
				if teleport then
					ent:Fire( "Lock" )
					ent:SetKeyValue( "spawnflags", "257" )
					ent:SetKeyValue( "speed", "0" )
					ent:SetRenderMode( RENDERMODE_TRANSALPHA )
					
					if ent.BHS then
						ent:SetKeyValue( "locked_sound", ent.BHS )
					else
						ent:SetKeyValue( "locked_sound", "None (Silent)" )
					end
					
					local nid = ent:EntIndex()
					index( nid )
					MapPlatforms[ #MapPlatforms + 1 ] = nid
				end
			end
		end
	end
end

--[[
	Description: Sends the platform indexes as well as timer indexes to the client
--]]
function Zones.SendPlatforms( ply )
	-- Send entity data
	NetPrepare( "Client/Entities", { ClientEnts, Zones.Type, MapPlatforms, PlatformBoosters } ):Send( ply )
end
Core.Register( "Global/Platforms", Zones.SendPlatforms )

--[[
	Description: Broadcast all timer entities
	Used by: Zone reloading
--]]
function Zones.BroadcastClientEnts()
	NetPrepare( "Client/Entities", { ClientEnts } ):Broadcast()
end



-- Getters and setters
local Lefty, Righty, Bypass, PsuedoOff = IN_LEFT, IN_RIGHT

--[[
	Description: Formats the date
	Notes: I moved it here because I thought the format looked messy
--]]
function Timer.GetCurrentDate( bFormat )
	if bFormat then
		return OD( "%Y-%m-%d %H:%M:%S", OT() )
	else
		return OT()
	end
end

--[[
	Description: Returns the current map
	Notes: No idea why I made a function for caching this (probably because game.GetMap() didn't fit with the rest)
--]]
function Timer:GetMap()
	if not self.CurrentMap then
		self.CurrentMap = game.GetMap()
	end
	
	return self.CurrentMap
end

--[[
	Description: Converts seconds to a readable and detailed time
--]]
function Core.ConvertTime( Seconds )
	if Seconds >= 3600 then
		return FO( "%d:%.2d:%.2d.%.3d", FL( Seconds / 3600 ), FL( Seconds / 60 % 60 ), FL( Seconds % 60 ), FL( Seconds * 1000 % 1000 ) )
	else
		return FO( "%.2d:%.2d.%.3d", FL( Seconds / 60 % 60 ), FL( Seconds % 60 ), FL( Seconds * 1000 % 1000 ) )
	end
end
Timer.Convert = Core.ConvertTime

--[[
	Description: Returns a variable from the Timer instance
	Used by: Command, admin
--]]
function Core.GetMapVariable( szType )
	if szType == "Plays" then
		return Timer.Plays
	elseif szType == "Multiplier" then
		return Timer.Multiplier
	elseif szType == "Bonus" then
		return Timer.BonusMultiplier
	elseif szType == "Options" then
		return Timer.Options
	elseif szType == "OptionList" then
		return Zones.Options
	elseif szType == "Tier" then
		return Timer.Tier
	elseif szType == "Type" then
		return Timer.Type
	elseif szType == "IsBindBypass" then
		return Bypass
	elseif szType == "Platforms" then
		return MapPlatforms
	end
end

--[[
	Description: Sets a variable on the timer object
	Used by: Admin panel
--]]
function Core.SetMapVariable( szType, varObj )
	Timer[ szType ] = varObj
end

--[[
	Description: Allows remote files to disable +left and +right checking
	Used by: Map files for fly maps
--]]
function Core.BypassStrafeBinds( bValue )
	Bypass = bValue
end

--[[
	Description: Returns a random number in range
	Notes: Apparently the first few calls to math.random are not exactly random (caused for weird behavior in RandomPairs)
--]]
function Core.TrueRandom( nUp, nDown )
	if not PsuedoOff then
		MR() MR() MR()
		PsuedoOff = true
	end
	
	return MR( nUp, nDown )
end
RTV.TrueRandom = Core.TrueRandom

--[[
	Description: Gets all the zone entities from the table
	Used by: Admin panel to show what zones to remove
--]]
function Core.GetZoneEntities( data, set )
	if data then
		if set then
			ZoneCache = set
		else
			return ZoneCache
		end
	else
		return ZoneEnts
	end
end

--[[
	Description: Translates a zone name to a zone ID
--]]
function Core.GetZoneID( szType )
	if not szType then return Zones.Type end
	return Zones.Type[ szType ]
end

--[[
	Description: Gets the center point of a zone with the given type
	Used by: Command (end and bend)
--]]
function Core.GetZoneCenter( bonus, other, embed )
	return Zones.GetCenterPoint( other and Zones.Type[ other ] or (bonus and Zones.Type["Bonus End"] or Zones.Type["Normal End"]), embed )
end

--[[
	Description: Returns more data about a zone
--]]
function Core.GetZoneInfo( zone )
	return Zones:GetZoneInfo( zone )
end

--[[
	Description: Returns the zone editor table for remote usage
	Used by: Admin panel
--]]
function Core.GetZoneEditor()
	return Zones.Editor
end

--[[
	Description: Reloads options and executes checks
--]]
function Core.ReloadMapOptions()
	Zones.CheckOptions()
end

--[[
	Description: Checks if an option is applied
--]]
function Core.IsMapOption( opt )
	return Zones.IsOption( opt )
end

--[[
	Description: Gets all bonus IDs
--]]
function Core.GetBonusIDs()
	return Zones.GetBonusIDs()
end

--[[
	Description: Gets the multiplier for the given style
--]]
function Core.GetMultiplier( nStyle, bAll )
	return Timer:GetMultiplier( nStyle, bAll )
end

--[[
	Description: Gets the average for the given style
--]]
function Core.GetAverage( nStyle )
	if GetAverage( nStyle ) > 0 then
		CalcAverage( nStyle )
		return GetAverage( nStyle )
	else
		return 0
	end
end

--[[
	Description: Adds a version to the RTV tracker
--]]
function Core.AddMaplistVersion( nAmount )
	RTV:UpdateVersion( nAmount )
end

--[[
	Description: Gets the map list version (duh, that's what the name of the function implies)
--]]
function Core.GetMaplistVersion()
	return RTV.Version
end

--[[
	Description: Executes a type of map check and returns that data
--]]
function Core.MapCheck( szMap, IsBSP, GetData )
	if IsBSP then
		return RTV.IsAvailable( szMap )
	else
		if GetData then
			return RTV.GetMapData( szMap )
		else
			return RTV.MapExists( szMap )
		end
	end
end

--[[
	Description: Change whetehr or not the map vote is being cancelled
	Used by: Admin panel
--]]
function Core.ChangeVoteCancel()
	RTV.CancelVote = not RTV.CancelVote
	
	return RTV.CancelVote
end

--[[
	Description: Gets all the records in the top list cache
--]]
function Core.GetPlayerTop( nStyle )
	return TopListCache[ nStyle ] or {}
end

--[[
	Description: Gets all the players holding WRs
--]]
function Core.GetPlayerWRTop( nStyle )
	return Timer.TopWRList[ nStyle ] or {}
end

--[[
	Description: Make sure that records can be inserted for this style
--]]
function Core.EnsureStyleRecords( nStyle )
	if not Records[ nStyle ] then
		Records[ nStyle ] = {}
	end
end

--[[
	Description: Gets all records on a player for each style
--]]
function Core.GetStyleRecords( ply )
	local values = {}
	local styles = Core.GetStyles()
	for i = Styles.Normal, Config.MaxStyle do
		if not styles[i] then continue end
		local nTime, nID = Timer.GetPlayerRecord( ply, i )
		if nTime > 0 and nID > 0 then
			values[ i ] = { nTime, nID }
		end
	end
	
	return values
end

--[[
	Description: Gets a part of the record list (from nStart to nMaximum)
	Used by: Commands, network
--]]
function Core.GetRecordList( nStyle, nStart, nMaximum )
	local tab = {}
	
	for i = nStart, nMaximum do
		if Records[ nStyle ] and Records[ nStyle ][ i ] then
			tab[ i ] = Records[ nStyle ][ i ]
		end
	end

	return tab
end

--[[
	Description: Gets the top times in a list
	Used by: Commands
--]]
function Core.GetTopTimes()
	local tab = {}
	
	for style,data in pairs( Records ) do
		if data[ 1 ] and data[ 1 ]["nTime"] then
			tab[ style ] = data[ 1 ]
		end
	end
	
	return tab
end

--[[
	Description: Gets the amount of records on a style
--]]
function Core.GetRecordCount( nStyle )
	return GetRecordCount( nStyle )
end

--[[
	Description: Gets the base statistics loaded on startup
	Used by: F1 Help window
--]]
function Core.GetBaseStatistics()
	return Timer.BaseStatistics
end

--[[
	Description: Returns when a map was last played
--]]
function Core.GetLastPlayed( szMap )
	if Maps[ szMap ] then
		return Maps[ szMap ].szDate, Maps[ szMap ]
	end
end

--[[
	Description: Clears out the RTV wait period
	Used by: Server command
--]]
function Core.ClearWaitPeriod()
	RTV.WaitPeriod = 0
end

--[[
	Description: Returns the amount of time left before the vote starts
	Used by: Sockets
--]]
function Core.GetTimeLeft()
	return RTV.End - ST()
end

--[[
	Description: Updates the command count statistic
	Used by: Post entity init
--]]
function Core.UpdateCommandCount()
	Timer.BaseStatistics[ 5 ], Timer.BaseStatistics[ 6 ] = Core.CountCommands()
end



-- Fixes short lags upon loadout of several maps
local function KeyValueChecks( ent, key, value )
	if ent:GetClass() == "info_player_counterterrorist" or ent:GetClass() == "info_player_terrorist" then
		if key == "angles" then
			if not Timer.Spawns[ value ] then
				Timer.Spawns[ value ] = 1
			else
				Timer.Spawns[ value ] = Timer.Spawns[ value ] + 1
			end
		end
	elseif ent:GetClass() == "info_teleport_destination" then
		if key == "origin" then
			Timer.Teleports[ #Timer.Teleports + 1 ] = value
		elseif key == "angles" then
			Timer.Teleports[ #Timer.Teleports ] = { Timer.Teleports[ #Timer.Teleports ], value }
		end
	elseif ent:GetClass() == "game_player_equip" then
		if SU( key, 1, 4 ) == "ammo" or SU( key, 1, 5 ) == "weapon" or SU( 1, 5 ) == "item_" then
			return "1"
		end
	end
end
hook.Add( "EntityKeyValue", "KeyValueChecks", KeyValueChecks )

local uk, uj, us, es = IN_ATTACK2, IN_JUMP, Styles.Unreal, Styles.Extreme
local function UnrealBoostKey( ply, key )
	if key == uk then
		if ply.Style == us then
			ply:DoUnrealBoost( nil, nil, 5 )
		elseif ply.Style == es then
			ply:DoUnrealBoost( 0, nil, 5, ply:GetVelocity() * Vector( 2, 2, 4.5 ) )
		end
	elseif key == uj and Config.IsSurf then
		timer.Simple( 0.01, function()
			if not ply:IsOnGround() and ply:GetVelocity().z > 0 then
				ply.LastJumped = ST()
			end
		end )
	end
end
hook.Add( "KeyPress", "UnrealKeyPress", UnrealBoostKey )

local function UnrealKeyHold( ply, mv )
	if ply:IsOnGround() then return end

	local lastBoost = 0
	if ply.lastUnrealBoost != nil then
		lastBoost = ply.lastUnrealBoost
	else
		ply.lastUnrealBoost = lastBoost
	end

	if mv:KeyDown(uk) and ( ply.Style == Styles["Crazy"] or ply.Style == Styles["Cancer"] ) then
		if CurTime() - ply.lastUnrealBoost > 0.1 then
			local mult = 2.2
			ply:SetVelocity( ply:GetVelocity() * Vector( mult, mult, mult * 50 ) )
			ply.lastUnrealBoost = CurTime()
		end
	end
end
hook.Add( "Move", "UnrealKeyHold", UnrealKeyHold )

local function UnrealBoostBind( ply, _, varArgs )
	if ply.Style == us then
		local force
		if varArgs and varArgs[ 1 ] and tonumber( varArgs[ 1 ] ) then
			force = tonumber( varArgs[ 1 ] )
			
			if force then
				force = math.floor( force )
				
				if force < 1 or force > 4 then
					force = 1
				end
			end
		end
		
		ply:DoUnrealBoost( force )
	end
end
concommand.Add( "unrealboost", UnrealBoostBind )

-- Gamemode specific checks
if not Config.IsSurf then
	-- Check for this press every frame, otherwise we'll have to do it on the client and I don't like that
	local function BlockLeftRight( ply, data )
		-- Make sure to only check it when we set it to block it (so we can still use it on fly maps)
		if Bypass then return end
		
		-- Whenever we are pressing +left or +right, check if they have any timers, and stop them if they do
--		if data:KeyDown( Righty ) then
--			if ply.TAS then return end
--			if ply.Tn or ply.Tb then
--				if ply:StopAnyTimer() then
--					Core.Print( ply, "Timer", Core.Text( "StyleLeftRight" ) )
--				end
--			end
--		end
	end
	hook.Add( "SetupMove", "BlockLeftRight", BlockLeftRight )
elseif Config.IsSurf then
	-- Check for each jump landing to make sure we're legit
	local LastMessaged = {}
	local function PrehopLimitation( ply )
		if ply.Practice or Zones.IsOption( Zones.Options.TelehopMap ) then return end
		if ply.InSpawn and ply:GetVelocity():Length2D() != 0 then
			if ply.LastJumped and ST() - ply.LastJumped > 1 then return end
			
			ply:ResetSpawnPosition()
			
			timer.Simple( 0.01, function()
				if IsValid( ply ) then
					ply:SetLocalVelocity( Vector( 0, 0, 0 ) )
				end
			end )
			
			if not LastMessaged[ ply ] or ST() - LastMessaged[ ply ] > 2 then
				Player.Notification( ply, "Popup", { "Timer", Core.Text( "ZoneJumpInside" ), "information", 4 } )
				LastMessaged[ ply ] = ST()
			end
		end
	end
	hook.Add( "OnPlayerHitGround", "PrehopLimitation", PrehopLimitation )
end

-- Load all extensions
if file.Exists( Config.BaseType .. "/gamemode/extensions", "LUA" ) then
	-- Scan the directory for extensions
	local files = file.Find( Config.BaseType .. "/gamemode/extensions/*.lua", "LUA" )
	
	-- Create an init function holder
	Timer.PostInitFunc = {}
	
	-- Loop over the files
	for _,f in pairs( files ) do
		if SU( f, 1, 2 ) == "cl" then
			AddCSLuaFile( Config.BaseType .. "/gamemode/extensions/" .. f )
		elseif SU( f, 1, 2 ) == "sv" then
			include( Config.BaseType .. "/gamemode/extensions/" .. f )
			
			if Core.PostInitFunc then
				Timer.PostInitFunc[ #Timer.PostInitFunc + 1 ] = Core.PostInitFunc
			end
			
			Core.PostInitFunc = nil
		end
	end
end

-- Check if we have a map lua file, if we do, execute it
local files = file.Find( Config.BaseType .. "/gamemode/maps/*.lua", "LUA" )
for _,f in pairs( files ) do
	-- Replace for global types
	local ef = f:gsub( "wildcard", "*" ):gsub( ".lua", "" )
	
	-- Check if the map matches
	if (string.find( ef, "*", 1, true ) and string.match( Timer:GetMap(), ef )) or f:gsub( ".lua", "" ) == Timer:GetMap() then
		-- Check overrides
		if Zones[ "NoWildcard" ] and Zones[ "NoWildcard" ][ Timer:GetMap() ] and string.find( f, "wildcard", 1, true ) then continue end
		
		-- Create a global table to be populated
		__HOOK = {}
		__MAP = {}
		
		-- Load the individual map file
		include( Config.BaseType .. "/gamemode/maps/" .. f )
		
		-- Set the hook counter
		Timer.HookCount = (Timer.HookCount or 0) + 1
		
		-- Add all the custom hooks
		for identifier,func in pairs( __HOOK ) do
			hook.Add( identifier, identifier .. "_" .. Timer:GetMap() .. "_" .. Timer.HookCount, func )
		end
		
		-- Allow custom entities
		for identifier,bool in pairs( __MAP ) do
			if not Zones[ identifier ] then
				Zones[ identifier ] = {}
				
				if identifier == "CustomEntitySetup" then
					Zones[ identifier ] = bool
					break
				end
			end
			
			Zones[ identifier ][ Timer:GetMap() ] = bool
		end
		
		-- Dispose of that filthy global
		__HOOK = nil
		__MAP = nil
	end
end

local sounds = file.Find( Config.BaseType .. "/content/sound/" .. Config.MaterialID .. "/*.mp3", "LUA" )
for _,f in pairs( sounds ) do
	WRSounds[ #WRSounds + 1 ] = string.sub( f, 1, #f - 4 )
end