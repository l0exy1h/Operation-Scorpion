local md = {}

-- defs
local cam = workspace.CurrentCamera 
local rep = game.ReplicatedStorage

-- vars
local attcp = nil

function md.putParticlePart()
	attcp = Instance.new("Part", workspace)
	attcp.Name = "ParticlePart"
	attcp.Anchored = true
	attcp.Transparency = 1
	attcp.Size = Vector3.new(0,0,0)
	attcp.CanCollide = false
	attcp.CFrame = CFrame.new()
end

function md.onHit(h, p, d, mat)
	if h:IsDescendantOf(workspace.Alive) or h:IsDescendantOf(workspace.Ragdolls) then
		p = h.Position
		local rel = cam.CFrame:pointToObjectSpace(p)	
		if rel.z < 0 then
			if h.Name == "Head" then
				local pt = script.Particles.Headshot.Attachment:Clone()
				pt.Parent = attcp
				pt.Position = p
				pt.Axis = CFrame.new(p,p+d*100).lookVector
				local dist = (cam.CFrame.p - p).magnitude
				local v = (1 - (dist / 100)) * 1
				local bs = pt["Bam"..math.random(1,3)]
				bs.Volume=v
				bs:play()
			
				if rel.magnitude <= pt.ViewRange.Value then
					pt.Front2.Enabled = true
					pt.Back.Enabled = true
					pt.Impact.Enabled = true
				
					pt.Rocks.Enabled = true
					wait(0.1)
					
					pt.Front2.Enabled = false
					pt.Back.Enabled = false
					pt.Impact.Enabled = false
				
					pt.Rocks.Enabled = false
				end
				game.Debris:AddItem(pt,6)
			else
				local pt = script.Particles.Flesh.Attachment:Clone()
				pt.Parent = attcp
				pt.Position = p
				pt.Axis = CFrame.new(p,p+d*100).lookVector
				local dist = (cam.CFrame.p - p).magnitude
				local v = (1 - (dist / 100)) * 1
				local bs = pt["Bam"..math.random(1,3)]
				bs.Volume=v
				bs:play()
			
				if rel.magnitude <= pt.ViewRange.Value then
					pt.Front.Enabled = true
					pt.Front2.Enabled = true
					pt.Back.Enabled = true
					pt.Impact.Enabled = true
				
					pt.Rocks.Enabled = true
					wait(0.1)
					pt.Front.Enabled = false
					pt.Front2.Enabled = false
					pt.Back.Enabled = false
					pt.Impact.Enabled = false
				
					pt.Rocks.Enabled = false
				end
				game.Debris:AddItem(pt,6)		
			end
		end
	elseif mat == Enum.Material.Grass or mat == Enum.Material.Ground then

		local pt = script.Particles.Dirt.Attachment:Clone()
		pt.Parent = attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p - p).magnitude
		local v = (1 - (dist / 100)) * 1
		local bs = pt["Bam"]
		bs.Volume=v
		bs:play()
	
		pt.Artifact.Enabled = true
		pt.Artifact2.Enabled = true
		pt.Dust.Enabled = true
		pt.Dust2.Enabled = true
		pt.Impact.Enabled = true
		pt.Rocks.Enabled = true
		wait(0.2)
		pt.Rocks.Enabled = false
		pt.Artifact.Enabled = false
		pt.Dust.Enabled = false
		pt.Dust2.Enabled = false
		pt.Artifact2.Enabled = false
		pt.Impact.Enabled = false
		game.Debris:AddItem(pt,6)				
	
	elseif mat == Enum.Material.Snow then
		local pt = script.Particles.Snow.Attachment:Clone()
		pt.Parent = attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p - p).magnitude
		local v = (1 - (dist / 100)) * 3
		local bs = pt["Bam"]
		bs.Volume=v
		bs:play()
	
		pt.Artifact.Enabled = true
		pt.Artifact2.Enabled = true
		pt.Dust.Enabled = true
		pt.Dust2.Enabled = true
		pt.Impact.Enabled = true
		pt.Rocks.Enabled = true
		wait(0.2)
		pt.Rocks.Enabled = false
		pt.Artifact.Enabled = false
		pt.Dust.Enabled = false
		pt.Dust2.Enabled = false
		pt.Artifact2.Enabled = false
		pt.Impact.Enabled = false
		game.Debris:AddItem(pt,6)	
	
	elseif mat == Enum.Material.Sand then
		local pt = script.Particles.Sand.Attachment:Clone()
		pt.Parent = attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p - p).magnitude
		local v = (1 - (dist / 100)) * 2
		local bs = pt["Bam"]
		bs.Volume=v
		bs:play()
	
		pt.Artifact.Enabled = true
		pt.Artifact2.Enabled = true
		pt.Dust.Enabled = true
		pt.Dust2.Enabled = true
		pt.Impact.Enabled = true
		pt.Rocks.Enabled = true
		wait(0.2)
		pt.Rocks.Enabled = false
		pt.Artifact.Enabled = false
		pt.Dust.Enabled = false
		pt.Dust2.Enabled = false
		pt.Artifact2.Enabled = false
		pt.Impact.Enabled = false
		game.Debris:AddItem(pt,6)	
	
	elseif mat == Enum.Material.Water then
		local pt = script.Particles.Water.Attachment:Clone()
		pt.Parent = attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p - p).magnitude
		local v = (1 - (dist / 100)) * 3
		local bs = pt["Sound"..math.random(1, 2)]
		bs.Volume=v
		bs:play()
	
    pt.Dust.Enabled = true
		pt.Impact.Enabled = true
		pt.Water.Enabled = true
		wait(0.1)
		pt.Dust.Enabled = false
		pt.Impact.Enabled = false
		pt.Water.Enabled = false
		game.Debris:AddItem(pt,6)	
	
	elseif mat == Enum.Material.Wood then
		local pt = script.Particles.Wood.Attachment:Clone()
		pt.Parent = attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p - p).magnitude
		local v = (1 - (dist / 100)) * 2
		local bs = pt["Bam"]
		bs.Volume=v
		bs:play()
	
		pt.Artifact.Enabled = true
		pt.Dust.Enabled = true
		pt.Impact.Enabled = true
		wait(0.2)
		pt.Artifact.Enabled = false
		pt.Dust.Enabled = false
		pt.Impact.Enabled = false
		game.Debris:AddItem(pt,6)	
	
	elseif mat == Enum.Material.DiamondPlate or mat == Enum.Material.Metal then
		local pt = script.Particles.Metal.Attachment:Clone()
		pt.Parent = attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p - p).magnitude
		local v = (1 - (dist / 100)) * 1
		local bs = pt["Bam"]
		bs.Volume=v
		bs:play()
	
		pt.PointLight.Enabled = true
		pt.ParticleEmitter.Enabled = true
		pt.Smoke.Enabled = true
		wait(0.01)
		pt.PointLight.Enabled = false
		pt.ParticleEmitter.Enabled = false
		pt.Smoke.Enabled = false
		game.Debris:AddItem(pt,6)	
		
	elseif h.Name=="u_glass" then		-- unbreakable glass
		local rel = cam.CFrame:pointToObjectSpace(p)	
		local pt = script.Particles.UGlass.Attachment:Clone()
		pt.Parent=attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p-p).magnitude
		local v = (1 -(dist / 60)) * 1.5
		local bs = pt["Sound"..math.random(1, 2)]
		bs.Volume = v
		bs:play()
		pt.ParticleEmitter.Enabled = true
		pt.ShatterLarge.Enabled = true
		--pt.ShatterLarge2.Enabled = true
		pt.ShatterLargeLong.Enabled = true
		pt.ShatterSmall.Enabled = true
		wait(0.4)
		pt.ParticleEmitter.Enabled = false
		pt.ShatterLarge.Enabled = false
		--pt.ShatterLarge2.Enabled = false
		pt.ShatterLargeLong.Enabled = false
		pt.ShatterSmall.Enabled = false
		game.Debris:AddItem(pt,6)
	elseif h.Name == "glass" then		-- breakable glass
		local rel = cam.CFrame:pointToObjectSpace(p)	
		local pt = script.Particles.Glass.Attachment:Clone()
		pt.Parent=attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p-p).magnitude
		local v = (1 -(dist / 60)) * 2.5
		pt.Bam.Volume = v
		pt.Bam:play()
		
		pt.ShatterLarge.Enabled = true
		
		h.Parent = workspace.Map.glass.broken		
		wait(.2)
		h.CanCollide = false
		local savedTransparency = Instance.new("NumberValue", h)
		savedTransparency.Value = h.Transparency
		savedTransparency.Name = "SavedTransparency"
		h.Transparency = 1	
		
		wait(0.2)
		pt.ShatterLarge.Enabled = false
		
		--h.Parent = rep.MapRestore.BreakableGlasses

		
		game.Debris:AddItem(pt,6)
	elseif h.Name == "tv" or h.Name == "TV" then
		local rel = cam.CFrame:pointToObjectSpace(p)	
		local pt = script.Particles.TV.Attachment:Clone()
		pt.Parent=attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p-p).magnitude
		local v = (1 -(dist / 60)) * 1.5
		pt.Bam.Volume = v
		pt.Bam:play()
		
		pt.ParticleEmitter1.Enabled = true
		pt.ParticleEmitter2.Enabled = true
		pt.ParticleEmitter3.Enabled = true
		pt.ShatterLarge.Enabled = true
		pt.ShatterLargeLong.Enabled = true
		--pt.ShatterSmall.Enabled = true
		wait(0.3)
		pt.ParticleEmitter1.Enabled = false
		pt.ParticleEmitter2.Enabled = false
		pt.ParticleEmitter3.Enabled = false
		pt.ShatterLarge.Enabled = false
		pt.ShatterLargeLong.Enabled = false
		--pt.ShatterSmall.Enabled = false
		
		-- turn off the bloody TV
		h.SpotLight.Enabled = false
		for _, effect in ipairs(h.effect:GetChildren()) do
			if effect:IsA("Beam") then
				effect.Enabled = false
			end
		end
		h.Parent.Part:	
