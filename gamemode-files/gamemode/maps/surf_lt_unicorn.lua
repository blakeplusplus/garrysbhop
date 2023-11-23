-- Set custom respawning

local PLAYER = FindMetaTable( "Player" )
local StagePosition = Vector( 14688, -13808, 15988 )
local BonusPosition = Vector( 14864, -13808, 15988 )

PLAYER.BaseResetSpawnPosition = PLAYER.ResetSpawnPosition
function PLAYER:ResetSpawnPosition( tabCheck, bReset, bLeave )
	if self:BaseResetSpawnPosition( tabCheck, bReset, bLeave ) then
		local bonus = Core.IsValidBonus( self.Style )
		if not bonus then
			self:SetPos( StagePosition )
		elseif bonus and self.Style == Core.Config.Style.Bonus then
			self:SetPos( BonusPosition )
		end
	end
end