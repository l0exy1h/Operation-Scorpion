local md = {}

local plrs      = game.Players
local lp        = plrs.LocalPlayer
local lpScripts = lp:WaitForChild("PlayerScripts")
local lpVars    = lpScripts:WaitForChild("Variables")

local lpGui       = lp:WaitForChild("PlayerGui")
local gameplayGui = lpGui:WaitForChild("Gameplay")
local fpsGui      = gameplayGui:WaitForChild("FPS")
local cam         = workspace.CurrentCamera
local hud         = fpsGui:WaitForChild("HUD")

local rep = game.ReplicatedStorage
local events = rep:WaitForChild("Events")
local remote = events:WaitForChild("MainRemote")

local rep = game.ReplicatedStorage
local gm  = rep:WaitForChild("GlobalModules")
local ga  = require(gm:WaitForChild("GeneralAnimation"))
local sd  = require(gm:WaitForChild("ShadedTexts"))
local fpsUtils   = require(gm:WaitForChild("FpsUtils"))
local levelExpMd = require(gm:WaitForChild("LevelExp"))
local audioMd    = require(gm:WaitForChild("AudioPlay"))

local intermissionGui = gameplayGui:WaitForChild("Intermission")
local popupTitle      = intermissionGui:WaitForChild("Title")
local popupSub        = intermissionGui:WaitForChild("Sub")
local popupTimer      = intermissionGui:WaitForChild("Timer")
local popupLevel      = intermissionGui:WaitForChild("Level")
local popupExpBar     = intermissionGui:WaitForChild("ExpBar")

local lighting = game.Lighting
local blur = lighting:WaitForChild("Blur4Round")

local audios = rep:WaitForChild("Audios")

-- round intermission
----------------------------------------------
remote.OnClientEvent:connect(function(func, args)
	if func == "roundEnd" then
		local roundWinner = args[1]
		local matchWinner = args[2]
		if lpVars.atHome.Value == false then
			md.onRoundEnd(roundWinner, matchWinner)
		end
	end
end)