FindFirstChildOfClass("Sound"):Stop()
		
		game.Debris:AddItem(pt,1)
	elseif mat == Enum.Material.Neon or h.Name == "light" then
		local pt = script.Particles.Metal.Attachment:Clone()
		pt.Parent = attcp
		pt.Position = p
		pt.Axis = CFrame.new(p,p+d*100).lookVector
		local dist = (cam.CFrame.p - p).magnitude
		local v = (1 - (dist / 100)) * 2.5
		local bs = pt["Light"]
		bs.Volume=v
		bs:play()
	
		pt.PointLight.Enabled = true
		pt.ParticleEmitter.Enabled = true
		pt.Smoke.Enabled = true
		wait(0.01)
		pt.PointLight.Enabled = false
		pt.ParticleEmitter.Enabled = false
		pt.Smoke.Enabled = false
		game.Debris:AddItem(pt,6)	
		
		local l = h:FindFirstChildOfClass("SpotLight") or h:FindFirstChildOfClass("SurfaceLight") or h:FindFirstChildOfClass("PointLight")  
		l.Enabled = false
		h.Transparency = 1
	else
		local rel = cam.CFrame:pointToObjectSpace(p)	
		if rel.z < 0 then
			local pt = script.Particles.Default.Attachment:Clone()
			pt.Parent=attcp
			pt.Position = p
			pt.Axis = CFrame.new(p,p+d*100).lookVector
			local dist = (cam.CFrame.p - p).magnitude
			local v = (1 - (dist/35)) * 0.7
			pt.Bam.Volume=v
			pt.Bam:play()
			
			pt.Artifact.Enabled = true
			pt.Dust.Enabled = true
			pt.Impact.Enabled = true
			wait(0.1)
			pt.Artifact.Enabled = false
			pt.Dust.Enabled = false
			pt.Impact.Enabled = false
			
			game.Debris:AddItem(pt,6)
		end
	end
end

md.putParticlePart()
script.HitFX.Event:connect(md.onHit)

return md
