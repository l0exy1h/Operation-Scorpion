-- the data store handler in the server side

local rep        = game.ReplicatedStorage
local gm         = rep:WaitForChild("GlobalModules")
local levelExpMd = require(gm:WaitForChild("LevelExp"))

local plrs       = game.Players

local Events      = rep:WaitForChild("Events")
local dsEvent     = Events:WaitForChild("DS")
local RemoteFuncs = rep:WaitForChild("RemoteFuncs")
local dsFunc      = RemoteFuncs:WaitForChild("DS")	-- for data store
local ds          = game:GetService("DataStoreService")

local http = game:GetService("HttpService")

local currVersion = "beta.reserveServerUpdate"

local newPlaceId = 2116774667

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

local default = require(script:WaitForChild("DefaultData")).get()

-- consider the new players
-- includes default attc list
-- identify alpha testers
-- give alpha plr money based on the current exp
-- set the default-owned gears/attcs here
-- get data from the un-ordered data store
local function getData(plr)
	local unorderedDs = ds:GetDataStore("stats", plr.UserId)
	local plrName     = plr.Name
	local data
	local suc, msg = pcall(function()
		data = {
			-- unordered
			exp             = unorderedDs:GetAsync("exp") or 0,
			is_alpha_tester = unorderedDs:GetAsync("isAlphaTester") or false,
			
			gears = unorderedDs:GetAsync("gears") or default.gears,
			loadouts = {
				unorderedDs:GetAsync("loadout1") or default.loadouts.loadout1,
			},
	
			-- ordered portion is also stored here
			acc_credit = ds:GetOrderedDataStore("ordered", "accCredit"):GetAsync(plrName) or 0,
			credit     = ds:GetOrderedDataStore("ordered", "credit"):GetAsync(plrName) or 0,
			kills      = ds:GetOrderedDataStore("ordered", "kills"):GetAsync(plrName) or 0,
			headshots  = ds:GetOrderedDataStore("ordered", "headshots"):GetAsync(plrName) or 0,
			casual_wins= ds:GetOrderedDataStore("ordered", "casualWins"):GetAsync(plrName) or 0,
			captures   = ds:GetOrderedDataStore("ordered", "captures"):GetAsync(plrName) or 0,
			damage     = 0,
			assists    = 0,
			rank       = 0,
			ranked_wins= 0,
			
			match_cnt_today = 0,
			last_login_version = currVersion
		}
		
		data.level = levelExpMd.lvl(data.exp)
	end)
	if suc then 
		return data
	else
		return msg			-- return the error msg when the data store is fucked
	end
end



-- garbage collection for connections
local connections = {}
local tp = game:GetService("TeleportService")

-- connection for teleportation request
dsEvent.OnServerEvent:connect(function(caller, func)
	pcall(function()
		if func == "teleportButtonPressed" then 
			tp:Teleport(newPlaceId, caller)
		end
	end)
end)

