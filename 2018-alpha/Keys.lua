wait(1)
CharacterCode = game:GetService("ReplicatedStorage").CharacterCode
FE = CharacterCode.FE


script.Parent:WaitForChild("HumanoidRootPart")
cr = workspace.Alive:WaitForChild(game.Players.LocalPlayer.Name)
cr:WaitForChild("Stats")
--[[wait(1)
workspace.Alive:WaitForChild(game.Players.LocalPlayer.Name)]]

RS = game:GetService("RunService").RenderStepped
HB = game:GetService("RunService").Heartbeat
plr = game.Players.LocalPlayer
--[[plr.CameraMode = "Classic"]]
--plr.CameraMode = "LockFirstPerson"
workspace.CurrentCamera.FieldOfView = 85

gMove = Vector3.new()
cMove = Vector3.new()
mSpeed = 8

-- {ifPressed, lastUpdateTime}
keys = {}
keys["w"] = {false,0}
keys["a"] = {false,0}
keys["s"] = {false,0}
keys["d"] = {false,0}



m = plr:GetMouse()
run = false

-- for adv control
qp = false		-- q pressed
cp = false		-- c pressed


scrolled = true
recover = tick()		-- the last time when the running is updated
cspeed = 8
scroll = 0

-- added by y0rkl1u
local lp = game.Players.LocalPlayer
local lpVars = lp.PlayerScripts.Variables

Humanoid = script.Parent.Humanoid

Humanoid.FreeFalling:connect(function()
	script.Parent.Stats.Server.Jump.Value = 1
	FE.MainRemote:FireServer("SetLocalValue",{script.Parent.Stats.Server.Jump,1})
end)
Humanoid.Running:connect(function()
	script.Parent.Stats.Server.Jump.Value = 0
	FE.MainRemote:FireServer("SetLocalValue",{script.Parent.Stats.Server.Jump,0})
end)

Guns = {}
for i,v in ipairs(script.Parent.Stats.Gear:GetChildren()) do
	table.insert(Guns,v.Name)
end

Gun = Guns[1]

eqN = 1

mr = FE.MainRemote

gMove = Vector3.new()
cMove = Vector3.new()

--ctype = plr.PlayerGui.ControlType.CType

Mathf = require(script.Mathf)
function GetSpeed()
		walkspeed = (6 +(12-6)*scroll)*Mathf.Lerp(1,0.7,math.abs(script.Parent.Stats.Client.Lean.Value))*Mathf.Lerp(1,0.6,script.Parent.Stats.Client.Stance.Value)
		runspeed = 17*Mathf.Lerp(1,0.85,math.abs(script.Parent.Stats.Client.Lean.Value))*Mathf.Lerp(1,0.6,script.Parent.Stats.Client.Stance.Value)
		return Mathf.Lerp(walkspeed,runspeed,script.Parent.Stats.Client.Run.Value)
end
-- determine wot kind of breathing the local player is using
function SetBreath()
	recovering = tick()-recover < 8
	cbreath = recovering and "Recover" or "Normal"
	if script.Parent.Stats.Server.Aim.Value == 1 then
		cbreath = recovering and "Nervous" or "Calm"
	end
	if run then
		cbreath = script.Parent.Stats.Server.Aim.Value == 1 and "Shakey" or "Scared"
	end
	-- update
	script.Parent.Stats.Status.Scared.Value = cbreath
	FE.MainRemote:FireServer("SetLocalValue",{script.Parent.Stats.Status.Scared,cbreath})
end

function CycleGun(key)	-- modified by y0rkl1u: use 1, 2, 3 to change guns
	local goal = self.customization.gearName[key]
	if key == "1" 
		Gun = Guns[1]
	elseif key == "2" then
		Gun = Guns[2]
	else
		Gun = Guns[3]
	end
	-- need to expand the system:
	-- the local script should be able to load guns that only other players have.
	script.Parent.Stats.Status.GoalWeapon.Value = Gun
	FE.MainRemote:FireServer("SetLocalValue",{script.Parent.Stats.Status.GoalWeapon,Gun})
	maxshots = 0
end


