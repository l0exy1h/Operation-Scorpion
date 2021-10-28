-- 180803 animatedPlayer before character rewrite

-- welds for characters
-- welds??: the objects that connect two parts together
local characterWelds = {
	{
		"Torso", "Head",
		CFrame.new(0, 1, 0),
		CFrame.new(0, -0.5, 0.1),
		"Head"
	},
	{
		"Torso", "LeftArm",
		CFrame.new(-1.5 / 2 - 0.75 / 2, 0.6, 0),
		CFrame.new(0, 0.1, 0),
		"Shoulder"
	},
	{
		"LeftArm", "LeftForearm",
		CFrame.new(0, -0.5, 0),
		CFrame.new(0, 0.5, 0),
		"Hinge"
	},
	{
		"Torso", "RightArm",
		CFrame.new(1.5 / 2 + 0.75 / 2, 0.6, 0),
		CFrame.new(0, 0.1, 0),
		"Shoulder"
	},
	{
		"RightArm", "RightForearm",
		CFrame.new(0, -0.5, 0),
		CFrame.new(0, 0.5, 0),
		"Hinge"
	},
	{
		"Torso", "LeftLeg",
		CFrame.new(-1.5 / 2 + 0.75 / 2, -1, 0),
		CFrame.new(0, 0.5, 0),
		"Hip"
	},
	{
		"LeftLeg", "LeftShin",
		CFrame.new(0, -0.5, 0),
		CFrame.new(0, 0.5, 0),
		"LegHinge"
	},
	{
		"Torso", "RightLeg",
		CFrame.new(1.5 / 2 - 0.75 / 2, -1, 0),
		CFrame.new(0, 0.5, 0),
		"Hip"
	},
	{
		"RightLeg", "RightShin",
		CFrame.new(0, -0.5, 0),
		CFrame.new(0, 0.5, 0),
		"LegHinge"
	},
}
local secureC0verbose = true
local secureC0errGap  = 10
local secureC0st      = tick()
local function checkC0(C0, weld)
	--if true then return false end	
	local lp = game.Players.LocalPlayer
	local event = lp:WaitForChild("PlayerGui"):WaitForChild("ChatScreen"):WaitForChild("LocalChatHandler"):WaitForChild("LocalMsg")
	local C0aX, C0aY = math.asin(C0.lookVector.y), math.atan2(C0.lookVector.x, -C0.lookVector.z)
	if C0.p.magnitude > 10	
		or not (-2 * math.pi <= C0aX and C0aX <= 2 * math.pi) 
		or not (-2 * math.pi <= C0aY and C0aY <= 2 * math.pi) then
		
		if secureC0verbose then
			if tick() - secureC0st > secureC0errGap then
				event:Fire("Humanoid Root Part Bug Detected!")
				event:Fire("Please F9 and post a screenshot to the bug report forum.")
				
				warn("\n-------------------bug-------------------")
				warn(string.format("[bug report] lp = %s, weld = %s, c0ax = %s, c0ay = %s, magnitude = %s", lp.Name, weld:GetFullName(), tostring(C0aX), tostring(C0aY), tostring(weld.C0.p.magnitude)))
				warn("-------------------bug-------------------\n")
			end
		end
		return false
	else
		return true
	end 
end

-- set the second value as an entry
for _, v in ipairs(characterWelds) do
	characterWelds[v[2]] = v
end
characterWelds.Torso = {nil, nil, CFrame.new(0, 0, 0)}

local function secureC0(partName, cf, weld)
	if not checkC0(cf, weld) then
		if secureC0verbose then
			if tick() - secureC0st > secureC0errGap then
				secureC0st = tick()
				warn("replace the c0 with", characterWelds[partName][3])
			end
		end
		return characterWelds[partName][3]
	else
		return cf
	end
end
----------------------

local AnimatedPlayer = {}
AnimatedPlayer.__index = AnimatedPlayer

local Data = nil-- the data package received from teleportation
-- will contain information about the weapon customization and the clothing cust(wip)
-- confirmed: tables in tables in tables work!
--[[unction AnimatedPlayer.setData(_data)-- potential hack here
	warn("data received in AnimatedPlayerMd. wip")
	Data = _data
end--]]
spawn(function()
	script:WaitForChild("GetData").OnInvoke = function(func, args)
		print("animatedplayer: data received", func, args[1], args[2])
		if func == "appendPlrData" then
			local plrName       = args[1]
			local singlePlrData = args[2]
			repeat 
				wait()
			until Data
			Data.plrData[plrName] = singlePlrData
		elseif func == "setEntireData" then
			local _data = args[1]
			Data = _data
		else
			error("wrong func", func)
		end
	end
	require(game.ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("Loading")).loaded("APlr:WaitForData")
	
	repeat wait(0.2)
		print("wait for data")
	until Data ~= nil
	warn("client: complete data table received")
	
	require(game.ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("Loading")).loaded("CompleteDataTable")
end)

-- defs
local rep = game.ReplicatedStorage
local plrs = game.Players
local lp = plrs.LocalPlayer
local audioEvent = script.Parent.Parent:WaitForChild("AudioEngine"):WaitForChild("AudioEvent")
local weaponAssemblyMd = require(script:WaitForChild("WeaponAssembly"))

local rs = game:GetService("RunService").RenderStepped
local hb = game:GetService("RunService").Heartbeat

local cam = workspace.CurrentCamera
local events = rep:WaitForChild("Events")
local mainRemote = events:WaitForChild("MainRemote")

local lpScripts = lp:WaitForChild("PlayerScripts")
local lpVars = lpScripts:WaitForChild("Variables")
local clientMain = lpScripts:WaitForChild("ClientMain")
local hitFx = clientMain:WaitForChild("ParticleHandler"):WaitForChild("HitFX")

local bulletHoleMd = require(script:WaitForChild("BulletHole"))
local shellMd = require(script:WaitForChild("ShellHandler"))
shellMd.setup()
local emitShell = script.ShellHandler:WaitForChild("EmitShell")

local gm = rep:WaitForChild("GlobalModules")
	local mathMd = require(gm:WaitForChild("Mathf"))
		local lerp = mathMd.lerp
		local lerpTowards = mathMd.lerpTowards
		local clamp = mathMd.clamp
		local smoothLerp = mathMd.smoothLerp
	-- local apple = require(gm:WaitForChild("Apple"))
	-- 	local fireServer = apple.fireServer

-- input modules
local keyboardMd = require(script:WaitForChild("KeyboardInput"))
local mouseMd = require(script:WaitForChild("MouseInput"))
local cameraMd = require(script:WaitForChild("CameraEffects"))

-- switches
local smokeEnabled = true
local bulletHoleEnabled = false

-- consts
local rayIgnoreWithAllChar = {
	workspace.Alive,
	workspace.LocalSoundPart,
	workspace.ActiveShells,
	workspace.Clothes,
	workspace.Map.AmbientBoxes,
	workspace.Map.Rekt,
	workspace.Map.Spawn,
	workspace.Map.Final,
	workspace.Map.Hardpoints,
	workspace.Map.glass.broken,
	workspace.Map.ParticleHolders,
	workspace.Map.LightHolders,
	workspace.Map.Boundary,
	workspace.Characters,
	workspace.BulletHoles,
}

local outfitWip = {}-- temp solution. should be set in the lobby place
outfitWip["Alpha"] = {
	"ScorpionShirt",
	"TacticalMask",
	"PistolHolster_Right",
	"helmet",
	"militaryBackpack",
	"militaryVest",
	"nVGoggles",
	"tacticalHeadphones"
}
outfitWip["Beta"] = {
	"SkullShirt",
	"skullsVest",
	"coverMask",
	"duffelBag",
	"PistolHolster_Right_Dark"
}

local stt = tick()
local function stick()
	return tick() - stt
end

-- static funcs
local function isLocalChar(char)
	return char == lp.Character
end

local function isCharAlive(char)
	return char.Parent == workspace.Alive
end

function AnimatedPlayer:getSoundHolder()
	return self.isLocal and workspace.LocalSoundPart or self.customChar.Head.Sounds
end

function AnimatedPlayer:getAttcTable(gearName)
	return self.savedAttcList[gearName]
end

-- the function will take an existing model where the parts are not connected,
-- and weld them to each other in a way that the model will still look the same but is now 1 physics object.
local function weldAll(obj, center)
	for i, v in ipairs(obj:GetChildren()) do
		if v:IsA("BasePart") then
			-- Outfits don't use removal parts, even though they have the option,
			-- thats just a part of the weld function which i use for weapons as well.
			local dr = v:FindFirstChild("Removal") ~= nil-- dont remove
			if v ~= center then
				local w  = Instance.new("Weld", center)
				w.Name   = v.Name
				w.C0     = center.CFrame:toObjectSpace(v.CFrame)
				w.Part0  = center
				local cf = Instance.new("CFrameValue", w)
				cf.Name  = "DefaultCF"
				cf.Value = w.C0
				if not dr then
					w.Part1 = v
				end
			end
			-- set custom properties
			v.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.1, 0.1)
			v.Anchored                 = false
			v.CanCollide               = false
			if dr then
				v:Destroy()
			end
		end
		weldAll(v, center)
	end
end

-- for magazine swapping
local function getMagModel(model)
	local ret = nil
	for _, v in ipairs(model.Attachments:GetChildren()) do
		if v:IsA("Model") and rep.Attachment.Magazine:FindFirstChild(v.Name) then
			ret = v
			break
		end
	end
	return ret
end
local function setModelTransparency(model, val)
	for _, v in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") and not string.find(v.Name, "attc_") and not string.find(v.Name, "r_") then
			v.Transparency = val
		end
	end
end

local function attc_Item(item, customChar, cm)
	-- clone that single part and put it under custom model
	local v = item:clone()
	v:BreakJoints()
	v.Parent = cm

	-- tie everything in that item to its center and create a Weld bt the corresponding body part and that center
	-- the connection obj (the weld) itself is stored in the torso
	weldAll(v, v.Center)
	if customChar and customChar:FindFirstChild("Torso") then
		local weld = Instance.new("Weld", customChar.Torso)
		weld.Part0 = customChar[v.Name]
		weld.Part1 = v.Center
	end
