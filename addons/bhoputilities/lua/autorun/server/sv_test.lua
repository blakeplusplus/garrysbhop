


hook.Add("KeyPress", "EntRemoverKeyPress",function(pl,key)
	if (key == IN_ATTACK) then
	--	EntTestTrace(pl)
	end

end)

function EntTestTrace(pl)
	local tr = util.TraceLine({start = pl:EyePos(),
	endpos = pl:EyePos() + pl:EyeAngles():Forward() * 1000,
	filter = pl,
	mask = MASK_ALL,
	collisiongroup = COLLISION_GROUP_DEBRIS_TRIGGER,
	})
	
	--PrintTable(tr)
	
end

