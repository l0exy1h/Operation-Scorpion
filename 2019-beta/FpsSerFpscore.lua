local settings = {
	healthRegenSpeed = 2, 	-- health regen on
}

-- consts
------------------------------------------------
local plrs      = game.Players
local rep       = game.ReplicatedStorage
local ss        = game.ServerStorage
local wfc       = game.WaitForChild
local ffc       = game.FindFirstChild

local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local debugSettings = requireGm("DebugSettings")
local tableUtils = requireGm("TableUtils")
local networkRep = requireGm("ReplicationServer")
local debugSettings = requireGm("DebugSettings")()
local network    = requireGm("Network")
local events    = wfc(rep, "Events")
local fpsServer = network.loadRe(wfc(events, "Fps"), true)
local repServer = networkRep.loadReRf(wfc(events, "RepRe"), wfc(events, "RepRf"))
local connect   = game.Changed.Connect

-- vars for quick join
-------------------------
local roomInitInfo = nil

-- vars for each player
-- maybe turn this into a metatable?
-----------------------------------------------
local clientLoaded = {}
-- set to true when receiving the signal from client
-- set to nil when player quits the game

-- true iff every info is obtained for that plr to be spawned
-- by the MATCHSYSTEM
local clientSpawnable = {}

local weaponSlots  = {}
local alive        = {}
local health       = {}

-- public data on plr.Vars
-------------------------------------------
local publicVars = {}
do
	local sv = wfc(rep, "SharedVars")
	local keyToClass = {
		number     = "NumberValue",
		Color3     = "Color3Value",
		CFrame     = "CFrameValue",
		Vector3    = "Vector3Value",
		string     = "StringValue",
		BrickColor = "BrickColorValue",
		Ray        = "RayValue",
		boolean    = "BooleanValue",
		Instance   = "ObjectValue",
	}
	function publicVars.setPublicPlrVar(plr, key, value)
		print("server: setPublicPlrVar", plr, key, value)
		local vars = ffc(plr, "Vars")
		if vars == nil then
			print("Vars not found in", plr, "creating one")
			vars        = Instance.new("Folder")
			vars.Name   = "Vars"
			vars.Parent = plr
		end
		local xxValue = ffc(vars, key)
		if xxValue == nil then
			print(key, "not found in", plr, ".vars creating one")
			xxValue = Instance.new(keyToClass[typeof(key)], vars)
			xxValue.Name = key
		end
		xxValue.Value = value
	end
	function publicVars.setPublicVar(key, value)
		print("server: setPublicVar", key, value)
		local xxValue = ffc(sv, key)
		if xxValue == nil then
			print(key, "not found in rep.sv, creating one")
			xxValue      = Instance.new(keyToClass[typeof(key)], sv)
			xxValue.Name = key
		end
		xxValue.Value = value
	end
end