end

-- a single cloting might contain multiple parts for multiple body parts
-- for our custom char of course
local function attc_Clothing(customChar, clothing, cm)
	for i, piece in ipairs(clothing:GetChildren()) do
		-- if the customChar (custom char) has that body part
		if customChar:FindFirstChild(piece.Name) and piece:FindFirstChild("Center") then
			attc_Item(piece, customChar, cm)
		end
	end
end

function AnimatedPlayer:getClothesModel()
	return workspace.Clothes:FindFirstChild(self.plr.Name)
end

function AnimatedPlayer:equipGoalEquipment()
	self:attc_LoadGun(rep.Gear:FindFirstChild(self.equipment.goal, true), self:getAttcTable(self.equipment.goal))
end

-- gunFolder:  the folder for the base gun model, children = {Audio, Stats, Tool}
-- attcList :  a table containing strings (names) of attachments
-- modifies self.equipment.stats and self.equipment.model
function AnimatedPlayer:attc_LoadGun(gunFolder, attcList)
	-- optimization here
	local rbxChar    = self.plr.Character
	local cm         = self:getClothesModel()
	local customChar = self.customChar
	local gunName    = gunFolder.Name
	local equipment  = self.equipment

	-- update gun stats
	equipment.stats = self.savedStats[gunName]

	-- destroy existing gun sounds
	local soundHolder = self:getSoundHolder()
	for i, v in ipairs(soundHolder:GetChildren()) do
		if v:FindFirstChild("GunSound") then
			v:Destroy()
		end
	end

	-- clone the new sounds
	for i, v in ipairs(gunFolder.Audio:GetChildren()) do
		local sound    = v:clone()
		sound.Parent   = soundHolder
		local gunSound = Instance.new("NumberValue", sound)
		gunSound.Name  = "GunSound"
		
		if sound.Name == "GunshotSuppressed" then
			local customVolume = Instance.new("NumberValue", sound)
			customVolume.Value = 8 * equipment.stats.shooting.soundMult
			customVolume.Name = "CustomVolume"
		end
	end

	-- destroy existing gun model
	if equipment.model then
		equipment.model:Destroy()
		equipment.model = nil
	end

	-- add the new gun model
	local newModel  = self.savedModel[gunName]:clone()
	-- weaponAssemblyMd.assembly(gunFolder.Tool, attcList)
	newModel.Parent = cm
	equipment.model = newModel

	-- weaponAssemblyMd.getStats(gunFolder, attcList)

	-- connect the gun itself and attach it to the char
	--weldAll(newModel, newModel.Hold_Default)		-- optimized: moved to savedModel
	local m = Instance.new("Motor6D", newModel.Hold_Default)
	m.Name  = "Main"
	m.Part0 = customChar.Head
	m.Part1 = newModel.Hold_Default
	local w = newModel.Hold_Default.Main
	w.Part0 = customChar.Head
	w.C0    = CFrame.new()
	w.C1    = CFrame.new()

	equipment.current        = equipment.goal
	equipment.weight         = 1  						-- tmp
	equipment.gun_aimToSight = newModel.Hold_Default.Hold_Aim.C0:toObjectSpace(newModel.Hold_Default.Cam_Aim.C0)
end

-- hide/remove the default character in workspace.Alive
-- add custom character in workspace.Characters
function AnimatedPlayer:attachCustomChar(char)
	-- set the default bricks invisible
	-- dont remove them bc the player needs them to stay alive
	for i, v in ipairs(char:GetChildren()) do
		if v:IsA("BasePart") then
			v.Transparency = 1
			if v.Name == "Head" then
				v:ClearAllChildren()
			end
		elseif v:IsA("Accessory") then
			v:Destroy()
		end
	end
	
	-- put the hitboxes and the animation bases workspace.Characters
	local bod = script:WaitForChild("CustomCharacter"):Clone()
	bod.PrimaryPart = bod.Torso
	bod.Name = char.Name
	bod:BreakJoints()-- Roblox has joints that aren't instances,
	-- so this prevents the character from sticking to parts in the world.
	bod.Owner.Value = char
	bod.Parent = workspace.Characters
	
	-- add joints (constraints & motor6d)
	-- the constraints are added but disabled so that when the character ragdolls,
	-- the motor6Ds can be removed and the constraints get enabled
	for i, v in ipairs(characterWelds) do
		if bod:FindFirstChild(v[1]) and bod:FindFirstChild(v[2]) then
			-- put the motor6d object into bod.Torso
			local w = Instance.new("Motor6D", bod.Torso)
			-- set the joint based on the table
			w.Name                 = v[2]
			w.Part0                = bod[v[1]]
			w.Part1                = bod[v[2]]
			w.C0                   = v[3]
			w.C1                   = v[4]
			bod[v[1]].Anchored     = false
			bod[v[1]].Transparency = 1
			bod[v[2]].Anchored     = false
			bod[v[2]].Transparency = 1
			
			-- constraints for death
			local at1              = Instance.new("Attachment", bod[v[1]])
			local at2              = Instance.new("Attachment", bod[v[2]])
			at1.Name               = v[1] .. "/to/"..v[2]
			at2.Name               = v[2] .. "/to/"..v[1]
			at1.Position           = v[3].p
			at2.Position           = v[4].p
			
			local h                = script[v[5]]:clone()
			h.Enabled              = false -- <-- disable the constraints for alive plrs
			h.Parent               = bod.Torso -- add that in torso too
			h.Attachment0          = at1
			h.Attachment1          = at2
		end
	end
	if self.isLocal then
		-- Those lines attach the custom character to the default character so the physics of each can interact,
		-- such as if your custom character's head clips into a wall it can push your real character back.
		-- The default character doesn't turn as of now.
		local torw = Instance.new("Motor6D", bod.Torso)
		torw.Part0 = char.HumanoidRootPart
		torw.Part1 = bod.Torso
		torw.Name  = "Torso"
		torw.C1    = CFrame.new(0, -1, 0)
		bod.Torso.TurnLock:Destroy()
		bod.Torso.PosLock:Destroy()
		-- because the local player uses default character physics
		-- but other players i need more physics control over because of how roblox does motors
	else
		-- delete the original character for other players
		-- retain the original character for lp to make it alive (controllable)
		print("Destroying: "..char.Name)
		for i, v in ipairs(char:GetChildren()) do
			--if v.Name ~= "Stats" then
			v:Destroy()
			--end
		end
	end

	-- a reference to the custom character
	return bod
end

-- constructor (load character)
function AnimatedPlayer.new(plr)
	-- wait for data
	local waitCnt = 0
	repeat wait() 
		waitCnt = waitCnt + 1
		if waitCnt % 200 == 1 then
			print("wait for data table for", plr)
		end
	until Data and Data.plrData[plr.Name]	
	
	local self = {}
	setmetatable(self, AnimatedPlayer)

	self.plr          = plr
	self.name         = plr.Name
	self.isAlive      = true
	self.deathHandled = false
	self.isLocal      = plr.Name == lp.Name
	local char  = self.plr.Character
	local hrpCF = char.HumanoidRootPart.CFrame

	-- default rendering settings
	self.rendering = {
		lastUpdate = stick(),
		range = 1
	}

	-- instance variables here
	self.equipment = {
		ammo = {}
	}

	self.server = {
		position    = hrpCF.p,
		velocity    = Vector3.new(0, 0, 0),
		aim         = 0,
		angleX      = 0,
		angleY      = 0,
		cover       = 0,
		flashlight  = false,
		freeP       = 0,
		freeX       = 0,
		freeY       = 0,
		gunReady    = 1,
		jump        = 0,
		lean        = 0,
		nightVision = false,
		reload      = 0,
		run         = 0,
		stance      = 0,
		supressed   = 0,
		torsoLook   = 0.5,
	}
	self.client = {
		--dead         = false,
		aim            = 0,
		aimLast        = 0,
		angleX         = 0,
		angleY         = 0,
		cover          = 0,
		coverSmooth    = 0,
		deltaX         = 0,
		deltaY         = 0,
		flashlight     = false,
		freeP          = 0,
		freeX          = 0,
		freeY          = 0,
		goalHipAngle   = 0,
		gunReady       = 0,
		jump           = 0,
		lastJump       = 0,
		lastStepAngle  = 0,
		lean           = 0,
		leanSmooth     = 0,
		lHipAngle      = 0,
		nightVision    = false,
		position       = Vector3.new(0, 0, 0),
		reload         = 0,
		reloadState    = 0,
		rHipAngle      = 0,
		run            = 0,
		runSmooth      = 0,
		scroll         = 0,
		sDeltaX        = 0,
		sDeltaY        = 0,
		smoothAim      = 0,
		smoothSideTilt = 0,
		stance         = 0,
		stanceSmooth   = 0,
		supressed      = 0,
		sway           = 2,
		scroll         = 0,
		torsoLook      = 0,
		velocity       = Vector3.new(0, 0, 0),
		walkAmt        = 0,
		walkAmtSmooth  = 0,
		walkCount      = 0
	}
	self.shoot = {
		G_RBack   = 0,
		G_RUp     = 0,
		G_Vib     = 0,
		lastShot  = -100,
		RBack     = 0.1,
		RUp       = 0,
		Vib       = 0,
		shoot     = false,
		swayCount = 0
	}
	self.walk = {
		cycle    = 0,
		gPercent = 0,
		percent  = 0,
		sPercent = 0,
		legAngle = 0,
		stepDist = 0,
		recover  = tick()		-- for setBreath
	}
	self.scared = "Nervous"
	self.injured = false
	self.health = 100
	self.lastDmgTick = tick()
	self.test = false
	
	
	self.customChar = self:attachCustomChar(self.plr.Character)
	self.rayIgnoreWithChar = {
		workspace.Alive,
		workspace.LocalSoundPart,
		workspace.ActiveShells,
		workspace.Clothes,
		workspace.Map.AmbientBoxes,
		workspace.Map.Rekt,
		workspace.Map.Spawn,
		workspace.Map.Final,
		workspace.Map.Hardpoints,
		workspace.Map.ParticleHolders,
		workspace.Map.glass.broken,
		workspace.Map.LightHolders,
		workspace.BulletHoles,
		workspace.Map.Boundary,
		self.customChar
	}

	-- create the clothes model for the player
	local cm = Instance.new("Model", workspace.Clothes)-- cm stands for clothes model
	cm.Name = char.Name
	for i, v in ipairs(outfitWip[plr.Team.Name]) do
		attc_Clothing(self.customChar, script.Outfits[v], cm)
	end

	-- setup the sound part: must be before the gun loading
	local sounds = Instance.new("Attachment", self.customChar.Head)
	sounds.Name = "Sounds"
	local soundHolder = self:getSoundHolder()

	-- gear optimization:
		-- pre-process the gun model and the stats table
	self.savedModel = {}											-- gunName -> model
	self.savedStats = {}											-- gunName -> statsTable
	self.savedAttcList = {}
	self.savedGearName = {}
	for gearType, attcData in pairs(Data.plrData[self.name]) do
		local gearName = attcData.name
		local attcList = attcData.attcList		
		local gearFolder = rep.Gear:FindFirstChild(gearName, true)
		
		local model = weaponAssemblyMd.assemble(gearFolder, attcList)
		weldAll(model, model.Hold_Default)
		self.savedModel[gearName] = model
		self.savedStats[gearName] = weaponAssemblyMd.getStats(gearFolder, attcList)
		self.savedAttcList[gearName] = attcList
		table.insert(self.savedGearName, gearName)
		
		self.equipment.ammo[gearName.."_Mag"] = self.savedStats[gearName].resources.magSize
		warn("insert ammo:", self.equipment.ammo[gearName.."_Mag"])
		-- choose the first equipment
		if self.equipment.goal == nil then
			self.equipment.goal = gearName
		end
	end

	self:equipGoalEquipment()

	-- put everything in the sound holder
	for i, sound in ipairs(script.PlayerAudio:GetChildren()) do
		sound = sound:clone()
		sound.Parent = soundHolder
		-- start playing the breath sounds by default, just set the vol = 0
		if sound:FindFirstChild("SoundStats") and sound.Name:find("Breath") then
			sound.Volume = 0
			audioEvent:Fire("Play", {sound, false, true})
		end
	end

	-- sounds for steps
	for _, material in ipairs(rep.Events.Steps:GetChildren()) do
		for _, stance in ipairs(material:GetChildren()) do
			local cnt = 0
			for _, sound in ipairs(stance:GetChildren()) do
				if sound:IsA("Sound") then
					cnt = cnt + 1
					local soundName = material.Name.."/"..stance.Name.."_"..cnt
					sound           = sound:clone()
					sound.Name      = soundName
					sound.Parent    = soundHolder

					if material.Name ~= "Water" then					
						local soundStats  = Instance.new("StringValue")
						soundStats.Name   = "SoundStats"
						soundStats.Value  = "Step"..stance.Name
						soundStats.Parent = sound
					end
					
					-- preload the sound
					sound:play()
					sound:stop()
				end
			end
		end
	end

	if self.isLocal then
		keyboardMd.connect(self)
		mouseMd.connect(self)
		cameraMd.connect(self)
	end

	self:main()

	return self
