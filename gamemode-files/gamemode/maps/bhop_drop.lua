-- Set custom respawning

local PLAYER = FindMetaTable( "Player" )
local StagePosition = Vector( -11328, 13448, -188 )
local StageAngle = Angle( 0, 270, 0 )

PLAYER.BaseResetSpawnPosition = PLAYER.ResetSpawnPosition
function PLAYER:ResetSpawnPosition( tabCheck, bReset, bLeave )
	if self:BaseResetSpawnPosition( tabCheck, bReset, bLeave ) then
		local bonus = Core.IsValidBonus( self.Style )
		if not bonus then
			self:SetPos( StagePosition )
			self:SetEyeAngles( StageAngle )
		end
	end
end