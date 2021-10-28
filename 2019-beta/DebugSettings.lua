local RS = game:GetService("RunService")
return function()
	local pts = false
	return {
		isServer = RS:IsServer(),
		isClient = RS:IsClient(),
		isStudio = RS:IsStudio(),
		pts = pts,
		placeIds =  {
			Office = pts and 2579981163 or 2581124445,
			Metro  = pts and 2579981163 or 2581124332,
			Yacht  = pts and 2579981163 or 2607077439,
			Resort = pts and 2579981163 or 2662201266,
		},
		tableNames = {
			player = pts and "test_players" or "os_players",
			server = pts and "test_servers" or "os_servers",
		},
		currVersion = 1.10,
		bombDefusalMaxPlayers = 14,
		maxPlayerImbalance = 1,
		teamAutoShuffleInVoting = true,
		teamAutoShuffleAfterRound = false,

		-- mainframe
		matchmakingEnabled = true,
		-- testingCharacters = true,    -- only the tpp and fpp animations. chars spawn directly
		-- shorterWaitInHeli = true, 	
			-- decrease the wating time in helicopter
		-- extraWaitingBeforeMatch = true,  
			-- assume everyone is joined either through fs or qj
			-- disallow random join
			-- disabling this will separate the lobby and the match place
		healthRegenSpeed = 2,
		healthRegenDelay = 5,

		-- fastProgression = true,
		sqlEnabled = true, 	-- download data from server and upload data to server
		-- testData = true,
		preMatchEnabled = true,
		matchEnabled = true,
		showtimeEnabled = true,
		votingEnabled = true,
		-- votingDontEnd = true,

		

		-- gamemode/match
		-- atkCanDefuse = true,
		-- infiniteRounds = true,
		-- roundDontEnd = true,
		-- fastInvade = true,
		-- oneRoundOnly = true,
		-- twoRoundsOnly = true,
		-- teamKillEnabled = true,
		-- littleDamage = true,

		-- environment
		-- brighterLighting = true,

		-- fpp
		-- infiniteAmmo = true,
		-- bulletHoles = true,
		-- statsPanel = true,
		-- fppCamToggle = true,
		particleEnabled = true,

		-- tpp
		-- renderSelfTpp = true,  -- toggling is auto enabled
		-- canSpectateEveryone = true,  -- even your enemies

		-- lobby
		-- fasterMatchMaking = true,
		-- lobbyMatchmakingAllowSinglePlayer = true,
		-- smallRooms = true,
		-- showTestSkins = true,
	}
end