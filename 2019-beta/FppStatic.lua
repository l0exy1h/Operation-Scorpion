local rep  = game.ReplicatedStorage
local getC = game.GetChildren
local wfc  = game.WaitForChild
local ffc  = game.FindFirstChild
local plrs = game.Players
local lp   = plrs.LocalPlayer
local function requireGm(name)
	return require(wfc(wfc(rep, "GlobalModules"), name))
end

local db = requireGm("DebugSettings")()
local pv = requireGm("PublicVarsClient")
local cons = {} -- not used

local scoreboard = {}
do
	local teams   = game:GetService("Teams")
	local sg      = wfc(script, "Scoreboard")
	local alphaFr = wfc(wfc(sg, "Main"), "Alpha")
	local betaFr  = wfc(wfc(sg, "Main"), "Beta")
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

	do -- toggle
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
		local function setRoundEndGuiEnabled(bool)
			local m = ffc(wfc(lp, "PlayerGui"), "RoundEndGui")
			if m then
				m.Enabled = bool
			end
		end

		function scoreboard.show()
			if not showing then
				setRoundEndGuiEnabled(false)
				showing = true
				clearTw()
				tws[#tws + 1] = tween(blur, at, {Size = maxBlurSize})
				-- tws[#tws + 1] = tween(sg.Main, at, {Position = defPos})
				sg.Enabled = true
			end
		end
		function scoreboard.hide()
			if showing then
				setRoundEndGuiEnabled(true)
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
			local phaseValue = pv.waitForObj("Phase")
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
			local inputReader  = requireGm("InputReader")

			inputReader.listen("scoreboard.show", "Begin", "Keyboard", key, function()
				if isValidPhase() then scoreboard.show() end
			end)
			inputReader.listen("scoreboard.hide", "End", "Keyboard", key, scoreboard.hide)
		end
	end

	do-- player frame
		local playerFrameTemp  = wfc(alphaFrames, "Alive")
		playerFrameTemp.Parent = nil
		local lpFrameTemp      = wfc(alphaFrames, "MeAlive")
		lpFrameTemp.Parent     = nil

		aliveTextTrans = wfc(wfc(playerFrameTemp, "Frame"), "K").TextTransparency
		deadTextTrans  = wfc(wfc(wfc(alphaFrames, "Dead"), "Frame"), "K").TextTransparency

		local clone      = game.Clone
		local destroy    = game.Destroy
		local connect    = game.Changed.Connect
		local format     = string.format
		local getC       = game.GetChildren
		local pv         = requireGm("PublicVarsClient")
		local waitForPObj = pv.waitForPObj

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
				print("setting up K for", plr)
				local killsText = wfc(innerFr, "K")
				function self.onKillsChanged(val)
					killsText.Text = format("%d", val)
				end
				local killsValue = waitForPObj(plr, "Kills")
				self.onKillsChanged(killsValue.Value)
				cons[#cons + 1] = connect(killsValue.Changed, self.onKillsChanged)
			end

			do -- D
				print("setting up D for", plr)
				local deathsText = wfc(innerFr, "D")
				function self.onDeathsChanged(val)
					deathsText.Text = format("%d", val)
				end
				local deathsValue = waitForPObj(plr, "Deaths")
				self.onDeathsChanged(deathsValue.Value)
				cons[#cons + 1] = connect(deathsValue.Changed, self.onDeathsChanged)
			end

			do -- Score
				print("setting up Score for", plr)
				local scoreText = wfc(innerFr, "Score")
				function self.onScoreChanged(val)
					scoreText.Text = format("%d", val)
					fr.LayoutOrder = -val
				end
				local scoreValue = waitForPObj(plr, "Score")
				self.onScoreChanged(scoreValue.Value)
				cons[#cons + 1] = connect(scoreValue.Changed, self.onScoreChanged)
			end

			do -- Level
				print("setting up level for", plr)
				local levelText = wfc(innerFr, "Level")
				function self.onLevelChanged(val)
					levelText.Text = format("%d", val)
				end
				local levelValue = waitForPObj(plr, "Level")
				self.onLevelChanged(levelValue.Value)
				cons[#cons + 1] = connect(levelValue.Changed, self.onLevelChanged)
			end

			do -- Ping
				print("setting up Ping for", plr)
				local pingText = wfc(innerFr, "Ping")
				function self.onPingChanged(val)
					pingText.Text = format("%d", val * 1000)
				end
				local pingValue = waitForPObj(plr, "Ping")
				self.onPingChanged(pingValue.Value)
				cons[#cons + 1] = connect(pingValue.Changed, self.onPingChanged)
			end

			do -- alive / death
				print("setting up alive for", plr)
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
				local aliveValue = waitForPObj(plr, "isAlive")
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
				playerFrames[plr.Name] = nil
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
			local waitForObj = pv.waitForObj
			local connect = game.Changed.Connect
			for _, team in ipairs(teams:GetChildren()) do
				local teamName = team.Name
				local winsValue = waitForObj(teamName.."Wins")
				scoreboard.onTeamWinsChanged(team, winsValue.Value)
				connect(winsValue.Changed, function(val)
					scoreboard.onTeamWinsChanged(team, val)
				end)
			end
		end
	end

	do -- player added to team
		local connect = game.Changed.Connect

		function scoreboard.onPlayerAddedToTeam(team, plr)
			print("scoreboard.onPlayerAddedToTeam", team, plr)
			local plrName = plr.Name
			local playerFrame = scoreboard.waitForPlayerFrame(plr)
			if playerFrame.team ~= team then
				print("scoreboard: parenting to team fr", team, plr)
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
		spawn(function()
			local myTeam = requireGm("WaitForProperty")(lp, "Team")
			print("scoreboard, got my team", myTeam, "force onPlayerAddedToTeam")
			scoreboard.onPlayerAddedToTeam(myTeam, lp)
			print("scoreboard done my frame")
		end)
	end

	sg.Parent = wfc(lp, "PlayerGui")
	print("scoreboard initialized")
end

local teamTagSystem = {}
do-- the team tagger
	local destroy = game.Destroy
	local clone   = game.Clone

	local R       = 50
	local where   = "Head"
	local at      = 0.3
	local bgTemp  = wfc(script, "Tag")
	local alivesF = wfc(wfc(rep, "SharedVars"), "Alives")
	local tween   = requireGm("Tweening").tween

	local tags = {}
	local function newTag(plr)
		local self = {
			plr = plr
		}
		
		local bg     = clone(bgTemp)
		bg.name.Text = plr.Name
		local holder = plr.Character[where]
		bg.Parent    = holder
		local name   = bg.name
		local dot    = bg.Dot
		dot.Visible = false
		local arrows = bg.Arrows
		arrows.Visible = false

		do
			local over   = false
			local cam    = workspace.CurrentCamera
			local w2vpp  = cam.WorldToViewportPoint
			local offset = bg.StudsOffsetWorldSpace
			local newV2  = Vector2.new
			local tw     = {}
			local pvget  = pv.get
			function self.step()

				-- for hovering
				local v, onScreen = w2vpp(cam, holder.Position + offset)
				local over_
				if onScreen then
					over_ = (newV2(v.x, v.y) - cam.ViewportSize / 2).magnitude < R
				end
				if over ~= over_ then
					for i, v in ipairs(tw) do
						v:Cancel()
						tw[i] = nil
					end
					-- print(over, over_)
					over = over_
					if over then
						tw[#tw + 1] = tween(dot, at, {ImageTransparency = 1})
						tw[#tw + 1] = tween(arrows, at, {ImageTransparency = 1})
						tw[#tw + 1] = tween(name, at, {TextTransparency = 0})
					else
						tw[#tw + 1] = tween(dot, at, {ImageTransparency = 0})
						tw[#tw + 1] = tween(arrows, at, {ImageTransparency = 0})
						tw[#tw + 1] = tween(name, at, {TextTransparency = 1})
					end
				end

				-- for bomber
				local isBomber = pvget("Bomber") == plr
				arrows.Visible = isBomber
				dot.Visible    = not isBomber
			end
		end

		do
			local ido = game.IsDescendantOf
			function self.isInChar()
				return bg and bg.Parent and bg.Parent.Parent 
					and plr and plr.Character and ido(bg, plr.Character)
			end
		end

		function self.destroy()
			-- print("destroy", plr, "'s tag")
			destroy(bg)
		end

		-- for fpsgui visibility
		function self.setEnabled(bool)
			bg.Enabled = bool
		end

		return self
	end

	local function shouldPutTag(plr)
		return plr.Character 
			and ffc(plr.Character, where) 
			and ffc(alivesF, plr.Name)
			and lp.Team == plr.Team
			and lp ~= plr
	end

	-- loop every player to add / delete tags
	spawn(function()
		local clockrate = 2
		while wait(clockrate) do
			for _, plr in ipairs(getC(plrs)) do
				local tag_ = shouldPutTag(plr)
				local tag  = tags[plr.Name]
				if tag_ and (not tag or not tag.isInChar()) then
					-- print("creating new tag for", plr)
					tags[plr.Name] = newTag(plr)
				end
			end
		end
	end)

	function teamTagSystem.step()
		for _, tag in pairs(tags) do
			tag.step()
			local plr = tag.plr
			local tag_ = shouldPutTag(plr)
			if not tag_ then
				-- print("destroying tag for", plr)
				tag.destroy()
				tags[plr.Name] = nil
			end
		end
	end

	function teamTagSystem.setEnabled(bool)
		for _, tag in pairs(tags) do
			tag.setEnabled(bool)
		end
	end

	-- -- the step function
	-- spawn(function()
	-- 	local hb = game:GetService("RunService").Heartbeat
	-- 	local evwait = game.Changed.Wait
	-- 	while evwait(hb) do
	-- 	end
	-- end)
end

do-- hide top bar
	local suc, msg = pcall(function()
		game:GetService('StarterGui'):SetCore("TopbarEnabled", false)
	end)
	if suc then
		print("hide top bar")
	else
		print("failed to hide top bar", msg)
	end
end

local fpsGui = {}
do -- fpsgui
	local sg
	local staticFr
	local dynamicFr
	local guiStash
	do-- put sg into playergui
		local sgTemp = wfc(wfc(wfc(game:GetService("StarterPlayer"), "StarterPlayerScripts"), "Fpp"), "FpsGui")
		guiStash = wfc(sgTemp, "Stash")

		sg = sgTemp:Clone()
		fpsGui.sg = sg
		wfc(sg, "Stash"):Destroy()
		sg.Parent = wfc(lp, "PlayerGui")
		staticFr  = wfc(sg, "Static")
		dynamicFr = wfc(sg, "Dynamic")
	end

	-- insertCompassItemOnBombAdded
	-- insertBillBoardGuiOnBombAdded

	local compass = {}
	fpsGui.compass = compass
	do
		local transThreshold = 0.2
		
		local cam     = workspace.CurrentCamera
		local myMath  = requireGm("Math")
		local mod     = myMath.mod
		local isA     = game.isA
		local v3ToCyl = myMath.v3ToCyl
		local destroy = game.Destroy
		local clone   = game.Clone
		local newU2   = UDim2.new
		local pwd = game.GetFullName

		local compassGui  = wfc(guiStash, "Compass")
		compass.fr = compassGui
		local onLine      = wfc(compassGui, "OnLine")
		local itemsLib    = wfc(compassGui, "CompassItems")

		-- fuck transparency lets use opacity
		local function posToOpa(x) -- pos[0, 1] ==> opa[0, 1]
			if x < transThreshold then
				return x / transThreshold
			elseif x > 1.0 - transThreshold then
				return (1 - x) / transThreshold
			else
				return 1
			end
		end

		-- looky = 0		-- wip
		local function getOnLineStates(item, lo, hi)
			local wp = item.wp
			if typeof(wp) == "Instance" then
				wp = wp.Position
			end
			if typeof(wp) == "Vector3" then
				local P = cam.CFrame.p
				wp = v3ToCyl(wp - P)
			end
			if typeof(wp) == "number" then
				lo = mod(lo, 360)
				hi = mod(hi, 360)
				wp = mod(wp, 360)
				if hi < lo then
					hi = hi + 360
				end
				if wp < lo then 
					wp = wp + 360
				end
				local x = 1 - (wp - lo) / (hi - lo) 
				local o = posToOpa(x)
				return x, o
			else
				error("logic error typeof(wp) = "..typeof(wp))
			end
		end

		-- the items on the line
		local items = {}

		function compass.add(name, gui, wp, opacityAdjuster) 	-- wp stands for world coordinates, can be a {vector3, looky, or a pvinstance}
			-- assert(isA(wp) == "BasePart" or warn(wp and pwd(wp), "is not a basepart"))
			if items[name] then
				destroy(items[name].gui)
				-- warn("compass.add", name, "already exists. now deleted.")
			end
			gui = clone(gui)
			items[name] = {
				name = name,
				gui = gui,
				wp  = wp,
				opacityAdjuster  = opacityAdjuster,  	-- a func or a num (opacity mult)
			}
			opacityAdjuster(gui, 0)	-- hide by default
			gui.Parent = onLine
		end

		function compass.delete(name)
			if items[name] then
				destroy(items[name].gui)
				items[name] = nil
			else
				warn("compass.delete", name, "does not exist. nothing is changed.")
			end
		end

		-- local fov = 75
		function compass.step(dt, now)
			local fov = cam.FieldOfView
			local y = v3ToCyl(cam.CFrame.lookVector)
			local lo = y - fov / 2
			local hi = y + fov / 2
			for name, item in pairs(items) do
				local x, opacity = getOnLineStates(item, lo, hi)
				item.gui.Position = newU2(x, 0, 0.5, 0)

				-- check if part exists
				local wp = item.wp
				if wp == nil or (typeof(wp) == "Instance" and (wp.Parent == nil or wp.Parent.Parent == nil)) then
					warn("compass item", name, "'s part does not exist, deleting the compass item now")
					compass.delete(name)
				else

					-- adjust the opacity
					local suc, msg = pcall(function()
						item.opacityAdjuster(item.gui, opacity)
					end)
					if not suc then
						warn("compass item", name, "opacityAdjuster throws an exception", msg, ".deleted that item from compass")
						compass.delete(name)
					end
				end
			end
		end

		do -- init
			compassGui.Parent = dynamicFr

			-- load default compass item
			local b1 = 1- itemsLib.N.Text.TextTransparency
			local NWSEOpacityAdjuster = function(g, o)
				g.Text.TextTransparency = 1 - b1 * o
			end
			compass.add("N", itemsLib.N, 0, NWSEOpacityAdjuster)
			compass.add("W", itemsLib.W, 90, NWSEOpacityAdjuster)
			compass.add("S", itemsLib.S, 180, NWSEOpacityAdjuster)
			compass.add("E", itemsLib.E, 270, NWSEOpacityAdjuster)

			local b2 = 1 - itemsLib.NE.Text.TextTransparency
			local another4OpacityAdjuster = function(g, o)
				g.Text.TextTransparency = 1 - b2 * o
			end
			compass.add("NW", itemsLib.NW, 45, another4OpacityAdjuster)
			compass.add("SW", itemsLib.SW, 135, another4OpacityAdjuster)
			compass.add("SE", itemsLib.SE, 225, another4OpacityAdjuster)
			compass.add("NE", itemsLib.NE, 315, another4OpacityAdjuster)

			local b3 = (1 - itemsLib.Dot.Dot.BackgroundTransparency)
			local dotsOpacityAdjuster = function(g, o)
				g.Dot.BackgroundTransparency = 1 - b3 * o
			end
			for i = 1, 16, 1 do
				local y = (i - 1) * 22.5 + 22.5/2
				compass.add(string.format("%.2f", y), itemsLib.Dot, y, dotsOpacityAdjuster)
			end

			--name, gui, wp, opacityAdjuster
			local compassBe = wfc(wfc(rep, "Events"), "CompassBe")
			compassBe.Event:Connect(compass.add)
		end
	end

	local objectives = {}
	fpsGui.objectives = objectives
	do
		local newU2 = UDim2.new
		local tween = requireGm("Tweening").tween
		local setStProp = requireGm("ShadedTexts").setStProp
		local setStText = requireGm("ShadedTexts").setStText
		local cam = workspace.CurrentCamera
		local play = requireGm("AudioSystem").play
		local function sx()
			return cam.ViewportSize.X
		end
		local function sy()
			return cam.ViewportSize.Y
		end

		local queue = {}
		local l = 1
		local r = 0
		local Q = 20 	-- max msg size
		if Q < 20 then
			print("fppgui.objectives.Qsize =", Q)
		end

		local objectivesGui = wfc(guiStash, "Objectives")
		objectives.fr = objectives

		local botSmall = {}
		do
			local movingUpTime = 0.8
			local stayingTime  = 5
			local fadingTime   = 1
			local totalTime = movingUpTime + stayingTime + fadingTime
			local movingUpU2 = newU2(0, 0, -0.08, 0)

			local fr = wfc(objectivesGui, "BotSmall")
			do
				setStProp(fr, "Transparency", 1)
				setStText(fr, "initializing")
			end
			local defPos = fr.Position
			local toUpper = string.upper
			local function processStr(str)
				return toUpper(str)
			end

			function botSmall.animateAsync(str, time)
				local scaler = time / totalTime

				-- init animation
				fr.Position = defPos
				setStProp(fr, "Transparency", 1)
				setStText(fr, processStr(str))

				-- moving up
				tween(fr.text, movingUpTime * scaler, {TextTransparency = 0})
				tween(fr.shade, movingUpTime * scaler, {TextTransparency = 0})
				tween(fr, movingUpTime * scaler, {Position = defPos + movingUpU2})

				-- fading out
				delay(scaler * (movingUpTime + stayingTime), function()
					tween(fr.text, scaler * fadingTime, {TextTransparency = 1})
					tween(fr.shade, scaler * fadingTime, {TextTransparency = 1})
				end)
			end
		end

		local botBig = {}
		do
			local movingUpTime = 1
			local stayingTime  = 5
			local fadingTime   = 1
			local totalTime = movingUpTime + stayingTime + fadingTime

			local barSpacing   = 0.03
			local movingUpU2 = newU2(0, 0, -0.08, 0)

			local fr = wfc(objectivesGui, "BotBig")
			local leftBar = wfc(fr, "LeftBar")
			local rightBar = wfc(fr, "RightBar")
			local defPos = fr.Position
			do
				setStProp(fr, "TextTransparency", 1)
				leftBar.Transparency = 1
				rightBar.Transparency = 1
				setStText(fr, "Loading")
			end

			local toUpper = string.upper
			local sub = string.sub
			local function processStr(str)
				local ret = ""
				str = toUpper(str)
				for i = 1, #str do
					local c = sub(str, i, i)
					ret = ret..c.." "
				end
				ret = str
				return ret
			end

			function botBig.animateAsync(str, time)
				local scaler = time / totalTime

				-- init animation
				fr.Position = defPos
				setStProp(fr, "TextTransparency", 1)
				leftBar.Transparency = 1
				rightBar.Transparency = 1
				setStText(fr, processStr(str))
				local x = fr.text.TextBounds.X
				local o = barSpacing + x / 2 / sx()
				leftBar.Position = newU2(0.5 - o, 0, 0.5, 0)
				rightBar.Position = newU2(0.5 + o, 0, 0.5, 0)

				-- moving up
				tween(fr.text, movingUpTime * scaler, {TextTransparency = 0})
				tween(fr.shade, movingUpTime * scaler, {TextTransparency = 0})
				tween(leftBar, movingUpTime * scaler, {Transparency = 0})
				tween(rightBar, movingUpTime * scaler, {Transparency = 0})
				tween(fr, movingUpTime * scaler, {Position = defPos + movingUpU2})

				-- fading out
				delay((movingUpTime + stayingTime) * scaler, function()
					tween(fr.text, movingUpTime* scaler, {TextTransparency = 1})
					tween(fr.shade, movingUpTime* scaler, {TextTransparency = 1})
					tween(leftBar, movingUpTime* scaler, {Transparency = 1})
					tween(rightBar, movingUpTime* scaler, {Transparency = 1})
				end)
			end
		end

		local top = {}
		do
			local timerMovingTime = 0.2
			local textFadingTime = 0.3
			local totalTime = timerMovingTime + textFadingTime 

			local myMath  = requireGm("Math")
			local connect = game.Changed.Connect
			local floor   = math.floor
			local mod     = myMath.mod
			local format  = string.format

			local fr           = wfc(objectivesGui, "Top")
			local text         = wfc(wfc(fr, "Texts"), "text")
			local timerFr      = wfc(fr, "Timer")
			local timerText    = wfc(timerFr, 'Frame')
			local defTextTrans = text.TextTransparency
			do
				text.TextTransparency = 1
				timerFr.Position = newU2(0.5, 0, 0, 0)
			end
			local spacing = 20 -- between the text and the timer
			-- local c -- the default percentage length of timer
			local toUpper = string.upper
			local function processText(str)
				return toUpper(str)
			end

			function top.hideText(time)
				local scaler = time / totalTime
				tween(text, textFadingTime, {TextTransparency = 1})
				delay(textFadingTime, function()
					tween(timerFr, timerMovingTime * scaler, {Position = newU2(0.5, 0, 0, 0)})
				end)
			end
			function top.showText(str, time)
				local scaler = time / totalTime

				text.Text = processText(str)
				local l = text.TextBounds.X
				local c = timerFr.AbsoluteSize.X
				local textX = 0.5 + (l + c + spacing) / (2 * sx())
				local timerX = 1 - textX + c / timerFr.Parent.AbsoluteSize.X / 2

				fr.Texts.Position = newU2(textX, 0, 0, 0)
				tween(timerFr, timerMovingTime * scaler, {Position = newU2(timerX, 0, 0, 0)})
				delay(timerMovingTime * scaler, function()
					tween(text, textFadingTime, {TextTransparency = defTextTrans})
				end)
			end
			function top.setTimer(time)
				local minutes = floor(time / 60)
				local seconds = mod(time, 60)
				setStText(timerText, format("%02d:%02d", minutes, seconds))
			end
			cons[#cons + 1] = connect(pv.waitForObj("MatchTimer").Changed, top.setTimer)
		end

		local adders = {
			levelup = function(newLevel)
				assert(newLevel)
				local t = {
					completed = false,
					started = false,
				}
				t.run = function()
					t.started = true
					-- 5 secs					
					botSmall.animateAsync("level up", 4)
					botBig.animateAsync("level "..newLevel, 4)
					play("LevelUp", "2D")
					delay(4, function()
						t.completed = true
					end)
				end
				return t
			end;
			newobj = function(objStr)
				assert(objStr)
				local t = {
					completed = false,
					started = false,
				}
				function t.run()
					t.started = true
					-- 0.5 secs
					top.hideText(0.5)
					delay(0.5, function()
						-- 2 secs
						botSmall.animateAsync("new objective", 6)
						botBig.animateAsync(objStr, 6)
						play("NewObjective", "2D")
						delay(6, function()
							-- 0.5 secs
							top.showText(objStr, 1.5)
							delay(1.5, function()
								t.completed = true
							end)
						end)
					end)
				end
				return t
			end
		}
		function objectives.add(type, ...)
			local adder = adders[type]
			assert(adder, string.format("invalid type", type))
			if r == 0 then
				r = 1
			elseif r == Q then
				r = 1
			else
				r = r + 1
			end
			queue[r] = adder(...)
		end
		function objectives.step(dt)
			local q = queue[l]
			if q then
				if q.completed then
					l = l + 1
					q = queue[l]
				end
				if q and not q.started then
					assert(not q.completed)
					q.run()
					print("running", l)
				end
			end
		end
		
		do -- init
			objectivesGui.Parent = dynamicFr
			local be = wfc(wfc(rep, "Events"), "ObjectivesBe")
			be.Event:Connect(objectives.add)
			-- fpsClient.listen("level.up", function(newLevel)
			-- 	("levelup", newLevel)
			-- end)
			-- debug
			-- for i = 1, 10, 1 do
			-- 	objectives.add("levelup", i)
			-- end
			-- objectives.add("newobj", "test vaulting and sprinting")
		end
	end

	-- invade
	local bombsitesGui = {}
	fpsGui.bombsitesGui = bombsitesGui
	do
		local mr        = wfc(rep, "MatchResources")
		local setStText = requireGm("ShadedTexts").setStText
		local myMath    = requireGm("Math")

		local bombsites = workspace.Bombsites:GetChildren()

		local siteMarkers = {}

		do -- bombsitesGui.init()
			do -- put billboard gui into bomb sites
				local billboardGuiTemp = wfc(mr, "BombsiteBillboardGui")
				local floor   = math.floor
				local destroy = game.Destroy
				local hb      = game:GetService("RunService").Heartbeat
				local clone   = game.Clone

				local function newSiteMarker(site)
					-- put into bomb sites
					local gui = clone(billboardGuiTemp)
					gui.Name  = "SiteMarker"
					setStText(gui.Rot, site.Name)
					gui.Parent = site

					-- return an adjuster
					local t; t = {
						gui = gui,
						site = site,
						destroy = function()
							destroy(gui)
						end;
						setDistance = function(dist)
							setStText(gui.Dist, tostring(floor(dist)))
						end;
						hide = function()
							gui.Enabled = false
						end;
						show = function()
							gui.Enabled = true
						end;
						flash = function()
							t.flashing = true
							spawn(function()
								local evwait          = game.Changed.Wait
								local curve           = myMath.getOscillatingSine(0.5, 0, 255)
								local st              = tick()
								local newColor3       = Color3.fromRGB
								local text            = gui.Rot.text
								local border          = gui.Rot.Box
								local defTextColor3   = text.TextColor3
								local defBorderColor3 = border.ImageColor3
								while evwait(hb) do
									-- if t.stayAtRed then
									-- 	text.TextColor3 = newColor3(255, 0, 0)
									-- 	border.ImageColor3 = newColor3(255, 0, 0)						
									if t.flashing then
										local color3 = newColor3(curve(tick() - st), 0, 0)
										text.TextColor3 = color3
										border.ImageColor3 = color3
									else -- restore
										text.TextColor3 = defTextColor3
										border.ImageColor3 = defBorderColor3
										break
									end
								end
							end)
						end;
						restore = function()
							t.flashing = false
						end;
					}
					return t
				end
				for _, site in ipairs(bombsites) do
					local siteName = site.Name
					if siteMarkers[siteName] then
						siteMarkers[siteName].destroy()
					end
					siteMarkers[siteName] = newSiteMarker(site)
				end
			end
			do-- planted -> billboardgui flash red
				cons[#cons + 1] = pv.waitForObj("Planted").Changed:Connect(function(plantedSite)
					for _, site in ipairs(bombsites) do
						local siteName = site.Name
						local siteMarker = siteMarkers[siteName]
						if siteMarker then
							siteMarker[plantedSite == site 
								and "flash" 
								or plantedSite ~= nil 
									and "hide"
									or "restore"]()
						else
							warn("weird, planted but site marker for", site, "is not found")
						end
					end
				end)
			end
			do-- put the bombsite compass gui into compass
				local bombsiteCompassGuiTemp = wfc(mr, "SiteCompass")
				local clone                  = game.Clone
				local addToCompass           = compass.add
				for _, site in ipairs(bombsites) do
					local compassGui = clone(bombsiteCompassGuiTemp)
					compassGui.Site.Text = site.Name
					addToCompass("site "..site.Name, compassGui, site, function(g, o)
						g.Diamond.BackgroundTransparency = 1 - 0.7 * o
						g.Site.TextTransparency = 1 - 0.8 * o
					end)
				end
			end
		end

		function bombsitesGui.setEnabled(bool)
			for _, siteMarker in pairs(siteMarkers) do
				siteMarker[bool and "show" or "hide"]()
			end
		end

		local cam = workspace.CurrentCamera
		function bombsitesGui.step(dt, now)
			do-- camera position -> distance to site -> show on sitemarker
				for _, siteMarker in pairs(siteMarkers) do
					siteMarker.setDistance((cam.CFrame.p - siteMarker.site.Position).magnitude)
				end
			end
		end
		-- function bombsitesGui.onDeath()
			-- for _, siteMarker in pairs(siteMarkers) do
			-- 	siteMarker.destroy()
			-- end
		-- end/
	end

	local bombGui = {}
	fpsGui.bombGui = bombGui
	do
		local bombBillboardGui

		local mr = wfc(rep, "MatchResources")
	
		do -- bomb spawn or plr quickjoin -> add bomb compass gui & billboardgui
			local clone              = game.Clone
			local bombCompassGuiTemp = wfc(mr, "BombCompass")
			local addToCompass       = compass.add
			function bombGui.insertCompassItemOnBombAdded(bomb)
				if bomb and lp.Team == pv.waitFor("Atk") then
					local bombCompassGui = clone(bombCompassGuiTemp)
					addToCompass("bomb", bombCompassGui, bomb.PrimaryPart, function(g, o)
						g.Diamond.BackgroundTransparency = 1 - 0.7 * o
						g.Bomb.TextTransparency = 1 - 0.8 * o
					end)
				end
			end
		end

		do-- always on top for atk
			-- not for defender
			local bombBillboardGuiTemp = wfc(mr, "BombBillboardGui")

			local myMath = requireGm("Math")
			local newU2  = UDim2.new
			local clone  = game.Clone

			function bombGui.insertBillBoardGuiOnBombAdded(bomb)
				if bomb then
					if bombBillboardGui and bombBillboardGui.Parent then
						bombBillboardGui:Destroy()
					end

					bombBillboardGui = clone(bombBillboardGuiTemp)
					bombBillboardGui.AlwaysOnTop = pv.waitFor("Atk") == lp.Team
					bombBillboardGui.Parent = bomb.PrimaryPart

					-- start animating
					local singleBouncingCurve = myMath.getBouncingPara(1/2, 3/4, 1)
					local lerp                = myMath.lerp
					local animatingArrows     = bombBillboardGui.Arrows
					local defPos              = animatingArrows.Position
					local defY                = defPos.Y.Scale
					local newU2               = UDim2.new
					local mod                 = myMath.mod
					local function getPosOffset(x)
						return newU2(0, 0, -lerp(0, 0.15, singleBouncingCurve(mod(x, 1))), 0)
					end							
					spawn(function()
						local hb     = game:GetService("RunService").Heartbeat
						local evwait = game.Changed.Wait
						local st     = tick()
						while evwait(hb) and bomb and bomb.Parent do
							animatingArrows.Position = defPos + getPosOffset(tick() - st)
						end
					end)
				end
			end

			-- for quick join
			local bomb = pv.get("Bomb")
			bombGui.insertCompassItemOnBombAdded(bomb)
			bombGui.insertBillBoardGuiOnBombAdded(bomb)

			-- listenrs
			cons[#cons + 1] = pv.waitForObj("Bomb").Changed:Connect(bombGui.insertCompassItemOnBombAdded)
			cons[#cons + 1] = pv.waitForObj("Bomb").Changed:Connect(bombGui.insertBillBoardGuiOnBombAdded)
		end

		function bombGui.setEnabled(bool)
			if bombBillboardGui then
				bombBillboardGui.Enabled = bool
			end
		end
	end
end

-- hbstep
spawn(function()
	local steps = {
		fpsGui.compass.step,
		fpsGui.objectives.step,
		fpsGui.bombsitesGui.step,
		teamTagSystem.step,
	}
	local lastTick = tick()
	local evwait = game.Changed.Wait
	local hb = game:GetService("RunService").Heartbeat
	while evwait(hb) do
		local now = tick()
		local dt  = now - lastTick
		for _, step in ipairs(steps) do
			local suc, msg = pcall(function()
				step(dt)
			end)
			if not suc then
				warn(msg)
			end
		end
		lastTick = now
	end
end)

-- do -- 
-- 	local be = wfc(wfc(rep, "Events"), "FpsGuiVisibilityBe")
-- 	be.Event:Connect(function(bool)
-- 	end)
-- end

do -- disable fpp gui in certain phases
	local function setFpsGuiEnabled(bool)
		if db.testingCharacters then
			bool = true
		end
		-- fpsGui.compass.fr.Visible = bool
		-- fpsGui.objectives.fr.Visibie = bool
		fpsGui.sg.Enabled = bool
		fpsGui.bombsitesGui.setEnabled(bool)
		fpsGui.bombGui.setEnabled(bool)
		teamTagSystem.setEnabled(bool)
	end
	local function onPhaseChanged(phase)
		local strAfterColon = string.sub(phase, 7)
		if strAfterColon ~= "Defuse" and strAfterColon ~= "Boom" then -- dont show all the sites when defuse state is entered
			setFpsGuiEnabled(string.sub(phase, 1, 5) == "Match" and strAfterColon ~= "Intermission")
		end
	end
	local phase = pv.waitForObj("Phase")
	onPhaseChanged(phase.Value)
	phase.Changed:Connect(onPhaseChanged)
end