end

--[[
function AnimatedPlayer:isAlive()
return 
end--]]

function AnimatedPlayer:distToCam()
	if self.plr and self.plr.Character and self.plr.Character:FindFirstChild("HumanoidRootPart") then
		return (cam.CFrame.p - self.plr.Character.HumanoidRootPart.Position).magnitude
	else
		return (self.server.position - cam.CFrame.p).magnitude
	end
end

-- enable/disable head rendering
function AnimatedPlayer:renderHead(bool, cm)
	warn("renderhead", bool)
	if cm == nil then
		cm = self:getClothesModel()
	end
	if bool then
		if cm and cm:FindFirstChild("Head") == nil then
			for _, v in ipairs(outfitWip[self.plr.Team.Name]) do
				local item = script.Outfits[v]
				for _, piece in ipairs(item:GetChildren()) do
					if piece.Name == "Head" then
						attc_Item(piece, self.customChar, cm)
					end
				end
			end
		end
	else
		if cm then
			for _, v in ipairs(cm:GetChildren()) do
				if v.Name == "Head" then
					v:Destroy()
				end
			end
		end
	end
end

-- handling death
function AnimatedPlayer:rekt()

	local customChar = self.customChar

	if self.isWatched then
		-- add the head back on (bc the head is disabled for local player)
		local cm = self:getClothesModel()
		if cm and cm:FindFirstChild("Head") == nil then
			self:renderHead(true, cm)
		end
	end

	if not self.deathHandled then
		self.deathHandled = true

		if self.isLocal then
			keyboardMd.disconnect()
			mouseMd.disconnect()
		end

		-- enable constraints, destroy motor6ds and other stuff?
		for _, v in ipairs(self.customChar.Torso:GetChildren()) do
			if v:IsA("Constraint") then
				v.Enabled = true
			elseif not v:IsA("Weld") and not v:IsA("Attachment") then
				v:Destroy()
			elseif v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
				v:Destroy()
			end
		end

		-- add phyx objects
		-- that reduce gravity on the body, so it looks more realistic with a slower fall
		for i, v in ipairs(self.plr.Character:GetChildren()) do
			if v:IsA("BasePart") then
				local bf = Instance.new("BodyForce")
				bf.Force = Vector3.new(0, v:GetMass() * 40, 0)
				bf.Parent = v
			end
		end

		-- put the custom character into Ragdolls
		customChar.Parent              = workspace.Ragdolls
		customChar.LeftArm.CanCollide  = false
		customChar.LeftLeg.CanCollide  = false
		customChar.RightArm.CanCollide = false
		customChar.RightLeg.CanCollide = false

		-- along with the clothes
		local cm = self:getClothesModel()
		if cm then
			cm.Parent = customChar
		end
		--game.Debris:AddItem(bod,120)-- delete the ragdolls after 120 secs

		-- add some falling animations
		for i, v in ipairs(customChar:GetChildren()) do
			if v:IsA("BasePart") then
				-- anglex is verticle, angley is rotation left/right, and anglez is tilting to the side
				local tvel                 = CFrame.Angles(0, math.rad(self.client.angleY), 0) * self.client.velocity
				v.Anchored                 = false
				v.Velocity                 = tvel+Vector3.new(0,2,0)
				v.CanCollide               = true
				v.CustomPhysicalProperties = PhysicalProperties.new((v.Name == "Head" and 20 or 10),0.6, 0, 0.5, 1)	
				if v.Name == "Head" then
					v.Velocity = tvel*2
				end
			end
		end

		-- sound, stop all sounds save for deathscream
		local soundHolder = self:getSoundHolder()
		for _, v in ipairs(soundHolder:GetChildren()) do
			if v:IsA("Sound") and v.Name ~= "DeathScream" then
				v.Volume = 0
				if v:FindFirstChild("SoundStats") and v.SoundStats:IsA("Folder") then
					v.SoundStats.Volume.Value = 0
					v:Stop()
				else
					v:Stop()
				end
			end
		end
		-- auto play deathsound
		local ap = Instance.new("BoolValue")
		ap.Name = "AutoPlaySound"
		ap.Parent = soundHolder.DeathScream

		-- drop the weapon
		local weapon = self.equipment.model
		if weapon then
			weapon.Hold_Default.Main:Destroy()
			weapon.Hitbox.CustomPhysicalProperties = PhysicalProperties.new(10, 0.5, 0, 1, 1)
			weapon.Hitbox.CanCollide = true
		end

		if self.isLocal then
			self.plr.Character.HumanoidRootPart.CFrame = CFrame.new(0, 100, 0)
			-- keyboardMd.disconnect()
			-- mouseMd.disconnect()
			-- added by y0rkl1u: to take char out of Alive folder
			mainRemote:FireServer("SpawnR6")
		end
	end

	-- to do handling and destroy() and garbage collection
	-- dunno how, currently handled in PlayerAnimation (automatically, gets reassigned)
end

