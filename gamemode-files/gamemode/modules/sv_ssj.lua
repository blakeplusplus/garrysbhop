-- new ssj

-- We need to find out their first jump velocity yo!
local function SSJ_KeyPress(ply, key)
	if (key == IN_JUMP) and ply:OnGround() and (not ply.Spectating) then
		ply.ssj_data.holdingspace = true
		ply.ssj_data.jumps = {}
		ply.ssj_data.jumps[1] = SSJ_GetStatistics(ply)
		ShowSixthJump(ply)
	end
end
hook.Add("KeyPress", "SSJ_KeyPress", SSJ_KeyPress)

local function SSJ_KeyRelease(ply, key)
	if (key == IN_JUMP) and ply.ssj_data.holdingspace then
		ply.ssj_data.holdingspace = false
	end
end
hook.Add("KeyRelease", "SSJ_KeyRelease", SSJ_KeyRelease)

-- Get Statistics of a jump 
function SSJ_GetStatistics(ply)
	local velocity = ply:GetVelocity()
	local pos = ply:GetPos()
	return {velocity, pos}
end

-- Callback from ui
local cov = function(_in) return _in and 1 or 0 end
function SSJ_HandleCallback(ply, args)
	local Key = args[1]

	if (Key == 1) then
		ply.ssj_data.enabled = (not ply.ssj_data.enabled)
		ply:SetPData("ssj_enabled", cov(ply.ssj_data.enabled))
	elseif (Key == 2) then
		if not tobool(ply.ssj_data.every) then
			ply.ssj_data.every = 1
		elseif ply.ssj_data.every == 1 then
			ply.ssj_data.every = 2
		else
			ply.ssj_data.every = 0
		end 
		ply:SetPData("ssj_every", ply.ssj_data.every)
	elseif (Key == 3) then
		ply.ssj_data.speed = (not ply.ssj_data.speed)
		ply:SetPData("ssj_speed", cov(ply.ssj_data.speed))
	elseif (Key == 4) then
		ply.ssj_data.height = (not ply.ssj_data.height)
		ply:SetPData("ssj_height", cov(ply.ssj_data.height))
	elseif (Key == 5) then
		ply.ssj_data.showgains = (not ply.ssj_data.showgains)
		ply:SetPData("ssj_gains", cov(ply.ssj_data.showgains))
	end

	Core.Send( ply, "GUI/UpdateSSJ", { Key, ply.ssj_data } )
end
Core.Register( "Global/SSJ", SSJ_HandleCallback )

-- Print
function ShowSixthJump(ply)
	-- checks
	if (not ply.ssj_data) then return end
	if (not ply.ssj_data.holdingspace) then return end
	if (#ply.ssj_data.jumps > 1) and (ply.InZone) then return end
	if (ply.InPractice) then return end

	local data = ply.ssj_data.jumps[#ply.ssj_data.jumps]

	-- Data we would like to display
	local currentVelocity = data[1]:Length2D()
	local currentPosition = data[2]
	local str = {"Jumps: ", Color( 255, 157, 0 ), tostring(#ply.ssj_data.jumps), color_white, " | ", "Speed: ", Color( 255, 157, 0 ), tostring(math.Round(currentVelocity)), color_white}
	local ar = Core.Prepare( "NotifyMulti" )
	ar:String("SSJ")
	local szMessage = Core.ColorText()
	for _, v in ipairs(str) do
		szMessage:Add(v)
	end


	if (#ply.ssj_data.jumps ~= 1) then
		local oldData = ply.ssj_data.jumps[#ply.ssj_data.jumps - 1]

		-- Check
		if (not oldData) then return end

		local oldVelocity = oldData[1]:Length2D()
		local oldPosition = oldData[2]
		local difference = math.Round(currentVelocity - oldVelocity)
		local height = math.Round(currentPosition.z - oldPosition.z)

		if (ply.ssj_data.height) then
			szMessage:Add( " | Height ∆: ")
			szMessage:Add( Color( 255, 157, 0 ))
			szMessage:Add( tostring(height))
			szMessage:Add( color_white)
		end

		if (ply.ssj_data.speed) then
			szMessage:Add( " | Speed ∆: ")
			szMessage:Add( Color( 255, 157, 0 ))
			szMessage:Add( tostring(difference))
			szMessage:Add( color_white)
		end

		local data = 0
		for k,v in pairs(ply.ssj_data.gains) do
			data = data + v
		end
		local gain = math.Round(data / #ply.ssj_data.gains, 2)

		if (ply.ssj_data.showgains) then
			szMessage:Add(" | Gain %: ")
			szMessage:Add(Color(255, 157, 0))
			szMessage:Add(tostring(gain))
			szMessage:Add(color_white)
		end

		hook.Run("OnPlayerSSJ", ply, #ply.ssj_data.jumps, height, difference, gain)

		ply.ssj_data.gains = {}
	end
	ar:ColorText(szMessage)
	-- Viewers
	local Watchers = {}
 	for _, p in pairs( player.GetHumans() ) do
 		if not p.Spectating then continue end
 		local ob = p:GetObserverTarget()
 		if IsValid( ob ) and ob == ply then
  			table.insert( Watchers, p )
   		end
   	end
 	table.insert(Watchers, ply)

 	local final = {}

 	for k, v in pairs(Watchers) do
 		if (not v.ssj_data.enabled) then continue end
 		if v.ssj_data.every == 1 then
 			if #v.ssj_data.jumps != 6 then continue end
 		elseif v.ssj_data.every == 2 then
 			if #v.ssj_data.jumps % 6 != 0 then continue end
 		end
 		// Core.Print( v, "Timer", unpack(str) )
 		table.insert(final, v)
 	end

 	ar:Send( final )
end


function GetGainData(ply, data)
	if (not ply.ssj_data) then return end
	local aim = data:GetMoveAngles()
	local fw, rt = aim:Forward(), aim:Right()
	local fm, sm = data:GetForwardSpeed(), data:GetSideSpeed()
	local mv = 32.8
	local wv = fw * fm + rt * sm
	
	local wishspd = wv:Length()
	wishspd = math.Clamp(wishspd, 0, mv)
	
	local wishdir = wv:GetNormal()
	local current = data:GetVelocity():Dot(wishdir)
	
	local addspeed = wishspd - current
	if addspeed <= 0 then return end
	
	if current <= 30 then
		gain = math.Round(((wishspd - math.abs(current)) / wishspd * 100), 1)
		table.insert(ply.ssj_data.gains, gain)
	end
end
hook.Add( "SetupMove", "GetGainData", GetGainData )
