-- commented by y0rkl1u
-- compatibility issue confimed: my GUI will lag if I enable dis script

local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local sd = require(gm:WaitForChild("ShadedTexts"))
local timerMd = require(gm:WaitForChild("Timer"))
local Events = rep:WaitForChild("Events")
local tpOutEvent = Events:WaitForChild("TpOut")
local plrs = game.Players

repeat
	wait(0.1)
until _G.plrData
--local plrData = _G.plrData

-- const table containing template places for different maps
local placeId = {
	["Office_Day"] = 1905498769,
	["Office_Night"] = 1905498533,
	["Office_Sunrise"] = 1905497447,
	["Office_Sunset"] = 1905497198,
	["Office_Rainy Day"] = 1905498284,
	["Office_Rainy Night"] = 1905498010,
	["Office_Snowy Day"] = 1905497801,
	["Office_Snowy Night"] = 1905497627,
	["Resort_Day"] = 1905497054,
	["Resort_Night"] = 1905496872,
	["Resort_Sunrise"] = 1905494865,
	["Resort_Sunset"] = 1905457440,
	["Resort_Rainy Day"] = 1905496705,
	["Resort_Rainy Night"] = 1905496532,
	["Resort_Sandstorm"] = 1905496386,
}

-- return a table of plrs who are inside a specific team cylinder
function GetInCylinder(position,radius)
	local ret = {}
	for i,v in ipairs(game.Players:GetChildren()) do
		if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
			local pos = v.Character.HumanoidRootPart.Position
			if (pos*Vector3.new(1,0,1)-position*Vector3.new(1,0,1)).magnitude <= radius and pos.y > position.y then
				table.insert(ret,v)
			end
		end
	end
	return ret
end

-- return the map name with a weather option
function MapName(folder)
	return folder.Parent.Name.."/"..folder.Name
end
local function splitMapName(s)
	local i, _ = string.find(s, "/")
	return string.sub(s, 1, i-1), string.sub(s, i+1)
end

