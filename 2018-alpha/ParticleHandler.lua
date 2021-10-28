-- for the smoke effect on the part hit
-- not for the muzzle fire..

wait(3)
Particles = script.Particles

local Camera       =workspace.CurrentCamera
local attcp        = Instance.new("Part",workspace) -- the part for attaching the particle effects
attcp.Name         = "ParticlePart"
attcp.Anchored     = true
attcp.Transparency = 1
attcp.Size         = Vector3.new(0,0,0)
attcp.CanCollide   = false
attcp.CFrame       = CFrame.new()

game.ReplicatedStorage.HitFX.Event:connect(function(h,p,d)

	-- if the part hit is a character
	if h:IsDescendantOf(workspace.Characters) or h:IsDescendantOf(workspace.Ragdolls) then
		p = h.Position
		rel = Camera.CFrame:pointToObjectSpace(p)	-- for optimization: only render the effects in the front
		if rel.z < 0 then
			if h.Name == "Head" then
				local pt=Particles.Headshot.Attachment:Clone()
				pt.Parent=attcp
				pt.Position = p
				pt.Axis = CFrame.new(p,p+d*100).lookVector
				dist=(Camera.CFrame.p-p).magnitude
				v=(1-(dist/100))*1
				bs=pt["Bam"..math.random(1,3)]
				bs.Volume=v
				bs:play()
				for _,v in pairs(pt:GetChildren()) do
					if v:IsA('ParticleEmitter') then
						if rel.magnitude <= v.ViewRange.Value then
							v:Emit(v.Amt.Value)
						end
					end
				end
				game.Debris:AddItem(pt,3)
			else
				local pt=Particles.Flesh.Attachment:Clone()
				pt.Parent=attcp
				pt.Position = p
				pt.Axis = CFrame.new(p,p+d*100).lookVector
				dist=(Camera.CFrame.p-p).magnitude
				v=(1-(dist/60))*1
				bs=pt["Bam"..math.random(1,3)]
				bs.Volume=v
				bs:play()
				for _,v in pairs(pt:GetChildren()) do
					if v:IsA('ParticleEmitter') then
						if rel.magnitude <= v.ViewRange.Value then
							v:Emit(v.Amt.Value)
						end
					end
				end
				game.Debris:AddItem(pt,3)				
			end
		end

	-- if the part hit is not a character (probably some parts in map)
	else
		if h.Name=="glass" then
			rel = Camera.CFrame:pointToObjectSpace(p)	
			if rel.z < 0 then
				local pt=Particles.GlassSmall.Attachment:Clone()
				pt.Parent=attcp
				pt.Position = p
				pt.Axis = CFrame.new(p,p+d*100).lookVector
				dist=(Camera.CFrame.p-p).magnitude
				v=(1-(dist/60))*0.5
				pt.Bam.Volume=v
				pt.Bam:play()
				for _,v in pairs(pt:GetChildren()) do
					if v:IsA('ParticleEmitter') then
						if rel.magnitude <= v.ViewRange.Value then
							vc = v.Color.Keypoints[1].Value
							v.Color = ColorSequence.new(Color3.new(h.Color.r^vc.r,h.Color.g^vc.g,h.Color.b^vc.b))
							v:Emit(v.Amt.Value)
						end
					end
				end
				game.Debris:AddItem(pt,6)
			end		
		else
			rel = Camera.CFrame:pointToObjectSpace(p)	
			if rel.z < 0 then
				local pt=Particles.Default.Attachment:Clone()
				pt.Parent=attcp
				pt.Position = p
				pt.Axis = CFrame.new(p,p+d*100).lookVector
				dist=(Camera.CFrame.p-p).magnitude
				v=(1-(dist/35))*0.5
				pt.Bam.Volume=v
				pt.Bam:play()
				for _,v in pairs(pt:GetChildren()) do
					if v:IsA('ParticleEmitter') then
						if rel.magnitude <= v.ViewRange.Value then
							vc = v.Color.Keypoints[1].Value
							v.Color = ColorSequence.new(Color3.new(h.Color.r^vc.r,h.Color.g^vc.g,h.Color.b^vc.b))
							v:Emit(v.Amt.Value)
						end
					end
				end
				game.Debris:AddItem(pt,6)
			end
		end
	end
end)