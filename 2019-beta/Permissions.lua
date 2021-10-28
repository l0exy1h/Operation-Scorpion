local pms = {}

local permissionLevels = {
	["Player1"] = 1,
	["Player2"] = 1,
	["Player3"] = 1,
	["Player4"] = 1,
	["Player5"] = 1,
	["Player6"] = 1,

	["y0rkl1u"]       = 1,
	["y1rkl0u"]       = 1,
	["cbmaximillian"] = 1,

	["y0rkl0u"]       = 2,
	["144hertz"]      = 2,
	["Vedrakkerous"]  = 2,
	["sidnad10"]      = 2,
	["W1dg3tz"]       = 2,
	["viscosity_b3d"] = 2,
	["XLR"]           = 2,
}

function pms.hasPermission(plr, lvl)
	if type(plr) ~= "string" then
		plr = plr.Name
	end
	lvl = lvl or 1000
	local permissionLevel = permissionLevels[plr]
	return permissionLevel and permissionLevel <= lvl
end

return pms