local md = {}

-- defs
local rep    = game.ReplicatedStorage
local plrs   = game.Players
local lp     = plrs.LocalPlayer
local Gui    = lp:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")
local lpVars = lp:WaitForChild("PlayerScripts"):WaitForChild("Variables")
local remote = rep.Events.MainRemote

local roundGui    = Gui:WaitForChild("Gameplay"):WaitForChild("Round")
local popupTitle  = roundGui:WaitForChild("Title")
local popupSub    = roundGui:WaitForChild("Sub")
local popupTimer  = roundGui:WaitForChild("Timer")
local popupLevel  = roundGui:WaitForChild("Level")
local popupExpBar = roundGui:WaitForChild("ExpBar")

local scoreBarTimer = Gui.Gameplay:WaitForChild("Top"):WaitForChild("Timer"):WaitForChild("Timer")

local blur = game:GetService("Lighting").Blur4Round

local gm         = rep:WaitForChild("GlobalModules")
local ga         = require(gm:WaitForChild("GeneralAnimation"))
local sd         = require(gm:WaitForChild("ShadedTexts"))
local levelExpMd = require(gm:WaitForChild("LevelExp"))
local inHeliMd   = require(script.Parent:WaitForChild("InHeli"))
--local specMd     = require(script.Parent:WaitForChild("Spec"))
local fpsUtilsMd = require(gm:WaitForChild("FpsUtils"))
local hpMarkerMd = require(script.HardpointMarker)

local specLocalEvent = script.Parent.Parent:WaitForChild("PlayerAnimation"):WaitForChild("SpecLocal")

local Audios        = rep:WaitForChild("Audios")
local cam           = workspace.CurrentCamera
--local setHeadRemote = lp:WaitForChild("PlayerScripts"):WaitForChild("PlayerAnimation"):WaitForChild("SetHead")

-- consts
md.scoreFGColor3             = {}
md.scoreFGColor3["Alpha"] = Color3.fromRGB(255, 93, 0)
md.scoreFGColor3["Beta"]    = Color3.fromRGB(99, 39, 212)
md.scoreBGColor3             = {}
md.scoreBGColor3["Alpha"] = Color3.fromRGB(77, 64, 49)
md.scoreBGColor3["Beta"]    = Color3.fromRGB(45, 18, 99)
local camFarFinal            = workspace:WaitForChild("Map"):WaitForChild("Final"):WaitForChild("camFarFinal").CFrame
local camCloseFinal          = workspace.Map.Final:WaitForChild("camCloseFinal").CFrame
local inStudio               = game.CreatorId == 0
-- const funcs
function md.showScoreBar()
	warn("showScoreBar is called")
	if lpVars.atHome.Value == true or lp.Neutral or lp.Team == nil then return end
	warn("showScoreBar")

	Gui.Gameplay.Top.Left.Shape.ImageColor3            = md.scoreBGColor3[lp.Team.Name]
	Gui.Gameplay.Top.Left.Shape.Bar.Shape.ImageColor3  = md.scoreFGColor3[lp.Team.Name]
	Gui.Gameplay.Top.Right.Shape.ImageColor3           = md.scoreBGColor3[fpsUtilsMd.oppTeam().Name]
	Gui.Gameplay.Top.Right.Shape.Bar.Shape.ImageColor3 = md.scoreFGColor3[fpsUtilsMd.oppTeam().Name]

	-- side == "Left"
	local total= fpsUtilsMd.getTotalScore(lp.Team)
	local val  = fpsUtilsMd.getScore(lp.Team)

	sd.setProperty(Gui.Gameplay.Top.Left.Shape.Score, "Text", string.format("    %d", val))
	if total == 0 then total = 1 end
	Gui.Gameplay.Top.Left.Shape.Bar.Position = UDim2.new(1-val/total, 0, 0, 0)
	Gui.Gameplay.Top.Left.Shape.Bar.Size     = UDim2.new(val/total, 0, 1, 0)	

	-- side == "Right"
	total = fpsUtilsMd.getTotalScore(fpsUtilsMd.oppTeam())
	val   = fpsUtilsMd.getScore(fpsUtilsMd.oppTeam())

	sd.setProperty(Gui.Gameplay.Top.Right.Shape.Score, "Text", string.format("%d    ", val))
	if total == 0 then total = 1 end		
	Gui.Gameplay.Top.Right.Shape.Bar.Size = UDim2.new(val/total, 0, 1, 0)
	
	Gui.Gameplay.Top.Visible = true
end

