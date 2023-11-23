-- Set custom respawning

local PLAYER = FindMetaTable( "Player" )

PLAYER.BaseResetSpawnPosition = PLAYER.ResetSpawnPosition
function PLAYER:ResetSpawnPosition( tabCheck, bReset, bLeave )
	if self:BaseResetSpawnPosition( tabCheck, bReset, bLeave ) then
		self:SetName( "one" )
		self:SetKeyValue( "classname", "" )
	end
end