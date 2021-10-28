local debugSettings = {
	renderSelfTpp = true,
	-- rejectRepForDeadPlrs = false,
}

-- consts and vars
---------------------------------
local renderTS = 0
local plrs     = game.Players
local lp       = plrs.LocalPlayer
local rep      = game.ReplicatedStorage
local wfc      = game.WaitForChild

local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local tableUtils        = requireGm("TableUtils")
local myMath            = requireGm("Math")
local itp               = requireGm("Interpolation")
local rigInfo           = requireGm("RigInfo")
local keyframeAnimation = requireGm("KeyframeAnimation")
local wc                = requireGm("WeaponCustomization")
local particleSystem    = requireGm("ParticleSystem")
local audioSys          = requireGm("AudioSystem")

local events            = wfc(rep, "Events")
local fpsClient         = requireGm("Network").loadRe(wfc(events, "Fps"))
local repClient         = requireGm("ReplicationClient").loadReRf(wfc(events, "RepRe"), wfc(events, "RepRf"))

-- tppAnimation main module
----------------------------
local tppAnimation = {}
do
	-- localizations
	local getChildren   = game.GetChildren
	local ffcWia        = game.FindFirstChildWhichIsA
	local isA           = game.IsA
	local clone         = game.Clone
	local ffc           = game.FindFirstChild
	local newInstance   = Instance.new
	local destroy       = game.Destroy
	
	local cylToCf       = myMath.cylToCf
	local v3ToCyl       = myMath.v3ToCyl
	local cylToV3       = myMath.cylToV3
	local mod           = myMath.mod
	local floor         = math.floor
	local ceil          = math.ceil
	local newV3         = Vector3.new
	local invCf         = CFrame.new().inverse
	local newCf         = CFrame.new
	local deg           = myMath.deg
	local abs           = math.abs
	local degToCf       = myMath.degToCf
	local cfLerp        = myMath.cfLerp
	local clamp         = myMath.clamp
	local cylAngleRotCf = myMath.cylAngleRotCf

	-- consts
	local baseSpeed = 14
	local baseSpeedScaler = myMath.getLogisticFunction(0.35, 2, baseSpeed)
	local fastSpeed = 20
	local fastSpeedScaler = myMath.getLogisticFunction(0.2, 5, fastSpeed)
	local slowSpeed = 7
	local slowSpeedScaler = myMath.getLogisticFunction(0.4, 2, slowSpeed)

	local lookSmoother       = itp.getSmoother(4, 1)
	local idleLookYDelta     = 38
	local crouchSmoother     = itp.getSmoother(5, 0.5)
	local crouchTheta0       = 15
	local aimingMaxHeadTilt  = 30
	local aimingSmoother     = itp.getSmoother(5, 0.8)
	local leaningDegSmoother = itp.getSmoother(1, 1.5)
	local leaningDegAbsMax   = 20 

	local chars      = wfc(workspace, "Chars")
	local nonHitbox  = wfc(workspace, "NonHitbox")
	-- local weaponLib  = wfc(rep, "Weapons")
	local animations = requireGm("TppAnimations")
	for aniName, ani in pairs(animations) do
		ani.name = aniName
	end
	local ltGudC0 = animations.standIdle[1].goalC0.LowerTorso
	local utGudC0 = animations.standIdle[1].goalC0.UpperTorso

	function tppAnimation.new(plr)
		local tpp = {}

		-- init()
		-----------------------------------
		local char     = plr.Character
		local hrp      = wfc(char, "HumanoidRootPart")
		local humanoid = wfc(char, "Humanoid")

		local alive  = true
		local alive_ = true
		local killMethod        
		local killData

		local looky_, lookx_ = repClient.fetchWait("look", plr) --or unpack({0, 0})
		local looky, lookx   = looky_, lookx_
		local movingType_    = repClient.fetchWait("movingType", plr) --or "idle"
		local movingType     = movingType_
		local lowerStance_   = repClient.fetchWait("lowerStance", plr) --or "stand"
		local lowerStance    = lowerStance_
		local upperStance_   = repClient.fetchWait("upperStance", plr) --or "holding"
		local upperStance    = upperStance_
		local weapon_        = repClient.fetchWait("weapon", plr)
		local weapon         = weapon_
		local weaponCache    = {} 		-- store the model, stats, anidata for each slot
		local aiming_        = repClient.fetchWait("aim", plr)
		local aiming         = 0
		local leaningDir_    = repClient.fetchWait("leaningDir", plr)
		local leaningDeg     = 0
		local stamina_       = repClient.fetchWait("stamina", plr)
		local stamina        = stamina_

		local crouchP  = 0
		local lastUtC0 = utGudC0
		local lastUtT0 = 0

		-- assigned later
		local kfsUpper
		local kfsLower
		local kfsFull 

		local charNH
		if plr ~= lp then
			char.Parent  = chars
			assert(ffc(nonHitbox, plr.Name) == nil, string.format("non hit box model already exists for player %s", plr.Name))
			charNH = newInstance("Model") -- nh stands for non-hitbox
			charNH.Parent = nonHitbox
		else
			charNH = char  		-- this is just for debugging
		end

  	-- fill in aniparts, joints and defC0
  	-- put nonhitboxes to workspace.nonHitbox
  	local aniparts, joints, defC0, sounds, stash = {}, {}, {}, {}, {
  		Hitbox    = char,
  		NonHitbox = charNH,
  	}
		for _, bp in ipairs(getChildren(char)) do
			local joint = ffcWia(bp, "Motor6D")
			if isA(bp, "BasePart") and joint then
				local bpn = bp.Name
				aniparts[bpn] = bp
				joints[bpn]   = joint
				defC0[bpn]    = joint.C0
			end

			if not rigInfo.isTppVisPart(char, bp) and plr ~= lp then
				bp.Parent = charNH
			end
		end

		-- sound holder
		local sh = newInstance("Attachment", aniparts.Head)
		sh.Name = "SoundHolder"

		-- breathing system
		local bs = requireGm("BreathingSystem").new(aniparts.Head)

		local weaponModel
		local weaponFirePoint
		local function loadToWeaponCache()
			local model, stats, aniData = wc.get(weapon.weaponName, weapon.attachments, weapon.skin, "tpp")
			aniData.fppAnimations = nil -- free some mem
			weaponCache[weapon.id] = {
				model = model,
				stats = stats,
				aniData = aniData,
			}
		end
		local function unequipWeapon()
			-- disconnect model
			joints.WeaponMain.Part0 = nil
			weaponModel.Parent = nil
			weaponModel = nil
			local cache = weaponCache[weapon.id]
			assert(cache, "weapon cache nil")

			-- unload aniparts, joints, defC0
			for pn, part in pairs(cache.aniData.aniparts) do
				kfsUpper.interpolators[pn] = nil
				kfsLower.interpolators[pn] = nil
				kfsFull.interpolators[pn]  = nil 
				aniparts[pn] = nil
				joints[pn]   = nil
				defC0[pn]    = 0
			end
			weaponFirePoint = nil

			-- unload sounds
			for sn, sound in pairs(cache.aniData.sounds) do
				sounds[sn] = nil
			end

			-- animations?
		end
		local function equipWeapon()		-- @pre: weapon ~= weapon_ and current weapon unloaded
			weapon = weapon_
			if weaponCache[weapon.id] == nil then
				loadToWeaponCache(weapon)
			end
			local cache = weaponCache[weapon.id]

			-- connect the model to the player
			-- should consider weapon customization
			weaponModel = cache.model

			-- load special parts
			weaponFirePoint = cache.aniData.aniparts.FirePoint

			-- load animatable parts and joints
			for pn, part in pairs(cache.aniData.aniparts) do
				aniparts[pn] = part
				joints[pn]   = ffcWia(part, "Motor6D")
				if joints[pn] then
					defC0[pn] = joints[pn].C0
				else
					warn("fpp equipweapon: joints[", pn, "] is nil")
				end
			end

			-- load sounds
			for sn, sound in pairs(cache.aniData.sounds) do
				sounds[sn] = sound
			end

			-- connect the model to the player
			joints.WeaponMain.Part0 = aniparts.RightHand
			-- if lastWeaponC0 then
			-- 	joints.WeaponMain.C0 = lastWeaponC0
			-- end

			weaponModel.Parent = charNH
			weaponModel.Name   = "TppGun"
			weaponModel.Parent = stash.NonHitbox
			stash.TppGun       = weaponModel
		end
		equipWeapon()

		kfsUpper = keyframeAnimation.new(aniparts, joints, defC0, stash)
		kfsLower = keyframeAnimation.new(aniparts, joints, defC0, stash)
		kfsFull  = keyframeAnimation.new(aniparts, joints, defC0, stash)

		-- state changer (input / update from network)
		-----------------------------------------------
		local updaters = {
			look = function(looky__, lookx__)
				assert(looky__ and lookx__)
				looky_, lookx_ = looky__, lookx__
			end;
			movingType = function(movingType__)
				assert(movingType__ and type(movingType__) == "string")
				movingType_ = movingType__
			end;
			lowerStance = function(lowerStance__)
				assert(lowerStance__ and type(lowerStance__) == "string")
				lowerStance_ = lowerStance__
			end;
			upperStance = function(upperStance__)
				assert(upperStance__ and type(upperStance__) == "string")
				upperStance_ = upperStance__
			end;
			leaningDir = function(leaningDir__)
				assert(leaningDir__ and type(leaningDir__) == "string")
				leaningDir_ = leaningDir__
			end;
			weapon = function(weapon__)
				assert(weapon__ and type(weapon__) == "table")
				weapon_ = weapon__
			end;
			aim = function(aiming__)
				assert(aiming__ ~= nil and type(aiming__) == "boolean")
				if aiming__ ~= aiming_ then
					audioSys.play("Aim", sh)
				end
				aiming_ = aiming__
			end;
			shoot = function(hit, ...)
				if hit then
					particleSystem.onHit(hit, ...)
				end
			end;
			stamina = function(stamina__)
				stamina_ = stamina__
			end
		}
		function tpp.update(repKey, ...)
			local updater = updaters[repKey]
			if updater then
				if alive and alive_ then
					updater(...)
				else
					print(string.format("tpp: plr %s not alive, rejecting replications", plr.Name))
				end
			else
				error(string.format("tpp fatal: updater for %s is not setup", repKey))
			end
		end
		
		-- rsStep
		-----------------------------------
		function tpp.rsStep(dt, now)

			if alive ~= alive_ then
				alive = alive_

				local deathDir = 1
				local headshot = false
				if killMethod == "shot" then
				-- death from (left / right / front / back)
					local bulletY, _  = v3ToCyl(killData.deathBulletOrigin - killData.deathHit.Position)
					local y = mod(bulletY - looky, 360)
					if y >= 315 or y < 45 then
						deathDir = 1
					elseif y < 135 then
						deathDir = 2
					elseif y < 215 then
						deathDir = 3
					else
						deathDir = 4
					end					
					headshot = killData.deathHit == "Head"
				elseif killMethod == "debug" then
					-- do nothing
				end

				-- loadanimation based on hit direction and crouching status
				if lowerStance == "crouch" then
					deathDir = deathDir == 3 and 1 or deathDir		-- no crouch death from front animation for now
					kfsFull.loadAnimation(animations["crouchDeath"..deathDir], nil, true)
				else
					if headshot then
						if deathDir == 2 or deathDir == 4 then
							deathDir = 1
						end
						kfsFull.loadAnimation(animations["standDeathHeadshot"..deathDir], nil, true)
					else
						kfsFull.loadAnimation(animations["standDeath"..deathDir], nil, true)
					end
				end

				-- drop the oofing weapon
				local weaponMain    = aniparts.WeaponMain
				aniparts.WeaponMain = nil
				weaponMain.CanCollide = true
				weaponMain.Anchored   = false
				joints.WeaponMain:Destroy()

				-- oofing scream
				audioSys.play("DeathScream", sh)
			end

			if not alive then
				kfsFull.playAnimation(dt)
			else
				-- stamina breathing
				bs.adjust(stamina)
				print(stamina)

				-- looky on look joint
				looky = lookSmoother(looky, looky_, dt)
				lookx = lookSmoother(lookx, lookx_, dt)
				local hrpDirY, hrpDirX = v3ToCyl(hrp.CFrame.lookVector)
				joints.TppLook.C0 = cylToCf(looky - hrpDirY, 0) * defC0.TppLook

				-- weapon
				if weapon_ ~= weapon then
					unequipWeapon()
					equipWeapon()
					kfsUpper.update(aniparts, joints, defC0, stash)
					kfsLower.update(aniparts, joints, defC0, stash)
					kfsFull.update(aniparts, joints, defC0, stash)
				end

				movingType  = movingType_
				lowerStance = lowerStance_
				upperStance = upperStance_

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
					local y = mod(moveY - looky, 360)
					moveDir = ceil((y - 22.5) / 45) + 1
					if moveDir == 9 then
						moveDir = 1
					end
				end

				-- full body animations
				-- ignore lookx and other kfs
				local sp = 1
				local fullBodyAnimation = false
				if movingType == "climbing" then
					fullBodyAnimation = true
					kfsFull.loadAnimation(animations.climbing)
					sp = s1 < 0.1 and 0 or 1
				elseif movingType == "vaulting" then
					kfsFull.loadAnimation(animations.vaulting)
					fullBodyAnimation = true
				elseif movingType == "sprinting" then
					fullBodyAnimation = true
					kfsFull.loadAnimation(animations.sprinting)
					sp = fastSpeedScaler(s2)
				else
					fullBodyAnimation = false

					-- lower part animation
					if (lowerStance == "stand" or lowerStance == "jump") and movingType == "idle" then
						if abs(looky - looky_) < 10 then
							kfsLower.loadAnimation(animations.standIdle)
						else
							kfsLower.loadAnimation(animations.standTurn)
						end
					elseif (lowerStance == "stand" or lowerStance == "jump") and movingType == "walking" then
						kfsLower.loadAnimation(animations["standWalking"..moveDir])
						sp = baseSpeedScaler(s2)
					elseif lowerStance == "crouch" and movingType == "idle" then
						if abs(looky - looky_) < 10 then
							kfsLower.loadAnimation(animations.crouchIdle)
						else
							kfsLower.loadAnimation(animations.crouchTurn)
						end
					elseif lowerStance == "crouch" and movingType == "walking" then
						kfsLower.loadAnimation(animations["crouchWalking"..moveDir])
						sp = slowSpeedScaler(s2)
					end

					-- upper part animation
					if upperStance == "holding" then
						kfsUpper.loadAnimation(animations.weaponHolding)
					elseif upperStance == "lowering" then
						kfsUpper.loadAnimation(animations.weaponLowering)
					elseif upperStance == "drawing" then
						kfsUpper.loadAnimation(animations.weaponHolding)
					-- elseif upperStance == "reloading" then
					-- 	kfsUpper.loadAnimation(animations.weaponReloading)
					end
				end

				if fullBodyAnimation then
					kfsLower.pause()
					kfsUpper.pause()
					lastUtC0 = joints.UpperTorso.C0
					lastUtT0 = now
				else
					kfsFull.pause()
				end

				-- keyframe animation
				kfsFull.playAnimation(dt, sp)
				kfsUpper.playAnimation(dt, sp)
				kfsLower.playAnimation(dt, sp)

				-- procedual animation
				if not fullBodyAnimation then
					-- looky on upper torso and head
					joints.UpperTorso.C0 = newCf(0, 0.06, -0.1) 
						* joints.LowerTorso.C1 
						* invCf(joints.LowerTorso.C0 - joints.LowerTorso.C0.p) 
						* ltGudC0 * utGudC0
					joints.Head.C0       = defC0.Head * cylToCf(idleLookYDelta, 0)

					-- aiming on head
					aiming         = aimingSmoother(aiming, aiming_ and 1 or 0, dt)
					joints.Head.C0 = joints.Head.C0 
						* degToCf(0, 0, -aiming * aimingMaxHeadTilt)

					-- lookx on upper torso and shoulder
					local rotLookX = cylAngleRotCf(idleLookYDelta - 90, 0, -lookx * 0.5)
					joints.UpperTorso.C0  = rotLookX * joints.UpperTorso.C0
					joints.TppShoulder.C0 = rotLookX * defC0.TppShoulder

					-- leaning on lowerTorso and upper torso
					local leaningDeg_ = 0
					if leaningDir_ == "left" then
						leaningDeg_ = leaningDegAbsMax
					elseif leaningDir_ == "right" then
						leaningDeg_ = -leaningDegAbsMax
					end
					leaningDeg = leaningDegSmoother(leaningDeg, leaningDeg_, dt)
					joints.UpperTorso.C0        = cylAngleRotCf(idleLookYDelta, 0, leaningDeg) 
						* newCf(0, -abs(leaningDeg / 200), 0) 
						* joints.UpperTorso.C0
					joints.LowerTorso.Transform = cylToCf(idleLookYDelta, 0) 
						* newCf(-leaningDeg / 50, 0, 0) 
						* degToCf(0, 0, leaningDeg / 4) 
						* invCf(cylToCf(idleLookYDelta, 0))

					-- smoothing crouch
					crouchP = crouchSmoother(crouchP, lowerStance == "crouch" and 1 or 0, dt)
					joints.LowerTorso.Transform = newCf(0, crouchP, 0) * joints.LowerTorso.Transform

					-- smoothing uppertorso from sprinting to non sprinting
					joints.UpperTorso.C0 = cfLerp(lastUtC0, joints.UpperTorso.C0, clamp((now - lastUtT0) / 0.25, 0, 1))
				end
			end
		end

		function tpp.die(attacker, killMethod_, ...)
			assert(alive, string.format("plrToDie %s is not alive", plr.Name))
			alive_     = false
			killMethod = killMethod_
			killData   = {...}
		end

		function tpp.destroy()
			if stash.Hitbox then
				destroy(stash.Hitbox)
			end
			if stash.Nonhitbox then
				destroy(stash.nonHitbox)
			end
		end

		return tpp
	end
