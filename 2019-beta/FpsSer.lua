-- consts
------------------------------------------------
local plrs      = game.Players
local rep       = game.ReplicatedStorage
local wfc       = game.WaitForChild
local ffc       = game.FindFirstChild

local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local printTable = requireGm("TableUtils").printTable
local db         = requireGm("DebugSettings")()

local fpsServer
local mainframeServer
local fetchServer
do -- load remotes
	local events    = wfc(rep, "Events")
	local loadRe    = requireGm("Network").loadRe
	local loadRf    = requireGm("FetchServer").loadRf
	fpsServer       = loadRe(wfc(events, "FpsRe"), {socketEnabled = true, re2 = wfc(events, "FpsForwardRe")})
	mainframeServer = loadRe(wfc(events, "MainframeRe"), {socketEnabled = false})
	fetchServer     = loadRf(wfc(events, "FetchRf"))
end

-- predefine
local statsTracker = {}


-- vars for quick join
-------------------------
local roomInitInfo = nil

-- data store system
-------------------------------
local datastore = {}
do
	local uploaded = {}
	local plrDatas = {}
	local loadout1s = {}
	do -- publicize the plrdatas
		datastore.plrDatas = plrDatas
		datastore.loadout1s = loadout1s
		fetchServer.addTableToCache("plrData", plrDatas)
		fetchServer.addTableToCache("loadout1", loadout1s)
	end
	
	local sql = require(game.ServerStorage.SQL).query
	local def = requireGm("DefaultPlrData")

	do-- processAfterDownload: consider editions and null fields
		local currVersion = db.currVersion
		local getMoneyAndExpMultiplier = requireGm("Progression").getMoneyAndExpMultiplier
		function datastore.processAfterDownload(raw, plr)
			local temp = def.cloneAll(plr)
			local d = raw

			-- consider editions
			d.highestEditionLevel = 0 	-- free edition
			-- standard edition
			if d.has_edition1 then
				d.highestEditionLevel = 1
			end
			-- gold's edition
			if d.edition2_expiration_date then
				if sql("select '%s'::date >= current_date as b", d.edition2_expiration_date)[1].b then
					d.has_edition2 = true
					d.highestEditionLevel = 2
				end
			end
			-- founder's edition
			if d.edition3_expiration_date then
				if sql("select '%s'::date >= current_date as b", d.edition3_expiration_date)[1].b then
					d.has_edition3 = true
					d.highestEditionLevel = 3
				end
			end
			d.moneyMult, d.expMult = getMoneyAndExpMultiplier(d.highestEditionLevel)
			if db.fastProgression then
				d.expMult = 100
				d.moneyMult = 100
			end

			-- fill in null fields
			for k, v in pairs(temp) do
				if d[k] == nil then
					d[k] = v
					print("ds: fill in the null field", k, "with default data for", plr)
				end
			end

			return d
		end
	end

	do -- onPlayerAdded / removing
		local processAfterDownload = datastore.processAfterDownload
		local kick = require(game.ServerStorage.KickSystem).kick
		local setP = requireGm("PublicVarsServer").setP
		local getStats = requireGm("WeaponCustomization").get

		function datastore.onPlayerAdded(plr)
			local plrName = plr.Name

			local d = nil
			if db.sqlEnabled then
				local raw = sql("select * from PLAYERTABLE where user_id = %d", plr.UserId)[1]
				d = raw and processAfterDownload(raw, plr)
			else
				d = def.cloneAll(plr)
			end
			if d == nil then
				kick(plr, "no data found in datastore")
				return
			end
			
			local loadout1 = d.loadouts[1]
			loadout1s[plrName] = loadout1
			plrDatas[plrName] = d

			local slots = loadout1.weapons
			-- fpsCore.guns[plrName] = slots
			for i, slot in ipairs(slots) do
				_, slot.stats = getStats(slot.weaponName, slot.attachments, "fpp")
			end

			setP(plr, "Level", d.level)
		end

		function datastore.onPlayerRemoving(plr)
			local plrName = plr.Name
			datastore.upload(plr, {penalty = true})
			loadout1s[plrName] = nil
			plrDatas[plrName]  = nil
			uploaded[plrName]  = nil
		end
	end

	do -- combine (combine statsTracker into data)
		local prg = requireGm("Progression")
		local getLevelInt = prg.getLevelInt
		local penaltyMoneyMult = prg.penaltyMoneyMult

		-- @param d: plr data
		-- @param s: plr stats
		-- @param args.penalty (a boolean value)
		function datastore.combine(d, s, args)
			local plrName = d.user_name

			-- local h = d.highestEditionLevel or 0
			-- local moneyMult, expMult = prg.getMoneyAndExpMultiplier(h)
			-- print(plrName, "has edition", h, "moneyMult =", moneyMult, "expMult =", expMult)

			d.exp   = d.exp + s.score * d.expMult
			d.level = getLevelInt(d.exp)

			local p = args.penalty and penaltyMoneyMult or 1
			local moneyInc = s.score * p * d.moneyMult
			d.money        = d.money + moneyInc
			d.all_money    = d.all_money + moneyInc

			d.headshots     = d.headshots + s.headshots.all
			d.kills         = d.kills + s.kills.all
			d.damage        = d.damage + s.damage.all
			d.assists       = d.assists + s.assists
			d.deaths        = d.deaths + s.deaths
			d.bullets_hit   = d.bullets_hit + s.bullets_hit.all
			d.bullets_fired = d.bullets_fired + s.bullets_fired.all
			d.casual_wins   = d.casual_wins + s.win

			-- weapon
			for _, k in ipairs({"headshots", "kills", "damage", "bullets_hit", "bullets_fired"}) do
				for weaponName, inc in pairs(s[k]) do
					local w = d.weapons[weaponName]
					if w then
						w[k] = (w[k] or 0) + inc
					end
				end
			end

			return d
		end
	end

	do -- upload 
		local combine = datastore.combine
		local http    = game:GetService("HttpService")
		local toJSON  = http.JSONEncode

		-- @param: args.penalty true or false
		-- wont upload twice
		function datastore.upload(plr, args)
			if not db.sqlEnabled then return end
			local plrName = plr.Name
			if not uploaded[plrName] then
				uploaded[plrName] = true

				local s = statsTracker.stats[plrName]
				if s then
					local d = plrDatas[plrName]
					if d then
						print("load stats into plr data for", plr, "penalty =", args.penalty)
						d = combine(d, s, args)

						sql([[update PLAYERTABLE set
							exp = %d,
							level = %d,
							money = %d,
							all_money = %d,

							headshots = %d,
							kills = %d,
							casual_wins = %d,
							damage = %d,
							assists = %d,
							deaths = %d,
							bullets_hit = %d,
							bullets_fired = %d,

							weapons = '%s'

							where user_id = %d]],

							d.exp,
							d.level,
							d.money,
							d.all_money,

							d.headshots,
							d.kills,
							d.casual_wins,
							d.damage,
							d.assists,
							d.deaths,
							d.bullets_hit,
							d.bullets_fired,

							toJSON(http, d.weapons),

							plr.UserId
						)
					else
						warn("datastore: trying to upload", plr, "'s data but data not found. aborted")									
					end
				else
					warn("datastore: trying to upload", plr, "'s data but stats tracker not found. aborted")				
				end
			else
				warn("datastore: trying to upload", plr, "'s data but already uploaded before. aborted")
			end
		end
	end

	do --uploadAll
		local upload = datastore.upload
		-- @param: args.penalty true or false
		function datastore.uploadAll(args)
			for _, plr in ipairs(plrs:GetPlayers()) do
				upload(plr, args)
			end
		end
		function datastore.uploadAllAsync(args)
			for _, plr in ipairs(plrs:GetPlayers()) do
				spawn(function()
					upload(plr, args)
				end)
			end
		end
	end

	do -- newLevelFromScoreQ, used in statstracker
		local getLevelInt = requireGm("Progression").getLevelInt
		function datastore.newLevelFromScoreQ(plr, oldScore, inc) 
			local d = plrDatas[plr.Name]
			if d then
				local baseExp = d.exp
				local oldLevel = getLevelInt(baseExp + oldScore * d.expMult)
				local newLevel = getLevelInt(baseExp + (oldScore + inc) * d.expMult)
				if newLevel ~= oldLevel then
					return newLevel
				end
			end
		end
	end
end

