-- next??
-- action and callback system
-- callback for action interrupted and action completed

local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local plrs = game.Players
local lp   = plrs.LocalPlayer
local function requireGm(name)
	return require(wfc(wfc(rep, "GlobalModules"), name))
end
local db         = requireGm("DebugSettings")()
local printTable = requireGm("TableUtils").printTable

local fpsClient, dynClient, scsClient, fetchClient
do
	local events = wfc(rep, "Events")

	fpsClient = requireGm("Network").loadRe(
		wfc(events, "FpsRe"), 
		{
			socketEnabled = true, 
			re2 = wfc(events, "FpsForwardRe")
		}
	)

	dynClient = requireGm("Network").loadRe(wfc(events, "DynEnvRe"))

	scsClient = requireGm("SerializedCharStates").loadRe(wfc(events, "CharStatesRe"))

	fetchClient = requireGm("FetchClient").loadRf(wfc(events, "FetchRf"))
end
local inputReader = requireGm("InputReader")

local settings = {
	mouseSensitivity = 10,
	fov      = 75,
	shakyGui = true,
}

local loadout1 -- assuming loadout1
local fppModule = {}
do -- spawn
	local fpp = nil 		-- will be extended into an array for fpp spectating in the future
	fpsClient.listen("spawn", function(plr, spawnArgs)
		if plr == lp then
			if not loadout1 then
				loadout1 = fetchClient.fetch("loadout1", {wait = true})
			end
			if fpp then
				fpp.despawn()
				wait()
			end
			fpp = fppModule.spawn(spawnArgs)
		end
	end)
end

-- the raycasting whitelists
local rayWls = {
	everything = {workspace},
	mapObstr = {wfc(workspace, "Map")},
	shootable = {
		wfc(workspace, "Map"), 
		wfc(workspace, "Terrain"), 
		wfc(workspace, "Chars")
	},
}

-- projectile handler
local projectileHandler = {}
do
	local projs = {} -- the set containing all projectiles
	local unshown = {} -- of others
	local defCf = wfc(wfc(wfc(rep, "GlobalModules"), "Projectile"), "Proj").CFrame
	spawn(function()
		local stepped = game:GetService("RunService").Heartbeat
		local evwait = game.Changed.Wait
		while true do
			local dt = evwait(stepped)
			for id, proj in pairs(projs) do
				local ret = proj.step(dt)
				if ret == "destroyed" then  -- @todo check this in the projectile lib
					projs[id] = nil
				end
			end
			-- for id, part in pairs(unshown) do
			-- 	if part.Position ~= defCf.p then
			-- 		part.Transparency = 0
			-- 		unshown[id] = nil
			-- 	end
			-- 	if not part or not part.Parent then
			-- 		unshown[id] = nil
			-- 		print("removed destroyed parts")
			-- 	end
			-- end
		end
	end)

	local cnt = 0
	local newProj = requireGm("Projectile").new
	-- local lu = tick()
	-- local ut = 0.1
	-- same parameters as newProj
	function projectileHandler.createProjectile(p0, v0, args)
		cnt = cnt + 1
		local id = lp.Name.."_"..cnt 
		local proj = newProj(p0, v0, args)
		projs[id] = proj

		-- local now = tick() 
		-- if now - lu > ut then
		-- 	lu = now
		fpsClient.forward("shoot", id)
		-- end
	end

	local holder = wfc(workspace, "Projectiles")
	local isA = game.IsA
	local split = requireGm("StringPathSolver").split
	local stepped = game:GetService("RunService").Heartbeat
	local cac = game.ClearAllChildren
	holder.DescendantAdded:Connect(function(obj)
		if isA(obj, "Part") then
			local part = obj
			local projId = part.Name
			local sp = split(projId, "_")
			local shooterName, cnt = sp[1], tonumber(sp[2])
			if shooterName and cnt then
				-- print("projectile: get", shooterName, cnt, "from network", shooterName == lp.Name)
				if shooterName == lp.Name then
					local proj = projs[projId]
					if not proj then
						warn("got proj projId from network but no local proj found. aborted")
					else
						-- print("called replaceWithOnlinePart")
						proj.replaceWithOnlinePart(part)
					end
				else
					-- unshown[projId] = part
					part.Transparency = 0
					cac(part)
					-- part.Anchored = true
				end
			end
		end
	end)

	local createParticle = requireGm("ParticleSystem").onHit
	local ffc = game.FindFirstChild
	fpsClient.listen("bulletHit", function(attacker, hit, p1)
		local p0 = attacker and attacker.Character and ffc(attacker.Character, "Head") and attacker.Character.Head.Position
		if attacker and p0 and p1 and hit then
			createParticle(hit, p0, p1, hit.Material, attacker)
		end
	end)
end

-- taking it out for optimization
local tppAnimations = requireGm("TppAnimations")()

