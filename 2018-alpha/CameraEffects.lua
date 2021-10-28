local md = {}

-- defs
local uis = game:GetService("UserInputService")
local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
	local mathMd = require(gm:WaitForChild("Mathf"))
		local lerp = mathMd.lerp
		local clamp = mathMd.clamp
		local lerpTowards = mathMd.lerpTowards
		local smoothLerp = mathMd.smoothLerp
		local percentBetween = mathMd.percentBetween
-- local apple = require(gm:WaitForChild("Apple"))
-- 	local fireServer = apple.fireServer
local plrs = game.Players
	local lp = plrs.LocalPlayer
		local lpScripts = lp:WaitForChild("PlayerScripts")
			local lpVars = lpScripts:WaitForChild("Variables")
		local lpGui = lp:WaitForChild("PlayerGui")
			local screenfx = lpGui:WaitForChild("ScreenGui"):WaitForChild("Gameplay")
local random = math.random
local rad = math.rad
local noise = math.noise
local lighting = game.Lighting
local rs = game:GetService("RunService").RenderStepped
local hb = game:GetService("RunService").Heartbeat

local cam = workspace.CurrentCamera

local stt = tick()
local function stick()
	return tick() - stt
end

-- vars
local self = nil
local lastUpdate  = tick()
local lastUpdate2 = tick()
local connections = {}

function md.rsUpdate()
	if not (self and self.isWatched) then return end

	local ut = stick() - lastUpdate
	lastUpdate = stick()
	
	if self.isAlive and self.customChar then
		
		-- for optimization
		local server = self.server
		local client = self.client
		local customChar = self.customChar
		local equipment = self.equipment
		local shoot = self.shoot
		
		-- basically, your camera is not always centered on your head.
		--  when your gun is raised it's offset a bit by a stat inside each gun.
		--  When you aim however, it moves your camera to line up with the gun sight,
		--  but since your head tilts when you aim, it has to account for that,
		--  and then your camera also bobs a bit when walking/running, and vibrates when shooting, so all those things have to be applied to it
		--  also your camera shifts when you crouch as well, thats why your gun is farther out when crouched
		local xp = client.angleX / 85
		local toolStance = equipment.stats.toolStance
		
		-- ok so i do a bit of a weird thing with smoothing where you A) have a linear interpolation, and B) have a proportional interpolation to that linear value and then C) smooth that final smoothened value
		-- this means it'll be smooth no matter what value it interpolates too, as well as if you change that value while it's transitioning
		-- server.run is an ultimate goal value, then client.run is a goal value for runsmooth, and then srun is runsmooth mapped to a cosine wave to make it smoother at values near 0 and 1
		-- stance, run, and aim all use the same process of smoothing
		-- and they're all between 0 and 1
		-- btw, stance will sometimes be greater than 1 [0 means stand, 1 means crouch]
		-- when you jump or land from falling, i adjust the stance value to create a sort of bounce/landing effect
		local srun = smoothLerp(0, 1, client.runSmooth)
		local saim = client.smoothAim * (1 - srun) * (1 - smoothLerp(0, 1, client.coverSmooth) * client.coverSmooth * 0 - client.coverSmooth) * (1 - smoothLerp(0, 1, client.jump))---smoothLerp(0,1,client.smoothAim)
		local stance = smoothLerp(client.stanceSmooth, 1, client.jump)

		local coffset = toolStance.camOffsetCrouch:Lerp(toolStance.camOffsetStand, stance)

		-- As i said, shooting is one case thst triggers it
		-- However, pulling out/inserting the gun mag applies some vibration as well by using the recoil.vin value
		local vibx = (random() - 0.5) * (shoot.Vib / 0.005) ^ 2 * 0.005 + noise(stick() / 0.145) * 0.026 * (shoot.Vib / 0.005) ^ 2
		local viby = (random() - 0.5) * (shoot.Vib / 0.005) ^ 2 * 0.005 + noise(stick() / 0.145 + 23.123) * 0.026 * (shoot.Vib / 0.005) ^ 2
		local vibz = (random() - 0.5) * (shoot.Vib / 0.005) ^ 2 * 0.005 + noise(stick() / 0.145 + 73.7) * 0.026 * (shoot.Vib / 0.005) ^ 2

		if lpVars.DisableCamera.Value == false then
			cam.CFrame = customChar.Head.CFrame
			* CFrame.new(Vector3.new(coffset.x * (1 - srun) + math.abs(client.leanSmooth) ^ 2.5 * 0.145, coffset.y - xp * 0.02 + 0.5 * srun, coffset.z - (coffset.z - toolStance.camOffsetCrouch.z) * lerp(0, 0.5, saim) + xp * 0.03) * Vector3.new(1 - saim, 1 - saim, 1 - saim))
			* CFrame.Angles(0, 0, rad(saim * toolStance.tiltHead))
			* (CFrame.new():lerp(equipment.gun_aimToSight, saim))
			* CFrame.Angles(0, 0, -rad(client.leanSmooth * 25) + client.smoothSideTilt * 0.8 - rad(saim * 5) + client.freeY / 90 * rad(10))
			--* CFrame.new(tp and Vector3.new(3, -0.1, 5) or Vector3.new())	-- no
			* CFrame.fromEulerAnglesYXZ(vibx * 0.8, viby * 0.8, vibz * 0.8)
			cam.FieldOfView = smoothLerp(85, 85 / equipment.stats.handling.aimFOVMult, saim)
			workspace.LocalSoundPart.CFrame = cam.CFrame
		else
			workspace.LocalSoundPart.CFrame = customChar.Head.CFrame
		end

		local weapon = self.equipment.model
		if weapon then
			-- a surfacegui on a brick in the sight and all of that is math to make it point to where the bullet will go
			local optic = weapon:FindFirstChild("ProjectedOptic", true)
			if optic then
				local opticPart = optic.Parent
				local gp = opticPart.Position + weapon.Fire.CFrame.lookVector * self.equipment.stats.handling.zero
				local relAim = workspace.CurrentCamera.CFrame:pointToObjectSpace(gp)
				local ang = CFrame.new(Vector3.new(), relAim)
				local ncf = workspace.CurrentCamera.CFrame * ang
				local nang = (opticPart.CFrame * CFrame.Angles(0, math.pi, 0)):toObjectSpace(ncf)
				local np = nang * Vector3.new(0, 0, -nang.z / nang.lookVector.z)
				optic.Cutoff.Optic.Position = UDim2.new(np.x / (opticPart.Size.x), 0, -np.y / (opticPart.Size.y), 0)
				optic.Enabled = self.client.aim > 0.1
			end
		end

	else
		-- for dead players, camera should follow him/her to the ground
		-- i.e. for dead players, the camera module wont auto-disconnect
		if self.customChar then
			-- death fall cam.
			if lpVars.DisableCamera.Value == false and self.customChar:FindFirstChild("Head") then
				--cam.CFrame = self.customChar.Head.CFrame * CFrame.new(0, 0, -0.5)
				workspace.LocalSoundPart.CFrame = cam.CFrame
			end
		end
	end