-- return a table of map with weather options
-- {mapname, gamemode}
local function getRandomChild(folder)
	local list = folder:GetChildren()
	return list[math.random(1, #list)]
end
function GenerateVoteOptions()
	local ret = {}
	while #ret < 4 do
		local newOption = {getRandomChild(rep.Map).Name, getRandomChild(rep.Gamemode).Name}
		local repeated = false
		for _, opt in ipairs(ret) do
			if opt[1] == newOption[1] and opt[2] == newOption[2] then
				repeated = true
			end
		end
		if not repeated then
			ret[#ret + 1] = newOption
		end 
	end
	return ret
end

-- get the voting option which has the highest count
local function getFinalOption(f)
	local maxVoteOptions = {}
	local maxVote = -1
	for _, v in ipairs(f:GetChildren()) do
		if v.Value > maxVote then
			maxVote = v.Value
			maxVoteOptions = {v.Name}
		elseif v.Value == maxVote then
			maxVoteOptions[#maxVoteOptions + 1] = v.Name
		end
	end
	local finalOpt = maxVoteOptions[math.random(1, #maxVoteOptions)]
	local splitPos, _ = string.find(finalOpt, "_")
	return string.sub(finalOpt, 1, splitPos - 1), string.sub(finalOpt, splitPos + 1)
end

local timer = {}

local lastTpOut = {
	Matchmaking1 = -10000,
	Matchmaking2 = -10000,
	Matchmaking3 = -10000,
} 
local waitTime = 25

local dsNotFoundLastCheck = {
	
}

local function checkPlrData(plr)
	local data = _G.plrData[plr.Name]
	if data ~= nil then
		return true
	else
		if dsNotFoundLastCheck[plr.Name] == nil then

			print("data table not found for", plr)
			dsNotFoundLastCheck[plr.Name] = tick()
		elseif tick() - dsNotFoundLastCheck[plr.Name] > 5 then
			dsNotFoundLastCheck[plr.Name] = tick()
			print("data table not found for", plr)
		end
		return false
	end
end

-- main
function HandleMatch(match)		-- match is a model	
	
	local now = tick()
	if now - lastTpOut[match.Name] <= waitTime then
		return
	end 
	
	local matchStats = match.MatchStats
	local scorpCircle = match.Scorpions.Circle
	local skullCircle = match.Skulls.Circle
	
	-- a bunch of StringValues with the names of plrs storing their voting options
	local Scorps = matchStats.Players.Scorpions
	local Skulls = matchStats.Players.Skulls
	
	local Screens = match.Screen
	
	local inScorp = GetInCylinder(scorpCircle.CFrame.p,scorpCircle.Size.z/2)	-- a table containing plrs in the circle
	local curScorp = #Scorps:GetChildren()
	
	local inSkull = GetInCylinder(skullCircle.CFrame.p,skullCircle.Size.z/2)
	local curSkull = #Skulls:GetChildren()
	
	-- initialize the GUI
	if matchStats.Info.SetUp.Value == false then
		-- setting up the gui
		matchStats.Voting:ClearAllChildren()
		
		if Screens.Middle:FindFirstChild("MidGUI") == nil then
			script.MidGUI:Clone().Parent = Screens.Middle
			script.LeftGUI:Clone().Parent = Screens.Left
			script.RightGUI:Clone().Parent = Screens.Right
		end
		
		--Screens.Middle.MidGUI.Voting:ClearAllChildren()
		for _, gui in ipairs(Screens.Middle.MidGUI.Voting:GetChildren()) do
			if not gui:IsA("UILayout") then
				gui:Destroy()
			end
		end
		matchStats.Voting:ClearAllChildren()
		
		timer[match.Name] = timerMd.new(Screens.Middle.MidGUI.Timer)

		Screens.Middle.MidGUI.Timer.sec.Text = "0"
		sd.setProperty(Screens.Middle.MidGUI.Status, "Text", "Setting up match")
		
		-- get maps with weather options and get onto the gui
		local options = GenerateVoteOptions()
		for i, v in ipairs(options) do
			local mapName = v[1]
			local gamemode = v[2]
			local optIdentifier = mapName.."_"..gamemode

			x = (i-1)%4*0.25
			y = math.floor((i-1)/4)*0.5
			vt = Screens.Middle.MidGUI.VoteTemplate:clone()
			vt.Name = optIdentifier
			vt.Position = UDim2.new(x,0,y,0)
			vt:WaitForChild("Icon").Image = rep.Map[mapName].Value

			-- local mapOriginalName, lightingType = splitMapName(MapName(v))
			sd.setProperty(vt.Icon.Title1, "Text", mapName)
			sd.setProperty(vt.Icon.Title2, "Text", gamemode)
			sd.setProperty(vt.Icon.Votes, "Text", "0")
			vt.Visible = true
			vt.Parent = Screens.Middle.MidGUI.Voting
			
			iv = Instance.new("IntValue")	-- voting
			iv.Name = optIdentifier
			iv.Value = 0
			iv.Parent = matchStats.Voting
		end
		matchStats.Info.SetUp.Value = true
	end
	
	-- recalc the voting count every 0.01sec
	for i,v in ipairs(matchStats.Voting:GetChildren()) do
		v.Value = 0
	end
	
	-- for team scorpion
	for i,v in ipairs(inScorp) do								-- check everyone in the circle 
		local boot = true													-- true <-> not in the team, i.e. needs to leave the circle
		if checkPlrData(v) then
			if Scorps:FindFirstChild(v.Name) then			-- plr in circle before and now
				boot = false
				v.CurrentMatch.Value = match
			elseif curScorp < 5 then									-- plr not in circle before, consider joining
				boot = false
				n = Instance.new("StringValue")					-- update Scorps (plrName -> voting option)
				n.Name = v.Name
				n.Value = ""
				n.Parent = Scorps
				curScorp = curScorp+1
				v.CurrentMatch.Value = match
			end
			if boot == true then											-- cnm, gunna
				if v.Character then
					if v.Character:FindFirstChild("HumanoidRootPart") then
						local pos = v.Character.HumanoidRootPart.Position
						local torpos = pos*Vector3.new(1,0,1)
						local spos = scorpCircle.Position*Vector3.new(1,0,1)
						local rel = CFrame.new(torpos,spos)
						local dist = (torpos-spos).magnitude
						v.Character.HumanoidRootPart.CFrame = CFrame.new(pos)+rel.lookVector*-(scorpCircle.Size.z/2-dist+1)
					end
				end
			end
		end
	end
	for i,v in ipairs(Scorps:GetChildren()) do
		local isThere = false														-- check if the plr quits
		for a,b in ipairs(inScorp) do
			if b.Name == v.Name then
				isThere = true												-- still there
			end
		end
		if isThere == false then									-- cnm, gunna
			v:Destroy()
		else
			if matchStats.Voting:FindFirstChild(v.Value) then		-- calculate the voting count for each voting option
				matchStats.Voting[v.Value].Value = matchStats.Voting[v.Value].Value + 1
			end
		end
	end
	
	-- for team skull
	for i,v in ipairs(inSkull) do
		local boot = true
		if checkPlrData(v) then
			if Skulls:FindFirstChild(v.Name) then
				boot = false
				v.CurrentMatch.Value = match
			elseif curSkull < 5 then
				boot = false
				n = Instance.new("StringValue")
				n.Name = v.Name
				n.Value = ""
				n.Parent = Skulls
				curScorp = curScorp+1
				v.CurrentMatch.Value = match
			end
			if boot == true then
				if v.Character then
					if v.Character:FindFirstChild("HumanoidRootPart") then
						local pos = v.Character.HumanoidRootPart.Position
						local torpos = pos*Vector3.new(1,0,1)
						local spos = skullCircle.Position*Vector3.new(1,0,1)
						local rel = CFrame.new(torpos,spos)
						local dist = (torpos-spos).magnitude
						v.Character.HumanoidRootPart.CFrame = CFrame.new(pos)+rel.lookVector*-(skullCircle.Size.z/2-dist+1)
					end
				end
			end
		end
	end
	
	for i,v in ipairs(Skulls:GetChildren()) do
		local isThere = false
		for a,b in ipairs(inSkull) do
			if b.Name == v.Name then
				isThere = true
			end
		end
		if isThere == false then
			v:Destroy()
		else
			if matchStats.Voting:FindFirstChild(v.Value) then
				matchStats.Voting[v.Value].Value = matchStats.Voting[v.Value].Value + 1
			end
		end
	end
	
	-- display the voting counts
	for i,v in ipairs(matchStats.Voting:GetChildren()) do
		ui = Screens.Middle.MidGUI.Voting:FindFirstChild(v.Name)
		if ui then
			sd.setProperty(ui.Icon.Votes, "Text", v.Value)
		end
	end
	
	sd.setProperty(Screens.Middle.MidGUI.Casual, "Text", "CASUAL")
	
	-- update the plrList GUI
	for _, gui in ipairs(Screens.Left.LeftGUI.Frame.List:GetChildren()) do	-- added by y0rkl1u
		if not gui:IsA("UILayout") and gui.Name ~= "Title" then
			gui:Destroy()
		end 
	end
	local newSkulls = Skulls:GetChildren()
	for i,v in ipairs(newSkulls) do
		local pt = Screens.Left.LeftGUI.PlayerTemp:clone()
		local plr = game.Players:FindFirstChild(v.Name) 
		if plr then
			local data = _G.plrData[plr.Name]
			sd.setProperty(pt.Level, "Text", data.level)
			sd.setProperty(pt.PlrName, "Text", plr.Name)
			sd.setProperty(pt.Rank, "Text", data.rank)
			pt.Name = plr.Name
			pt.BackgroundColor3 = (i%2 == 0 and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(49, 49, 49))
			pt.Visible = true
			pt.Parent = Screens.Left.LeftGUI.Frame.List
		end
	end
	sd.setProperty(Screens.Left.LeftGUI.Frame.TeamCnt, "Text", #newSkulls.." | 5")
	
	for _, gui in ipairs(Screens.Right.RightGUI.Frame.List:GetChildren()) do   -- added by y0rkl1u
		if not gui:IsA("UILayout") and gui.Name ~= "Title" then
			gui:Destroy()
		end 
	end
	local newScorps = Scorps:GetChildren()
	for i,v in ipairs(newScorps) do
		local pt = Screens.Right.RightGUI.PlayerTemp:clone()
		local plr = game.Players:FindFirstChild(v.Name) 
		if plr then
			local data = _G.plrData[plr.Name]
			sd.setProperty(pt.Level, "Text", data.level)
			sd.setProperty(pt.PlrName, "Text", plr.Name)
			sd.setProperty(pt.Rank, "Text", data.rank)
			pt.Name = plr.Name
			pt.BackgroundColor3 = (i%2 == 0 and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(49, 49, 49))
			pt.Visible = true
			pt.Parent = Screens.Right.RightGUI.Frame.List
		end
	end
	sd.setProperty(Screens.Right.RightGUI.Frame.TeamCnt, "Text", #newScorps.." | 5")
	
	-- check if match is ok to run: minplrCount & Balance
	--setStatus = (#newSkulls >= matchStats.Info.MinTeamSize.Value and #newScorps >= matchStats.Info.MinTeamSize.Value) and "Voting" or "Waiting for at least "..matchStats.Info.MinTeamSize.Value.." player on each team."
	local countdown = false
	if (#newSkulls >= matchStats.Info.MinTeamSize.Value and #newScorps >= matchStats.Info.MinTeamSize.Value) and (#newSkulls + #newScorps >= 1) then	
		if math.abs(#newSkulls-#newScorps) > matchStats.Info.MaxTeamImbalance.Value then
			setStatus = "Teams unbalanced"
		else
			setStatus = "Vote for a map"
			countdown = true		-- ok to run the match: proceed to countdown
		end
	else
		setStatus = "At least "..matchStats.Info.MinTeamSize.Value.." player per team needed to start"
	end
	match.CountDown.Value = countdown
	
	-- countdown!!!!
	if countdown then
		-- timer using workspace.DistributedGameTime (accumulated runtime so far)
		timer[match.Name]:start()
		if workspace.DistributedGameTime - matchStats.Info.LastTimeUpdate.Value >= 1 then
			matchStats.Info.Timer.Value = matchStats.Info.Timer.Value - 1
			matchStats.Info.LastTimeUpdate.Value = workspace.DistributedGameTime
		end
	else
		-- freeze the timer to the maximum waiting time if match cannot begin
		timer[match.Name]:reset()
		matchStats.Info.Timer.Value = matchStats.Info.VotingTime.Value	 
	end
	
	-- countdown phase end, starting the match
	if matchStats.Info.Timer.Value <= 0 and countdown then
		local teleportSt = tick()
		warn("about to teleport")
		--START MATCH
		matchStats.Info.Timer.Value = matchStats.Info.VotingTime.Value		-- reset timer
		matchStats.Info.LastTimeUpdate.Value = workspace.DistributedGameTime
		local finalMap, finalGamemode = getFinalOption(matchStats.Voting)
		warn(string.format("finalMap = %s, finalGamemode = %s", finalMap, finalGamemode))

		-- randomly select a weather option now
		local finalWeather = getRandomChild(rep.Map[finalMap]).Name
		warn(string.format("finalWeather = %s", finalWeather))
		local placeIdentifier = finalMap.."_"..finalWeather

		--[[temp = workspace.Maps:FindFirstChild(matchStats.Info.Gamemode.Value).Template:clone()
		temp.Name = matchStats.Info.Gamemode.Value
		temp.Parent = workspace.CurrentMatches
		
		pos = Vector3.new(#workspace.CurrentMatches:GetChildren()*200,0,0)
		
		temp.Scorpions.CFrame = CFrame.new(pos-Vector3.new(0,0,15))
		temp.Skulls.CFrame = CFrame.new(pos+Vector3.new(0,0,15))
		
		temp.Scorpions.Attachment.BillboardGui.Title.Text = matchStats.Info.Gamemode.Value.." :: "..selMap.Name
		temp.Skulls.Attachment.BillboardGui.Title.Text = matchStats.Info.Gamemode.Value.." :: "..selMap.Name]]
		
		timer[match.Name]:reset()		
		
		-- Teleport Service
		-- set up data table
		local data = {}
		data.scorpion = {}
		for i, plr in ipairs(newScorps) do
			table.insert(data.scorpion, plr.Name)
		end
		data.skull = {}
		for i, plr in ipairs(newSkulls) do
			table.insert(data.skull, plr.Name)
		end
		data.plrCnt = #data.skull + #data.scorpion
		data.mapName = finalMap
		data.gamemode = finalGamemode
		data.weather = finalWeather		-- not used in the match place any more
		data.placeIdentifier = placeIdentifier
		
		-- debug: add tables in tables
		local function addPlrData(plrName)
			local loadout = _G.plrData[plrName].loadouts.loadout1 
			return {
				Primary = {
					name = loadout.Primary,
					attcList = loadout.customizations[loadout.Primary].attcList
				},
				Secondary = {
					name = loadout.Secondary,
					attcList = loadout.customizations[loadout.Secondary].attcList
				},
			}
		end
		data.plrData = {}
		for _, plr in ipairs(newScorps) do
			local plrName = plr.Name
			data.plrData[plrName] = addPlrData(plrName) 
		end
		for _, plr in ipairs(newSkulls) do
			local plrName = plr.Name
			data.plrData[plrName] = addPlrData(plrName)
		end
		
		-- create a match server from template
		local matchPlaceId = game:GetService("AssetService"):CreatePlaceAsync(
			placeIdentifier, placeId[placeIdentifier])
		
		local plrList = {} 		-- for group teleportation
		for _, v in ipairs(newScorps) do
			local plrName = v.Name
			if plrs:FindFirstChild(plrName) and plrs[plrName].Character then
				local plr = plrs:FindFirstChild(plrName)
				table.insert(plrList, plr)
				tpOutEvent:FireClient(plr)
			end 
		end
		for _, v in ipairs(newSkulls) do
			local plrName = v.Name
			if plrs:FindFirstChild(plrName) and plrs[plrName].Character then
				local plr = plrs:FindFirstChild(plrName)
				table.insert(plrList, plr)
				tpOutEvent:FireClient(plr)
			end
		end
		
		game:GetService("TeleportService"):TeleportPartyAsync(matchPlaceId, plrList, data)
		warn("teleported", tick() - teleportSt)
		lastTpOut[match.Name] = tick()
		sd.setProperty(Screens.Middle.MidGUI.Casual, "Text", "Pending...")
		
		matchStats.Info.SetUp.Value = false
	end
	
	-- update GUI
	Screens.Middle.MidGUI.Timer.sec.Text = matchStats.Info.Timer.Value..""
	sd.setProperty(Screens.Middle.MidGUI.Status, "Text", setStatus)
end

-- 
function LoadPlayer(plr)
	cMatch = Instance.new("ObjectValue")
	cMatch.Name = "CurrentMatch"
	cMatch.Value = nil
	cMatch.Parent = plr
end

-- voting through remote event
function Vote(plr,val)
	m = plr.CurrentMatch.Value
	if m then
		myVal = m.MatchStats.Players.Scorpions:FindFirstChild(plr.Name)
		if myVal == nil then
			myVal = m.MatchStats.Players.Skulls:FindFirstChild(plr.Name)
		end
		if myVal == nil then return end
		myVal.Value = val
	end
end

game.ReplicatedStorage.Vote.OnServerEvent:connect(Vote)

-- checking the shit every 0.01 secs
wait(3)
--local rs = game:GetService("RunService").RenderStepped
while wait(0.01) do
	-- look for those who dont have the curretMatch value attached (maybe new plrs)
	for i,v in ipairs(game.Players:GetPlayers()) do
		if v:FindFirstChild("CurrentMatch") == nil then
			LoadPlayer(v)
		end
		v.CurrentMatch.Value = nil
	end
	local suc, msg = pcall(function()
		HandleMatch(workspace.Matches.Matchmaking1)
	end)
	if not suc then warn("match1: ", msg) end
	local suc, msg = pcall(function()
		HandleMatch(workspace.Matches.Matchmaking2)
	end)
	if not suc then warn("match2: ", msg) end
	local suc, msg = pcall(function()
		HandleMatch(workspace.Matches.Matchmaking3)
	end)
	if not suc then warn("match3: ", msg) end
end