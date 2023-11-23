local PlayerCenter = {}
PlayerCenter.Protocol = "PlayerCenter"
PlayerCenter.Cache = {}
PlayerCenter.Private = {}

--[[
	Description: Gets a stored value
--]]
function PlayerCenter:Get( nid, szKey, varDefault )
	-- Get the stored item
	local item = self.Cache[ nid ] and self.Cache[ nid ][ szKey ]
	
	-- ONLY if the item is a nil, return the default value
	if item != nil then
		return item
	end
	
	return varDefault
end

--[[
	Description: Gets a stored private value
--]]
function PlayerCenter:GetPrivate( nid, szKey, varDefault )
	-- Get the stored item
	local item = self.Private[ nid ] and self.Private[ nid ][ szKey ]
	
	-- ONLY if the item is a nil, return the default value
	if item != nil then
		return item
	end
	
	return varDefault
end

--[[
	Description: Sets a value in the cache
--]]
function PlayerCenter:Set( nid, szKey, varObj )
	-- Make sure we have a usable table
	if not self.Cache[ nid ] then
		self.Cache[ nid ] = {}
	end

	-- Update or create the entry
	self.Cache[ nid ][ szKey ] = varObj
end

function PlayerCenter:SetPrivate( nid, szKey, varObj )
	-- Make sure we have a usable table
	if not self.Private[ nid ] then
		self.Private[ nid ] = {}
	end

	-- Update or create the entry
	self.Private[ nid ][ szKey ] = varObj
end


--[[
	Description: Sends the initial data to the player
	Notes: Added local net variable for a lil' more speed, doesn't matter really
--]]
local net = net
function PlayerCenter.InitialSend( ply )
	net.Start( PlayerCenter.Protocol )
	net.WriteUInt( 0, 4 )
	net.WriteTable( PlayerCenter.Cache )
	net.Send( ply )
end

--[[
	Description: Respond to a pull request
--]]
function PlayerCenter.RespondPull( ply, nid )
	net.Start( PlayerCenter.Protocol )
	net.WriteUInt( 1, 4 )
	net.WriteBit( false )
	net.WriteUInt( nid, 16 )
	net.WriteTable( PlayerCenter.Cache[ nid ] or {} )
	net.Send( ply )
end

--[[
	Description: Respond to an update request
--]]
function PlayerCenter.RespondUpdate( plys )
	net.Start( PlayerCenter.Protocol )
	net.WriteUInt( 1, 4 )
	net.WriteBit( true )
	
	local ids, datas = {}, {}
	for i = 1, #plys do
		ids[ i ] = plys[ i ].NID
		datas[ i ] = PlayerCenter.Cache[ ids[ i ] ] or {}
	end
	
	net.WriteTable( ids )
	net.WriteTable( datas )
	net.Broadcast()
end

--[[
	Description: Publishes a single key OR everything to everyone
--]]
function PlayerCenter.PublishKey( nid, szKey )
	if szKey then
		net.Start( PlayerCenter.Protocol )
		net.WriteUInt( 2, 4 )
		net.WriteUInt( nid, 16 )
		net.WriteBit( false )
		net.WriteString( szKey )
		net.WriteType( PlayerCenter.Cache[ nid ][ szKey ] )
		net.Broadcast()
	else
		net.Start( PlayerCenter.Protocol )
		net.WriteUInt( 2, 4 )
		net.WriteUInt( nid, 16 )
		net.WriteBit( true )
		net.WriteTable( PlayerCenter.Cache[ nid ] or {} )
		net.Broadcast()
	end
end

--[[
	Description: Publishes a single key privately
--]]
function PlayerCenter.SendPrivate( ply, nid, szKey )
	net.Start( PlayerCenter.Protocol )
	net.WriteUInt( 2, 4 )
	net.WriteUInt( nid, 16 )
	net.WriteBit( false )
	net.WriteString( szKey )
	net.WriteType( PlayerCenter.Private[ nid ][ szKey ] )
	net.Send( ply )
end

function PlayerCenter.ClearUpdate( id )
	net.Start( PlayerCenter.Protocol )
	net.WriteUInt( 3, 4 )
	net.WriteUInt( id, 16 )
	net.Broadcast()
end



local ENTITY = FindMetaTable( "Entity" )
local PLAYER = FindMetaTable( "Player" )

--[[
	Description: Usable on players and entities to set objects
--]]
function ENTITY:SetObj( szKey, varObj, bPublish, bPrivate )
	local nid = self:EntIndex()
	if bPrivate then
		PlayerCenter:SetPrivate( nid, szKey, varObj )
		
		if IsValid( bPublish ) then
			PlayerCenter.SendPrivate( bPublish, nid, szKey )
		end
		
		bPublish = nil
	else
		PlayerCenter:Set( nid, szKey, varObj )
	end
	
	-- Publish a change right away if requested
	if bPublish then
		PlayerCenter.PublishKey( nid, szKey )
	end
end

--[[
	Description: Get the value from the entity
--]]
function ENTITY:GetObj( szKey, varDefault, bDummy, bPrivate )
	if bPrivate then
		return PlayerCenter:GetPrivate( self:EntIndex(), szKey, varDefault )
	else
		return PlayerCenter:Get( self:EntIndex(), szKey, varDefault )
	end
end

--[[
	Description: Publish an object's key (or everything)
--]]
function ENTITY:PublishObj( szKey )
	PlayerCenter.PublishKey( self:EntIndex(), szKey )
end

--[[
	Description: Function to send the initial data
	Used by: Player message in PostInitEntity
--]]
function PLAYER:InitialObj()
	PlayerCenter.InitialSend( self )
end

--[[
	Description: Reloads all given players
	Used by: Rank reloading
--]]
function Core.PublishPlayers( plys )
	PlayerCenter.RespondUpdate( plys )
end


--[[
	Description: Hook to clear out the data if we have a player that disconnected
--]]
local function OnEntityRemoved( ent )
	local id = ent:EntIndex()
	if PlayerCenter.Cache[ id ] then
		Core.CleanTable( PlayerCenter.Cache[ id ] )
		PlayerCenter.Cache[ id ] = nil
		PlayerCenter.ClearUpdate( id )
	end
end
hook.Add( "EntityRemoved", "PlayerCenterClear", OnEntityRemoved )

--[[
	Description: Read a pull request
--]]
local function ReceiveRequest( _, ply )
	PlayerCenter.RespondPull( ply, net.ReadUInt( 16 ) )
end
net.Receive( PlayerCenter.Protocol, ReceiveRequest )