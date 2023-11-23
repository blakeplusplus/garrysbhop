-- Remove jail teleports teleport

__HOOK[ "InitPostEntity" ] = function()
	for k,v in pairs( ents.FindByClass( "trigger_teleport" ) ) do
		if v:GetName() == "start_zusammen" then
			v:Remove()
		end
	end
	
	for k,v in pairs( ents.FindByClass( "trigger_multiple" ) ) do
		if v:GetName() == "ban" then
			v:Remove()
		end
	end
	
	for k,v in pairs( ents.FindByClass( "func_button" ) ) do
		v:Remove()
	end
end