-- shooting / ray casting
-- dist is the distToCam
function AnimatedPlayer:handleShooting(dist, weapon)
	
	-- optimization
	local shooting   = self.equipment.stats.shooting
	local customChar = self.customChar
	local char       = self.plr.Character
	local shoot      = self.shoot
	local client     = self.client
	local server     = self.server
	local gearName   = self.equipment.current
	
	-- handling the firing animation only when dist < 500
	if dist < 500 then
		-- set recoil when you shoot
		-- Recoil.RBack is how much the gun is currently kicking back towards the camera,
		-- RUp is how much the gun is kicked up/down (position, not rotation),
		-- Recoil.Vib is how much the gun vibrates in place when you shoot, etc.
		shoot.G_RBack  = shooting.recBack * (client.reload > 0.1 and 2 or 1)
		shoot.G_RUp    = shooting.recKickUp * (client.reload > 0.1 and 1.8 or 1)
		shoot.G_Vib    = shooting.recVibration * (client.reload > 0.1 and 1.4 or 1)
		shoot.lastShot = stick()

		-- change the server-side vars here, uploaded elsewhere
		server.angleX = server.angleX + shooting.camKickUp
		client.angleX = client.angleX + shooting.camKickUp * 0.5
		
		-- barrel animations, smoke
		if smokeEnabled and weapon:FindFirstChild("Fire") then
			local flashMult = shooting.flashMult
			local smokeMult = shooting.smokeMult
			local fx = weapon.Fire.Effects
			if lpVars.NightVision.Value == false then
				fx.Flash:Emit(2 * flashMult)
				fx.Smoke:Emit(2 * smokeMult)
			else
				fx.NVFlash:emit(1 * flashMult)
				fx.NVSmoke:emit(2 * smokeMult)
			end
		end
	end
	
	-- the firing sound.
	if weapon then
		local soundHolder = self:getSoundHolder()
		audioEvent:Fire("Play", {soundHolder:FindFirstChild(shooting.suppressed and "GunshotSuppressed" or "Gunshot"), false, true})
		audioEvent:Fire("Play", {soundHolder:FindFirstChild("GunMechanics"), false, true})
		
		-- render the shell only when dist < 25
		if dist < 25 and weapon:FindFirstChild("ShellEmitter") then
			local se = weapon.ShellEmitter
			se.ShellGas:emit(1)
			local shellDropSound = nil
			if client.stance >= 1 then	-- crouch
				shellDropSound = soundHolder:FindFirstChild("ShellDropLow")
			else
				shellDropSound = soundHolder:FindFirstChild("ShellDrop"..math.random(1, 2))
			end
			emitShell:Fire(shooting.shellType, se.CFrame, se.CFrame.lookVector, 1, shellDropSound)
		end
	end
	
	-- the bullet comes from the barrel if normal
	-- the bullet comes from the scope if ads
	if weapon:FindFirstChild("Fire") and weapon:FindFirstChild("Cam_Aim") then
		-- ray casting here
		local ray = Ray.new(weapon.Fire.Position:lerp(weapon.Cam_Aim.Position, client.aim)
		-weapon.Fire.CFrame.lookVector * 0.4, weapon.Fire.CFrame.lookVector * 999)
		-- hit: part hit
		-- point: position as a vector3
		-- surface: the orthogonal vector of the plane hit
		local hit, point, surface, material = workspace:FindPartOnRayWithIgnoreList(ray, self.rayIgnoreWithChar)
		
		if hit then
			if bulletHoleEnabled then
				bulletHoleMd.makeHole(point)
			end
			if smokeEnabled then
				hitFx:Fire(hit, point, surface, material)
			end
			
			-- fucking orthogonal projection here
			local scf    = CFrame.new(ray.Origin, ray.Origin + ray.Direction)-- cf.point = origin, cf.lookvec = ray
			local relpos = scf:pointToObjectSpace(workspace.CurrentCamera.CFrame.p)--
			local ncf    = scf * Vector3.new(0, 0, clamp(relpos.z, -(point - ray.Origin).magnitude, 0))
			
			-- supression system
			if relpos.z < -5 then
				local camdist = (workspace.CurrentCamera.CFrame.p - ncf).magnitude
				if camdist < 10 then
					script.Whizz["Impact"..math.random(1, 5)]:play()
					game.Lighting.DirtBlur.Size = 7
					lpVars.GoalDust.Value = lerp(lpVars.Dust.Value, 0.5, 0.15)
				elseif camdist < 40 then
					script.Snap["Impact"..math.random(1, 5)]:play()
				end
			end
			
			-- let the local player handling damage [bad]
			-- only register the hit in characters (body parts), i.e. everything in workspace.Characters is hitboxes.
			-- ignore clothing and etc (see the ignore list)
			if hit:IsDescendantOf(workspace.Characters) and self.isLocal then
				if hit.Parent:FindFirstChild("Owner") then
					local owner = hit.Parent.Owner.Value
					if owner and isCharAlive(owner) then
						-- potential: body part detection! (damage varies based on body part)
						local dmg = nil
						if hit.Name == "Head" then
							dmg = 233
						else
							dmg = shooting.damage
						end
						mainRemote:FireServer("changeHealth", {owner.Name, -dmg, gearName, Ray.new(Vector3.new(1, 2, 3), Vector3.new(4, 5, 6))})
						-- todo: move this to the victim's side???
					end
				end
			end
		end
	end
end

