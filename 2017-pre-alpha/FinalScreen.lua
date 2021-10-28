local md = {}

local plrs = game.Players
local lp = plrs.LocalPlayer
local lpScripts = lp:WaitForChild("PlayerScripts")
local lpVars = lpScripts:WaitForChild("Variables")

local lpGui = lp:WaitForChild("PlayerGui")
local gameplayGui = lpGui:WaitForChild("Gameplay")
local fpsGui = gameplayGui:WaitForChild("FPS")
local cam = workspace.CurrentCamera

local events = rep:WaitForChild("Events")
local remote = events:WaitForChild("MainRemote")

local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local ga = require(gm:WaitForChild("GeneralAnimation"))
local screenCamFx = require(gm:WaitForChild("ScreenCamFx"))

local camFarFinal            = workspace:WaitForChild("Map"):WaitForChild("Final"):WaitForChild("camFarFinal").CFrame
local camCloseFinal          = workspace.Map.Final:WaitForChild("camCloseFinal").CFrame

function md.setFinalScreen(matchWinner)
	print("set final screen")   
	local st = tick()

	lpVars.inFinal.Value       = true -- force setting heads
	lpVars.DisableCamera.Value = true

	screenCamFx.setLighting("Final")
	screenCamFx.setCameraFx("Final")
	specLocalEvent:Fire("stop")
	-- md.showMessage("The more you play, the more credit you gain!", 100)

	if lp.Team and matchWinner then
		Audios[lp.Team == matchWinner and "Win" or "Lose"]:play()
	end
	
	cam.CFrame = camFarFinal
	wait(1)
	ga.animateCFrame(cam, "CFrame", camCloseFinal, 10)
	wait(5)

	warn("final cam animation:", tick() - st)
end

-- connect!
remote.OnClientEvent:connect(function(func, args)
	if func == "setFinalScreen" then
		local matchWinner = args[1]
		md.setFinalScreen(matchWinner)
	end
end)

return md