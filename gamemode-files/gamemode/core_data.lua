util.AddNetworkString( "SecureTransfer" )
util.AddNetworkString( "BinaryTransfer" )
util.AddNetworkString( "KeyDataTransfer" )
util.AddNetworkString( "PlayerCenter" )
util.AddNetworkString( "QuickNet" )
util.AddNetworkString( "QuickPrint" )

-- Validation functions

--[[
	Description: Asserts whether or not a result from a data query is valid
--]]
function Core.Assert( varType, szType )
	if varType and type( varType ) == "table" and varType[ 1 ] and type( varType[ 1 ] ) == "table" and varType[ 1 ][ szType ] then
		return true, varType[ 1 ][ szType ]
	end
	
	return false, nil
end

--[[
	Description: Makes sure an entry for the database isn't NULL
--]]
function Core.Null( varInput, varAlternate )
	if varInput and type( varInput ) == "string" and varInput != "NULL" then
		return varInput
	end
	
	return varAlternate
end

--[[
	Description: Adds all available resources to the download queue
	Notes: WR sounds are now retrieved directly from the FastDL as they aren't required that often
--]]
function Core.AddResources()
	local Identifier = Core.Config.MaterialID
	resource.AddFile( "materials/" .. Identifier .. "/timer.png" )
	
	for i = 1, 13 do
		resource.AddFile( "materials/" .. Identifier .. "/icon_rank" .. i .. ".png" )
	end
	
	for i = 1, 6 do
		resource.AddFile( "materials/" .. Identifier .. "/icon_special" .. i .. ".png" )
	end

	resource.AddFile( "resource/fonts/latoregular.ttf" )
end

-- Networking code

--[[
	Description: Sends data over the main network connection to the given player or players
--]]
local net = net
function Core.Send( ply, szAction, ... )
	net.Start( "SecureTransfer" )
	net.WriteString( szAction )
	
	local arg = { ... }
	if arg[ 1 ] and type( arg[ 1 ] ) == "table" then
		net.WriteBit( true )
		net.WriteTable( arg[ 1 ] )
	elseif arg[ 1 ] then
		net.WriteBit( true )
		net.WriteTable( arg )
	elseif not arg[ 1 ] then
		net.WriteBit( false )
	end
	
	net.Send( ply )
end

--[[
	Description: Broadcasts a network message, optionally excluding varExlude
--]]
function Core.Broadcast( szAction, varArgs, varExclude )
	net.Start( "SecureTransfer" )
	net.WriteString( szAction )
	
	if varArgs and type( varArgs ) == "table" then
		net.WriteBit( true )
		net.WriteTable( varArgs )
	else
		net.WriteBit( false )
	end
	
	if varExclude and (type( varExlude ) == "table" or (IsValid( varExclude ) and varExclude:IsPlayer())) then
		net.SendOmit( varExclude )
	else
		net.Broadcast()
	end
end

--[[
	Description: Easy printing for the server side
--]]
function Core.Print( plys, szPrefix, szText )
	net.Start( "QuickPrint" )
	net.WriteString( szPrefix )
	net.WriteString( szText )
	
	if plys then
		net.Send( plys )
	else
		net.Broadcast()
	end
end


-- Prepared network statements

local nets = {}
nets.Int = function( t, n, b ) net.WriteInt( n, b or 32 ) end
nets.UInt = function( t, n, b ) net.WriteUInt( n, b or 32 ) end
nets.String = function( t, s ) net.WriteString( s ) end
nets.Bit = function( t, b ) net.WriteBit( b ) end
nets.Double = function( t, n ) net.WriteDouble( n ) end
nets.Color = function( t, c ) net.WriteColor( c ) end
nets.ColorText = function( t, d ) t.Cache[ "ColorText" ]( t, d ) end
nets.Open = function() net.Start( "QuickNet" ) end
nets.Pattern = function( t, s, v ) t.Cache[ s ]( t, v ) end
nets.Send = function( t, p ) net.Send( p ) end
nets.Broadcast = function() net.Broadcast() end

