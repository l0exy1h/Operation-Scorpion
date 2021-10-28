local rep   = game.ReplicatedStorage
local wfc   = game.WaitForChild
local gm    = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local rf = wfc(wfc(rep, "Events"), "PingRf")
rf.OnClientInvoke = function()
	return true
end