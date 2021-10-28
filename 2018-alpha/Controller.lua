CharacterCode = game:GetService("ReplicatedStorage").CharacterCode
FE = CharacterCode.FE



-- for the local player

local module = {}
Character = nil
Body = nil
Camera = workspace.CurrentCamera
US = game:GetService("UserInputService")

Mathf = require(script.Parent.Mathf)

mr = FE.MainRemote

spectating = false

m = game.Players.LocalPlayer:GetMouse()
tp = false
lc = false
startTick = tick()
loaded = false
deathbody = nil
function sTick()
	return tick()-startTick
end
function GetSpeed()
	weightMult = Mathf.Lerp(1,0.7,(Character.Stats.Status.Weight.Value/25)^0.5)
	runspeed = 17*Mathf.Lerp(1,0.85,math.abs(Character.Stats.Client.Lean.Value))*Mathf.Lerp(1,0.6,Character.Stats.Client.Stance.Value)
	walkspeed = (6 +(12-6)*Character.Stats.Client.Scroll.Value)*Mathf.Lerp(1,0.7,math.abs(Character.Stats.Client.Lean.Value))*Mathf.Lerp(1,0.6,Character.Stats.Client.Stance.Value)
	return Mathf.Lerp(walkspeed,runspeed,Character.Stats.Client.Run.Value)*weightMult
end
local lp = game.Players.LocalPlayer
local lpVars = lp.PlayerScripts.Variables
function module.Unload()
	if loaded then
		ckd:disconnect()
		cch:disconnect()
		mm:disconnect()
		if lpVars.Spectating.Value then	-- added by y0rk1lu: handle the case where Controller overrides spectating
			script.Parent.SetHead:Fire(true, lpVars.Spectating.Value)
		end
		loaded = false
		print("Unloaded!")		
	end
end
function module.MoveMouse(inputObject)
	if Character and spectating == false then
		-- reduce cam movement when ADS
		deltaX, deltaY = -inputObject.Delta.y*0.3*Mathf.Lerp(1, 0.3, Character.Stats.Client.Aim.Value), -inputObject.Delta.x*0.2*Mathf.Lerp(1,0.3,Character.Stats.Client.Aim.Value)
	
		if Character.Stats.Server.FreeP.Value < 1 then
			-- freelook is disabled or in the process of being disabled
			Character.Stats.Server.AngleX.Value = Mathf.Clamp(Character.Stats.Server.AngleX.Value + deltaX, -85, 85)
			Character.Stats.Server.AngleY.Value = Character.Stats.Server.AngleY.Value + deltaY
			mr:FireServer("SetLocalValue",{Character.Stats.Server.AngleX,Character.Stats.Server.AngleX.Value})
			mr:FireServer("SetLocalValue",{Character.Stats.Server.AngleY,Character.Stats.Server.AngleY.Value})
			
			-- client deltax/y is for gunsways
			-- playeranimation will automatically transition them back to 0 over time
			ac = Mathf.Lerp(7,3,Character.Stats.Client.Aim.Value)
			Character.Stats.Client.DeltaX.Value = Mathf.Clamp(Character.Stats.Client.DeltaX.Value+deltaX*0.1, -ac, ac)
			Character.Stats.Client.DeltaY.Value = Mathf.Clamp(Character.Stats.Client.DeltaY.Value+deltaY*0.1, -ac, ac)
		else
			-- freelook
			gFreeX = Character.Stats.Server.FreeX.Value + deltaX
			gFreeY = Character.Stats.Server.FreeY.Value + deltaY
			ang = Vector2.new(gFreeX/45,gFreeY/90)
			if ang.Magnitude > 1 then
				ang = ang.unit
			end
			ang = ang*Vector2.new(45,90)
			Character.Stats.Server.FreeX.Value = Mathf.Clamp(ang.x+Character.Stats.Server.AngleX.Value,-85,85)-Character.Stats.Server.AngleX.Value--Mathf.Clamp(ang.x,-70,90)
			Character.Stats.Server.FreeY.Value = ang.y --Mathf.Clamp(ang.x,-70,90)
			mr:FireServer("SetLocalValue",{Character.Stats.Server.FreeX,Character.Stats.Server.FreeX.Value})
			mr:FireServer("SetLocalValue",{Character.Stats.Server.FreeY,Character.Stats.Server.FreeY.Value})			
		end
	end
		--totalGoalX,totalGoalY=totalGoalX+deltaX,totalGoalY+deltaY