end

-- main
----------------------------------
do
	local evwait  = game.Changed.Wait
	local runser  = game:GetService("RunService")
	local rs      = runser.RenderStepped
	local hb      = runser.Heartbeat
	local ffc     = game.FindFirstChild

	local tpps = {}
	local function loadTpp(plr)
		local plrName = plr.Name
		assert(tpps[plrName] == nil or warn("tried to load tpp on an already loaded character", plr))
		tpps[plr.Name] = tppAnimation.new(plr)
	end
	local function unloadTpp(plr)
		local plrName = plr.Name
		assert(tpps[plrName], "tried to unload nil tpp", plr)
		tpps[plr.Name].destroy()
		tpps[plr.Name] = nil
	end

	-- spawn & despawn
	-- for plrName, _ in pairs(sv.get("alivePlrs")) do @todo read-only replication
	-- 	local plr = ffc(plrs, plrName)
	-- 	if plr then
	-- 		loadTpp(plr)
	-- 	end
	-- end
	fpsClient.listen("spawn", function(...)
		local args = {...}
		local plr  = args[1]; assert(plr)
		if plr ~= lp or debugSettings.renderSelfTpp then
			loadTpp(plr)
		end
	end)
	fpsClient.listen("kill", function(plrToKill, killMethod, ...)
		if plrToKill then
			local tppToKill = tpps[plrToKill.Name]
			if tppToKill then
				tppToKill.die(killMethod, ...)
			else
				warn(string.format("tpp: %s hasn't spawned!", plrToKill.Name))
			end
		else
			error("plrToKill is nil")
		end
	end)
	fpsClient.listen("despawn", function(...)
		local args = {...}
		local plr  = args[1]; assert(plr)
			if plr ~= lp or debugSettings.renderSelfTpp then
			unloadTpp(plr)
			-- that player's client will destroy its own character
			-- so probably just do some garbage collection here.
		end
	end)

	-- replication
	-- updater: a player whose information is updated via network
	local distributer = function(updater, repKey, ...)
		local tpp = tpps[updater.Name]
		if tpp then
			tpp.update(repKey, ...)
		end
	end
	repClient.setDistributer(distributer)

	-- render threads
	spawn(function()
		local lastTick = tick()
		while evwait(rs) do
			local now = tick()
			local dt  = now - lastTick

			debug.profilebegin("[[tpp: rsStep all char")
			for _, tpp in pairs(tpps) do
				tpp.rsStep(dt, now)
			end
			debug.profileend("[[tpp: rrsStep all char")

			renderTS = renderTS + 1
			lastTick = now
		end
	end)
	-- spawn(function()
	-- 	local lastTick = tick()
	-- 	while evwait(hb) do
	-- 		local now = tick()
	-- 		local dt  = now - lastTick

	-- 		debug.profilebegin("[[tpp: hbStep all char")
	-- 		for _, tpp in pairs(tpps) do
	-- 			tpp.hbStep(dt, now)
	-- 		end
	-- 		debug.profileend("[[tpp: hbStep all char")

	-- 		lastTick = now
	-- 	end
	-- end)
end