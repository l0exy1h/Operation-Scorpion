local lp  = game.Players.LocalPlayer
local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local ffc    = game.FindFirstChild
local pwd    = game.GetFullName
local deaths = wfc(workspace, "Deaths")
local isVisBodypart = requireGm("RigInfo").isVisBodypart
for _, death in ipairs(deaths:GetChildren()) do
	death.Touched:connect(function(part)
		print("death brick touched", pwd(part))
		if part.Parent == lp.Character and isVisBodypart(part, "tpp") then
			local humanoid = ffc(lp.Character, "Humanoid")
			if humanoid then
				humanoid.Health = 0
				warn("lp char touched death brick, set humanoid.Health to 0")
			else
				warn("lp char touched death brick but humanoid not found")
			end
		end
	end)
end