-- main module: data sync
--------------------------------------------
local function onPlayerAdded(plr)
	warn("playeradded", plr)

	local plrName = plr.Name
	local userId  = plr.UserId
	local unorderedDs = ds:GetDataStore("stats", plr.UserId)
	local newPlayerQ = unorderedDs:GetAsync("exp") == nil

	if newPlayerQ then
		tp:Teleport(newPlaceId, plr)
		return
	else
		local suc, msg = pcall(function()
			sql.query("select now()")
		end)
		if suc then
			local rawData = sql.query(string.format([[select * from playerstats where user_id = %d]], userId))
			if rawData[1] then
				-- player column exists in sql
				local data = rawData[1]
				if data.synced_from_old_os == true then	
					-- already synced
					dsEvent:FireClient(plr, "sqlColumnFoundAndSynced")
					dsEvent:FireClient(plr, "teleportReady", {"You have data in both the old and new Operation Scorpion place. Press Sync to override your newest data with the previous save."})
				else
					-- not synced
					dsEvent:FireClient(plr, "sqlColumnFoundButNotSynced")
					connections[plr.Name] = dsEvent.OnServerEvent:connect(function(caller, func)
						if caller == plr then
							if func == "syncButtonPressed" then
								local oldData = getData(caller)
								if type(oldData) == "string" then
									-- error retrieving data from roblox default data store
									dsEvent:FireClient(plr, "robloxDataStoreError", {oldData})							
								else
									print("old data: ")
									sql.printTable(oldData)									
									
									oldData.synced_from_old_os = true
									local suc2, msg2 = pcall(function()
										sql.query(string.format([[
											update playerstats set
												is_alpha_tester = %s, 
												exp = exp + %d, 
											  headshots = headshots + %d,
											  kills = kills + %d, 
											  level = %d, 
												credit = credit + %d, 
												acc_credit = acc_credit + %d, 
												casual_wins = casual_wins + %d, 
												captures = captures + %d, 
												rank = 0, 
												ranked_wins = 0, 
												match_cnt_today = 0, 
												synced_from_old_os = %s,
												gears = '%s',
											  loadouts = '%s',
												damage = damage + %d, 
												assists = assists + %d
											where user_id = %d 
											]],
											tostring(oldData.is_alpha_tester),
											oldData.exp,
											oldData.headshots,
											oldData.kills,
											levelExpMd.lvl(data.exp + oldData.exp),
											oldData.credit,
											oldData.acc_credit,
											oldData.casual_wins,
											oldData.captures,
											tostring(oldData.synced_from_old_os),
											http:JSONEncode(oldData.gears),
											http:JSONEncode(oldData.loadouts),
											oldData.damage,
											oldData.assists,
											userId																					
										))
									end)
									
									if suc2 then
										wait(1)
										dsEvent:FireClient(caller, "teleportReady", {"Your data has already been merged. Press teleport to play Operation Scorpion!"})
									else
										dsEvent:FireClient(caller, "sqlError", {msg2})
									end
								end
							end
						end
					end)
				end
			else
				-- player column does not exist in sql
				dsEvent:FireClient(plr, "noColumnInSql")
				connections[plr.Name] = dsEvent.OnServerEvent:connect(function(caller, func)
					if caller == plr then
						if func == "syncButtonPressed" then
							local oldData = getData(caller)
							if type(oldData) == "string" then
								-- error retrieving data from roblox default data store
								dsEvent:FireClient(plr, "robloxDataStoreError", {oldData})							
							else
								local data = oldData
								data.synced_from_old_os = true
								local suc2, msg2 = pcall(function()
									sql.query(string.format([[
										insert into playerstats(
											user_id, user_name, is_alpha_tester, last_login_version, exp, 
											headshots, kills, level, credit, acc_credit, 
											casual_wins, captures, rank, ranked_wins, match_cnt_today, 
											synced_from_old_os,
											gears,
											loadouts,
											damage, assists
										)
										values(%d, '%s', %s, '%s', %d, 
											%d, %d, %d, %d, %d, 
											%d, %d, %d, %d, %d, 
											%s, '%s', '%s',
											%d, %d
										)
										]], 
										plr.UserId,
										plr.Name,
										tostring(data.is_alpha_tester),
										data.last_login_version,
										data.exp,		--5
										data.headshots, 
										data.kills,
										data.level,
										data.credit,
										data.acc_credit,	-- 10
										data.casual_wins,
										data.captures,
										data.rank,
										data.ranked_wins,
										data.match_cnt_today,	-- 15
										tostring(data.synced_from_old_os),
										http:JSONEncode(data.gears),
										http:JSONEncode(data.loadouts),
										data.damage,
										data.assists
									))
								end)
								
								if suc2 then
									wait(1)
									dsEvent:FireClient(caller, "teleportReady", {"Your data has already been synced. Press teleport to play Operation Scorpion!"})
								else
									dsEvent:FireClient(caller, "sqlError", {msg2})
								end
							end
						end
					end
				end)
			end 
		else
			dsEvent:FireClient(plr, "sqlError", {msg})
		end
	end