-- stats tracker (for keeping track of the players performance in this match)
-- should not be used for isAlive and other stuff
----------------------------------
do
	local stats = {}
	statsTracker.stats = stats

	do -- onplayeradded / removing
		local setP = requireGm("PublicVarsServer").setP

		function statsTracker.onPlayerAdded(plr)
			local plrName = plr.Name

			if stats[plrName] then
				warn("stats tracker: new plr", plr, "already has a stats table. weird. table replaced with a new one")
			end
			-- order according to datastore.upload
			stats[plrName] = {
				score = 0,  	-- should be called using change(). change exp/level/money/all_money

				headshots     = {all = 0, },
				kills         = {all = 0, },
				win           = 0,
				damage        = {all = 0, },
				assists       = 0,
				deaths        = 0,
				bullets_hit   = {all = 0, },
				bullets_fired = {all = 0, },
			
				-- just char
				injurers = {},
			}

			setP(plr, "Kills", 0)
			setP(plr, "Deaths", 0)
			setP(plr, "Score", 0)
		end

		function statsTracker.onPlayerRemoving(plr)
			local plrName = plr.Name
			stats[plrName] = nil
		end
	end

	do -- incScore
		local newLevelFromScoreQ = datastore.newLevelFromScoreQ
		local prg        = requireGm("Progression")
		local fireClient = fpsServer.fireClient
		local setP       = requireGm("PublicVarsServer").setP

		function statsTracker.incScore(plr, inc, type, args)
			if typeof(inc) == 'string' then
				inc = prg[inc]
			end

			-- increase score and detect if level up
			local plrStats = stats[plr.Name]
			if plrStats then
				local newLevel = newLevelFromScoreQ(plr, plrStats.score, inc)
				plrStats.score = plrStats.score + inc
				if newLevel then
					fireClient(plr, "level.up", newLevel)
					setP(plr, "Level", newLevel)
				end
				-- print("inc score plr +", inc, "to", plrStats.score)
			else
				-- print("statsTracker.inscore(", plr, ") but stats[plr] is nil aborted")
				return
			end

			-- annouce the change to player's score gui with type
			fireClient(plr, "score.inc", inc, type, args)
			setP(plr, "Score", plrStats.score)
		end
	end

	function statsTracker.onBulletFired(firer, weaponName)
		local t = stats[firer.Name].bullets_fired
		t.all = t.all + 1
		t[weaponName] = (t[weaponName] or 0) + 1
	end

	do -- onBulletHit
		local incScore = statsTracker.incScore
		local prg        = requireGm("Progression")
		local scorePerDamage = prg.scorePerDamage
		function statsTracker.onBulletHit(attacker, victim, weaponName, dmg)
			local as = stats[attacker.Name]
			local vs = stats[victim.Name]

			if as then
				-- bullets hit
				local t       = as.bullets_hit
				t.all         = t.all + 1
				t[weaponName] = (t[weaponName] or 0) + 1

				-- damage
				local damage = dmg
				local t      = as.damage
				t.all         = t.all + damage
				t[weaponName] = (t[weaponName] or 0) + damage
				incScore(attacker, scorePerDamage * damage, "hit") --{victim = victim, hit = hit})
			end
			if vs then
				vs.injurers[attacker.Name] = true	
			end
		end
	end

	-- function statsTracker.onPlayerAlive(plr)
	-- 	-- stats[plr.Name].injurers = {}
	-- end
	do -- onKill
		local incScore = statsTracker.incScore
		local setP     = requireGm("PublicVarsServer").setP
		local prg      = requireGm("Progression")
		local scorePerKill = prg.scorePerKill
		local scorePerHeadshot = prg.scorePerHeadshot

		function statsTracker.onKill(victim, killMethod, killData)
			-- print('statsTracker.onKill', victim, killMethod, killData)
			local vs = stats[victim.Name]

			-- victim death
			if killMethod == "shot" or killMethod == "reset" then
				if vs then
					vs.deaths = vs.deaths + 1
					setP(victim, "Deaths", vs.deaths)
				end
			end

			-- attacker kills, headshots
			if killMethod == "shot" then
				local attacker = killData.attacker
				local as = stats[attacker.Name]
				local w  = killData.weaponName
				if as then
					local t = as.kills
					t.all   = t.all + 1
					t[w]    = (t[w] or 0) + 1
					setP(attacker, "Kills", t.all)

					killData.victim = victim
					if killData.hit and killData.hit.Name == "Head" then
						local t = as.headshots
						t.all   = t.all + 1
						t[w]    = (t[w] or 0) + 1
						incScore(attacker, scorePerKill + scorePerHeadshot, "kill", killData)
					else
						incScore(attacker, scorePerKill, "kill", killData)
					end
				end
			end

			-- assisters
			if vs and vs.injurers then
				local attacker
				if killMethod == "shot" then
					attacker = killData.attacker
				end
				for plrName, _ in pairs(vs.injurers) do
					local as = stats[plrName]
					if as then
						as.assists = as.assists + 1
					end
					vs.injurers[plrName] = nil
				end
			end
		end
	end
end


