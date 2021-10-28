-- the server-side main
------------------------------------------------

-- defs
local waitMd   = require(script.Wait)
local tpBackMd = require(script.TpBack)
local matchMd  = require(script.Match)
local fpsCoreMd = require(game.ServerScriptService.FPSCore)
local rep = game.ReplicatedStorage
local direstSpawn = rep:WaitForChild("Debug"):WaitForChild("DirectSpawn")

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

game.Close:connect(function()
	sql.query(string.format([[delete from rbxserver where placeid = %d;]], game.PlaceId))	
end)

-- player status update
-- announce death / spawn / adding / removing of players
----------------------------------------
--[[local rep = game.ReplicatedStorage
local events = rep:WaitForChild("Events")
local playerStatusUpdateRemote = events:WaitForChild("PlayerStatusUpdate")
local plrs = game.Players
events:WaitForChild("PlayerRekt"):connect(function(plr)
	playerStatusUpdateRemote:FireAllClients("rekt", plr)
end)
plrs.PlayerAdded:--]]




-- main
----------------------------------------
fpsCoreMd.init()
waitMd.main()
matchMd.main()
tpBackMd.main()
