local wfc  = game.WaitForChild
local rep = game.ReplicatedStorage
local pv = {}
do
	local ffc = game.FindFirstChild
	local sv = wfc(rep, "SharedVars")
	function pv.waitForPObj(plr, key)
		return wfc(wfc(plr, "Vars"), key)
	end
	function pv.waitForP(plr, key)
		return wfc(wfc(plr, "Vars"), key).Value
	end	
	function pv.getP(plr, key)
		local val = ffc(wfc(plr, "Vars"), key)
		return val and val.Value or nil
	end
	function pv.waitFor(key)
		return wfc(sv, key).Value 
	end
	function pv.waitForObj(key)
		return wfc(sv, key)
	end
	function pv.get(key)
		local val = ffc(sv, key)
		return val and val.Value or nil
	end
end
return pv