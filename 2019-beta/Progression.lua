-- math functions for level and exp relationship
-- should not put any data store shit here (put them in server storage)
local md = {
	scorePerKill = 100,
	scorePerDamage = 1,
	scorePerHeadshot = 50,
	scorePerPlant = 200,
	scorePerDefuse = 200,
	scorePerRoundVictory = 50,
	scorePerMatchVictory = 100,
	penaltyMoneyMult = 0, 	-- no money if quit match early
}

do -- editions
	local moneyMultipliers = {
		[3] = 1 / 25,
		[2] = 1 / 50,
		[1] = 1 / 100,
		[0] = 1 / 200,
	}
	local experienceMultipliers = {
		[3] = 2,
		[2] = 1.6,
		[1] = 1.25,
		[0] = 0.85,
	}
	function md.getMoneyAndExpMultiplier(highestEditionLevel)
		return moneyMultipliers[highestEditionLevel], experienceMultipliers[highestEditionLevel]
	end
end

local floor = math.floor
function md.getLevelInt(exp)
	return 1 + floor((exp ^ 0.62) * 0.01)
end
function md.getLevelFloat(exp)
	return 1 + (exp ^ 0.62) * 0.01
end
function md.getPercentage(exp)
	local l = md.getLevelFloat(exp)
	return l - floor(l)
end

return md