function md.play(a, t)
	spawn(function()
		a.PlaybackSpeed = 1
		local startTime = tick()
		for i = 1, 5, 0.2 do
			a.PlaybackSpeed = i
			wait(0.1)
			if tick() - startTime > t then break end
		end
	end)
	spawn(function()
		a:Play()
		local startTime = tick()
		repeat
			wait(0.1)
		until tick() - startTime > t
		a:Stop() 
	end)  
end

function md.onRoundEnd(roundWinner, matchWinner)
	if lpVars.atHome.Value == true then return end

	lpVars.inRoundIntermission.Value = true
	Gui.Spec.Visible = false
	print("roundWinner = ", roundWinner, "myTeam is", lp.Team)
	local tt = tick()
	
	blur.Size = 0
	blur.Enabled = true
	ga.animateProperty(blur, "Size", 22, 0.5)

	-- if all enemies leave the game
	local enemyFled = roundWinner == lp.Team and #fpsUtilsMd.oppTeam():GetPlayers() == 0 and inStudio == false
	
	-- victory/defeat
	if roundWinner == nil then 
		sd.setProperty(popupTitle, "Text", "D R A W")
	elseif enemyFled then 
		sd.setProperty(popupTitle, "Text", "A L L   E N E M I E S   F L E D")
	else 
		sd.setProperty(popupTitle, "Text", 
			roundWinner == lp.Team and "V I C T O R Y" or "D E F E A T") 
	end
	sd.setPosition(popupTitle, UDim2.new(0, 0, 0.42, 0))
	
	Audios.vicdef:Play()
	sd.fade(popupTitle, -1, 1.25)	
	wait(2.5)
	sd.fade(popupTitle, 1, 1)
	wait(1)

	-- scores
	--in
	if enemyFled then
		wait(1.5)
	else
		sd.setPosition(Gui.Gameplay.Round.ScoreLeft, UDim2.new(0.455, 0, 0.425, 0))
		sd.setPosition(Gui.Gameplay.Round.ScoreMid, UDim2.new(0.45, 0, 0.435, 0))
		sd.setPosition(Gui.Gameplay.Round.ScoreRight, UDim2.new(0.495, 0, 0.425, 0))
		if roundWinner == nil then
			sd.setProperty(Gui.Gameplay.Round.ScoreLeft, "Text", 
				tostring(fpsUtilsMd.getWins(lp.Team)))
			sd.setProperty(Gui.Gameplay.Round.ScoreRight, "Text", 
				tostring(fpsUtilsMd.getWins(fpsUtilsMd.oppTeam())))
		elseif roundWinner == lp.Team then
			sd.setProperty(Gui.Gameplay.Round.ScoreLeft, "Text", 
				tostring(fpsUtilsMd.getWins(lp.Team) - 1))
			sd.setProperty(Gui.Gameplay.Round.ScoreRight, "Text", 
				tostring(fpsUtilsMd.getWins(fpsUtilsMd.oppTeam())))
		else
			sd.setProperty(Gui.Gameplay.Round.ScoreLeft, "Text", 
				tostring(fpsUtilsMd.getWins(lp.Team)))
			sd.setProperty(Gui.Gameplay.Round.ScoreRight, "Text", 
				tostring(fpsUtilsMd.getWins(fpsUtilsMd.oppTeam()) - 1))
		end
		sd.fade(Gui.Gameplay.Round.ScoreLeft, -1, 0.75)
		sd.fade(Gui.Gameplay.Round.ScoreMid, -1, 0.75)
		sd.fade(Gui.Gameplay.Round.ScoreRight, -1, 0.75)
		wait(1)
		--enlarge & shrink		
		if roundWinner then
			Audios.roundScore:Play()	
			if roundWinner == lp.Team then
				sd.TweenSizeAndPosition(Gui.Gameplay.Round.ScoreLeft, UDim2.new(0.05, 0, 0.108, 0), 
					UDim2.new(0.455, 0, 0.415, 0), "Out", "Quad", 0.25)
				wait(0.26)	
				sd.setProperty(Gui.Gameplay.Round.ScoreLeft, "Text", 
					tostring(fpsUtilsMd.getWins(lp.Team)))
				sd.TweenSizeAndPosition(Gui.Gameplay.Round.ScoreLeft, UDim2.new(0.05, 0, 0.088, 0), 
					UDim2.new(0.455, 0, 0.425, 0), "Out", "Quad", 0.25)
				wait(0.26)
			else
				sd.TweenSizeAndPosition(Gui.Gameplay.Round.ScoreRight, UDim2.new(0.05, 0, 0.108, 0), 
					UDim2.new(0.495, 0, 0.415, 0), "Out", "Quad", 0.25)
				wait(0.26)
				sd.setProperty(Gui.Gameplay.Round.ScoreRight, "Text", 
					tostring(fpsUtilsMd.getWins(fpsUtilsMd.oppTeam())))
				sd.TweenSizeAndPosition(Gui.Gameplay.Round.ScoreRight, UDim2.new(0.05, 0, 0.088, 0), 
					UDim2.new(0.495, 0, 0.425, 0), "Out", "Quad", 0.25)
				wait(0.26)
			end
			wait(2)
		end
		if matchWinner == nil then
			-- scores moves up
			Audios.scoreUp:Play()
			sd.TweenPosition(Gui.Gameplay.Round.ScoreLeft, UDim2.new(0.455, 0, 0.333, 0), "Out", "Quad", 0.55)
			sd.TweenPosition(Gui.Gameplay.Round.ScoreMid, UDim2.new(0.45, 0, 0.344, 0), "Out", "Quad", 0.55)
			sd.TweenPosition(Gui.Gameplay.Round.ScoreRight, UDim2.new(0.495, 0, 0.333, 0), "Out", "Quad", 0.55)
			wait(0.56)
		end
		--out
		sd.fade(Gui.Gameplay.Round.ScoreLeft, 1, 0.75)
		sd.fade(Gui.Gameplay.Round.ScoreMid, 1, 0.75)
		sd.fade(Gui.Gameplay.Round.ScoreRight, 1, 0.75)
		wait(0.75)
	end
	
	if matchWinner then
		local name = matchWinner == game.Teams.Alpha and "S C O R P I O N S" or "S K U L L S"
		sd.setProperty(popupTitle, "Text", name.."   W O N   T H E   G A M E")

		Audios.vicdef:Play()
		sd.fade(popupTitle, -1, 1.25)
		wait(4.5)				
		sd.fade(popupTitle, 1, 0.75)
		wait(0.75)
		
		local prevExp       = lp.Stats.Exp.Value - lp.Stats.ExpInc.Value
		local prevLvl       = levelExpMd.lvl(prevExp)
		local prevPercentage= levelExpMd.percentageToNextLvl(prevExp)
		local prevBar       = 0.1 + prevPercentage * 0.9
		local currExp       = lp.Stats.Exp.Value
		local currLvl       = levelExpMd.lvl(currExp)
		local currPercentage= levelExpMd.percentageToNextLvl(currExp)
		local currBar       = 0.1 + currPercentage * 0.9

		sd.setProperty(popupLevel, "Text", "LVL. "..tostring(prevLvl))
		popupExpBar.br.Size = UDim2.new(prevBar, 0, 1, 0)
		popupExpBar.dr.Size = UDim2.new(prevBar, 0, 1, 0)

		popupExpBar.ImageTransparency = 1
		ga.animateProperty(popupExpBar, "ImageTransparency", 0.66, 0.75)
		popupExpBar.br.ImageTransparency = 1
		ga.animateProperty(popupExpBar.br, "ImageTransparency", 0.55, 0.75)
		popupExpBar.dr.ImageTransparency = 1
		ga.animateProperty(popupExpBar.dr, "ImageTransparency", 0, 0.75)

		sd.fade(popupLevel, -1, 0.75)
		wait(1)
		
		if currLvl == prevLvl then
			Audios.ExpStart:Play()
			popupExpBar.dr:TweenSize(UDim2.new(currBar, 0, 1, 0), "Out", "Quad", 1.5)
			wait(2.5)
			if math.abs(currBar - prevBar) >= 1 then
				md.play(Audios.ExpInc, 0.75, 0.15)
			end
			popupExpBar.br:TweenSize(UDim2.new(currBar, 0, 1, 0), "InOut", "Quad", 0.75)
			wait(0.75)
			Audios.ExpEnd:Play()
		else
			-- loop
			for i = prevLvl, currLvl do
				if i == prevLvl then
					Audios.ExpStart:Play()
					popupExpBar.dr:TweenSize(UDim2.new(1, 0, 1, 0), "Out", "Quint", 1.5)
					wait(1.25)
					md.play(Audios.ExpInc, 1.5)
					popupExpBar.br:TweenSize(UDim2.new(1, 0, 1, 0), "InOut", "Quad", 1.5)
					wait(1.51)
					
					Audios.rankUp:Play()
					sd.TweenSizeAndPosition(popupLevel, UDim2.new(1,0,0.14,0), 
						UDim2.new(0,0,0.32,0), "Out", "Quint", 0.15)
					wait(0.155)
					sd.setProperty(popupLevel, "Text", "LVL. "..tostring(i+1))
					sd.TweenSizeAndPosition(popupLevel, UDim2.new(1,0,0.12,0), 
						UDim2.new(0,0,0.33,0), "Out", "Quint", 0.15)
					wait(0.151)
					
					popupExpBar.dr.Size = UDim2.new(0, 0, 1, 0)
					popupExpBar.br.Size = UDim2.new(0, 0, 1, 0)
					wait(0.12)
				elseif i < currLvl then					
					popupExpBar.dr:TweenSize(UDim2.new(1, 0, 1, 0), "InOut", "Quint", 2.0)
					wait(1.75)
					md.play(Audios.ExpInc, 2.0)
					popupExpBar.br:TweenSize(UDim2.new(1, 0, 1, 0), "InOut", "Quad", 2.0)
					wait(2.01)
					
					Audios.rankUp:Play()
					sd.TweenSizeAndPosition(popupLevel, UDim2.new(1,0,0.14,0), 
						UDim2.new(0,0,0.32,0), "Out", "Quint", 0.15)
					wait(0.155)
					sd.setProperty(popupLevel, "Text", "LVL. "..tostring(i+1))
					sd.TweenSizeAndPosition(popupLevel, UDim2.new(1,0,0.12,0), 
						UDim2.new(0,0,0.33,0), "Out", "Quint", 0.15)
					wait(0.151)
					
					popupExpBar.dr.Size = UDim2.new(0, 0, 1, 0)
					popupExpBar.br.Size = UDim2.new(0, 0, 1, 0)
				else
					popupExpBar.br.ImageTransparency = 0.55					
					popupExpBar.dr:TweenSize(UDim2.new(currBar, 0, 1, 0), "Out", "Quint", 1.5)  
					wait(1.25)
					md.play(Audios.ExpInc, 1.5)
					popupExpBar.br:TweenSize(UDim2.new(currBar, 0, 1, 0), "InOut", "Quad", 1.5)
					wait(1.51)
					Audios.ExpEnd:Play()
				end
			end
		end
				
		wait(3)
		ga.animateProperty(popupExpBar, "ImageTransparency", 1, 0.75)
		ga.animateProperty(popupExpBar.br, "ImageTransparency", 1, 0.75)
		ga.animateProperty(popupExpBar.dr, "ImageTransparency", 1, 0.75)
		sd.fade(popupLevel, 1, 0.75)
		ga.animateProperty(blur, "Size", 0, 3)
		wait(3)
	else
		-- next round start in
		sd.fade(popupSub, -1, 0.75)
		wait(0.75)
		
		-- countdown
		wait(0.5)
		local t = 5
		sd.setProperty(popupTimer, "Text", tostring(t))
		spawn(function()
			wait(0.25)
			Audios.secBeep:Play()	
		end)
		sd.fade(popupTimer, -1, 0.75)
		wait(0.75)	
		while t >= 1 do
			wait(0.35)
			
			sd.TweenSizeAndPosition(popupTimer, UDim2.new(1, 0, 0.108, 0), 
				UDim2.new(0, 0, 0.41, 0), "Out", "Quad", 0.15)
			wait(0.16)
			
			t = t - 1
			sd.setProperty(popupTimer, "Text", tostring(t))
			Audios.secBeep:Play()
			
			sd.TweenSizeAndPosition(popupTimer, UDim2.new(1, 0, 0.088, 0), 
				UDim2.new(0, 0, 0.42, 0), "Out", "Quad", 0.15)
			wait(0.16)
			
			wait(0.35)
		end
		
		-- everything fades out
		wait(1)
		sd.fade(popupSub, 1, 1)
		sd.fade(popupTimer, 1, 1)
		ga.animateProperty(blur, "Size", 0, 2)
		wait(2)
		blur.Enabled = false
	end
	lpVars.inRoundIntermission.Value = false
	warn(tick()-tt)