end
--[[for _, plr in ipairs(plrs:GetPlayers()) do
	onPlayerAdded(plr)
end--]]
--plrs.PlayerAdded:connect(onPlayerAdded)
dsEvent.OnServerEvent:connect(function(plr, func)
	if func == "clientSyncModuleLoaded" then
		onPlayerAdded(plr)
	end
end)
plrs.PlayerRemoving:connect(function(plr)
	if connections[plr.Name] then
		connections[plr.Name]:disconnect()
	end
end)
---------------------------------------------
---------------------------------------------
-- client side:

local home    = script.Parent
local welcome = home:WaitForChild("Welcome")
local homePageControl = home:WaitForChild("UIPageLayout")

local rep = game.ReplicatedStorage
local gm  = rep:WaitForChild("GlobalModules")
local ga  = require(gm:WaitForChild("GeneralAnimation"))
local sd  = require(gm:WaitForChild("ShadedTexts"))

local buttonSound    = require(gm:WaitForChild("ButtonSound")) 
local rs = game:GetService("RunService").RenderStepped

local lp    = game.Players.LocalPlayer
local mouse = lp:GetMouse() 

local events  = rep:WaitForChild("Events")
local dsEvent = events:WaitForChild("DS")

local rFuncs  = rep:WaitForChild("RemoteFuncs")

-- welcome page
-----------------
local syncGui = welcome:WaitForChild("Sync")
local buts    = syncGui:WaitForChild("List"):WaitForChild("ButHolder")
local syncBut = buts:WaitForChild("Sync")
local teleBut = buts:WaitForChild("Teleport")
local syncMsg = syncGui:WaitForChild("List"):WaitForChild("Msg")

local syncStarted = false

dsEvent.OnClientEvent:connect(function(func, args)
	if func == "noColumnInSql" then
		sd.setText(syncMsg, "Your data has been found in the old Operation Scorpion place. Press Sync to get your data back.")
		syncStarted = true
	elseif func == "sqlColumnFoundButNotSynced" then
		sd.setText(syncMsg, "You have data in both the old and new Operation Scorpion place. Press Sync to override your newest data with the previous save.")
		syncStarted = true
	elseif func == "sqlColumnFoundAndSynced" then
		--sd.setText(syncMsg, "Data found in two places and already synced before. Press button to teleport. contact the devs if you have any question.") 
		syncStarted = true
		
	elseif func == "teleportReady" then
		teleBut.Visible = true
		syncBut.Visible = false
		local msg = args[1]
		sd.setText(syncMsg, msg)
	elseif func == "robloxDataStoreError" then
		local msg = args[1]
		sd.setText(syncMsg, "Roblox Data Store Error, please send a screenshot to the bug report forum\n"..msg)
		syncBut.Visible = false
		teleBut.Visible = false
	elseif func == "sqlError" then
		local msg = args[1]
		sd.setText(syncMsg, "SQL Error, please send a screenshot to the bug report forum\n"..msg)
		syncBut.Visible = false
		teleBut.Visible = false		
	end
end)

local nextDots = {
	[""]    = ".",
	["."]   = "..",
	[".."]  = "...",
	["..."] = "",
} 
local function animateShadedDots(fr, baseText)
	spawn(function()
		local dots = ""
		while wait(1) do
			sd.setText(fr, baseText..dots)
			dots = nextDots[dots]
		end
	end)
end

local syncButtonPressed = false
syncBut.MouseButton1Click:connect(function()
	if not syncButtonPressed then
		syncButtonPressed = true
		dsEvent:FireServer("syncButtonPressed")
		animateShadedDots(syncBut.Frame, "Syncing")
	end
end)
local teleportButtonPressed = false
teleBut.MouseButton1Click:connect(function()
	if not teleportButtonPressed then
		teleportButtonPressed = true
		dsEvent:FireServer("teleportButtonPressed")
		animateShadedDots(teleBut.Frame, "Teleporting")
	end
end)
buttonSound.setDefault(teleBut)
buttonSound.setDefault(syncBut)

dsEvent:FireServer("clientSyncModuleLoaded")

--[[repeat
	wait(0.1)
until syncStarted--]]
local loadingEvent = events:WaitForChild("Loading")
local scriptLoaded = Instance.new("BoolValue")
scriptLoaded.Name  = "HomeScript"
scriptLoaded.Parent= loadingEvent

