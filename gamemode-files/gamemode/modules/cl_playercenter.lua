local PlayerCenter = {}
PlayerCenter.Protocol = "PlayerCenter"
PlayerCenter.Received = 0

PlayerCenter.Cache = {}
PlayerCenter.Pulling = {}

local pairs, type = pairs, type
function PlayerCenter:Import( nid, data, wipe )
	if type( nid ) == "table" then
		for i = 1, #nid do
			self:Import( nid[ i ], data[ i ] )
		end
	else
		if not self.Cache[ nid ] then
			self.Cache[ nid ] = {}
		end
		
		if wipe then
			Core.CleanTable( self.Cache[ nid ] )
		end
		
		for key,value in pairs( data ) do
			self.Cache[ nid ][ key ] = value
		end
	end
end

function PlayerCenter:ImportSingle( nid, key, data )
	if not self.Cache[ nid ] then
		self.Cache[ nid ] = {}
	end
	
	self.Cache[ nid ][ key ] = data
end

function PlayerCenter:Clear( nid )
	Core.CleanTable( self.Cache[ nid ] )
	self.Cache[ nid ] = nil
end

local net = net
function PlayerCenter:Pull( nid )
	if self.Pulling[ nid ] then return end
	
	self.Pulling[ nid ] = true
	
	net.Start( self.Protocol )
	net.WriteUInt( nid, 16 )
	net.SendToServer()
end

function PlayerCenter:Get( nid, szKey, varDefault )
	if not self.Authorized then return varDefault end
	if self.Cache[ nid ] then
		local item = self.Cache[ nid ][ szKey ]
		if item != nil then
			return item
		end
	else
		self:Pull( nid )
	end
	
	return varDefault
end

local ENTITY = FindMetaTable( "Entity" )
function ENTITY:GetObj( szKey, varDefault, bPull )
	local out = PlayerCenter:Get( self:EntIndex(), szKey, varDefault )
	if out == varDefault and bPull then
		PlayerCenter:Pull( self:EntIndex() )
	end
	
	return out
end

local function ReceiveType( l )
	PlayerCenter.Received = PlayerCenter.Received + l
	
	local id = net.ReadUInt( 4 )
	if not PlayerCenter.Authorized and id != 0 then return end
	
	if id == 0 then
		PlayerCenter.Cache = net.ReadTable() or {}
		PlayerCenter.Authorized = true
	elseif id == 1 then
		local multi = net.ReadBit() == 1
		local nid = not multi and net.ReadUInt( 16 )
		
		if not multi then PlayerCenter.Pulling[ nid ] = nil end
		PlayerCenter:Import( multi and net.ReadTable() or nid, net.ReadTable() )
	elseif id == 2 then
		local nid, full = net.ReadUInt( 16 ), net.ReadBit() == 1
		
		if full then
			PlayerCenter:Import( nid, net.ReadTable(), true )
		else
			PlayerCenter:ImportSingle( nid, net.ReadString(), net.ReadType( net.ReadUInt( 8 ) ) )
		end
	elseif id == 3 then
		PlayerCenter:Clear( net.ReadUInt( 16 ) )
	end
end
net.Receive( PlayerCenter.Protocol, ReceiveType )

function Core.GetSessionBytes()
	return PlayerCenter.Received
end

function Core.GetNetVars( set )
	if set and engine.IsPlayingDemo() then
		PlayerCenter.Cache = set
		PlayerCenter.Authorized = true
	else
		return PlayerCenter.Cache
	end
end