end

-- load the cam on a char
function module.Load(char, bod, spectate)
	warn(char, bod, spectate)
	--if char == nil or bod == nil then return end -- added by y0rkl1u
	if loaded then
		module.Unload()
	end
	if spectate == false then  -- add head back and clear values
		if _G.stopSpectating then
			_G.stopSpectating()
		end
		
	end
	-- assign "instance variables"
	spectating = spectate
	plrg = game.Players.LocalPlayer.PlayerGui
	screenfx = plrg.Gameplay
	Character = char
	Body = bod
	Camera.CameraType = "Scriptable"
	deathbody = bod

	-- setup mouse behavior
	wait(0.25)
	US.MouseBehavior = Enum.MouseBehavior.LockCenter
	US.MouseIconEnabled = spectating

	-- remove head
	if workspace.Clothes:FindFirstChild(char.Name) then
		if workspace.Clothes[char.Name]:FindFirstChild("Head") then
			workspace.Clothes[char.Name].Head:Destroy()
		end
	end
	script.Parent.SetHead:Fire(tp or lc, char)

	loaded = true
	lastupdate = tick()
	lastupdate2 = tick()
	ckd = m.KeyDown:connect(function(key)
		-- modified by y0rkl1u, disabled for PreAlpha
		--[[if key == "z" then
			tp = not tp
		end
		if key == "x" then
			lc = not lc
		end
		if key == "z" or key == "x" then
			print("SetHead to "..(tostring(tp or lc)).." at "..(tick()))
			script.Parent.SetHead:Fire(tp or lc,char)
		end]]
	end)
	-- in first person i have a part that is always placed at your camera that holds audio makes it so sounds will stay centered on the camera from your own character
	cch = Camera.Changed:connect(function()
		if Body and Character then
			if not lc then
				chead = Character.Stats.Client.Character.Value.Head
				workspace.LocalSoundPart.CFrame = chead.CFrame
				--chead.Sounds.Position = (chead.CFrame):pointToObjectSpace(Camera.CFrame.p)		
			end
		end
	end)
	mm = US.InputChanged:connect(module.MoveMouse)
end


lu = tick()

-- for rs
ut = 1/60
lastupdate = tick()
-- for hb
ut2 = 1/60
lastupdate2 = tick()

lastAlive = tick()

