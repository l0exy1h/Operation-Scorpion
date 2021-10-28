local plrs = game.Players
local lp   = plrs.LocalPlayer
local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local ffc  = game.FindFirstChild
local getC = game.GetChildren

local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local printTable = requireGm("TableUtils").printTable

local db = requireGm("DebugSettings")()

local fpsClient, scsClient, fetchClient
do
	local events = wfc(rep, "Events")

	fpsClient = requireGm("Network").loadRe(
		wfc(events, "FpsRe"), 
		{
			socketEnabled = true, 
			re2 = wfc(events, "FpsForwardRe")
		}
	)  -- shouldn't fire any events using this

	scsClient = requireGm("SerializedCharStates").loadRe(wfc(events, "CharStatesRe"))

	fetchClient = requireGm("FetchClient").loadRf(wfc(events, "FetchRf"))
end

local tppModule = {}
local tpps = {}

-- global animations
local tppAnimations = requireGm("TppAnimations")()

function tppModule.spawn(plr)
	local tpp = {plr = plr}
	print("tpp spawning", plr)

	local alive = true
	tpp.alive_ = true
	tpp.alive = true

	local oldTpp = tpps[plr.Name]
	if oldTpp then
		oldTpp.despawn()
	end

	if plr == lp and not db.renderSelfTpp then
		return
	end

	local loadout1 = fetchClient.fetch("loadout1", {wait = true, requestee = plr})
	local skin     = fetchClient.fetch("skin", {wait = true, requestee = plr})
	if not (loadout1 and skin) then 
		return nil
	end

	print("tpp: waiting for char", plr)
	local char = plr.Character or plr.CharacterAdded:wait()
	print("tpp: get char", plr)
	local hrp      = wfc(char, "HumanoidRootPart")
	local humanoid = wfc(char, "Humanoid")
	tpp.char = char

	local aniparts, joints, defC0, sounds, stash = {}, {}, {}, {}, {}
	do -- init rig
		local rigHelper = requireGm("RigHelper")
		rigHelper.initRig(char, aniparts, joints, defC0)
		stash.char = char

		local charNH = Instance.new("Model")
		charNH.Name = plr.Name
		charNH.Parent = wfc(workspace, "NonHitbox")
		stash.charNH = charNH
	end

	local specialAnimations = {}

	-- sound holder
	local sh
	do
		sh = Instance.new("Attachment")
		sh.Name = "SoundHolder_"..plr.Name
		sh.Parent = aniparts.Head
	end

	-- kfs and the animation table
	local kfsFull, kfsLower, kfsUpper
	do
		local play = requireGm("AudioSystem").play
		local function soundPlayer(sound)
			play(sound, sh)
		end

		local kfs= requireGm("KeyframeAnimation")
		kfsFull  = kfs.new(aniparts, joints, defC0, stash, soundPlayer)
		kfsLower = kfs.new(aniparts, joints, defC0, stash, soundPlayer)
		kfsUpper = kfs.new(aniparts, joints, defC0, stash, soundPlayer)
	end

	tpp.skinObjs = {tpp = {}, fpp = {}}
	if plr ~= lp then -- visibility and shootabliity
		local rigHelper = requireGm("RigHelper")
		local isVisBodypart = rigHelper.isVisBodypart
		for _, bp in ipairs(getC(char)) do
			if bp:IsA("BasePart") then
				bp.CanCollide = false
				if not isVisBodypart(bp, "tpp") then
					bp.Parent = stash.charNH	 --@todo turn this into a lib function
				end
			end
		end
		char.Parent = wfc(workspace, "Chars")

		local setCharVisibility = rigHelper.setCharVisibility
		setCharVisibility("tpp", true, char, aniparts, tpp.skinObjs, {skin = skin, charNH = stash.charNH})
		setCharVisibility("fpp", false, char, aniparts, tpp.skinObjs)
	end

	local ns = {} 		
	do -- new states (un-updated char states)
		requireGm("SerializedCharStates").deserialize(
			fetchClient.fetch("states", {
				wait = true,
				requestee = plr,
			}), 
			ns
		)
		tpp.ns = ns
	end

	local consts = {}

	tpp.weaponSystem = {}
	do
		local gearSlots = loadout1.weapons  -- download from server. augmented with stats, anidata...
		local gearIdx_ = fetchClient.fetch("gearIdx", {requestee = plr, wait = true})[1]
		local gearIdx  = -1
		function tpp.setGearIdx(gearIdx)
			gearIdx_ = gearIdx
		end

		-- onGunEquipped
		stash.TppGun = nil
		local gun
		local stats
		local skinStep
		local fireSound
		local flashMult, smokeMult, lightMult
		local ms 
		
		do -- preload. similar to fpp. cache the weapon to slot
			local get = requireGm("WeaponCustomization").get
			
			function tpp.weaponSystem.preload(slotId)
				local slot = gearSlots[slotId]
				local model, stats, aniData, _, skinStep_ = get(slot.weaponName, slot.attachments, "tpp")

				model.Name = "TppGun"

				slot.model   = model
				slot.stats   = stats
				slot.aniData = aniData
				slot.id      = slotId
				slot.skinStep= skinStep_

				-- remove reticles
				if aniData.reticle then
					aniData.reticle:Destroy()
				end
				if aniData.reticleExt then
					for _, v in ipairs(aniData.reticleExt) do
						v:Destroy()
					end
				end
			end

			for i = 1, #gearSlots do
				tpp.weaponSystem.preload(i)
			end
		end

		do -- equip / unequip
			local newMuzzleSystem = requireGm("MuzzleSystem").new
			function tpp.weaponSystem.equip() -- assuming its gun now. may be gadgets later
				
				gearIdx = gearIdx_
				gun = gearSlots[gearIdx]
				stats = gun.stats
				skinStep = gun.skinStep

				if gun.aniData.tppAnimations then -- load animations into animation table 
					for trackName, track in pairs(gun.aniData.tppAnimations) do
						specialAnimations[trackName] = track
					end
				end

				do -- load aniparts, joints, and def c0
					local ffcWia = game.FindFirstChildWhichIsA
					for pn, part in pairs(gun.aniData.aniparts) do
						aniparts[pn] = part
						joints[pn]   = ffcWia(part, "Motor6D")
						if joints[pn] then
							defC0[pn] = joints[pn].C0
						else
							warn(plr, "tpp equipweapon: joints[", pn, "] is nil")
						end
					end
				end

				if gun.aniData.sounds then -- load sounds
					for sn, sound in pairs(gun.aniData.sounds) do
						sounds[sn] = sound
					end
				end

				-- connect the gun
				joints.WeaponMain.Part0 = aniparts.RightLowerArm
				gun.model.Parent = stash.charNH
				stash.TppGun = gun.model

				-- on gun equipped
				kfsUpper.update(aniparts, joints, defC0, stash)
				kfsLower.update(aniparts, joints, defC0, stash)
				kfsFull.update(aniparts, joints, defC0, stash)
				flashMult = stats.suppressed and 0 or stats.flashMult
				smokeMult = stats.smokeMult
				lightMult = stats.lightMult
				fireSound = sounds[stats.suppressed and "ShootSuppressed" or "Shoot"]
				ms = newMuzzleSystem(aniparts.FirePoint)

				-- modify the current idx
				tpp.gearIdx = gun.id
			end

			function tpp.weaponSystem.unequip()
				if not gun then return end
				do -- disconnect model
					joints.WeaponMain.Part0 = nil
					gun.model.Parent        = nil
				end
				if gun.aniData.tppAnimations then-- restore animations
					for trackName, track in pairs(gun.aniData.tppAnimations) do
						specialAnimations[trackName] = nil
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
						kfsFull.interpolators[pn] = nil
						kfsLower.interpolators[pn] = nil
						kfsUpper.interpolators[pn] = nil
						aniparts[pn] = nil
						joints[pn]   = nil
						defC0[pn]    = nil
					end
				end
				do-- unload everything	
					stash.TppGun = nil
					gun = nil
					stats = nil
					skinStep = nil
				end
			end
		end

		do -- tpp.shoot
			local play = requireGm("AudioSystem").play
			local createParticle = requireGm("ParticleSystem").onHit
			local v3 = Vector3.new()

			function tpp.shoot()
				play(fireSound, sh)
				play("GunMechanics", sh)
				ms.shoot(flashMult, 0, lightMult)
			end
		end

		do -- step
			local equip   = tpp.weaponSystem.equip
			local unequip = tpp.weaponSystem.unequip

			function tpp.weaponSystem.step(dt, now)
				if gearIdx ~= gearIdx_ then
					unequip()
					equip(gearIdx_)
				end
				ms.step(dt)
				if skinStep then
					skinStep(dt)
				end
			end
		end

		do -- set gun enabled (for dancing. currently not used)
			function tpp.weaponSystem.setGunVisible(bool) -- safe to call multiple timess 
				if gun and gun.model then
					gun.model.Parent = bool and stash.charNH or nil
				end
			end
		end

		do -- drop weapon
			local setPartsProperty = requireGm("Welding").setPartsProperty
			local raycasting = {}
			do
				local newRay = Ray.new
				local newV3  = Vector3.new
				local downVector = newV3(0, -1000, 0) 
				local raycastWith = workspace.FindPartOnRayWithWhitelist
				function raycasting.down(top)
					if typeof(top) == "Instance" then
						top = top.Position
					end
					local ray  = newRay(top, newV3(0, -1000, 0))
					local _, p = workspace:FindPartOnRayWithWhitelist(ray, {workspace.Map})
					return raycastWith(workspace, newRay(top, downVector), {workspace.Map})
				end
			end
			local myMath = requireGm("Math")
			local degToCf = myMath.degToCf
			local rand = myMath.randomDouble
			local newCf = CFrame.new
			local newV3 = Vector3.new
			function tpp.weaponSystem.dropWeapon()
				if gun and gun.model then
					joints.WeaponMain.Part0 = nil
					setPartsProperty(gun.model, {CanCollide = false, Anchored = false})
					gun.model.PrimaryPart.Anchored = true

					local _, downPos = raycasting.down(gun.model.PrimaryPart.CFrame.p)
					local cf = newCf(downPos + newV3(0, 0.2, 0)) * degToCf(0, rand(0, 360), 90)
					gun.model:SetPrimaryPartCFrame(cf)
				end
			end
		end
	end

	tpp.crouchAction = {}
	do
		tpp.crouchingSm = 0

		local smoother = requireGm("Interpolation").getSmoother(4, 1.2)

		function tpp.crouchAction.step(dt)
			if not alive then return end
			tpp.crouchingSm = smoother(tpp.crouchingSm, tpp.lowerStance == "crouching" and 1 or 0, dt)
		end
	end

	tpp.leanAction = {}
	do
		tpp.leaningDeg = 0
		tpp.leaning    = "mid"

		local leaningDegMax = 22
		local degSmoother = requireGm("Interpolation").getSmoother(6, 1)

		function tpp.leanAction.step(dt) 
			if not alive then return end

			tpp.leaning = ns.leaning
			tpp.leaningDeg = degSmoother(tpp.leaningDeg, leaningDegMax * (
				tpp.leaning == "left" 
					and 1 
					or tpp.leaning == "right" 
						and -1 or 0),
				dt
			)
		end
	end

	tpp.aimAction = {}
	do
		local play = requireGm("AudioSystem").play

		tpp.aiming = false
		tpp.aimingSm = 0
		local aimingSmoother = requireGm("Interpolation").getSmoother(5, 0.8)

		function tpp.aimAction.step(dt)
			if not alive then return end

			if tpp.aiming ~= ns.aiming then
				tpp.aiming = ns.aiming
				play("Aim", sh)
			end
			tpp.aimingSm = aimingSmoother(tpp.aimingSm, tpp.aiming and 1 or 0, dt)
		end
	end

	tpp.lookAction = {}
	do
		local looky_, lookx_ = 0, 0
		tpp.looky, tpp.lookx = 0, 0
		tpp.hrpy, tpp.hrpx   = 0, 0
		tpp.turning          = false

		local smoother = requireGm("Interpolation").getSmoother(6, 1)

		function tpp.setLookAngles(looky, lookx)
			looky_, lookx_ = looky, lookx
		end

		local myMath = requireGm("Math")
		local v3ToCyl = myMath.v3ToCyl
		local abs = math.abs
		local mod = myMath.mod
		function tpp.lookAction.step(dt, now)
			if not alive then return end

			tpp.looky = smoother(tpp.looky, looky_, dt)
			tpp.lookx = smoother(tpp.lookx, lookx_, dt)
			tpp.hrpy, tpp.hrpx = v3ToCyl(hrp.CFrame.lookVector)
			do -- turning
				local d = mod(abs(tpp.looky - looky_), 360)
				tpp.turning = d >= 10 and d <= 360 - 10
			end
		end
	end

	tpp.killAction = {}
	do
		local killMethod, killData

		function tpp.kill(_killMethod, _killData)
			tpp.alive_ = false
			killMethod, killData = _killMethod, _killData
		end

		local getDeathAnimation = requireGm("GetDeathAnimation")
		function tpp.killAction.step(dt)
			if alive and not tpp.alive_ then
				alive     = false 
				tpp.alive = false

				local aniName, deathDir, headshotQ = getDeathAnimation(killMethod, killData, {
					hrp = hrp, 
					looky = tpp.looky, 
					crouching = tpp.lowerStance == "crouching",
				})
				print("tpp death animation got:", aniName, deathDir, headshotQ)
				kfsFull.load(tppAnimations, aniName, {snapFirstFrame = true, table0 = specialAnimations})

				-- drop the weapon
				tpp.weaponSystem.dropWeapon()

				-- ooooooof
				requireGm("AudioSystem").play("DeathScream", sh)

				-- -- make the char not cancollide and anchored
				-- delay(3, function() 
				-- 	local isA = game.IsA
				-- 	if char and humanoid then
				-- 		humanoid:Destroy()
				-- 		for _, v in ipairs(char:GetDescendants()) do
				-- 			if isA(v, "BasePart") then
				-- 				v.Anchored = true
				-- 				v.CanCollide = false
				-- 			end
				-- 		end
				-- 	end
				-- end)
			end
		end
	end

	tpp.danceAction = {}
	do
		tpp.redance = false
		function tpp.setRedance()
			tpp.redance = true
			print("set redance!")
		end
	end

	-- movedir, footsteps
	tpp.moveAction = {}
	do
		tpp.moveDir = 1
		tpp.moving = false

		local myMath  = requireGm("Math")
		local newV3   = Vector3.new
		local v3ToCyl = myMath.v3ToCyl
		local mod     = myMath.mod
		local ceil    = math.ceil

		local lastFootStepTick = -1
		local ffs = requireGm("FootStepSystem")
		local getStepSound = ffs.getStepSound
		local footStepDurScaler = myMath.getLogisticFunction(0.45, 4, 14)
		local play = requireGm("AudioSystem").play

		function tpp.moveAction.step(dt, now)
			if not alive then return end

			-- moveDir
			local v3 = hrp.Velocity
			local v2 = newV3(v3.x, 0, v3.z)
			local v1 = newV3(0, v3.y, 0)
			local s3 = v3.magnitude
			local s2 = v2.magnitude
			local s1 = v1.magnitude
			local moveDir
			if s3 < 0.5 then
				moveDir = 1
			else
				local moveY = v3ToCyl(v3)
				local y = mod(moveY - tpp.looky, 360)
				moveDir = ceil((y - 22.5) / 45) + 1
				if moveDir == 9 then
					moveDir = 1
				end
			end
			tpp.s1, tpp.s2, tpp.s3 = s1, s2, s3
			tpp.moveDir = moveDir
			tpp.moving3 = s3 > 0.1  -- in 3 directions
			tpp.moving2 = s2 > 0.1  -- in horizontal directions
			tpp.moving1 = s1 > 0.1  -- in vertical direction

			-- footsteps
			if s2 > 3 then
				local footStepDur = 0.5 / footStepDurScaler(s2)
				if now - lastFootStepTick > footStepDur then
					play(
						getStepSound(
							humanoid.FloorMaterial, 
							tpp.lowerStance == "crouch" 
								and "Crouch" 
								or tpp.fullbodyStance == "sprinting" 
									and "Run" 
									or "Walk"
						),
						sh
					)
					lastFootStepTick = now
				end
			end
		end
	end

	-- three stances
	tpp.KfsPlayer = {}
	do
		local playFull = kfsFull.playAnimation
		local playLower = kfsLower.playAnimation
		local playUpper = kfsUpper.playAnimation

		local loadFull = kfsFull.load
		local loadLower = kfsLower.load
		local loadUpper = kfsUpper.load

		tpp.fullbodyQ = false
		local full_, lower_, upper_ -- the animations last time

		local myMath = requireGm("Math")
		local baseSpeedScaler = myMath.getLogisticFunction(0.35, 2, 14)
		local fastSpeedScaler = myMath.getLogisticFunction(0.2, 5, 20)
		local slowSpeedScaler = myMath.getLogisticFunction(0.4, 2, 7)

		local setGunVisible = tpp.weaponSystem.setGunVisible

		local play = requireGm("AudioSystem").play

		function tpp.KfsPlayer.rsStep(dt, now)
			if not alive then
				playFull(dt)
				return
			end

			-- set new states
			local f, u, l = ns.fullbodyStance, ns.upperStance, ns.lowerStance
			if tpp.fullbodyStance ~= f then
				if f == "vaulting" then
					play("Vaulting", sh)
				elseif f == "dancing" then
					setGunVisible(false)
				end

				if tpp.fullbodyStance == "dancing" then
					setGunVisible(true)
				end
				tpp.fullbodyStance = f
			end
			if tpp.upperStance ~= u then
				tpp.upperStance = u
			end
			if tpp.lowerStance ~= l then
				tpp.lowerStance = l
				if l == "crouching" then
					play("Crouching", sh)
				elseif l == "jumping" then
					if f ~= "vaulting" then
						play("Jumping", sh)
					end
				end
			end

			-- -- get the animation names and speed
			local full, lower, upper, sp, reloadFull
			do 
				if f ~= "none" then
					if f == "dancing" then
						full = loadout1.dance
						if tpp.redance then
							tpp.redance = false
							reloadFull = true
						end
					elseif f == "climbing" then
						full = "climbing"
						sp   = tpp.moving1 and 1 or 0
					elseif f == "vaulting" then
						full = "vaulting"
					elseif f == "sprinting" then
						full = "sprinting"
						sp = fastSpeedScaler(tpp.s2)
					end
				else
					-- upper
					if u == "reloading" then
						upper = "lowering" 
					else
						upper = u
					end
					-- lower
					if l == "standing" or l == "jumping" then
						if tpp.moving2 then
							lower = "standWalking"..tpp.moveDir
							sp = baseSpeedScaler(tpp.s2)
						else
							lower = tpp.turning and "standTurn" or "standIdle"
						end
					elseif l == "crouching" then
						if tpp.moving2 then
							lower = "crouchWalking"..tpp.moveDir
							sp = slowSpeedScaler(tpp.s2)
						else
							lower = tpp.turning and "crouchTurn" or "crouchIdle" 
						end
					end
				end
			end

			-- set fullbodyQ
			local fullbodyQNew = (f ~= "none") --(full ~= nil)
			local fullbodyChanged = tpp.fullbodyQ ~= fullbodyQNew
			if fullbodyChanged then
				tpp.fullbodyQ = fullbodyQNew
				if not fullbodyQNew then
					tpp.upperTorsoJointHandler.onFullbodyAnimation(dt, now)
				end
			end

			-- load and play animation
			if fullbodyQNew then
				loadFull(tppAnimations, full, {reload = fullbodyChanged or reloadFull, table0 = specialAnimations})
				playFull(dt, sp)
			else
				loadLower(tppAnimations, lower, {reload = fullbodyChanged, table0 = specialAnimations})
				playLower(dt, sp)
				loadUpper(tppAnimations, upper, {reload = fullbodyChanged, table0 = specialAnimations})
				playUpper(dt, sp)
			end
		end
	end

	tpp.lookJointHandler = {}
	do
		local lookJoint = joints.TppLook
		local lookDefC0 = defC0.TppLook
		local cylToCf = requireGm("Math").cylToCf
		function tpp.lookJointHandler.rsStep(dt, now)
			if not alive then return end
			-- print(tpp.looky, tpp.hrpy)
			lookJoint.C0 = cylToCf(tpp.looky - tpp.hrpy, 0) * lookDefC0
		end
	end

	-- must be before lowertorso?
	tpp.upperTorsoJointHandler = {}
	do
		local newCf         = CFrame.new
		local myMath        = requireGm("Math")
		local invCf         = myMath.invCf
		local rotOnlyCf     = myMath.rotOnlyCf
		local cylAngleRotCf = myMath.cylAngleRotCf
		local abs           = math.abs
		local cfLerp        = myMath.cfLerp
		local clamp         = myMath.clamp
		local iCf           = CFrame.new()

		local const1 = newCf(0, 0.06, -0.1) * joints.LowerTorso.C1
		local const2 = tppAnimations.standIdle[1].goalC0.LowerTorso * tppAnimations.standIdle[1].goalC0.UpperTorso
		consts.idleLookYDelta = 38
		local idleLookYDelta  = consts.idleLookYDelta

		local ltJoint = joints.LowerTorso
		local utJoint = joints.UpperTorso

		local lastUtC0 = utJoint.C0
		local lastUtT0 = tick()

		function tpp.upperTorsoJointHandler.onFullbodyAnimation(dt, now)
			lastUtC0 = utJoint.C0
			lastUtT0 = now
		end

		function tpp.upperTorsoJointHandler.rsStep(dt, now)
			if tpp.fullbodyQ or not alive then return end

			local lookyCf = const1 * invCf(rotOnlyCf(ltJoint.C0)) * const2
			local lookxCf = cylAngleRotCf(idleLookYDelta - 90, 0, -tpp.lookx * 0.5)
			local leaningCf = cylAngleRotCf(idleLookYDelta, 0, tpp.leaningDeg) * newCf(0, -abs(tpp.leaningDeg / 200), 0)

			-- smoothing uppertorso from sprinting to non sprinting
			utJoint.C0 = cfLerp(
				lastUtC0,
				leaningCf * lookxCf * lookyCf, 
				clamp((now - lastUtT0) / 0.25, 0, 1)
			)
		end
	end

	tpp.lowerTorsoJointHandler = {}
	do
		local myMath  = requireGm("Math")
		local newCf   = CFrame.new
		local degToCf = myMath.degToCf
		local invCf   = myMath.invCf
		local cylToCf = myMath.cylToCf

		local idleLookYDelta = consts.idleLookYDelta
		local ltJoint = joints.LowerTorso
		local utJoint = joints.UpperTorso

		function tpp.lowerTorsoJointHandler.rsStep(dt)
			if tpp.fullbodyQ or not alive then return end

			local leaningCf = cylToCf(idleLookYDelta, 0) 
				* newCf(-tpp.leaningDeg / 50, 0, 0) 
				* degToCf(0, 0, tpp.leaningDeg / 4) 
				* invCf(cylToCf(idleLookYDelta, 0))

			local crouchingCf = newCf(0, tpp.crouchingSm, 0)

			ltJoint.Transform = crouchingCf * leaningCf
		end
	end

	tpp.shoulderJointHandler = {}
	do		
		local myMath         = requireGm("Math")
		local cylAngleRotCf  = myMath.cylAngleRotCf
		local idleLookYDelta = consts.idleLookYDelta

		local shoulderJoint = joints.TppShoulder
		local const1 = defC0.TppShoulder

		function tpp.shoulderJointHandler.rsStep(dt)
			if tpp.fullbodyQ or not alive then return end

			local lookxCf = cylAngleRotCf(idleLookYDelta - 90, 0, -tpp.lookx * 0.5)
			shoulderJoint.C0 = lookxCf * const1
		end
	end

	tpp.headJointHandler = {}
	do
		local headJoint = joints.Head
		local headDefC0 = defC0.Head

		local myMath  = requireGm("Math")
		local cylToCf = myMath.cylToCf
		local degToCf = myMath.degToCf

		local idleLookCf = cylToCf(consts.idleLookYDelta, 0)
		local const1 = headDefC0 * idleLookCf
		local aimingMaxHeadTilt = 30

		function tpp.headJointHandler.rsStep(dt, now)
			if tpp.fullbodyQ or not alive then return end

			local aimingCf = degToCf(0, 0, -tpp.aimingSm * aimingMaxHeadTilt)
			headJoint.C0 = const1 * aimingCf
		end
	end

	do -- rsstep
		local funcs = {
			tpp.crouchAction.step,
			tpp.lookJointHandler.rsStep,
			tpp.KfsPlayer.rsStep,
			tpp.upperTorsoJointHandler.rsStep,
			tpp.lowerTorsoJointHandler.rsStep,
			tpp.shoulderJointHandler.rsStep,
			tpp.headJointHandler.rsStep,
			tpp.weaponSystem.step,
		}
		local runFuncs = requireGm("FuncList").runFuncs
		requireGm("FuncList").removeNilFuncs(funcs, 10)

		function tpp.rsStep(dt, now)
			runFuncs(funcs, dt, now)
		end
	end

	do --hbStep
		local funcs = {
			tpp.moveAction.step,
			tpp.leanAction.step,
			tpp.aimAction.step,
			tpp.lookAction.step,
			tpp.danceAction.step,			
			tpp.killAction.step,
		}
		local runFuncs = requireGm("FuncList").runFuncs
		requireGm("FuncList").removeNilFuncs(funcs, 10)

		function tpp.hbStep(dt, now)
			runFuncs(funcs, dt, now)
		end
	end

	-- do -- stepped
	-- 	local isA = game.IsA
	-- 	local function turnOffPhysics(model)
	-- 		if model then
	-- 			for _, v in ipairs(model:GetChildren()) do
	-- 				if isA(v, "BasePart") then
	-- 					v.CanCollide = false
	-- 					-- v.Anchored = true
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- 	function tpp.stepped()
	-- 		turnOffPhysics(char)
	-- 		turnOffPhysics(stash.charNH)
	-- 	end
	-- end

	function tpp.despawn()
		-- char will be destroyed by the server
		if stash.charNH then
			stash.charNH:Destroy()
		end
		tpps[plr.Name] = nil
		tpp = nil
	end

	print("tpp for", plr, "is fully loaded")
	tpps[plr.Name] = tpp
	return tpp