end

function md.setFinalScreenCam(matchWinner)
	local st = tick()
	print("set final screen")	
	--if lpVars.atHome.Value == true then return end

	--game.Players.LocalPlayer.PlayerScripts.ControlScript.Disabled = true
	lpVars.inFinal.Value = true	-- force setting heads
	--[[for i, plr in ipairs(matchWinner:GetPlayers()) do  -- show head, now set that in cameraMd
		setHeadRemote:Fire(true, plr.Character)
	end--]]
	lp.PlayerScripts.Variables.DisableCamera.Value = true

	inHeliMd.setNormalLighting()
	game.Lighting.HeliFade.Enabled = false
	--specMd.stopSpectating()
	specLocalEvent:Fire("stop")
	md.showMessage("The more you play, the more credit you gain!", 100)
	if lp.Team and matchWinner then
		Audios[lp.Team == matchWinner and "Win" or "Lose"]:play()
	end
	
	cam.FieldOfView = 85	
	cam.CFrame = camFarFinal
	wait(1)
	ga.animateCFrame(cam, "CFrame", camCloseFinal, 10)
	wait(5)
	warn("final cam animation:", tick() - st)
end

function sd.setTimerText(t)
	if t < 0 then
		t = 0
	end
	local sec = t % 60
	local min = math.floor(t / 60)
	sd.setProperty(scoreBarTimer, "Text", string.format("%02d:%02d", min, sec))
