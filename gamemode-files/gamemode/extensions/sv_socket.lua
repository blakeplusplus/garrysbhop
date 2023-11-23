-- Module documentation: https://github.com/Bromvlieg/gm_bromsock
-- Thank you Bromvlieg for making this, my fellow Nederlander

local Socket = {}
Socket.Module = require( "bromsock" ) --we dont have this file so we just dont call it
Socket.Ports = { ["bhopeasy"] = 4318, ["bhophard"] = 4319, ["surfmain"] = 4320 }
Socket.Received = 0


--[[
	Description: Initializes the sockets
--]]
local Prepare = SQLPrepare
function Socket.Init()
	local port = Socket.Ports[ Core.Config.GameType ]
	if not port then return end
	
	local serv = BromSock()
	serv:Listen( port )

	serv:SetCallbackAccept( Socket.AcceptClient )
	serv:Accept()
	
	Socket.Bind = serv
end
Core.PostInitFunc = Socket.Init

--[[
	Description: Accepts the client and assigns handlers
--]]
function Socket.AcceptClient( server, client )
	if not client then return end
	
	local ip = client:GetIP()
	if ip != "127.0.0.1" and not string.find( ip, "208.146.35", 1, true ) then
		client:Disconnect()
		server:Accept()
		
		return print( "Blocked socket connection from", ip )
	end
	
	client:SetCallbackReceive( Socket.ReceiveClient )
	client:SetCallbackDisconnect( function() end )
	
	client:SetTimeout( 1000 )
	client:ReceiveUntil( "\r\n" )
	
	server:Accept()
end

