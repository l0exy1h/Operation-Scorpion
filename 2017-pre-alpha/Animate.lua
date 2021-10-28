local keybinding = {
	sprint = Enum.KeyCode.LeftShift,
	pause = Enum.KeyCode.P,
	crouch = Enum.KeyCode.LeftControl,
	crouch2 = Enum.KeyCode.C,
}
local settings = {
	invertedMouse = false,
	mouseSensitivity = 10,
	holdCrouching = true,
}
local debug = {
	showLookDir = true,
	showHrpDir = true,
	walkingEnabled = true,
	sprintEnabled = false,
}

-- math and constants
-------------------------------------
local function clamp(x, l, r)
	assert(l <= r)
	local v = x < l and l or x > r and r or x
	local b = l <= x and x <= r
	return v, b
end
local sqrt = math.sqrt
local sqr = function(x)
	return x * x
end
local cos, sin = math.cos, math.sin
local asin, acos, atan2 = math.asin, math.acos, math.atan2
local function dist(u, v)
	return sqrt(sqr(u.x - v.x) + sqr(u.y - v.y) + sqr(u.z - v.z))
end
local eps = 1e-4
local pi = math.pi
local newCF = CFrame.new
local iCF = newCF()
local _anglesCF = CFrame.Angles
local deg = pi / 180
local function anglesToCf(x, y, z)
	return _anglesCF(x * deg, y * deg, z * deg)
end
local V3new = Vector3.new

local uis = game:GetService("UserInputService")
local runser = game:GetService("RunService") 
local rs = runser.RenderStepped
local hb = runser.Heartbeat
local rep = game.ReplicatedStorage
local function bindRS(funcName, priority, func) 
	runser:BindToRenderStep(funcName, 300 + priority, func)
end
local function unbindRS(funcName)
	runser:UnbindFromRenderStep(funcName)
end
local function cylToV3(y, x)
	x, y = x * deg, y * deg
	local cosx = cos(x)
	return V3new(cosx * sin(y), sin(x), cosx * cos(y))
end
local function v3ToCyl(v)
	local x, y, z = v.x, v.y, v.z
	local alpha = atan2(x, z) / deg
	if alpha < 0 then alpha = alpha + 360 end
	return alpha, asin(y / v.magnitude) / deg 
end

local lp = game.Players.LocalPlayer
repeat wait()	
until lp.Character

local char = lp.Character
local humanoid = char.Humanoid
local hrp = char.HumanoidRootPart
local function getInstantVelocityV3()
	return hrp.Velocity.magnitude
end
local function getInstantVelocityV2()
	return V3new(hrp.Velocity.x, 0, hrp.Velocity.z)
end
local function getInstantSpeedV2()
	return sqrt(sqr(hrp.Velocity.x) + sqr(hrp.Velocity.z))
end

-- initialize char & anichar table
--------------------------------

local	joints = {}
local	bodyparts = {}
local	state = {}
local	movement = {
	ceshen = 45
}
local function isBodypart(v)
	local motor6d = v:FindFirstChildWhichIsA("Motor6D")
	local bool = v:IsA("BasePart") and motor6d ~= nil
	return bool, motor6d 
end
for _, v in ipairs(char:GetChildren()) do
	local b, joint = isBodypart(v)
	if b then
		bodyparts[v.Name] = v
		joints[v.Name] = joint
	end
end


-- turning simulation
--------------------------------

do
	if debug.showHrpDir then
		hrpDirPart = Instance.new("Part", workspace)
		hrpDirPart.Name = "LookDir"
		hrpDirPart.Transparency = 0.5
		hrpDirPart.Shape = "Ball"
		hrpDirPart.Size = V3new(1, 1, 1)
		hrpDirPart.Anchored = true
		hrpDirPart.CanCollide = false
		hrpDirPart.BrickColor = BrickColor.Black()
	end
	function showHrpDirRsStep()
		if debug.showHrpDir then
			hrpDirPart.Position = hrp.Position + hrp.CFrame.lookVector * 3
		end
	end

	-- read from mouse input
	rmbHold = false
	mouseLocked = false
	function setMouseLocked(bool)
		uis.MouseBehavior = bool 
			and Enum.MouseBehavior.LockCenter 
			or rmbHold 
				and Enum.MouseBehavior.LockCurrentPosition 
				or Enum.MouseBehavior.Default
	end
	uis.InputBegan:connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local keyPressed = input.KeyCode
			if keyPressed == keybinding.pause then
				mouseLocked = not mouseLocked
				setMouseLocked(mouseLocked)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rmbHold = true
		end
	end)
	uis.InputEnded:connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rmbHold = false
		end
	end)
	function mouseLockHbStep()
		setMouseLocked(mouseLocked)
	end

	-- mouse input change look vector
	looky, lookx = 0, 0
	if debug.showLookDir then
		lookDirPart = Instance.new("Part", workspace)
		lookDirPart.Name = "LookDir"
		lookDirPart.Transparency = 0.5
		lookDirPart.Shape = "Ball"
		lookDirPart.Size = V3new(1, 1, 1)
		lookDirPart.Anchored = true
		lookDirPart.CanCollide = false
		lookDirPart.BrickColor = BrickColor.Blue()
	end 
	function showLookDirRsStep()
		if debug.showLookDir then
			lookDirPart.Position = hrp.Position + V3new(0, 1.5, 0) + cylToV3(looky, lookx) * 3
		end
	end
	uis.InputChanged:connect(function(input)
		if uis.MouseBehavior == Enum.MouseBehavior.LockCenter 
			and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mult = (settings.invertedMouse and 1 or -1) * settings.mouseSensitivity / 100
			
			local rawy = mult * input.Delta.x
			local rawx = mult * input.Delta.y
			
			lookx = clamp(lookx + rawx, -75, 75)
			looky = (looky + rawy) % 360
		end
	end)