-- handling keyboard inputs here
m.KeyDown:connect(function(key)
	-- movement
	if key == "w" or key == "a" or key == "s" or key == "d" then
		keys[key] = {true,tick()}
	end
	-- aim key
	-- a toggling option, so "z" doesn't require handling in the keyup setion
	if key == "z" then
		if script.Parent.Stats.Server.Aim.Value == 0 then
			script.Parent.Stats.Server.Aim.Value = 1
		else
			script.Parent.Stats.Server.Aim.Value = 0
		end
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Aim,script.Parent.Stats.Server.Aim.Value})
		SetBreath()	
	end
	-- left shift
	if key:byte()==48 then
		run = true
		--mSpeed = GetSpeed()
		script.Parent.Stats.Server.Run.Value = 1
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Run,script.Parent.Stats.Server.Run.Value})
		-- running disables leaning
		script.Parent.Stats.Server.Lean.Value = 0
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})

		recover = tick()
	end
	-- flashlight 
	if key == "f" then
		--script.Parent.Stats.Server.Flashlight.Value = not script.Parent.Stats.Server.Flashlight.Value
		mr:FireServer("SetValue",{script.Parent.Stats.Server.Flashlight,not script.Parent.Stats.Server.Flashlight.Value})
	end
	-- night vision
	if key == "n" then
		if lpVars.DisableCamera.Value == true then return end -- y0rkl1u
		--script.Parent.Stats.Server.NightVision.Value = not script.Parent.Stats.Server.NightVision.Value
		-- play the sound here?
		if script.Parent.Stats.Server.NightVision.Value == false then
			script.NightVision:Play()
		end
		mr:FireServer("SetValue",{script.Parent.Stats.Server.NightVision, not script.Parent.Stats.Server.NightVision.Value})
		--game.Players.LocalPlayer.PlayerScripts.Variables.NightVision.Value = not game.Players.LocalPlayer.PlayerScripts.Variables.NightVision.Value
	end
	if key == "r" then
		if script.Parent.Stats.Client.Reload.Value < 0.01 then	-- if reloading complete/no reloading
			-- reload start
			script.Parent.Stats.Server.Reload.Value = 1
			mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Reload,script.Parent.Stats.Server.Reload.Value})

			-- simulate the last bullet in the gun
			script.Parent.Stats.Resources[Gun.."_Mag"].Value = math.min(script.Parent.Stats.Resources[Gun.."_Mag"].Value,1)

			-- wait for reload to complete
			wait(script.Parent.Stats.ToolStats.Handling.ReloadTime.Value)

			-- reload complete
			script.Parent.Stats.Server.Reload.Value = 0
			mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Reload,script.Parent.Stats.Server.Reload.Value})

			-- add back bullet	
			script.Parent.Stats.Resources[Gun.."_Mag"].Value = script.Parent.Stats.Resources[Gun.."_Mag"].Value + script.Parent.Stats.ToolStats.Resources.MagSize.Value		
		end
	end
	if key == "gIsDisabledInPreAlpha" then
		if lpVars.DisableCamera.Value == true then return end -- y0rkl1u
		mr:FireServer("ThrowSmoke",{workspace.CurrentCamera.CFrame*CFrame.new(0,0,-4)})
	end
	if key == "yIsDisabledInPreAlpha" then
		game.Players.LocalPlayer.PlayerScripts.AudioEngine.SimpleSound.Value = not game.Players.LocalPlayer.PlayerScripts.AudioEngine.SimpleSound.Value
	end
	-- change gun
	if key == "1" or key == "2" or key == "3" then
		CycleGun(key)
	end
	if key == "q" and run == false then
		if script.SimpleControls.Value == false then
			qp = true	
			scrolled = false
			qpress = tick()
		else
			script.Parent.Stats.Server.Lean.Value = (script.Parent.Stats.Server.Lean.Value == 1 and 0 or 1)
			mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})				
		end
	end
	if key == "e" and run == false and script.SimpleControls.Value == true then
		script.Parent.Stats.Server.Lean.Value = (script.Parent.Stats.Server.Lean.Value == -1 and 0 or -1)
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})
	end
	if key == "c" then
		if script.SimpleControls.Value == false then
			cp = true
			qp = false
		else
			-- toggling here
			script.Parent.Stats.Server.Stance.Value = 1-math.floor(script.Parent.Stats.Server.Stance.Value)
			mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Stance,script.Parent.Stats.Server.Stance.Value})	
		end
	end
	--[[if key == "DISABLED_PRECISION" then
		if lpVars.DisableCamera.Value == true then return end -- y0rkl1u
		cp = false
		cq = false
		scrolled = false
		script.SimpleControls.Value = not script.SimpleControls.Value
		ctype.Text = "Controls: "..(script.SimpleControls.Value and "Simple" or "Precice")
		ctype.TextTransparency = -1
	end]]
	if key == "b" then
		if lpVars.DisableCamera.Value == true then return end -- y0rkl1u
		script.Parent.Stats.Server.FreeP.Value = 1
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.FreeP,script.Parent.Stats.Server.FreeP.Value})
	end
	if key == "mIsDisabled" then
		if lpVars.DisableCamera.Value == true then return end -- y0rkl1u
		mr:FireServer("SetValue",{script.Parent.Stats.Server.Health,0})
	end
	SetBreath()
	--[[if breaths[key] and script.Parent:FindFirstChild("Stats") then
		FE.MainRemote:FireServer("SetValue",{script.Parent.Stats.Status.Scared,breaths[key]})
	end]]
