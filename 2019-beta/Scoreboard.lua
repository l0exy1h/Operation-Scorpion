local rep   = game.ReplicatedStorage
local wfc   = game.WaitForChild
local ffc   = game.FindFirstChild
local gm    = wfc(rep, "GlobalModules")
local plrs  = game.Players
local lp    = plrs.LocalPlayer
local teams = game:GetService("Teams")
local function requireGm(name)
	return require(wfc(gm, name))
end

local scoreboard = {}

local sg         = wfc(script, "Scoreboard")
local alphaFr    = wfc(wfc(sg, "Main"), "Alpha")
local betaFr     = wfc(wfc(sg, "Main"), "Beta")
local innerFrames = {
	Alpha = wfc(alphaFr, "ImageLabel"),
	Beta  = wfc(betaFr, "ImageLabel"),
}
local teamFrames = {
	Alpha = wfc(innerFrames.Alpha, "Players"),
	Beta  = wfc(innerFrames.Beta, "Players"),
}
local alphaFrames  = teamFrames.Alpha
local betaFrames   = teamFrames.Beta
local playerFrames = {}

-- toggle
do
	local showing = false

	local blur        = wfc(game:GetService("Lighting"), "BlurScoreboard")
	local maxBlurSize = blur.Size
	blur.Size         = 0
	blur.Enabled      = true
	local at          = 0.1
	local tws         = {}
	local function clearTw()
		for i, tw in ipairs(tws) do
			tw:Cancel()
			tws[i] = nil
		end
	end

	local defPos = sg.Main.Position
	local hidePos = defPos + UDim2.new(0, 0, 0.6, 0)

	local tween = requireGm("Tweening").tween
	local pv = requireGm("PublicVarsClient")

	-- temp
	-- should have a visibility control function in the mainframelocalhelper
	local function setMainframeGuiEnabled(bool)
		local m = ffc(wfc(lp, "PlayerGui"), "MainframeGui")
		if m then
			m.Enabled = bool
		end
	end

	function scoreboard.show()
		if not showing then
			setMainframeGuiEnabled(false)
			showing = true
			clearTw()
			tws[#tws + 1] = tween(blur, at, {Size = maxBlurSize})
			-- tws[#tws + 1] = tween(sg.Main, at, {Position = defPos})
			sg.Enabled = true
		end
	end
	function scoreboard.hide()
		if showing then
			setMainframeGuiEnabled(true)
			showing = false
			clearTw()
			tws[#tws + 1] = tween(blur, at, {Size = 0})
			-- tws[#tws + 1] = tween(sg.Main, at, {Position = hidePos})
			sg.Enabled = false
		end
	end
	showing = true
	scoreboard.hide()

	do-- gui should only show up in certain phase
		local phaseValue = pv.getPublicVarObjWait("Phase")
		local sub = string.sub
		function scoreboard.isValidPhase()
			local phase = phaseValue.Value
			return sub(phase, 1, 5) == "Match" or phase == "Showtime"
		end
		phaseValue.Changed:Connect(function()
			if showing and not scoreboard.isValidPhase() then
				scoreboard.hide()
			end
		end)
	end

	do -- connect
		local key          = requireGm("Keybindings").toggleScoreboard
		assert(key)
		local uis          = game:GetService("UserInputService")	
		local itKeyboard   = Enum.UserInputType.Keyboard
		local connect      = game.Changed.Connect
		local isValidPhase = scoreboard.isValidPhase

		connect(uis.InputBegan, function(input, g)
			if g then return end 
			if input.UserInputType == itKeyboard then
				if input.KeyCode == key and isValidPhase() then
					scoreboard.show()
				end
			end
		end)
		connect(uis.InputEnded, function(input, g)
			if g then return end 
			if input.UserInputType == itKeyboard then
				if input.KeyCode == key then
					scoreboard.hide()
				end
			end
		end)
	end
end


do-- player frame
	local playerFrameTemp  = wfc(alphaFrames, "Alive")
	playerFrameTemp.Parent = nil
	local lpFrameTemp      = wfc(alphaFrames, "MeAlive")
	lpFrameTemp.Parent     = nil

	aliveTextTrans = wfc(wfc(playerFrameTemp, "Frame"), "K").TextTransparency
	deadTextTrans  = wfc(wfc(wfc(alphaFrames, "Dead"), "Frame"), "K").TextTransparency

	local clone   = game.Clone
	local destroy = game.Destroy
	local connect = game.Changed.Connect
	local format  = string.format
	local getC    = game.GetChildren
	local pv      = requireGm("PublicVarsClient")
	local getPublicPlrVarObjWait = pv.getPublicPlrVarObjWait

	local function clearFrames(frames)
		for _, v in ipairs(frames:GetChildren()) do
			if v.Name ~= "Title" and v.Name ~= "UIGridLayout" then
				destroy(v)
			end
		end
	end
	clearFrames(alphaFrames)
	clearFrames(betaFrames)

	function scoreboard.onPlayerAdded(plr)
		local self = {}
		local cons = {}
		local plrName = plr.Name
		print("score board: creating frame for", plrName)

		local fr = clone((plr == lp) and lpFrameTemp or playerFrameTemp)
		self.fr = fr
		fr.Name = plrName
		local innerFr = wfc(fr, "Frame")

		do-- playername
			wfc(innerFr, "Player").Text = plrName
		end

		do -- K
			-- print("setting up K")
			local killsText = wfc(innerFr, "K")
			function self.onKillsChanged(val)
				killsText.Text = format("%d", val)
			end
			local killsValue = getPublicPlrVarObjWait(plr, "Kills")
			self.onKillsChanged(killsValue.Value)
			cons[#cons + 1] = connect(killsValue.Changed, self.onKillsChanged)
		end

		do -- D
			-- print("setting up D")
			local deathsText = wfc(innerFr, "D")
			function self.onDeathsChanged(val)
				deathsText.Text = format("%d", val)
			end
			local deathsValue = getPublicPlrVarObjWait(plr, "Deaths")
			self.onDeathsChanged(deathsValue.Value)
			cons[#cons + 1] = connect(deathsValue.Changed, self.onDeathsChanged)
		end

		do -- Score
			-- print("setting up Score")
			local scoreText = wfc(innerFr, "Score")
			function self.onScoreChanged(val)
				scoreText.Text = format("%d", val)
				fr.LayoutOrder = -val
			end
			local scoreValue = getPublicPlrVarObjWait(plr, "Score")
			self.onScoreChanged(scoreValue.Value)
			cons[#cons + 1] = connect(scoreValue.Changed, self.onScoreChanged)
		end

		do -- Level
			-- print("setting up level")
			local levelText = wfc(innerFr, "Level")
			function self.onLevelChanged(val)
				levelText.Text = format("%d", val)
			end
			local levelValue = getPublicPlrVarObjWait(plr, "Level")
			self.onLevelChanged(levelValue.Value)
			cons[#cons + 1] = connect(levelValue.Changed, self.onLevelChanged)
		end

		do -- Ping
			-- print("setting up Ping")
			local pingText = wfc(innerFr, "Ping")
			function self.onPingChanged(val)
				pingText.Text = format("%d", val * 1000)
			end
			local pingValue = getPublicPlrVarObjWait(plr, "Ping")
			self.onPingChanged(pingValue.Value)
			cons[#cons + 1] = connect(pingValue.Changed, self.onPingChanged)
		end

		do -- alive / death
			-- print("setting up alive")
			local texts = {}
			for _, v in ipairs(getC(innerFr)) do
				if v.Name ~= "UIListLayout" then
					texts[#texts + 1] = v
				end
			end
			-- print("alive1")
			function self.onAliveChanged(val)
				for _, v in ipairs(texts) do
					v.TextTransparency = val and aliveTextTrans or deadTextTrans
				end
			end
			local aliveValue = getPublicPlrVarObjWait(plr, "Alive")
			-- print("alive2")
			self.onAliveChanged(aliveValue.Value)
			-- print("alive3")
			cons[#cons + 1] = connect(aliveValue.Changed, self.onAliveChanged)
			-- print("alive4")
		end

		function self.destroy()
			for _, con in ipairs(cons) do
				con:Disconnect()
			end
			destroy(fr)
		end

		playerFrames[plrName] = self
		print("scoreboard: created frame for", plrName)
	end
	function scoreboard.onPlayerRemoving(plr)
		if playerFrames[plr.Name] then
			playerFrames[plr.Name].destroy()
		end
	end
	function scoreboard.waitForPlayerFrame(plr)
		local plrName = plr.Name
		if not playerFrames[plrName] then
			local st = tick()
			local warned = false
			repeat 
				wait(0.1)
				if tick() - st > 5 and not warned then
					warned = true
					warn("waiting for", plr, "'s frame for more than 5 seconds")
				end
			until playerFrames[plrName]
			if warned then
				warn(plr, "'s frame is finally created:")
			end
		end
		return playerFrames[plrName]
	end

	for _, plr in ipairs(plrs:GetPlayers()) do
		spawn(function()
			scoreboard.onPlayerAdded(plr)
		end)
	end
	connect(plrs.PlayerAdded, scoreboard.onPlayerAdded)
	connect(plrs.PlayerRemoving, scoreboard.onPlayerRemoving)
end


do-- the left side is always your team
	function scoreboard.onMyTeamChanged(myTeam)
		if myTeam == teams.Alpha then
			alphaFr.LayoutOrder = 0
			betaFr.LayoutOrder = 1
		elseif myTeam == teams.Beta then
			alphaFr.LayoutOrder = 1
			betaFr.LayoutOrder = 0
		else
			warn("my team changed to neither alpha nor beta", myTeam, "aborted")
		end
	end
end

do-- team wins
	do
		local winsTexts = {
			Alpha = wfc(innerFrames.Alpha, "Wins"),
			Beta  = wfc(innerFrames.Beta, "Wins"),
		}

		local format = string.format
		local function formatter(wins)
			return format("W: %d/6", wins)
		end

		function scoreboard.onTeamWinsChanged(team, wins)
			winsTexts[team.Name].Text = formatter(wins)
		end
	end

	do -- connect
		local pv = requireGm("PublicVarsClient")
		local getPublicVarObjWait = pv.getPublicVarObjWait
		local connect = game.Changed.Connect
		for _, team in ipairs(teams:GetChildren()) do
			local teamName = team.Name
			local winsValue = getPublicVarObjWait(teamName.."Wins")
			scoreboard.onTeamWinsChanged(team, winsValue.Value)
			connect(winsValue.Changed, function(val)
				scoreboard.onTeamWinsChanged(team, val)
			end)
		end
	end
end

do -- player added to team
	local connect    = game.Changed.Connect

	function scoreboard.onPlayerAddedToTeam(team, plr)
		local plrName = plr.Name
		local playerFrame = scoreboard.waitForPlayerFrame(plr)
		if playerFrame.team ~= team then
			playerFrame.fr.Parent = teamFrames[team.Name]
			playerFrame.team = team
		end

		if plr == lp then
			scoreboard.onMyTeamChanged(team)
		end
	end
	function scoreboard.onPlayerRemovedFromTeam(team, plr)
		local plrName = plr.Name
		local playerFrame = playerFrames[plrName]
		if playerFrame then
			if playerFrame.team == team then
				playerFrame.fr.Parent = nil
				playerFrame.team = nil
			end
		end
	end

	for _, team in ipairs(teams:GetChildren()) do
		for _, plr in ipairs(team:GetPlayers()) do
			scoreboard.onPlayerAddedToTeam(team, plr)
		end

		connect(team.PlayerAdded, function(plr)
			scoreboard.onPlayerAddedToTeam(team, plr)
		end)
		connect(team.PlayerRemoved, function(plr)
			scoreboard.onPlayerRemovedFromTeam(team, plr)
		end)		
	end
end

sg.Parent = wfc(lp, "PlayerGui")
print("scoreboard initialized")