-- closure based
function fppModule.spawn(spawnArgs)
	print("fpp spawn with spawnArgs:")
	-- printTable(spawnArgs)

	-- variable/function table
	local fpp = {}

	-- variables that are accessed not so frequently should be added into the table
	fpp.skinObjs = {fpp = {}, tpp = {}}	
	fpp.alive_ = true
	fpp.alive = true

	-- variables that are accessed very frequently should be localized
	local initTick = tick()
	local alive = true
	local aliveSm = 1
	local now   = 0
	local TS    = 0
	local cons  = {}

	-- chars
	print("fpp: waiting for char", lp)
	local char = lp.Character or lp.CharacterAdded:Wait()
	char.Parent = workspace.NonHitbox
	print("fpp: get char", lp)
	local humanoid = wfc(char, "Humanoid")
	local hrp = wfc(char, "HumanoidRootPart")

	local fppAnimations = {} -- @todo should have a saved animation like tpp
	-- right now we dont need it because there's only vaulting and vaulting wont be changed by any gun

	assert(spawnArgs.spawnLocation, "no spawnlocation received from server")
	fpp.looky_, fpp.lookx_ = requireGm("Math").v3ToCyl(spawnArgs.spawnLocation.CFrame.lookVector)
	do -- init look angles
		fpp.looky, fpp.lookx = fpp.looky_, fpp.lookx_
		fpp.lookyRel = 0
		fpp.hrpy = 0
	end

	local gearSlots = loadout1.weapons
	local gun
	local stats

	local aniparts, joints, defC0, sounds, stash = {}, {}, {}, {}, {Char = char}
	requireGm("RigHelper").initRig(char, aniparts, joints, defC0)

	local kfs
	do -- kfs
		local play = requireGm("AudioSystem").play
		kfs = requireGm("KeyframeAnimation").new(aniparts, joints, defC0, stash, function(sound)
			play(sounds[sound] or sound, "2D")
		end)
	end

	do-- configure stash.charNH2
		-- nonhitbox, not slibling of humanoid. store models
		-- note: fpp clothes / fppgun -> outside of char (charnh2)
		--       your own tpp clothes (for dancing and death) -> char with humanoid
		--       others' tpp clothes / tpp gun -> outside of char (charnh2)
		local charNH2 = Instance.new("Model")
		charNH2.Name = lp.Name.."_charNH2"
		charNH2.Parent = wfc(workspace, "NonHitbox")
		stash.charNH2 = charNH2
	end

	do-- char visibility
		assert(spawnArgs.skin, "fpp: skin is nil")
		local setCharVisibility = requireGm("RigHelper").setCharVisibility
		setCharVisibility("fpp", true, char, aniparts, fpp.skinObjs, {skin = spawnArgs.skin, charNH = stash.charNH2})
		setCharVisibility("tpp", false, char, aniparts, fpp.skinObjs)
		-- @done send the skin WITH TEAM from server
		-- @done loadskin now does not consider the side
		-- @done tpp skin should not be uplaoded from lp. tpp
	end

	do--disable swimming
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	end

	do -- reset handler
		local resetBindable = Instance.new("BindableEvent")
		resetBindable.Event:connect(function()
			fpsClient.fireServer("reset")	  
		end)
		game:GetService("StarterGui"):SetCore("ResetButtonCallback", resetBindable)
	end

	print("fpp basic stuff loaded")

	-- the small modules
	---------------------------------------------------

	fpp.fppGuiInit = {}
	do
		fpp.sgTemp = wfc(wfc(wfc(game:GetService("StarterPlayer"), "StarterPlayerScripts"), "Fpp"), "FpsGui")
		fpp.sg = wfc(wfc(lp, "PlayerGui"), "FpsGui")
		fpp.dynamicFr = wfc(fpp.sg, "Dynamic") 
		fpp.staticFr = wfc(fpp.sg, "Static")

		do -- get gui
			local guiStash = wfc(fpp.sgTemp, "Stash")
			local clone    = game.Clone
			function fpp.fppGuiInit.getNewGui(guiName)
				return clone(wfc(guiStash, guiName))
			end
		end

		do -- insert / remove Gui
			local ffc = game.FindFirstChild
			local destroy = game.Destroy
			function fpp.fppGuiInit.removeGui(gui)
				if ffc(fpp.dynamicFr, gui.Name) then
					destroy(ffc(fpp.dynamicFr, gui.Name))
				end
				if ffc(fpp.staticFr, gui.Name) then
					destroy(ffc(fpp.staticFr, gui.Name))
				end				
			end
			local removeGui = fpp.fppGuiInit.removeGui
			function fpp.fppGuiInit.insertGui(gui, parent)
				removeGui(gui)
				gui.Parent = parent
			end
		end
	end


	fpp.mouseLockSystem = {}
	do
		local mbLockCenter          = Enum.MouseBehavior.LockCenter
		local mbLockCurrentPosition = Enum.MouseBehavior.LockCurrentPosition
		local mbDefault             = Enum.MouseBehavior.Default
		local rmbHold               = false

		local locked 
		-- should be moved to the in-game settings later on?
		inputReader.listen("pause", "Begin", "Keyboard", requireGm("Keybindings").pause, function()
			locked = not locked
		end)
		inputReader.listen("rmb0", "Begin", "MouseButton2", nil, function()
			rmbHold = true
		end)
		inputReader.listen("rmb1", "End", "MouseButton2", nil, function()
			rmbHold = false
		end)

		local uis = game:GetService("UserInputService")
		function fpp.mouseLockSystem.setLocked(bool)
			uis.MouseBehavior = bool
				and mbLockCenter
				or rmbHold 
					and mbLockCurrentPosition
					or mbDefault
			uis.MouseIconEnabled = not bool
			locked = bool
		end
		fpp.mouseLockSystem.setLocked(true)

		local setLocked = fpp.mouseLockSystem.setLocked
		function fpp.mouseLockSystem.rs1()  -- state
			if not alive then return end
			setLocked(locked)
		end
	end

	fpp.camLockSystem = {}
	do
		fpp.camLocked = true
		local cam = workspace.CurrentCamera
		local head = aniparts.Head
		local ctScriptable = Enum.CameraType.Scriptable
		local ctFollow     = Enum.CameraType.Follow

		function fpp.camLockSystem.setLocked(bool)
			if fpp.camLocked ~= bool then
				fpp.camLocked = bool
				if bool then
					cam.CameraType = ctScriptable
					cam.CameraSubject = nil
				else
					cam.CameraType = ctFollow
					cam.CameraSubject = head 
				end
			end
		end

		if db.fppCamToggle then
			inputReader.listen("fppCamToggle", "Begin", "Keyboard", requireGm("Keybindings").camLock, function()
				fpp.camLockSystem.setLocked(not fpp.camLocked)
			end)
		end
	end

	fpp.deathSystem = {}
	do
		local ffc = game.FindFirstChild
		local myMath = requireGm("Math")
		local audioSys = requireGm("AudioSystem")
		local setCharVisibility = requireGm("RigHelper").setCharVisibility

		local killMethod, killData

		function fpp.deathSystem.onDeathImmediate(killMethod_, killData_)
			killMethod = killMethod_
			killData   = killData_
			fpp.alive_ = false
		end

		function fpp.deathSystem.onDeath()
			-- kfs = requireGm("KeyframeAnimation").new(aniparts, joints, defC0, stash)

			do -- disable movements
				humanoid.WalkSpeed  = 0
				humanoid.JumpPower  = 0
				humanoid.AutoRotate = false
				delay(2, function()
					hrp.Anchored = true
				end)
			end

			audioSys.play("DeathScream", "2D")
			
			do -- play death animation
				local aniName, deathDir, headshotQ = requireGm("GetDeathAnimation")(killMethod, killData, {hrp = hrp, looky = fpp.looky, fpp.crouching})
				print("fpp death animation got:", aniName, deathDir, headshotQ)
				kfs.load(tppAnimations, aniName, {snapFirstFrame = true})
			end

			do -- drop the oofing weapon
				local weaponMain = aniparts.WeaponMain
				if weaponMain and gun then
					aniparts.WeaponMain = nil
					requireGm("Welding").setPartsProperty(gun.model, {CanCollide = true})
					joints.WeaponMain.Part0 = nil

					delay(5, function()
						if gun.model then
							requireGm("Welding").setPartsProperty(gun.model, {CanCollide = false, Anchored = true})
						end
					end)
				end
			end

			do--hide fpp parts and show tpp parts
				setCharVisibility("fpp", false, char, aniparts, fpp.skinObjs, {charNH = stash.charNH2})
				setCharVisibility("tpp", true, char, aniparts, fpp.skinObjs, {skin = spawnArgs.skin})--, looky = fpp.looky, hrpy = fpp.hrpy, tppLookJoint = joints.TppLook})
				fpp.camLockSystem.setLocked(false)
				fpp.mouseLockSystem.setLocked(false)
			end
		end
	end

	-- sets the tpplookjoints (for dancing and death. correcting angles)
	fpp.tppAngleSystem = {}
	if not db.renderSelfTpp then
		local tppLookJoint = joints.TppLook
		local cylToCf = requireGm("Math").cylToCf
		function fpp.tppAngleSystem.rs2()
			if not alive then return end
			tppLookJoint.C0 = cylToCf(fpp.lookyRel, 0)
		end
	end

	if db.renderSelfTpp then
		local kb = requireGm("Keybindings")
		local rigHelper = requireGm("RigHelper")
		local f = true
		inputReader.listen("toggleFpp", "Begin", "Keyboard", kb.toggleFpp, function()
			f = not f
			rigHelper.setCharVisibility("fpp", f, char, aniparts, fpp.skinObjs, {skin = spawnArgs.skin, gunModel = gun and gun.model, charNH = stash.charNH2})
		end)
		local t = false
		inputReader.listen("toggleTpp", "Begin", "Keyboard", kb.toggleTpp, function()
			t = not t
			rigHelper.setCharVisibility("tpp", t, char, aniparts, fpp.skinObjs, {skin = spawnArgs.skin})
		end)
	end

	fpp.mouseInertiaSystem = {}
	do
		local maxInertia = 10

		fpp.mouseInertiaY = 0
		fpp.mouseInertiaX = 0

		local mouseInertiaX_  = 0  -- the "goal values" set by onMouseMoved
		local mouseInertiaY_  = 0

		local lastMouseInputTS = -1
		local springY = requireGm("NumericSpring").new(2, 0.15, 0.3)
		local springX = requireGm("NumericSpring").new(2, 0.15, 0.3)

		function fpp.mouseInertiaSystem.onMouseMoved(rawx, rawy)
			mouseInertiaX_   = rawx * 1.5
			mouseInertiaY_   = rawy * 1.5
			lastMouseInputTS = TS
		end

		local myMath = requireGm("Math")
		local clamp  = myMath.clamp

		function fpp.mouseInertiaSystem.rs2(dt)
			if lastMouseInputTS ~= TS or not alive then
				mouseInertiaY_, mouseInertiaX_ = 0, 0
			end
			fpp.mouseInertiaY = springY.step(dt, clamp(mouseInertiaY_, -maxInertia, maxInertia))
			fpp.mouseInertiaX = springX.step(dt, clamp(mouseInertiaX_, -maxInertia, maxInertia))
		end
	end

	fpp.recoilSystem = {}
	do
		fpp.recoilX           = 0
		local recoilX_        = 0
		local recoilXMax      = db.removeRecoilXLimit and 10000 or 10
		local recoilXSmoother = requireGm("Interpolation").getSmoother(5, 0.8)
		local recoilXInc
		local recoilXRec 
		local recoilXDampDur
		local recoilXDampInit
		local recoilXDampExp

		fpp.recoilY = 0
		local recoilY_ = 0
		local recoilYMax = 10000
		local recoilYSmoother = requireGm("Interpolation").getSmoother(15, 0.5)
		local recoilYRec
		local recoilYPattern, recoilYPatternLength, recoilYLast
		local recoilYRan  
		local recoilYMult 
		local recoilYStart -- >= 1

		local counterRecoilY = 0

		fpp.recoilZ = 0
		local recoilZDir
		local recoilZT
		local recoilZSmoother    = requireGm("Interpolation").getSmoother(8, 0.2)
		local recoilZBackCurve   = function(t) return t^0.2 end
		local recoilZReturnCurve = function(t) return t end

		fpp.recoilCamRot = 0
		local recoilCamRot

		fpp.recoilFov = 0
		local recoilFov

		local myMath = requireGm("Math")

		do -- onGunEquipped
			local nsToArray = requireGm("NumberSequence").toArray
			function fpp.recoilSystem.onGunEquipped()
				recoilXRec = stats.recoilXRec / 10
				recoilXInc = stats.recoilX
				recoilXDampDur = stats.recoilXDampDur
				recoilXDampInit = stats.recoilXDampInit
				recoilXDampExp = stats.recoilXDampExp

				recoilYRec   = stats.recoilYRec / 10
				recoilYRan   = stats.recoilYRan
				recoilYMult  = stats.recoilYMult
				recoilYStart = stats.recoilYStart
				if db.statsPanel then
					recoilYPattern, recoilYPatternLength = nsToArray(stats.recoilYPattern)
					recoilYLast = recoilYPattern[recoilYPatternLength - 1]
				else
					assert(typeof(stats.recoilYPattern) == "table", typeof(stats.recoilYPattern))
					recoilYPattern       = stats.recoilYPattern
					recoilYPatternLength = stats.recoilYPatternLength
					recoilYLast          = stats.recoilYLast
				end

				recoilZDir  = 0
				recoilZT    = 0

				recoilCamRot = stats.recoilCamRot
				recoilFov = stats.recoilFov
			end
		end

		local clamp = myMath.clamp
		local floor = math.floor
		local min   = math.min

		-- return a random double in the range
		local random = math.random
		local function rand(l, r)
			return (r - l) * random() + l
		end

		-- @param rawx, rawy: the raw input from the mouse
		-- @ret some portion of the input will contribute to cancel the recoil,
		--      this function will return the mouse dx,dy subtracted by value thats cancelled
		-- cancelling vertical recoil means fpp.recoilX and recoilX_ will get reduced
		-- for cancelling horizontal recoil, due to its bidirectional nature, we keep track of a value called counterRecoilY. this value will be considered in the calculation of recoilYInc.
		function fpp.recoilSystem.onMouseMoved(rawx, rawy)
			-- counter vertical
			local recoilX = fpp.recoilX
			if recoilX > 1e-3 and rawx < 0 then
				local m     = min(-rawx, recoilX)
				fpp.recoilX = recoilX - m
				rawx        = rawx + m
				recoilX_    = clamp(recoilX_ - m, 0, recoilXMax)
			end

			-- counter horizontal
			local recoilY = fpp.recoilY
			if recoilY > 1e-3 and rawy < 0 then
				local m     = min(recoilY, -rawy)
				fpp.recoilY = recoilY - m
				rawy        = rawy + m
				counterRecoilY = counterRecoilY - m
				-- recoilY_    = clamp(recoilY_ - m, -recoilYMax, recoilYMax)
			elseif recoilY < 1e-3 and rawy > 0 then
				local m     = min(-recoilY, rawy)
				fpp.recoilY = recoilY + m
				rawy        = rawy - m
				counterRecoilY = counterRecoilY + m
				-- recoilY_    = clamp(recoilY_ + m, -recoilYMax, recoilYMax)
			end

			return rawx, rawy
		end

		-- @param s: shotsSprayed
		function fpp.recoilSystem.incRecoil(s)
			-- recoilx
			local damp = clamp(
				recoilXDampInit + 
					(1 - recoilXDampInit) * (s / recoilXDampDur) ^ recoilXDampExp, 
				0, 1)
			recoilX_ = recoilX_ + recoilXInc * damp
			if recoilX_ > recoilXMax then
				recoilX_ = recoilXMax
			end

			-- recoilCamRot
			fpp.recoilCamRot = (random(0, 1) == 1 and 1 or -1) * recoilCamRot * rand(0.9, 1.1)

			-- recoilFov
			fpp.recoilFov = (random(0, 1) == 1 and 1 or -1) * recoilFov * rand(0.9, 1.1)
		end

		-- @param s: shotsSprayed
		function fpp.recoilSystem.incRecoilY(s)
			if s == 1 then -- reset the counterRecoil when the shooting just begins
				counterRecoilY = 0
			end
			s = s - recoilYStart
			if s >= 0 then
				recoilY_ = clamp(
					rand(-recoilYRan, recoilYRan) 
					+ counterRecoilY
					+ recoilYMult 
						* (floor(s / recoilYPatternLength) * recoilYLast 
							+ recoilYPattern[(s % recoilYPatternLength) + 1])
					,
					-recoilYMax, 
					recoilYMax
				)
			end
		end

		function fpp.recoilSystem.rs2(dt)
			-- recoilx
			recoilX_ = clamp(recoilX_ - recoilXRec, 0, recoilXMax)
			fpp.recoilX = recoilXSmoother(fpp.recoilX, recoilX_, dt)

			-- recoily
			if recoilY_ > 0 then
				recoilY_ = clamp(recoilY_ - recoilYRec, 0, 100000000)
			elseif recoilY_ < 0 then
				recoilY_ = clamp(recoilY_ + recoilYRec, -100000000, 0)
			end
			fpp.recoilY = recoilYSmoother(fpp.recoilY, recoilY_, dt)

			-- print(string.format("recoilX = %.2f recoilY = %.2f", fpp.recoilX, fpp.recoilY))
			-- print(string.format("%.6f", dt - (1/60)))

			-- recoilcamrot
			fpp.recoilCamRot = fpp.recoilCamRot / 2

			-- recoilfov
			fpp.recoilFov = fpp.recoilFov / 2

			-- recoilz
			if fpp.shooting then
				recoilZDir = 1
			end
			local recoilZGoal = 0
			if recoilZDir == 1 then
				recoilZT    = clamp(recoilZT + dt / stats.recoilZBackDur, 0, 1)
				recoilZGoal = recoilZBackCurve(recoilZT)
			elseif recoilZDir == -1 then
				recoilZT    = clamp(recoilZT - dt / stats.recoilZReturnDur, 0, 1)
				recoilZGoal = recoilZReturnCurve(recoilZT)
			end
			if recoilZDir == 1 and recoilZT == 1 then
				recoilZDir = -1
			elseif recoilZDir == -1 and recoilZT == 0 then
				recoilZDir = 0
			end
			recoilZGoal    = recoilZGoal * stats.recoilZ
			fpp.recoilZ    = recoilZSmoother(fpp.recoilZ, recoilZGoal, dt)
			fpp.shootingSm = fpp.recoilZ / stats.recoilZ
		end
	end

	fpp.turnAction = {}
	do
		local myMath  = requireGm("Math")
		local cylToCf = myMath.cylToCf
		local v3ToCyl = myMath.v3ToCyl
		local clamp   = myMath.clamp

		local maxAngle = 60 		-- there's also one in look joint handler

		local counterRecoilX = fpp.recoilSystem.onMouseMoved
		local trackMouseInertia = fpp.mouseInertiaSystem.onMouseMoved

		local function onMouseMoved(input)
			if not fpp.dancing then
				local mult = - settings.mouseSensitivity / 75
				local d = input.Delta
				local rawy = mult * d.x
				local rawx = mult * d.y

				trackMouseInertia(rawx, rawy)
				local dx, dy = counterRecoilX(rawx, rawy)

				fpp.lookx_ = clamp(fpp.lookx_ + dx, -maxAngle, maxAngle)
				fpp.looky_ = fpp.looky_ + dy --) % 360
			end
		end
		inputReader.listen("mouse.move", "Change", "MouseMovement", nil, onMouseMoved)
	end

	fpp.blockingSystem = {}
	do
		fpp.blocking = false

		local raycastWl = requireGm("Raycasting").raycastWl
		local cylToV3 = requireGm("Math").cylToV3
		local blockingDist = 3.3

		local fppLook = aniparts.FppLook
		local down    = CFrame.new(0, -1, 0)

		function fpp.blockingSystem.rs1(dt)
			if not alive then return end
			fpp.blocking = not (fpp.reloading or fpp.sprinting or fpp.bursting or fpp.vaulting or fpp.equipping or fpp.unequipping) and raycastWl((fppLook.CFrame * down).p, cylToV3(fpp.looky, fpp.lookx) * blockingDist, rayWls.mapObstr) 
		end
	end

	fpp.crouchAction = {}
	do
		fpp.crouchAtmpt = false
		fpp.crouching = false
		fpp.crouchingSm = 0
		local crouchSmoother = requireGm("Interpolation").getSmoother(5, 0.5)
		fpp.cruochingSp = 0
		local crouchSpring = requireGm("NumericSpring").new(1, 0.5, 0.12)

		local play = requireGm("AudioSystem").play

		-- ctrl: hold to crouch
		inputReader.listen("crouch0", "Begin", "Keyboard", requireGm("Keybindings").crouch, function()
			fpp.crouchAtmpt = true
			fpp.danceAtmpt = false
		end)
		inputReader.listen("crouch1", "End", "Keyboard", requireGm("Keybindings").crouch, function()
			fpp.crouchAtmpt = false
		end)
		-- c: toggle crouch
		inputReader.listen("crouch2", "Begin", "Keyboard", requireGm("Keybindings").crouch2, function()
			fpp.crouchAtmpt = not fpp.crouchAtmpt
			fpp.danceAtmpt = false
		end)

		function fpp.crouchAction.rs1(dt)
			if not alive then return end
			local crouchingNew = fpp.crouchAtmpt
				and not (fpp.sprinting or fpp.climbing or fpp.jumping)	-- add more
			if crouchingNew ~= fpp.crouching then
				fpp.crouching = crouchingNew
				if crouchingNew then
					play("Crouching", "2D")
				end
			end
			local crouching_ = crouchingNew and 1 or 0
			fpp.crouchingSm = crouchSmoother(fpp.crouchingSm, crouching_, dt)
			_, fpp.crouchingSp = crouchSpring.step(dt, crouching_)
		end

		function fpp.crouchAction.rs2(dt)
			humanoid.HipHeight = 1.55 - aliveSm * fpp.crouchingSm * 0.9 
		end
	end

	fpp.jumpAction = {}
	do 	-- jump / vault / climb
		local play        = requireGm("AudioSystem").play
		local newV3       = Vector3.new
		local myMath      = requireGm("Math")
		local cylToV3     = myMath.cylToV3
		local clamp       = myMath.clamp
		local raycastWl = requireGm("Raycasting").raycastWl

		-- consts for vaulting
		local vaultingDur  = 0.75
		local vaultRayDist = 5
		local function getVaultH(obstr, point)
			return obstr.Position.Y + obstr.Size.Y * 0.5 - point.Y
		end
		local function isVaultable(obstr, point, h)
			h = h or getVaultH(obstr, point)
			return h <= 3.5
		end
		do -- getVaultingParabola
			local sin = math.sin
			local cos = math.cos
			local deg = myMath.deg
			function fpp.jumpAction.getVaultingParabola(_h)
				local p0    = hrp.Position
				local h     = (_h + humanoid.HipHeight + hrp.Size.Y) * 1.1
				local theta = fpp.looky * deg
				local t0    = now
				local d     = vaultRayDist
				local T     = vaultingDur / 2
				local a     = h / (d^2)
				return function(t)
					t       = t - t0
					local x = t * d / T
					local y = - a * ((x - d)^2) + h
					return p0 + newV3(sin(theta) * x, y, cos(theta) * x)
				end
			end
		end
		local getVaultingParabola = fpp.jumpAction.getVaultingParabola

		-- vars for vaulting parabola
		local vaultingParabola 
		local vaultingT = 0
		local vaultingSt = -1
		fpp.vaulting = false
		fpp.vaultingP = 0

		-- vaulting body mover
		local vaultingBm = Instance.new("BodyPosition")
		local function setBmEnabled(bool)
			vaultingBm.MaxForce = newV3(bool and 400000 or 0, bool and 400000 or 0, bool and 400000 or 0)
		end
		do -- initialize vaulting body mover
			vaultingBm.D = 100
			vaultingBm.Parent = hrp
			setBmEnabled(false)
		end

		do -- insert fpp animations for vaulting
			local newCf = CFrame.new
			local keyframes = {
				vault1 = {
					FppRightArm = newCf(1.30952513, -0.0340596735, -0.995640397, 0.916124225, -0.377461553, -0.135052472, 0.36527887, 0.924755454, -0.106764548, 0.165190071, 0.0484777614, 0.985069633),
					FppLeftArm = newCf(-0.958647728, -0.226490647, -1.74296761, 0.818710685, -0.559243679, 0.130228683, 0.452690631, 0.768157244, 0.452775598, -0.353248, -0.311738878, 0.882062733),
				},
				vault2 = {
					FppRightArm = newCf(1.26412928, 0.148768693, -1.14816213, 0.769121468, -0.636191487, -0.0609313026, 0.598520279, 0.750434041, -0.280396581, 0.224110812, 0.179190397, 0.957948446),
					FppLeftArm = newCf(-0.686708927, -0.800103545, -0.871892333, 0.818710685, -0.542656541, -0.187714666, 0.452690601, 0.408873796, 0.792397261, -0.353247941, -0.733720779, 0.580404818),
				},
				vault3 = {
					FppRightArm = newCf(1.30952513, -0.0340597332, -0.995640397, 0.916124225, -0.377461553, -0.135052472, 0.36527887, 0.924755454, -0.106764548, 0.165190071, 0.0484777614, 0.985069633),
					FppLeftArm = newCf(-0.95864737, -0.226490408, -1.74296749, 0.818710685, -0.559243679, 0.130228683, 0.452690631, 0.768157244, 0.452775598, -0.353248, -0.311738878, 0.882062733),
				},
			}
			local vaultingAnimation = {
				name = "vaulting",
				[1] = {
					goalC0 = keyframes.vault1,
					dur    = vaultingDur * 1.00 * 5 / 20,
					easing = "easeInCubic",
				},
				[2] = {
					goalC0 = keyframes.vault2,
					dur    = vaultingDur * 1.00 * 8 / 20,
					easing = "easeOutQuart",
				},
				[3] = {
					goalC0 = keyframes.vault3,
					dur    = vaultingDur * 1.00 * 6 / 20,
					easing = "easeInCubic",
				},
			}
			fppAnimations.vaulting = vaultingAnimation
		end

		-- jumping & climbing
		local jumpAtmpt = false
		fpp.jumping   = false
		fpp.climbing = false
		-- localize states
		local hsJumping = Enum.HumanoidStateType.Jumping
		local hsFreefall = Enum.HumanoidStateType.Freefall
		local hsClimbing = Enum.HumanoidStateType.Climbing
		-- springs
		fpp.landingSp = 0
		local landingPulse = requireGm("NumericPulse").new(1.5, 0.5, 0.12, 0.1)
		fpp.jumpingSp = 0
		local jumpingPulse = requireGm("NumericPulse").new(1.5, 0.5, 0.12, 0.1)
		
		-- jumpower is 0 by default
		humanoid.JumpPower = 0
		local jumpTS = -1
		inputReader.listen("jump", "Begin", "Keyboard", requireGm("Keybindings").jump, function()
			jumpTS = TS
			fpp.danceAtmpt = false
			fpp.crouchAtmpt = false
			-- fpp.leaning = nil
		end)

		do -- exitClimbing
			local back = newV3(-2, 0, -2)
			function fpp.jumpAction.exitClimbing()
				if fpp.climbing then
					local hrpcf = hrp.CFrame
					hrp.CFrame = hrpcf + hrpcf.lookVector * back
				end
			end
		end
		local exitClimbing = fpp.jumpAction.exitClimbing

		function fpp.jumpAction.rs1(dt)
			if not alive then return end
			jumpAtmpt = jumpTS == TS
			if jumpAtmpt then

				if not (fpp.vaulting or fpp.jumping or fpp.climbing or fpp.staminaLock) then
					-- the floor
					local hrpp = hrp.Position
					local standingBrick = raycastWl(
						hrpp, 
						newV3(0, -1.5 * (humanoid.HipHeight + hrp.Size.Y / 2), 0), 
						rayWls.mapObstr
					)
					-- the obstr
					local obstr, point = raycastWl(
						hrpp, 
						cylToV3(fpp.looky, 0) * vaultRayDist, 
						rayWls.mapObstr
					)
					-- the height of the obstr					
					local _h = obstr and getVaultH(obstr, point)

					if obstr 
						and obstr ~= standingBrick 
						and isVaultable(obstr, point, _h) 
						and not fpp.reloading then

						fpp.vaulting = true
						fpp.holding = true

						setBmEnabled(true)
						vaultingT  = 0
						vaultingSt = now
						vaultingParabola = getVaultingParabola(_h)

						kfs.load(fppAnimations, "vaulting", {fitLength = vaultingDur})

						play("Vaulting", "2D")
					else
						humanoid.JumpPower = 17
						humanoid.Jump      = true
						play("Jumping", "2D")
					end

				else 

					exitClimbing()
				end

			else
				-- exit jumping
				humanoid.JumpPower = 0
			end

			if fpp.vaulting then
				if vaultingT < vaultingDur then
					vaultingT           = clamp(vaultingT + dt, 0, vaultingDur)
					vaultingBm.Position = vaultingParabola(now)
				else
					fpp.vaulting = false
					setBmEnabled(false)
				end
			end

			fpp.vaultingP = (now - vaultingSt) / vaultingDur
		end

		function fpp.jumpAction.hb1(dt)
			if not alive then return end
			local state   = humanoid:GetState()
			fpp.climbing  = state == hsClimbing

			local jumping_ = state == hsJumping or state == hsFreefall 
			if jumping_ ~= fpp.jumping then
				fpp.jumping = jumping_
				if jumping_ then
					jumpingPulse.pulse()
				else
					landingPulse.pulse()
				end
			end
			fpp.landingSp = landingPulse.step(dt)
			fpp.jumpingSp = jumpingPulse.step(dt)
		end

		do -- camera rs step
			local myMath    = requireGm("Math")
			local degToCf   = myMath.degToCf
			local axisRotCf = CFrame.fromAxisAngle
			local deg       = myMath.deg
			local sin       = math.sin
			local pi        = math.pi
			local iCf       = CFrame.new()

			local vaultingSwayX
			do
				local xa, xb, xc = 0.1, -0.2, 1
				local cx = 2 * pi / (1 - xb - xa)
				vaultingSwayX = function(t)
					if t <= xa or t >= 1 - xb then
						return 0
					else
						return xc * sin(cx * (t - xa))
					end
				end
			end

			local vaultingSwayZ
			do
				local za, zb, zc = 0.2, 0.2, 1
				local cz = pi / (1 - zb - za)
				vaultingSwayZ = function(t)
					if t <= za or t >= 1 - zb then
						return 0
					else
						return zc * sin(cz * (t - za))
					end
				end
			end

			local vaultingSwayP
			local pv = Vector3.new(1, 1, -1)
			do
				local pa, pb, pc = 0.3, 0, 1
				local pc = pi / (1 - pa - pb)
				vaultingSwayP = function(t)
					if t <= pa or t >= 1 - pb then
						return 0
					else
						return pc * sin(pc * (t - pa))
					end
				end
			end

			function fpp.jumpAction.getVaultingCamSway(dt)
				local vt = (now - vaultingSt) / vaultingDur
				if vt <= 1.2 then
					return degToCf(
							vaultingSwayX(vt), 
							0, 
							vaultingSwayZ(vt)
						) 
						* axisRotCf(pv, vaultingSwayP(vt) * deg)
				else
					return iCf
				end
			end
		end

		function fpp.jumpAction.onDeath()
			setBmEnabled(false)
			exitClimbing()
		end
	end

	fpp.wasdTracker = {}
	do
		fpp.forwardAtmpt = false 	-- the potential for moving forward
		fpp.backAtmpt    = false
		fpp.leftAtmpt    = false
		fpp.rightAtmpt   = false

		local kb = requireGm("Keybindings")

		inputReader.listen("pForward0", "Begin", "Keyboard", kb.moveForward, function()
			fpp.forwardAtmpt = true
			fpp.backAtmpt = false
			fpp.danceAtmpt = false
		end)
		inputReader.listen("pBack0", "Begin", "Keyboard", kb.moveBack, function()
			fpp.forwardAtmpt = false
			fpp.backAtmpt = true
			fpp.danceAtmpt = false
		end)
		inputReader.listen("pLeft0", "Begin", "Keyboard", kb.moveLeft, function()
			fpp.leftAtmpt = true
			fpp.rightAtmpt = false
			fpp.danceAtmpt = false
		end)
		inputReader.listen("pRight0", "Begin", "Keyboard", kb.moveRight, function()
			fpp.rightAtmpt = true
			fpp.leftAtmpt = false
			fpp.danceAtmpt = false
		end)
		inputReader.listen("pForward1", "End", "Keyboard", kb.moveForward, function()
			fpp.forwardAtmpt = false
		end)
		inputReader.listen("pBack1", "End", "Keyboard", kb.moveBack, function()
			fpp.backAtmpt = false
		end)
		inputReader.listen("pLeft1", "End", "Keyboard", kb.moveLeft, function()
			fpp.leftAtmpt = false
		end)
		inputReader.listen("pRight1", "End", "Keyboard", kb.moveRight, function()
			fpp.rightAtmpt = false
		end)
	end

	fpp.sprintAction = {}
	do
		fpp.sprinting = false
		fpp.sprintAtmpt = false
		fpp.sprintingSm = 0
		local sprintSmoother = requireGm("Interpolation").getSmoother(1.5, 0.5)
		fpp.sprintingSp = 0
		local sprintSpring = requireGm("NumericSpring").new(0.8, 0.1, 1.5)

		do-- hold to sprint 
			local sprintKey = requireGm("Keybindings").sprint
			inputReader.listen("sprint0", "Begin", "Keyboard", sprintKey, function()
				fpp.sprintAtmpt = true
				fpp.leaning     = nil
				fpp.crouchAtmpt = false
			end)
			inputReader.listen("sprint1", "End", "Keyboard", sprintKey, function()
				fpp.sprintAtmpt = false
			end)
		end

		function fpp.sprintAction.rs1(dt)
			if not alive then return end
			fpp.sprinting = fpp.sprintAtmpt and fpp.forwardAtmpt and fpp.holding
				and not (fpp.crouching or fpp.aiming or fpp.shooting or fpp.reloading or fpp.vaulting or fpp.climbing or fpp.staminaLock)
			local sprinting_ = fpp.sprinting and 1 or 0
			fpp.sprintingSm = sprintSmoother(fpp.sprintingSm, sprinting_, dt)
			fpp.sprintingSp = sprintSpring.step(dt, sprinting_)

			-- print(string.format("sprintingSm = %.3f", fpp.sprintingSm))
		end
	end

	fpp.leanAction = {}
	do
		local leaningDegMax = 17
		fpp.leaningDeg    = 0
		local leaningDeg_   = 0
		local leaningTime   = 0.22
		local rate          = 0
		local clamp = requireGm("Math").clamp

		-- the only action without "attmpt"
		fpp.leaning = nil

		local leanLeftTS, leanRightTS = -1, -1

		-- note that cuz begin will fire only once

		-- toggle leaning
		inputReader.listen("lean.left", "Begin", "Keyboard", requireGm("Keybindings").leanLeft, function()
			leanLeftTS = TS
		end)
		inputReader.listen("lean.right", "Begin", "Keyboard", requireGm("Keybindings").leanRight, function()
			leanRightTS = TS
		end)		

		function fpp.leanAction.rs1(dt)
			if not alive then return end
			local leaningNew = fpp.leaning
			if leanLeftTS == TS then
				if fpp.leaning == "left" then
					leaningNew = nil
				else
					leaningNew = "left"
				end
			elseif leanRightTS == TS then
				if fpp.leaning == "right" then
					leaningNew = nil
				else
					leaningNew = "right"
				end
			end
			if fpp.leaning ~= leaningNew then
				fpp.leaning = leaningNew
				if leaningNew then
					fpp.sprintAtmpt = false
				end
			end

			local leaningDeg_New = (fpp.leaning == "left" and 1 or fpp.leaning == "right" and -1 or 0) * leaningDegMax
			if leaningDeg_New ~= leaningDeg_ then
				leaningDeg_ = leaningDeg_New
				rate = (leaningDeg_ - fpp.leaningDeg) / leaningTime
			end
			if fpp.leaningDeg ~= leaningDeg_ then
				if rate > 0 then
					fpp.leaningDeg = clamp(fpp.leaningDeg + rate * dt, -100, leaningDeg_)
				else
					fpp.leaningDeg = clamp(fpp.leaningDeg + rate * dt, leaningDeg_, 100)
				end
			end
		end

		local forward = scsClient.forward
		function fpp.leanAction.hb1(dt)
			if not alive then return end
			forward("leaning", fpp.leaning or "mid")
		end
	end

	fpp.staminaSystem = {}
	do
		fpp.staminaLock = false
		fpp.stamina     = 100
		local rate      = 0
		local clamp     = requireGm("Math").clamp
		local bs = requireGm("BreathingSystem").new(lp)
		local adjustBreathing = bs.adjust

		function fpp.staminaSystem.hb1(dt)
			if not alive then return end
			local rate_
			if fpp.vaulting then
				rate_ = -7
			elseif fpp.jumping then
				rate_ = -10
			elseif fpp.sprinting then
				rate_ = -2
			elseif fpp.moving then
				rate_ = 5
			else
				rate_ = 8
			end
			rate = 1 * rate_

			if rate ~= 0 then
				fpp.stamina = clamp(fpp.stamina + dt * rate, 0, 100)
				if fpp.stamina == 0 then
					fpp.staminaLock = true
				end
				if fpp.staminaLock and fpp.stamina >= 25 then
					fpp.staminaLock = false
				end
			end

			adjustBreathing(fpp.stamina)
		end

		-- stop the breathing sound
		function fpp.staminaSystem.onDeath()
			adjustBreathing(100)
		end
	end

	fpp.speedSystem = {}
	do
		local sqrt = math.sqrt
		local function getInstantSpeedV2()
			local hrpv = hrp.Velocity
			return sqrt((hrpv.x)^2 + (hrpv.z)^2)
		end
		local clamp = requireGm("Math").clamp

		fpp.moving = false
		fpp.movingSm = 0
		local movingSmoother = requireGm("Interpolation").getSmoother(3, 0.4)

		-- mouse wheel
		local wheel = 0 
		do
			local wheelMax = 2
			inputReader.listen("mouse.wheel", "Change", "MouseWheel", nil, function(input)
				wheel = clamp(wheel + input.Position.z, -wheelMax, wheelMax)
			end)
		end

		local baseSpeed   = 12
		local idleSpeed   = 5
		local sprintSpeed = 16.5
		local crouchSpeed = 7
		local climbSpeed  = 10
		local speed       = idleSpeed
		local baseAcc     = 15
		fpp.actualSpeed   = 0

		-- wasd have different speed.
		-- only forward will have full speed
		local function getSpeedMult8Dir()
			local ret
			if fpp.forwardAtmpt then
				ret = 1
				if fpp.leftAtmpt or fpp.rightAtmpt then
					ret = .9
				end
			elseif fpp.backAtmpt then
				ret = .6
			else
				ret = .75
			end
			return ret
		end

		function fpp.speedSystem.rs1(dt)
			if not alive then return end
			fpp.moving = getInstantSpeedV2() > 1e-1
			local moving_ = fpp.moving and 1 or 0
			fpp.movingSm = movingSmoother(fpp.movingSm, moving_, dt)

			local speed_
			do-- calculate goal speed
				if not fpp.moving then
					if fpp.climbing then
						speed_ = climbSpeed + wheel * 1.5
					else
						speed_ = idleSpeed
					end
				elseif fpp.crouching then
					speed_ = crouchSpeed
				elseif fpp.sprinting then
					speed_ = sprintSpeed
				else
					speed_ = baseSpeed + wheel
				end
				speed_ = speed_ 
					* ((1 - fpp.aimingSm) * 0.5 + 0.5)
					* getSpeedMult8Dir()
			end

			do-- calculate speed and acc
				local maxAcc = baseAcc * (fpp.sprinting and 2 or 1)
				if speed ~= speed_ then
					local acc
					if speed < speed_ then
						acc   = maxAcc
						speed = clamp(speed + dt * acc, 0, speed_)
					else
						acc   = -maxAcc
						speed = clamp(speed + dt * acc, speed_, 100)
					end
				end				
			end

			do-- assign the speed
				local finalSpeed = speed
				if stats and stats.weight and stats.weight > 1e-1 then
					finalSpeed = finalSpeed / stats.weight
				end
				if fpp.dancing then
					finalSpeed = 0
				end

				humanoid.WalkSpeed = finalSpeed
				fpp.actualSpeed    = fpp.moving and finalSpeed or 0
			end
		end
	end

	-- idle and walking sway.
	-- applied to the right arm or cam (when aiming).
	fpp.swaySystem = {}
	do
		local baseSpeed = 12

		-- localized gun stats
		local swayPivot 
		local swayRotX  
		local swayRotY  
		local swayRotZ  
		local swayTransX 
		local swayTransY 
		local swaySpeed  
		function fpp.swaySystem.onGunEquipped()
			swayPivot  = stats.swayPivot  
			swayRotX   = stats.swayRotX   
			swayRotY   = stats.swayRotY   
			swayRotZ   = stats.swayRotZ   
			swayTransX = stats.swayTransX
			swayTransY = stats.swayTransY
			swaySpeed  = stats.swaySpeed
		end

		local getStepSound = requireGm("FootStepSystem").getStepSound
		local play   = requireGm("AudioSystem").play

		local myMath = requireGm("Math")
		local pi     = math.pi
		local abs    = math.abs
		local max    = math.max
		local sin    = math.sin
		local cos    = math.cos
		local newCf  = CFrame.new
		local degToCf= myMath.degToCf
		local clamp  = myMath.clamp

		-- public final values. rot and trans
		fpp.swayRotX = 0
		fpp.swayRotY = 0
		fpp.swayRotZ = 0
		fpp.swayTransX = 0
		fpp.swayTransY = 0

		fpp.sprintRotY = 0

		-- for varying speed. use additive dt instead of now - initTick.
		local tt1 = 0  -- speed: 1; start: 0;
		local tt2 = 0  -- speed: 2; start: 0;
		local tt3 = pi -- speed: 1; start: pi;
		local tt4 = pi -- speed: 2; start: pi;

		-- scalers:
		local speedScaler = myMath.getLogisticFunction2(0.15, 0.85, 10, 12, 1)
		local sizeScaler = myMath.getLogisticFunction2(0.1, 0.3, 10, 12, 1)

		-- for footsteps
		local function near(a, b) 
			return abs(a - b) < 1e-2
		end
		-- local posOffset = {
		-- 	left = newCf(0, 10, 0),
		-- 	right = newCf(0, -10, 0),
		-- }
		local play = requireGm("AudioSystem").play
		local getStepSound = requireGm("FootStepSystem").getStepSound
		local function playFootStep(side)
			local sound = getStepSound(
				humanoid.FloorMaterial, 
				fpp.crouching and "Crouch" or
				fpp.sprinting and "Run" or
											    "Walk"
			)
			play(sound, "2D")
			-- play(sound, (hrp.CFrame * posOffset[side]).p)
		end

		function fpp.swaySystem.rs2(dt)
			if not alive then return end

			-- moving sway
			local movingSm = fpp.movingSm^3
			local s = fpp.sprintingSm
			local swaySpeed_ = swaySpeed * speedScaler(humanoid.WalkSpeed) * (s * 1 + (1 - s) * 1 / 1.1)
			local swaySizeMult = movingSm * sizeScaler(humanoid.WalkSpeed)

			-- print(string.format("speed = %.2f, speedScaler = %.2f, finalSwaySpeed = %.2f, sizeScaler = %.2f", humanoid.WalkSpeed, speedScaler(humanoid.WalkSpeed), speedScaler(humanoid.WalkSpeed) * (s * 1 + (1 - s) * 1 / 1.1), sizeScaler(humanoid.WalkSpeed)))
			
			local tt1_ = tt1
			tt1 = tt1 + dt * swaySpeed_
			local movingSwayTransX = swaySizeMult * sin(tt1) * swayTransX

			tt2 = tt2 + dt * swaySpeed_ * 2
			local movingSwayTransY = swaySizeMult * sin(tt2) * swayTransY

			tt3 = tt3 + dt * swaySpeed_ * 2
			local movingSwayRotX   = swaySizeMult * sin(tt3) * swayRotX

			tt4 = tt4 + dt * swaySpeed_
			local movingSwayRotY   = swaySizeMult * sin(tt4) * swayRotY
			local movingSwayRotZ   = swaySizeMult * sin(tt4) * swayRotZ

			-- idleSway
			local tt = (now - initTick) * 3
			local idleSm = 1 - movingSm
			local idleSwayRotY = idleSm * sin(tt) * 0.2
			local idleSwayRotX = idleSm * cos(tt) * 0.5

			fpp.swayTransX = movingSwayTransX
			fpp.swayTransY = movingSwayTransY
			fpp.swayRotX   = movingSwayRotX + idleSwayRotX
			fpp.swayRotY   = movingSwayRotY + idleSwayRotY
			fpp.swayRotZ   = movingSwayRotZ

			-- footstep
			if fpp.moving then
				local thisSin = sin(tt1)
				local lastSin = sin(tt1_)
				if near(thisSin, 1) and not near(lastSin, 1) then 
					playFootStep("right")
				elseif near(thisSin, -1) and not near(lastSin, -1) then
					playFootStep("left")
				end
			end

			-- sprinting augmentation
			fpp.sprintRotY = s * sin((now - initTick) * 2.5) * 7
		end
	end


	fpp.statsPanel = {}
	if db.statsPanel then
		local clone   = game.Clone
		local ffc     = game.FindFirstChild
		local connect = game.Changed.Connect

		local oldSg = ffc(wfc(lp, "PlayerGui"), "StatsPanel")
		if oldSg then
			oldSg:Destroy()
		end
		local sg = clone(wfc(script, "StatsPanel"))
		sg.Parent = wfc(lp, "PlayerGui")
		local list = wfc(sg, "List")
		local temp = wfc(list, "temp")
		temp.Parent = nil

		local statsCons = {}
		function fpp.statsPanel.loadStats()
			for i, con in ipairs(statsCons) do
				con:Disconnect()
				statsCons[i] = nil
			end
			for _, v in ipairs(list:GetChildren()) do
				if v:IsA("Frame") then
					v:Destroy()
				end
			end
			local function addBar(k, v, t)
				local fr          = clone(temp)
				fr.TextBox.Text   = v
				fr.TextLabel.Text = k
				fr.Name           = k
				fr.Parent         = list

				local textBox = fr.TextBox
				local last = t ~= "string" and tonumber(textBox.Text) or textBox.Text

				statsCons[#statsCons + 1] = connect(textBox.FocusLost, function(e)
					if not e then
						textBox.Text = tostring(last)
						return
					end
					local val = t ~= "string" and tonumber(textBox.Text) or textBox.Text
					last = val
					stats[k] = val

					fpp.shellSystem.onGunEquipped()
					fpp.reticleSystem.onGunEquipped()
					fpp.aimGunAction.onGunEquipped()
					fpp.shootGunAction.onGunEquipped()
					fpp.recoilSystem.onGunEquipped()
					fpp.swaySystem.onGunEquipped()
					fpp.hitSystem.onGunEquipped()
				end)
				if t == "string" then
					statsCons[#statsCons + 1] = connect(textBox.Focused, function()
						textBox.Text = last
					end)
				end
			end
			for k, v in pairs(stats) do
				if type(v) == "number" then
					addBar(k, v, type(v))
				elseif k == "recoilYPattern" then
					addBar(k, v, type(v))
				end
			end
		end
	end

	fpp.reticleSystem = {}
	do
		local reticle
		local reticleExt
		function fpp.reticleSystem.onGunEquipped()
			reticle    = gun.aniData.reticle
			reticleExt = gun.aniData.reticleExt
		end
		function fpp.reticleSystem.onGunUnequipped()
			reticle, reticleExt = nil, nil
		end
		function fpp.reticleSystem.rs2(dt)
			local reticleTrans = 1 - fpp.aimingSm^3 * aliveSm
			if reticle then
				reticle.Transparency = reticleTrans
			end
			if reticleExt then
				for _, v in ipairs(reticleExt) do
					v.Transparency = reticleTrans
				end
			end
		end
	end

	fpp.shellSystem = {}
	do
		local shellTemp
		local p0Brick
		local d0Brick

		function fpp.shellSystem.onGunEquipped()
			shellTemp = gun.aniData.shell
			shellTemp.Anchored = true
			p0Brick = aniparts.ShellP0
			d0Brick = aniparts.ShellD0
			-- fpp.shellSystem.clear()
		end

		local g = 98.4
		local s = 15
		local shells, l, r = {}, 1, 0
		local sz = 5  -- 10 shells max
		local expireTime = 1

		local myMath = requireGm("Math")
		local mod = myMath.mod
		local function inc(i)
			return mod(i, sz) + 1
		end

		do -- _createshell
			local clone        = game.Clone
			local randomDouble = myMath.randomDouble
			local cylToCf      = myMath.cylToCf
			local degToCf      = myMath.degToCf
			local clamp        = myMath.clamp
			local newV3        = Vector3.new
			local destroy      = game.Destroy
			function fpp.shellSystem._createShell()  -- returns a shell. dont modify the shells
				local shell = {}
				-- a shell can have 3 states: active. model-destroyed. mem-freed.

				-- should be put in non hitbox
				local model  = clone(shellTemp)
				local p0 = p0Brick.CFrame
				local d0 = d0Brick.CFrame
				model.CFrame = p0 * cylToCf(randomDouble(-20, 20), randomDouble(-20, 20))
				model.Parent = char

				local d   = randomDouble(-25, -10)
				local v0  = (d0 * degToCf(d, 0, 0)).lookVector * s
				local t   = 0
				
				function shell.rsStep(dt, now)
					t = clamp(t + dt, 0, expireTime)
					model.Position = p0.p + newV3(
						v0.x * t ,
						v0.y * t - 0.5 * g * t * t,
						v0.z * t
					)
					-- model.Position = d0.p + v0 * 2
					if t == expireTime then
						shell.destroy()
					end
				end
				function shell.destroy()
					destroy(model)
					shell.destroyed = true
				end

				return shell
			end
		end

		do -- createShell: modifies the queue
			local _createShell = fpp.shellSystem._createShell
			local myMath = requireGm("Math")
			function fpp.shellSystem.createShell() 
				local shell = _createShell()				

				r = inc(r)
				if r == l and shells[l] then
					shells[l].destroy()
					l = inc(l)
				end
				shells[r] = shell
			end
		end

		function fpp.shellSystem.rs2(dt)
			if r == 0 then return end
			local _r = r < l and r + sz or r
			for i = l, _r do
				i = mod(i - 1, sz) + 1
				local shell = shells[i]
				if shell and not shell.destroyed then
					shell.rsStep(dt)
				else
					l = inc(l)
				end
			end
		end
	end

	fpp.aimGunAction = {}
	do
		local aimPart
		local aimMult
		local aimTime

		local sqrt = math.sqrt

		function fpp.aimGunAction.onGunEquipped()
			aimPart = aniparts.AimPart
			aimMult = sqrt(stats.aimMult)
			aimTime = stats.aimTime
		end
		function fpp.aimGunAction.onGunUnequipped()
			aimPart = nil
		end

		fpp.aimAtmpt = false
		inputReader.listen("mouse.aim0", "Begin", "MouseButton2", nil, function()
			fpp.aimAtmpt = true			
			fpp.sprintAtmpt = false
		end)
		inputReader.listen("mouse.aim1", "End", "MouseButton2", nil, function()
			fpp.aimAtmpt = false
		end)
		inputReader.listen("aimKey", "Begin", "Keyboard", requireGm("Keybindings").aimKey, function()
			fpp.aimAtmpt = not fpp.aimAtmpt
		end)

		local aiming_ = false 		-- starts to aim
		fpp.aiming    = false 				-- isAiming
		fpp.aimingSm  = 0	  
		local aimingT = 0

		do -- rs1
			local clamp        = requireGm("Math").clamp
			local scopeInCurve = requireGm("Easing").getEasingInOut(2)
			local play = requireGm("AudioSystem").play
			function fpp.aimGunAction.rs1(dt)
				if not alive then return end
				local aiming_New = fpp.aimAtmpt and fpp.holding
					and not (fpp.sprinting or fpp.vaulting or fpp.climbing or fpp.blocking or fpp.dancing) 
				if aiming_New ~= aiming_ then
					aiming_ = aiming_New
					play("Aim", "2D")
				end

				local tDir   = aiming_ and 1 or -1 
				aimingT      = clamp(aimingT + tDir * dt / aimTime, 0, 1)
				fpp.aimingSm = scopeInCurve(aimingT)
				fpp.aiming   = fpp.aimingSm > 0.9
			end
		end

		do -- hb1
			local forward = scsClient.forward
			function fpp.aimGunAction.hb1(dt)
				if not alive then return end
				forward("aiming", fpp.aimingSm > 0.2)
			end
		end
	end

	fpp.hitSystem = {}
	do
		local ido   = game.IsDescendantOf
		local chars = workspace.Chars
		local ffc   = game.FindFirstChild
		local play  = requireGm("AudioSystem").play
		local pwd   = game.GetFullName

		local bodypartDmgModfier = {
			Head = "oneShot",
			LeftFoot      = 0.67,
			LeftHand      = 0.67,
			LeftLowerArm  = 0.67,
			LeftLowerLeg  = 0.67,
			LeftUpperArm  = 0.75,
			LeftUpperLeg  = 0.75,
			RightFoot     = 0.67,
			RightHand     = 0.67,
			RightLowerArm = 0.67,
			RightLowerLeg = 0.67,
			RightUpperArm = 0.75,
			RightUpperLeg = 0.75,
			LowerTorso    = 1,
			UpperTorso    = 1,
		}

		local get = requireGm("PublicVarsClient").get
		local alivesF = wfc(wfc(rep, "SharedVars"), "Alives")

		local createParticle = requireGm("ParticleSystem").onHit
		local createBulletHole = requireGm("BulletHoleSystem").onHit

		local dist0, dist1, dmg0, dmg1, dist_

		function fpp.hitSystem.onGunEquipped()
			dist0 = stats.dist0
			dist1 = stats.dist1
			dist_ = dist1 - dist0
			dmg0  = stats.dmg0
			dmg1  = stats.dmg1
		end

		local myMath = requireGm("Math")
		local clamp  = myMath.clamp
		local lerp   = myMath.lerp
		local little = db.littleDamage and 0.01 or 1
		local min    = math.min

		local function getDmg(hit, dist, impactLeft)
			local modifier = bodypartDmgModfier[hit.Name]
			local dmg 
			if not modifier then
				warn(string.format("%s shouldn't be shootable. no damage dealt", hit.Name))
			else
				if modifier == "oneShot" then
					dmg = 100
					play("HitHead", "2D")
				else
				  dmg = impactLeft * modifier * lerp(
				  	dmg0, 
				  	dmg1, 
				  	clamp((dist - dist0) / dist_, 0, 1)
				  )
				  play("HitBody", "2D")
				end
				dmg = min(dmg * little, 100)
			end
			return dmg
		end

		local sub = string.sub

		function fpp.hitSystem.getOnHit(p0, v0)
			local hitCnt = 0
			local hitPlrs = {}

			-- print("\nfired:")

			return function(hit, p1, normal, mat, impactLeft, dist)
				-- bullet holes
				if db.bulletHoles then
					createBulletHole(p1, normal)
				end

				-- particle creation
				hitCnt = hitCnt + 1
				-- if hitCnt == 1 then
					createParticle(hit, p0, p1, mat, lp)
				-- end

				-- breakable objects
				if ffc(hit, "BreakableId") and ffc(hit, "BreakableType") then
					dynClient.fireServer(
						"destroy", 
						hit.BreakableId.Value, 
						hit.BreakableType.Value
					)
				end				

				-- shooting dummies
				local pName = hit.Parent.Name
				if sub(pName, 1, 2) == "SD" then
					if not hitPlrs[pName] then
						hitPlrs[pName] = true
						local dmg = getDmg(hit, dist, impactLeft)
					  print(string.format("[%d] hit target %d studs away with %.1f damage at %s using %s", hitCnt, dist, dmg, hit.Name, gun.weaponName))							  	
					end
					return
				end

				-- damage system
				local hitPlr, dmg
				if ido(hit, chars) then

					-- check if the bullet hits a player
					local hitChar = hit.Parent
					hitPlr  = ffc(plrs, hitChar.Name)
					if not hitPlr then
						warn(string.format("shoot.hit: player %s not found, aborted", hitChar.Name))
					else

						-- check if the player can be killed
					  if not (get("Phase") ~= "Match:Intermission" 
					  	and (db.teamKillEnabled or lp.Team ~= hitPlr.Team) 
					  	and ffc(alivesF, hitPlr.Name)) then
					  	warn("trying to deal damage to the player but phase/team not valid or that plr is not alive")
					  else

					  	-- get damage
					  	local dmg_ = getDmg(hit, dist, impactLeft)
					  	if dmg_ then

					  		-- check if the player is already shot by this bullet
								if hitPlrs[hitPlr.Name] then
									warn(hitPlr, "has been hit with this bullet before. skipped")

								else
									hitPlrs[hitPlr.Name] = true
									dmg = dmg_
								end
					  	end
					  end
					end
				end

				-- replication
				fpsClient.fireServer("bulletHit", hit, p1, hitPlr, dmg)
			end
		end
	end

	fpp.shootGunAction = {}
	do
		local rps
		local spr
		local firePoint
		local aimPart
		local ms
		local shootSound
		local spread
		local flashMult
		local smokeMult
		local lightMult

		local slideP  
		local slideDir
		local slideSp 

		local bulletWidth
		local bulletLength
		local bulletGrav
		local bulletPen
		local bulletDrag
		local bulletDist
		local bulletSpeed
		local bulletShowDist
		local bulletColor

		do -- on gun equipped / un equipped
			local max = math.max
			local min = math.min
			function fpp.shootGunAction.onGunEquipped()
				firePoint  = aniparts.FirePoint
				aimPart    = aniparts.AimPart
				ms = requireGm("MuzzleSystem").new(firePoint)
				fpp.shootingSm = 0

				rps = stats.rps
				spr = 1 / rps

				spread = stats.spread

				flashMult = stats.suppressed and 0 or stats.flashMult
				smokeMult = stats.smokeMult
				lightMult = stats.lightMult  

				shootSound = sounds[stats.suppressed and "ShootSuppressed" or "Shoot"]

				slideP   = 0
				slideDir = 0
				slideSp  = max(rps, 15)

				-- @todo stats page
				bulletDist   = stats.dist2
				bulletWidth  = stats.bulletWidth
				bulletLength = stats.bulletLength
				bulletGrav   = stats.bulletGrav
				bulletPen    = stats.bulletPen
				bulletDrag   = stats.bulletDrag
				bulletSpeed  = stats.bulletSpeed
				bulletShowDist = stats.bulletShowDist
				bulletColor = stats.bulletColor
			end
			function fpp.shootGunAction.onGunUnequipped()
				firePoint = nil
			end
		end

		fpp.shooting   = false
		fpp.shootingSm = 0
		fpp.shootAtmpt = false
		fpp.bursting   = false
		local shootReady           = false
		local shootTS              = -1
		local noBulletsSoundPlayed = false
		local lastShootTick        = -1
		local lastReadyTick        = -1
		local shotsSprayed = 0 	-- shotsSprayed > shotsBeforeRecoilY --> horizontal recoil

		do-- shoot once
			local incRecoil   = fpp.recoilSystem.incRecoil
			local createShell = fpp.shellSystem.createShell
			local noise       = math.noise
			local myMath      = requireGm("Math")
			local degToCf     = myMath.degToCf
			local cfLerp      = myMath.cfLerp
			local iCf         = myMath.iCf
			local getOnHit    = fpp.hitSystem.getOnHit
			local play        = requireGm("AudioSystem").play
			local forward     = fpsClient.forward
			local incRecoilY  = fpp.recoilSystem.incRecoilY
			local createProjectile = projectileHandler.createProjectile

			local back = CFrame.new(0, 0, -4)

			function fpp.shootGunAction.shootOnce()
				shotsSprayed = shotsSprayed + 1
				shootTS = TS
				lastShootTick = now
				incRecoil(shotsSprayed)
				incRecoilY(shotsSprayed)
				createShell()
				play(shootSound, "2D")
				play("GunMechanics", "2D")
				ms.shoot(flashMult, smokeMult, lightMult)
				gun.currBullets = gun.currBullets - 1

				-- raycasting
				local p0, v0
				if fpp.aiming then
					p0 = aimPart.Position
					v0 = - aimPart.CFrame.lookVector * bulletSpeed
				else
					local tt       = (now - initTick) * 5
					local scale    = spread
					local spreadCf = firePoint.CFrame * cfLerp(degToCf(scale * noise(tt + 34.44), scale * noise(tt), scale * noise(tt - 33.33)), iCf, fpp.crouchingSm * 0.25)
					p0 = (firePoint.CFrame * back).p
					v0 = - spreadCf.lookVector * bulletSpeed
				end
				createProjectile(p0, v0, {
					width    = bulletWidth,
					length   = bulletLength,
					grav     = bulletGrav,
					pen      = bulletPen,
					drag     = bulletDrag,
					maxDist  = bulletDist,
					color    = bulletColor,
					rayWl    = rayWls.shootable,
					showDist = bulletShowDist,
					onHit    = getOnHit(p0, v0),
				})
			end
		end

		do-- burst
			local shootOnce = fpp.shootGunAction.shootOnce
			function fpp.shootGunAction.burst(r)
				fpp.bursting = true
				spawn(function()
					for i = 1, r do
						shootOnce()
						if i < r then
							wait(spr / 1.5)
						end
					end
				end)
				delay(spr * 5, function()
					fpp.bursting = false
				end)
			end
		end


		do -- attemptToShoot
			local play      = requireGm("AudioSystem").play
			local shootOnce = fpp.shootGunAction.shootOnce
			local floor     = math.floor
			local min       = math.min
			local burst     = fpp.shootGunAction.burst

			function fpp.shootGunAction.attemptToShoot(dt)
				local d1 = now - lastReadyTick
				local d2 = now - lastShootTick
				local b  = gun.currBullets + (db.infiniteAmmo and 1000000 or 0)
				if b == 0 then
					if not noBulletsSoundPlayed then
						noBulletsSoundPlayed = true
						play("NoBullets", "2D")
					end
				end
				local hasBullets = b > 0 

				if gun.fireMode == "auto" then
					if d2 >= spr and hasBullets then
						local r = min(floor(d2 < d1 and d2/spr or 1), b)
						for i = 1, r do
							shootOnce()
						end
					end

				elseif gun.fireMode == "single" then
					if d2 >= spr and hasBullets then
						shootOnce()
						fpp.shootAtmpt = false
					end

				elseif gun.fireMode == "burst" then
					if d2 >= spr and hasBullets and not fpp.bursting then
						fpp.shootAtmpt = false
						burst(min(3, b))
					end

				else
					warn("unsupported firemode", gun.fireMode)
				end
			end
		end

		inputReader.listen("shoot0", "Begin", "MouseButton1", nil, function()
			fpp.shootAtmpt = true
			fpp.sprintAtmpt = false
			fpp.danceAtmpt = false
		end)
		inputReader.listen("shoot1", "End", "MouseButton1", nil, function()
			fpp.shootAtmpt = false
		end)

		do -- rs1
			local attemptToShoot = fpp.shootGunAction.attemptToShoot
			function fpp.shootGunAction.rs1(dt)
				if not alive then return end
				local shootReadyNew = fpp.bursting or (fpp.shootAtmpt and fpp.holding)
				if shootReady ~= shootReadyNew then
					shootReady           = shootReadyNew
					noBulletsSoundPlayed = false
					lastReadyTick        = now
				end
				if shootReady then
					attemptToShoot(dt)
				else
					-- stops holding
					-- shotsSprayed = 0
				end
				fpp.shooting = shootTS == TS
				-- fpp.shootingSm = shootingSmoother()

				if now - lastShootTick > spr * 2 then
					shotsSprayed = 0
				end

				-- print(fpp.holding, fpp.reloading, fpp.equipping, fpp.unequipping, fpp.vaulting, fpp.aiming, fpp.sprinting)
			end
		end

		do -- animation rs step
			local myMath = requireGm("Math")
			local clamp  = myMath.clamp
			local newV3  = Vector3.new
			local noise  = math.noise
			local random = math.random

			fpp.shootingRandomSway = 0
			local smoother = requireGm("Interpolation").getSmoother(2, 0.8)

			fpp.shootingFovNoise = 0
			local fovNoise = 0
			local fovNoiseSmoother = requireGm("Interpolation").getSmoother(100, 0.8)

			function fpp.shootGunAction.rs2(dt)
				-- bolt / slide
				if fpp.shooting and alive then
					slideDir = 1
					slideP   = 0
				end
				if slideDir ~= 0 then
					slideP = clamp(slideP + slideDir * dt * slideSp, 0, 1)
				end
				if slideP == 1 then
					slideDir = -1
				elseif slideP == 0 then
					slideDir = 0
				end
				joints.WeaponBolt.C0 = defC0.WeaponBolt + newV3(0, 0, - slideP * stats.slideLength)

				-- shooting random sway
				local tt   = now - initTick
				local rot_ = noise(tt * 5) * fpp.shootingSm * 20 
				fpp.shootingRandomSway = smoother(fpp.shootingRandomSway, rot_, dt)

				-- shooting fov noise
				-- local fovNoise_ = (random() - 0.5) * 4 * fpp.recoilZ * stats.recoilFov
				-- fovNoise = fovNoiseSmoother(fovNoise, fovNoise_, dt)
				-- fpp.shootingFovNoise = fovNoise * fpp.shootingSm
				if ms then
					ms.step() 
				end
			end
		end
	end

	fpp.cycleFireModeGunAction = {}
	do
		-- no animation currently. so takes no time
		local play = requireGm("AudioSystem").play
		inputReader.listen("cycleFireMode", "Begin", "Keyboard", requireGm("Keybindings").cycleFireMode, function()
			fpp.shootAtmpt = false
			if not fpp.bursting or fpp.reloading or fpp.vaulting or fpp.blocking then
				gun.fireMode = stats.supportedFireModes[gun.fireMode]
				play("FiremodeSwitch", "2D")
			end
		end)
	end

	fpp.reloadGunAction = {}
	do
		local reloadTS 
		inputReader.listen("reload", "Begin", "Keyboard", requireGm("Keybindings").reload, function()
			reloadTS = TS
			fpp.danceAtmpt = false
		end)
		fpp.reloading = false

		local function onReloaded()
			fpp.reloading = false
			fpp.holding = true

			gun.bkupBullets = gun.bkupBullets + gun.currBullets
			gun.currBullets = 0

			local newBullets = math.min(stats.magSize, gun.bkupBullets + gun.currBullets)
			gun.currBullets = newBullets
			gun.bkupBullets = gun.bkupBullets - newBullets

			-- print("reload end")
		end

		function fpp.reloadGunAction.rs1(dt)
			if not alive then return end
			local reloadingNew = fpp.reloading or ((reloadTS == TS) and gun and gun.currBullets ~= stats.magSize and fpp.holding and not fpp.vaulting and not fpp.climbing)
			if reloadingNew ~= fpp.reloading then
				fpp.reloading = reloadingNew
				if reloadingNew then
					kfs.load(fppAnimations, "reloading", {callback = onReloaded})
					fpp.holding = false
				end
			end
		end
	end

	fpp.equipGearAction = {}
	do
		-- local gearIdx__ = nil
		local gearIdx_  = 1
		local gearIdx   = 1
		local switching = false
		fpp.equipping   = false
		fpp.unequipping = false

		-- dynamic skin handler is temporarily here
		local skinStep = nil

		do-- listen to keys
			inputReader.listen("equip.primary", "Begin", "Keyboard", requireGm("Keybindings").weapon1, function()
				gearIdx_ = 1
			end)
			inputReader.listen("equip.secondary", "Begin", "Keyboard", requireGm("Keybindings").weapon2, function()
				gearIdx_ = 2
			end)			
		end


		do -- preload
			local wc = requireGm("WeaponCustomization")
			local nsToArray = requireGm("NumberSequence").toArray
			function fpp.equipGearAction.preload(slotId)
				local slot = gearSlots[slotId]
				local model, stats, aniData, _, skinStep = wc.get(slot.weaponName, slot.attachments, "fpp")
						
				if not db.statsPanel then
					stats.recoilYPattern, stats.recoilYPatternLength = nsToArray(stats.recoilYPattern)
					stats.recoilYLast = stats.recoilYPattern[stats.recoilYPatternLength - 1]
				end

				-- bad examples here
				-- stats.aimMult = math.sqrt(stats.aimMult)
				-- stats.weight = 1 + (stats.weight - 1) / 3

				slot.model    = model
				slot.stats    = stats
				slot.aniData  = aniData
				slot.skinStep = skinStep

				slot.id          = slotId -- not necessarily the slot id, maybe changed if we have weapon picking up system
				slot.bkupBullets = db.infiniteAmmo and 3000 or stats.totalBullets
				slot.currBullets = stats.magSize
				slot.fireMode    = stats.supportedFireModes.default

				--debug: temporary stats

				slot.simplifiedTable = {
					weaponName  = slot.weaponName, 
					attachments = slot.attachments,
					skin        = slot.skin,
					id          = slot.id,
				}
			end
			for i = 1, #gearSlots do
				fpp.equipGearAction.preload(i)
			end
		end		
		do -- equip/unequip weapon
			local pwd = game.GetFullName
			local forward = fpsClient.forward 
			forward("gearIdx", 1)  -- currently only this needs to be initialzed on spawn

			function fpp.equipGearAction.equip(gearIdx_) 	-- assume it is a gun
				gearIdx = gearIdx_
				gun   = gearSlots[gearIdx]
				stats = gun.stats

				-- load the skinstep
				skinStep = gun.skinStep

				do-- load animations into animation table
					for trackName, track in pairs(gun.aniData.fppAnimations) do
						track.name               = trackName
						fppAnimations[trackName] = track
					end
				end

				do -- load aniparts, joints, and def c0
					local ffcWia = game.FindFirstChildWhichIsA
					for pn, part in pairs(gun.aniData.aniparts) do
						-- assert(aniparts[pn] == nil, string.format("loading new gun %s, aniparts[%s] is taken by", gun.weaponName, pn, aniparts[pn] and pwd(aniparts[pn])))
						aniparts[pn] = part
						joints[pn]   = ffcWia(part, "Motor6D")
						if joints[pn] then
							defC0[pn] = joints[pn].C0
						else
							warn("fpp equipweapon: joints[", pn, "] is nil")
						end
					end
				end


				do -- load sounds
					for sn, sound in pairs(gun.aniData.sounds) do
						assert(sounds[sn] == nil, string.format("equipweapon: sounds[%s] is taken", sn))
						sounds[sn] = sound
					end
				end

				do-- connect the model to the player
					local model        = gun.model
					stash.FppGun       = model
					model.Parent       = stash.charNH2
					local gunMainJoint = joints.WeaponMain
					assert(gunMainJoint.Part1)
					gunMainJoint.Part0 = aniparts.FppRightArm
				end

				kfs.update(aniparts, joints, defC0, stash)

				do -- set firepoint to cancollide
					aniparts.AimPart.CanCollide = true
				end

				fpp.shellSystem.onGunEquipped()
				fpp.reticleSystem.onGunEquipped()
				fpp.aimGunAction.onGunEquipped()
				fpp.shootGunAction.onGunEquipped()
				fpp.recoilSystem.onGunEquipped()
				fpp.swaySystem.onGunEquipped()
				fpp.hitSystem.onGunEquipped()
				if fpp.statsPanel.loadStats then
					fpp.statsPanel.loadStats()
				end

				forward("gearIdx", gearIdx)
			end
			function fpp.equipGearAction.unequip()
				do -- disconnect model
					joints.WeaponMain.Part0 = nil
					gun.model.Parent        = nil
				end
				do-- unload animations
					for trackName, track in pairs(gun.aniData.fppAnimations) do
						fppAnimations[trackName] = nil
					end
				end
				do-- unload sounds
					for sn, sound in pairs(gun.aniData.sounds) do
						sounds[sn] = nil
					end
				end
				do -- unload aniparts, joints, defC0
					local cachedAniparts = gun.aniData.aniparts
					for pn, part in pairs(cachedAniparts) do
						kfs.interpolators[pn] = nil
						if cachedAniparts[pn] ~= aniparts[pn] then
							cachedAniparts[pn] = aniparts[pn]
							-- print("gun part changed and replaced", pn)
						end
						aniparts[pn] = nil
						joints[pn]   = nil
						defC0[pn]    = nil
					end
				end

				do-- unload everything	
					fpp.shootGunAction.onGunUnequipped()
					fpp.aimGunAction.onGunUnequipped()
					fpp.reticleSystem.onGunUnequipped()
					stash.FppGun = nil
					gun = nil
					stats = nil
					skinStep = nil
				end
			end
			fpp.equipGearAction.equip(1)
		end

		function fpp.equipGearAction.rs1(dt)
			if not alive then return end
			if gearIdx ~= gearIdx_ then
				if not fpp.unequipping then
					fpp.unequipping = true
					fpp.equipping   = false
					fpp.holding     = false
					fpp.reloading   = false   -- cancel reloading but does not trigger the callback

					-- print("unequipping start")
					kfs.load(fppAnimations, "unequipping", {fitLength = 0.3, callback = function()
						fpp.equipGearAction.unequip()
						fpp.equipGearAction.equip(gearIdx_)
						-- print("unequipping end")
					end})
				end
			else
				if fpp.unequipping then
					fpp.unequipping = false
					fpp.equipping   = true

					-- print("equipping start")
					kfs.load(fppAnimations, "equipping", {fitLength = 0.3, callback = function()
						fpp.equipping = false
						fpp.holding   = true
						-- print("equipping end")
					end})
				end
			end
			if skinStep then
				skinStep(dt)
			end
		end
	end

	fpp.danceAction = {}
	do
		fpp.danceAtmpt = false
		fpp.dancing = false
		local danceAtmptTS = -1

		local danceName = loadout1.dance
		assert(danceName)

		local setCharVisibility = requireGm("RigHelper").setCharVisibility

		inputReader.listen("dance0", "Begin", "Keyboard", requireGm("Keybindings").dance, function()
			danceAtmptTS = TS
			fpp.danceAtmpt = true -- cancelled directly by other actions
		end)
		
		local function loadDanceAnimation()
			kfs.load(tppAnimations, danceName, {reload = true, snapFirstFrame = false})
		end

		local function resetTppAnimation()
			joints.LowerTorso.C0 = CFrame.new()
			kfs.clearInterpolators()
		end

		local hintFr = fpp.fppGuiInit.getNewGui("DancingHint")
		hintFr.Visible = false
		fpp.fppGuiInit.insertGui(hintFr, fpp.staticFr)

		local forward = fpsClient.forward
		function fpp.danceAction.rs1(dt)
			if not alive then return end
			local dancingNew = fpp.danceAtmpt and fpp.holding and not (fpp.jumping or fpp.vaulting or fpp.planting or fpp.defusing or fpp.crouching)
			if not dancingNew and danceAtmptTS == TS then
				fpp.danceAtmpt = false
			end
			if fpp.dancing == dancingNew then
				if dancingNew and danceAtmptTS == TS then -- redance!
					loadDanceAnimation()
					forward("redance")
				end
			else
				fpp.dancing = dancingNew
				if dancingNew then
					humanoid.AutoRotate = false 	-- to fix the angle issue
					loadDanceAnimation()
					hintFr.Visible = true
				else
					humanoid.AutoRotate = true
					resetTppAnimation()
					hintFr.Visible = false
				end
				fpp.mouseLockSystem.setLocked(not dancingNew)
				-- fpp.camLockSystem.setLocked(not dancingNew)

				setCharVisibility("fpp", not dancingNew, char, aniparts, fpp.skinObjs, {skin = spawnArgs.skin, gunModel = gun and gun.model, charNH = stash.charNH2, gunHolder = stash.charNH2})
				-- setCharVisibility("tpp", dancingNew, char, aniparts, fpp.skinObjs, {skin = spawnArgs.skin})--, looky = fpp.looky, hrpy = fpp.hrpy, tppLookJoint = joints.TppLook})
			end
		end
	end

	fpp.gunStanceDeterminer = {}
	do
		local load = kfs.load

		function fpp.gunStanceDeterminer.rs1(dt)
			if not alive then return end
			if not (fpp.vaulting or fpp.reloading or fpp.equipping or fpp.unequipping or fpp.dancing) then -- these actions have already set fpp.holding. and have call backsand do not overlap each other
				if fpp.planting or fpp.defusing or fpp.climbing or fpp.blocking then
					fpp.holding = false  --
					load(fppAnimations, "lowering") 
				elseif fpp.sprinting then
					fpp.holding = true
					load(fppAnimations, "sprinting")
				else
					fpp.holding = true
					load(fppAnimations, "holding") 
				end
			end
		end

		local forward = scsClient.forward
		function fpp.gunStanceDeterminer.hb1()
			if not alive then return end
			local upperStance
			if fpp.planting or fpp.defusing or fpp.blocking or fpp.unequipping or fpp.climbing then
				upperStance = "lowering"
			elseif fpp.reloading then
				upperStance = "reloading"
			elseif fpp.equipping then
				upperStance = "drawing"
			else
				upperStance = "holding"
			end
			forward("upperStance", upperStance)
		end
	end

	fpp.extraReplications = {}
	do
		local forward = scsClient.forward

		function fpp.extraReplications.hb1()
			if not alive then return end
			local fullbodyStance
			if fpp.dancing then
				fullbodyStance = "dancing"
			elseif fpp.vaulting then
				fullbodyStance = "vaulting"
			elseif fpp.climbing then
				fullbodyStance = "climbing"
			elseif fpp.sprinting then
				fullbodyStance = "sprinting"
			-- elseif not fpp.moving then
			-- 	fullbodyStance = "idle"
			-- else
			-- 	fullbodyStance = "walking"
			else
				fullbodyStance = "none"
			end
			forward("fullbodyStance", fullbodyStance)

			local lowerStance
			if fpp.jumping then
				lowerStance = "jumping"
			elseif fpp.crouching then
				lowerStance = "crouching"
			else
				lowerStance = "standing"
			end
			forward("lowerStance", lowerStance)
		end
	end

	fpp.velocityTiltSystem = {}
	do
		local springX = requireGm("NumericSpring").new(2, 0.5, 0.1)
		local springZ = requireGm("NumericSpring").new(1.3, 0.5, 0.15)
		fpp.velTiltX  = 0
		fpp.velTiltZ  = 0

		function fpp.velocityTiltSystem.rs2(dt)
			fpp.velTiltX = springX.step(dt, fpp.forwardAtmpt and -1 or fpp.backAtmpt and 1 or 0)
			fpp.velTiltZ = springZ.step(dt, fpp.rightAtmpt and -1 or fpp.leftAtmpt and 1 or 0)
		end
	end

	-- handles the rootjoint's transform
	-- and then left/right arms' transform
	fpp.inertiaJointHandler = {}
	do
		local myMath  = requireGm("Math")
		local newCf   = CFrame.new
		local degToCf = myMath.degToCf
		local cfLerp  = myMath.cfLerp
		local clamped = myMath.clamped
		local sin     = math.sin
		local iCf     = newCf()
		local pi      = math.pi
		local invCf   = CFrame.new().inverse
		local lerp    = myMath.lerp

		local rootJoint  = joints.FppRoot
		local root       = aniparts.FppRoot
		local rightJoint = joints.FppRightArm
		local rightArm   = aniparts.FppRightArm
		local leftJoint  = joints.FppLeftArm
		local leftArm    = aniparts.FppLeftArm
		local lookJoint  = joints.FppLook

		local function transformArms(cf)
			local pivot = lerp(stats.swayPivot, 0.5, fpp.sprintingSm)
			cf = newCf(0, 0, -pivot) * cf * newCf(0, 0, pivot)

			rightJoint.Transform = cf

			local rt = root.CFrame
			local y = leftJoint.C0
			local r = rightArm.CFrame
			leftJoint.Transform = invCf(y) * invCf(rt) * r * cf * invCf(r) * rt * y
		end

		local sin = math.sin

		function fpp.inertiaJointHandler.rs2(dt)
			if not alive then return end
			
			local mouseInertiaY = fpp.mouseInertiaY
			local mouseInertiaX = fpp.mouseInertiaX
			local landingSp = fpp.landingSp
			local jumpingSp = fpp.jumpingSp
			local swayTransX = fpp.swayTransX
			local swayTransY = fpp.swayTransY
			local a = fpp.aimingSm
			local a_ = 1 - a
			local a__ = a_ * 1 + a * 0.66
			local s = fpp.sprintingSm
			local s_ = 1 - s

			local vaultCf = iCf
			do
				local vt = fpp.vaultingP
				if clamped(vt, 0.8, 1.5) then
					vaultCf = degToCf(- 2 * sin(pi / 0.7 * (vt - 0.8)) , 0, 0)
				end
			end

			rootJoint.Transform = vaultCf
				* newCf(
					(swayTransX * 80
						+ mouseInertiaY * (-0.03)) * s * s
					,
					(fpp.swayTransY * (-5)
						+ mouseInertiaX * 0.02
						+ jumpingSp * (-0.06)
						+ landingSp * (-0.25)) * s
					,
					0
				)


			-- make the gun sway to the absolute left/right. i.e. 
			-- not affected by leaning
			local leanCf = degToCf(0, 0, fpp.leaningDeg)
			local leanCfInv = invCf(leanCf)

			if db.configureGrip then
				leftJoint.Transform = invCf(leftJoint.C0) * newCf(rep.gx.Value, rep.gy.Value, rep.gz.Value) * leftJoint.C0
			else

				-- velTilt, gunSway, recoilZ, shootingRandomSway
				local armsCf = iCf
					* leanCfInv
					* newCf(
						(swayTransX
							- mouseInertiaY * 0.005
							- jumpingSp * 0.05) * a_ * s_
						, 
						(swayTransY * s_ 
							+ fpp.crouchingSp * (-0.02)) * a_ 
							+ (jumpingSp * (-0.06)
							+ landingSp * (-0.15)) * s_ * a__ 
						,
						fpp.recoilZ 
					) 
					* degToCf(
						(fpp.swayRotX * (s_ + s * 0.2)
							+ mouseInertiaX * 0.25 * s_
							+ fpp.velTiltX * 1.5) * a_
							+ (jumpingSp * 5
							- landingSp * 10) * a__
						,
						(fpp.swayRotY * (s_ + s * 0.2)
							+ mouseInertiaY * 0.25 * s_
							+ landingSp * 2
							+ fpp.velTiltZ * 1.5
							+ fpp.sprintRotY) * a_
						,
						(fpp.swayRotZ * (s_ + s * 0.2)
							+ fpp.shootingRandomSway * 3) * a_
							+ mouseInertiaY * 0.3
							+ fpp.velTiltZ * 2.75
					)
					* leanCf

				transformArms(armsCf)
			end

			-- lookjoint
			lookJoint.Transform = newCf(
				swayTransX * a_ * 33,
				swayTransY * a_ * 10,
				0
			)
		end
	end

	fpp.lookJointHandler = {}
	do
		local fppLookJoint   = joints.FppLook
		local lookJointDefC0 = defC0.FppLook
		local newCf   = CFrame.new
		local myMath  = requireGm("Math")
		local degToCf = myMath.degToCf
		local cylToCf = myMath.cylToCf
		local clamp   = myMath.clamp
		local v3ToCyl = myMath.v3ToCyl

		local maxAngle = 60 		-- there's also one in turn action

		function fpp.lookJointHandler.rs1(dt)
			if not alive then return end
			fpp.hrpy = v3ToCyl(hrp.CFrame.lookVector)
			fpp.looky = fpp.looky_ + fpp.recoilY
			fpp.lookyRel = fpp.looky - fpp.hrpy
			fpp.lookx = clamp(fpp.lookx_ + fpp.recoilX, -maxAngle, maxAngle)

			local turnCf = cylToCf(fpp.lookyRel, fpp.lookx)
			local leanCf = newCf(-fpp.leaningDeg / 20, 0, 0) * degToCf(0, 0, fpp.leaningDeg)

			fppLookJoint.C0 = turnCf * leanCf * lookJointDefC0
		end

		do -- hb2
			local lu = tick()
			local ur = 1/5
			local forward = fpsClient.forward
			local floor = math.floor
			function fpp.lookJointHandler.hb2(dt)
				if not alive then return end
				if now - lu > ur then
					forward("look", floor(fpp.looky), floor(fpp.lookx)) -- no compression
					lu = now
				end
			end
		end
	end

	fpp.eyeJointHandler = {}
	do
		local fppEye           = aniparts.FppEye
		local fppEyeJoint      = joints.FppEye
		local fppEyeJointDefC0 = defC0.FppEye

		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable

		-- mouse inertia
		local myMath = requireGm("Math")
		local degToCf = myMath.degToCf

		-- sprinting
		local iCf = CFrame.new()
		local newCf = CFrame.new
		local cfLerp = myMath.cfLerp

		-- aim
		local invCf    = myMath.invCf
		local cfLerp   = myMath.cfLerp
		local lerp     = myMath.lerp
		local fppEyeCf = defC0.FppEye * invCf(joints.FppEye.C1)
		local fppLook  = aniparts.FppLook

		local noise = math.noise

		local getVaultingCamSway = fpp.jumpAction.getVaultingCamSway

		function fpp.eyeJointHandler.rs3(dt)
			if fpp.camLocked then

				local aimingCf = iCf
				if fpp.aimingSm > 1e-2 then
					local weaponAimCf =
						invCf(fppLook.CFrame * fppEyeCf) 
						* aniparts.AimPart.CFrame
						* newCf(0, 0, fpp.recoilZ / 3)
					aimingCf = newCf(cfLerp(iCf, weaponAimCf, fpp.aimingSm).p)
				end

				local idleCamSwayX, idleCamSwayY
				do
					local tt = (now - initTick) / 5					
					idleCamSwayX = noise(tt + 23.33) * 2
					idleCamSwayY = noise(tt) * 2
				end

				local mouseInertiaY = fpp.mouseInertiaY
				local mouseInertiaX = fpp.mouseInertiaX
				local a = fpp.aimingSm
				local a_ = 1 - a 
				local s = fpp.sprintingSm

				-- velTilt, gunSway, recoilZ, shootingRandomSway
				-- the anti leaning must be before sway. only this way,
				--  the gun will sway to the absolute left/right when swaying. not relative to leaning
				local camCf = fppEye.CFrame 
					* aimingCf 
					* getVaultingCamSway(dt)
					* degToCf(0, 0, -fpp.leaningDeg * 1.2) -- anti leaning
					* newCf(
						fpp.swayTransX * a * 1
							- mouseInertiaY * a * 0.0008
						, 
						fpp.swayTransY * a * 0.33
							+ mouseInertiaX * a * 0.0008
						, 
						0 
					) 
					* degToCf(
						idleCamSwayX * a_
							- fpp.landingSp * 1.5
						,
						idleCamSwayY * a_
						,
						fpp.velTiltZ * a_ * 0.8
							+ fpp.recoilCamRot
							+ fpp.landingSp * 0.75 * a_
							+ fpp.swayRotZ * 0.18 * s 
					)

				cam.CFrame = camCf
			end
		end
	end

	fpp.fovHandler = {}
	do
		local cam    = workspace.CurrentCamera
		local myMath = requireGm("Math")
		local lerp   = myMath.lerp

		function fpp.fovHandler.rs3(dt)
			if fpp.camLocked then
				local aimingFOV = settings.fov / lerp(1, stats.aimMult, fpp.aimingSm) 
				cam.FieldOfView = aimingFOV + fpp.recoilFov-- fpp.shootingFovNoise
			else
				cam.FieldOfView = settings.fov
			end
		end

		function fpp.fovHandler.onDeath()
			cam.FieldOfView = settings.fov
		end
	end
	
	fpp.scoreGui = {}
	do
		local connect = game.Changed.Connect
		local tween   = requireGm("Tweening").tween
		local scoreFr = fpp.fppGuiInit.getNewGui("Score")

		local bigScore = {}
		do
			local val = Instance.new("IntValue")
			local accVal = 0
			local tws = {}
			local id = 0

			local timings = {
				transIn = 0.1,
				transOut = 0.5,
				val = 0.5,
				delay = 5.1,
			}
			local scoreText = wfc(wfc(scoreFr, "Score"), "TextLabel")
			do -- init
				scoreText.TextTransparency = 1
				cons[#cons + 1] = connect(val.Changed, function()
					scoreText.Text = tostring(val.Value)
				end)
			end

			local function clearTweens()
				for i, tw in ipairs(tws) do 
					tw:Cancel()
					tws[i] = nil
				end
			end

			function bigScore.onScoreChanged(inc)
				id = id + 1
				clearTweens()

				tws[#tws + 1] = tween(scoreText, timings.transIn, {TextTransparency = 0})
				tws[#tws + 1] = tween(val, timings.val, {Value = accVal + inc})
				accVal = accVal + inc

				local savedId = id
				delay(timings.delay, function()
					if savedId == id then
						clearTweens()
						tws[#tws + 1] = tween(scoreText, timings.transOut, {TextTransparency = 1})
						delay(timings.transOut + 0.02, function()
							if savedId == id then
								accVal = 0
								val.Value = 0
							end
						end)
					end
				end)
			end
		end

		local feed = {}
		do
			local feedFr = wfc(scoreFr, "Feed")
			local feedTemp = wfc(feedFr, "Frame")
			local grid = wfc(feedFr, "UIGridLayout")
			local gridY = grid.CellSize.Y.Scale
			do -- init
				feedTemp.Size   = grid.CellSize
				feedTemp.Parent = nil
				feedFr:ClearAllChildren()
			end

			local maxFeedCnt = 3 + 1
			local timings = {
				movingDown = 0.19,
				delay = 5,
				hideDelta = 0.05,
				show = 0.3,
				hide = 0.5,
			}

			local id      = 0
			local addable = true
			local feeds   = {}

			do -- get feed fr
				local clone  = game.Clone
				local format = string.format
				local typeToText = {
					hit           = "ENEMY HIT",
					plant         = "BOMB PLANTED",
					defuse        = "BOMB DEFUSED",
					kill          = "ENEMY KILLED",
					headshot      = "HEADSHOT",
				}

				function feed.format(inc, type)
					return format("%s +%d", typeToText[type], inc)
				end

				function feed.getFeedFr(inc, type)
					local fr = clone(feedTemp)
					fr.TextLabel.Text = feed.format(inc, type)
					return fr
				end

				local newU2 = UDim2.new
				function feed.getPos(i)
					return newU2(0, 0, (i - 1 + 0.5) * gridY, 0)
				end
			end

			function feed.showAll()
				for _, v in ipairs(feeds) do
					v.show()
				end
			end

			do -- add feed
				local getFeedFr = feed.getFeedFr
				local getPos    = feed.getPos
				function feed.addFeed(inc, type)
					addable = false

					-- combine the lastfeed is type is the same
					-- local lastFeed = feeds[1]
					-- if lastFeed then
					-- 	if lastFeed.type == type then
					-- 		lastFeed.updateValue(inc)
					-- 		addable = true
					-- 		return
					-- 	end
					-- end

					local self = {type = type}
					local fr = getFeedFr(inc, type)
					local idx = nil

					-- move down & destroy & show
					for i = #feeds, 1, -1 do
						local feed = feeds[i]
						feed.setIdx(i+1)
						feed.moveToIdx()
						feed.show()
						if i + 1 > maxFeedCnt then
							feed.destroy()
						end
					end

					function self.setIdx(i)
						feeds[i] = self
						if idx then
							feeds[idx] = nil
						end
						idx = i
					end
					self.setIdx(1)

					do -- moving down
						local tw = nil
						function self.moveToIdx()
							if tw then
								tw:Cancel()
								tw = nil
							end
							tw = tween(fr, timings.movingDown, {Position = getPos(idx)})
						end
					end

					function self.parentToFeedFr()
						-- fr.TextLabel.TextTransparency = 1
						fr.LayoutOrder = -id
						fr.Parent = feedFr
						fr.Position = getPos(0)
						self.moveToIdx()	-- should be one here
					end

					-- mainly the transparency step
					do
						local a = 0.15
						local b = 0.3
						-- local c = 0.3
						local function opacityCurve(y)
							-- y = y + c
							if y <= 0 then
								return 0
							elseif y <= a then
								return y / a
							elseif y <= 1 - b then
								return 1
							elseif y <= 1 then
								return (1 - y) / b
							else
								return 0
							end
						end

						-- default to 1 (shown by default)
						local masterOpacity = Instance.new("NumberValue")
						do
							masterOpacity.Value = 1
							local tw = nil
							function self.show()
								if tw then
									tw:Cancel()
									tw = nil
								end
								if masterOpacity.Value ~= 1 then
									tw = tween(masterOpacity, timings.show, {Value = 1})
								end
							end
							function self.hide()
								if tw then
									tw:Cancel()
									tw = nil
								end
								if masterOpacity.Value ~= 0 then
									tw = tween(masterOpacity, timings.hide, {Value = 0})
								end
							end
						end

						local textLabel = fr.TextLabel
						function self.step()
							if fr.Parent == nil then
								self.parentToFeedFr()
							end
							-- set transparency here
							textLabel.TextTransparency = 1 - opacityCurve(fr.Position.Y.Scale) * masterOpacity.Value
						end
					end

					do
						local destroy = game.Destroy
						function self.destroy()
							if idx then
								feeds[idx] = nil
							end
							destroy(fr)
						end
					end

					-- helper function for combining the lastfeed
					local accVal = inc
					function self.updateValue(inc2)
						accVal = accVal + inc2
						fr.TextLabel.Text = feed.format(accVal, type)
					end

					addable = true
				end
			end

			local scorePerHeadshot = requireGm("Progression").scorePerHeadshot
			function feed.onScoreChanged(inc, type, args)
				id = id + 1

				-- hide after a few seconds
				local savedId = id
				delay(timings.delay, function()
					if savedId == id then
						for i = #feeds, 1, -1 do
							local feed = feeds[i]
							if savedId == id then
								feed.hide()
								delay(timings.hide + 0.02, function()
									if savedId == id then
										feed.destroy()
									end
								end)
								wait(timings.hideDelta)
							else
								break
							end
						end
					end
				end)

				-- add feed (auto-show it)
				if not addable then
					repeat
						wait()
					until addable
				end
				if type == "kill" then
					if args.isHeadshot then
						feed.addFeed(scorePerHeadshot, "headshot")
					end
				else
					feed.addFeed(inc, type)
				end
			end

			function feed.step()
				for _, v in ipairs(feeds) do
					v.step()
				end
			end
		end		

		local bigFeed = {}
		do
			local tw = nil
			local bigFeedFr = wfc(scoreFr, "BigFeed")
			local textLabel = wfc(bigFeedFr, "TextLabel")
			do
				textLabel.Transparency = 1
			end
			local id = 0

			local timings = {
				show  = 0.4,
				delay = 5.5,
				hide  = 0.4,
			}

			local format = string.format
			local scorePerKill = requireGm("Progression").scorePerKill
			function bigFeed.onScoreChanged(inc, type, args)
				id = id + 1
				local savedId = id
				delay(timings.delay, function()
					if savedId == id then
						if tw then tw:Cancel(); tw = nil end
						tw = tween(textLabel, timings.show, {TextTransparency = 1})
					end
				end)

				if type == "kill" then
					if tw then tw:Cancel(); tw = nil end
					textLabel.Text = format("%s +%d", args.victim.Name, scorePerKill)
					tw = tween(textLabel, timings.show, {TextTransparency = 0})
				end
			end
		end

		local iconFeed = {}
		do
			local iconFeedFr = wfc(scoreFr, "IconFeed")
			local iconTemp = wfc(iconFeedFr, "Frame")
			local iconTempHeadshot = wfc(iconFeedFr, "FrameHeadshot")
			local destroy  = game.Destroy
			do -- init
				iconTemp.Parent = nil
				iconTempHeadshot.Parent = nil
				local getC     = game.GetChildren
				for _, v in ipairs(getC(iconFeedFr)) do
					if v.Name ~= "UIListLayout" then
						destroy(v)
					end
				end
			end
			local maxWidth = iconTemp.Size.X.Scale

			-- local id = 0
			local skullZoom = 3
			local timings = {
				delay = 6,
				show = 0.4,
				hide = 0.2, 	-- cant be >= 0.2, will lag
			}

			do
				local clone    = game.Clone
				local newU2    = UDim2.new
				local audioSys = requireGm("AudioSystem")
				function iconFeed.addIcon(inc, type, args)
					local fr = clone(args.isHeadshot and iconTempHeadshot or iconTemp)

					-- set up visibility function
					local vis = Instance.new("NumberValue")
					vis.Value = 0
					local function setVisibility(v)
						fr.Skull.ImageTransparency = (1 - v^2)
						fr.Size = newU2(v * maxWidth, 0, 1, 0)
					end
					setVisibility(0)
					cons[#cons + 1] = vis.Changed:connect(setVisibility)

					-- add to icons (show)
					local tws = {}
					tws[#tws + 1] = tween(vis, timings.show, {Value = 1})
					fr.Skull.Size = newU2(skullZoom, 0, skullZoom, 0)
					tws[#tws + 1] = tween(fr.Skull, timings.show, {Size = newU2(1, 0, 1, 0)})
					if args.isHeadshot then
						tween(fr.Circle, timings.show, {ImageTransparency = 0, Size = newU2(0, 0, 0, 0)})
						audioSys.play("KilledByLpHead", "2D")
					else
						audioSys.play("KilledByLp", "2D")
					end
					fr.Parent = iconFeedFr

					-- hide and then delete
					delay(timings.delay, function()
						for i, tw in ipairs(tws) do
							tw:Cancel()
							tws[i] = nil
						end
						tws[#tws + 1] = tween(vis, timings.hide, {Value = 0})
						delay(timings.hide + 0.01, function() 	-- delete
							destroy(fr)
						end)
					end)
				end
			end

			local icons = {}
			function iconFeed.onScoreChanged(inc, type, args)
				if type == "kill" then
					-- id = id + 1
					iconFeed.addIcon(inc, type, args)
				end
			end
		end

		function fpp.scoreGui.onScoreChanged(inc, type, args)
			if type ~= "round.win" and type ~= "match.win" then
				-- preprocess the args
				args = args or {}
				args.isHeadshot = args.hit and args.hit.Name == "Head"

				bigScore.onScoreChanged(inc)
				feed.onScoreChanged(inc, type, args)
				bigFeed.onScoreChanged(inc, type, args)
				iconFeed.onScoreChanged(inc, type, args)
			end
		end
		do -- init
			fpsClient.listen("score.inc", fpp.scoreGui.onScoreChanged)
			fpp.fppGuiInit.insertGui(scoreFr, fpp.staticFr)
		end

		function fpp.scoreGui.hb4()
			feed.step()
		end
	end

	fpp.suppressionSystem = {} -- @fucked
	do
		local x      = 0
		local xDecay = 0.93
		local myMath = requireGm("Math")
		local curve  = myMath.getLogisticFunction(9, 5, 0, 0)
		local blur   = wfc(game:GetService("Lighting"), "BlurSuppression")
		do
			blur.Size = 0
			blur.Enabled = true
		end
		local ffc = game.FindFirstChild
		local cam = workspace.CurrentCamera
		local dot = Vector3.new().Dot
		local min = math.min

		function fpp.suppressionSystem.suppressedQ(a, b)
			local c   = cam.CFrame.p
			local u   = a - b
			local v   = c - b
			local w   = c - a
			local duv = dot(u, v)

			local b, r
			if duv > 1e-1 and dot(w, -u) > 1e-1 then
				r = (v - u * (duv / dot(u, u))).magnitude
				b = r <= 7
			else
				r = min(v.magnitude, w.magnitude)
				b = r <= 5
			end

			return b, r
		end
		function fpp.suppressionSystem.incSuppression(intensity)
			x = x + 6 / (intensity + 1)
		end
		function fpp.suppressionSystem.cameraHbStep(dt, now)
			x = x * xDecay
			blur.Size = curve(x)
		end

		do --init
			local suppressedQ    = fpp.suppressionSystem.suppressedQ
			local incSuppression = fpp.suppressionSystem.incSuppression
			local play           = requireGm("AudioSystem").play
			local ffc = game.FindFirstChild
			fpsClient.listen("bulletHit", function(shooter, hit, p1)
				if shooter ~= lp and shooter and shooter.Character and ffc(shooter.Character, "Head") then
					local p0 = shooter.Character.Head.Position
					local suppressed, intensity = suppressedQ(p0, p1)
					if suppressed then
						incSuppression(intensity)
						play("Suppression", "2D")
					end
				end
			end)
		end
	end

	fpp.shotIndicatorGui = {}
	do
		local shotIndicators = fpp.fppGuiInit.getNewGui("ShotIndicators")
		local centerGui = wfc(shotIndicators, "Center")

		local v3ToCyl = requireGm("Math").v3ToCyl
		local o = 0

		function fpp.shotIndicatorGui.shot(p0, p1)
			local y = v3ToCyl(p0 - p1)
			centerGui.Rotation = fpp.looky - y + 180
			o = 1
		end
		function fpp.shotIndicatorGui.hb4(dt, now)
			if not alive then return end
			o = o * 0.95
			centerGui.ImageTransparency = 1 - o
		end

		fpp.fppGuiInit.insertGui(shotIndicators, fpp.staticFr)

		function fpp.shotIndicatorGui.onDeath()
			delay(5, function()
				centerGui.Visible = false
			end)
		end
	end

	-- suppression and gui
	fpp.healthIndicatorGui = {}
	do
		local blood = fpp.fppGuiInit.getNewGui("FullscreenBlood")
		
		local clamp = math.clamp
		local myMath = requireGm("Math")
		local delta = myMath.delta
		local sgn = math.sign

		local lastHealth = 100
		local defOpacity = 1 - blood.ImageTransparency
		local damagedTS = -1
		local goalOpacity = 0
		local currOpacity = 0

		function fpp.healthIndicatorGui.setHealth(health)
			if health < lastHealth then 		-- damaged
				damagedTS = TS
				currOpacity = 1
				goalOpacity = 1
				spawn(function()
					local thisTS = damagedTS
					wait(1)
					if damagedTS == thisTS then
						goalOpacity = clamp(1 - health / 50, 0, 1)
					end
				end)
			else
				goalOpacity = clamp(1 - health / 50, 0, 1)
			end

			lastHealth = health
		end
		function fpp.healthIndicatorGui.hb4(dt)
			if not alive then return end
			-- print(currOpacity, goalOpacity)
			local dir = sgn(goalOpacity - currOpacity)
			local sp = delta(goalOpacity, currOpacity) / 4
			if dir == 1 then
				currOpacity = clamp(currOpacity + dt * sp, 0, goalOpacity)
			elseif dir == -1 then
				currOpacity = clamp(currOpacity - dt * sp, goalOpacity, 1)			
			end
			blood.ImageTransparency = 1 - currOpacity * defOpacity
		end

		fpp.fppGuiInit.insertGui(blood, fpp.staticFr)

		function fpp.healthIndicatorGui.onDeath()
			delay(5, function()
				blood.Visible = false
			end)
		end
	end

	fpp.healthSystem = {}
	do -- connect to health changes
		local ffc = game.FindFirstChild
		local shot = fpp.shotIndicatorGui.shot
		local setHealth = fpp.healthIndicatorGui.setHealth

		fpsClient.listen("health", function(health, attackInfo)
			setHealth(health)

			-- shot indicator
			if attackInfo.attacker and attackInfo.attacker.Character and ffc(attackInfo.attacker.Character, "Head") then
				local p0 = attackInfo.attacker.Character.Head.Position
				local p1 = hrp.Position
				shot(p0, p1)
			end
		end)

		requireGm("PublicVarsClient").waitForPObj(lp, "Health").Changed:Connect(setHealth)
	end

	fpp.shakyGui = {}
	if settings.shakyGui then
		local defPos = wfc(fpp.sgTemp, "Dynamic").Position
		local newU2  = UDim2.new
		local dynamicFr = fpp.dynamicFr
		function fpp.shakyGui.rs4()
			local s = fpp.sprintingSm

			dynamicFr.Position = defPos + newU2(
				0, 
				aliveSm * (
					fpp.swayTransX * 1500 * (s * 1 + (1 - s) * 0.33)
					- fpp.mouseInertiaY
					- fpp.velTiltZ * 10
				),
				0,
				aliveSm * (
					- fpp.swayTransY * 110
					- fpp.mouseInertiaX
					+ fpp.velTiltX * 3
					- fpp.jumpingSp * 5
					+ fpp.landingSp * 20
				)
			)
		end
	end

	fpp.statusBarGui = {}
	do
		local statusGui = fpp.fppGuiInit.getNewGui("Status")
		local currBullets = wfc(wfc(statusGui, "currBullets"), "Frame")
		local bkupBullets = wfc(wfc(statusGui, "bkupBullets"), "Frame")
		local fireModeGuis = {
			auto   = wfc(wfc(wfc(statusGui, "FireMode"), "Frame"), "Auto"),
			single = statusGui.FireMode.Frame.Single,
			burst  = statusGui.FireMode.Frame.Burst,
		}	

		local setStText = requireGm("ShadedTexts").setStText

		do
			setStText(currBullets, "-")
			setStText(bkupBullets, "-")
		end

		function fpp.statusBarGui.onDeath()
			statusGui.Visible = false
		end

		local ffc = game.FindFirstChild
		function fpp.statusBarGui.hb4()
			if gun then
				if not ffc(currBullets, "shade") then return end -- weird bug
				setStText(currBullets, gun.currBullets)
				setStText(bkupBullets, gun.bkupBullets)
				for fireMode, gui in pairs(fireModeGuis) do
					gui.Visible = fireMode == gun.fireMode
				end
			end
		end

		fpp.fppGuiInit.insertGui(statusGui, fpp.dynamicFr)
	end

	do -- objectives and level up
		fpp.objectivesBe = wfc(wfc(rep, "Events"), "ObjectivesBe")
		fpsClient.listen("level.up", function(newLevel)
			fpp.objectivesBe:Fire("levelup", newLevel)
		end)
	end

	-- invade related
	fpp.invadeLogistics       = {}
	fpp.dropBombAction        = {}
	fpp.pickupBombAction      = {}
	fpp.plantDefuseBombAction = {}
	do -- invade
		local bomb
		local plantingSite
		fpp.planting = false
		fpp.defusing = false
		fpp.bombAtmpt = false

		local plantingTime = db.fastInvade and 5 or 5
		local defusingTime = db.fastInvade and 5 or 5

		local bombsites = workspace.Bombsites:GetChildren()

		local pv      = requireGm("PublicVarsClient")
		local get     = pv.get
		local waitFor = pv.waitFor
		local kb      = requireGm("Keybindings")
		local cam     = workspace.CurrentCamera
		local w2s       = cam.WorldToScreenPoint
		
		local lastDropTick = -1
		local lastPickupRequestTick = -1

		local function nearBombQ()
			if bomb then
				local bombPos = bomb.PrimaryPart.Position
				local b = (bombPos - hrp.Position).magnitude < 8
				return b
			end
		end

		do -- fpp.invadeLogistics.rs1
			local planarV3  = Vector3.new(1, 0, 1)
			function fpp.invadeLogistics.rs1(dt)
				if not alive then return end
				bomb = get("Bomb")

				do -- get the site that the player is in
					local plantingSite_ = nil
					local hrpp    = hrp.CFrame.p
					for _, site in ipairs(bombsites) do
						local siteCf  = site.CFrame
						local halfSzY = site.Size.y/2
						local b = ((hrpp - siteCf.p) * planarV3).magnitude <= site.Size.z / 2
							and siteCf.p.y + halfSzY > hrpp.y and hrpp.y > siteCf.p.y - halfSzY
						if b then
							plantingSite_ = site
							break
						end
					end
					plantingSite = plantingSite_
				end
			end
		end

		-- hints @todo hint manager?
		local hintsFr = fpp.fppGuiInit.getNewGui("Hints")
		local plantHintGui  = wfc(hintsFr, "Plant")
		local defuseHintGui = wfc(hintsFr, "Defuse")
		local dropHintGui = wfc(hintsFr, "Drop")

		do -- dropBombAction
			local function canDropQ()
				return get("Bomber") == lp
			end
			inputReader.listen("bomb.drop", "Begin", "Keyboard", kb.dropBomb, function()
				if canDropQ() then
					fpsClient.fireServer("dropBomb")
					lastDropTick = now
					print("drop request sent")
				end
			end)
			function fpp.dropBombAction.hb4()
				dropHintGui.Visible = alive and canDropQ() and now - lastPickupRequestTick < 4 and not plantHintGui.Visible and not fpp.planting  -- two hints are conflicting each other here @todo should have a hint manager
			end
		end

		do -- pickupBombAction
			local range = 4

			local function canPickUpQ()
				if lp.Team == get("Atk") 
					and not get("Planted") 
					and now - lastDropTick > 4
					and now - lastPickupRequestTick > 1.5 then
					return nearBombQ()
				end
			end

			function fpp.pickupBombAction.hb1(dt)
				if not alive then return end
				if canPickUpQ() then
					fpsClient.fireServer("pickupBomb")
					lastPickupRequestTick = now
					print("pickup request sent")
				end
			end
		end

		do -- plant / defuse BombAction
			inputReader.listen("plant/defuse0", "Begin", "Keyboard", kb.plantOrDefuse, function()
				fpp.bombAtmpt = true
			end)
			inputReader.listen("plant/defuse0", "End", "Keyboard", kb.plantOrDefuse, function()
				fpp.bombAtmpt = false
			end)

			local function canPlantQ()
				return get("Bomber") == lp and plantingSite
			end

			local function canDefuseQ()
				if get("Planted") ~= nil then
					return nearBombQ()
				end
			end

			local plantAttemptId = 0
			local defuseAttemptId = 0
			local canPlant = false
			local canDefuse = false

			function fpp.plantDefuseBombAction.hb1(dt)
				if not alive then return end
				local cond1 = fpp.bombAtmpt and not (fpp.shooting or fpp.aiming or fpp.sprinting or fpp.jumping or fpp.moving) 

				if lp.Team == get("Atk") then
					-- plant
					canPlant = canPlantQ()
					local plantingNew = cond1 and canPlant

					if fpp.planting ~= plantingNew then
						fpp.planting = plantingNew
						plantAttemptId = plantAttemptId + 1

						if plantingNew then
							fpsClient.fireServer("planting.start") 	

							-- callback
							local savedPlantAttemptId = plantAttemptId
							delay(plantingTime, function()
								if savedPlantAttemptId == plantAttemptId then
									print("sent planted signal")
									fpsClient.fireServer("planted", plantingSite.Name, plantingSite.Position, hrp.Position)
								end
								-- @todo play plant confirmed sound / also in server side
							end)
						else
							fpsClient.fireServer("planting.cancel")
						end
					end
				end

				if lp.Team == get("Def") or db.atkCanDefuse then
					-- defuse
					canDefuse = canDefuseQ()
					local defusingNew = cond1 and canDefuse
					if defusingNew ~= fpp.defusing then
						fpp.defusing    = defusingNew
						defuseAttemptId = defuseAttemptId + 1

						if defusingNew then
							fpsClient.fireServer("defusing.start")

							-- callback
							local savedDefuseAttemptId = defuseAttemptId
							delay(defusingTime, function()
								if savedDefuseAttemptId == defuseAttemptId then
									print("sent defused signal")
									fpsClient.fireServer("defused", bomb.PrimaryPart.Position)
								end
							end)
						else
							fpsClient.fireServer("defusing.cancel")
						end
					end
				end
			end

			do -- gui step
				function fpp.plantDefuseBombAction.hb4(dt)
					plantHintGui.Visible  = canPlant and not fpp.planting
					defuseHintGui.Visible = canDefuse and not fpp.defusing
				end
				
				-- on death
				function fpp.plantDefuseBombAction.onDeath()
					plantHintGui.Visible = false
					defuseHintGui.Visible = false
				end
			end
		end

		fpp.fppGuiInit.insertGui(hintsFr, fpp.dynamicFr)
	end

	fpp.invadeObjectives = {}
	do
		local pv = requireGm("PublicVarsClient")
		local waitFor = pv.waitFor
		local get = pv.get
		local play = requireGm("AudioSystem").play
		local function phaseHandler(phase)
			local obj
			local soundName
			if lp.Team == pv.get("Atk") then
				if phase == "Match:Plant" then
					obj = "plant the bomb at any site"
					soundName = "AtkStartRoundVoice"
				elseif phase == "Match:Defuse" then
					obj = "prevent the bomb from being defused"
				-- elseif phase == "Boom" then
				-- 	obj = "Mission Success"
				end
			else
				if phase == "Match:Plant" then
					obj = "defend the sites from the enemies"
					soundName = "DefStartRoundVoice"
				elseif phase == "Match:Defuse" then
					obj = "defuse the bomb at site "..waitFor("Planted").Name
				-- elseif phase == "Boom" then
				-- 	obj = "Mission Failed"
				end
			end
			if obj then
				fpp.objectivesBe:Fire("newobj", obj)
				if soundName then
					play(soundName, "2D")
				end
			else
				warn("no object text got from", phase, lp.Team)
			end
		end
		local phaseValue = pv.waitForObj("Phase")
		if phaseValue.Value then
			phaseHandler(phaseValue.Value)
		end
		cons[#cons+1] = phaseValue.Changed:Connect(phaseHandler)
	end

	print("fpp small systems loaded")

	-- steps
	---------------------------------------------------
	local runFuncs = requireGm("FuncList").runFuncs
	local removeNilFuncs = requireGm("FuncList").removeNilFuncs

	do --rsstep & death
		local rsSteps = {
			-- 1: the state machine. (input -> char states)
			------------------------------------

			--alive
			fpp.mouseLockSystem.rs1,
			fpp.jumpAction.rs1,
			fpp.speedSystem.rs1,
			fpp.blockingSystem.rs1,
			fpp.leanAction.rs1,
			fpp.crouchAction.rs1,
			fpp.sprintAction.rs1,
			fpp.danceAction.rs1,

			fpp.equipGearAction.rs1,
			fpp.reloadGunAction.rs1,
			fpp.aimGunAction.rs1,
			fpp.gunStanceDeterminer.rs1,

			fpp.lookJointHandler.rs1,
			fpp.shootGunAction.rs1,

			fpp.invadeLogistics.rs1,

			-- 2: animation. (char states -> animation)
			----------------------------

			-- alive
			fpp.tppAngleSystem.rs2,
			kfs.playAnimation, -- dead, too
			fpp.shootGunAction.rs2, -- dead, too
			fpp.reticleSystem.rs2, -- dead, too
			fpp.crouchAction.rs2, -- dead, too
			fpp.shellSystem.rs2, -- dead, too
			fpp.recoilSystem.rs2, -- dead, too
			fpp.mouseInertiaSystem.rs2, -- dead, too
			fpp.swaySystem.rs2,
			fpp.velocityTiltSystem.rs2, -- dead, too
			fpp.inertiaJointHandler.rs2,

			-- 3: camera. (char states -> camera)
			-----------------------------

			-- alive
			fpp.eyeJointHandler.rs3,
			fpp.fovHandler.rs3,

			-- 4: gui. (char states -> gui)
			------------------------------
			fpp.shakyGui.rs4, -- dead, too
		}
		removeNilFuncs(rsSteps, 50)

		local onDeaths = {
			fpp.deathSystem.onDeath,
			fpp.fovHandler.onDeath,
			fpp.statusBarGui.onDeath,
			fpp.healthIndicatorGui.onDeath,
			fpp.shotIndicatorGui.onDeath,
			fpp.plantDefuseBombAction.onDeath,
			fpp.staminaSystem.onDeath,
			fpp.jumpAction.onDeath,
		}
		removeNilFuncs(rsSteps, 10)

		-- rsstep
		local function rsStepMain(dt)
			now = tick()

			debug.profilebegin("[[[fpp:rsSteps")

			if alive and not fpp.alive_ then   -- manually consider deaths
				alive     = false
				fpp.alive = false
				runFuncs(onDeaths, dt)
			end
			if not alive then
				aliveSm = aliveSm * 0.95
			end

			runFuncs(rsSteps, dt)

			debug.profileend("[[[fpp:rsSteps")

			TS = TS + 1
		end
		game:GetService("RunService"):BindToRenderStep(
			lp.Name.."_rsSteps", 
			150, 
			rsStepMain
		)

		-- kill (death) -> set alive_ to false
		fpsClient.listen("kill", function(plrToKill, killMethod_, killData_)
			if plrToKill == lp then
				fpp.deathSystem.onDeathImmediate(killMethod_, killData_)
				print("fpp: lp is killed rip", plrToKill, killMethod_, killData_)
			end
		end)
	end

	local running = true
	do --hbstep
		local hbSteps = {
			-- 1: states
			------------------------------------

			-- all require alive
			fpp.jumpAction.hb1,
			fpp.leanAction.hb1,
			fpp.staminaSystem.hb1,
			fpp.pickupBombAction.hb1,
			fpp.plantDefuseBombAction.hb1,
			fpp.gunStanceDeterminer.hb1,
			fpp.aimGunAction.hb1,
			fpp.extraReplications.hb1,
			scsClient.fireServerAtmpt,   -- wont run when no update

			-- 2: animation
			-------------------------------------

			-- all require alive
			fpp.lookJointHandler.hb2,

			-- 3: camera
			-------------------------------------

			-- 4: gui
			-------------------------------------

			fpp.scoreGui.hb4, -- can run when dead
			fpp.shotIndicatorGui.hb4,   -- has on death. dont run on alive
			fpp.healthIndicatorGui.hb4, -- same
			fpp.statusBarGui.hb4,       -- same
			fpp.plantDefuseBombAction.hb4, -- same
			fpp.dropBombAction.hb4, -- can be run on dead
		}
		spawn(function()
			local hb     = game:GetService("RunService").Heartbeat
			local evwait = game.Changed.Wait
			while running do
				local dt = evwait(hb)
				now = tick()
				debug.profilebegin("[[[hbStepMain")
				runFuncs(hbSteps, dt)
				debug.profileend("[[[hbStepMain")
			end
		end)
	end

	----------------------------------------------------

	function fpp.despawn()
		running = false  -- stop hb thread
		game:GetService("RunService"):UnbindFromRenderStep(lp.Name.."_rsSteps") -- stop rs thread
		for i, con in ipairs(cons) do
			con:Disconnect()
			cons[i] = nil
		end
		if stash.charNH2 then
			stash.charNH2:Destroy()
		end
		print("fpp despawn!")
	end

	print("fpp fully loaded")

	return fpp
end

do -- upload join data
	local joinData 
	if db.matchmakingEnabled then
		joinData = requireGm("WaitForProperty")(_G, "joinData", {clockrate = 0.1})
	else
		joinData = {
			joinMethod = db.matchEnabled and "freshstart" or "debug",
			roomInitInfo = {
				Alpha = {y1rkl0u = 1, },
				Beta  = {y0rkl1u = 1, },
			},
			party = {[lp.Name] = 1},
		}
		_G.joinData = joinData
	end

	print("teleportation data table obtained, clientLoaded")
	fpsClient.fireServer("clientLoaded", joinData)
end

spawn(function()-- setup death bricks
	local ffc    = game.FindFirstChild
	local pwd    = game.GetFullName
	local deaths = wfc(workspace, "Deaths")
	local isVisBodypart = requireGm("RigHelper").isVisBodypart
	local alivesF = wfc(wfc(rep, "SharedVars"), "Alives")

	local lu = tick()
	local ur = 0.5

	local function onTouched(part)
		if part.Parent == lp.Character and (isVisBodypart(part, "tpp") or part.Name == "HumanoidRootPart") then
			if ffc(alivesF, lp.Name) then
				local now = tick()
				if now - lu > ur then
					fpsClient.fireServer("reset")
					lu = now
					print(pwd(part), "triggered the death brick for", lp)
				end
			end
		end	
	end

	for _, death in ipairs(deaths:GetChildren()) do
		death.Touched:connect(onTouched)
	end
end)