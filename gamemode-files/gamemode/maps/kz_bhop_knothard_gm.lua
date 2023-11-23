__HOOK[ "InitPostEntity" ] = function()
	local _, Type = debug.getupvalue(player_manager.RegisterClass, 1)
	Type.player_bhop.WalkSpeed = 260
end