end

-- acceleration - maxcharspeed system
--------------------------------

do
	movement.currSpeed = 5
	movement.goalSpeed = 5
	movement.currAcc   = 0
	movement.maxAcc    = 0
	function changeCharSpeed(goalSpeed, maxAcc)
		movement.goalSpeed = goalSpeed
		movement.maxAcc    = maxAcc
	end
	function accSpeedRsStep(dt)
		if movement.currSpeed ~= movement.goalSpeed then
			if movement.goalSpeed > movement.currSpeed then
				movement.currAcc   = movement.maxAcc
				movement.currSpeed = clamp(movement.currSpeed + dt * movement.currAcc, 0, movement.goalSpeed)
			else
				movement.currAcc   = -movement.maxAcc
				movement.currSpeed = clamp(movement.currSpeed + dt * movement.currAcc, movement.goalSpeed, 233333)
			end 
			humanoid.WalkSpeed = movement.currSpeed 
		else
			movement.currAcc = 0
		end 
	end
end

-- stance control system: 
-- walk, crouch, crouch walk, sprint, lean
----------------------------------------

do
	walking       = false

	readyToCrouch = false
	crouching     = false
	crouchWalking = false  -- moving and readyToCrouch

	readyToSprint = false
	sprinting     = false

	moving        = false  -- as opposed to being idle

	walkSpeed      = 10
	sprintSpeed    = walkSpeed * 2
	crouchSpeed    = walkSpeed / 2

	-- determined every frame based on moving or idle
	idleSpeed      = 5
	movingSpeed    = walkSpeed

	walkSpeedWheelMax  = math.floor((sprintSpeed - walkSpeed) * .75)
	walkSpeedWheel     = walkSpeedWheelMax / 2

	humanoid.WalkSpeed = debug.walkingEnabled and walkSpeed or 0

	function updateMovingAndIdleSpeed()
		if readyToSprint then
			movingSpeed = sprintSpeed
			idleSpeed = 12
		elseif crouching then
			movingSpeed = crouchSpeed
			idleSpeed = 3
		else
			movingSpeed = walkSpeed + walkSpeedWheel
			idleSpeed = 8
		end
	end

	uis.InputBegan:connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local keyCode = input.keyCode
			if keyCode == keybinding.sprint then
				readyToSprint = true
				readyToCrouch = false
				--updateMovingAndIdleSpeed()
			elseif keyCode == keybinding.crouch then
				if settings.holdCrouching then
					readyToCrouch = true
				else 	-- toggled
					readyToCrouch = not readyToCrouch
				end
				readyToSprint = false
				--updateMovingAndIdleSpeed()
			end
		end
	end)

	uis.InputEnded:connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local keyCode = input.keyCode
			if keyCode == keybinding.sprint then
				readyToSprint = false
				--updateMovingAndIdleSpeed()
			elseif keyCode == keybinding.crouch then
				if settings.holdCrouching then
					readyToCrouch = false
				end
				--updateMovingAndIdleSpeed()
			end
		end
	end)

	uis.InputChanged:connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local direction = input.Position.z
			walkSpeedWheel = clamp(walkSpeedWheel + direction, 0, walkSpeedWheelMax)
			--updateMovingAndIdleSpeed()
		end
	end)
end



-- walking pose simulation
--------------------------------

do
	-- acceleration tilt
	function wtf() 
		
	end
	
	
	interpolators = {}

	function getInterpolator(a, b, t0, dur)
		local p = 0		-- percentage of completedness
		return function(t, sp)	-- accepts an instant, and a speed
			sp = sp or 1
			
			local tspeed1 = t - t0
			local tspeedsp = tspeed1 * sp
			local pspeedsp = tspeedsp / dur
			
			p  = clamp(p + pspeedsp, 0, 1)
			t0 = t
			local p1 = p	-- math here
			
			return a:lerp(b, p1)
		end
	end

	function lerpToKf(kfName, dur)
		local kf = script.Keyframes[kfName]
		for _, bpcf in ipairs(kf:GetChildren()) do		-- bodypart cframe
			local c0 = bpcf.Value
			local bpn = bpcf.Name		-- body part name
			interpolators[bpn] = getInterpolator(joints[bpn].C0, c0, tick(), dur)
		end 
	end

	state.curr = "Idle"
	state.goal = "Idle"
	state.p    = 1
	state.t0   = -1
	state.dur  = 1
	function isStateFinished()
		return state.p >= 1 - eps
	end
	function changeToState(state, dur)
		print(string.format("change to state %s with dur = %f", state, dur))
		
		lerpToKf(state, dur)
		state.goal = state
		state.t0   = tick()
		state.p    = 0
		state.dur  = dur
	end