-- fpsCore
-- handles all the spawning and killing and despawning
-- and all replications
-----------------------------------------------
local fpsCore = {}
do
	local alivesF = wfc(wfc(rep, "SharedVars"), "Alives")

	local spawnId   = {}
	local isAlive   = {}; fpsCore.isAlive = isAlive
	local health    = {}
	local regens    = {}
	local spawnable = {}; fpsCore.spawnable = spawnable
	local currWeaponName = {} -- for stats tracking
	local skins = {}
	-- local guns = {}; fpsCore.guns = guns
	local projHolders = workspace.Projectiles
	fetchServer.addTableToCache("skin", skins) -- skins taking side into account (have a better method? @todo)

	do -- setup the bindable event
		local aliveEv = Instance.new("BindableEvent")
		local deadEv  = Instance.new("BindableEvent")
		local healthEv= Instance.new("BindableEvent")
		local fire = Instance.new("BindableEvent").Fire
		function fpsCore.fireOnAlive(plr)
			fire(aliveEv, plr)
		end
		function fpsCore.fireOnDead(plr)
			fire(deadEv, plr)
		end
		function fpsCore.fireOnHealthChanged(plr, delta)
			fire(healthEv, plr, delta)
		end
		fpsCore.onAlive = aliveEv.Event
		fpsCore.onDead  = deadEv.Event
		fpsCore.onHealthChanged = healthEv.Event
	end

	local lastPos = {}
	do -- lastPosTracking
		local ur = 1 -- update rate
		local getC = game.GetChildren

		function fpsCore.getHrp(plr)
			return plr.Character and ffc(plr.Character, "HumanoidRootPart") and plr.Character.HumanoidRootPart
		end
		local getHrp = fpsCore.getHrp
		
		spawn(function()
			while wait(ur) do
				for _, plr in ipairs(getC(plrs)) do
					local hrp = getHrp(plr)
					if hrp then
						lastPos[plr.Name] = hrp.Position
					end
				end
			end
		end)

		function fpsCore.getCurrOrLastPosition(plr)
			local hrp = getHrp(plr)
			return hrp and hrp.Position or lastPos[plr.Name]
			-- may still return nil if the player's position has not been cached into the lastpos array
		end		
	end

	do -- setAlive
		-- manages the shared vars
		-- and the two events
		local setP        = requireGm("PublicVarsServer").setP
		local newInstance = Instance.new
		local fireOnAlive = fpsCore.fireOnAlive
		local fireOnDead  = fpsCore.fireOnDead
		local destroy     = game.Destroy

		function fpsCore.setAlive(plr, bool)
			isAlive[plr.Name] = bool
			if bool then
				local aliveStr = ffc(alivesF, plr.Name)
				if aliveStr then
					warn("fpsser: setting isAlive = true for", plr, "but already in the alivefolder.  continued")
				else
					local str = newInstance("StringValue")
					str.Name  = plr.Name
					str.Parent = alivesF
				end
				fireOnAlive(plr)
				setP(plr, "isAlive", true)
			else 
				local aliveStr = ffc(alivesF, plr.Name)
				if aliveStr then
					destroy(aliveStr)
				else
					warn("fpsser: setting isAlive = false for", plr, "but not in the alivefolder.  continued")
				end
				fireOnDead(plr)
				setP(plr, "isAlive", false)
			end
		end
	end

	do -- spawn
		-- spawn logic: if the server sends the spawn event 
		--   the client will always destroy the original character
		--   and spawn a new one
		--   so spawning should always be successful
		local setAlive = fpsCore.setAlive
		local random   = math.random
		local newCf    = CFrame.new

		-- @param [args.side]: [] means it can be nil
		-- 										"Atk" or "Def"
		-- @param spawnLocation: with directions
		function fpsCore.spawn(plr, args)

			plr:LoadCharacter()
			if not plr.Character then
				plr.CharacterAdded:wait()
			end

			local char = plr.Character
			char.HumanoidRootPart.CFrame = newCf(args.spawnLocation.Position)

			local plrName    = plr.Name
			spawnId[plrName] = spawnId[plrName] + 1
			isAlive[plrName] = true
			health[plrName]  = 100

			args.skin = (args.side or (random(1, 2) == 1 and "atk" or "def")).."_Default"
			skins[plrName] = args.skin
			-- print(args.skin)
			fpsServer.fireAllClients("spawn", plr, args)

			setAlive(plr, true)
			-- statsTracker.onPlayerAlive(plr)
		end
	end

	do -- kill
		-- kill logic: the server doesn't send despawn command. 
		--   the despawn function is controlled fully by the client. 
		--   the server only kills
		local setAlive = fpsCore.setAlive

		function fpsCore.kill(victim, killMethod, killData)
			print("fpscore.kill", victim, killMethod, killData)
			fpsServer.fireAllClients("kill", victim, killMethod, killData)
			setAlive(victim, false)
			statsTracker.onKill(victim, killMethod, killData)
		end
	end

	do -- killall
		local getC = game.GetChildren
		local kill = fpsCore.kill
		function fpsCore.killAll(killMethod, killData)
			for _ , plr in ipairs(getC(plrs)) do
				if spawnable[plr.Name] and isAlive[plr.Name] then
					kill(plr, killMethod, killData)
				end
			end
		end
	end

	do -- setup replication 
		-- character state replication
		local scsServer = requireGm("SerializedCharStates").loadRe(wfc(wfc(rep, "Events"), "CharStatesRe"))
		fpsCore.states = scsServer.cache
		fetchServer.addTableToCache("states", fpsCore.states)

		-- cache gear idx
		fpsCore.gearIdxs = fpsServer.cacheKey("gearIdx")  	-- into a table
		fetchServer.addTableToCache("gearIdx", fpsCore.gearIdxs)

		do -- getCurrGun & stats
			local loadout1s = datastore.loadout1s
			local gearIdxs = fpsCore.gearIdxs
			function fpsCore.getCurrGun(plr)
				local idx = gearIdxs[plr.Name][1]
				if idx then
					local plrGuns = loadout1s[plr.Name].weapons
					if plrGuns then
						local gun = plrGuns[idx]
						if gun then
							return gun, gun.stats 
						end
					end
				end
			end
		end

		do -- bullethit
			local statsTrackerOnBulletHit = statsTracker.onBulletHit
			local kill = fpsCore.kill
			local fpsServerFireClient = fpsServer.fireClient
			fpsServer.listen("bulletHit", function(attacker, hit, p1, victim, dmg)
				-- print(attacker, victim, hit, dmg)
				fpsServer.fireAllClients("bulletHit", attacker, hit, p1)

				if not (attacker and victim and hit and dmg) then return end

				local attackerName = attacker.Name
				local victimName   = victim.Name
				local weaponName   = currWeaponName[attackerName]
				-- print(isAlive[attackerName], isAlive[victimName], (attacker.Team ~= victim.Team or db.teamKillEnabled), weaponName)
				if isAlive[attackerName] and isAlive[victimName] and (attacker.Team ~= victim.Team or db.teamKillEnabled) and weaponName then

					health[victimName] = health[victimName] - dmg

					local attackInfo = {
						hit = hit,
						dmg = dmg,
						attacker   = attacker,
						weaponName = weaponName,
						-- victim   = victim,
					}
					statsTrackerOnBulletHit(attacker, victim, weaponName, dmg)

					if health[victimName] <= 0 then
						kill(victim, "shot", attackInfo)
					else
						fpsServerFireClient(victim, "health", health[victimName], attackInfo)
						fpsCore.fireOnHealthChanged(victim, -dmg)
					end
				end
			end)
		end

		do -- swtich to weapon. log the current weapon on server side for stats purposes
			local loadout1s = datastore.loadout1s
			fpsServer.listen("gearIdx", function(plr, gearIdx)
				if loadout1s[plr.Name] then
					currWeaponName[plr.Name] = loadout1s[plr.Name].weapons[gearIdx].weaponName
				else
					warn("plr switches weapon but loadout1s is nil")
				end
			end)
		end

		fpsServer.listen("reset", function(plr)
			if not plr then return end
			if isAlive[plr.Name] then
				fpsCore.kill(plr, "reset")
			end
		end)

		-- danceid, look is updated(forwarded) in fpsServer through auto-forwarding

		-- shooting and projectiles
		if not db.statsPanel then  -- statsPanel will disable projectiles created on server
			local trackBulletFired = statsTracker.onBulletFired
			local projTemp = rep.GlobalModules.Projectile.Proj
			local clone = game.Clone
			local newV3 = Vector3.new
			local newBrickColor = BrickColor.new
			local debris = game:GetService("Debris")
			local addToDebris = debris.AddItem
			local getCurrGun = fpsCore.getCurrGun
			-- width and length is currently not replicated
			fpsServer.listen("shoot", function(plr, projId)
				local pt = clone(projTemp)
				pt.Name = projId

				local gun, stats = getCurrGun(plr)
				local color = stats.bulletColor
				local width = stats.bulletWidth
				local length = stats.bulletLength
				if color then
					pt.BrickColor = newBrickColor(color)
				end
				local w = width or pt.Size.X
				local l = length or pt.Size.Z
				pt.Size = newV3(w, w, l) 	
				pt.Transparency = 1 -- invisible by default
				pt.AntiG.Force = newV3(0, workspace.Gravity, 0)
				pt.Parent = wfc(projHolders, plr.Name)
				pt:SetNetworkOwner(plr)
				addToDebris(debris, pt, 5) -- auto destroy

				local weaponName = currWeaponName[plr.Name]
				if weaponName then
					trackBulletFired(plr, weaponName)
				else
					warn(plr, "shoots but currWeaponName is nil")
				end
			end)
		end
	end

	if db.healthRegenSpeed then 	-- health regen

		local sp = db.healthRegenSpeed
		local setP = requireGm("PublicVarsServer").setP
		local function newRegen(plr)
			local plrName = plr.Name
			local self = {}
			local running = true
			spawn(function()
				while wait(1) and running and ffc(plrs, plrName) do
					local h = health[plrName]
					local newH = h + sp > 100 and 100 or h + sp
					if newH ~= h then
						h = newH
						health[plrName] = h
						setP(plr, "Health", h)
					end
				end
				print("health regen for", plrName, "has stopped")
			end)
			function self.stop()
				running = false
			end
			return self
		end

		local healthRegenDelay = db.healthRegenDelay  -- @todo
		fpsCore.onHealthChanged:Connect(function(plr, delta)
			if delta < 0 then
				local plrName = plr.Name
				local regen = regens[plrName]
				if regen then
					regen.stop()
					regens[plrName] = nil
				end

				local savedHealth = health[plrName]
				delay(healthRegenDelay, function()
					if savedHealth == health[plrName] and isAlive[plrName] then
						print("start regenerating health for", plr)
						regens[plrName] = newRegen(plr)
					end
				end)
			end
		end)
	end

	do -- playeradded / removing
		local setP = requireGm("PublicVarsServer").setP
		local cac = game.ClearAllChildren
		local destroy = game.Destroy
		function fpsCore.onPlayerAdded(plr)
			local plrName = plr.Name
			spawnId[plrName] = 0
			setP(plr, "isAlive", false)
			setP(plr, "Health", 0) 

			local projHolder = ffc(projHolders, plrName)
			if not projHolder then
				projHolder = Instance.new("Folder")
				projHolder.Name = plrName
				projHolder.Parent = projHolders
			else
				cac(projHolder)
			end

			-- guns = {}
		end
		function fpsCore.onPlayerRemoving(plr)
			local plrName = plr.Name
			spawnId[plrName] = nil
			isAlive[plrName] = nil
			health[plrName]  = nil
			lastPos[plrName] = nil
			regens[plrName]  = nil
			currWeaponName[plrName] = nil
			spawnable[plrName] = nil
			-- guns[plrName] = nil

			local projHolder = ffc(projHolders, plrName)
			if projHolder then
				destroy(projHolder)
			end
		end
	end
end

-- -- server-side projectile handler
-- local projectileHandler = {}
-- do
-- 	fpsServer.listen("shoot")
-- end

-- party system
-------------------------------
local partySystem = {}
do
	local parties = {}
	partySystem.parties = parties
	function partySystem.onPlayerAdded(plr, joinData)
		local plrName = plr.Name
		if joinData.parties then
			parties[plrName] = joinData.parties[plrName]
			return
		end
		if joinData.party then
			parties[plrName] = joinData.party 	-- a dictionary of {memberName -> 1}
			return
		end
		warn(plr, "loaded but has no party in the joindata")
	end
	function partySystem.onPlayerRemoving(plr)
		local plrName = plr.Name
		local party = parties[plrName]
		if party then
			for memberName, _ in pairs(party) do
				local party2 = parties[memberName]
				if party2 then
					party2[plrName] = nil
				end
			end
			parties[plrName] = nil
		else
			warn(plr, "leaves the game but has no party aborted")
		end
	end
end


-- quickjoin system
-- creating / maintaining / destroying the row in sql 
-----------------------------
local quickjoinSystem = {}
do
	local rowCreated  = false
	local instance_id = game.JobId
	local place_id    = game.PlaceId
	local sql         = require(game.ServerStorage.SQL).query
	local region      = require(game.ServerStorage.ServerRegion).region or "err_match"
	function quickjoinSystem.removeRow()
		if not db.matchmakingEnabled then return end
		sql("delete from SERVERTABLE where instance_id = '%s'", instance_id)
	end
	function quickjoinSystem.unlockQuickjoin()
		if not db.matchmakingEnabled then return end
		sql("update SERVERTABLE set quickjoin_lock = timestamp '-infinity' where instance_id = '%s'", instance_id)
	end
	-- @pre: plr.team
	function quickjoinSystem.onPlayerAdded(plr)
		if not db.matchmakingEnabled then return end
		if not rowCreated and db.matchmakingEnabled then
			repeat 
				wait(0.5)
			until rowCreated
		end
		local team = plr.Team
		if team then
			local getKey = {Alpha = "alpha_cnt", Beta = "beta_cnt"}
			local key = getKey[team.Name]
			local team_cnt = #team:GetPlayers()
			sql([[update SERVERTABLE set
				%s = %d,
				player_cnt = %d
				where instance_id = '%s']],
				key, team_cnt,
				#plrs:GetPlayers(),
				instance_id
			)
		end
	end
	-- @pre: plr.team
	function quickjoinSystem.onPlayerRemoving(plr)
		if not db.matchmakingEnabled then return end
		if not rowCreated and db.matchmakingEnabled then
			repeat 
				wait(0.5)
			until rowCreated
		end
		local team = plr.Team
		if team then
			local getKey = {Alpha = "alpha_cnt", Beta = "beta_cnt"}
			local key = getKey[team.Name]
			plr.Team = nil
			local team_cnt = #team:GetPlayers()
			sql([[update SERVERTABLE set
				%s = %d,
				player_cnt = %d
				where instance_id = '%s']],
				key, team_cnt,
				#plrs:GetPlayers(),
				instance_id
			)
		end
	end
	function quickjoinSystem.updateTeams()
		sql([[update SERVERTABLE set
			alpha_cnt = %d, 
			beta_cnt = %d
			where instance_id = '%s']], 
			#game.Teams.Alpha:GetPlayers(), 
			#game.Teams.Beta:GetPlayers(),
			instance_id
		)
	end
	function quickjoinSystem.insertRow()
		if not db.matchmakingEnabled then return end
		if not rowCreated then
			sql([[insert into SERVERTABLE(
					access_code,
					instance_id,
					player_cnt, alpha_cnt, beta_cnt,
					quickjoin_lock,
					is_vip_room,
					place_id,
					time_created,
					region
				)
					values(
					'%s',
					'%s',
					0, 0, 0,
					timestamp 'infinity',
					'%s',
					%d,
					current_timestamp,
					'%s'
				)]],
				roomInitInfo.access_code or "",
				instance_id,
				roomInitInfo.is_vip_room == nil and "true" or tostring(roomInitInfo.is_vip_room),
				place_id,
				region
			)
			rowCreated = true
		else
			warn("quickjoinSystem: called insertRow twice. aborted")
		end
	end
