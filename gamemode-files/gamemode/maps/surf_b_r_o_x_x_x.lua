-- Broxxx removing rotating stuff

__HOOK[ "InitPostEntity" ] = function()
	for _,v in pairs( ents.FindByClass( "func_breakable" ) ) do
		if v:GetPos() == Vector( -3634.52, -1026, -990 ) then
			v:Remove()
		end
	end
	
	for _,v in pairs( ents.FindByClass( "func_rotating" ) ) do
		if v:GetPos() == Vector( -3634.69, -1024, -987.5 ) or v:GetPos() == Vector( -3634.6, -1024, -987.5 ) then
			v:Remove()
		end
	end
	
	for _,v in pairs( ents.FindByClass( "trigger_teleport" ) ) do
		if v:GetPos() == Vector( -3641.41, -1026, -990 ) then
			v:Remove()
		end
	end
end