-- fpsCore
-- handles all the spawning and killing and despawning
-----------------------------------------------
local fpsCore = {}
do
	local sv          = wfc(rep, "SharedVars")
	local alivesF     = wfc(sv, "Alives")
	local ffc         = game.FindFirstChild
	local destroy     = game.Destroy
	local newInstance = Instance.new
	local spawnId     = {}

	local healthRegenSystem = {}
	do
		function healthRegenSystem.init()
			if settings.healthRegenSpeed then
				local sp = settings.healthRegenSpeed
				spawn(function()
					while wait(1) do
						for plrName, h in pairs(health) do
							local newH = h + sp > 100 and 100 or h + sp
							if newH ~= h then
								h = newH
								health[plrName] = h
								local plr = ffc(plrs, plrName)
								if plr then
									fpsServer.fireClient(plr, "health", h)
								end
							end
						end
					end
				end)
			end
		end
	end

	local replicationSystem = {}
	do
		function replicationSystem.init()

			fpsServer.listen("bulletHit", function(attacker, victim, hitName, dmg, rayP0, rayP1, weapon)
				-- print("server: bullethit", attacker, victim, hitName, dmg, rayP0)
				-- print(alive[attacker.Name], alive[victim.Name])
				assert(attacker and victim and hitName and rayP0 and rayP1 and weapon)
				if alive[attacker.Name] and alive[victim.Name] then
					health[victim.Name] = health[victim.Name] - dmg
					-- print("health = ", health[victim.Name])
					local attackInfo = {
						attacker = attacker,
						hitName  = hitName,
						dmg      = dmg,
						rayP0    = rayP0,
						rayP1    = rayP1,
						weapon   = weapon,
					}
					if health[victim.Name] <= 0 then
						fpsCore.kill(victim, "shot", attackInfo)
					else
						fpsServer.fireClient(victim, "health", health[victim.Name], attackInfo)
					end
				end
			end)
			fpsServer.listen("reset", function(plr)
				fpsCore.kill(plr, "reset")
			end)
			-- setup forwarders
			local replicators = {
				"look",
				"movingType",
				"lowerStance",
				"upperStance",
				"weapon",		-- a table containing weaponName, attachments, skin,.
				"leaningDir",
				"aim",
				"shoot",
				"stamina",
			}
			for _, updateStr in ipairs(replicators) do
				repServer.forward(updateStr)
			end
		end
	end

	function fpsCore.setAlive(plr, bool)
		alive[plr.Name] = bool
		if bool then
			local aliveStr = ffc(alivesF, plr.Name)
			if aliveStr then
				warn("fpsser: setting alive = true for", plr, "but already in the alivefolder.  continued")
			else
				local str = newInstance("StringValue")
				str.Name  = plr.Name
				str.Parent = alivesF
			end
		else 
			local aliveStr = ffc(alivesF, plr.Name)
			if aliveStr then
				destroy(aliveStr)
			else
				warn("fpsser: setting alive = false for", plr, "but not in the alivefolder.  continued")
			end
		end
	end
	-- function fpsCore.setHealth(plr, val)
	-- 	assert(plr, "plr is nil")
	-- 	local plrName          = plr.Name
	-- 	healthF[plrName].Value = val
	-- 	health[plrName]        = val
	-- end

	-- victim, killMethod, ...
	-- killMethod: shot: attacker, hitName, dmg, rayP0, rayP1, weapon
	-- killMethod: debug: nil
	function fpsCore.kill(victim, killMethod, killData)
		fpsServer.fireAllClients("kill", victim, killMethod, killData)
		fpsCore.setAlive(victim, false)
	end
	function fpsCore.despawn(plr)
		fpsServer.fireAllClients("despawn", plr)
		fpsCore.setAlive(plr, false)
	end
	function fpsCore.spawn(plr, spawnLocation)

		plr:LoadCharacter()

		if not plr.Character then
			plr.CharacterAdded:wait()
		end

		local char = plr.Character
		char.HumanoidRootPart.CFrame = spawnLocation.CFrame
		-- char.Parent = workspace.Alive   -- tell other players

		spawnId[plr.Name] = spawnId[plr.Name] + 1
		alive[plr.Name]   = true
		health[plr.Name]  = 100

		fpsServer.fireAllClients("spawn", 
			plr, 
			spawnLocation, 
			spawnId[plr.Name], 
			weaponSlots[plr.Name]
		)

		fpsCore.setAlive(plr, true)
	end
	function fpsCore.init()
		print("fpsCore init started")
		healthRegenSystem.init()
		replicationSystem.init()
		print("fpsCore init ended")
	end
	function fpsCore.onPlayerAdded(plr, plrName)
		spawnId[plrName] = 0
	end
	function fpsCore.onPlayerRemoving(plr, plrName)
		spawnId[plrName] = nil
		alive[plrName]        = nil
		health[plrName]       = nil
	end
end

-- data store system
-------------------------------
local dataStore = {}
do
	function dataStore.init()

	end
	function dataStore.onPlayerAdded(plr, plrName)
		weaponSlots[plrName] = {		-- attachments here, wip
			[1] = {
				weaponName  = "MK16", 
				attachments = {
					Optic = "Holographic Sight"
				},
				skin = nil,
			},
			[2] = {
				weaponName  = "MK16", 
				attachments = {
					-- Optic = "Holographic Sight"
				},
				skin = nil,
			},
		}
		publicVars.setPublicPlrVar(plr, "Level", 10)
	end
	function dataStore.onPlayerRemoving(plr, plrName)
		weaponSlots[plrName]  = nil
	end
end