end

-- check ping
--------------------------------
local pingChecker = {}
do
	local setP = requireGm("PublicVarsServer").setP
	local ur = 5
	local rf = wfc(wfc(rep, "Events"), "PingRf")
	local invokeClient = rf.InvokeClient

	function pingChecker.onPlayerAdded(plr)
		setP(plr, "Ping", -1)
		local plrName = plr.Name

		spawn(function()
			while wait(ur) and ffc(plrs, plrName) do
				ypcall(function()
					local st = tick()
					invokeClient(rf, plr)
					setP(plr, "Ping", tick() - st)
				end)
			end
		end)		
	end
end

-- the prematch scene
-- just the helicopter now
-- remember the prematch is gonna be used only once
-- bc we're using 
----------------------------------
local preMatch = {}
do
	local set = requireGm("PublicVarsServer").set

	function preMatch.start()	-- yield function
		if not db.preMatchEnabled then 
			wait(1)
			return 
		end
		print("preMatch.start started")

		set("Phase", "WaitInHeli")
		repeat 
			print("pre-match waiting for room info")
			wait(1)
		until roomInitInfo

		-- wait for all the players for freshstart / competitive
		-- startserver() should already processed the init players array in roomInitInfo
		local st = tick()
		local maxWaitTime = db.shorterWaitInHeli and 10 or 45
		set("HeliTimer", maxWaitTime)
		while wait(1) do
			local now = tick()
			local T   = now - st
			set("HeliTimer", maxWaitTime + 1 - T)
			if T > maxWaitTime then
				roomInitInfo.initWaitingEnded = true
				break
			end
			if roomInitInfo.expectedJoinedCnt and roomInitInfo.joinedCnt and roomInitInfo.joinedCnt >= roomInitInfo.expectedJoinedCnt then
				print("all init players present. prematch ends.")
				break
			end
			if not db.matchmakingEnabled then
				break
			end
		end
		print("prematch loop ended")

		-- prematch ended
		-- wait(10)
		set("Phase", "OutOfHeli")
		-- 9.2 seconds
		wait(11.5)

		print("preMatch.start ended")
	end
end