-- for local-players
-- execute after each rendering frame (HB)
function module.HBUpdate()
	ut2 = tick()-lastupdate2
	lastupdate2 = tick()
	ok = loaded and Body and Character
	if ok then
		ok = ok and Character.Stats.Server.Health.Value > 0.01
	end
	if ok then
		--Character.Stats.Server.Velocity.Value = Character.HumanoidRootPart.Velocity*Vector3.new(1,0,1)

		-- keep the player from falling
		if spectating == false then		
			if Character.HumanoidRootPart.Position.y < - 100 then
				Character.HumanoidRootPart.CFrame = CFrame.new(0,100,0)
			end
		end

		--Character.Stats.Server.Velocity.Value = Character.HumanoidRootPart.Velocity*Vector3.new(1,0,1)
		--Character.Stats.Server.Position.Value = Character.HumanoidRootPart.Position

		-- uploading the position and velocity every 0.1s
		if spectating == false then		
			if tick() - lu >= 0.1 then
				lu = tick()
				mr:FireServer("SetLocalValue",{Character.Stats.Server.Velocity,Character.HumanoidRootPart.Velocity*Vector3.new(1,0,1)})
				mr:FireServer("SetLocalValue",{Character.Stats.Server.Position,Character.HumanoidRootPart.CFrame.p})
			end
		--Character.Humanoid.WalkSpeed = GetSpeed()
		end
		--Body.Head.Sounds.Position = (Body.Head.CFrame):pointToObjectSpace(Camera.CFrame.p)
		
		-- these values are just for the local player, so no need to include a server-side version

		-- decrease the goal dust overtime
		script.Parent.Parent.Variables.GoalDust.Value = Mathf.LerpTowards(script.Parent.Parent.Variables.GoalDust.Value,0,ut/10)
		-- keep lerping actual dust value toward the goal value
		script.Parent.Parent.Variables.Dust.Value = Mathf.Lerp(script.Parent.Parent.Variables.Dust.Value,script.Parent.Parent.Variables.GoalDust.Value,Mathf.Clamp(ut/0.08,0,1))
		-- screen dust effects
		lamt = script.Parent.Parent.Variables.Dust.Value*3
		screenfx.Lenses.Dirt1.ImageTransparency = Mathf.PercentBetween(3-lamt,2,3)
		screenfx.Lenses.Dirt2.ImageTransparency = Mathf.PercentBetween(3-lamt,1,2)
		screenfx.Lenses.Dirt3.ImageTransparency = Mathf.PercentBetween(3-lamt,0,1)
		screenfx.Lenses.Health.ImageTransparency = Mathf.Lerp(0.3,1,Character.Stats.Server.Health.Value/100)
		game.Lighting.DirtBlur.Size = Mathf.Lerp(game.Lighting.DirtBlur.Size,lamt/3*8,Mathf.Clamp(ut/0.1,0,1))
		game.Lighting.DirtBloom.Intensity = lamt/6
		game.Lighting.DirtBloom.Size = lamt/3*40
		game.Lighting.DirtBloom.Threshold = 0.9--*lamt/4

		-- night vision scanline effects
		screenfx.NV.ScanLine.Position = UDim2.new(0,0,0,(sTick()*45%2)*2)
		-- screen effects due to health
		game.Lighting.Fade.Saturation = Mathf.Lerp(-0.9,0,Character.Stats.Server.Health.Value/100)
		game.Lighting.Fade.Contrast = Mathf.Lerp(0.15,0,Character.Stats.Server.Health.Value/100)
		game.Lighting.Fade.Brightness = Mathf.Lerp(game.Lighting.Fade.Brightness,0,ut2/0.8)

		-- for spectating, if its on then turn it on
		script.Parent.Parent.Variables.NightVision.Value = Character.Stats.Server.NightVision.Value
		if script.Parent.Parent.Variables.NightVision.Value then
			-- client differing from server means that the client has not implemented dis change
			if Character.Stats.Client.NightVision.Value == false then
				game.Lighting.Fade.Brightness = 2
				Character.Stats.Client.NightVision.Value = true
			end
			game.Lighting.NV_Bloom.Enabled = true
			game.Lighting.NV_CC.Enabled = true
			screenfx.NV.Visible = true
		else
			if Character.Stats.Client.NightVision.Value == true then
				game.Lighting.Fade.Brightness = -0.4
				Character.Stats.Client.NightVision.Value = false
			end
			game.Lighting.NV_Bloom.Enabled = false
			game.Lighting.NV_CC.Enabled = false
			screenfx.NV.Visible = false
		end
		lastAlive = tick()
	else
		--[[if deathbody and deathbody.Parent then
			lalp = Mathf.Clamp((tick()-lastAlive)/0.2,0,1)
			game.Lighting.Fade.Saturation = Mathf.Lerp(-0.9,-0.6,lalp)
			game.Lighting.Fade.Contrast = Mathf.Lerp(0.15,0.3,lalp)
			game.Lighting.Fade.Brightness = (tick()-lastAlive > 3 and Mathf.Lerp(game.Lighting.Fade.Brightness,-1.9,ut/3) or 0)
		end]]
	end	