end	

-- anichar.step
---------------------------------------


local lastTick = tick()
local function step(dt)
	local now = tick()
	local dt = now - lastTick
	showHrpDirRsStep()
	showLookDirRsStep()
	
	ispeed = getInstantSpeedV2()
	if ispeed > eps and not moving then
		moving = true
		changeCharSpeed(movingSpeed, 40)
		--changeToState("Walk0rl", 0.3)
	
	elseif ispeed > eps and moving then
		changeCharSpeed(movingSpeed, 40)
		if isStateFinished() then
			if state.goal == "Idle" then
				--changeToState("Walk0rl", 0.3)
			else
				--changeToState("Idle", 0.3)
			end				
		end 			
	elseif ispeed <= eps and moving then
		moving = false
		changeCharSpeed(idleSpeed, 30)
		--changeToState("Idle", 0.1)
	end
	

	crouching = readyToCrouch			-- may add some more here later
	crouchWalking = moving and crouching
	sprinting = moving and readyToSprint
	updateMovingAndIdleSpeed()		
	--print(crouchWalking, sprinting)

	
	accSpeedRsStep(dt)
	print(humanoid.WalkSpeed, movement.currAcc, movement.currSpeed)
	


	hrpDirY, hrpDirX = v3ToCyl(hrp.CFrame.lookVector)
	joints.LowerTorso.C0 = anglesToCf(0, looky - hrpDirY - movement.ceshen, 0)
	
	--[[
	local anisp = 0.5			-- animation speed. change this based on the v2 speed
	state.p  = clamp(state.p + (now - state.t0) * anisp / state.dur, 0, 1)
	state.t0 = now 
	
	for bpn, interpolator in pairs(interpolators) do
		joints[bpn].C0 = interpolator(now, anisp)
	end--]]
	lastTick = now
end


bindRS("char Update", 1, step)
spawn(function()
	while hb:wait() do
		mouseLockHbStep()
	end
end)

--[[
-- root joint. sideway movement & tilting
---------------------------------------------

local facingDirIndicator = Instance.new("Part", workspace)
facingDirIndicator.Size = Vector3.new(0.5, 0.5, 0.5)
facingDirIndicator.Anchored = true
facingDirIndicator.CanCollide = false
facingDirIndicator.Shape = "Ball"
spawn(function()
	while rs:wait() do
		facingDirIndicator.Position = hrp.Position + hrp.CFrame.lookVector * 3
	end
end)

local lowerTorso = char.LowerTorso 
local rootJoint = lowerTorso.Root
local sidewayAngleY = 45 
spawn(function()
	while rs:wait() do
		sidewayAngleY = rep.num1.Value
	end
end)

rootJoint.C1 = iCF

spawn(function()
	while rs:wait() do
		rootJoint.C0 = newCF(0, -0.15, 0)		-- rbxdefault
		* anglesCF(0, -sidewayAngleY * deg, 0)				-- sideways
	end
end)
	
-- legs
---------------------------------------------

local lupl = char.LeftUpperLeg
local llol = char.LeftLowerLeg
local lhip = lupl.LeftHip
local lknee = llol.LeftKnee
local strechingOutAngleX = 30

local rupl = char.RightUpperLeg
local rlol = char.RightLowerLeg
local rhip = rupl.RightHip
local rknee = rlol.RightKnee
local rightLegAngleY = 75

spawn(function()
	while rs:wait() do
		strechingOutAngleX = rep.num2.Value
		rightLegAngleY = rep.num3.Value
	end
end)

spawn(function()
	--local lhipC1inv = lhip.C1:inverse()
	--lhip.C1 = iCF
	while rs:wait() do
		lhip.C0 = newCF(-0.4, -0.2, 0)										-- rbx default
		 * anglesCF(0, sidewayAngleY * deg, 0)						-- facing foward 
		 * anglesCF(strechingOutAngleX * deg, 0, 0) 			-- stretching out
		 --* lhipC1inv -- finish
		
		lknee.C0 = newCF(0, -0.3, 0)											-- rbxdefault
			* anglesCF(- strechingOutAngleX * deg, 0, 0) 		-- directly down
		
		rhip.C0 = newCF(0.4, -0.2, 0)										-- rbx default
		 * anglesCF(0, - (rightLegAngleY - sidewayAngleY) * deg, 0)						-- facing foward 
		 * anglesCF(strechingOutAngleX * deg, 0, 0) 			-- stretching out
		
		rknee.C0 = newCF(0, -0.3, 0)
			* anglesCF(- strechingOutAngleX * deg, 0, 0) 		-- directly down
	end
end)
--]]

	


	