-- gamemodes system
-------------------------------
local matchSystem = {}
do
	local resLib    = wfc(rep, "MatchResources")
	local nonHitbox = wfc(workspace, "NonHitbox")

	local invade = {} 
	do
		-- consts
		local sites = {}
		local defusePhaseTL = db.fastInvade and 20 or 40
		local plantPhaseTL  = db.fastInvade and 40 or 2 * 60

		-- shared vars: should implement setter but no getter
		local countdown = {}
		local timeup 
		do
			-- consts
			local internalTick = 0.5
			local announceTick = 1
			local floor = math.floor
			local set = requireGm("PublicVarsServer").set
			-- vars
			local time
			local id = -1
			function countdown.set(_time)
				time   = _time
				id     = id + 1
				timeup = _time == 0 and true or false
			end
			function countdown.run()
				local _id = id
				local st = tick()
				local lastAnnounceTick = -1
				spawn(function()
					while _id == id do
						-- time elapsed
						local dt = wait(internalTick)
						time = time - dt
						if time < 0 then
							time   = 0
							timeup = true
							break
						end
						
						-- annonuce
						local now = tick()
						if now - lastAnnounceTick > announceTick then
							lastAnnounceTick = now
							set("MatchTimer", floor(time))
						end	
					end
				end)
			end
			function countdown.initOnRoundStart()
				countdown.set(plantPhaseTL)
				countdown.run()
			end
		end


		local bombSystem = {}
		local bomb          -- points to the bomb model / part
		local bomber        -- points to the plr
		local planted 			-- not just a boolean, a site INSTANCE instead (not string)
		local defused       -- just a boolaen
		do
			local flareTemp = wfc(resLib, "BombSiteFlare")
			local clone     = game.Clone
			local newCf     = CFrame.new
			local rad       = math.rad
			local newV3     = Vector3.new
			local ocf       = CFrame.fromOrientation
			local defBombOrientation = ocf(0, rad(152), rad(-90))
			local bombHandler, bombSiteHandler
			local bombSpawnLocation  = wfc(workspace, "BombSpawnLocation")

			-- just handles the input from the player and set the game states
			local plantingHandler = {}
			do
				local isAlive = fpsCore.isAlive
				function plantingHandler.initOnMatchStart()
					fpsServer.listen("planted", function(plr, siteName, sitePos, plantedPos)
						if not (plr and siteName and sitePos and plantedPos) then return end

							-- server side verification for planting
						local plrName  = plr.Name
						local verifications = {
							function() return not planted end;
							function() return isAlive[plrName] end;
							function() return bomber == plr end;
							function() return sites[siteName] ~= nil end;
							function() return (sitePos - sites[siteName].Position).magnitude < 0.1 end;
						}
						local pass = true
						for i = 1, #verifications do
							if not verifications[i]() then
								pass = false
								warn("plr", plr, "fails to plant because verification", i, "is not met")
								break
							end
						end
						if pass then					
							bombSiteHandler.plant(sites[siteName], plantedPos, plr)
							-- wip here
						end
					end)

					do -- global planting sound
						local play = requireGm("AudioSystem").play
						local getHrp = fpsCore.getHrp
						local controller = nil
						fpsServer.listen("planting.start", function(plr, site)
							print("planting.start")
							local hrp = getHrp(plr)
							if hrp then
								if controller then 
									controller.destroy() 
								end
								controller = play("BombPlanting", hrp.Position)--site.Position)
								print("planting.start: play server-side sound")
							end
						end)
						fpsServer.listen("planting.cancel", function(plr)
							if controller then 
								controller.destroy() 
								print("planting.cancel: cancel server-side sound")
							end
						end)
					end
				end
			end
			local defusingHandler = {}
			do
				local isAlive = fpsCore.isAlive
				function defusingHandler.initOnMatchStart()
					fpsServer.listen("defused", function(plr, bombPos)
						-- server side verification for defusing
						if not (plr and bomb and bombPos) then return end
						local plrName = plr.Name
						local verifications = {
							function() return planted end;
							function() return isAlive[plrName] end;
							function() return (bombPos - bomb.PrimaryPart.Position).magnitude < 0.1 end;
						}
						local pass = true
						for i = 1, #verifications do
							if verifications[i]() == false then
								pass = false
								warn("plr", plr, "fails to defuse because verification", i, "is not met")
							end
						end
						if pass then
							bombSiteHandler.defuse(plr)
						end
					end)


					do -- global defusing sound
						local play = requireGm("AudioSystem").play
						local getHrp = fpsCore.getHrp
						local controller = nil
						fpsServer.listen("defusing.start", function(plr)
							local hrp = getHrp(plr)
							if hrp then
								if controller then 
									controller.destroy() 
								end
								controller = play("BombDefusing", hrp.Position)
							end
						end)
						fpsServer.listen("defusing.cancel", function(plr)
							if controller then 
								controller.destroy() 
							end
						end)
					end
				end
			end
			local droppingHandler = {}
			do
				local connect = game.Changed.Connect
				function droppingHandler.initOnMatchStart()
					local verify = function(plr)
						if bomber == plr then
							bombHandler.drop(plr)
						end
					end
					connect(fpsCore.onAlive, verify)
					connect(fpsCore.onDead, verify)
					fpsServer.listen("dropBomb", verify)
				end
			end
			local pickingHandler = {}
			do
				function pickingHandler.initOnMatchStart()
					fpsServer.listen("pickupBomb", bombHandler.pickUpBy)
				end
			end

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

			-- handles the actually bomb and  functions.
			-- invoked by player the for input receivers
			--    or round start / phase start / matchstart
			--    or round phases changes such as time ends etc..
			bombHandler = {}
			do
				local destroy = game.Destroy
				-- pv.initPublicVar("bomber", "Instance")

				function bombHandler.pickUpBy(plr)
					if not plr then return end
					bombHandler.despawnBomb()
					bombHandler.setBomber(plr)
				end
				function bombHandler.drop(plr)
					local pos = fpsCore.getCurrOrLastPosition(plr) 
					if pos == nil then
						pos = bombSpawnLocation
						warn("bombHandler.drop by", plr, ". last pos not found, spawning bomb at default bomb spawn location")
					end
					bombHandler.spawnBomb(pos)
				end

				local raycastDown        = raycasting.down
				local spcf               = Instance.new("Model").SetPrimaryPartCFrame
				local defBombOrientation = CFrame.fromOrientation(math.pi / 2, 0, 0)
				local bombTemp           = wfc(resLib, "InvadeBomb")
				local set = requireGm("PublicVarsServer").set

				function bombHandler.spawnBomb(pos)
					local oldBomb = bomb
					if oldBomb then
						warn("spawnBomb: previous bomb not destroyed, destroy it now")
						destroy(oldBomb)
					end

					if pos == "default" then
						pos = bombSpawnLocation
					end
					local newBomb = clone(bombTemp)
					local _, dropPos = raycastDown(pos)

					spcf(newBomb, newCf(dropPos + newV3(0, newBomb.PrimaryPart.Size.Z / 2, 0)) * defBombOrientation)
					newBomb.Parent = nonHitbox

					bombHandler.setBomb(newBomb)
					bombHandler.setBomber(nil)
				end
				function bombHandler.despawnBomb()
					if bomb then
						destroy(bomb)
						bombHandler.setBomb(nil)
					else
						warn("trying to despawn bomb but bomb is nil")
					end
				end

				-- setter for bomb
				function bombHandler.setBomb(_bomb)
					bomb = _bomb
					set("Bomb", bomb)
				end
				-- setter for bomber
				function bombHandler.setBomber(_bomber)
					bomber = _bomber
					set("Bomber", bomber)
				end

				local put = requireGm("AudioSystem").put
				function bombHandler.startBeeping()
					local bc = bomb.BeepContainer

					-- setup audio beep
					local s  = put("BombBeep", bc)
					local function audioBeep()
						s:Play()
					end

					-- setup visual beep
					local p = bc.BeepParticle
					local function visualBeep()
						spawn(function()
							p.Enabled = true
							wait(0.2)
							p.Enabled = false
						end)
					end

					-- setup faster beep
					local function fasterBeep(times)
						print("beep: times = ", times)
						spawn(function()
							for i = 1, times, 1 do
								audioBeep()
								visualBeep()
								wait(1 / times)
							end
						end)
					end

					-- start beeping!
					spawn(function()
						local max = math.max
						local ceil = math.ceil
						for i = 1, defusePhaseTL do
							if bomb and bomb.Parent and bomb.Parent.Parent then
								if i < defusePhaseTL - 5 then
									audioBeep()
									visualBeep()
								else
									fasterBeep(max(1, ceil(8 - defusePhaseTL + i)))
								end
							else
								break
							end
							wait(1)
						end
					end)
				end

				do -- set up kaboom
					local debris = game:GetService("Debris")
					local addToDebris = debris.AddItem
					local play = requireGm("AudioSystem").play
					local getC = game.GetChildren
					function bombHandler.kaboom()
						play("BombDetonated", bomb.PrimaryPart.Position)

						-- clone the particle holder and set auto destroy
						local particleHolder = clone(bomb.MeshPart)
						particleHolder.Parent = nonHitbox
						addToDebris(debris, particleHolder, 20)

						-- enable all detonation particle effects
						for _, v in ipairs(getC(particleHolder)) do
							v.Enabled = true
						end
						delay(3, function()
							for _, v in ipairs(getC(particleHolder)) do
								v.Enabled = false
							end
						end)

						-- finally despawn the bomb
						bombHandler.despawnBomb()
					end
				end
			end

			bombSiteHandler = {}
			do
				-- bombSiteHandler.initPublicVar("planted", "Instance")
				local play = requireGm("AudioSystem").play
				local getC = game.GetChildren
				local set = requireGm("PublicVarsServer").set
				function bombSiteHandler.defuse(plr)
					-- bombHandler.stopBeeping()
					bombHandler.despawnBomb()
					bombSiteHandler.setDefused(true)
					play("BombDefused", "2D")
					-- bombSiteHandler.setPlanted(nil)
					statsTracker.incScore(plr, "scorePerDefuse", "defuse")
				end
				function bombSiteHandler.plant(site, pos, plr)
					bombSiteHandler.setPlanted(site)
					bombHandler.spawnBomb(pos)
					bombHandler.startBeeping()
					play("BombPlanted", "2D")
					statsTracker.incScore(plr, "scorePerPlant", "plant")
				end
				function bombSiteHandler.initOnMatchStart()
					-- configure sites
					local spcf = Instance.new("Model").SetPrimaryPartCFrame
					for _, site in ipairs(getC(wfc(workspace, "Bombsites"))) do
						local siteName    = site.Name
						sites[siteName]   = site
						print("loaded site", siteName)
						site.Transparency = 1

						-- put flare in sites
						local flare = clone(flareTemp)
						local cf = flare.PrimaryPart.CFrame
						local _, dropPos = raycasting.down(site.CFrame.p)
						spcf(flare, cf - cf.p + dropPos + newV3(0, 0.066, 0))
						flare.Parent = site
					end
					printTable(sites)
				end

				-- setters
				function bombSiteHandler.setPlanted(_planted)
					planted = _planted
					set("Planted", planted)
				end
				function bombSiteHandler.setDefused(_defused)
					defused = _defused
					set("Defused", defused)
				end
			end

			function bombSystem.initOnRoundStart()
				bombSiteHandler.setPlanted(nil)
				bombSiteHandler.setDefused(false)
				bombHandler.spawnBomb("default")
				bombHandler.setBomber(nil)
			end

			function bombSystem.initOnMatchStart()
				bombSiteHandler.initOnMatchStart()
				plantingHandler.initOnMatchStart()
				defusingHandler.initOnMatchStart()
				droppingHandler.initOnMatchStart()
				pickingHandler.initOnMatchStart()
			end

			function bombSystem.detonate()
				bombHandler.kaboom()
				fpsCore.killAll("kaboom")
			end
		end

		local atk
		local def
		-- local atkOnly	-- changed to functions
		-- local defOnly
		local teamSystem = {}
		invade.teamSystem = teamSystem
		do
			local teams = game.Teams
			local getP  = teams.Alpha.GetPlayers
			local getC = game.GetChildren
			local isAlive = fpsCore.isAlive
			local set = requireGm("PublicVarsServer").set
			local spawnable = fpsCore.spawnable
			local spawnLocations = {
				atk = getC(wfc(wfc(workspace, "Spawns"), "Atk")),
				def = getC(wfc(wfc(workspace, "Spawns"), "Def")),
			}
			do-- remove all spawnlocations's decal and hide the brick
				local ffcWia = game.FindFirstChildWhichIsA
				for _, side in ipairs({"atk", "def"}) do
					for _, spawn in ipairs(spawnLocations[side]) do
						local decal = ffcWia(spawn, "Decal") 
						if decal then
							decal:Destroy()
						end
						spawn.Transparency = 1
					end
				end
			end
			local ranint = math.random
			function teamSystem.getSideAliveCnt(side)
				local team = typeof(side) == "string" and teamSystem.getTeam(side) or side
				local cnt = 0
				for _, p in ipairs(getP(team)) do
					if isAlive[p.Name] then
						cnt = cnt +1
					end
				end
				return cnt
			end
			local getSideAliveCnt = teamSystem.getSideAliveCnt
			function teamSystem.getSideAliveCnts()
				return getSideAliveCnt(atk), getSideAliveCnt(def)
			end
			function teamSystem.isAtkOnly()
				local atkLives = getSideAliveCnt(atk)
				local defLives = getSideAliveCnt(def)
				return atkLives > 0 and defLives == 0
			end
			function teamSystem.isDefOnly()
				local atkLives = getSideAliveCnt(atk)
				local defLives = getSideAliveCnt(def)
				return atkLives == 0 and defLives > 0
			end
			function teamSystem.isAtkDefOnly()
				local atkLives = getSideAliveCnt(atk)
				local defLives = getSideAliveCnt(def)
				local atkOnly = atkLives > 0 and defLives == 0
				local defOnly = atkLives == 0 and defLives > 0
				return atkOnly, defOnly
			end
			function teamSystem.getTeam(side)
				if side == "atk" then
					return atk
				elseif side == "def" then
					return def
				else
					error("teamSystem.getTeam invalid side "..side)
				end
			end
			function teamSystem.getSide(team)
				if atk == team then
					return "atk"
				elseif def == team then
					return "def"
				else
					warn("teamSystem.getSide", team, "is nil. atk =", atk, " def =", def)
				end
			end
			function teamSystem.switchSide()
				if not atk or not def then 		-- first round
					atk = teams.Alpha
					def = teams.Beta
				else
					local tmp = atk
					atk = def
					def = tmp
				end
				-- annonuce it
				set("Atk", atk)
				set("Def", def)
			end
			function teamSystem.getRandomSpawnLocation(side)
				if typeof(side) == "Instance" then
					side = teamSystem.getSide(side)
				end
				local t = spawnLocations[side]
				return t[ranint(1, #t)]
			end
			function teamSystem.spawnAllAsync()
				print("spawnall")
				for _, plr in ipairs(getC(plrs)) do
					print("got plr", plr)
					if spawnable[plr.Name] then
						spawn(function()
							fpsCore.spawn(plr, {
								spawnLocation = teamSystem.getRandomSpawnLocation(plr.Team),
								side = teamSystem.getSide(plr.Team)
							})
						end)
					else
						print("not spawnable")
					end
				end
				wait(1.5)
			end
			function teamSystem.initOnRoundStart()
				teamSystem.attemptToShuffleTeam()
				teamSystem.switchSide()
				teamSystem.spawnAllAsync()
			end
			-- function teamSystem.initOnMatchStart()
			-- 	-- load the spawn locations

			-- end
			do-- team shuffling
				local parties = partySystem.parties
				--@pre: the parties = {plrName -> dictionary of members}
				-- i.e. there's no party.members and party.membercnt
				-- party.members should be devalue-ed when transferred from lobby
				-- party members should be contained in the player's joinData
				-- known issue: if plr1 is in plr2's party and then plr1 leaves and joins back
				--    plr2's party will still contain plr1 but plr1's party wont contain plr2
				local function getParties()
					local ret = {}
					local visited = {}
					for _, plr in ipairs(plrs:GetPlayers()) do
						local plrName = plr.Name
						local party = parties[plrName]
						if party then
							if not visited[plrName] then
								print("getParties: add", plrName, "'s party")
								local p = {memberCnt = 0, members = {}}
								for memberName, _ in pairs(party) do
									local member = ffc(plrs, memberName)
									if member then
										visited[memberName] = true
										p.memberCnt = p.memberCnt + 1
										p.members[memberName] = member
										print(memberName)
									end
								end
								ret[#ret + 1] = p
							end
						else
							warn("room: try shuffling teams but", plr, "'s party is not found")
						end
					end
					return ret
				end

				function teamSystem.balance(ps)
					table.sort(ps, function(p1, p2) return p1.memberCnt > p2.memberCnt end)
					local alpha = {playerCnt = 0, players = {}}
					local beta  = {playerCnt = 0, players = {}}

					for _, p in ipairs(ps) do
						if alpha.playerCnt < beta.playerCnt then
							alpha.playerCnt = alpha.playerCnt + p.memberCnt
							for _, plr in pairs(p.members) do
								alpha.players[plr.Name] = plr
							end
						else
							beta.playerCnt = beta.playerCnt + p.memberCnt
							for _, plr in pairs(p.members) do
								beta.players[plr.Name] = plr
							end
						end
					end

					return alpha, beta
				end
				local balance = teamSystem.balance

				local abs = math.abs
				local maxIm = db.maxPlayerImbalance
				function teamSystem.attemptToShuffleTeam()
					if not db.teamAutoShuffleAfterRound then return end
					local im = abs(#teams.Alpha:GetPlayers() - #teams.Beta:GetPlayers())
					if not maxIm or im <= maxIm then return end
					local newAlpha, newBeta = balance(getParties())
					local function getNewTeam(plr)
						if newAlpha.players[plr.Name] then return teams.Alpha
						elseif newBeta.players[plr.Name] then return teams.Beta
						else
							warn("getNewTeam returns nil for", plr)
						end
					end
					if abs(newAlpha.playerCnt - newBeta.playerCnt) < im then
						for _, plr in ipairs(plrs:GetPlayers()) do
							-- ignore thos who just join and have no team
							if plr.Team then
								local newTeam = getNewTeam(plr)
								if plr.Team ~= newTeam then
									plr.Team = newTeam
								end
							end
						end
						quickjoinSystem.updateTeams()
					end
				end
			end
		end

		local set = requireGm("PublicVarsServer").set
		function invade.runMatch()		-- return the matchwinner (a team) and the teamname

			-- init on matchstart here
			local bo = 11
			if db.oneRoundOnly then
				bo = 1
			end
			if db.twoRoundsOnly then
				bo = 3
			end
			local maxWins   = (bo + 1) / 2
			local currRound = 0
			local matchWinner, matchWinnerName = nil, nil
			local teamWins = {
				Alpha = 0,
				Beta = 0,
			}
			bombSystem.initOnMatchStart()
			print("match start initiated")

			-- start the round loop
			while matchWinner == nil do
				local roundWinner, roundWinnerName = invade.runRound()
				teamWins[roundWinnerName] = teamWins[roundWinnerName] + 1
				set("AlphaWins", teamWins.Alpha)
				set("BetaWins", teamWins.Beta)

				-- end match if matchpoint is catched
				if teamWins[roundWinnerName] >= maxWins and not db.infiniteRounds then
					matchWinner = roundWinner
					matchWinnerName = roundWinnerName
				end

				if not db.infiniteRounds then-- end match if one team is gone
					local alpha = game.Teams.Alpha
					local beta  = game.Teams.Beta
					local alphaCnt = #alpha:GetPlayers()
					local betaCnt  = #beta:GetPlayers()
					if alphaCnt == 0 and betaCnt > 0 then
						matchWinner = beta
						matchWinnerName = beta.Name
					elseif alphaCnt > 0 and betaCnt == 0 then
						matchWinner = alpha
						matchWinnerName = alpha.Name
					end
				end

				-- round win score stats
				for _, plr in ipairs(roundWinner:GetPlayers()) do
					statsTracker.incScore(plr, "scorePerRoundVictory", "round.win")
				end

				-- match point -> disable quickjoin
				if teamWins[roundWinnerName] == maxWins - 1 then
					quickjoinSystem.removeRow()
				end

				-- post round
				mainframeServer.fireAllClients("round end", roundWinner, matchWinner)
				set("Phase", "Match:Intermission")
				if matchWinner then
					wait(13) 	-- time measured in the client side.
				else
					wait(16)
				end
			end

			for _, plr in ipairs(matchWinner:GetPlayers()) do
				statsTracker.incScore(plr, "scorePerMatchVictory", "match.win")
			end

			return matchWinner, matchWinnerName
		end

		local roundId = 0
		local forceRoundEnd = {}
		function invade.forceRoundEnd(rw) 		-- for debug
			forceRoundEnd = {
				rw = rw,
				id = roundId,
			}
		end

		-- equivalent as run planting phase
		local internalTick = 1
		local stringify = requireGm("TableUtils").stringifyTableOneLine
		local isAtkDefOnly = teamSystem.isAtkDefOnly
		function invade.runRound()		-- returns the roundwinner
			local roundWinner

			-- init on round start
			bombSystem.initOnRoundStart()
			teamSystem.initOnRoundStart()
			countdown.initOnRoundStart()
			roundId = roundId + 1
			set("RoundId", roundId)
			print("round start")

			set("Phase", "Match:Plant")

			while roundWinner == nil do
				if forceRoundEnd.id == roundId then
					return forceRoundEnd.rw, forceRoundEnd.rw.Name
				end

				local atkOnly, defOnly = isAtkDefOnly()
				if db.roundDontEnd then
					atkOnly, defOnly = false, false
				end

				-- warn("plantingPhase:", planted, atkOnly, defOnly, timeup, roundWinner, atk, def, atk and stringify(atk:GetPlayers()), def and stringify(def:GetPlayers()))

				if planted then
					roundWinner = invade.runDefusingPhase()
				else
					if atkOnly then
						roundWinner = atk
					elseif defOnly then
						roundWinner = def
					else
						roundWinner = timeup and def or nil
					end
				end
				wait(internalTick)
			end
			print("round end roundwinner = ", roundWinner)

			return roundWinner, roundWinner.Name
		end
		function invade.runDefusingPhase()
			local roundWinner = nil

			set("Phase", "Match:Defuse")
			countdown.set(defusePhaseTL)
			countdown.run()

			while roundWinner == nil do
				if forceRoundEnd.id == roundId then
					return forceRoundEnd.rw
				end

				local atkOnly, defOnly = isAtkDefOnly()
				if db.roundDontEnd then
					atkOnly, defOnly = false, false
				end

				-- warn("plantingPhase:", defused, atkOnly, defOnly, timeup, roundWinner, atk, def, atk and stringify(atk:GetPlayers()), def and stringify(def:GetPlayers()))

				if timeup then
					if defused then
						roundWinner = def
					else
						roundWinner = atk
						bombSystem.detonate()
						set("Phase", "Match:Boom")
					end
				else
					if defused then
						roundWinner = def
					else
						if atkOnly then
							roundWinner = atk
						else
							roundWinner = nil
						end
					end
				end
				wait(internalTick)
			end

			return roundWinner, roundWinner.Name
		end
	end
	matchSystem.invade = invade

	function matchSystem.start()
		if db.testingCharacters then -- thread wont end. infinite loop
			print("matchSystem.testingCharacters")
			requireGm("PublicVarsServer").set("Phase", "Match:TC")

			local getC           = game.GetChildren
			local spawnLocation  = getC(getC(workspace.Spawns)[1])[1]
			local scheduled      = {}
			local hasEverSpawned = {}
			local spawnable      = fpsCore.spawnable
			local isAlive        = fpsCore.isAlive
			local spawn          = fpsCore.spawn
			while wait(2) do
				for _, plr in ipairs(getC(plrs)) do
					plr.Team = game.Teams[math.random(0, 1) == 1 and "Alpha" or "Beta"]

					local plrName = plr.Name
					if spawnable[plrName] and not isAlive[plrName] then

						if not hasEverSpawned[plrName] then
							spawn(plr, {spawnLocation = spawnLocation})
							hasEverSpawned[plrName] = true

						elseif not scheduled[plrName] then
							scheduled[plrName] = true

							print("testingCharacters: schedule to spawn", plr, "10 seconds later")
							delay(10, function()
								spawn(plr, {spawnLocation = spawnLocation})
								scheduled[plrName] = false
							end)
						end
					end
				end
			end
		end

		if db.matchEnabled then
			print("matchSystem.start")
			quickjoinSystem.unlockQuickjoin()

			local mw = invade.runMatch()
			print("matchWinner is", mw)

			datastore.uploadAllAsync({penalty = false})
			quickjoinSystem.removeRow()
			return mw
		end
	end
end

-- show time (aka final screen)
-------------------------------------
local showtime = {}
do
	local order = {}
	local showtimeSpawns = {}
	do -- setup showtimeSpawns
		local ffcWia = game.FindFirstChildWhichIsA
		for _, spawn in ipairs(wfc(wfc(workspace, "Showtime"), "Spawns"):GetChildren()) do
			showtimeSpawns[tonumber(spawn.Name)] = spawn
			local decal = ffcWia(spawn, "Decal")
			if decal then
				decal:Destroy()
			end
		end
	end
	
	local set = requireGm("PublicVarsServer").set
	function showtime.start(mw)
		if not db.showtimeEnabled then return end
		print("showtime.start")

		-- kill all player
		fpsCore.killAll("readyToDance")

		if mw == nil then
			warn("showtime: mw = nil, consider all the players instead")
			mw = plrs
		end
		set("Phase", "Showtime")

		local dancers = {}
		do -- configure dancer's order
		   -- sort the players according to score. 	-- should be reversed, i.e. low to hi
			local stats = statsTracker.stats
			local order = {} 
			for _, plr in ipairs(mw:GetPlayers()) do
				if stats[plr.Name] and stats[plr.Name].score then
					order[#order + 1] = plr
				end
			end
			table.sort(order, function(plr1, plr2)
				return stats[plr1.Name].score > stats[plr2.Name].score
			end)
			local side = math.random(1, 2) == 1 and "atk" or "def"
			local spawnable = fpsCore.spawnable
			local loadout1s = datastore.loadout1s
			for i = 1, 10 do
				local plr = order[i]
				if plr and spawnable[plr.Name] then
					local plrName = plr.Name
					dancers[i] = {
						plrName = plrName,
						-- plr = plr,
						dance = loadout1s[plrName].dance,
						stats = stats[plrName],	-- pass down the entire stats table
						spawnLocation = showtimeSpawns[i],
						side = side
					}
				end
			end
		end

		-- start showtime
		mainframeServer.fireAllClients("showtime.start", dancers, 
			mw:IsA("Team") and mw or nil)
		wait(15)
		mainframeServer.fireAllClients("showtime.end")
	end
end

-- final voting
-----------------------------------

local voting = {}
do
	local connect         = game.Changed.Connect
	local votingPhaseTL   = db.fasterMatchMaking and 5 or 15
	local startingPhaseTL = db.fasterMatchMaking and 5 or 10
	local clockrate       = 1
	local pv              = requireGm("PublicVarsServer")
	function voting.start()
		if not db.votingEnabled then return end
		pv.set("Phase", "Voting")

		local self = {
			phase = "voting",
			timer = -1,
			players = {},
			playerCnt = 0,
			teams = {
				alpha = {
					players = {},
					playerCnt = 0,
					rbxTeam = game.Teams.Alpha,
				},
				beta = {
					players = {},
					playerCnt = 0,
					rbxTeam = game.Teams.Beta
				},
			},
			plrVotes = {}, 	-- an index
			options = {		-- not randomly genrated
				[1] = {
					mapName = "Office",
					vote = 0,
				},
				[2] = {
					mapName = "Metro",
					vote = 0,
				},
				[3] = {
					mapName = "Yacht",
					vote = 0,
				},
				[4] = {
					mapName = "Resort",
					vote = 0,
				}
			},
		}
		local players  = self.players
		local teams    = self.teams
		local plrVotes = self.plrVotes
		local options  = self.options
		
		-- add ppl to team
		for teamName, team in pairs(teams) do
			warn(1)
			for _, plr in pairs(team.rbxTeam:GetPlayers()) do
				warn(2, plr)
				local plrName = plr.Name
				players[plrName] = plr
				self.playerCnt = self.playerCnt + 1
				team.players[plrName] = plr
				team.playerCnt = team.playerCnt + 1
			end
		end

		mainframeServer.fireAllClients("voting.start", self)

		local function restorePlrVote(plr)
			local oldIdx = plrVotes[plr.Name]
			if oldIdx then
				options[oldIdx].vote = options[oldIdx].vote - 1
			end
			plrVotes[plr.Name] = nil
		end
		function self.receivePlrVote(plr, idx)
			if not (plr and idx) then return end
			restorePlrVote(plr)
			options[idx].vote = options[idx].vote + 1
			plrVotes[plr.Name] = idx
			mainframeServer.fireClients(players, "voting.votes", options)
		end
		mainframeServer.listen("voting.vote", self.receivePlrVote)

		function self.leaveRoom(plr)
			local plrName = plr.Name
			if players[plrName] ~= plr then
				warn("_leaveRoom: plr", plr, "tries to leave room but is not in the room. aborted")
				return
			end
			players[plrName] = nil
			self.playerCnt   = self.playerCnt - 1

			local plrTeamName = nil
			for teamName, team in pairs(teams) do
				if team.players[plrName] then
					plrTeamName = teamName
					break
				end
			end
			if not plrTeamName then
				warn("_leaveRoom: plr", plr, "tries to leave room but is not in any team. aborted")
			end
			local plrTeam = teams[plrTeamName]
			plrTeam.playerCnt = plrTeam.playerCnt - 1

			restorePlrVote(plr)
			mainframeServer.fireClient(plr, "voting.cancel")
			mainframeServer.fireClients(players, "voting.votes", options)
			mainframeServer.fireClients(players, "voting.teams", teams)
		end

		do-- auto shuffle
			local abs = math.abs
			local parties = partySystem.parties
			local function getParties()
				local ret = {}
				local visited = {}
				for plrName, plr in pairs(players) do
					local party = parties[plrName]
					if party then
						if not visited[plrName] then
							print("getParties: add", plrName, "'s party")
							local p = {memberCnt = 0, members = {}}
							for memberName, _ in pairs(party) do
								local member = ffc(plrs, memberName)
								if member then
									visited[memberName] = true
									p.memberCnt = p.memberCnt + 1
									p.members[memberName] = member
									print(memberName)
								end
							end
							ret[#ret + 1] = p						
						end
					else
						warn("room: try shuffling teams but", plr, "'s party is not found")
					end
				end
				return ret
			end

			-- @param: ps: parties
			-- a heuristic greedy algorithm O(n log n)
			local function balance(ps)
				table.sort(ps, function(p1, p2) return p1.memberCnt > p2.memberCnt end)
				local alpha = {playerCnt = 0, players = {}}
				local beta  = {playerCnt = 0, players = {}}

				for _, p in ipairs(ps) do
					if alpha.playerCnt < beta.playerCnt then
						alpha.playerCnt = alpha.playerCnt + p.memberCnt
						for _, plr in pairs(p.members) do
							alpha.players[plr.Name] = plr
						end
					else
						beta.playerCnt = beta.playerCnt + p.memberCnt
						for _, plr in pairs(p.members) do
							beta.players[plr.Name] = plr
						end
					end
				end

				return alpha, beta
			end

			function self.attemptToShuffleTeam()
				if not db.teamAutoShuffleInVoting then return end
				local im = abs(teams.alpha.playerCnt - teams.beta.playerCnt)
				if im <= db.maxPlayerImbalance then return end

				-- @pre: party members must all be present in a room
				local newAlpha, newBeta = balance(getParties())

				if abs(newAlpha.playerCnt - newBeta.playerCnt) < im then
					teams.alpha = newAlpha
					teams.beta  = newBeta
					print("team shuffled")
					return true
				end
			end
		end
		connect(plrs.PlayerRemoving, function(plr)
			if not plr then return end
			self.leaveRoom(plr)
			if self.phase == "voting" then
				if self.attemptToShuffleTeam() then
					mainframeServer.fireClients(players, "voting.teams", teams)
				end
			end
		end)

		do-- set up phases
			local phases = {
				voting = {},
				starting = {},
			}
			local function changePhase(phase)
				self.phase = phase
				phases[phase].start()
			end

			do--voting
				function phases.voting.start()
					if self.attemptToShuffleTeam() then
						mainframeServer.fireClients(players, "voting.teams", teams)
					end
					self.timer = votingPhaseTL
					mainframeServer.fireClients(players, "voting.phase", self)
				end
				function phases.voting.step(dt)
					if self.playerCnt < 1 or
						(not db.votingDontEnd and 
							(teams.alpha.playerCnt < 1 or teams.beta.playerCnt < 1)) then
						return "ended"
					end
					self.timer = self.timer - dt
					if self.timer < 0 then
						self.timer = 0
					end
					if self.timer == 0 then
						changePhase("starting")
					else
						mainframeServer.fireClients(players, "voting.timer", self.phase, self.timer)
					end
				end
			end

			do-- starting
				local function getMostPopularOption()		-- returns an index and the option
					local a = {}
					local highestVote
					for i = 1, #options do
						local option = options[i]
						local vote = option.vote
						if not highestVote then
							a[#a + 1] = i
							highestVote = vote
						elseif vote == highestVote then
							a[#a + 1] = i
						elseif vote > highestVote then
							a = {i}
							highestVote = vote
						end
					end
					local idx = math.random(1, #a)
					return a[idx], options[a[idx]]
				end
				local placeIds = db.placeIds
				local function getTemplatePlaceId(option)
					return placeIds[option.mapName]
				end
				local devalue = requireGm("TableUtils").devalue
				local dekey   = requireGm("TableUtils").dekey
				local ts            = game:GetService("TeleportService")
				local reserveServer = ts.ReserveServer
				local groupTeleport = ts.TeleportToPrivateServer
				function phases.starting.start()
					self.timer = startingPhaseTL
					local mpIdx, mpOption = getMostPopularOption()
					self.mpIdx = mpIdx
					mainframeServer.fireClients(players, "voting.phase", self)

					-- create server
					local templatePlaceId = getTemplatePlaceId(mpOption)
					local roomInitInfo2 = {
						Alpha = devalue(teams.alpha.players),
						Beta  = devalue(teams.beta.players),
						access_code = reserveServer(ts, templatePlaceId),
						is_vip_room = roomInitInfo.is_vip_room,
						lobbyPlaceId = roomInitInfo.lobbyPlaceId,
						lobbyInstanceId = roomInitInfo.lobbyInstanceId,
					}
					local joinData = {
						roomInitInfo = roomInitInfo2,
						joinMethod = "freshstart",
						parties = partySystem.parties,
					}
					spawn(function()
						groupTeleport(ts, templatePlaceId, roomInitInfo2.access_code, dekey(players), "", joinData)
					end)
				end
				function phases.starting.step(dt)
					if self.playerCnt <= 0 then
						warn("room: no players. end room thread.")
						return "ended"
					end
					self.timer = self.timer - dt
					mainframeServer.fireClients(players, "voting.timer", self.phase, self.timer)
					if self.timer < 0 then
						return "ended"
					end
				end
			end

			phases.voting.start()
			spawn(function()
				local lastTick = tick()
				while wait(clockrate) do
					local now = tick()
					local dt = now - lastTick
					local ended = phases[self.phase].step(dt)
					if ended then
						break
					end
					lastTick = now
				end
				print("room thread ends. doing nothing")
			end)
		end

		do-- set up teleporing back
			local ts            = game:GetService("TeleportService")
			-- local reserveServer = ts.ReserveServer
			local toInstance = ts.TeleportToPlaceInstance
			local toPlace = ts.Teleport
			mainframeServer.listen("voting.backToLobby", function(plr)
				if not plr then return end
				self.leaveRoom(plr)
				if roomInitInfo.is_vip_room then
					toInstance(ts, roomInitInfo.lobbyPlaceId, roomInitInfo.lobbyInstanceId, plr)
				else
					toPlace(ts, roomInitInfo.lobbyPlaceId, plr)
				end
			end)
		end
	end
end


-- handles player added and player removing
-- grabs data from data teleported here
---------------------------------------
local main = {}
do
	-- this will run only after room init info is set
	function main.prepareMainframe(_roomInitInfo)
		roomInitInfo = _roomInitInfo

		-- insert row into sql and init the helicopter waiting
		if db.matchmakingEnabled then
			assert(typeof(roomInitInfo.Alpha) == "table" and typeof(roomInitInfo.Beta) == "table")

			-- count how many players should join during the waiting phase
			roomInitInfo.joined    = {}
			roomInitInfo.expectedJoinedCnt = 0
			roomInitInfo.joinedCnt = 0
			for _, teamName in ipairs({"Alpha", "Beta"}) do
				for plrName, _ in pairs(roomInitInfo[teamName]) do
					roomInitInfo.joined[plrName] = false
					roomInitInfo.expectedJoinedCnt = roomInitInfo.expectedJoinedCnt + 1
				end
			end
			print("startserver: expectedJoinedCnt =", roomInitInfo.expectedJoinedCnt)

			quickjoinSystem.insertRow()
		end

		-- assign teams based on roomInitInfo
		-- done in playeradded
	end

	-- may yield
	function main.mainframe(_roomInitInfo)
	
		-- helicopter
		preMatch.start()

		if db.extraWaitingBeforeMatch then
			wait(5)
			print("extraWaitingBeforeMatch")
		end

		local mw = matchSystem.start()
		showtime.start(mw)
		voting.start()
	end

	-- when the game closes
	game:BindToClose(function()
		-- datastore.uploadAll(false)
		quickjoinSystem.removeRow()
	end)

	local clientLoaded = {}
	-- set to true when receiving the signal from client
	-- set to nil when player quits the game
	do -- clientLoaded (our custom playerAdded with roominitInfo)
		local kick      = require(game.ServerStorage.KickSystem).kick
		local teams     = game.Teams
		local alpha     = teams.Alpha
		local beta      = teams.Beta
		local getC      = game.GetChildren
		local spawnable = fpsCore.spawnable

		local joinHandlers = {
			debug = function(plr, joinData)
				-- everybody can join
				plr.Team = #teams.Alpha:GetPlayers() <= #teams.Beta:GetPlayers() and teams.Alpha or teams.Beta
			end;
			quickjoin = function(plr, joinData)
				if roomInitInfo == nil then
					kick(plr, "trying to quick join a server with no room data")
					return "error"
				end

				-- assign team
				-- print("quickjoin joinData:", joinData.teamName)
				-- printTable(joinData)
				plr.Team = teams[joinData.teamName]

				-- team must be non nil
				if not plr.Team then
					kick(plr, "not in any team. joinMethod = quickjoin")
					return "error"
				end
			end;
			freshstart = function(plr, joinData)
				if roomInitInfo.initWaitingEnded then
					kick(plr, "joining server timed out. initWaitingEnded")
					return "error"
				end
				local plrName = plr.Name

				-- assign teams
				if db.matchmakingEnabled then
					for _, team in ipairs(getC(teams)) do
						if roomInitInfo[team.Name][plrName] then
							plr.Team = team
							break
						end
					end
				else
					plr.Team = #alpha:GetPlayers() > #beta:GetPlayers() and beta or alpha
				end

				-- team must be non nil
				if not plr.Team then
					kick(plr, "not in any team. joinMethod = freshstart")
					return "error"
				end
			end;
			competitive = function(plr, joinData)
			end;
		}

		fpsServer.listen("clientLoaded", function(plr, joinData)
			if not (plr and joinData) then return end

			if clientLoaded[plr.Name] then
				kick(plr, "sent clientLoaded signal twice")
				return
			end
			
			-- print(plr, "clientLoaded with joinData")
			-- printTable(joinData)

			-- load the game init info and run mainframe
			if roomInitInfo == nil and joinData.roomInitInfo then
				main.prepareMainframe(joinData.roomInitInfo)
				spawn(main.mainframe)
			end

			do-- process join method
				local joinMethod = joinData.joinMethod
				local joinHandler 
				if joinMethod then
					joinHandler = joinHandlers[joinMethod]
				end
				if joinHandler then
					-- assign team for qj players or sth
					if joinHandler(plr, joinData) == "error" then -- returns "error" when error occurs
						return
					end
				else
					kick(plr, "invalid joinMethod "..joinMethod)
				end
			end

			-- mark client loaded to true
			partySystem.onPlayerAdded(plr, joinData)
			clientLoaded[plr.Name] = true

			do-- count player
				if roomInitInfo.joinedCnt == nil then
					roomInitInfo.joinedCnt = 0
				end	
				roomInitInfo.joinedCnt = roomInitInfo.joinedCnt + 1
				print("joinedCnt++, is now", roomInitInfo.joinedCnt)
			end

			-- assign teams

			-- onPlayerAdded
			quickjoinSystem.onPlayerAdded(plr)
			fpsCore.onPlayerAdded(plr)
			datastore.onPlayerAdded(plr)
			statsTracker.onPlayerAdded(plr)
			pingChecker.onPlayerAdded(plr)
			fpsCore.spawnable[plr.Name] = true
			print("set spawnable = true for", plr)
		end)
	end

	-- player out
	plrs.PlayerRemoving:Connect(function(leaver)
		if not leaver then return end
		local leaverName = leaver.Name
		clientLoaded[leaverName] = nil

		quickjoinSystem.onPlayerRemoving(leaver)
		fpsCore.onPlayerRemoving(leaver)
		datastore.onPlayerRemoving(leaver)
		statsTracker.onPlayerRemoving(leaver)
		partySystem.onPlayerRemoving(leaver)
	end)
end

-- admin server-side command-line system
---------------------------------------
do
	local ss = game.ServerStorage
	local debugBf = wfc(ss, "ServerDebugServer")
	local debugRf = wfc(rep, "LocalDebugServer")
	local ffc     = game.FindFirstChild
	local pms     = require(wfc(ss, "Permissions"))

	local cmdHandler = {
		kill = function(plr, ...)
			if type(plr) == "string" then
				plr = ffc(plrs, plr)
			end
			if plr and plr.Character then
				--victim, killMethod, 
				fpsCore.kill(plr, "debug")
			else
				warn(string.format("plr is not in this server or char not found", plr))
			end
		end;
		forceRoundEnd = function(rw)
			if not rw then
				warn("force round end but not specifying a round winner. set rw to alpha")
				rw = game.Teams.Alpha
			end 
			matchSystem.invade.forceRoundEnd(rw)
		end;
		advanceLighting = function()
		  game.ReplicatedStorage.SharedVars.RoundId.Value = game.ReplicatedStorage.SharedVars.RoundId.Value + 1
		end;
	}
	local cmdLvl = {
		kill = 1,
		forceRoundEnd = 1,
		advanceLighting = 1,
	}
	local function onInvoke(cmd, ...)
		if cmd == nil then
			warn("cmd is nil")
			return
		end
		local handler = cmdHandler[cmd]
		if handler then
			handler(...)
		else
			warn(cmd, "isn't setup yet. try the following")
			for cmd, _ in pairs(cmdHandler) do
				warn("\t"..cmd)
			end
		end
	end
	debugBf.OnInvoke = onInvoke
	debugRf.OnServerInvoke = function(cmder, cmd, ...)
		if not (cmd and cmder) then
			warn("cmd or cmder is nil", cmd, cmder)
			return
		end
		if not cmdLvl[cmd] then
			warn("pmsLvl for cmd", cmd, "not found")
			return
		end
		if pms.hasPermission(cmder, cmdLvl[cmd]) then
			onInvoke(cmd, ...)
		else
			warn("permission denied")
		end
	end
end