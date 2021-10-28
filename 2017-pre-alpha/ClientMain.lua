-- the client-side main
------------------------------------------------

-- defs
local inHeliMd = require(script.InHeli)
--local localMiscHandlerMd = require(script.LocalMiscHandler) -- inside playeranimation
--local instaKillMd = require(script.InstaKill)	-- moved to the server side
local teamTaggerMd = require(script.TeamTagger)
local particleHandlerMd = require(script.ParticleHandler)
local fpsGuiMd = require(script.FpsGui)
--local specMd = require(script.Spec)						-- inside playeranimation
local rep = game.ReplicatedStorage
local lp = game.Players.LocalPlayer
local direstSpawn = rep:WaitForChild("Debug"):WaitForChild("DirectSpawn")
--local playerAnimationMd = require(script.)		-- individual module
local lpVars = lp:WaitForChild("PlayerScripts"):WaitForChild("Variables")
local disableFPScam = lpVars:WaitForChild("DisableCamera") 

-- main

--[[if direstSpawn.Value == true then
	script.Parent:WaitForChild("Variables"):WaitForChild("DisableCamera").Value = false
	particleHandlerMd.setup()
else--]]
	
local quickJoined = lp:WaitForChild("QuickJoined").Value
if quickJoined then
	teamTaggerMd.setup()
	particleHandlerMd.setup()
	fpsGuiMd.setup()
	fpsGuiMd.setFpsGui()	
	
	lpVars.atHome.Value = false
	disableFPScam.Value = false		
	
	-- load characters will automatically wait for data
	-- begin receiving remoteevents
	-- spec some one
	-- show guis
else
	inHeliMd.setUpHeli()
	teamTaggerMd.setup()
	particleHandlerMd.setup()
	fpsGuiMd.setup()
end