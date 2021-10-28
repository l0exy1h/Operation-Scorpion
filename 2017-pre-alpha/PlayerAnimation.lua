-- defs
print("0.1")
local rep = game.ReplicatedStorage
local aplr = require(script:WaitForChild("AnimatedPlayer"))
print("initializing playeranimation")
require(game.ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("Loading")).loaded("AnimatedPlayer")
local plrs = game.Players
	local lp = plrs.LocalPlayer
		local lpScripts = lp:WaitForChild("PlayerScripts")
			local lpVars = lpScripts:WaitForChild("Variables")
		local lpGui = lp:WaitForChild("PlayerGui")
			local specGui = lpGui:WaitForChild("ScreenGui"):WaitForChild("Spec")
local aliveFolder = workspace:WaitForChild("Alive")
local mainRemote = rep:WaitForChild("Events"):WaitForChild("MainRemote")
local cameraMd = require(script:WaitForChild("AnimatedPlayer"):WaitForChild("CameraEffects"))
local uis = game:GetService("UserInputService")
local gm = rep:WaitForChild("GlobalModules")
	local fpsUtilsMd = require(gm:WaitForChild("FpsUtils"))
	local sd = require(gm:WaitForChild("ShadedTexts"))
local ts = game:GetService("TextService")
local testVec = Vector2.new(1000, 1000)

-- funcs
local aplrs = {}
local function createAPlr(rbxChar)
	warn("create custom char for", rbxChar.Name)
	local plr = plrs:GetPlayerFromCharacter(rbxChar)
	if plr then
		aplrs[plr.Name] = aplr.new(plr)
	else
		warn("player not found for", rbxChar)
	end
end

-- helper function for setValue
-- return a table of strings
local function splitStringBy(str, c)
	local ret = {}
	local l = 1 
	while true do
		local sp, _ = string.find(str, c, l)
		if sp then
			local r = sp - 1
			table.insert(ret, string.sub(str, l, r))
			l = sp + 1
		else
			table.insert(ret, string.sub(str, l)) 
			break 
		end
	end
	return ret
end

-- setup event listeners
mainRemote.OnClientEvent:connect(function(func, args)
	if func == "changeHealth" then
		local victimName = args[1]
		local newHealth  = args[2]
		local aplr = aplrs[victimName]
		warn("health change:", victimName, newHealth)
		if aplr then
			if newHealth < aplr.health then
				aplr.lastDmgTick = tick()
			end
			aplr.health = newHealth
		end
	elseif func == "setValue" then
		local plrName   = args[1]
		local path      = args[2]
		local value     = args[3]
		
		local aplr = aplrs[plrName]
		if aplr then
			-- the path is like "xxx.yyy.zzz", i can xxx/yyy/zzz a field
			local cur = aplr		-- current pointer (initialied to self)
			local fields = splitStringBy(path, "%.")
			local suc, msg = pcall(function()
				for i = 1, #fields do
					local field = fields[i]
					--warn(field) 
					if i == #fields then
						cur[field] = value
					else
						cur = cur[field]
					end
				end	
			end)
			if not suc then
				warn("setValue/setLocalValue: "..path.." is an invalid path; "..msg)
			end
		end
	elseif func == "resetAmmo" then
		local aplr = aplrs[lp.Name]
		if aplr then
			aplr:resetAmmo()
		end
	elseif func == "resetHealth" then
		local aplr = aplrs[lp.Name]
		if aplr then
			aplr:resetHealth()
		end
	elseif func == "clearBodies" then
		workspace.Ragdolls:ClearAllChildren()
	elseif func == "resetTVnGlass" then
		if workspace.Map:FindFirstChild("TV") then
			for _, v in ipairs(workspace.Map.TV:GetChildren()) do
				local tv = v
				tv.Part:FindFirstChildOfClass("Sound"):Play()
				tv.TV.SpotLight.Enabled = true
				for _, effect in ipairs(tv.TV.effect:GetChildren()) do
					if effect:IsA("Beam") then
						effect.Enabled = true
					end
				end
			end
		end
		if workspace.Map:FindFirstChild("glass") and workspace.Map.glass:WaitForChild("break") then
			--[[workspace.Map.glass["break"]:ClearAllChildren()
			for _, glass in ipairs(rep.MapRestore.BreakableGlasses:GetChildren()) do
				glass.Parent = workspace.Map.glass["break"]
			end--]]
			local originalFolder = workspace.Map.glass["break"] 
			for _, glass in ipairs(workspace.Map.glass["broken"]:GetChildren()) do
				glass.Transparency = glass.SavedTransparency.Value
				glass.SavedTransparency:Destroy()
				glass.CanCollide = true
				glass.Parent = originalFolder
			end 
		end
		for _, pt in ipairs(workspace.Map:GetDescendants()) do
			if pt:IsA("BasePart") and pt.Name == "light" then
				local l = pt:FindFirstChildOfClass("SpotLight") or pt:FindFirstChildOfClass("SurfaceLight") or pt:FindFirstChildOfClass("PointLight")  
				l.Enabled = true
				pt.Transparency = 0
			end
		end
	end
end)

-- remove player models if the player is leaving
local function removeModels(plrName, f)
	local model = f:FindFirstChild(plrName)
	if model then model:Destroy() end
end
plrs.PlayerRemoving:connect(function(plr)
	local plrName = plr.Name
	removeModels(plrName, workspace.Clothes)
	removeModels(plrName, workspace.Ragdolls)
end)

