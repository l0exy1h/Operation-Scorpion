local md = {}

-- defs
local uis = game:GetService("UserInputService")
local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local mathMd = require(gm:WaitForChild("Mathf"))
	local lerp = mathMd.lerp
	local clamp = mathMd.clamp
-- local apple = require(gm:WaitForChild("Apple"))
-- 	local fireServer = apple.fireServer
local remote = rep:WaitForChild("Events"):WaitForChild("MainRemote")

local rs = game:GetService("RunService").RenderStepped
local hb = game:GetService("RunService").Heartbeat

-- vars
local self        = nil
local connections = {}
local lastShot    = tick()
local clicking    = false
local lock        = true

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

local function moveMouse(input)
	-- for optimization
	local client = self.client
	local server = self.server

	-- reduce cam movement when ADS
	local fovMultReciprocal = 1 / self.equipment.stats.handling.aimFOVMult
	local deltaX = -input.Delta.y * 0.3 * lerp(1, fovMultReciprocal, client.aim)
	local deltaY = -input.Delta.x * 0.2 * lerp(1, fovMultReciprocal, client.aim)

	if server.freeP < 1 then
		-- freelook is disabled or in the process of being disabled
		server.angleX = clamp(server.angleX + deltaX, -85, 85)
		server.angleY = server.angleY + deltaY
		-- todo: change the frequency here?
		-- issue: if you move the mouse and its been less than .1 seconds and then you stop moving it, it wont get sent
		remote:FireServer("setLocalValue", {"server.angleX", server.angleX})
		remote:FireServer("setLocalValue", {"server.angleY", server.angleY})

		-- client deltax/y is for gunsways
		-- playeranimation will automatically transition them back to 0 over time
		local ac = lerp(7, 3, client.aim)
		client.deltaX = clamp(client.deltaX + deltaX * 0.1, -ac, ac)
		client.deltaY = clamp(client.deltaY + deltaY * 0.1, -ac, ac)
	else
		-- freelook
		local gFreeX = server.freeX + deltaX
		local gFreeY = server.freeY + deltaY
		local angle = Vector2.new(gFreeX / 45, gFreeY / 90)
		if angle.Magnitude > 1 then
			angle = angle.unit
		end
		angle = angle * Vector2.new(45, 90)
		server.freeX = clamp(angle.x + server.angleX, -85, 85) - server.angleX--clamp(angle.x,-70,90)
		server.freeY = angle.y --clamp(angle.x,-70,90)
		remote:FireServer("setLocalValue", {"server.freeX", server.freeX})
		remote:FireServer("setLocalValue", {"server.freeY", server.freeY})
	end
end

-- update self.shoot.shoot if the player is able to shoot
local function shoot()
	if lock then return end

	-- todo: check all optimizational references
	clickin         = true
	local client    = self.client
	local server    = self.server
	local equipment = self.equipment
	local ammo      = equipment.ammo
	local shooting  = equipment.stats.shooting
	local gunName   = equipment.current

	-- rps times a duration stands for the #rounds the gun can fire in that duration
	local rps            = (shooting.rpm / 60)		-- rounds per sec here
	local bulletN        = clamp((tick() - lastShot) * rps, 0, 1)
	local magString      = gunName.."_Mag"
	local bulletPerClick = shooting.automatic and 99999 or 1

	--[[ 3 different constraints for shooting
	local firable = bulletN >= 1 			-- rpm constraint
		and bulletPerClick >= 1 				-- automatic constraint
		and ammo[magString] >= 1				-- ammo constraint
	--]]

	spawn(function()
		while clickin == true and bulletPerClick >= 1 and ammo[magString] >= 1 do -- only consider the automatic constraint and ammo constraint here
			if self.equipment.current ~= gunName then 
				break
			end	
			-- cannot shoot if covering or running
			-- Cover is 1 if your gun is blocked by a wall, and 0 otherwise.
			if server.cover < 0.05 and server.run < 0.05 then
	
				if bulletN >= 1 then 		-- consider the rpm constraint here
					lastShot         = tick()
					bulletN          = bulletN - 1
					bulletPerClick   = bulletPerClick - 1
					ammo[magString]  = ammo[magString] - 1
					
					self.shoot.shoot = true
					remote:FireServer("setLocalValue", {"shoot.shoot", true})
				end
	
				-- update the #bullet
				local lu = tick()
				hb:wait()
				local ut = tick() - lu
				bulletN = clamp(bulletN + ut * rps, 0, ammo[magString])
			else
				hb:wait()
			end
		end
	end)
end

local function setupMouseListeners()

	-- optimizations here
	local m = self.plr:GetMouse()
	local server = self.server
	local client = self.client
	local equipment = self.equipment

	-- mouse movements
	connections[#connections + 1] = uis.InputChanged:connect(moveMouse)

	-- right mouse button pressesd
	connections[#connections + 1] = m.Button2Down:connect(function()
		server.aim = 1
		remote:FireServer("setLocalValue", {"server.aim", server.aim})
	end)

	-- right mouse button released
	connections[#connections + 1] = m.Button2Up:connect(function()
		server.aim = 0
		remote:FireServer("setLocalValue", {"server.aim", server.aim})
	end)

	-- left mouse button pressed
	connections[#connections + 1] = m.Button1Down:connect(shoot)

	-- left mouse button released
	connections[#connections + 1] = m.Button1Up:connect(function()
		clickin = false
	end)

	-- mousewheels
	connections[#connections + 1] = m.WheelForward:connect(function()
		local scroll = client.scroll + 4/12
		if scroll > 1 then
			scroll = 1
		end
		client.scroll = scroll
	end)
	connections[#connections + 1] = m.WheelBackward:connect(function()
		local scroll = client.scroll - 4/12
		if scroll < -1 then
			scroll = -1
		end
		client.scroll = scroll
	end)
end

function md.connect(_aplr)
	md.disconnect()
	self = _aplr

	lastShot    = tick()
	clicking    = false

	setupMouseListeners()
end

return md