-- secondary main
-- "Server values update depending on the value. Position and angle is every 0.1 seconds
-- The rest update whenever the player sends a signal to the server such as when they right click to aim" -- Matt
function AnimatedPlayer:renderUpdate()
	if self.health <= 0.01 then
		self.isAlive = false
	end
	if not self.isAlive then
		self:rekt()
		return
	end

	-- optmization
	local char       = self.plr.Character
	local customChar = self.customChar
	
	local customTorso= customChar.Torso
	local cm         = self:getClothesModel()
	local distToCam  = self:distToCam()
	local isWatched  = self.isLocal or self.isWatched

	-- local
	local client = self.client
	local walk   = self.walk
	local shoot  = self.shoot

	-- server
	local server    = self.server
	local equipment = self.equipment
	
	-- for weapon switching
	if equipment.goal ~= equipment.current then
		self:equipGoalEquipment()
	end
	local weapon     = equipment.model
	local handling   = equipment.stats.handling
	local shooting   = equipment.stats.shooting
	local toolStance = equipment.stats.toolStance
	local resources  = equipment.stats.resources
	local weightMult = lerp(0.7, 1, (1 - equipment.weight / 80) ^ 1.5)

	-- record the last update and update time
	local now = stick()
	local ut = now - self.rendering.lastUpdate
	self.rendering.updateTime = ut
	self.rendering.lastUpdate = now

	-- decide to render sth or not based on the distance passed into the function
	local dist         = self:distToCam()
	local r_dorec      = (dist < 60)
	local r_gunmove    = (dist < 20)
	local r_doaimdet   = (dist < 15)
	local r_doaimtrans = (dist < 100)
	local r_dogun      = (dist < 500)
	local r_dolegs     = (dist < 400)
	
	-- stepdist is for the sound: stepDist is how many studs your character has to move to take a step (play a footstep sound)
	walk.stepDist = walk.stepDist + server.velocity.magnitude * ut
	
	-- FreeP is sorta a boolean. 
	-- Notice how when you stop freelooking it transitions back to straight forward 
	-- and then if you start again freex and freey are at 0
	client.freeP = (server.freeP == 1 and 1 or lerpTowards(client.freeP, 0, ut / 0.2))
	
	-- position related data
	-- not lp.char
	if not self.isLocal then
		-- lerp the angles smoothly since the server-side value updates once every 1/10 secs,
		-- whereas the client-side updates everyframe ~ 1/60 secs.
		--local clamp = function() return 1 end
		client.angleX   = lerp(client.angleX, server.angleX, clamp(ut / 0.1, 0, 1))
		client.angleY   = lerp(client.angleY, server.angleY, clamp(ut / 0.1, 0, 1))
		client.freeX    = lerp(client.freeX, server.freeX, clamp(ut / 0.1, 0, 1))
		client.freeY    = lerp(client.freeY, server.freeY, clamp(ut / 0.1, 0, 1))
		client.position = client.position:lerp(server.position, clamp(ut / 0.1, 0, 1))
	else -- lp.char
		-- the server-side value is uploaded sw else
		server.position = char.HumanoidRootPart.Position
		server.velocity = char.HumanoidRootPart.Velocity * Vector3.new(1, 0, 1)
		
		client.angleY   = server.angleY
		client.angleX   = server.angleX
		client.position = server.position
		client.freeX    = server.freeX
		client.freeY    = server.freeY
		
		-- the gun sway values is only client side (there will be codes processing others gun sway down below)
		-- smoothened version of deltax/y (gun sway)
		client.sDeltaX  = lerp(client.sDeltaX, client.deltaX, clamp(ut / 0.06, 0, 1))
		client.sDeltaY  = lerp(client.sDeltaY, client.deltaY, clamp(ut / 0.06, 0, 1))
		
		-- gun sway,  keep reducing the gun sway
		client.deltaX   = lerp(client.deltaX, 0, clamp(ut / 0.11, 0, 1))
		client.deltaY   = lerp(client.deltaY, 0, clamp(ut / 0.11, 0, 1))
	end
	
	-- self.scared
	local recovering = tick() - self.walk.recover < 8
	local cbreath = recovering and "Recover" or "Normal"
	if server.aim == 1 then
		cbreath = recovering and "Nervous" or "Calm"
	end
	if server.run then
		cbreath = server.aim == 1 and "Shakey" or "Scared"
	end
	self.scared = cbreath
	mainRemote:FireServer("setLocalValue", {"scared", cbreath})

	-- headlight control
	-- adjust headlight considering Night vision
	customChar.Head.Flash_Point.Brightness = lpVars.NightVision.Value and 5 or 1
	customChar.Head.Flash_Point.Range = lpVars.NightVision.Value and 12 or 8
	customChar.Head.Flash_Spot.Brightness = lpVars.NightVision.Value and 5 or 1
	customChar.Head.Flash_Spot.Angle = lpVars.NightVision.Value and 60 or 40
	
	-- enable/disable head-light
	if server.flashlight ~= client.flashlight then
		customChar.Head.Flash_Point.Enabled = server.flashlight
		customChar.Head.Flash_Spot.Enabled = server.flashlight
		client.flashlight = server.flashlight
		if cm then
			local fl = cm:FindFirstChild("FlashlightPart", true)
			if fl then
				fl.Material = server.flashlight and Enum.Material.Neon or Enum.Material.Plastic
			end
		end
	end
	
	-- change the server-side vars here, uploaded elsewhere
	server.freeX = (client.freeP == 0 and 0 or client.freeX)
	server.freeY = (client.freeP == 0 and 0 or client.freeY)
	
	-- Shooting!
	-- the shoot table is only client side
	if shoot.shoot then
		shoot.shoot = false
		self:handleShooting(distToCam, weapon)
	end
	
	-- number values for body animations
	-- recover from recoil
	shoot.RBack   = lerp(shoot.RBack, shoot.G_RBack, clamp(ut / 0.05, 0, 1))
	shoot.G_RBack = lerp(shoot.G_RBack, 0, clamp(ut / 0.06, 0, 1))
	shoot.RUp     = lerp(shoot.RUp, shoot.G_RUp, clamp(ut / 0.05, 0, 1))
	shoot.G_RUp   = lerp(shoot.G_RUp, 0, clamp(ut / 0.06, 0, 1))
	shoot.Vib     = lerp(shoot.Vib, shoot.G_Vib, clamp(ut / 0.08, 0, 1))
	shoot.G_Vib   = lerp(shoot.G_Vib, 0, clamp(ut / 0.11, 0, 1))

	client.goalHipAngle = (math.abs(client.angleY - client.goalHipAngle) > 65
		and client.angleY
		or client.walkAmtSmooth > 0.1
			and client.angleY
			or client.goalHipAngle)

	-- Client L/rHipAngle are for animation. 
	-- Notice how when you turn while standing in place, you legs don't rotate with you until you turn a certain amount? 
	-- Those are the values for the current rotation of the hips like that.
	client.lHipAngle = (server.velocity * Vector3.new(1, 0, 1)).magnitude > 0.1 
		and client.goalHipAngle 
		or lerpTowards(
			clamp(
				client.lHipAngle, 
				client.goalHipAngle - 70, 
				client.goalHipAngle + 90
			), 
			client.goalHipAngle, ut * 260
		)
	client.rHipAngle = client.lHipAngle

	client.lean         = lerpTowards(client.lean, server.lean, ut / (0.18 / weightMult))
	client.leanSmooth   = lerp(client.leanSmooth, client.lean, clamp(ut / 0.08, 0, 1))
	client.stance       = lerpTowards(client.stance, lerp(server.stance, 0.7, server.jump), ut / 0.35)
	client.stanceSmooth = lerp(client.stanceSmooth, client.stance, clamp(ut / 0.09, 0, 1))
	client.gunReady     = lerpTowards(client.gunReady, server.gunReady, ut / 0.35)
	--client.torsoLook  = lerpTowards(client.torsoLook,server.torsoLook,ut/0.45)
	client.aim          = lerpTowards(client.aim, server.aim, ut / handling.aimSpeed)
	client.smoothAim    = lerp(client.smoothAim, client.aim, clamp(ut / handling.aimSmoothing, 0, 1))
	client.run          = lerpTowards(client.run, (server.velocity.magnitude > 1 and server.run or 0), ut / 0.3)
	client.runSmooth    = lerp(client.runSmooth, client.run, clamp(ut / 0.12, 0, 1))
	client.reload       = lerpTowards(client.reload, server.reload, ut / (server.reload == 1 and 0.9 or 0.4))
	
	client.cover        = lerpTowards(client.cover, server.cover, ut / (server.cover == 1 and 0.2 or 0.09))
	client.coverSmooth  = lerp(client.coverSmooth, client.cover, clamp(ut / 0.08, 0, 1))

	-- jump
	-- I use the default behavior for jump physics. 
	-- But the jump value is for animation, since your character bounces when you jdmp, 
	-- and bounces a bit when you land, as well as raising their legs while in the air.
	client.jump = lerp(client.jump, server.jump, clamp(server.jump == 1 and ut / 0.125 or ut / 0.26, 0, 1))
	if server.jump == 1 and client.lastJump == 0 then
		--client.stance = 0.7
	elseif server.jump == 0 and client.lastJump == 1 then
		client.stance = server.stance + lerp(1.7, 1.1, server.stance)
	end
	client.lastJump = server.jump

	-- walk
	-- The walk values are all for walk animations. 
	-- WalkPercent is a value between 0 and 1 that transitions smoothly to 1 if you are currently walking, and 0 otherwise. 
	-- walkAmt is another smooth value that transitions up. 
	-- It's your current movement speed divided by your max movement speed, and is used to get a proper speed for the leg animations.  
	-- dwalkCount is a value that counts up as you walk based on speed.
	-- It basically is used for the sin waves and stuff of the leg animations.
	walk.gPercent = (server.velocity * Vector3.new(1, 0, 1)).magnitude > 0.1 and 1 or 0
	walk.percent  = lerpTowards(walk.percent, walk.gPercent, ut / 0.2)
	walk.sPercent = lerp(walk.sPercent, walk.percent, clamp(0, 1, ut / 0.05))
	if walk.sPercent > 0.025 then
		walk.cycle = mathMd.wrap(walk.cycle + client.walkAmtSmooth * ut * lerp(lerp(1.7, 1.55, mathMd.percentBetween((server.velocity * Vector3.new(1, 0, 1)).magnitude, 6, 12)), 1.2, client.run), 0, 1)
	else
		walk.cycle = 0.25
	end
	--server.velocity = char.HumanoidRootPart.velocity*Vector3.new(1,0,1)
	local flatdir = CFrame.Angles(0, math.rad(client.angleY), 0)
	client.velocity      = client.velocity:lerp(flatdir:pointToObjectSpace(server.velocity), clamp(ut / 0.15, 0, 1))
	client.walkAmt       = lerp(client.walkAmt, client.velocity.magnitude / 12, clamp(ut / 0.08, 0, 1))
	client.walkAmtSmooth = lerp(client.walkAmtSmooth, client.walkAmt, clamp(ut / 0.08, 0, 1))
	client.walkCount     = client.walkCount + ut * lerp(0.6, 1.2, client.walkAmtSmooth) * weightMult

	local velUnit = (client.velocity.magnitude > 0.01 and client.velocity.unit or Vector3.new())

	-- the smoothened values
	local sJump         = smoothLerp(0, 1, client.jump)
	local sStanceSmooth = client.stanceSmooth--lerp(client.stanceSmooth--,0.7,sJump)
	local sGunReady     = smoothLerp(0, 1, client.gunReady)
	local sRun          = smoothLerp(0, 1, client.runSmooth)
	local sCover        = handling.obstruction and client.coverSmooth * (1 - sRun) or 0
	local sAim          = client.smoothAim * (1 - sCover) * (1 - sRun) * (1 - sJump)--smoothLerp(0,1,client.smoothAim)
	local sReload       = server.reload == 1 and smoothLerp(0, 1, client.reload ^ 1.3) or client.reload

	-- torsoLook is basically when you look up and down, how much does your torso bend to follow you. 
	-- At 0, your torso doesn't rotate up or down and its all in the neck, 
	-- at 1, your head is fixed to the top of your torso which looks up or down completely with your camera.
	client.torsoLook = lerp(0.5, 0.3, sRun)

	---RELOAD SHIZ--
	-- Reloading is complicated and poorly coded so there's not a great way to explain it. I basically have a value between 0 and 1 saying what stage of the reload you're in. Whenever the reload value passes a certain number, I trigger a sound or recoil effect, etc. At the end, the keys script resets your ammo.
	-- Server reload will be set to 1 when the player is reloading, and 0 when they are not (or slightly before the reload ends, right when your ammo is reset). 
	-- Client reload transitions from 0 to 1 or 1 to 0 depending on the server reload value. 
	-- And reloadstate is a way of saying what parts of the reload are done. So say, if the client reload value is greater than 0.1 and reloadstate is 0, play the reload sound and set reloadstate to 1 so that it doesn't do it twice
	-- and then if the reload value is 0.9 and reloadstate is 1, play the mag grabbing sound and set reloadstate to 2
	local soundHolder = self:getSoundHolder()
	if server.reload == 1 and client.reload > 0.09 and client.reloadState == 0 then
		audioEvent:Fire("Play", {soundHolder:FindFirstChild("MagOut"), false, false})
		shoot.G_Vib = 0.0035
		shoot.G_RUp = 0.05
		client.reloadState = 1
		if weapon then
			local m = getMagModel(weapon)
			if m then
				if m:IsA("Weld") then
					m = m.Part1
				end
				setModelTransparency(m, 1)
				if dist < 60 then
					--emitShell:Fire(equipment.current.."Mag", m.CFrame, (customChar.Head.CFrame*CFrame.Angles(-math.pi/2, 0, 0)).lookVector, 0.9)
				end
			end
		end
	elseif server.reload == 0 and client.reloadState == 1 then
		audioEvent:Fire("Play", {soundHolder:FindFirstChild("GrabMag"), false, false})
		client.reloadState = 2	
	elseif server.reload == 0 and sReload < 0.2 and client.reloadState == 2 then
		audioEvent:Fire("Play", {soundHolder:FindFirstChild("MagIn"), false, false})
		shoot.G_Vib = 0.01
		shoot.G_RUp = 0.09
		client.reloadState = 0
		if weapon then
			local m = getMagModel(weapon)
			if m then
				if m:IsA("Weld") then
					m = m.Part1
				end
				setModelTransparency(m, 0)
			end
		end
	end


	-- render gun animations if plr is in the range and has weapon
	-- natural/constant sway
	-- Delta isn't a part of the natural gun sway. It's applied later on because its just a simple value. The gun sway you're looking at relates to the size of the sway that's constant. If you notice, your gun is constantly moving up down and around a bit even when standing still and not looking around. That's what that sway logic is for. DeltaX/Y are not related to that kind of sway at all. Swaycount is a value that constantly counts up and is for the smooth noise function that handles how much the gun is swaying randomly, and how fast.
	local swayy = nil
	local swayx = nil
	local walky = nil
	local walkx = nil
	local vibx  = nil
	local viby  = nil
	if r_gunmove and weapon then
		shoot.swayCount = shoot.swayCount + ut/handling.swaySpeed * lerp(1, 2, sJump)
		client.sway     = handling.swaySize * smoothLerp(1, 5, sReload) * smoothLerp(smoothLerp(1, smoothLerp(1.3, 2, sReload), client.walkAmtSmooth) * lerp(1, 0.35, sAim) * lerp(1, 0.5, sStanceSmooth), 2, sJump) * (1-sRun)
		swayy           = math.noise(shoot.swayCount) * math.rad(client.sway) * (1 - client.aim)
		swayx           = math.noise(shoot.swayCount + 12.34) * math.rad(client.sway) * smoothLerp(1, 2, client.walkAmtSmooth) * lerp(1.5, 1, sAim) * (1 - client.aim)
		walkx           =math.sin(client.walkCount * math.rad(420)) * client.walkAmtSmooth * 0.01 * lerp(1, 2, math.abs(velUnit.x)) * lerp(2, 0.8, sAim) * smoothLerp(1, 2, sReload) + client.velocity.x/12 * 0.02
		walky           =math.cos(client.walkCount * math.rad(420) * 2) * client.walkAmtSmooth * 0.01 * lerp(1.8, 0.8, sAim) * smoothLerp(1, 2, sReload) * smoothLerp(1, 2, sStanceSmooth)
		vibx            = (math.random()-0.5) * shoot.Vib + math.noise(stick()/shooting.recSwaySpeed) * (shoot.Vib/shooting.recVibration) * shooting.recSwaySize * (1 - client.aim)
		viby            = (math.random()-0.5) * shoot.Vib + math.noise(stick()/shooting.recSwaySpeed + 23.123) * (shoot.Vib/shooting.recVibration) * shooting.recSwaySize * (1 - client.aim)
		--vibz = (math.random()-0.5) * shoot.Vib + math.noise(stick()/0.145 + 73.7) * (shoot.Vib/shooting.recVibration)
	end	

	-- are these all for torc0?
	local walkax          =math.cos(client.walkCount * math.rad(420)) * client.walkAmtSmooth * lerp(1, 2, math.abs(velUnit.x)) * lerp(2.6, 1, sAim) + client.velocity.x/12 * 0.8
	local walkay          =math.sin(client.walkCount * math.rad(420) * 2) * client.walkAmtSmooth * lerp(2.3, 1, sAim)	
	local walktiltsd      = -walkax * math.rad(lerp(1.3, 4, sRun)) * 0.3 - math.sin(walk.cycle * math.pi * 2) * math.rad(lerp(2, 10, sRun)) * walk.sPercent + ((r_gunmove and weapon) and swayy or 0)
	local walktiltfwd     = -walkay * math.rad(lerp(1.2, 3, sRun))  +  math.sin(stick()/1.8 * math.pi) * math.rad(smoothLerp(5, 2, sAim)) + ((r_gunmove and weapon) and swayx or 0)
	local wcycleside      = math.sin(-walk.cycle * math.pi * 2) * lerp(0.1, 0.15, sRun) * walk.sPercent
	local wcycleup        = (math.cos(walk.cycle * math.pi * 4) + 1)/2 * lerp(0.15, 0.2, sRun) * walk.sPercent
	local walkSideTilt    = math.abs(client.velocity.x/16)^0.9 * math.sign(client.velocity.x) * math.rad(15)
	client.smoothSideTilt = lerp(client.smoothSideTilt, walkSideTilt, clamp(ut/0.1, 0, 1))
	
	-- wtf head tilts?? and lean?
	local headtilt    = -math.rad(toolStance.tiltHead) * sAim-- * (1-sCover)	
	local leanamt     = math.rad(client.leanSmooth * 30)-client.smoothSideTilt
	local tiltfwd     = -lerp(math.rad(toolStance.tiltFwd), math.rad(toolStance.tiltFwd_Aim), client.smoothAim) - math.rad(lerp(10, -2, sStanceSmooth)) * sRun - math.rad(25) * (sStanceSmooth^0.8)-client.walkAmtSmooth * math.rad(5) * weightMult-walktiltfwd * 0.2
	local tortiltarms = -(lerp(sGunReady * math.rad(toolStance.tiltSide), math.rad(toolStance.tiltSide_Aim), client.smoothAim)-math.rad(5) * (sStanceSmooth^0.8)) * (1-sRun)
	local tiltsd      = tortiltarms-walktiltsd
	local torc0
	if self.isLocal then
		torc0 = char.HumanoidRootPart.CFrame:toObjectSpace(CFrame.new(char.HumanoidRootPart.CFrame.p) * CFrame.Angles(0, math.rad(client.angleY), 0))
	else
		torc0 = CFrame.new(client.position) * CFrame.Angles(0, math.rad(client.angleY), 0)
	end
	torc0 = torc0 * CFrame.new(-1 * leanamt  +  wcycleside, wcycleup-1.2 * lerp(1, 0.8, sRun)-math.abs(client.leanSmooth) * 0.25 * (1-sStanceSmooth)-0.7 * (sStanceSmooth * (1/0.8)) + smoothLerp(0.1, 0.6, sStanceSmooth) * client.walkAmtSmooth^0.5 + smoothLerp(0.05, 0.25, sStanceSmooth) * client.smoothAim, 0) * CFrame.Angles(math.rad(client.angleX) * client.torsoLook + tiltfwd, 0, leanamt) * CFrame.Angles(0, tiltsd, 0)	
	
	-- adjust the torso position
	if self.isLocal then
		customTorso.Torso.C0 = secureC0("Torso", torc0, customTorso.Torso)
		--checkC0(customTorso.Torso)
	else
		customTorso.CFrame = torc0 * CFrame.new(0, 1, 0)
	end
	
	local ttilt = CFrame.Angles(-walktiltfwd * lerp(0.07, 0.2, sAim), -tiltsd-walktiltsd * lerp(0.05, 0.3, sAim), -leanamt-walktiltsd * 0.01)

	-- adjust the head position
	customTorso.Head.C0 = secureC0("Head", characterWelds.Head[3] * ttilt * CFrame.fromEulerAnglesYXZ(math.rad(client.angleX) * (1-client.torsoLook)-tiltfwd+math.rad(client.freeX * client.freeP), math.rad(client.freeY * client.freeP), leanamt+headtilt), customTorso.Head)
	--checkC0(customTorso.Head)

	-- foot ik
	if r_dolegs then
		local ground = client.position - Vector3.new(0, 3 - walktiltsd * 0, 0)

		local gwangle = 0
		if (client.velocity * Vector3.new(1, 0, 1)).magnitude > 0.1 then
			gwangle = -math.atan2(client.velocity.unit.x, -client.velocity.unit.z)
		end
		walk.legAngle = math.rad(mathMd.lerpAngle(math.deg(walk.legAngle), math.deg(gwangle), clamp(ut / 0.125, 0, 1)))
		local wangle  = walk.legAngle

		local lfwalkup   = (clamp(math.sin(-walk.cycle * math.pi * 2), 0, 1) + 0.3 * 0) * walk.sPercent * lerp(0.2, 0.3, sRun)
		local lfwalkfwd  = (math.cos(-walk.cycle * math.pi * 2)) * walk.sPercent * lerp(0.6, 0.8, sRun)
		local loffset    = lerp(-0.65, 0, sRun) * walk.sPercent
		local rfwalkup   = (clamp(math.sin(-walk.cycle * math.pi * 2 + math.pi), 0, 1) + 0.3 * 0) * walk.sPercent * lerp(0.2, 0.3, sRun)
		local rfwalkfwd  = (math.cos(-walk.cycle * math.pi * 2 + math.pi)) * walk.sPercent * lerp(0.6, 0.8, sRun)
		local roffset    = lerp(0.5, 0, sRun) * walk.sPercent
		
		local hoffset    = math.rad(client.lHipAngle - client.angleY)
		local offset     = characterWelds["LeftLeg"][3] * CFrame.fromEulerAnglesYXZ(0, -tiltsd, -leanamt) * CFrame.Angles(-math.rad(client.angleX) * client.torsoLook - tiltfwd, 0, 0) * CFrame.Angles(0, hoffset, 0)
		local lsp        = customTorso.CFrame * offset
		local relp       = lsp:pointToObjectSpace(ground)
		relp             = Vector3.new(0, lerp(0.6, 1, sStanceSmooth) * (1 - sRun), relp.y) + Vector3.new(clamp(-1 * client.leanSmooth, 0, 9999), 0, 0) + Vector3.new(0, loffset, 0) + CFrame.fromEulerAnglesXYZ(0, 0, -wangle) * Vector3.new(0, lfwalkfwd, lfwalkup)
		local cf, a1, a2 = mathMd.IK(Vector3.new(), relp, 1, 1)
		local sstepa     = math.atan2(relp.unit.x, -relp.unit.z)
		local sstepf     = math.asin(relp.unit.y)

		-- adjust left leg position
		customTorso.LeftLeg.C0  = secureC0("LeftLeg", offset * CFrame.Angles(0, 0, -sstepa) * CFrame.fromEulerAnglesYXZ(-a1 + sstepf, math.rad(10) * (1 - sRun), 0), customTorso.LeftLeg)
		customTorso.LeftShin.C0 = secureC0("LeftShin", characterWelds["LeftShin"][3] * CFrame.Angles(-a2, 0, 0), customTorso.LeftShin)
		--checkC0(customTorso.LeftLeg)
		--checkC0(customTorso.LeftShin)

		hoffset    = math.rad(client.rHipAngle - client.angleY)
		offset     = characterWelds["RightLeg"][3] * CFrame.fromEulerAnglesYXZ(0, -tiltsd, -leanamt) * CFrame.Angles(-math.rad(client.angleX) * client.torsoLook - tiltfwd, 0, 0) * CFrame.Angles(0, hoffset, 0)
		lsp        = customTorso.CFrame * offset
		relp       = lsp:pointToObjectSpace(ground)
		relp       = Vector3.new(-lerp(0.4, lerp(0.5, -0.5, -clamp(client.leanSmooth, -99999, 0)), sStanceSmooth) * (1 - sRun), 0, relp.y) + Vector3.new(clamp(-1 * client.leanSmooth, -99999, 0), 0, 0) + CFrame.fromEulerAnglesXYZ(0, 0, -math.rad(40) * (1 - sRun)) * Vector3.new(0, roffset, 0) + CFrame.fromEulerAnglesXYZ(0, 0, -math.rad(40) * (1 - sRun) - wangle) * Vector3.new(0, rfwalkfwd, rfwalkup)
		cf, a1, a2 = mathMd.IK(Vector3.new(), relp, 1, 1)
		sstepa     = math.atan2(relp.unit.x, -relp.unit.z)
		sstepf     = math.asin(relp.unit.y)

		-- adjust the right leg position
		customTorso.RightLeg.C0 = secureC0("RightLeg", offset * CFrame.Angles(0, 0, -sstepa) * CFrame.fromEulerAnglesYXZ(-a1 + sstepf, -math.rad(40) * (1 - sRun), 0), customTorso.RightLeg)
		customTorso.RightShin.C0 = secureC0("RightShin", characterWelds["RightShin"][3] * CFrame.Angles(-a2, 0, 0), customTorso.RightShin)
		--checkC0(customTorso.RightLeg)
		--checkC0(customTorso.RightShin)
	end

	-- gun animations
	local finalcf
	if weapon and r_dogun then
		local camoffset = (-0.4 + (client.angleX / 85) * 0.03 - 0.1 * sStanceSmooth * lerp(1, 0.5, sAim)) * 0
		local finalcf   = CFrame.new(-client.walkAmtSmooth * 0.02 * (1 - sAim) * (1 - sRun) - client.smoothSideTilt * 0.4 * handling.strafeSideMult * (1 - sAim) * (1 - sRun) * client.walkAmtSmooth ^ 0.4, -client.walkAmtSmooth * 0.15 * (1 - sAim) * (1 - sRun) * handling.walkLowerMult, 0) * CFrame.fromEulerAnglesYXZ(-sJump * math.rad(8), sJump * math.rad(3), sJump * math.rad(8))--CFrame.new(0,0,server.cover)
		if r_dorec and r_gunmove then
			local pulldown  = (shoot.RUp / shooting.recKickUp) * shooting.recPullUp
			local swaynwalk = CFrame.fromEulerAnglesYXZ(swayx + walkay * math.rad(0.8) + vibx * shooting.recVibMultiplier.x + shoot.RUp, swayy - walkax * math.rad(0.8) + viby * shooting.recVibMultiplier.y, 0)
			
			if isWatched and weapon:FindFirstChild("Hold_Default") then -- y0rkl1u
				swaynwalk = weapon.Hold_Default.Cam_Aim.C0 * CFrame.new(0, 0, camoffset) * swaynwalk * ((weapon.Hold_Default.Cam_Aim.C0 * CFrame.new(0, 0, camoffset)):inverse())
			end
			
			finalcf = finalcf * swaynwalk * CFrame.new(-walkx * lerp(1, 4, sRun), 0, 0) * CFrame.new(walkx * 0.5 * lerp(1, 2, sRun) + vibx * 0.2, walky * 0.5 * lerp(1, 2, sRun) + viby * 0.2 + pulldown, shoot.RBack)
			if isWatched then
				finalcf = CFrame.new(0, 0, -1) * CFrame.fromEulerAnglesYXZ(math.rad(client.sDeltaX), math.rad(client.sDeltaY), 0) * CFrame.new(0, 0, 1) * finalcf
			end

			local shotTime = (stick() - shoot.lastShot)
			local bblength = (1 / (shooting.rpm / 60)) * 0.8
			local bbP      = math.sin(clamp(shotTime / bblength, 0, 1) * math.pi)
			
			-- adjust the cframe of the gun here
			if weapon:FindFirstChild("Hold_Default") then -- y0rkl1u
				weapon.Hold_Default.Slide.C0 = weapon.Hold_Default.Slide.DefaultCF.Value - Vector3.new(0, 0, -bbP * shooting.slideAmount)
				--checkC0(weapon.Hold_Default.Slide)
			end
		elseif r_dorec then
			finalcf = finalcf * CFrame.new(0, 0, shoot.RBack)
		end
		if weapon:FindFirstChild("Hold_Default") then
			if sAim > 0.001 and sAim < 0.999 and sCover < 0.999 and r_doaimtrans then
				finalcf = finalcf * CFrame.new():lerp(weapon.Hold_Default.Hold_Aim.C0:inverse(), sAim)
				if r_doaimdet then
					local aimrot = math.sin(sAim * math.pi)
					finalcf      = finalcf * CFrame.Angles(-aimrot * math.rad(4), 0, aimrot * math.rad(4))
				end
			elseif sAim >= 0.999 and sCover < 0.999 then
				finalcf = finalcf * weapon.Hold_Default.Hold_Aim.C0:inverse()
			end
			if sRun > 0.001 and sRun < 0.999 and sCover < 0.999 then
				local runtr  = weapon.Hold_Default.Hold_Run.C0:lerp(weapon.Hold_Default.Hold_CrouchRun.C0, sStanceSmooth)
				local offset = CFrame.new():lerp(customChar.Head.CFrame:toObjectSpace(customTorso.CFrame), sRun)
				finalcf      = offset * finalcf * CFrame.new():lerp(runtr:inverse(), sRun)
			elseif sRun >= 0.999 and sCover < 0.999 then
				local runtr  = weapon.Hold_Default.Hold_Run.C0:lerp(weapon.Hold_Default.Hold_CrouchRun.C0, sStanceSmooth)
				local offset = customChar.Head.CFrame:toObjectSpace(customTorso.CFrame)
				finalcf      = offset * finalcf * runtr:inverse()
			end
			if sCover > 0.001 and sCover < 0.999 then
				local runtr  = weapon.Hold_Default.Hold_Cover.C0
				local offset = CFrame.new():lerp(customChar.Head.CFrame:toObjectSpace(customTorso.CFrame), sCover)
				finalcf      = offset * finalcf * CFrame.new():lerp(runtr:inverse(), sCover)
			elseif sCover >= 0.999 then
				local runtr  = weapon.Hold_Default.Hold_Cover.C0
				local offset = customChar.Head.CFrame:toObjectSpace(customTorso.CFrame)
				finalcf      = offset * finalcf * runtr:inverse()
			end
		end

		local AP = (client.angleX) / 85
		local APP = (AP < 0 and - 1 or 1)
		AP = ((AP ^ 2) ^ 0.7) * APP

		if math.abs(headtilt) > 0.001 then
			finalcf = CFrame.Angles(0, 0, -headtilt) * finalcf
		end
		local torsoLockPerc = 1 - (1 - sRun) * (1 - sCover)
		local normallheadcf = customTorso.CFrame * characterWelds["Head"][3] * CFrame.Angles(-walktiltfwd * lerp(0.07, 0.2, sAim), -tiltsd - walktiltsd * lerp(0.05, 0.3, sAim), -leanamt - walktiltsd * 0.01) * CFrame.fromEulerAnglesYXZ(math.rad(client.angleX) * (1 - client.torsoLook) - tiltfwd, 0, leanamt + headtilt) * (characterWelds["Head"][4]:inverse())
		local headoffset = customChar.Head.CFrame:toObjectSpace(normallheadcf):lerp(CFrame.new(), torsoLockPerc)

		local blockoffset = 0
		if isWatched then
			local joltheadcf = customTorso.CFrame * characterWelds["Head"][3] * CFrame.Angles(-walktiltfwd * 0.07, -tiltsd - walktiltsd * 0.05, -leanamt - walktiltsd * 0.01) * CFrame.fromEulerAnglesYXZ(math.rad(client.angleX) * (1 - client.torsoLook) - tiltfwd, 0, leanamt +- math.rad(toolStance.tiltHead) * client.smoothAim) * (characterWelds["Head"][4]:inverse())
			if weapon:FindFirstChild("Hold_Default") then
				local bp   = joltheadcf * (weapon.Hold_Default.Fire.C0)
				local hp   = joltheadcf.p
				local ap   = joltheadcf * (weapon.Hold_Default.Cam_Aim.C0.p)
				local hprl = bp:pointToObjectSpace(hp)
				local hpcf = bp * Vector3.new(0, 0, hprl.z)
				local apcf = bp * (bp:pointToObjectSpace(ap) * Vector3.new(1, 1, 0) + Vector3.new(0, 0, hprl.z))
				local rpos = hpcf:lerp(apcf, server.aim)
				
				-- cover detection!!
				local ray = Ray.new(rpos, bp.lookVector * (math.abs(hprl.z) - 0.4))
				local hit, position = workspace:FindPartOnRayWithIgnoreList(ray, self.rayIgnoreWithChar)
				if hit then
					if server.cover ~= 1 then
						server.cover = 1
						-- mainRemote:FireServer("setLocalValue::/")
						mainRemote:FireServer("setLocalValue", {"server.cover", 1})
					end
					--end
				else
					if server.cover ~= 0 then
						server.cover = 0
						mainRemote:FireServer("setLocalValue", {"server.cover", 0})
					end
				end
			end
		end
		local sidetilt = smoothLerp(0, 1, math.sin(mathMd.percentBetween(sReload, 0, 1) ^ 0.3 * math.pi)) * math.rad(15) * (1 - sAim * 0.7) * server.reload
		local uptilt   = smoothLerp(0, 1, math.sin(mathMd.percentBetween(sReload, 0, 1) * math.pi)) * math.rad(10) * (1 - sAim * 0.7) * server.reload
		finalcf        = CFrame.Angles(uptilt, 0, sidetilt) * finalcf

		if weapon then
			if weapon:FindFirstChild("Hold_Default") then -- added by y0rkl1u
				weapon.Hold_Default.Main.C0 = headoffset * CFrame.new(0, 0, blockoffset) * finalcf
				--checkC0(weapon.Hold_Default.Main)
			end

			if weapon:FindFirstChild("Fire") then -- added by y0rkl1u
				weapon.Fire.Effects.PointLight.Brightness = (shoot.G_RBack / 0.1) ^ 4 * 3
			end
			if r_dolegs then
				local ba = CFrame.new(0, 0, (1 - ((client.angleX) / 85 + 1) / 2) * 0.6 * (isWatched and torsoLockPerc or 1))
				local wepcf, lsp, relp
				
				if isWatched then
					wepcf = (customChar.Head.CFrame * headoffset * finalcf):lerp(customTorso.CFrame, torsoLockPerc)
					lsp = wepcf * (characterWelds["Head"][4] * (characterWelds["Head"][3]:inverse())):lerp(CFrame.new(), torsoLockPerc) * CFrame.fromEulerAnglesYXZ(tiltfwd * (1 - torsoLockPerc), tortiltarms * (1 - torsoLockPerc), 0) * ba * characterWelds["LeftArm"][3] * CFrame.new(0.2, -0.3, 0) * CFrame.Angles(-tiltfwd * (1 - torsoLockPerc), -tortiltarms * (1 - torsoLockPerc), 0)
				else
					lsp = customChar.Head.CFrame - customChar.Head.Position + (customTorso.CFrame * ba * characterWelds["LeftArm"][3] * Vector3.new(0, 0, -0.3))
				end
				if weapon:FindFirstChild("Left_Grip") then -- added by y0rkl1u
					relp = lsp:pointToObjectSpace(weapon.Left_Grip.Position)
	
					local reloadp    = lsp:pointToObjectSpace(customTorso.CFrame * Vector3.new(0.5, -0.5, -1.3))
					local reloadoff  = smoothLerp(0, 1, math.sin(sReload ^ 0.5 * math.pi))
					local cf, a1, a2 = mathMd.IK(Vector3.new(), relp:Lerp(reloadp, sReload) * 0.8 + Vector3.new(-reloadoff * 0.7, reloadoff * 0.3, -reloadoff * 0.4) * (server.reload), 0.9, 1)
	
					-- left arms
					customTorso.LeftArm.C0     = secureC0("LeftArm", customTorso.CFrame:toObjectSpace(lsp) * cf * CFrame.new(0, 0, -relp.magnitude * 0.2) * CFrame.Angles(0, 0, -headtilt * (isWatched and 0 or 1) - sReload * math.pi * 0.3 * (server.reload)) * CFrame.Angles(math.pi / 2 + a1, 0, 0), customTorso.LeftArm)
					customTorso.LeftForearm.C0 = secureC0("LeftForearm", characterWelds["LeftForearm"][3] * CFrame.Angles(a2, 0, 0), customTorso.LeftForearm)
					--checkC0(customTorso.LeftForearm)
					--checkC0(customTorso.LeftArm)
				end
				
				if isWatched then
					lsp = wepcf * (characterWelds["Head"][4] * (characterWelds["Head"][3]:inverse())):lerp(CFrame.new(), torsoLockPerc) * CFrame.fromEulerAnglesYXZ(tiltfwd * (1 - torsoLockPerc), tortiltarms * (1 - torsoLockPerc), 0) * ba * characterWelds["RightArm"][3] * CFrame.Angles(-tiltfwd * (1 - torsoLockPerc), -tortiltarms * (1 - torsoLockPerc), 0)
				else
					lsp = customChar.Head.CFrame - customChar.Head.Position + (customTorso.CFrame * ba * characterWelds["RightArm"][3] * Vector3.new(0, 0, -0.25))
				end
				if weapon:FindFirstChild("Right_Grip") then -- added by y0rkl1u
					relp = lsp:pointToObjectSpace(weapon.Right_Grip.Position)
					local cf, a1, a2 = mathMd.IK(Vector3.new(), relp * 0.8, 0.9, 1)

					-- right arms
					customTorso.RightArm.C0     = secureC0("RightArm", customTorso.CFrame:toObjectSpace(lsp) * cf * CFrame.new(0, 0, -relp.magnitude * 0.2) * CFrame.Angles(0, 0, -headtilt * (isWatched and 0 or 1)) * CFrame.Angles(math.pi / 2 + a1, 0, 0), customTorso.RightArm)
					customTorso.RightForearm.C0 = secureC0("RightForearm", characterWelds["RightForearm"][3] * CFrame.Angles(a2, 0, 0), customTorso.RightForearm)
					--checkC0(customTorso.RightArm, customTorso.RightForearm)
				end
				
			else
				customTorso.RightArm.C0 = secureC0("RightArm", characterWelds["RightArm"][3] * CFrame.Angles(math.rad(client.angleX) * (1 - client.torsoLook) - tiltfwd, 0, 0), customTorso.RightArm)
				customTorso.LeftArm.C0  = secureC0("LeftArm", characterWelds["LeftArm"][3] * CFrame.Angles(math.rad(client.angleX) * (1 - client.torsoLook) - tiltfwd, 0, 0), customTorso.LeftArm)
				--checkC0(customTorso.RightArm)
				--checkC0(customTorso.LeftArm)
			end
		end
	end

	if math.abs(client.lHipAngle - client.lastStepAngle) > 65 then
		client.lastStepAngle = client.lHipAngle
		-- LastStepAngle is the last angle your hip was at.
		-- It's for the previously mentioned feature where your legs don't rotate with the camera till you turn a certain amount, 
		-- and when your legs do turn with you it plays a footstep sound.
	end

	self:audioUpdate()
	
	-- update step sounds
	if walk.stepDist > 5 then
		walk.stepDist = walk.stepDist - 5
	end
