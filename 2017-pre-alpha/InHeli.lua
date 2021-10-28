local md = {}

-- defs
local rep           = game:GetService("ReplicatedStorage")
local uis           = game:GetService("UserInputService")
local lp            = game.Players.LocalPlayer
local lpVars        = lp:WaitForChild("PlayerScripts"):WaitForChild("Variables")
local heli          = workspace:WaitForChild("Helicopter") 
local mouse         = lp:GetMouse()
local camPart       = heli:WaitForChild("CameraPart")
local cam           = workspace.CurrentCamera
local gm            = rep:WaitForChild("GlobalModules")
local mathf         = require(gm:WaitForChild("Mathf"))
local screenCamFx   = require(gm:WaitForChild("ScreenCamFx"))
local ga            = require(gm:WaitForChild("GeneralAnimation"))
local RS            = game:GetService("RunService").RenderStepped
local HB            = game:GetService("RunService").Heartbeat
local disableFPScam = lpVars:WaitForChild("DisableFpsCam") 
local Lighting      = game:GetService("Lighting")
local fade          = Lighting:WaitForChild("HeliFade")
local fpsGui        = lp:WaitForChild("PlayerGui"):WaitForChild("Gameplay"):WaitForChild("FPS")
local plrs          = game.Players
local rightScreen   = heli:WaitForChild("ScreenMidR"):WaitForChild("SurfaceGui")
local leftScreen    = heli:WaitForChild("ScreenMidL"):WaitForChild("SurfaceGui")
local sd            = require(gm:WaitForChild("ShadedTexts"))

-- vars
local gCamInt = 0
local camInt = 0

-- consts
local inStudio = game.CreatorId == 0
local timerYellow = Color3.fromRGB(254, 168, 20)
local timerOrange = Color3.fromRGB(253, 104, 59)

function md.isThereHeli()
	return workspace:FindFirstChild("Helicopter")      ~= nil 
		 and workspace.Helicopter:FindFirstChild("Heli") ~= nil
end

function md.setHeliSFX()
	if rep:WaitForChild("Debug"):WaitForChild("DirectSpawn").Value == false then
		script.Audio.Helicopter.Volume = 0
		script.Audio.Helicopter.EqualizerSoundEffect.HighGain = -20
		script.Audio.Helicopter.EqualizerSoundEffect.MidGain  = -15
		script.Audio.Helicopter:Play()
		coroutine.resume(coroutine.create(function()
			for i = 0,0.5,0.025 do
				wait(0.05)
				script.Audio.Helicopter.Volume = i
			end
		end))
	end
end

function md.setHomeCam()
	disableFPScam.Value = true
	cam.FieldOfView = 70
	coroutine.resume(coroutine.create(function()
		local tTick = tick()
		while lpVars.atHome.Value == true do
			local lu = tick()
			RS:wait()
			local ut = tick()-lu
			local uTick = tick()-tTick
			local MX = ((mouse.X/mouse.ViewSizeX)-0.5)*2 
			local MY = ((mouse.Y/mouse.ViewSizeY)-0.5)*2
			camInt = mathf.lerpTowards(camInt,gCamInt,ut/2)
			if lpVars.atHome.Value == true then
				cam.CFrame = (heli.CameraPart.CFrame*CFrame.new((1-MX)*-0.6,0,(MY)*-0.8)):lerp(
						heli.DoorOpen.CFrame,mathf.smoothLerp(0,1,camInt)
					)*CFrame.new(
						(math.random()-0.5)*0.005,
						(math.random()-0.5)*0.005,
						(math.random()-0.5)*0.005
					)*CFrame.fromEulerAnglesYXZ(
						math.noise(uTick/5)*math.rad(3)-MY*math.rad(20)-math.rad(10),
						math.noise(uTick/5+7.76352)*math.rad(3)-MX*math.rad(10),
						math.noise(uTick/5+1.23252)*math.rad(1)
					)
				end
		end
	end))		
end

