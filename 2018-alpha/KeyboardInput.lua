local md = {}

-- defs
local plrs = game.Players
local lp = plrs.LocalPlayer
local uis = game:GetService("UserInputService")
local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local mathMd = require(gm:WaitForChild("Mathf"))
	local lerp = mathMd.lerp
	local clamp = mathMd.clamp
-- local apple = require(gm:WaitForChild("Apple"))
-- 	local fireServer = apple.fireServer
local rs = game:GetService("RunService").RenderStepped
local hb = game:GetService("RunService").Heartbeat
local abs = math.abs
local inStudio = game.CreatorId == 0
local remote = rep:WaitForChild("Events"):WaitForChild("MainRemote")

-- vars
local self = nil
local connections = {}
local keys = nil 				-- for movement
local run = false
local lock = true

remote.OnClientEvent:connect(function(func, args)
	if func == "lock" then
		lock = true		
	elseif func == "unlock" then
		lock = false
	end
end)

function md.disconnect()
	for _, connection in ipairs(connections) do
		connection:disconnect()
	end
	self = nil
end

local function getSpeed()
	local client = self.client
	local walkspeed = (8 + 2 * client.scroll) * lerp(1, 0.7, abs(client.lean)) * lerp(1, 0.6, client.stance)
	local runspeed = 14 * lerp(1, 0.85, abs(client.lean)) * lerp(1, 0.6, client.stance)
	return lerp(walkspeed, runspeed, client.run) * self.equipment.stats.handling.walkSpeedMult
end 

local function handleMovement()

	-- for optimization
	local server = self.server
	local char = self.plr.Character

	-- disable default movement
	char.Humanoid.WalkSpeed = 0
	-- we set the final velocity we want the character to reach based on key press
	-- and we set the accleration here
	-- LocalPlayer uses a bodymover for the x and z axis, and default humanoid behavior for the y axis.
	local bv    = Instance.new("BodyVelocity", char.HumanoidRootPart)
	bv.MaxForce = Vector3.new(100000, 0, 100000)
	bv.Velocity = Vector3.new()
	
	spawn(function()
		while rs:wait() do
			-- the velocity
			local vel = Vector3.new()
			if keys["w"][1] == true then
				vel = Vector3.new(0, 0, -1)
				-- both pressed,  s is pressed after,  then go backward
				if keys["s"][1] == true  and keys["s"][2] > keys["w"][2] then
					vel = Vector3.new(0, 0, 1)
				end
			elseif keys["s"][1] == true then
				vel = Vector3.new(0, 0, 1)
			end
			
			if keys["a"][1] == true then
				vel = vel + Vector3.new(-1, 0, 0)
				if keys["d"][1] == true  and keys["d"][2] > keys["a"][2] then
					vel = vel + Vector3.new(2, 0, 0)
				end
			elseif keys["d"][1] == true then
				vel = vel + Vector3.new(1, 0, 0)
			end
	
			-- added by y0rkl1u: disable movements in final screen
			if not lock then
				local speed = getSpeed()
				bv.Velocity = CFrame.Angles(0, math.rad(server.angleY), 0) * (vel.Magnitude < 0.01 and Vector3.new() or vel.Unit * speed)
			else
				bv.Velocity = Vector3.new()
			end
	
			-- keep the player from falling
			if char.HumanoidRootPart.Position.y < - 100 then
				char.HumanoidRootPart.CFrame = CFrame.new(0, 100, 0)
			end
	
			-- uploading the position and velocity every 0.1s
			local now = tick()
			if now - speedLu >= 0.1 then
				speedLu = now
				remote:FireServer("setLocalValue", {"server.velocity", char.HumanoidRootPart.Velocity * Vector3.new(1, 0, 1)})
				remote:FireServer("setLocalValue", {"server.position", char.HumanoidRootPart.CFrame.p})
			end
		end
	end)
end

