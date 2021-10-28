local md = {}

-- defs
local tp = game:GetService("TeleportService")
local plrs = game.Players

-- const
local lobbyPlaceId = 1436977294

-- main
function md.main()
	local isVipRoom = _G.gameData.isVipRoom
	
	if not isVipRoom then
		tp:TeleportPartyAsync(lobbyPlaceId, game.Players:GetPlayers())
	else
		--[[local vipServerInstanceId = _G.gameData.vipServerInstanceId
		for _, plr in ipairs(plrs:GetPlayers()) do
			tp:TeleportToPlaceInstance(lobbyPlaceId, vipServerInstanceId, plr)
		end--]]
	end 
end

return md