end

function md.setScoreBarEnabled(b)
	Gui.Gameplay.Top.Visible = b
end

-- make this compatible with different game modes
function md.onScoreChanged(val, team)
	if lp.Neutral or lp.Team == nil then 
		return 
	end
	local side  = team == lp.Team and "Left" or "Right"
	local frame = Gui.Gameplay.Top[side].Shape
	local total = fpsUtilsMd.getTotalScore(team)
	if total == 0 then
		total = 1
	end
	if val > total then
		val = total
	end
	-- animations needed
	-- should be the total amount of players
	sd.setProperty(frame.Score, "Text", string.format("%d", val))
	if side == "Right" then
		frame.Bar.Size     = UDim2.new(val/total, 0, 1, 0)	
	else
		frame.Bar.Position = UDim2.new(1-val/total, 0, 0, 0)
		frame.Bar.Size     = UDim2.new(val/total, 0, 1, 0)
	end
end

function md.setFpsLighting()
	game.Lighting.EmotionColor.Enabled = true
	game.Lighting.DirtBlur.Enabled = true
	game.Lighting.DirtBloom.Enabled = true
	--game.Lighting.ColorCorrection.Enabled = true
	game.Lighting.Blur4Round.Enabled = false
end

function md.setFpsCam()
	cam.FieldOfView = 85