function md.onRoundEnd(roundWinner, matchWinner)

	lpVars.inRoundIntermission.Value = true
	hud.Spec.Visible = false
	print("roundWinner = ", roundWinner, "myTeam is", lp.Team)
	local tt = tick()
	
	blur.Size = 0
	blur.Enabled = true
	ga.animateProperty(blur, "Size", 22, 0.5)

	-- if all enemies leave the game
	local enemyFled = roundWinner == lp.Team and #fpsUtils.oppTeam():GetPlayers() == 0
	
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
	
	audios.vicdef:Play()
	sd.fade(popupTitle, -1, 1.25)   
	wait(2.5)
	sd.fade(popupTitle, 1, 1)
	wait(1)

	-- scores
	--in
	if enemyFled then
		wait(1.5)
	else
		sd.setPosition(intermissionGui.ScoreLeft, UDim2.new(0.455, 0, 0.425, 0))
		sd.setPosition(intermissionGui.ScoreMid, UDim2.new(0.45, 0, 0.435, 0))
		sd.setPosition(intermissionGui.ScoreRight, UDim2.new(0.495, 0, 0.425, 0))
		if roundWinner == nil then
			sd.setProperty(intermissionGui.ScoreLeft, "Text", 
				tostring(fpsUtils.getWins(lp.Team)))
			sd.setProperty(intermissionGui.ScoreRight, "Text", 
				tostring(fpsUtils.getWins(fpsUtils.oppTeam())))
		elseif roundWinner == lp.Team then
			sd.setProperty(intermissionGui.ScoreLeft, "Text", 
				tostring(fpsUtils.getWins(lp.Team) - 1))
			sd.setProperty(intermissionGui.ScoreRight, "Text", 
				tostring(fpsUtils.getWins(fpsUtils.oppTeam())))
		else
			sd.setProperty(intermissionGui.ScoreLeft, "Text", 
				tostring(fpsUtils.getWins(lp.Team)))
			sd.setProperty(intermissionGui.ScoreRight, "Text", 
				tostring(fpsUtils.getWins(fpsUtils.oppTeam()) - 1))
		end
		sd.fade(intermissionGui.ScoreLeft, -1, 0.75)
		sd.fade(intermissionGui.ScoreMid, -1, 0.75)
		sd.fade(intermissionGui.ScoreRight, -1, 0.75)
		wait(1)
		--enlarge & shrink      
		if roundWinner then
			audios.roundScore:Play()    
			if roundWinner == lp.Team then
				sd.TweenSizeAndPosition(intermissionGui.ScoreLeft, UDim2.new(0.05, 0, 0.108, 0), 
					UDim2.new(0.455, 0, 0.415, 0), "Out", "Quad", 0.25)
				wait(0.26)  
				sd.setProperty(intermissionGui.ScoreLeft, "Text", 
					tostring(fpsUtils.getWins(lp.Team)))
				sd.TweenSizeAndPosition(intermissionGui.ScoreLeft, UDim2.new(0.05, 0, 0.088, 0), 
					UDim2.new(0.455, 0, 0.425, 0), "Out", "Quad", 0.25)
				wait(0.26)
			else
				sd.TweenSizeAndPosition(intermissionGui.ScoreRight, UDim2.new(0.05, 0, 0.108, 0), 
					UDim2.new(0.495, 0, 0.415, 0), "Out", "Quad", 0.25)
				wait(0.26)
				sd.setProperty(intermissionGui.ScoreRight, "Text", 
					tostring(fpsUtils.getWins(fpsUtils.oppTeam())))
				sd.TweenSizeAndPosition(intermissionGui.ScoreRight, UDim2.new(0.05, 0, 0.088, 0), 
					UDim2.new(0.495, 0, 0.425, 0), "Out", "Quad", 0.25)
				wait(0.26)
			end
			wait(2)
		end
		if matchWinner == nil then
			-- scores moves up
			audios.scoreUp:Play()
			sd.TweenPosition(intermissionGui.ScoreLeft, UDim2.new(0.455, 0, 0.333, 0), "Out", "Quad", 0.55)
			sd.TweenPosition(intermissionGui.ScoreMid, UDim2.new(0.45, 0, 0.344, 0), "Out", "Quad", 0.55)
			sd.TweenPosition(intermissionGui.ScoreRight, UDim2.new(0.495, 0, 0.333, 0), "Out", "Quad", 0.55)
			wait(0.56)
		end
		--out
		sd.fade(intermissionGui.ScoreLeft, 1, 0.75)
		sd.fade(intermissionGui.ScoreMid, 1, 0.75)
		sd.fade(intermissionGui.ScoreRight, 1, 0.75)
		wait(0.75)
	end
	
	if matchWinner then
		local name = matchWinner == game.Teams.Alpha and "S C O R P I O N S" or "S K U L L S"
		sd.setProperty(popupTitle, "Text", name.."   W O N   T H E   G A M E")

		audios.vicdef:Play()
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
			audios.ExpStart:Play()
			popupExpBar.dr:TweenSize(UDim2.new(currBar, 0, 1, 0), "Out", "Quad", 1.5)
			wait(2.5)
			if math.abs(currBar - prevBar) >= 1 then
				audioMd.play(audios.ExpInc, 0.75, 0.15)
			end
			popupExpBar.br:TweenSize(UDim2.new(currBar, 0, 1, 0), "InOut", "Quad", 0.75)
			wait(0.75)
			audios.ExpEnd:Play()
		else
			-- loop
			for i = prevLvl, currLvl do
				if i == prevLvl then
					audios.ExpStart:Play()
					popupExpBar.dr:TweenSize(UDim2.new(1, 0, 1, 0), "Out", "Quint", 1.5)
					wait(1.25)
					audioMd.play(audios.ExpInc, 1.5)
					popupExpBar.br:TweenSize(UDim2.new(1, 0, 1, 0), "InOut", "Quad", 1.5)
					wait(1.51)
					
					audios.rankUp:Play()
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
					audioMd.play(audios.ExpInc, 2.0)
					popupExpBar.br:TweenSize(UDim2.new(1, 0, 1, 0), "InOut", "Quad", 2.0)
					wait(2.01)
					
					audios.rankUp:Play()
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
					audioMd.play(audios.ExpInc, 1.5)
					popupExpBar.br:TweenSize(UDim2.new(currBar, 0, 1, 0), "InOut", "Quad", 1.5)
					wait(1.51)
					audios.ExpEnd:Play()
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
			audios.secBeep:Play()   
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
			audios.secBeep:Play()
			
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

return md