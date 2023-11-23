VIPS = {
	["STEAM_0:1:43979621"] = 2, --rq
	["STEAM_0:1:47723510"] = 2, --czarchasm
	["STEAM_0:0:74583369"] = 2, --frijoles
	["STEAM_0:1:118982272"] = 2, --dannykills
	["STEAM_0:1:83835528"] = 2, --south
	["STEAM_0:0:517128716"] = 2, --lorp
	["STEAM_0:0:182133780"] = 2, --drew
	["STEAM_0:0:3356741"] = 2, --astra
	["STEAM_0:0:59583774"] = 2, --greatchar
	["STEAM_0:1:30178511"] = 2, --jesse
	["STEAM_0:1:66043906"] = 2, --hunnid
	["STEAM_0:0:49487942"] = 2, --sputnik
	["STEAM_0:0:155729017"] = 1, --instinctboi
}

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

local function CaratUpper(text)
	return text:gsub("%^(%w)", string.upper)
end

function ParseColoredText(text)
	local ret = {}
	local splote = text:Split("")

	local skip = 1
	for k, v in ipairs(splote) do
		if k < skip then continue end
		-- print(k, v, skip)
		if v == "#" then
			local test = table.concat(splote, "", k, k + 6)
		--	print(test)
			if ValidHexColor(test) then
				if k != 1 then
					table.insert(ret, table.concat(splote, "", skip, k - 1))
				end
				table.insert(ret, HexToColor(test))
				skip = k + 7
			end
		end
	end
	if skip < #splote then
		table.insert(ret, table.concat(splote, "", skip))
	end

	return ret
end

Core.AddCmd( { "vip", "imgay" }, function(ply, args)
	if not VIPS[ply:SteamID()] then
		return Core.Print("General", "You're not a VIP")
	end

	// upperino time
	for k, arg in ipairs(args) do
		args[k] = CaratUpper(arg)
	end

	local arg = (args[1] or ""):lower()
	local a = arg == "clearname" or arg == "cleartag"
	if not a and (#args < 2 or (arg != "tag" and arg != "name" and arg != "chat")) then
		return Core.Print(ply, "General", "Type /vip <tag/name/chat/cleartag/clearname/clearchat> <format> to set a tag or custom name. For example: \"/vip tag #FF0000cool dude!!\" will give you a red tag that says \"cool dude!!.\" VIP+ can put multiple colors in their name/tag (like #FF0000red#00FF00green)")
	end

	if arg == "cleartag" then
		ply:SetNW2String("VIPTAG", "")
		ply:SetPData("VIPTAG", "")
		return
	elseif arg == "clearname" then
		ply:SetNW2String("VIPNAME", "")
		ply:SetPData("VIPNAME", "")
		return
	end

	if arg == "chat" then
		if not ValidHexColor(args[2]) then
			Core.Print(ply, "General", "That's not a valid color")
		else
			ply:SetNW2String("VIPCHAT", args[2])
		end

		return
	end

	local cc = table.concat(args, " ", 2)
	local lentest, _ = cc:gsub("#......", "")
	if #lentest > 16 and arg == "tag" then
		return Core.Print(ply, "General", "That is too long of a tag")
	elseif #lentest > 31 and arg == "name" then
		return Core.Print(ply, "General", "That is too long of a name")
	end

	ply:SetNW2String("VIP" .. arg:upper(), cc)
	ply:SetPData("VIP" .. arg:upper(), cc)
end)

hook.Add("PlayerInitialSpawn", "LoadVIPShit", function(ply)
	if VIPS[ply:SteamID()] then
		ply:SetNW2String("VIPTAG", ply:GetPData("VIPTAG"))
		ply:SetNW2String("VIPNAME", ply:GetPData("VIPNAME"))
	end
	ply:SetNW2Int("VIPLevel", VIPS[ply:SteamID()])
end)