end

-- for the sound
local materialSound = {}
materialSound.Carpet       = "Carpet"
materialSound.Wood         = "Wood"
materialSound.Grass        = "Snow"
materialSound.WoodPlanks   = "Wood"
materialSound.Tile         = "Stone"
materialSound.Metal        = "Metal"
materialSound.DiamondPlate = "Metal"
materialSound.Concrete     = "Stone"
materialSound.Dirt         = "Dirt"
materialSound.Water        = "Water"

function AnimatedPlayer:audioUpdate()

	-- optmization here
	local soundHolder = self:getSoundHolder()
	local dist        = self:distToCam()
	local isWatched   = self.isLocal or self.isWatched
	local client      = self.client
	local server      = self.server
	local walk        = self.walk

	-- breath
	-- only play sounds for the player within 100 studs
	if dist < 100 then
		for i, v in ipairs(script.PlayerAudio:GetChildren()) do
			local s = soundHolder[v.Name]
			if s.Name:find("Breath_") then
				local isactive = s.Name == "Breath_"..self.scared
				if s.SoundStats:IsA("Folder") then
					s.SoundStats.Volume.Value = lerpTowards(s.SoundStats.Volume.Value, isactive and s.MainVolume.Value or 0, self.rendering.updateTime / (isactive and 0.3 or 0.25))
					s.SoundStats.Pitch.Value = isWatched and 0.95 or 1
				end
			end
		end
	end

	-- Basically, AimLast is whatever value Aim.Value was the previous time the character was updated. I use it to detect whenever Aim.Value has changed so I know to play the sound for aiming in with your gun or aiming out (same sound right now)
	if client.aimLast ~= server.aim then
		client.aimLast = server.aim
		audioEvent:Fire("Play", {soundHolder:FindFirstChild("Aim_In"), false, false})
	end

	-- step sounds, depending on the floor type
	-- dunno
	if (walk.stepDist > 5 or math.abs(client.lHipAngle - client.lastStepAngle) * (client.walkAmtSmooth > 0.05 and 0 or 1) > 65) and dist < 160 then
		
		-- raycasting downwards
		local ray = Ray.new(client.position, Vector3.new(0, -5, 0))
		local hit, position, _, mat = workspace:FindPartOnRayWithIgnoreList(ray, rayIgnoreWithAllChar)
		if hit then
			local material = materialSound[mat.Name]
			if material == nil then
				material = materialSound["Concrete"]
			end
			-- volumn based on the weight
			local weightMult = lerp(1, 0.7, (self.equipment.weight / 25) ^ 0.5)
			local worr = client.run > 0.5 and "/Run_" or "/Walk_"
			local s = soundHolder[material..(worr)..math.random(1, 5)]
			local scrollspeed = mathMd.percentBetween((client.velocity * Vector3.new(1, 0, 1)).magnitude / weightMult, 6, 12)

			audioEvent:Fire("Play", {s, false, true})
			-- fuck he fucking sets it here
			if s:FindFirstChild("SoundStats") and s.SoundStats.ClassName == "Folder" then	
				s.SoundStats.Volume.Value = lerp(lerp(0.4, 0.8, scrollspeed), 1.4, client.run)
				s.SoundStats.Range.Value = lerp(lerp(50, 70, scrollspeed), 120, client.run)
			end
		end
	end