--[[
	Description: Prepares a table with easy-access functions for net sending
--]]
function Core.Prepare( szType, varPattern )
	-- Open and add the type identifier
	nets:Open()
	nets:String( szType )
	
	-- Check for pattern
	if varPattern then
		nets:Pattern( szType, varPattern )
	end
	
	-- And return the easy-object
	return nets
end


--- SQL ---

-- Local functions because these are used a lot and we need the query to be ready as quick as it can be
local gp, gt, gn, gs = pairs, type, tonumber, tostring
local ss, sl, sg = string.sub, string.len, string.gsub
local sqstr, sq, lqe = sql.SQLStr, sql.Query

--[[
	Description: Prepares a query and formats it
	Notes: I like this type of queries, and they're far more secure
--]]
function SQLPrepare( szQuery, varArgs, bNoQuote, bNoParse )
	if varArgs and #varArgs > 0 then
		for i = 1, #varArgs do
			local sort = gt( varArgs[ i ] )
			local num = gn( varArgs[ i ] )
			local arg = ""
			
			if sort == "string" and not num then
				arg = sqstr( varArgs[ i ] )
				if bNoQuote then
					arg = ss( arg, 2, sl( arg ) - 1 )
				end
			elseif (sort == "string" and num) or (sort == "number") then
				arg = varArgs[ i ]
			else
				arg = gs( varArgs[ i ] ) or ""
				print( "Parameter of type " .. sort .. " was parsed to a default value on query: " .. szQuery )
			end
			
			szQuery = sg( szQuery, "{" .. i - 1 .. "}", arg )
		end
		
		if varArgs.GetQuery then
			return szQuery
		end
	end
	
	local varData, szError
	local data = sq( szQuery )
	
	if data then
		if not bNoParse then
			-- This is required because I don't want to update all Prepare statements to check for SQLite.
			-- Screw you Garry! Why haven't you added type parsing to the default SQLite library... :(
			
			for id,item in gp( data ) do
				for key,value in gp( item ) do
					if gn( value ) then
						data[ id ][ key ] = gn( value )
					end
				end
			end
		end
		
		varData = data
	else
		-- Show error in query if we're running a SELECT query, for UPDATE it's normal to not get any data
		local statement = ss( szQuery, 1, 6 )
		if statement == "SELECT" then
			szError = sql.LastError()
			
			if szError and szError != lqe then
				lqe = szError
				
				print( "SQL Error", "Error on SELECT query (" .. szQuery .. ") -> " .. szError )
			end
		else
			varData = true
		end
	end
	
	-- Return callback function
	return function( fCallback, varArg ) fCallback( varData, varArg, szError ) end
end


