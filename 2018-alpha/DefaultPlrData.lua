local md = {}

local wfc = game.WaitForChild
local rep = game.ReplicatedStorage
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local debugSettings = requireGm("DebugSettings")()
-- local currVersion = requireGm("GameVersion")

function md.cloneAll(plr)
	if debugSettings.testData then
		return {
			user_id   = plr.UserId,
			user_name = plr.Name,  	-- update this every time.

			first_login_version = 0.01,
			last_login_version = debugSettings.currVersion,
			
			exp       = 100000,
			level     = 25,
			money     = 23333333,
			all_money = 0,
			
			headshots     = 0,
			kills         = 0,
			casual_wins   = 0,
			damage        = 0,
			assists       = 0,
			deaths        = 0,
			bullets_hit   = 0,
			bullets_fired = 0,

			highestEditionLevel = 1, 		-- @todo
			has_edition1 = true,   -- should only upload this to sql server.
			has_edition2 = false,
			has_edition3 = false,
			expMult = debugSettings.fastProgression and 100 or 1,
			moneyMult = debugSettings.fastProgression and 100 or 1,

			loadouts = {
				[1] = {		-- attachments here, wip
					weapons = {
						[1] = {weaponName  = "VSSM Vintorez", attachments = {
								Optic = "TA31H Acog",
							}, 
						},
						[2] = {weaponName  = "MP5A3", attachments = {
								Muzzle = "Osprey Suppressor",
								Optic = "ET Holographic Sight",
								Stock = "MP5A3 Closed Stock",
							}, 
						},
					},
					dance = "Bawk Bawk",
					skin = "Default",
				},
			},
			weapons = {
				M4A1 = {attachments = {}, skins = {}, kills = 79, },
				["USP .45"] = {attachments = {}, skins = {}, },
			},
			dances = {Default = true, },
			gun_skins = {},
			crates = {},
		}
	else
		return {
			user_id   = plr.UserId,
			user_name = plr.Name,  	-- update this every time.

			first_login_version = debugSettings.currVersion,
			last_login_version = debugSettings.currVersion,
			
			exp       = 0,
			level     = 1,
			money     = 0,
			all_money = 0,
			
			headshots     = 0,
			kills         = 0,
			casual_wins   = 0,
			damage        = 0,
			assists       = 0,
			deaths        = 0,
			bullets_hit   = 0,
			bullets_fired = 0,

			highestEditionLevel = 0,
			has_edition1 = false,   
			has_edition2 = false,
			has_edition3 = false,
			expMult = debugSettings.fastProgression and 100 or 1,
			moneyMult = debugSettings.fastProgression and 100 or 1,

			loadouts = {
				[1] = {		-- attachments here, wip
					weapons = {
						[1] = {weaponName  = "M4A1", attachments = {}, },
						[2] = {weaponName  = "USP .45", attachments = {}, },
					},
					dance = "Default",
					skin = "Default",
				},
			},
			weapons = {
				M4A1 = {attachments = {}, skins = {}},
				["USP .45"] = {attachments = {}, skins = {}, },
			},
			dances = {Default = true, },
			gun_skins = {},
			crates = {},
		}
	end
end

return md