end

do-- scan alive players
	local alivesF = wfc(wfc(rep, "SharedVars"), "Alives")
	for _, v in ipairs(getC(alivesF)) do
		local plrName = v.Name
		local plr = ffc(plrs, plrName)
		if plr then
			spawn(function()
				tppModule.spawn(plr)
			end)
		end
	end
	-- destroy dead chars when joined
	for _, plr in ipairs(getC(plrs)) do
		if plr.Character and not ffc(alivesF, plr.Name) then
			plr.Character:Destroy()
		end
	end
end

do -- setup replication
		
	-- spawn and kill
	---------------------------------

	fpsClient.listen("spawn", tppModule.spawn)

	fpsClient.listen("kill", function(victim, killMethod, killData)
		print("tpp.kill", victim, killMethod, killData)
		local tpp = tpps[victim.Name]
		if tpp and tpp.alive then
			tpp.kill(killMethod, killData)
		end
	end)

	plrs.PlayerRemoving:Connect(function(plr)
		local tpp = tpps[plr.Name]
		if tpp then
			tpp.despawn()
		end
	end)

	-- replications other than states
	--------------------------------

	fpsClient.listen("shoot", function(plr)
		local tpp = tpps[plr.Name]
		if tpp and tpp.alive then
			tpp.shoot()
		end
	end)

	fpsClient.listen("redance", function(plr)
		local tpp = tpps[plr.Name]
		if tpp and tpp.alive then
			tpp.setRedance()
		end
	end)

	fpsClient.listen("look", function(plr, looky, lookx)
		local tpp = tpps[plr.Name]
		if tpp and tpp.alive then
			tpp.setLookAngles(looky, lookx)
		end
	end)

	fpsClient.listen("gearIdx", function(plr, gearIdx)
		local tpp = tpps[plr.Name]
		if tpp and tpp.alive then
			tpp.setGearIdx(gearIdx)
		end
	end)

	-- serialized states
	------------------------------

	local function plrStatesGetter(plr)
		local tpp = tpps[plr.Name] 
		return tpp and tpp.ns
	end
	scsClient.setPlrStatesGetter(plrStatesGetter)
