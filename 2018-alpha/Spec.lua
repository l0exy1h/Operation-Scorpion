local md = {}

-- defs
local plrs    = game.Players
local lp      = plrs.LocalPlayer
local rep     = game.ReplicatedStorage
local lpVars  = script.Parent.Parent.Variables
local setHead = script.Parent.Parent.PlayerAnimation.SetHead
local specGui = lp:WaitForChild("PlayerGui"):WaitForChild("ScreenGui"):WaitForChild("Spec")
local uis     = game:GetService("UserInputService")
local gm      = rep:WaitForChild("GlobalModules")
local errMd   = require(gm:WaitForChild("ErrorHandling"))
local sd      = require(gm:WaitForChild("ShadedTexts"))
local fpsUtilsMd = require(script.Parent.Parent.FpsUtils)
local remote  = rep.Events.MainRemote
local ts      = game:GetService("TextService")
local testVec = Vector2.new(1000, 1000)
local plrs = game.Players
	local lp = plrs.LocalPlayer
		local lpScripts = lp:WaitForChild("PlayerScripts")
			local aplr = lp:WaitForChild("PlayerAnimation")
				local cameraMd = require(aplr:WaitForChild("CameraEffects"))

-- vars
local plrList = {}					-- chars inside
local index   = 1
local mode = "teamOnly"			-- changed it to local for security
md.goal = nil
md.curr = nil 							-- added checking: md.curr in plrList

local function getPlayerList()
	plrList = {}
	for i, char in ipairs(workspace.Alive:GetChildren()) do
		local plrName = char.Name
		if game.Players:FindFirstChild(plrName) then
			if mode == "everyone" or plrs[plrName].Team == lp.Team then
				if fpsUtilsMd.aliveQ(char) then
					table.insert(plrList, char)
				end
			end
		end
	end
end

local function setBar(str)
	sd.setProperty(specGui.plrName, "Text", str)
	local tsz = ts:GetTextSize(str, specGui.plrName.text.TextSize, specGui.plrName.text.Font, testVec).X
	if tsz < 180 then
		tsz = 180
	end
	tsz = tsz + 2.5 * specGui.Size.Y.Offset
	specGui.ArrowLeft.Position  = UDim2.new(0.5, -tsz/2, 0, 3)
	specGui.ArrowRight.Position = UDim2.new(0.5, tsz/2-specGui.Size.Y.Offset, 0, 3)
end

local function inList(a, list)
	for _, v in ipairs(list) do
		if a == v then return true end
	end
	return false
end

function md.spectate(char)
	md.curr = char
	if inList(char, plrList) then
		for i,v in ipairs(workspace.Alive:GetChildren()) do
			if v:FindFirstChild("Stats") then
				v.Stats.Client.IsMe.Value = false
			end
		end
		char.Stats.Client.IsMe.Value = true
		setBar(char.Name)
	end
end

function md.stopSpectating()
	if lpVars.Spectate.Value then
		lpVars.Spectate.Value.Stats.Client.IsMe.Value = false
		setHead:Fire(true, lpVars.Spectate.Value)		-- add head back
	end
	lpVars.Spectate.Value = nil
	setBar("...")
end

specGui.ArrowLeft.MouseButton1Click:connect(function()
	getPlayerList()
	for i, v in ipairs(plrList) do
		warn(v)
	end
	md.index = md.index - 1
	md.index = md.index < 1 and #plrList or md.index
	md.spectate(plrList[md.index])
end)

specGui.ArrowRight.MouseButton1Click:connect(function()
	getPlayerList()
	md.index = md.index + 1
	md.index = md.index > #plrList and 1 or md.index
	md.spectate(plrList[md.index])
end)

function md.setup()
	-- remote for mode changing (for hardpoint)
	remote.OnClientEvent:connect(function(func, args)
		if func == "rushMode" then
			warn("client: spec: change mode to: everyone")
			mode = "everyone"
		elseif func == "Spec::changeMode" then
			warn("client: spec: change mode to:", args[1])
			mode = args[1]
		end
	end)
	
	spawn(function()
		while wait(1) do
			local en = specGui.Visible
			local tmp = not fpsUtilsMd.aliveQ(lp) and lpVars.atHome.Value == false and rep.Stage.Value == "Match"
			
			if mode == "teamOnly" then
				tmp = tmp and fpsUtilsMd.getLives(lp.Team) > 0
			elseif mode == "everyone" then
				tmp = tmp and fpsUtilsMd.getLivesCntForBothTeam() > 0
			else
				error("specMode error", mode)
			end
			specGui.Visible = tmp
				
			specGui.ArrowLeft.Modal = specGui.Visible
			if en ~= specGui.Visible and specGui.Visible then
				uis.MouseIconEnabled = true
			end
		end
	end)
end

return md
