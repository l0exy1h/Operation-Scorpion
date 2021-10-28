local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local plrs = game.Players
local lp   = plrs.LocalPlayer
local function requireGm(name)
	return require(wfc(gm, name))
end
local ss = game.ServerStorage
local function requireSm(name)
	return require(wfc(ss, name))
end
local pms        = requireSm("Permissions")
local events     = wfc(rep, "Events")
local chatServer = requireGm("Network").loadRe(wfc(events, "Chat"), {socketEnabled = true})	
local printTable = requireGm("TableUtils").printTable

-- connect to 

local getC   = game.GetChildren
local ts     = game:GetService("TextService")
local filter = ts.FilterStringAsync
-- last = 0

local tags = {
	y0rkl1u = 'GOD',
	y0rkl0u = 'DOG',

	cbmaximillian = 'Fake',
	josie_elaine  = 'Fake',	

	bluegrassmonkey = 'Actor',
	geeq12          = 'Modeler',
	Raftre          = '911 GT3',

	eliz1014 = 'Ashbringer',
	sidnad10        = 'Developer',
}

chatServer.listen("chat", function(sender, channel, text)
	-- print(tick() - last)
	-- last = tick()
	if not (sender and channel and text) then return end

	local filtered  = filter(ts, text, sender.UserId)
	local receivers = {}
	local tag       = nil

	local senderName = sender.Name

	-- get receivers
	if channel == "team" then
		if sender.Team then
			for _, plr in ipairs(getC(plrs)) do
				if plr.Team == sender.Team then
					receivers[#receivers+1] = plr
				end
			end
		else
			warn(sender, "atteptes to send a team message but team is nil. changing to global message")
			channel = "global"
		end
	end
	if channel == "global" then
		receivers = getC(plrs)
	end

	-- get team
	local team = "Neutral"
	if sender.Team then
		team = sender.Team.Name
	end

	-- get tag
	local rag = nil
	if channel == "team" then
		tag = "Team"
	elseif channel == "global" then
		tag = tags[senderName]
		if not tag and pms.hasPermission(sender) then
			tag = "Dev"
		end
	end

	for _, plr in ipairs(receivers) do
		pcall(function()
			local str = filtered:GetChatForUserAsync(plr.UserId)
			chatServer.fireClient(plr, "chat", tag, senderName, str, team)
		end)
	end
end)

