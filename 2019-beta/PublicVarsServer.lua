local ffc = game.FindFirstChild
local wfc = game.WaitForChild
local rep = game.ReplicatedStorage
local pv = {}
do
	local sv = wfc(rep, "SharedVars")
	local newInstance = Instance.new
	local keyToClass = {
		number     = "NumberValue",
		Color3     = "Color3Value",
		CFrame     = "CFrameValue",
		Vector3    = "Vector3Value",
		string     = "StringValue",
		BrickColor = "BrickColorValue",
		Ray        = "RayValue",
		boolean    = "BoolValue",
		Instance   = "ObjectValue",
		["nil"]    = "ObjectValue",
	}
	function pv.setP(plr, key, value)
		-- print("server: setP", plr, key, value)
		local vars = ffc(plr, "Vars")
		if vars == nil then
			-- print("Vars not found in", plr, "creating one")
			vars        = newInstance("Folder")
			vars.Name   = "Vars"
			vars.Parent = plr
		end
		local xxValue = ffc(vars, key)
		if xxValue == nil then
			-- print(key, "not found in", plr, ".vars creating one")
			xxValue = newInstance(keyToClass[typeof(value)], vars)
			xxValue.Name = key
		end
		xxValue.Value = value
	end
	function pv.set(key, value)
		-- print("server: set", key, value)
		local xxValue = ffc(sv, key)
		if xxValue == nil then
			-- print(key, "not found in rep.sv, creating one")
			xxValue      = newInstance(keyToClass[typeof(value)], sv)
			xxValue.Name = key
		end
		xxValue.Value = value
	end
	-- function pv.initPublicVar(key, type)
	-- 	local xxValue = newInstance(keyToClass[type], sv)
	-- 	xxValue.Name  = key
	-- end
end
return pv