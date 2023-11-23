-- Crouch parts removal

local rem = Vector( 4312, 3600, -3780 )
__HOOK[ "InitPostEntity" ] = function()

	for k,v in pairs( ents.FindByClass( "trigger_teleport" ) ) do
		if v:GetPos() == rem then
			v:Remove()
		end
	end
end