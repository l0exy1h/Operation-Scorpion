local wfc   = game.WaitForChild
local plrs  = game.Players
local lp    = plrs.LocalPlayer
local clone = game.Clone

local rep = game.ReplicatedStorage
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local pv = requireGm("PublicVarsClient")
local mainframeClient = requireGm("Network").loadRe(wfc(wfc(rep, "Events"), "MainframeRe"), false)
local db = requireGm("DebugSettings")()

local playerGui     = wfc(lp, "PlayerGui")
local printTable    = requireGm("TableUtils").printTable

local preMatchHandler = {}
do
	local heli    = wfc(workspace, "Helicopter")

	local destroy = game.Destroy
	local connect = game.Changed.Connect
	local evwait  = game.Changed.Wait
	local ffc     = game.FindFirstChild
	local getC    = game.GetChildren
	local myMath   = requireGm("Math")
	local audioSys = requireGm("AudioSystem")

	local cons    = {}
	local running = true

	local tween   = requireGm("Tweening").tween

	-- @todo let team list work on gun mastery???
	local heliGui = {}
	do
		local teams     = game.Teams
		local setStText = requireGm("ShadedTexts").setStText
		local screens = {
			left  = wfc(wfc(heli, "ScreenMidL"), "SurfaceGui"),
			right = wfc(wfc(heli, "ScreenMidR"), "SurfaceGui"),
		}
		local teamLists = {
			Alpha = wfc(screens.left, "Alpha"),
			Beta  = wfc(screens.right, "Beta")
		}
		local plrTeamListFrameTemplate = wfc(heli, "PlrListFrame")
		local timerGui  = screens.left.Timer
		local timerText = timerGui.sec
		local timerFans = {}
		for i = 0, 5 do
			timerFans[i] = timerGui.Fans[tostring(i)]
		end
		local timerYellow = Color3.fromRGB(254, 168, 20)
		local timerOrange = Color3.fromRGB(253, 104, 59)

		local wfp = requireGm("WaitForProperty")

		local function addToTeamList(plr)
			spawn(function()

				local team     = wfp(plr, "Team", {clockrate = 0.1})
				local teamName = team.Name
				local teamList = teamLists[teamName]
				assert(teamList or warn("heliGuis: invalid teamName", teamName))
				local plrName  = plr.Name

				local New                       = clone(plrTeamListFrameTemplate)
				New.Name                        = plrName
				New.FullCover.ImageColor3       = team.TeamColor.Color
				New.FullCover.ImageTransparency = 0.7	
				setStText(New.lvl, pv.waitForP(plr, "Level"))
				setStText(New.name, plr.Name)

				if ffc(teamList, plrName) then
					warn("heli: addToTeamList:", plr, "is already in", teamName, ". aborted.")
					return
				end
				New.Parent = teamList
			end)
		end
		local function removeFromTeamList(plr)
			for _, list in pairs(teamLists) do
				local peak = ffc(list, plr.Name)
				if peak then
					destroy(peak)
				end
			end
		end
		function heliGui.init()
			cons[#cons + 1] = connect(pv.waitForObj("HeliTimer").Changed, function(t)
				timerText.Text = tostring(t)
				local fans = screens.left.Timer.Fans
				for i = 0, 6-1 do
					local fan = timerFans[i]
					fan.ImageColor3 = timerYellow
					tween(fan, 4/6, {ImageColor3 = timerOrange})
					wait(1/6)
				end
			end)
			for _, plr in ipairs(getC(plrs)) do
				addToTeamList(plr)
			end
			cons[#cons + 1] = connect(teams.Alpha.PlayerAdded, addToTeamList)
			cons[#cons + 1] = connect(teams.Beta.PlayerAdded, addToTeamList)
			cons[#cons + 1] = connect(teams.Alpha.PlayerRemoved, removeFromTeamList)
			cons[#cons + 1] = connect(teams.Beta.PlayerRemoved, removeFromTeamList)
		end
	end

	local heliSfx = {}
	do
		local heliSoundsLib = wfc(wfc(rep, "Sounds"), "Helicopter")
		local mainSound = clone(heliSoundsLib.Helicopter)
		function heliSfx.init()
			local max = mainSound.Volume
			mainSound.Volume = 0
			mainSound.EqualizerSoundEffect.HighGain = -20
			mainSound.EqualizerSoundEffect.MidGain  = -15
			mainSound:Play()
			spawn(function()
				for i = 0,max,0.025 do
					if not running then
						return
					end
					wait(0.05)
					if mainSound then
						mainSound.Volume = i
					end
				end
			end)
		end
		function heliSfx.destroy()
			destroy(mainSound)
		end
		heliSfx.heliSoundsLib = heliSoundsLib
	end

	local heliCam = {}
	do
		local mouse  = lp:GetMouse()
		local rs     = game:GetService("RunService").RenderStepped
		local newCf  = CFrame.new
		local exyz   = CFrame.fromEulerAnglesYXZ
		local cfLerp = myMath.cfLerp
		local camPart     = heli.CameraPart
		local rad         = math.rad
		local ran         = math.random
		local noise       = math.noise
		local _smoothLerp = myMath._smoothLerp
		local cam = workspace.CurrentCamera

		local camInt = 0
		local gCamInt = 0

		function heliCam.init()
			spawn(function()
				local st = tick()
				local lastTick = tick()
				while evwait(rs) and running do
					local now = tick()
					local dt  = now - lastTick
					local sum = now - st
					lastTick = now

					local mx = ((mouse.X / mouse.ViewSizeX) - 0.5) * 2 
					local my = ((mouse.Y / mouse.ViewSizeY) - 0.5) * 2

					camInt = myMath.lerpTo(camInt, gCamInt, dt / 2)

					-- credits to matt
					cam.CFrame = cfLerp(
							camPart.CFrame * newCf( (1-mx)*-0.6,0,(my)*-0.8 ),
							heli.DoorOpen.CFrame,
							_smoothLerp(0, 1, camInt)
						)
						* newCf(
							(ran()-0.5) * 0.005,
							(ran()-0.5) * 0.005,
							(ran()-0.5) * 0.005
						)
						* exyz(
							noise(sum/5) * rad(3) - my * rad(20) - rad(10),
							noise(sum/5 + 7.76352) * rad(3) - mx * rad(10),
							noise(sum/5 + 1.23252) * rad(1)
						)
				end
			end)
		end
		function heliCam.setGCamInt(val)
			gCamInt = val
		end
		function heliCam.destroy()
			-- running = false
		end
	end

	function preMatchHandler.destroyAnimate()
		-- transition to fps
		local s = heliSfx.heliSoundsLib
		s.Warning:Play()
		wait(0.5)

		local st = tick()
		heliCam.setGCamInt(1)
		wait(2)
		wait(0.8)
		st = tick()
		s.MetalSlam:Play()

		local hb          = game:GetService("RunService").Heartbeat
		local spcf        = Instance.new("Model").SetPrimaryPartCFrame
		local slide       = heli.Heli.slide
		local slideClosed = heli.SlideClosed
		local slideBack   = heli.SlideBack
		local _smoothLerp = myMath._smoothLerp
		local clamp       = math.clamp
		local cfLerp      = myMath.cfLerp

		while tick() - st < 0.5 do
			hb:wait()
			local stp = clamp((tick()-st)/0.5, -1000, 1)
			spcf(slide, cfLerp(slideClosed.CFrame, slideBack.CFrame, _smoothLerp(0, 1, stp)))
			s.Helicopter.EqualizerSoundEffect.HighGain = -10*(1-stp^0.5)-10
			s.Helicopter.EqualizerSoundEffect.MidGain =  -10*(1-stp^0.5)-5
		end

		wait(0.3)
		s.HeavyDoor:Play()
		wait(0.1)
		local fade      = game:GetService("Lighting").HeliFade
		fade.Brightness = 0
		fade.Contrast   = 0
		fade.Saturation = 0

		audioSys.play("MatchStart", "2D")
		local slideOpen = heli.SlideOpen
		st = tick()
		while tick() - st < 5 do
			evwait(hb)
			local stp = (tick() - st) / 5
			stp = stp > 1 and 1 or stp
			spcf(slide, cfLerp(slideBack.CFrame, slideOpen.CFrame, _smoothLerp(0, 1, stp)))
			fade.Brightness = clamp(stp * 3, 0, 10)
			s.Helicopter.Volume = (1+0.5*stp) / 2
			s.Helicopter.EqualizerSoundEffect.HighGain = -10*(1-stp^0.5)
			s.Helicopter.EqualizerSoundEffect.MidGain  =  -5*(1-stp^0.5)
		end
		running = false

		print("destroying the prematch module 1")

		spawn(function()
			for i = 0,1,0.025 do
				wait(0.05)
				s.Helicopter.Volume = ((1-i)*1.5) / 2
			end
			spawn(function()
				local rs = game:GetService("RunService").RenderStepped
				local fade      = game:GetService("Lighting").HeliFade
				while evwait(rs) and fade.Parent and fade.Brightness > 0.01 do
					fade.Brightness = fade.Brightness * 0.95
				end
				destroy(fade)
			end)

			heliCam.destroy()
			heliSfx.destroy()
			for _, con in ipairs(cons) do
				con:Disconnect()
			end
			heli:Destroy()
		end)

		print("destroying the prematch module done")
	end

	function preMatchHandler.init()
		local joinData = requireGm("WaitForProperty")(_G, "joinData")
		if joinData.joinMethod == "quickjoin" then 
			heli:Destroy()
			return
		end
		if not db.preMatchEnabled then return end

		heliGui.init()
		heliSfx.init()
		heliCam.init()

		local done = false
		local function onPhaseChanged(phase)
			print("local client detects phase change", phase, typeof(phase))
			if not done then
				if phase ~= "" and phase ~= "WaitInHeli" then
					print("fpp: destroying helicopter")
					done = true
					preMatchHandler.destroyAnimate()
				end
			end
		end

		local phaseValue = pv.waitForObj("Phase")
		onPhaseChanged(phaseValue.Value)
		connect(phaseValue.Changed, onPhaseChanged)
	end
	preMatchHandler.init()
end

local roundEndHandler = {}
do
	local lighting = game.Lighting
	local roundEndGui  = clone(wfc(script, "RoundEndGui"))
	roundEndGui.Parent = playerGui

	local tweening    = requireGm("Tweening")
	local shadedTexts = requireGm("ShadedTexts")
	local tween       = tweening.tween
	local tweenSt     = shadedTexts.tween
	local setStProps  = shadedTexts.setStProps
	local setStText   = shadedTexts.setStText
	local newU2 = UDim2.new
	local teams = game.Teams
	local audioSys = requireGm("AudioSystem")

	local blur = {}
	do
		local blurObj = wfc(lighting, "BlurMainframe")
		local blurMax = blurObj.Size
		function blur.blur(time)
			tween(blurObj, time, {Size = blurMax})
		end
		function blur.unblur(time)
			tween(blurObj, time, {Size = 0})
		end
		function blur.init()
			blurObj.Size = 0
			blurObj.Enabled = true
		end
	end

	local popupTitle = {}
	do
		local sub = string.sub
		local toUpper = string.upper
		local function processStr(str)
			local ret = ""
			str = toUpper(str)
			for i = 1, #str do
				ret = ret..sub(str, i, i).." "
			end
			return ret
		end
		
		local textGui = wfc(roundEndGui, "PopupTitle")
		local defTextTrans, defShadeTrans
		--  {
				-- fadingIn  = 0.5,
				-- staying   = 0.5,
				-- fadingOut = 0.5,
			-- }
		local timings = {
			fadingIn  = 1.5,
			staying   = 1.5,
			fadingOut = 1.5,
		}
		function popupTitle.show(str)
			-- set the text and the initial Texttransparency
			setStProps(textGui, {TextTransparency = 1, Text = processStr(str)})

			-- fadein
			do
				print("defTextTrans =", defTextTrans)
				tweenSt(textGui, timings.fadingIn, {TextTransparency = defTextTrans})
				wait(timings.fadingIn)
			end

			-- stay
			wait(timings.staying)

			-- fadeout
			do
				tweenSt(textGui, timings.fadingIn, {TextTransparency = 1})
				wait(timings.fadingOut)
			end
		end
		function popupTitle.init()
			defTextTrans  = textGui.text.TextTransparency
			defShadeTrans = textGui.shade.TextTransparency
			textGui.text.TextTransparency  = 1
			textGui.shade.TextTransparency = 1
		end
	end

	local scores = {}
	do
		local scoresGui = wfc(roundEndGui, "Scores")
		local defPos, defSize
		local left       = wfc(scoresGui, "Left")
		local right      = wfc(scoresGui, "Right")
		local mid        = wfc(scoresGui, "Mid")
		local enlargeU2  = newU2(0.2, 0, 0.2, 0)
		local movingUpU2 = newU2(0, 0, -0.05, 0)
		local timings = {
			fadingIn = 1.1,
			stayBeforeEnlarging = 0.33,
			enlarging = 0.35,
			stayAtLargest = 0,
			shrinking = 0.35,
			stayAfterShrinking = 1,
			fadingOut = 0.7,
		}
		function scores.show(leftScore, rightScore, changedSide)
			local changedSideGui, changedSideScore
			do
				if changedSide == "left" then
					changedSideGui = left
					changedSideScore = leftScore
				elseif changedSide == "right" then
					changedSideGui = right
					changedSideScore = rightScore
				end
			end
			-- fadingIn = 0.5,
			do
				scoresGui.Position = defPos
				setStText(left, tostring(leftScore))
				setStText(right, tostring(rightScore))
				setStText(changedSideGui, tostring(changedSideScore - 1))
				tweenSt(left, timings.fadingIn, {TextTransparency = 0})
				tweenSt(right, timings.fadingIn, {TextTransparency = 0})
				tweenSt(mid, timings.fadingIn, {TextTransparency = 0})
				wait(timings.fadingIn)
			end

			-- stayBeforeEnlarging = 0.5,
			audioSys.play("RoundScoreChange", "2D")--, {fitLength = timings.stayBeforeEnlarging + timings.enlarging})
			wait(timings.stayBeforeEnlarging)

			-- enlarging = 0.1
			do
				tween(changedSideGui, timings.enlarging, {Size = defSize + enlargeU2})
				wait(timings.enlarging)
				setStText(changedSideGui, tostring(changedSideScore))
			end

			-- stayAtLargest = 0,
			wait(timings.stayAtLargest)

			-- shrinking = 0.1,
			do
				tween(changedSideGui, timings.shrinking, {Size = defSize})
				wait(timings.shrinking)
			end

			-- stayAfterShrinking = 0.5,
			wait(timings.stayAfterShrinking)

			-- fadeOut = 0.5 and moving up
			do
				audioSys.play("RoundScoreMove", "2D")--, {fitLength = timings.fadingOut})
				tweenSt(left, timings.fadingOut, {TextTransparency = 1})
				tweenSt(right, timings.fadingOut, {TextTransparency = 1})
				tweenSt(mid, timings.fadingOut, {TextTransparency = 1})
				tween(scoresGui, timings.fadingOut, {Position = defPos + movingUpU2})
				wait(timings.fadingOut)
			end
		end
		function scores.init()
			defPos = scoresGui.Position
			defSize = left.Size
			setStProps(left, {TextTransparency = 1})
			setStProps(right, {TextTransparency = 1})
			setStProps(mid, {TextTransparency = 1})
		end
	end

	local countdown = {}
	do
		local countdownGui = wfc(roundEndGui, "Countdown")
		local timer = wfc(countdownGui, "Timer")
		local sub = wfc(countdownGui, "Sub")
		local defSize, enlargedSize
		function countdown.init()
			defSize = timer.Size
			local factor = 1.2
			enlargedSize = newU2(1.2 * defSize.X.Scale, 0, 1.2 * defSize.Y.Scale, 0)
			setStProps(sub, {TextTransparency = 1})
			setStProps(timer, {TextTransparency = 1})
		end
		local timings = {
			fadingInSub    = 1.5,
			waitTimer      = 0.5,
			fadingInTimer  = 1.0,
			stayAsShrinked = 0.7,
			enlarging      = 0.15,
			stayAsEnlarged = 0.0,
			shrinking      = 0.15,
			fadingOut      = 1.5,
		}
		function countdown.show(time)
			-- fading in sub
			do
				tweenSt(sub, timings.fadingInSub, {TextTransparency = 0})
				wait(timings.fadingInSub + timings.waitTimer)
			end
			-- fading in timer
			do
				setStText(timer, tostring(time))
				tweenSt(timer, timings.fadingInTimer, {TextTransparency = 0})
				wait(timings.fadingInTimer)
			end
			-- loop the timer
			for i = time, 1, -1 do
				-- wait before enlarge 
				wait(timings.stayAsShrinked / 2)

				-- enlarging
				do
					tween(timer, timings.enlarging, {Size = enlargedSize})
					wait(timings.enlarging)
				end

				-- staying as enlarged
				do
					audioSys.play("RoundCountdownBeep", "2D")
					setStText(timer, tostring(i - 1))
					wait(timings.stayAsEnlarged) 
				end

				-- shrinking
				do
					tween(timer, timings.shrinking, {Size = defSize})
					wait(timings.shrinking)
				end

				wait(timings.stayAsShrinked / 2)
			end

			-- fadingOut
			do
				tweenSt(timer, timings.fadingOut, {TextTransparency = 1})
				tweenSt(sub, timings.fadingOut, {TextTransparency = 1})
				wait(timings.fadingOut)
			end
		end
	end

	-- local fpsGui = {}
	-- do
	-- 	-- local fpsGuiLocalEvent = wfc(wfc(wfc(lp, "PlayerScripts"), "Fpp"), "Event")
	-- 	function fpsGui.turnoff()
	-- 		pv.setPublicVar("FpsGuiOn", false)
	-- 		-- fpsGuiLocalEvent:Fire("setEnabled", false)
	-- 	end
	-- 	function fpsGui.turnOn()
	-- 		pv.setPublicVar("FpsGuiOn", true)
	-- 		-- fpsGuiLocalEvent:Fire("setEnabled", true)
	-- 	end
	-- end

	-- timing: 16.2s for round end
	-- timing: 13s for match end
	local roundEndGuiRunning = false
	local roundEndSt
	function roundEndHandler.onRoundEnd(rw, mw)		-- roundwinner and matchwinner as a team
		if roundEndGuiRunning then 
			warn("roundEndGui already Running. new thread stopped. round ends too fast?")
			return
		end

		roundEndGuiRunning = true
		roundEndSt = tick()

		-- -- turnoff fps gui
		-- fpsGui.turnoff()

		-- blur the oofing blur
		blur.blur(0.5)

		-- show who oofing wins the round
		do
			local function getOppositeTeam(team)
				return team == teams.Alpha and teams.Alpha or teams.Beta
			end
			local function hasEnemyAllFled()
				if lp.Team then
					return #getOppositeTeam(lp.Team):GetPlayers() == 0
				else
					return false
				end
			end
			local function getTextToShow()
				if rw == "draw" then
					return "draw"
				elseif lp.Team == nil then
					warn("my team is not set yet")
					return "Team "..rw.Name.." wins the round"
				elseif rw == lp.Team then
					if hasEnemyAllFled() then
						return "all anemies fled"
					else	
						return "victory"
					end
				else
					return "defeat"
				end
			end
			audioSys.play("RoundResult", "2D")
			popupTitle.show(getTextToShow())
		end

		-- change the oofing score
		do

			local function getLeftAndRightTeam()		-- based on lp.team
				if lp.Team == nil then
					warn("my team is not set yet")
					return teams.Alpha, teams.Beta
				elseif lp.Team == teams.Alpha then
					return teams.Alpha, teams.Beta
				else
					return teams.Beta, teams.Alpha
				end
			end
			local function getScoreChangeSide(left, right)
				if left == rw then
					return "left"
				elseif right == rw then
					return "right"
				else
					return "draw"
				end
			end
			local function getTeamScore(team)
				return pv.waitFor(team.Name.."Wins")
			end
			local function getScoreChangeData()		-- based on left, right, and rw
				local left, right = getLeftAndRightTeam()
				return getTeamScore(left), getTeamScore(right), getScoreChangeSide(left, right)
			end
			scores.show(getScoreChangeData())
		end

		if not mw then
			-- count the oofing down
			countdown.show(3)
		else
			-- show the oofing text
			do
				local function getWinnerText()
					return "Team "..mw.Name.." won the match"
				end
				audioSys.play("RoundResult", "2D")
				popupTitle.show(getWinnerText())
			end
		end

		-- unblur the oofing blur
		blur.unblur(0.5)

		-- turn back on fpp gui
		-- fpsGui.turnOn()

		roundEndGuiRunning = false
		print("round end gui has finished running", tick() - roundEndSt)
	end

	function roundEndHandler.init()
		blur.init()
		countdown.init()
		scores.init()
		popupTitle.init()

		-- listen to EVENTS
		mainframeClient.listen("round end", roundEndHandler.onRoundEnd)

		-- listen to debug
		local debugHandlers = {
			["testing round end"] = roundEndHandler.onRoundEnd
		}
		rep.LocalDebugLocal.OnInvoke = function(key, ...)
			if debugHandlers[key] then
				debugHandlers[key](...)
			end
		end
	end
	roundEndHandler.init()
end

local showtimeHandler = {}
do
	local getC    = game.GetChildren
	local audioSys          = requireGm("AudioSystem")

	local showtimeLib = wfc(workspace, "Showtime")
	local spawns  = {}
	for _, spawn in ipairs(wfc(showtimeLib, "Spawns"):GetChildren()) do
		spawns[tonumber(spawn.Name)] = spawn
		spawn.Transparency = 1
	end

	do-- spawndancer
		local charTemp          = game.StarterPlayer.StarterCharacter
		local clone             = game.Clone
		local destroy           = game.Destroy
		local spcf              = Instance.new("Model").SetPrimaryPartCFrame
		local rigHelper         = requireGm("RigHelper")
		local keyframeAnimation = requireGm("KeyframeAnimation")
		local animations        = requireGm("TppAnimations")()

		function showtimeHandler.spawnDancer(dance, spawnLocation, side, delay)
			local self = {}

			local char = clone(charTemp)
			spcf(char, spawnLocation.CFrame)
			char.HumanoidRootPart.Anchored = true
			char.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

			local aniparts, joints, defC0, sounds, stash = {}, {}, {}, {}, {}
			do
				rigHelper.initRig(char, aniparts, joints, defC0)
				local skinObjs = {fpp = {}, tpp = {}}
				local skin = side.."_Default"
				rigHelper.setCharVisibility("tpp", true, char, aniparts, skinObjs, {skin = skin})
				rigHelper.setCharVisibility("fpp", false, char, aniparts, skinObjs)
		  end

		  local kfs = keyframeAnimation.new(aniparts, joints, defC0, stash)
		  kfs.load(animations, dance, {snapFirstFrame = true})

		  char.Parent = workspace
		  local running = true
		  spawn(function()
		  	local rs = game:GetService("RunService").RenderStepped
		  	local evwait = game.Changed.Wait
		  	wait(delay)
		  	while running do
		  		local dt = evwait(rs)
		  		kfs.playAnimation(dt)
		  	end
		  end)

		  do
		  	local deathAnis = {
		  		"standDeath1",
		  		"standDeath2",
		  		"standDeath3",
		  		"standDeath4",
		  		"standDeathHeadshot1",
		  		"standDeathHeadshot3",
		  	}
				function self.die()
					kfs.load(animations, deathAnis[math.random(1, #deathAnis)])
					audioSys.play("DeathScream", "2D")
				end
			end

			function self.destroy()
				running = false
				destroy(char)
			end

			return self
		end
	end

	do-- start/end
		local cam     = workspace.CurrentCamera
		local blur    = game.Lighting.BlurShowtime
		local blurMax = blur.Size

		local cam0    = wfc(showtimeLib, "Cam0").CFrame
		showtimeLib.Cam0.Transparency = 1
		showtimeLib.Cam0:ClearAllChildren()
		local cam1    = wfc(showtimeLib, "Cam1").CFrame
		showtimeLib.Cam1.Transparency = 1
		showtimeLib.Cam1:ClearAllChildren()
		local tween = requireGm("Tweening").tween
		local timings = { --10secs
			blur1     = 1.5,
			camStay0  = 0.5,
			camZoomIn = 10.5,
			camStay1  = 2.5,
		}
		local dancers = {}

		local guiTemp = spawns[1].BillboardGui
		guiTemp.Parent = nil
		local clone = game.Clone
		local ffc = game.FindFirstChild
		local guis = {}

		function showtimeHandler.start(dancerInfos, mw)
			print("showtimeHandler.start")
			-- play sound
			if mw == nil or lp.Team == nil then
				print("showtimeHandler: mw =", mw, "lp.Team =", lp.Team, "using the victorysound")
				audioSys.play("ShowtimeVictory", "2D")
			else
				audioSys.play(mw == lp.Team and "ShowtimeVictory" or "ShowtimeDefeat", "2D")
			end

			-- spawn dancers and configure the surface gui.
			for i, d in ipairs(dancerInfos) do
				dancers[i] = showtimeHandler.spawnDancer(d.dance, d.spawnLocation, d.side, i * 0.2)
				local gui = clone(guiTemp)
				gui.Frame.score.Text = string.format("Score: %d", d.stats.score)
				gui.Frame.name.Text = d.plrName
				if mw then
					gui.Frame.name.TextColor3 = mw.TeamColor.Color
				end
				gui.Parent = d.spawnLocation
				guis[#guis + 1] = gui
			end

			do-- cam animations
				-- blur in
				blur.Enabled = true
				blur.Size = 0
				tween(blur, timings.blur1 / 2, {Size = blurMax})
				wait(timings.blur1 / 2)

				-- cam trans
				cam.CameraType    = Enum.CameraType.Scriptable
				cam.CameraSubject = spawns[5]
				cam.CFrame        = cam0

				-- blur out
				tween(blur, timings.blur1 / 2, {Size = 0})
				wait(timings.blur1 / 2)

				-- camstay0
				wait(timings.camStay0)

				-- camZoomin
				tween(cam, timings.camZoomIn, {CFrame = cam1})
				wait(timings.camZoomIn)

				-- camstay1
				wait(timings.camStay1)
			end
		end
		function showtimeHandler.jieshu()
			for i = #dancers, 1, -1 do
				local dancer = dancers[i]
				dancer.die()
				dancers[i] = nil
				wait(0.15)
			end
			for _, gui in ipairs(guis) do
				gui:Destroy()
			end
			print("showtime ends")
		end
	end
	do-- listen to online events
		mainframeClient.listen("showtime.start", showtimeHandler.start)
		mainframeClient.listen("showtime.end", showtimeHandler.jieshu)
	end
end

local votingHandler = {}
do
	local getC    = game.GetChildren
	local destroy = game.Destroy
	local connect = game.Changed.Connect

	local inRoom = false

	-- local inited  = false
	do -- blur
		local tween   = requireGm("Tweening").tween
		local blur    = game.Lighting.BlurVoting
		blur.Enabled  = false
		local blurMax = blur.Size
		blur.Size = 0
		function votingHandler.setBlur()
			blur.Enabled  = true
			blur.Size     = 0
			tween(blur, 0.5, {Size = blurMax})
		end
	end


	local sg = wfc(script, "Voting")
	sg.Enabled = false
	sg.Parent = playerGui

	local quitFr   = wfc(sg, "Quit")
	local quitText = wfc(wfc(quitFr, "Frame"), "text")
	local mainFr   = wfc(sg, "Main")
	local voteFr   = wfc(mainFr, "Vote")
	local vote     = nil
	local phase    = nil

	do-- handleteams()
		local frames = {
			alpha = wfc(wfc(mainFr, "Alpha"), "ImageLabel"),
			beta  = wfc(wfc(mainFr, "Beta"), "ImageLabel"),
		}
		local cnts = {
			alpha = wfc(frames.alpha, "PlayerCnt"),
			beta  = wfc(frames.beta, "PlayerCnt"),
		}
		local playerLists = {
			alpha = wfc(frames.alpha, "Players"),
			beta  = wfc(frames.beta, "Players")
		}
		local playerTemp = wfc(playerLists.alpha, "Frame")
		local playerTempParty = wfc(playerLists.beta, "Frame")
		playerTemp.Parent = nil
		playerTempParty.Parent = nil
		local ffc = game.FindFirstChild
		local clone = game.Clone
		local destroy = game.Destroy
		function votingHandler.handleTeams(teams)
			-- teamlist
			for teamName, team in pairs(teams) do
				local playerList = playerLists[teamName]
				-- delete removed players
				for _, fr in ipairs(getC(playerList)) do
					if fr.Name ~= "UIGridLayout" and not team[fr.Name] then
						destroy(fr)
					end
				end
				-- add new players
				-- local cnt = 0
				for plrName, plr in pairs(team.players) do
					-- cnt = cnt + 1
					if ffc(playerList, plrName) == nil then
						local playerFr = clone(plr == lp and playerTempParty or playerTemp)
						playerFr.Name = plrName
						playerFr.TextLabel.Text = plrName
						playerFr.Parent = playerList
					end
				end
				-- teamcount
				cnts[teamName].Text = team.playerCnt.."/7"
			end
		end
	end

	do-- options and voting
		local optionsFr = wfc(voteFr, "Options")
		local optionFrs = {
			[1] = wfc(optionsFr, "Office"),
			[2] = wfc(optionsFr, "Metro"),	
			[3] = wfc(optionsFr, "Yacht"),
			[4] = wfc(optionsFr, "Resort"),
		}
		local checks = {
			[1] = wfc(optionFrs[1], "Checks"),
			[2] = wfc(optionFrs[2], "Checks"),
			[3] = wfc(optionFrs[3], "Checks"),
			[4] = wfc(optionFrs[4], "Checks"),
		}
		local checkN = {
			[1] = 0,
			[2] = 0,
			[3] = 0,
			[4] = 0,
		}
		local clone = game.Clone
		local destroy = game.Destroy
		local ffcWia = game.FindFirstChildWhichIsA
		local checkTemp = wfc(checks[1], "Check")
		checkTemp.Parent = nil

		-- connect vote buttons
		for i, optionFr in ipairs(optionFrs) do
			connect(optionFr.MouseButton1Click, function()
				if vote ~= i and phase == "voting" and inRoom then
					vote = i
					mainframeClient.fireServer("voting.vote", i)
				end
			end)
		end

		function votingHandler.handleOptions(options)
			for i, option in ipairs(options) do
				local optionFr = optionFrs[i]
				local vote     = option.vote
				if vote < checkN[i] then
					for _ = 1, checkN[i] - vote do
						local check = ffcWia(checks[i], "ImageLabel")
						destroy(check)
					end
				elseif vote > checkN[i] then
					for _ = 1, vote - checkN[i] do
						clone(checkTemp).Parent = checks[i]
					end							
				end
				checkN[i] = vote
				-- optionFr.Visible = true
			end
		end
		function votingHandler.hideOtherOptions(mpIdx)
			for i, optionFr in ipairs(optionFrs) do
				if i ~= mpIdx then
					optionFr.Visible = false
				end
			end
		end
		function votingHandler.showAllOptions()
			for i, optionFr in ipairs(optionFrs) do
				optionFr.Visible = true
			end
		end
	end

	do --title
		local pwd = game.GetFullName
		local title     = wfc(voteFr, "Title")
		-- print(pwd(voteFr))
		-- print(pwd(title))
		-- printTable(title:GetChildren())
		local setStText = requireGm("ShadedTexts").setStText
		function votingHandler.setTitle(phase, timer)
			local timer = math.floor(timer + 0.5)
			if phase == "waiting" then
				setStText(title, "WAITING FOR MORE PLAYERS")
			elseif phase == "voting" then
				setStText(title, timer.." SECONDS LEFT TO VOTE")
			elseif phase == "starting" then
				setStText(title, "TELEPORTING TO MATCH")
			else
				error(string.foramt("invalid phase %s", phase))
			end
		end
	end

	do-- handle phase
		function votingHandler.handlePhase(room)
			phase = room.phase
			if room.phase == "starting" then
				votingHandler.hideOtherOptions(room.mpIdx)
			else
				votingHandler.showAllOptions()
			end
			votingHandler.setTitle(room.phase, room.timer)
		end
	end

	connect(quitFr.MouseButton1Click, function()
		mainframeClient.fireServer("voting.backToLobby")
	end)
	mainframeClient.listen("voting.cancel", function()
		print("client: teleporting back to lobby")
		inRoom = false
	end)
		
	mainframeClient.listen("voting.start", function(room)
		-- init room gui here
		votingHandler.setBlur()
		votingHandler.handlePhase(room)
		
		votingHandler.handleTeams(room.teams)
		votingHandler.setTitle(room.phase, room.timer)
		votingHandler.handleOptions(room.options)

		vote = nil
		inRoom = true
		sg.Enabled = true
	end)
	mainframeClient.listen("voting.phase", votingHandler.handlePhase)
	mainframeClient.listen("voting.teams", votingHandler.handleTeams)
	mainframeClient.listen("voting.timer", votingHandler.setTitle)
	mainframeClient.listen("voting.votes", votingHandler.handleOptions)
end

print("mainframe local helper setup")