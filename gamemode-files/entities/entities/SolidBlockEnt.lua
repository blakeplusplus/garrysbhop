ENT.Type = "anim"
ENT.Base = "base_anim"

if SERVER then
	AddCSLuaFile()
	
	function ENT:Initialize()    
		self:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
		
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_VPHYSICS )

		self:PhysicsInitBox( self.min, self.max )
		self:SetCollisionBounds( self.min, self.max )

		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then
			phys:EnableMotion( false )
		end
	end

	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then
			phys:EnableMotion( false )
		end 
	end
else
	local ViewZones, Time, DrawZone = CreateClientConVar( "pg_showzones", "0", true, false ), SysTime
	function ENT:Draw()
	end
	
	function ENT:Think()
		if not self.LastCheck or Time() - self.LastCheck > 0.1 then
			local b = ViewZones:GetBool()
			local up = b and not self.IsDrawing
			
			self.IsDrawing = b
			self.LastCheck = Time()
			
			if up then
				local Min, Max = self:GetCollisionBounds()
				Min = self:GetPos() + Min
				Max = self:GetPos() + Max
				
				self.Created = true
				self.Color = Color( 255, 0, 127 )
				self.Bottom = { Vector( Min.x, Min.y, Min.z ), Vector( Min.x, Max.y, Min.z ), Vector( Max.x, Max.y, Min.z ), Vector( Max.x, Min.y, Min.z ) }
				self.Top = { Vector( Min.x, Min.y, Max.z ), Vector( Min.x, Max.y, Max.z ), Vector( Max.x, Max.y, Max.z ), Vector( Max.x, Min.y, Max.z ) }
				self.DrawBox = DrawCustomZone
				
				DrawZone = self
				
				if Core.ZonePaint and Core.ZonePaint.Active then
					self.zonetype = 12
					Core.ZonePaint[ self:EntIndex() ] = self
				end
				
				hook.Add( "PostDrawTranslucentRenderables", "PreviewSolids", function()
					if DrawZone and DrawZone.DrawBox then
						DrawZone:DrawBox()
					else
						hook.Remove( "PostDrawTranslucentRenderables", "PreviewSolids" )
					end
				end )
			elseif not b and DrawZone then
				DrawZone = nil
			end
		end
	end
end