-- Centralized data transmission patterns
nets.Cache = {}
nets.Cache["Client/Entities"] = function( ar, args )
	if #args > 1 then
		ar:Bit( true )
	else
		ar:Bit( false )
	end
	
	ar:UInt( Core.CountHash( args[ 1 ] ), 32 )
	
	for index,data in pairs( args[ 1 ] ) do
		ar:UInt( index, 16 )
		
		if data[ 2 ] then
			ar:Bit( true )
			ar:Int( data[ 2 ] or 0, 12 )
			ar:Int( data[ 1 ] or 0, 8 )
		else
			ar:Bit( false )
			ar:Int( data[ 1 ] or 0, 8 )
		end
	end
	
	if #args > 1 then
		ar:UInt( Core.CountHash( args[ 2 ] ), 8 )
		
		for name,id in pairs( args[ 2 ] ) do
			ar:String( name )
			ar:UInt( id, 8 )
		end
		
		ar:UInt( #args[ 3 ], 16 )
		
		for i = 1, #args[ 3 ] do
			ar:UInt( args[ 3 ][ i ], 16 )
		end
		
		ar:UInt( Core.CountHash( args[ 4 ] ), 16 )
		
		for nid,bh in pairs( args[ 4 ] ) do
			ar:UInt( nid, 16 )
			ar:UInt( bh, 20 )
		end
	end
end

nets.Cache["GUI/Build"] = function( ar, args )
	ar:String( args.ID )
	ar:String( args.Title )
	ar:UInt( args.X, 10 )
	ar:UInt( args.Y, 10 )
	ar:Bit( not not args.Mouse )
	ar:Bit( not not args.Blur )
	
	local data = args.Data
	if args.ID == "Records" then
		ar:Bit( not not data.IsEdit )
		
		if data.Map then
			ar:Bit( true )
			ar:String( data.Map )
		else
			ar:Bit( false )
		end
		
		if data.Started and data.TargetID then
			ar:Bit( true )
			ar:UInt( data.Started, 16 )
			ar:UInt( data.TargetID, 16 )
		else
			ar:Bit( false )
		end
		
		ar:UInt( data[ 2 ], 16 )
		ar:Int( data[ 3 ], 8 )
		ar:UInt( data[ 4 ] or 0, 16 )
		
		for id,v in pairs( data[ 1 ] ) do
			ar:UInt( id, 16 )
			ar:String( v.szUID or "" )
			ar:Double( v.nTime or 0 )
			ar:Double( v.nPoints or 0 )
			ar:UInt( v.nDate or 0, 32 )
			ar:String( v.vData or "" )
		end
		
		ar:UInt( 0, 16 )
	elseif args.ID == "Maps" then
		ar:Int( data.Style, 8 )
		
		if data.Type and data.Version then
			ar:Bit( true )
			ar:String( data.Type )
			ar:UInt( data.Version, 20 )
			ar:UInt( #data[ 1 ], 16 )
			
			local tab = data[ 1 ]
			for i = 1, #tab do
				ar:String( tab[ i ].szMap or "" )
				ar:Double( tab[ i ].nTime or 0 )
				ar:Double( tab[ i ].nPoints or 0 )
				ar:UInt( tab[ i ].nDate or 0, 32 )
			end
		else			
			ar:Bit( false )
			
			if data.By then
				ar:Bit( true )
				ar:String( data.By )
			else
				ar:Bit( false )
			end
			
			ar:UInt( #data[ 1 ], 16 )
			
			local tab = data[ 1 ]
			for i = 1, #tab do
				ar:String( tab[ i ].szMap or "" )
				ar:Double( tab[ i ].nTime or 0 )
				ar:Double( tab[ i ].nPoints or 0 )
				ar:UInt( tab[ i ].nDate or 0, 32 )
				ar:Int( tab[ i ].nStyle or 1, 8 )
				ar:String( tab[ i ].vData or "" )
			end
		end
	elseif args.ID == "Top" then
		local tab = data[ 1 ]
		ar:UInt( data.ViewType, 4 )
		ar:UInt( data.Count or #tab, 16 )
		ar:Bit( not not data.IsEdit )
		
		if data.ViewType == 0 then
			for i = 1, #tab do
				ar:String( tab[ i ].szUID )
				ar:Double( tab[ i ].nSum )
			end
		elseif data.ViewType == 1 then
			ar:UInt( data.Style, 8 )
			
			for i = 1, #tab do
				ar:String( tab[ i ].szUID )
				ar:UInt( tab[ i ].nStyle, 8 )
				ar:UInt( tab[ i ].nWins, 16 )
				ar:UInt( tab[ i ].nStreak, 16 )
			end
		elseif data.ViewType == 2 then
			ar:UInt( data.Total, 16 )
			ar:UInt( data.Style, 8 )
			ar:UInt( data.ID, 8 )
			
			if data.Pos then
				ar:Bit( true )
				ar:UInt( data.Pos, 16 )
			else
				ar:Bit( false )
			end
			
			for i = 1, #tab do
				ar:String( tab[ i ].szUID )
				ar:Double( tab[ i ].nTime )
			end
		elseif data.ViewType == 3 then
			for i = 1, #tab do
				ar:String( tab[ i ].szUID )
				ar:String( tab[ i ].szAppend )
				ar:Double( tab[ i ].nTime )
			end
		elseif data.ViewType == 4 then
			ar:UInt( data.Style, 8 )
			
			for i = 1, #tab do
				ar:String( tab[ i ].szUID )
				ar:Double( tab[ i ].nTime )
				ar:Double( tab[ i ].nReal )
				ar:UInt( tab[ i ].nDate, 32 )
			end
		elseif data.ViewType == 5 then
			for i = 1, #tab do
				ar:String( tab[ i ].szText )
				ar:Double( tab[ i ].nTime )
			end
		elseif data.ViewType == 6 then
			for i = 1, #tab do
				ar:String( tab[ i ].szUID )
				ar:String( tab[ i ].szPrepend )
				ar:Double( tab[ i ].nTime )
			end
		elseif data.ViewType == 7 then
			for steam,count in pairs( tab ) do
				ar:String( steam )
				ar:UInt( count, 10 )
			end
		elseif data.ViewType == 8 then
			ar:UInt( data.Style, 8 )
			
			for i = 1, math.Clamp( #tab, 0, 50 ) do
				ar:String( tab[ i ].szUID )
				ar:Double( tab[ i ].nValue )
				ar:UInt( tab[ i ].nDate, 32 )
				ar:String( tab[ i ].vData )
			end
		end
	end
end

nets.Cache["GUI/Update"] = function( ar, args )
	local data = args.Data
	ar:String( args.ID )
	
	if args.ID == "Records" then
		ar:UInt( data[ 2 ], 16 )
		
		for id,v in pairs( data[ 1 ] ) do
			ar:UInt( id, 16 )
			ar:String( v.szUID or "" )
			ar:String( v.szPlayer or "" )
			ar:Double( v.nTime or 0 )
			ar:Double( v.nPoints or 0 )
			ar:UInt( v.nDate or 0, 32 )
			ar:String( v.vData or "" )
		end
		
		ar:UInt( 0, 16 )
	elseif args.ID == "Top" then
		ar:UInt( #data[ 1 ], 16 )
		ar:UInt( data[ 2 ], 16 )
		ar:UInt( data[ 3 ], 16 )
		ar:UInt( data[ 4 ], 16 )
		
		for i = 1, #data[ 1 ] do
			ar:String( data[ 1 ][ i ].szUID )
			ar:Double( data[ 1 ][ i ].nTime )
		end
	end
end

nets.Cache["Notify"] = function( ar, args )
	ar:String( args[ 1 ] )
	ar:String( args[ 2 ] )
	ar:String( args[ 3 ] )
	ar:UInt( args[ 4 ], 8 )
	ar:String( args[ 5 ] or "" )
end

nets.Cache["ColorText"] = function( ar, args )
	ar:UInt( #args, 8 )
	
	for i = 1, #args do
		if IsColor( args[ i ] ) then
			ar:Bit( true )
			ar:Color( args[ i ] )
		elseif type( args[ i ] ) == "string" then
			ar:Bit( false )
			ar:String( args[ i ] )
		end
	end
end

nets.Cache["RTV/VoteList"] = function( ar, args )
	for i = 1, 7 do
		ar:UInt( args[ i ], 8 )
	end
end

nets.Cache["Spectate/Timer"] = function( ar, args )
	ar:Bit( args[ 1 ] )
	
	if args[ 2 ] then
		ar:Bit( true )
		ar:Double( args[ 2 ] )
	else
		ar:Bit( false )
	end
	
	local i = args[ 1 ] and 4 or 3
	if args[ 1 ] then
		ar:String( args[ 3 ] or "" )
	end
	
	if args[ i ] then
		ar:Bit( true )
		ar:Double( args[ i ] )
	else
		ar:Bit( false )
	end
	
	local tab = args[ i + 1 ]
	if not tab then
		ar:UInt( 0, 4 )
	else
		if type( tab ) == "table" then
			ar:UInt( 2, 4 )
			ar:UInt( #tab, 8 )
			
			for i = 1, #tab do
				ar:String( tab[ i ] )
			end
		else
			ar:UInt( 1, 4 )
		end
	end
end