end


local function sumSaturation()
	local ret = 0
	for _, v in ipairs(lighting:GetChildren()) do
		if v:IsA("ColorCorrectionEffect") and v.Enabled then
			ret = ret + v.Saturation
		end
	end
	return ret
end
function md.hbUpdate()
	if not (self and self.isWatched) then return end

	local ut2   = tick() - lastUpdate2
	lastUpdate2 = tick()

	-- optimization here
	local spectating = not self.isLocal
	local server = self.server
	local client = self.client
	local customChar = self.customChar
	
	-- these values are just for the local player, so no need to include a server-side version
	-- decrease the goal dust overtime
	lpVars.GoalDust.Value = lerpTowards(lpVars.GoalDust.Value, 0, ut2 / 10)
	-- keep lerping actual dust value toward the goal value
	lpVars.Dust.Value     = lerp(lpVars.Dust.Value, lpVars.GoalDust.Value, clamp(ut2 / 0.08, 0, 1))
	-- screen dust effects
	local lamt = lpVars.Dust.Value * 3
	screenfx.Lenses.Dirt1.ImageTransparency  = percentBetween(3 - lamt, 2, 3)
	screenfx.Lenses.Dirt2.ImageTransparency  = percentBetween(3 - lamt, 1, 2)
	screenfx.Lenses.Dirt3.ImageTransparency  = percentBetween(3 - lamt, 0, 1)
	screenfx.Lenses.Health.ImageTransparency = lerp(lerp(0.3, 1, self.health / 100), 1, clamp((tick() - self.lastDmgTick)/8, 0, 1))
	lighting.DirtBlur.Size                   = lerp(lighting.DirtBlur.Size, lamt / 3 * 8, clamp(ut2 / 0.1, 0, 1))
	lighting.DirtBloom.Intensity             = lamt / 6
	lighting.DirtBloom.Size                  = lamt / 3 * 40
	lighting.DirtBloom.Threshold             = 0.9 --* lamt / 4

	-- night vision scanline effects
	screenfx.NV.ScanLine.Position = UDim2.new(0, 0, 0, (stick() * 45 % 2) * 2)
	-- screen effects due to health
	local sum = sumSaturation()
	lighting.HeliFade.Saturation      = lerp(lerp(-0.9, 0, self.health / 100), 0, clamp((tick() - self.lastDmgTick)/8, 0, 1))
	lighting.HeliFade.Contrast        = lerp(0.15, 0, self.health / 100)
	lighting.HeliFade.Brightness      = lerp(lighting.HeliFade.Brightness, 0, ut2 / 0.8)

	if lpVars.NightVision.Value ~= server.nightVision then
		lpVars.NightVision.Value = server.nightVision
		if server.nightVision then
			warn(1)
			-- client differing from server means that the client has not implemented dis change
			--if client.nightVision == false then
				lighting.HeliFade.Brightness = 2
				--client.nightVision       = true
			--end
			lighting.NV_CC.Saturation = math.max(-1-sum, -1)
			lighting.NV_Bloom.Enabled = true
			lighting.NV_CC.Enabled    = true
			screenfx.NV.Visible       = true
			customChar.Head.NV_Point.Enabled = true
			customChar.Head.NV_Spot.Enabled  = true
		else
			warn(2)
			--if client.nightVision == true then
				lighting.HeliFade.Brightness = -0.4
				--client.nightVision = false
			--end
			lighting.NV_Bloom.Enabled = false
			lighting.NV_CC.Enabled    = false
			screenfx.NV.Visible       = false
			customChar.Head.NV_Point.Enabled = false
			customChar.Head.NV_Spot.Enabled  = false
		end
	end--]]
