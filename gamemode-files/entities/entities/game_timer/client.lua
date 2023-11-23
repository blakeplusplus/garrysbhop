local DrawArea = {
	[0] = Color( 0, 230, 0 ),
	[1] = Color( 180, 0, 0 ),
	[2] = Color( 127, 140, 141 ),
	[3] = Color( 52, 73, 118 ),
	[5] = Color( 0, 80, 255 )
}

local ViewZones = CreateClientConVar( "pg_showzones", "0", true, false )
local PaintPly, PaintColor, PaintDark, PaintPos, Iv, Ivb, PaintNames = LocalPlayer, Color( 255, 255, 255 ), Color( 25, 25, 25 ), TEXT_ALIGN_CENTER, IsValid, Core.IsValidBonus

if not Core.ZonePaint then
	Core.ZonePaint = {}
end

local Paintables = Core.ZonePaint
local function PaintZoneDetails()
	local ply = PaintPly()
	if not Iv( ply ) or not ply:Alive() then return end
	if not ViewZones:GetBool() and not Ivb( ply.Style ) then return end
	
	if not PaintNames and Core.EntNames then
		PaintNames = {}
		
		for n,i in pairs( Core.EntNames ) do
			PaintNames[ i ] = n
		end
	end
	
	local d, fe = {}, PaintNames or {}
	for i,ent in pairs( ents.FindInSphere( ply:GetPos(), 175 ) ) do
		if Iv( ent ) and Paintables[ ent:EntIndex() ] and ent.zonetype then
			if ent.zonetype >= 2 and ent.zonetype <= 3 then
				if Paintables.Active or Ivb( ply.Style ) then
					d[ #d + 1 ] = { Text = (fe[ ent.zonetype ] or "Unknown") .. " (ID: " .. (ent.embedded or "Main") .. ")", Dist = (ply:GetPos() - ent:GetPos()):Length2D(), Ent = ent }
				end
			elseif Paintables.Active and ent.Color then
				d[ #d + 1 ] = { Text = (fe[ ent.zonetype ] or "Unknown") .. (ent.embedded and " (Data ID: " .. ent.embedded .. ")" or ""), Dist = (ply:GetPos() - ent:GetPos()):Length2D(), Ent = ent }
			end
		end
	end
	
	table.SortByMember( d, "Dist", true )
	
	local x, y, c = ScrW() / 2, 20, #d
	if c == 0 then
		local pe = Paintables.High
		if IsValid( pe ) then
			pe.Color = pe.BaseColor and pe.BaseColor or table.Copy( PaintColor )
		end
		
		Paintables.High = nil
	end
	
	for i = 1, c do
		if i == 1 then
			local t = "Nearest: " .. d[ i ].Text .. " (" .. d[ i ].Ent:EntIndex() .. ")"
			draw.SimpleText( t, "FullscreenHeader", x, y + 2, PaintDark, PaintPos )
			draw.SimpleText( t, "FullscreenHeader", x, y, PaintColor, PaintPos )
			y = y + 24
			
			if Paintables.High != d[ i ].Ent then
				local pe = Paintables.High
				if IsValid( pe ) then
					pe.Color = pe.BaseColor and pe.BaseColor or table.Copy( PaintColor )
				end
				
				Paintables.High = d[ i ].Ent
			end
		else
			local t = d[ i ].Text .. " (" .. math.floor( d[ i ].Dist ) .. "u)"
			draw.SimpleText( t, "FullscreenSubtitle", x, y + 2, PaintDark, PaintPos )
			draw.SimpleText( t, "FullscreenSubtitle", x, y, PaintColor, PaintPos )
			y = y + 20
		end
	end
end

if not Core.ZonePainting then
	Core.ZonePainting = true
	hook.Add( "HUDPaint", "ZoneTooltipPaint", PaintZoneDetails )
end

function ENT:Initialize()
end

function ENT:Think()
	local Min, Max = self:GetCollisionBounds()
	self:SetRenderBounds( Min, Max )
	
	local data = ((Core and Core.ClientEnts) or {})[ self:EntIndex() ]
	if not self.Created then
		if not data then return end
		
		self.zonetype = data[ 1 ]
		self.embedded = data[ 2 ]

		local Min, Max = self:GetCollisionBounds()
		Min = self:GetPos() + Min
		Max = self:GetPos() + Max
		
		self.Created = true
		self.Bottom = { Vector( Min.x, Min.y, Min.z ), Vector( Min.x, Max.y, Min.z ), Vector( Max.x, Max.y, Min.z ), Vector( Max.x, Min.y, Min.z ) }
		self.Top = { Vector( Min.x, Min.y, Max.z ), Vector( Min.x, Max.y, Max.z ), Vector( Max.x, Max.y, Max.z ), Vector( Max.x, Min.y, Max.z ) }
		self.Color = DrawArea[ self.zonetype ]
		self.BaseColor = self.Color
		self.DrawBox = DrawCustomZone
		
		if not self.BaseColor and Paintables.Active then
			data[ 3 ] = { Paintables.Active }
		end
		
		Paintables[ self:EntIndex() ] = self
	else
		if data[ 3 ] then
			self.Color = self.BaseColor and self.BaseColor or (data[ 3 ][ 1 ] and table.Copy( PaintColor ))
			data[ 3 ] = nil
		elseif Paintables.Active and Paintables.High == self and not self.BaseColor and self.Color then
			if not self.Up and self.Color.r > 0 then
				self.Color.r = self.Color.r - 1
			elseif not self.Up and self.Color.r <= 0 then
				self.Up = true
			elseif self.Up and self.Color.r < 255 then
				self.Color.r = self.Color.r + 1
			elseif self.Up and self.Color.r >= 255 then
				self.Up = false
			end
		elseif not Paintables.Active and self.BaseColor then
			if self.BaseColor != self.Color then
				self.Color = self.BaseColor
			end
			
			if ViewZones:GetInt() == -1 then
				self.Color = nil
			end
		end
		
		if not self.Color then return end
		if self.Down and self.Color.a > 80 then
			self.Color.a = self.Color.a - 0.15
		elseif self.Down and self.Color.a <= 80 then
			self.Down = false
		elseif not self.Down and self.Color.a < 255 then
			self.Color.a = self.Color.a + 0.3
		elseif not self.Down and self.Color.a >= 255 then
			self.Down = true
		end
	end
end

function ENT:Draw()
	if self.DrawBox then
		self:DrawBox()
	end
end