end

function md.setFpsGui()
	Gui.Gameplay.Visible = true
	md.showScoreBar()
	Gui.Gameplay.Lenses.Visible = true
	md.setFpsCam()
	md.setFpsLighting()
end

function md.showMessage(str, t)
	spawn(function()
		sd.setProperty(Gui.Gameplay.GlobalMsg, "Text", str)
		sd.fade(Gui.Gameplay.GlobalMsg, -1, .25)
		wait(t + .25)
		sd.fade(Gui.Gameplay.GlobalMsg, 1, .25)
	end)
end

function md.showHardpointMessage(teamAlive, sec)
	md.showMessage(string.format("%ss have %d seconds to catch up", teamAlive.Name, sec), 3)
end

function md.setup()
	rep.SharedVars.FPSTimer.Changed:connect(function()
		if rep.Stage.Value == "Match" then
			sd.setTimerText(rep.SharedVars.FPSTimer.Value)
		end
	end)
	fpsUtilsMd.getScoreObj(game.Teams.Alpha).Changed:connect(function()
		md.onScoreChanged(fpsUtilsMd.getScore(game.Teams.Alpha), game.Teams.Alpha)
	end)
	fpsUtilsMd.getScoreObj(game.Teams.Beta).Changed:connect(function()
		md.onScoreChanged(fpsUtilsMd.getScore(game.Teams.Beta), game.Teams.Beta)
	end)
	rep.Stage.Changed:connect(function()
		if rep.Stage.Value == "Match" then
			fpsUtilsMd.waitForFpsToLoad()
			md.setFpsGui()
		end
	end)
	remote.OnClientEvent:connect(function(func, args)
		if func == "roundEnd" then
			md.onRoundEnd(args[1], args[2])
		elseif func == "setFinalScreenCam" then
			print(func)
			md.setFinalScreenCam(args[1])
		elseif func == "showScoreBar" then	-- done in loadFPS()
			md.setScoreBarEnabled(true)
		elseif func == "hideScoreBar" then
			md.setScoreBarEnabled(false)
		elseif func == "rushMode" then
			md.showHardpointMessage(args[1], args[2])
		end
	end)
	
	-- set up local billboard gui for hardpoint markers
	local hpMarkers = {}
	for _, cyl in ipairs(workspace.Map.Hardpoints:GetChildren()) do
		table.insert(hpMarkers, hpMarkerMd.new(cyl))
	end
end

return md