-- the prematch scene
-- just the helicopter now
-- remember the prematch is gonna be used only once
-- bc we're using 
----------------------------------
local preMatch = {}
do
	function preMatch.init()	-- yield function
		print("preMatch.init started")
		if debugSettings.testingFull then
			publicVars.setPublicVar("Phase", "WaitInHeli")
			repeat 
				print("pre-match waiting for room info")
				wait(1)
			until roomInitInfo

			-- wait for all the players for freshstart / competitive
			-- startserver() should already processed the init players array in roomInitInfo
			local st = tick()
			local maxWaitTime = 45
			publicVars.setPublicVar("HeliTimer", maxWaitTime)
			while wait(1) and roomInitInfo.joinedCnt < roomInitInfo.expectedJoinedCnt do
				local now = tick()
				local T   = now - st
				publicVars.setPublicVar("HeliTimer", maxWaitTime + 1 - T)
				if T > maxWaitTime then
					roomInitInfo.initWaitingEnded = true
					break
				end
			end

			-- prematch ended
			wait(10)
			publicVars.setPublicVar("Phase", "OutOfHeli")
			wait(12)		-- wait for transition animations in client side
		end
		print("preMatch.init ended")
	end
end

-- gamemodes system
-------------------------------
local matchSystem = {}
do
	local getC      = game.GetChildren
	local resLib    = wfc(rep, "MatchResources")
	local nonHitbox = wfc(workspace, "NonHitbox")

	local invade = {}
	do
		-- consts
		local sites = {}
		local defusePhaseTL = 40
		local plantPhaseTL  = 2.75 * 60

		-- shared vars: should implement setter but no getter
		local countdown = {}
		local timeup 
		do
			-- consts
			local internalTick = 0.1
			local announceTick = 1

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
							setPublicVar("MatchTimer", time)
						end	
					end
				end)
			end
			function countdown.initOnMatchStart()
				countdown.set(plantPhaseTL)
				countdown.run()
			end
		end


		local bombSystem = {}
		local bomb          -- points to the bomb model / part
		local bomber        -- points to the plr
		local planted 			-- not just a boolean, a name of site instead
		local defused       -- just a boolaen
		do
			local flareTemp = wfc(resLib, "BombSiteFlare")
			local clone     = game.Clone
			local newCf     = CFrame.new
			local rad       = math.rad
			local newV3     = Vector3.new
			local ocf       = CFrame.fromOrientation
			local defBombOrientation = ocf(0, rad(152), rad(-90))

			-- just handles the input from the player and set the game states
			local plantingHandler = {}
			do
				function plantingHandler.initOnMatchStart()
					fpsServer.listen("planted", function(plr, siteName, sitePos)
							-- server side verification for planting
						local plrName  = plr.Name

						local verifications = {
							function() return siteName ~= nil end;
							function() return sitePos ~= nil end;
							function() return not planted end;
							function() return alive[plrName] end;
							function() return bomber == plr end;
							function() return sites[siteName] ~= nil end;
							function() return (sitePos - sites[siteName]).magnitude < 0.1 end;
						}
						local pass = true
						for i, 1, #verifications do
							if verification[i]() == false then
								pass = false
								warn("plr", plr, "fails to plant because verification", i, "is not met")
							end
						end
						if pass then					
							bombSiteHandler.plant(siteName, plr)
							-- wip here
						end
					end)
				end
			end
			local defusingHandler = {}
			do
				function defusingHandler.initOnMatchStart()
					fpsServer.listen("dufused", function(plr, bombPos)
						-- server side verification for defusing
						local plrName = plr.Name
						local verifications = {
							function() return bombPos ~= nil end;
							function() return planted end;
							function() return alive[plrName] end;
							function() return (bombPos - bomb.Position).magnitude < 0.1 end;
						}
						local pass = true
						for i, 1, #verifications do
							if verification[i]() == false then
								pass = false
								warn("plr", plr, "fails to defuse because verification", i, "is not met")
							end
						end
						if pass then
							bombHandler.defuse(plr)
						end
					end
				end
			end
			local droppingHafndler = {}
			do
				function droppingHandler.initOnMatchStart()
					local verify = function(plr)
						if bomber == plr then
							bombHandler.drop(plr)
						end
					end
					connect(players.Alive, verify)
					connect(players.Dead, verify)
					fpsServer.listen("dropBomb", verify)
				end
			end
			local pickingHandler = {}
			do
				function pickingHandler.initOnMatchStart()
					fpsServer.listen("pickingBomb", bombHandler.pickUpBy)
				end
			end

			-- handles the actually bomb and  functions.
			-- invoked by player the for input receivers
			--    or round start / phase start / matchstart
			--    or round phases changes such as time ends etc..
			local bombHandler = {}
			do
				function bombHandler.pickUpBy(plr)
					bombHandler.despawnBomb()
					bombHandler.setBomber(plr)
				end
				function bombHandler.drop(plr)
					local pos = players.getCurrOrLastPosition(plr) 
					if pos == nil then
						pos = bombSpawnLocation
						warn("bombHandler.drop by", plr, ". last pos not found, spawning bomb at default bomb spawn location")
					end
					bombHandler.spawnBomb(pos)
				end

				local raycasting = {}
				do
					local newRay = Ray.new
					local newV3  = Vecter3.new
					local downVector = newV3(0, -1000, 0) 
					local raycastWith = workspace.FindPartOnRayWithWhitelist
					function raycasting.down(top)
						local ray  = Ray.new(topVec, Vector3.new(0, -1000, 0))
						local _, p = workspace:FindPartOnRayWithWhitelist(ray, {workspace.Map.ActualMap})
						return raycastWith(workspace, newRay(top, downVector), {workspace.Map})
					end
				end
				local raycastDown        = raycasting.down
				local spcf               = Instance.new("Model").SetPrimaryPartCFrame
				local defBombOrientation = CFrame.fromOrientation(math.pi / 2, 0, 0)
				local bombSpawnLocation  = wfc(workspace, "BombSpawnLocation")
				local bombTemp           = wfc(resLib, "InvadeBomb")

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
					local dropPos = raycastDown(pos)

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
					publicVars.setPublicVar("Bomb", bomb)
				end
				-- setter for bomber
				function bombHandler.setBomber(_bomber)
					bomber = _bomber
					publicVars.setPublicVar("Bomber", bomber)
				end

				function bombHandler.startBeeping()
					local bc = bomb.BeepContainer

					-- setup audio beep
					local s  = audioSys.put("BombBeep", bc)
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
						for i = 1, defusePhaseTL do
							if bomb then
								if i < invade.defusePhaseTL - 5 then
									audioBeep()
									visualBeep()
								else
									fasterBeep(max(1, ceil(8 - defusePhaseTL + i)))
								end
							else
								break
							end
						end
					end)
				end
				function bombHandler.kaboom()
					audioSys.play("BombDetonated", bomb.Position)
					bombHandler.despawnBomb()
				end
			end

			local bombSiteHandler = {}
			do
				function bombSiteHandler.defuse(plr)
					bombSiteHandler.setDefused(true)
					-- bombSiteHandler.setPlanted(nil)
				end
				function bombSiteHandler.plant(site, pos, plr)
					bombSiteHandler.setPlanted(site)
					bombHandler.spawnBomb(pos)
					bombHandler.startBeeping()
					audioSys.play("BombPlanted", "2D")
				end
				function bombSiteHandler.initOnMatchStart()
					-- configure sites
					for _, site in ipairs(getC(wfc(workspace, "Bombsites"))) do
						local siteName    = site.Name
						sites[siteName]   = site
						site.Transparency = 1

						-- put flare in sites
						local flare = clone(flareTemp)
						spcf(flare, 
							newCf(site.CFrame.p - newV3(0, site.Size.X/2 - 1, 0)) 
							* defBombOrientation
						)
						flare.Parent = site
					end
					-- bombSiteHandler.setPlanted(nil)
				end

				-- setters
				function bombSiteHandler.setPlanted(_planted)
					if typeof(_planted) == "string" then
						_planted = sites[_planted]
					end
					planted = _planted
					publicVars.setPublicVar("Planted", planted)
				end
				function bombSiteHandler.setDefused(_defused)
					defused = _defused
					publicVars.setPublicVar("defused", defused)
				end
			end

			function bombSystem.initOnRoundStart()
				bombSiteHandler.setPlanted(nil)
				bombSiteHandler.setDefused(nil)
				bombHandler.spawn("default")
				bombHandler.setBomber(nil)
			end

			function bombSystem.initOnMatchStart()
				bombSiteHandler.initOnMatchStart()
				plantingHandler.initOnMatchStart()
				defusingHandler.initOnMatchStart()
				droppingHandler.initOnMatchStart()
				pickingHandler.initOnMatchStart()
			end
		end

		local atk
		local def
		local atkOnly
		local defOnly
		local teamSystem = {}
		do
			local teams = game.Teams
			function teamSystem.switchSide()
				if not atk or not def then 		-- first round
					atk = teams.Alpha
					def = team.Beta
				else
					local tmp = atk
					atk = def
					def = tmp
				end
				-- annonuce it
				publicVars.setPublicVar("Atk", atk)
				publicVars.setPublicVar("Def", def)
			end
			function teamSystem.spawnAll()
				for _, plr in ipairs(getC(plrs)) do
					if clientSpawnable[plr.Name] then
						players.spawn(plr, {
							spawnLocation = teamSystem.getRandomSpawnLocation(plr.Team),
							side = teamSystem.getSide(plr.Team)
						})
					end
				end
			end
			function teamSystem.initOnRoundStart()
				connect(players.)
			end
		end

		function invade.runMatch()		-- return the matchwinner (a team) and the teamname

			-- init on matchstart here
			local bo = 5
			local maxWins   = (bo + 1) / 2
			local currRound = 0
			local matchWinner, matchWinnerName = nil, nil
			local teamWins = {
				Alpha = 0,
				Beta = 0,
			}
			bombSystem.initOnMatchStart()

			-- start the round loop
			while matchWinner == nil do
				local roundWinner, roundWinnerName = invade.runRound()
				teamWins[roundWinnerName] = teamWins[roundWinnerName] + 1

				if teamWins[roundWinnerName] >= maxWins then
					matchWinner = roundWinner
					matchWinnerName = roundWinnerName
				end
			end

			return matchWinner, matchWinnerName
		end

		-- equivalent as run planting phase
		local internalTick = 0.5
		function invade.runRound()		-- returns the roundwinner
			local matchWinner

			-- init on round start
			bombSystem.initOnMatchStart()
			teamSystem.initOnMatchStart()
			countdown.initOnMatchStart()

			while matchWinner == nil do
				if timeup then
					if planted then
						if atkOnly then
							matchWinner = atk
						else
							matchWinner = invade.runDefusingPhase()
						end 
					else
						if atkOnly then
							matchWinner = atk
						else
							matchWinner = def
						end
					end
				else
					if planted then
						if atkOnly then
							matchWinner = atk
						else
							matchWinner = invade.runDefusingPhase()
						end
					else
						if atkOnly then
							matchWinner = atk
						elseif defOnly then
							matchWinner = def
						else
							matchWinner = nil
						end
					end
				end
				wait(internalTick)
			end
		end
		function invade.runDefusingPhase()
			local matchWinner = nil

			countdown.set(defusePhaseTL)

			while matchWinner == nil do
				if timeup then
					if defused then
						matchWinner = def
					else
						matchWinner = atk
					end
				else
					if defused then
						matchWinner = def
					else
						if atkOnly then
							matchWinner = atk
						else
							matchWinner = nil
						end
					end
				end
				wait(internalTick)
			end

			return matchWinner
		end
	end
	local gamemodes = {
		invade = invade,
	}

	function matchSystem.init()
		print("matchSystem.init")
		if debugSettings.testingCharacters then
			local spawnLocations = workspace.SpawnLocations:GetChildren()
			local function spawnAll()
				for _, plr in ipairs(getC(plrs)) do
					if not alive[plr.Name] and clientLoaded[plr.Name] then
						fpsCore.spawn(plr, spawnLocations[math.random(1, #spawnLocations)])
					end
				end
			end
			spawnAll()
			spawn(function()
				while wait(10) do
					spawnAll()
				end
			end)
		end
		if debugSettings.testingGamemode then
			local matchWinner = invade.runMatch()
			print("matchWinner is", matchWinner)
		end
	end
	function matchSystem.onPlayerAdded(plr, plrName)

	end
	function matchSystem.onPlayerRemoving(plr, plrName)

	end
end


-- handles player added and player removing
-- grabs data from data teleported here
---------------------------------------
local main = {}
do
	local newInstance = Instance.new

	local joinHandlers = {
		debug = function(plr, plrName, joinData)
			roomInitInfo = {}
		end;
		quickjoin = function(plr, plrName, joinData)
			if roomInitInfo == nil then
				plr:Kick("trying to quick join a server with no room data")
				warn(plrName, "was kicked due to trying to quick join a server with no room data")
			end
		end;
		freshstart = function(plr, plrName, joinData)
			if roomInitInfo.initWaitingEnded then
				plr:Kick("joining server timed out. initWaitingEnded")
				warn(plrName, "was kicked due to joining server timed out. initWaitingEnded")
			end
		end;
		competitive = function(plr, plrName, joinData)
		end;
	}
	local function startServer(_roomInitInfo)
		roomInitInfo = _roomInitInfo
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

		-- assign teams based on roomInitInfo
		-- done in playeradded
	end
	fpsServer.listen("clientLoaded", function(plr, joinData)
		if clientLoaded[plr.Name] then
			plr:Kick("sent clientLoaded signal twice")
			return
		end

		print("clientloaded with joinData")
		tableUtils.printTable(joinData)
		
		-- load the game init info
		if roomInitInfo == nil and joinData.roomInitInfo then
			startServer(joinData.roomInitInfo)
		end

		-- process join method
		local joinMethod = joinData.joinMethod
		local joinHandler 
		if joinMethod then
			joinHandler = joinHandlers[joinMethod]
		end
		if joinHandler then
			joinHandler(plr, plr.Name, joinData)
		else
			plr:Kick("invalid joinMethod", joinMethod)
			warn("plr", plr.Name, "is kicked due to invalid joinMethod", joinMethod)
		end

		-- mark client loaded to true
		clientLoaded[plr.Name] = true
	end)

	-- player in
	local function onPlayerAdded(plr)
		local plrName = plr.Name
		clientLoaded[plrName] = false
		repeat
			print("wating for client", plrName, "to send the loaded signal")
			if ffc(plrs, plrName) == nil then
				print("player", plrName, "quitted before sending the loaded signal, waiting ends")
				return
			end
			wait(1)
		until clientLoaded[plrName]
		repeat 
			print("server", plr, "waiting for room info")
			wait(1)
		until roomInitInfo
		wait()

		-- count player
		if roomInitInfo.joinedCnt == nil then
			roomInitInfo.joinedCnt = 0
		end	
		roomInitInfo.joinedCnt = roomInitInfo.joinedCnt + 1
		print("joinedCnt++, is now", roomInitInfo.joinedCnt)

		-- assign teams
		for _, teamName in ipairs({"Alpha", "Beta"}) do
			if roomInitInfo[teamName][plrName] then
				local team = game.Teams[teamName]
				plr.Team = team
				break
			end
		end
		if plr.Team == nil then
			local msg = plrName.." is neither in alpha nor in beta team"
			plr:Kick(msg)
			warn("server: kicked", plrName, "because", msg)
		end

		fpsCore.onPlayerAdded(plr, plrName)
		dataStore.onPlayerAdded(plr, plrName)
		matchSystem.onPlayerAdded(plr, plrName)
		clientSpawnable[plr.Name] = true
	end
	for _, p in ipairs(plrs:GetPlayers()) do
		onPlayerAdded(p)
	end
	connect(plrs.PlayerAdded, onPlayerAdded)

	-- player out
	connect(plrs.PlayerRemoving, function(leaver)
		local leaverName         = leaver.Name
		clientLoaded[leaverName] = nil
		clientSpawnable[plr.Name] = nil

		fpsCore.onPlayerRemoving(leaver, leaverName)
		dataStore.onPlayerRemoving(leaver, leaverName)
		matchSystem.onPlayerRemoving(leaver, leaverName)
	end)

	-- init all
	fpsCore.init()
	dataStore.init()
	preMatch.init()
	matchSystem.init()
end

-- admin server-side command-line system
---------------------------------------
do
	local debugBf = wfc(ss, "DebugBf")
	local debugRf = wfc(rep, "DebugRf")
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
	}
	local cmdLvl = {
		kill = 1,
	}
	local onInvoke = function(cmd, ...)
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
		end
	end
end