end

do -- setup steps
	local runSer = game:GetService("RunService")

	-- rsstep
	---------------------------------

	function tppModule.rsStep(dt)
		debug.profilebegin("[[[tpps:rsSteps")
		for _, tpp in pairs(tpps) do
			-- ypcall(tpp.rsStep, dt, tick())
			tpp.rsStep(dt, tick())
		end
		debug.profileend("[[[tpps:rsSteps")
	end
	runSer:BindToRenderStep("tppRsSteps", 501, tppModule.rsStep)

	-- hbstep
	------------------------------

	function tppModule.hbStep(dt)
		debug.profilebegin("[[[tpps:hbSteps")
		for _, tpp in pairs(tpps) do
			-- ypcall(tpp.hbStep, dt, tick())
			tpp.hbStep(dt, tick())
		end
		debug.profilebegin("[[[tpps:hbSteps")
	end
	spawn(function()
		local hb = runSer.Heartbeat
		local evwait = game.Changed.Wait
		while true do
			tppModule.hbStep(evwait(hb), tick())
		end
	end)

	-- -- stepped
	-- function tppModule.onStepped(dt)
	-- 	for _, tpp in pairs(tpps) do
	-- 		tpp.stepped()
	-- 	end
	-- end
	-- spawn(function()
	-- 	local stepped = runSer.Stepped
	-- 	local evwait = game.Changed.Wait
	-- 	while true do
	-- 		tppModule.onStepped(evwait(stepped), tick())
	-- 	end
	-- end)

	print("tpp steps setup")
