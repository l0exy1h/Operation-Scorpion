local md = {}

local plrs = game.Players
local lp = plrs.LocalPlayer

function md.updatePlayerTag(rbxChar)
	--print("updatePlayerTag 1", char.Name)
	local putTag = false
	local plr = plrs:GetPlayerFromCharacter(rbxChar)
	--print("updatePlayerTag: check plr", plr)
	if plr then
		--print("updatePlayerTag: check plr Name: ", plr.Name, lp.Name)
		if plr.Name ~= lp.Name then
			--print("updatePlayerTag: check team color", lp.TeamColor, plr.TeamColor, lp.Team, plr.Team)
			if plr.TeamColor == lp.TeamColor then
				putTag = true
			end
		end
	end
	--print("updatePlayerTag 2", char.Name)
	local customChar = workspace.Characters:FindFirstChild(rbxChar.Name)
	if customChar and customChar:FindFirstChild("Torso") then
		--print("updatePlayerTag 3", char.Name, putTag, char.Torso:FindFirstChild("TeamTag") ~= nil)
		if customChar.Torso:FindFirstChild("TeamTag") and putTag == false then
			customChar.Torso.TeamTag:Destroy()
		elseif customChar.Torso:FindFirstChild("TeamTag") == nil and putTag == true then
			local tt = script:WaitForChild("TeamTag"):Clone()
			tt.Parent = customChar.Torso
			tt.Tag.Text = customChar.Name
			--print("updatePlayerTag put", char.Name)
		end
	end
end

function md.updateTags()
	--print("update tags")
	for i,v in ipairs(workspace.Alive:GetChildren()) do
		--print("\n")
		md.updatePlayerTag(v)
		--print("\n")
	end
end

function md.setup()
	md.updateTags()
	workspace.Alive.ChildAdded:connect(md.updateTags)
	workspace.Alive.ChildRemoved:connect(md.updateTags)
	spawn(function()
		while true do
			wait(3)
			md.updateTags()
		end
	end)
end

return md
