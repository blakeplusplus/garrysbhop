-- Bunny hop Utilities
-- By Meeno

-- List of keywords
local Commands = {
	"trigger",
	"triggers",
	"showtrigger",
	"showtriggers",
	
	"triggerfix",
}

local TriggerTable = { ["trigger_teleport"] = {}, ["trigger_push"] = {}, ["trigger_multiple"] = {}}
local ValidClass = {["trigger_teleport"] = true, ["trigger_push"] = true, ["trigger_multiple"] = true}

local IWishDadLovedMe = {false}
local ServerShuttingDown = false

hook.Add("PlayerSay","TriggerToggleCommandc:",function(pl,txt)
	local Prefix = string.sub(txt,0,1)
	if Prefix == "!" or Prefix == "/" then
		local PlayerCmd = string.lower(string.sub(txt,2))
		for k,v in pairs(Commands) do
			if PlayerCmd == v then
				if PlayerCmd == "triggerfix" then
					FixTriggersFixPeople(pl)
					return ""
				end
				ShowTriggersPopPeople(pl)
				return ""
			end
		end
	end
end)

local function postentload()	
	for k,p in pairs(ValidClass) do
		for _,ent in pairs(ents.FindByClass(k)) do
			table.insert(TriggerTable[k],ent)
		end
	end
end
hook.Add("InitPostEntity","PostEntLoadTriggerStuff",postentload)

local function InitSpawnPreventTransmit(pl)
	if pl:IsBot() then return end 

	-- This was more consistently faster compared to for i = 1,#t do but both had slower/faster calls
	for _,t in pairs(TriggerTable) do
		for k,p in pairs(t) do
			p:RemoveEffects(EF_NODRAW)
			p:SetPreventTransmit(pl,true)
		end
	end

end
hook.Add("PlayerInitialSpawn","123fhh23g4h1f23faghdsk,345",InitSpawnPreventTransmit)

function FixTriggersFixPeople(pl)
	for k,p in pairs(ValidClass) do
		for _,ent in pairs(ents.FindByClass(k)) do
			if !table.KeyFromValue(TriggerTable[k],ent) then
				table.insert(TriggerTable[k],ent)
			end
		end
	end
	
	for _,t in pairs(TriggerTable) do
		for k,p in pairs(t) do
			p:RemoveEffects(EF_NODRAW)
			p:SetPreventTransmit(pl,true)
		end
	end
end

function ShowTriggersPopPeople(pl)
	for _,t in pairs(TriggerTable) do
		for k,p in pairs(t) do
			p:SetPreventTransmit(pl,IWishDadLovedMe[pl])
		end
	end
	IWishDadLovedMe[pl] = !IWishDadLovedMe[pl]
end

function RemoveEntFromTable(ent)
    local class = ent:GetClass()
    if ValidClass[class] then
		table.remove(TriggerTable[class],table.KeyFromValue(TriggerTable[class],ent))
    end
end
hook.Add("EntityRemoved","RemoveEntFromTablec:",RemoveEntFromTable)