end

local spectatingSystem = {}
do 
	local spectatingReady = false -- lp is dead in match & not in heli / final
	local spectatee = nil -- the tpp being spectated
	local spectatables = {}

	local pv = requireGm("PublicVarsClient")
	local sg, leftArrow, rightArrow

	do -- gui, setGuiVisible, setName
		local sgTemp = wfc(script, "Spectating")
		sg = sgTemp:Clone()
		do
			sg.Enabled = false
			sg.Parent = wfc(lp, "PlayerGui")
		end

		function spectatingSystem.setGuiVisible(bool)  -- safe
			sg.Enabled = bool
		end

		local switcher      = wfc(sg, "Switcher")
		local spectateeText = wfc(switcher, "Spectatee")
		leftArrow  = wfc(switcher, "LeftArrow")
		rightArrow = wfc(switcher, "RightArrow")
		local leftArrowDefPos  = leftArrow.Position
		local rightArrowDefPos = rightArrow.Position
		local minimumSpacing   = rightArrowDefPos.X.Offset

		local setStText = requireGm("ShadedTexts").setStText
		local newU2     = UDim2.new
		setStText(spectateeText, "")

		function spectatingSystem.setName(str)
			setStText(spectateeText, str)

			-- auto adjust length
			local x = spectateeText.text.TextBounds.X / 2 + 30 - minimumSpacing
			if x < 0 then x = 0 end
			leftArrow.Position  = leftArrowDefPos + newU2(0, -x, 0, 0)
			rightArrow.Position = rightArrowDefPos + newU2(0, x, 0, 0)
		end
	end

	do --getSpectatables
		function spectatingSystem.getSpectatables()
			spectatables = {}
			for _, tpp in pairs(tpps) do
				if tpp.alive and tpp.plr and (tpp.plr.Team == lp.Team or db.canSpectateEveryone) then
					spectatables[#spectatables + 1] = tpp
				end
			end
			return spectatables
		end
	end


	do -- spectate and stopSpectating
		local cam       = workspace.CurrentCamera
		local setName   = spectatingSystem.setName

		local ctFollow = Enum.CameraType.Follow
		local ctScriptable = Enum.CameraType.Scriptable

		function spectatingSystem.spectate(tpp)
			local plr = tpp.plr
			local char = tpp.char
			if not ffc(char, 'Head') then return end

			cam.CameraSubject = char.Head
			cam.CameraType    = ctFollow
			spectatee         = tpp

			setName(plr.Name)
		end

		-- local setGuiVisible = spectatingSystem.setGuiVisible
		function spectatingSystem.stopSpectating()
			spectatee = nil
			cam.CameraType = ctScriptable
			-- setGuiVisible(false)
		end
	end

	do -- spectateByIndex
		local mod    = requireGm("Math").mod
		local format = string.format
		local idx    = 1
		local spectate = spectatingSystem.spectate

		function spectatingSystem.spectateByIndex(didx)
			if #spectatables > 0 then
				idx = mod(idx - 1 + didx, #spectatables) + 1
				spectate(spectatables[idx])
			end
		end
	end

	do -- spectateRandom
		local getSpectatables = spectatingSystem.getSpectatables
		local spectate = spectatingSystem.spectate
		function spectatingSystem.spectateRandom()
			if #getSpectatables() > 0 then
				spectate(spectatables[1])
			end
		end
	end

	do -- connect buttons
		local spectateByIndex = spectatingSystem.spectateByIndex
		leftArrow.MouseButton1Click:Connect(function()
			spectateByIndex(-1)
		end)
		rightArrow.MouseButton1Click:Connect(function()
			spectateByIndex(1)
		end)
	end 

	do -- show gui when spectatingReady and there is someone to spectate
		local getSpectatables = spectatingSystem.getSpectatables
		local setGuiVisible = spectatingSystem.setGuiVisible
		local spectateRandom = spectatingSystem.spectateRandom
		spawn(function()
			while wait(0.5) do
				local vis = #getSpectatables() > 0 and spectatingReady
				setGuiVisible(vis)
				if vis and not spectatee then
					spectateRandom()
				end
			end
		end)
	end

	do -- alive and in match -> stop spectating
		 -- other wise -> spectate random after 5 seconds
		-- local spectateRandom = spectatingSystem.spectateRandom -- done in the last module
		local stopSpectating = spectatingSystem.stopSpectating
		local isAliveObj = pv.waitForPObj(lp, "isAlive")
		local phaseObj = pv.waitForObj("Phase")
		local sub = string.sub

		local function onChanged()
			local isAlive = isAliveObj.Value
			local phase = phaseObj.Value

			if not isAlive and sub(phase, 1, 5) == "Match" then
				delay(5, function()
					local isAlive = isAliveObj.Value
					local phase = phaseObj.Value
					if not isAlive and sub(phase, 1, 5) == "Match" then 
						spectatingReady = true
						-- if not spectatee then				-- done in the last module
						-- 	spectateRandom()
						-- end
					end
				end)
			else
				spectatingReady = false
				stopSpectating()
			end
		end
		onChanged()
		isAliveObj.Changed:Connect(onChanged)
		phaseObj.Changed:Connect(onChanged)
	end

	do -- spectatee dead 5 seconds -> spectate others
		local stopSpectating = spectatingSystem.stopSpectating
		spawn(function()
			while wait(1) do
				if spectatee and not spectatee.alive then
					local savedSpectatee = spectatee
					delay(5, function()
						if savedSpectatee == spectatee and not spectatee.alive then
							stopSpectating()
						end
					end)
				end
			end
		end)
	end
end