end)
m.KeyUp:connect(function(key)
	if key == "w" or key == "a" or key == "s" or key == "d" then
		keys[key] = {false,tick()}
	end
	if key:byte()==48 then
		run = false
		--script.Parent.Humanoid.WalkSpeed = GetSpeed()
		script.Parent.Stats.Server.Run.Value = 0
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Run,script.Parent.Stats.Server.Run.Value})
		recover = tick()
		wait(8.5)
		SetBreath()
	end
	if key == "b" then
		script.Parent.Stats.Server.FreeP.Value = 0
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.FreeP,script.Parent.Stats.Server.FreeP.Value})
	end
	if key == "qIsDisabled" then
		qp = false
		if script.SimpleControls.Value == true and script.Parent.Stats.Server.Lean.Value==1 then
			script.Parent.Stats.Server.Lean.Value = 0
			mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})	
		else
			-- q and e is toggling rn, so no need to make it 
			if scrolled == false then
				--script.Parent.Stats.Server.Lean.Value = 0
				--mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})	
			end
		end
	end
	if key=="e" then
		if script.SimpleControls.Value == true and script.Parent.Stats.Server.Lean.Value==-1 then
			--script.Parent.Stats.Server.Lean.Value = 0
			--mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})	
		end
	end
	if key == "c" then
		cp = false		
	end
	SetBreath()
end)

-- mouse wheel events
m.WheelForward:connect(function()
	if qp then
		scrolled = true
		script.Parent.Stats.Server.Lean.Value = Mathf.Clamp(script.Parent.Stats.Server.Lean.Value-0.2,-1,1)
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})
	elseif cp then
		script.Parent.Stats.Server.Stance.Value = Mathf.Clamp(script.Parent.Stats.Server.Stance.Value-0.2,0,1)
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Stance,script.Parent.Stats.Server.Stance.Value})		
	else
		-- it seems that only this branch will execute in the current OS now.
		-- the scroll value is only client side since there's no point uploading em and making use em in other clients
		scroll = scroll + 2/12
		scroll = scroll > 1 and 1 or scroll
		script.Parent.Stats.Client.Scroll.Value = scroll
	end
	--mSpeed = GetSpeed()
end)
m.WheelBackward:connect(function()
	if qp then
		scrolled = true
		script.Parent.Stats.Server.Lean.Value = Mathf.Clamp(script.Parent.Stats.Server.Lean.Value+0.2,-1,1)
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})
	elseif cp then
		script.Parent.Stats.Server.Stance.Value = Mathf.Clamp(script.Parent.Stats.Server.Stance.Value+0.2,0,1)
		mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Stance,script.Parent.Stats.Server.Stance.Value})		
	else
		scroll = scroll - 2/12
		scroll = scroll < 0 and 0 or scroll
		script.Parent.Stats.Client.Scroll.Value = scroll
	end
	mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Lean,script.Parent.Stats.Server.Lean.Value})
	--script.Parent.Humanoid.WalkSpeed = GetSpeed()