end

function md.connect(_aplr)
	md.disconnect()
	warn("camera effects connect", _aplr.plr.Name)

	self = _aplr
	self.isWatched = true
	local spectating = not self.isLocal 

	-- assign "instance variables"
	lpScripts   = lp:WaitForChild("PlayerScripts")
	lpVars      = lpScripts:WaitForChild("Variables")
	lpGui       = lp:WaitForChild("PlayerGui")
	screenfx    = lpGui:WaitForChild("ScreenGui"):WaitForChild("Gameplay")
	lastUpdate  = tick()
	lastUpdate2 = tick()

	-- camera
	cam.CameraType = "Scriptable"
	cam.FieldOfView = 85

	-- setup mouse behavior
	uis.MouseBehavior    = Enum.MouseBehavior.LockCenter
	uis.MouseIconEnabled = spectating

	-- remove head
	self:renderHead(false)

	-- in first person i have a part that is always placed at your camera that holds audio makes it so sounds will stay centered on the camera from your own character
	local cch = cam.Changed:connect(function()
		local customChar = self.customChar
		local char = self.plr.Character
		if self and customChar and char then
			workspace.LocalSoundPart.CFrame = customChar.Head.CFrame
		end
	end)
	table.insert(connections, cch)

	-- moved to AnimatedPlayer, since rsupdate must be called after self:renderUpdate
	-- spawn(function()
	-- 	while self and self.isWatched do
	-- 		rs:wait()
	-- 		rsUpdate()
	-- 	end
	-- end)
	-- spawn(function()
	-- 	while self and self.isWatched do
	-- 		hb:wait()
	-- 		hbUpdate()
	-- 	end
	-- end)
end

function md.disconnect()
	if self then
		self.isWatched = false
		self:renderHead(true)
		warn("camera effects disconnect", self.plr.Name)
	end
	self = nil
	for _, connection in ipairs(connections) do
		connection:disconnect()
	end
end

return md