local function setupKeyListeners()

	-- optimizations here
	local m = self.plr:GetMouse()
	local server = self.server
	local client = self.client
	local equipment = self.equipment
	local walk = self.walk

	-- handling keyboard inputs here
	-- key pressed
	connections[#connections + 1] = m.KeyDown:connect(function(key)

		-- aim key (toggle)
		-- a toggling option, so "z" doesn't require handling in the keyup setion
		if key == "z" then
			if server.aim == 0 then
				server.aim = 1
			else
				server.aim = 0
			end
			remote:FireServer("setLocalValue", {"server.aim", server.aim})
		end

		-- flashlight (toggle)
		if key == "f" then
			remote:FireServer("setValue", {"server.flashlight", not server.flashlight})
		end

		-- night vision (toggle)
		if key == "n" then
			if not lock then
				-- play the sound here?
				if server.nightVision == false then
					script.NightVision:Play()
				end
				remote:FireServer("setValue", {"server.nightVision", not server.nightVision})
			end
		end

		-- reload (toggle)
		if key == "r" then
			if client.reload < 0.01 then-- if reloading complete/no reloading
				local gunName   = equipment.current
				local handling  = equipment.stats.handling
				local resources = equipment.stats.resources
				local ammo      = equipment.ammo

				-- reload start
				server.reload = 1
				remote:FireServer("setLocalValue", {"server.reload", server.reload})
				
				-- simulate the last bullet in the gun
				ammo[gunName.."_Mag"] = math.min(ammo[gunName.."_Mag"], 1)
				
				-- wait for reload to complete
				wait(handling.reloadTime)
				
				-- reload complete
				server.reload = 0
				remote:FireServer("setLocalValue", {"server.reload", server.reload})
				
				-- add back bullet
				ammo[gunName.."_Mag"] = ammo[gunName.."_Mag"] + resources.magSize
			end
		end

		-- change gun (toggle)
		if key == "1" or key == "2" then
			equipment.goal = self.savedGearName[tonumber(key)]
			remote:FireServer("setLocalValue", {"equipment.goal", equipment.goal})			
		end

		-- lean (toggle)
		if key == "q" and run == false then
			server.lean = (server.lean == 1 and 0 or 1)
			remote:FireServer("setLocalValue", {"server.lean", server.lean})
		end
		if key == "e" and run == false then
			server.lean = (server.lean == -1 and 0 or - 1)
			remote:FireServer("setLocalValue", {"server.lean", server.lean})
		end

		-- crouch (toggle)
		if key == "c" then
			server.stance = 1 - math.floor(server.stance)
			remote:FireServer("setLocalValue", {"server.stance", server.stance})
		end

		-- suicide (toggle)
		if key == "k" and inStudio then
			--warn("attempted suicide")
			if self.health - 10 > 0 then
				self.health = self.health - 10
				self.lastDmgTick = tick()
			end
			--remote:FireServer("changeHealth", {lp.Name, -1000})
		end
		
		if key == "l" and inStudio then
			if self.health + 10 <= 100 then
				self.health = self.health + 10
			end
		end

		-- movement (hold)
		if key == "w" or key == "a" or key == "s" or key == "d" then
			keys[key] = {true, tick()}
		end

		-- left shift (hold)
		if key:byte() == 48 then
			run = true
			--mSpeed = GetSpeed()
			server.run = 1
			remote:FireServer("setLocalValue", {"server.run", server.run})
			-- running disables leaning
			server.lean = 0
			remote:FireServer("setLocalValue", {"server.lean", server.lean})
			
			walk.recover = tick()
			remote:FireServer("setLocalValue", {"walk.recover", walk.recover})
		end

		-- free look (hold)
		if key == "b" then
			if not lock then
				server.freeP = 1
				remote:FireServer("setLocalValue", {"server.freeP", server.freeP})
			end
		end

		-- disable camera
		if key == "x" then
			lp.PlayerScripts.Variables.DisableCamera.Value = not lp.PlayerScripts.Variables.DisableCamera.Value
		end
	end)

	-- key released
	connections[#connections + 1] = m.KeyUp:connect(function(key)
		-- movement (hold)
		if key == "w" or key == "a" or key == "s" or key == "d" then
			keys[key] = {false, tick()}
		end

		-- left shift (hold)
		if key:byte()==48 then
			run = false
			--script.Parent.Humanoid.WalkSpeed = GetSpeed()
			server.run = 0
			remote:FireServer("setLocalValue", {"server.run", server.run})
			walk.recover = tick()
			remote:FireServer("setLocalValue", {"walk.recover", walk.recover})
			wait(8.5)
		end

		-- free look (hold)
		if key == "b" then
			server.freeP = 0
			remote:FireServer("setLocalValue", {"server.freeP", server.freeP})
		end

	end)
end

local function enableCustomJump()
	local humanoid = self.plr.Character.Humanoid
	humanoid.FreeFalling:connect(function()
		self.server.jump = 1
		remote:FireServer("SetLocalValue", {"server.jump", 1})
	end)
	humanoid.Running:connect(function()
		self.server.jump = 0
		remote:FireServer("SetLocalValue", {"server.jump", 0})
	end)
end

function md.connect(_aplr)
	md.disconnect()
	self = _aplr

	-- init
	keys = {
		w = {false, 0},
		a = {false, 0},
		s = {false, 0},
		d = {false, 0}
	}
	self.walk.recover = tick()
	remote:FireServer("setLocalValue", {"walk.recover", self.walk.recover})
	run     = false
	speedLu = tick()
	-- lock = true
	setupKeyListeners()
	handleMovement()
	enableCustomJump()
end

return md