-- 12.66s
function md.transitionToFps()
	wait(1)
	
	if rep:WaitForChild("Debug"):WaitForChild("DirectSpawn").Value == false then
		-- DISABLED FOR DEV
		script.Audio.Warning:Play()
		wait(0.5)
		local sTick = tick()
		gCamInt = 1
		wait(2)
		wait(0.8)
		sTick = tick()
		script.Audio.MetalSlam:Play()
		
		while (tick()-sTick < 0.5) do
			HB:wait()
			local stp = (tick()-sTick)/0.5
			stp = stp > 1 and 1 or stp
			heli.Heli.slide:SetPrimaryPartCFrame(heli.SlideClosed.CFrame:lerp(
				heli.SlideBack.CFrame,mathf.smoothLerp(0,1,stp)))
			script.Audio.Helicopter.EqualizerSoundEffect.HighGain = -10*(1-stp^0.5)-10
			script.Audio.Helicopter.EqualizerSoundEffect.MidGain =  -10*(1-stp^0.5)-5
		end
		
		wait(0.3)
		script.Audio.HeavyDoor:Play()
		wait(0.1)
		fade.Brightness = 0
		fade.Contrast = 0
		fade.Saturation = 0
		--fade.Enabled = true
		
		sTick = tick()
		while (tick()-sTick < 5) do
			HB:wait()
			local stp = (tick()-sTick)/5
			stp = stp > 1 and 1 or stp
			heli.Heli.slide:SetPrimaryPartCFrame(heli.SlideBack.CFrame:lerp(
				heli.SlideOpen.CFrame,mathf.smoothLerp(0,1,stp)))
			fade.Brightness = stp*3
			script.Audio.Helicopter.Volume = 1+0.5*stp
			script.Audio.Helicopter.EqualizerSoundEffect.HighGain = -10*(1-stp^0.5)
			script.Audio.Helicopter.EqualizerSoundEffect.MidGain  =  -5*(1-stp^0.5)
		end
		lpVars.atHome.Value = false
		for i = 0,1,0.025 do
			wait(0.05)
			script.Audio.Helicopter.Volume = (1-i)*1.5
		end
		
		script.Audio.Helicopter:Stop()	
	--heli.Heli.slide:SetPrimaryPartCFrame(heli.SlideClosed.CFrame)
	end
end

function md.setDefaultMouseBehavior()
	uis.MouseIconEnabled = true
	uis.MouseBehavior    = Enum.MouseBehavior.Default
end

function md.setUpHomeGui()
	local function addToTeamList(plr)
		warn(plr.Team)
		local teamList = rightScreen[plr.Team.Name].List
		if teamList:FindFirstChild(plr.Name) then 
			return
		end
		local New = script.PlrListFrame:Clone()
		New.Parent = teamList
		New.Name = plr.Name
		sd.setProperty(New.lvl, "Text", tostring(plr:WaitForChild("Stats").Level.Value))
		sd.setProperty(New.name, "Text", plr.Name)
		New.Size = UDim2.new(1, 0, 0.12, 0)	
		New.FullCover.ImageColor3 = plr.Team.TeamColor.Color
		New.FullCover.ImageTransparency = 0.7	
	end
	local function removeFromTeamList(plr)
		if md.isThereHeli() then
			local teamList = rightScreen[plr.Team.Name].List
			if teamList:FindFirstChild(plr.Name) then
				teamList[plr.Name]:Destroy()
			end
		end
	end
	-- add exisiting plrs to the list
	for _, plr in ipairs(plrs:GetChildren()) do
		if plr.Team then
			addToTeamList(plr)
		end
	end
	game.Teams.Alpha.PlayerAdded:connect(function(plr)
		addToTeamList(plr)
	end)
	game.Teams.Beta.PlayerAdded:connect(function(plr)
		addToTeamList(plr)
	end)
	game.Teams.Alpha.PlayerRemoved:connect(function(plr)
		removeFromTeamList(plr)
	end)
	game.Teams.Beta.PlayerRemoved:connect(function(plr)
		removeFromTeamList(plr)
	end)
	rep.SharedVars.HeliCounter.Changed:connect(function()
		leftScreen.Timer.sec.Text = tostring(rep.SharedVars.HeliCounter.Value)

		for i = 0, 6-1, 1 do
			local fan_i = leftScreen.Timer.Fans:FindFirstChild(tostring(i))
			fan_i.ImageColor3 = timerYellow
			spawn(function()
				ga.animateColor3(fan_i, "ImageColor3", timerOrange, 4/6)
			end)
			wait(1/6)
		end
	end)
end

function md.destroy()
	workspace.Helicopter:ClearAllChildren()
end

-- main
md.setUpHomeGui()
screenCamFx.setLighting("Heli")
screenCamFx.setCameraFx("Heli")
md.setDefaultMouseBehavior()
md.setHeliSFX()
md.setHomeCam()
local function transitionToFpsQ(stage)
	return stage == "Wait End" or string.sub(stage, 1, 5) == "Match" 
end
local fpsLoaded = false
local function loadFps()
	if not fpsLoaded then
		if transitionToFpsQ(rep.Stage.Value) then
			fpsLoaded = true
			md.transitionToFps()
			require(script.Parent.MatchStart)
		end
	end 
end
loadFps()
rep.Stage.Changed:connect(loadFps)

return md