end

-- rendering distances: an optimization based on dist to cam
local renderingRanges = {
	[1] = {framerate = 1 / 60, dist = 40},
	[2] = {framerate = 1 / 45, dist = 100},
	[3] = {framerate = 1 / 30, dist = 200},
	[4] = {framerate = 1 / 15, dist = 250},
	[5] = {framerate = 1 / 10, dist = 400}
}

-- main function for rendering
function AnimatedPlayer:main()
	if self.isLocal then  		-- for the local player
		spawn(function()
			while self.isAlive do
				game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.LockCenter
				rs:wait()
				self:renderUpdate()
				if self.isWatched then
					cameraMd.rsUpdate()
				end
			end
		end)
		spawn(function()
			while self.isAlive do
				hb:wait()
				if self.isWatched then
					cameraMd.hbUpdate()
				end
			end
		end)
	else 											-- for rendering others
		spawn(function()
			while self.isAlive do
				hb:wait()

				if self.isWatched then
					cameraMd.hbUpdate()
				end

				local now = stick()
				local gap = now - self.rendering.lastUpdate
				local currRange = self.rendering.range
				
				-- render the next frame based on framerate specified for this range
				if gap > renderingRanges[currRange].framerate then
					self.lastUpdate = now
					local distToCam = self:distToCam()
					local posWrtCam = cam.CFrame:pointToObjectSpace(self.server.position)
					self:renderUpdate()

					if self.isWatched then
						cameraMd.rsUpdate()
					end
				
					-- update range based on dist to cam
					if currRange < #renderingRanges and (distToCam > renderingRanges[currRange].dist or posWrtCam.z > 10) then
						self.rendering.range = currRange + 1
					elseif currRange > 1 and distToCam <= renderingRanges[currRange - 1].dist
						and (distToCam > renderingRanges[currRange].dist or posWrtCam.z <= 10) then
						self.rendering.range = currRange - 1
					end
				end
			end
		end)		
	end
			

	-- spawn(function()
	-- 	while self.isAlive do
	-- 		if self.isLocal then
	-- 			rs:wait()
	-- 			self:renderUpdate()
	-- 			cameraMd.rsUpdate()
	-- 		else
	-- 			hb:wait()
	-- 			local now = stick()
	-- 			local gap = now - self.rendering.lastUpdate
	-- 			local currRange = self.rendering.range
	
	-- 			-- render the next frame based on framerate specified for this range
	-- 			if gap > renderingRanges[currRange].framerate then
	-- 				self.lastUpdate = now
	-- 				local distToCam = self:distToCam()
	-- 				local posWrtCam = cam.CFrame:pointToObjectSpace(self.server.position)
	-- 				self:renderUpdate()
	
	-- 				-- update range based on dist to cam
	-- 				if currRange < #renderingRanges and (distToCam > renderingRanges[currRange].dist or posWrtCam.z > 10) then
	-- 					self.rendering.range = currRange + 1
	-- 				elseif currRange > 1 and distToCam <= renderingRanges[currRange - 1].dist
	-- 					and (distToCam > renderingRanges[currRange].dist or posWrtCam.z <= 10) then
	-- 					self.rendering.range = currRange - 1
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- end)
end

-- TODO: combine them together into a reset()   (in server side too)
-- PRE: alive
function AnimatedPlayer:resetAmmo()
	for gearType, attcData in pairs(Data.plrData[self.name]) do
		local gearName = attcData.name
		self.equipment.ammo[gearName.."_Mag"] = self.savedStats[gearName].resources.magSize
	end
end
function AnimatedPlayer:resetHealth()
	self.health = 100
end

return AnimatedPlayer