end)

-- RMB, update the aim value here
m.Button2Down:connect(function()
	script.Parent.Stats.Server.Aim.Value = 1
	mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Aim,script.Parent.Stats.Server.Aim.Value})
	SetBreath()
end)
m.Button2Up:connect(function()
	script.Parent.Stats.Server.Aim.Value = 0
	mr:FireServer("SetLocalValue",{script.Parent.Stats.Server.Aim,script.Parent.Stats.Server.Aim.Value})
	SetBreath()
end)

-- for shooting  (its continuous so there's a loop inside)
clickin = false
c = 0	-- ??
lastShot = 0
m.Button1Down:connect(function()
	clickin = true
	if lpVars.inFinal.Value == true then return end -- y0rkl1u: disable shooting in the final screen
	st = script.Parent.Stats
	t = st.ToolStats
	s = t.Shooting
	r = (s.RPM.Value/60)		-- rounds per sec here

	-- since r is the rounds per second
	-- r times a duration stands for the #rounds the gun can fire in that duration
	c = Mathf.Clamp((tick() - lastShot) * r, 0, 1)
	sv = script.Parent.Stats.Resources[Gun.."_Mag"]
	maxshots = sv.Value == 0 and 0 or (s.Automatic.Value == true and 99999 or 1)
	while clickin == true and maxshots > 0 and sv.Value > 0 do
		-- cannot shoot if covering or running
		-- Cover is 1 if your gun is blocked by a wall, and 0 otherwise.
		if script.Parent.Stats.Server.Cover.Value < 0.05 and script.Parent.Stats.Server.Run.Value < 0.05 then

			-- fire!
			if c >= 1 then
				c = c-1
				lastShot = tick()
				maxshots = maxshots - 1
				sv.Value = sv.Value - 1
				script.Parent.Stats.Client.Recoil.Shoot.Value = true
				mr:FireServer("SetLocalValue",{script.Parent.Stats.Client.Recoil.Shoot,true})
			end

			lu = tick()
			HB:wait()
			ut = tick()-lu
			-- update the #bullet
			c=Mathf.Clamp(c + ut*r, 0, sv.Value)
		else
			HB:wait()
		end
	end
end)
m.Button1Up:connect(function()
	clickin = false
end)

-- for movements
-- disable default movements
script.Parent.Humanoid.WalkSpeed = 0
-- we set the final velocity we want the character to reach based on key press
-- and we set the accleration here
-- LocalPlayer uses a bodymover for the x and z axis, and default humanoid behavior for the y axis.
bv = Instance.new("BodyVelocity",script.Parent.HumanoidRootPart)
bv.MaxForce = Vector3.new(100000,0,100000)
bv.Velocity = Vector3.new()

while true do
	wait(0.01)
	
	mSpeed = GetSpeed()
	
	-- the velocity
	gMove = Vector3.new()
	if keys["w"][1] == true then
		gMove = Vector3.new(0,0,-1)
		-- both pressed, s is pressed after, then go backward
		if keys["s"][1] == true  and keys["s"][2] > keys["w"][2] then
			gMove = Vector3.new(0,0,1)
		end
	elseif keys["s"][1] == true then
		gMove = Vector3.new(0,0,1)
	end
	
	if keys["a"][1] == true then
		gMove = gMove+Vector3.new(-1,0,0)
		if keys["d"][1] == true  and keys["d"][2] > keys["a"][2] then
			gMove = gMove+Vector3.new(2,0,0)
		end
	elseif keys["d"][1] == true then
		gMove = gMove+Vector3.new(1,0,0)
	end

	-- added by y0rkl1u: disable movements in final screen
	if lpVars.inRoundIntermission.Value == false and lpVars.inFinal.Value == false then
		bv.Velocity = CFrame.Angles(0,math.rad(script.Parent.Stats.Server.AngleY.Value),0)*(gMove.Magnitude < 0.01 and Vector3.new() or gMove.Unit*mSpeed)
	else
		bv.Velocity = Vector3.new()
	end
end