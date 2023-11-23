-- Bunny hop Utilities
-- By Meeno

-- List of keywords
local Commands = {
	"trigger",
	"triggers",
	"showtrigger",
	"showtriggers"
}

local TriggerTable = { ["Teleport"] = {}, ["Push"] = {}, ["Mulitple"] = {}}

local IWishDadLovedMe = {false}
local ServerShuttingDown = false

hook.Add("PlayerSay","TriggerToggleCommandc:",function(pl,txt)
	local Prefix = string.sub(txt,0,1)
		if Prefix == "!" or Prefix == "/" then
			for k,v in pairs(Commands) do
				if string.lower(string.sub(txt,2)) == v then
					ShowTriggersPopPeople(pl)
					return ""
				end
			end
		end
end)

local function postentload()	
	for _,ent in pairs(ents.FindByClass("trigger_teleport")) do
		table.insert(TriggerTable["Teleport"],ent)
	end

	for _,ent in pairs(ents.FindByClass("trigger_multiple")) do
		table.insert(TriggerTable["Mulitple"],ent)
	end
	for _,ent in pairs(ents.FindByClass("trigger_push")) do
		table.insert(TriggerTable["Push"],ent)
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

function ShowTriggersPopPeople(pl)
	for _,t in pairs(TriggerTable) do
		for k,p in pairs(t) do
			p:SetPreventTransmit(pl,IWishDadLovedMe[pl])
		end
	end
	IWishDadLovedMe[pl] = !IWishDadLovedMe[pl]
end

local ValidClass = {["trigger_teleport"] = true, ["trigger_push"] = true, ["trigger_multiple"] = true}

function RemoveEntFromTable(ent)
    if ServerShuttingDown then return end
    local class = ent:GetClass()
    if ValidClass[class] then
        table.remove(TriggerTable[class],table.KeyFromValue(TriggerTable[class],ent))
    end
end
hook.Add("EntityRemoved","RemoveEntFromTablec:",RemoveEntFromTable)

function ServerShuttingDownBoolChange()
    ServerShuttingDown = true
end
hook.Add("ShutDown","ServerShuttingDownBoolChangec:",ServerShuttingDownBoolChange)