--[[
	Description: Receives data from the given socket
--]]
function Socket.ReceiveClient( sock, packet )
	local data = packet:ReadLine()
	local split = string.find( data, "\n", 1, true )
	local ptype, parg = ""
	
	if split then
		ptype = string.sub( data, 1, split - 1 )
		parg = string.sub( data, split + 1, #data )
	else
		ptype = data
	end

	Socket.HandlePacket( sock, ptype, parg )
end


--[[
	Description: Handles a specific packet
--]]
function Socket.HandlePacket( sock, id, arg )
	Socket.Received = Socket.Received + 1
	
	local output = BromPacket()
	local ply = { OutputSock = true }
	
	if id == "MAP" then
		output:WriteLine( game.GetMap() )
	elseif id == "MAPINFO" then
		local func = Core.GetCmd( "map" )
		local text = func( ply, {} )
		
		output:WriteLine( text )
	elseif id == "RECORDS" then
		local details = string.Explode( ",", arg )
		local map, style, mi, ma = details[ 1 ], tonumber( details[ 2 ] ), 1, 25
		if not Core.MapCheck( map ) or not style or not Core.IsValidStyle( style ) then
			return Socket.Trash( sock, output, "-1" )
		end
		
		if tonumber( details[ 3 ] ) and tonumber( details[ 4 ] ) then
			mi = math.Clamp( tonumber( details[ 4 ] ) + 1, tonumber( details[ 4 ] ) + 1, tonumber( details[ 3 ] ) )
			ma = math.Clamp( tonumber( details[ 4 ] ) + 25, tonumber( details[ 4 ] ) + 25, tonumber( details[ 3 ] ) )
		end
		
		local list, count = Core.DoRemoteWR( ply, map, style, { mi, ma } )
		if list and count and Core.CountHash( list ) > 0 then
			output:WriteStringRaw( count .. "," )
			
			local first, last
			for pos,_ in SortedPairs( list ) do if not first then first = pos end last = pos end
			
			output:WriteStringRaw( first .. "," )
			output:WriteStringRaw( last .. ";" )
			
			for k,data in SortedPairs( list ) do
				output:WriteStringRaw( data.szUID .. "," )
				output:WriteStringRaw( data.nDate .. "," )
				output:WriteStringRaw( data.nTime .. "," )
				output:WriteStringRaw( data.vData )
				
				if k != last then
					output:WriteStringRaw( ";" )
				end
			end
			
			output:WriteStringRaw( "\r\n" )
		else
			output:WriteLine( "0" )
		end
	elseif id == "TOP_STYLE" then
		local tab = Core.GetTopTimes()
		if Core.CountHash( tab ) > 0 then
			local last
			for pos,_ in SortedPairs( tab ) do last = pos end
			
			output:WriteStringRaw( "TOP," .. Core.CountHash( tab ) .. ";" )
			
			for style,data in SortedPairs( tab ) do
				output:WriteStringRaw( style .. "," )
				output:WriteStringRaw( data.szUID .. "," )
				output:WriteStringRaw( data.nDate .. "," )
				output:WriteStringRaw( data.nTime .. "," )
				output:WriteStringRaw( data.vData )
				
				if style != last then
					output:WriteStringRaw( ";" )
				end
			end
			
			output:WriteStringRaw( "\r\n" )
		else
			output:WriteLine( "TOP,0;" )
		end
	elseif id == "TOP_TYPE" then
		local details = string.Explode( ",", arg )
		local nType, nStyle = tonumber( details[ 1 ] ), tonumber( details[ 2 ] )
		if not nType or not nStyle or not Core.IsValidStyle( nStyle ) then
			return Socket.Trash( sock, output, "0" )
		end
		
		-- Points top
		if nType == 0 then
			local data = Core.GetPlayerTop( nStyle )
			if #data == 0 then
				output:WriteLine( "0" )
			else
				for i = 1, #data do
					output:WriteStringRaw( data[ i ].szUID .. "," )
					output:WriteStringRaw( math.Round( data[ i ].nSum or 0, 2 ) .. "" )
					
					if i != #data then
						output:WriteStringRaw( ";" )
					end
				end
				
				output:WriteStringRaw( "\r\n" )
			end
			
		-- Race top
		elseif nType == 1 then
			local data = Core.GetRaceTop( nStyle )
			if #data == 0 then
				output:WriteLine( "0" )
			else
				for i = 1, #data do
					output:WriteStringRaw( data[ i ].szUID .. "," )
					output:WriteStringRaw( data[ i ].nWins .. "," )
					output:WriteStringRaw( data[ i ].nStreak .. "" )
					
					if i != #data then
						output:WriteStringRaw( ";" )
					end
				end
				
				output:WriteStringRaw( "\r\n" )
			end
			
		-- LJ top
		elseif nType == 2 then
			local data = Core.GetJumpStats( nStyle )
			if #data == 0 then
				output:WriteLine( "0" )
			else
				for i = 1, #data do
					output:WriteStringRaw( data[ i ].szUID .. "," )
					output:WriteStringRaw( data[ i ].nValue .. "," )
					output:WriteStringRaw( data[ i ].nDate .. "," )
					output:WriteStringRaw( data[ i ].vData )
					
					if i != #data then
						output:WriteStringRaw( ";" )
					end
				end
				
				output:WriteStringRaw( "\r\n" )
			end
			
		else
			return Socket.Trash( sock, output, "0" )
		end
	elseif id == "PLAYERS" then
		local plys = player.GetHumans()
		for i = 1, #plys do
			local p = plys[ i ]
			local rt, rc = Core.ObtainRank( p.Rank, p.Style, true )
			
			output:WriteStringRaw( p:Name():gsub( ",", "" ) .. "," )
			output:WriteStringRaw( p:SteamID64() .. "," )
			output:WriteStringRaw( p.Style .. "," )
			output:WriteStringRaw( p.Record .. "," )
			output:WriteStringRaw( ((p.Tb and SysTime() - p.Tb) or (p.Tn and SysTime() - p.Tn) or 0) .. "," )
			output:WriteStringRaw( rt .. "," )
			output:WriteStringRaw( util.TypeToString( rc ) .. "," )
			output:WriteStringRaw( Core.GetAdminAccess( p ) .. "," )
			output:WriteStringRaw( (p.ConnectedAt and SysTime() - p.ConnectedAt or 0) .. "" )
			
			if i != #plys then
				output:WriteStringRaw( ";" )
			end
		end
		
		if #plys == 0 then
			output:WriteLine( "0" )
		else
			output:WriteStringRaw( "\r\n" )
		end
	elseif id == "TIME" then
		local formatted = Core.ConvertTime( Core.GetTimeLeft() )
		
		output:WriteLine( formatted )
	end
	
	sock:Send( output )
	sock:Receive()
end

--[[
	Description: Easy function to close off the connection anywhere
--]]
function Socket.Trash( sock, output, data )
	output = output or BromPacket()
	output:WriteLine( data or "0" )
	
	sock:Send( output )
	sock:Receive()
end


--[[
	Description: Gets the amount of packets received
--]]
function Core.GetPacketsReceived()
	return Socket.Received
end