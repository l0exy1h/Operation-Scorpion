return {
	fisrtTimeBeta = true,
	lastLoginVersion = "beta.1",
	gears = {
		["M4A1 Carbine"] = {
			kills = 0,
			exp   = 0,
			level = 1,
			headshots = 0,
			owned = true,
			ownedAttcs = {
				["M4 Standard Barrel"] = true,
				["M4 Standard Handle"] = true,
				["M4 Standard Magazine"] = true,
				["M4 Standard Stock"] = true,
				["M4 Iron Sight"] = true,
				["No Muzzle"] = true,
				["No Grip"] = true,
				["No Stock"] = true,
			},
		},
		["USP.45"] = {
			kills = 0,
			exp   = 0,
			level = 1,
			headshots = 0,
			owned = true,
			ownedAttcs = {
				["USP Standard Magazine"] = true,
				["No Muzzle"] = true,
				["No Sight"] = true,
			},
		},
		AK5C = {
			kills = 0,
			exp   = 0,
			level = 1,
			headshots = 0,
			owned = false,
			ownedAttcs = {
				["AK5C Standard Stock"] = true,
				["AK5C Standard Muzzle"] = true,
				["AK5C Standard Magazine"] = true,
				["AK5C Standard Handle"] = true,
				["No Grip"] = true,
				["No Sight"] = true,
				["No Stock"] = true,
			},
		},
		AK74N = {
			kills = 0,
			exp   = 0,
			level = 1,
			headshots = 0,
			owned = false,
			ownedAttcs = {
				["AK74N Standard Barrel"] = true,
				["AK74N Standard Handle"] = true,
				["AK74N Standard Magazine"] = true,
				["AK74N Standard Muzzle"] = true,
				["AK74N Standard Stock"] = true,
				["No Grip"] = true,
				["No Sight"] = true,
				["No Stock"] = true,
			}
		},
		["SCAR-L CQC"] = {
			kills = 0,
			exp   = 0,
			level = 1,
			headshots = 0,
			owned = false,
			ownedAttcs = {
				["SCAR-L Standard Magazine"] = true,
				["SCAR-L Iron Sight I"] = true,
				["No Muzzle"] = true,
				["No Grip"] = true,
			}
		},
		["VSS Vintorez"] = {
			kills = 0,
			exp   = 0,
			level = 1,
			headshots = 0,
			owned = false,
			ownedAttcs = {
				["VSS Vintorez Standard Barrel"] = true,
				["VSS Vintorez Standard Magazine"] = true,
				["VSS Vintorez Standard Stock"] = true,
				["No Muzzle"] = true,
				["No Sight"] = true,
			}
		},
		["Kriss Vector Gen II"] = {
			kills = 0,
			exp   = 0,
			level = 1,
			headshots = 0,
			owned = false,
			ownedAttcs = {
				["Vector Standard Barrel"] = true,
				["Vector Standard Magazine"] = true,
				["Vector Standard Muzzle"] = true,
				["Vector Standard Stock"] = true,
				["Vector Iron Sight"] = true,
				["No Grip"] = true,
				["No Stock"] = true,
			}
		},
	},
	loadouts = {				-- not a key
		loadout1 = {			-- a key
			Primary   = "M4A1 Carbine",
			Secondary = "USP.45",
			customizations = {
				["M4A1 Carbine"] = {
					attcList = {
						Barrel = "M4 Standard Barrel",
						Handle = "M4 Standard Handle",
						Magazine = "M4 Standard Magazine",
						Stock  = "M4 Standard Stock",
						Sight  = "M4 Iron Sight",
						Muzzle = "No Muzzle",
						Grip   = "No Grip",
					},
				},
				["USP.45"] = {
					attcList = {
						Magazine = "USP Standard Magazine",
						Muzzle = "No Muzzle",
						Sight  = "No Sight",
					},
				},
				AK5C = {
					attcList = {
						Stock = "AK5C Standard Stock",
						Muzzle = "AK5C Standard Muzzle",
						Magazine = "AK5C Standard Magazine",
						Handle = "AK5C Standard Handle",
						Grip = "No Grip",
						Sight = "No Sight",
					},
				},
				AK74N = {
					attcList = {
						Barrel = "AK74N Standard Barrel",
						Handle = "AK74N Standard Handle",
						Magazine = "AK74N Standard Magazine",
						Muzzle = "AK74N Standard Muzzle",
						Stock = "AK74N Standard Stock",
						Grip = "No Grip",
						Sight = "No Sight",
					},
				},
				["SCAR-L CQC"] = {
					attcList = {
						Magazine = "SCAR-L Standard Magazine",
						Sight = "SCAR-L Iron Sight I",
						Muzzle = "No Muzzle",
						Grip = "No Grip",
					},
				},
				["VSS Vintorez"] = {
					attcList = {
						Barrel = "VSS Vintorez Standard Barrel",
						Magazine = "VSS Vintorez Standard Magazine",
						Stock = "VSS Vintorez Standard Stock",
						Muzzle = "No Muzzle",
						Sight = "No Sight",
					},
				},
				["Kriss Vector Gen II"] = {
					attcList = {
						Barrel = "Vector Standard Barrel",
						Magazine = "Vector Standard Magazine",
						Muzzle = "Vector Standard Muzzle",
						Stock = "Vector Standard Stock",
						Sight = "Vector Iron Sight",
						Grip = "No Grip",
					},
				},
			},
		},
	}
}