end
function module.Update()
	ut         = tick() - lastupdate
	lastupdate = tick()
	ok         = loaded and Body and Character
	if ok then
		ok = ok and Character.Stats.Server.Health.Value > 0.01
	end
	if ok then
		--Character.Stats.Server.Velocity.Value = Character.HumanoidRootPart.Velocity*Vector3.new(1,0,1)
		--Character.Stats.Server.Velocity.Value = Character.HumanoidRootPart.Velocity*Vector3.new(1,0,1)
		--Character.Stats.Server.Position.Value = Character.HumanoidRootPart.Position
		if not lc then
			script.Parent.Parent.Variables.NightVision.Value = Character.Stats.Server.NightVision.Value
			nv_V = script.Parent.Parent.Variables.NightVision.Value
			if Body.Head.NV_Point.Enabled ~= nv_V then
				Body.Head.NV_Point.Enabled = nv_V
				Body.Head.NV_Spot.Enabled = nv_V
			end

			-- basically, your camera is not always centered on your head. 
			--  when your gun is raised it's offset a bit by a stat inside each gun. 
			--  When you aim however, it moves your camera to line up with the gun sight, 
			--  but since your head tilts when you aim, it has to account for that, 
			--  and then your camera also bobs a bit when walking/running, and vibrates when shooting, so all those things have to be applied to it
			--  also your camera shifts when you crouch as well, thats why your gun is farther out when crouched
			xp = Character.Stats.Client.AngleX.Value/85
			gs = Character.Stats.ToolStats.ToolStance

			-- ok so i do a bit of a weird thing with smoothing where you A) have a linear interpolation, and B) have a proportional interpolation to that linear value and then C) smooth that final smoothened value
			-- this means it'll be smooth no matter what value it interpolates too, as well as if you change that value while it's transitioning
			-- server.run is an ultimate goal value, then client.run is a goal value for runsmooth, and then srun is runsmooth mapped to a cosine wave to make it smoother at values near 0 and 1
			-- stance, run, and aim all use the same process of smoothing
			-- and they're all between 0 and 1
			-- btw, stance will sometimes be greater than 1 [0 means stand, 1 means crouch]
			-- when you jump or land from falling, i adjust the stance value to create a sort of bounce/landing effect
			srun = Mathf.SmoothLerp(0,1,Character.Stats.Client.RunSmooth.Value)
			saim = Character.Stats.Client.SmoothAim.Value*(1-srun)*(1-Mathf.SmoothLerp(0,1,Character.Stats.Client.CoverSmooth.Value)*Character.Stats.Client.CoverSmooth.Value*0-Character.Stats.Client.CoverSmooth.Value)*(1-Mathf.SmoothLerp(0,1,Character.Stats.Client.Jump.Value))---Mathf.SmoothLerp(0,1,Character.Stats.Client.SmoothAim.Value)
			stance = Mathf.SmoothLerp(Character.Stats.Client.StanceSmooth.Value, 1, Character.Stats.Client.Jump.Value)
			
			coffset = gs.CamOffsetCrouch.Value:Lerp(gs.CamOffsetStand.Value,stance)
			
			-- As i said, shooting is one case thst triggers it
			-- However, pulling out/inserting the gun mag applies some vibration as well by using the recoil.vin value
			Client = Character.Stats.Client
			vibx = (math.random()-0.5)*(Client.Recoil.Vib.Value/0.005)^2*0.005+math.noise(sTick()/0.145)*0.026*(Client.Recoil.Vib.Value/0.005)^2
			viby = (math.random()-0.5)*(Client.Recoil.Vib.Value/0.005)^2*0.005+math.noise(sTick()/0.145+23.123)*0.026*(Client.Recoil.Vib.Value/0.005)^2
			vibz = (math.random()-0.5)*(Client.Recoil.Vib.Value/0.005)^2*0.005+math.noise(sTick()/0.145+73.7)*0.026*(Client.Recoil.Vib.Value/0.005)^2
				
			--Body.Head.Sounds.Position = (Body.Head.CFrame):pointToObjectSpace(Camera.CFrame.p)
			if script.Parent.Parent.Variables.DisableCamera.Value == false then
				Camera.CFrame = Body.Head.CFrame 
					* CFrame.new(Vector3.new(coffset.x*(1-srun)+math.abs(Character.Stats.Client.LeanSmooth.Value)^2.5*0.145,coffset.y-xp*0.02+0.5*srun,coffset.z-(coffset.z-gs.CamOffsetCrouch.Value.z)*Mathf.Lerp(0,0.5,saim)+xp*0.03)*Vector3.new(1-saim,1-saim,1-saim))
					* CFrame.Angles(0, 0, math.rad(saim * gs.TiltHead.Value))
					* (CFrame.new():lerp(Character.Stats.EquipmentData.gun_aimToSight.Value,saim))
					* CFrame.Angles(0, 0, -math.rad(Character.Stats.Client.LeanSmooth.Value*25) + Client.SmoothSideTilt.Value*0.8 - math.rad(saim*5) +Character.Stats.Client.FreeY.Value/90*math.rad(10))
					* CFrame.new(tp and Vector3.new(3, -0.1, 5) or Vector3.new())
					* CFrame.fromEulerAnglesYXZ(vibx*0.8, viby*0.8, vibz*0.8)
				Camera.FieldOfView = Mathf.SmoothLerp(85, 85/Character.Stats.ToolStats.Handling.AimFOVMult.Value, saim)	
				workspace.LocalSoundPart.CFrame = Camera.CFrame	
				--Body.Head.Sounds.Position = (Body.Head.CFrame):pointToObjectSpace(Camera.CFrame.p)
			else
				workspace.LocalSoundPart.CFrame = Body.Head.CFrame
				--Body.Head.Sounds.Position = Vector3.new()
			end
			local Weapon = Character.Stats.Status.Weapon.Value

			if Weapon then
				-- a surfacegui on a brick in the sight and all of that is math to make it point to where the bullet will go
				optic = Weapon:FindFirstChild("ProjectedOptic",true)
				if optic then
					opticPart = optic.Parent
					gp = opticPart.Position+Weapon.Barrel.CFrame.lookVector*Character.Stats.ToolStats.Handling.Zero.Value
					relAim = workspace.CurrentCamera.CFrame:pointToObjectSpace(gp)
					ang = CFrame.new(Vector3.new(),relAim)
					ncf = workspace.CurrentCamera.CFrame*ang
					nang = (opticPart.CFrame*CFrame.Angles(0,math.pi,0)):toObjectSpace(ncf)
					np = nang*Vector3.new(0,0,-nang.z/nang.lookVector.z)
					optic.Cutoff.Optic.Position = UDim2.new(np.x/(opticPart.Size.x),0,-np.y/(opticPart.Size.y),0)
					--optic.Optic.ImageTransparency = 1-Mathf.PercentBetween(sAim,0.925,0.935)
				end
			end
		else
			--Body.Head.Sounds.Position = Vector3.new()
		end
		lastAlive = tick()
	else
		-- auto unload when the obj becomes nil
		if loaded == true then
			module.Unload()
		end
		if deathbody then
			if not lc then
				-- death fall cam.
				if script.Parent.Parent.Variables.DisableCamera.Value == false and deathbody:FindFirstChild("Head") then
					Camera.CFrame = deathbody.Head.CFrame*CFrame.new(0,0,-0.5)
					workspace.LocalSoundPart.CFrame = Camera.CFrame	
				end
			end
		end
	end
end
return module