-- spectating control
local specList  = {}					    -- aplrs inside
local specIndex = 1
local specMode  = "teamOnly"			-- changed it to local for security

-- remote for specMode changing (for hardpoint)
mainRemote.OnClientEvent:connect(function(func, args)
	if func == "rushMode" then
		warn("client: spec: change specMode to: everyone")
		specMode = "everyone"
	elseif func == "Spec::changeMode" then
		warn("client: spec: change specMode to:", args[1])
		specMode = args[1]
	end
end)

-- decide if the spectating gui should show up
spawn(function()
	while wait(1) do
		local oldStatus = specGui.Visible
		local newStatus = not fpsUtilsMd.aliveQ(lp) and lpVars.atHome.Value == false and rep.Stage.Value == "Match"
		
		if specMode == "teamOnly" then
			newStatus = newStatus and fpsUtilsMd.getLives(lp.Team) > 0
		elseif specMode == "everyone" then
			newStatus = newStatus and fpsUtilsMd.getLivesCntForBothTeam() > 0
		else
			error("specMode error", specMode)
		end
		specGui.Visible = newStatus
			
		specGui.ArrowLeft.Modal = specGui.Visible
		if oldStatus ~= newStatus and newStatus then
			uis.MouseIconEnabled = true
		end
	end
end)

-- update the text in the specGui
local textSize = specGui.plrName.text.TextSize
local textFont = specGui.plrName.text.Font
local function setBar(str)
	sd.setText(specGui.plrName, str)
	local tsz = ts:GetTextSize(str, textSize, textFont, testVec).X
	if tsz < 180 then
		tsz = 180
	end
	tsz = tsz + 2.5 * specGui.Size.Y.Offset
	specGui.ArrowLeft.Position  = UDim2.new(0.5, -tsz/2, 0, 3)
	specGui.ArrowRight.Position = UDim2.new(0.5, tsz/2-specGui.Size.Y.Offset, 0, 3)
end

local function spectate(aplr)
	cameraMd.connect(aplr)
	setBar(aplr.name)
end

-- get the list of aplrs available for spectating
local function updateSpecList()
	warn("new speclist")
	specList = {}
	for plrName, aplr in pairs(aplrs) do
		if aplr.isAlive then
			if specMode == "everyone" or aplr.plr.Team == lp.Team then
				table.insert(specList, aplr)
				warn(aplr.name)
			end
		end
	end
end

-- connections for spec gui arrows
specGui.ArrowLeft.MouseButton1Click:connect(function()
	updateSpecList()
	specIndex = specIndex - 1
	if specIndex < 1 then
		specIndex = #specList
	end
	if #specList then
		spectate(specList[specIndex])
	end
end)

specGui.ArrowRight.MouseButton1Click:connect(function()
	updateSpecList()
	specIndex = specIndex + 1
	if specIndex > #specList then
		specIndex = 1
	end
	if #specList then
		spectate(specList[specIndex])
	end
end)

local specLocalEvent = script:WaitForChild("SpecLocal")
specLocalEvent.Event:connect(function()
	cameraMd.disconnect()
	-- how about the bars?
end)

-- main
if lp:WaitForChild("QuickJoined").Value == true then
	for _, rbxChar in ipairs(aliveFolder:GetChildren()) do
		createAPlr(rbxChar)
	end
	aliveFolder.ChildAdded:connect(createAPlr)
	updateSpecList()
	if specList[1] then
		spectate(specList[1])
	end
else
	print("alivefolder connected")
	aliveFolder.ChildAdded:connect(createAPlr)
end

print("playeranimation initialized")
require(game.ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("Loading")).loaded("PlayerAnimation")

-- dev cheats
-----------------------------------------

-- wall hacking
local wallHack = false
local uis = game:GetService("UserInputService") 
uis.InputBegan:connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local keyPressed = input.KeyCode
		if keyPressed == Enum.KeyCode.H and lp.Name == 'y0rkl1u' then
			wallHack = not wallHack
			warn(string.format("wallHack = %s", tostring(wallHack)))
		end
	end
end)
if lp.Name == 'y0rkl1u' then
	while true do
		for name, _aplr in pairs(aplrs) do
			if plrs:FindFirstChild(name) then
				if _aplr.customChar and _aplr.customChar:FindFirstChild("Torso") then
					local guiHolder = _aplr.customChar.Torso
					if wallHack and guiHolder:FindFirstChild("hack") == nil then
						warn("inserting wall hack for", name)
						local sur = Instance.new("SurfaceGui")
						sur.Name = "hack"
						sur.AlwaysOnTop = true
		
						local fr = Instance.new("Frame")
						fr.BackgroundColor3 = _aplr.plr.TeamColor.Color
						fr.Size = UDim2.new(1, 0, 1, 0)
						fr.Parent = sur
						
						for n = 0, 5 do 
							local insert = sur:Clone()
							insert.Face = n
							insert.Parent = guiHolder
						end
					elseif not wallHack and guiHolder:FindFirstChild("hack") then
						for _, v in ipairs(guiHolder:GetChildren()) do
							if v.Name == "hack" then
								v:Destroy()
							end
						end
					end
				else
					warn(string.format("aplr %s doesnt have a customchar or torso %s %s", name, tostring(_aplr.customChar), tostring(_aplr.customChar:FindFirstChild("Torso"))))
				end
			end
		end
		wait(1)
	end
end