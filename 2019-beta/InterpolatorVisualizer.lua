local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local function printNum(a)
	print(string.format("%.4f", a))
end

local lp = game.Players.LocalPlayer
local mouse = lp:GetMouse()

-- local interpolatorSpring = {}
-- do -- spring
-- 	local f = wfc(rep, "f")
-- 	local pd = wfc(rep, "pd")
-- 	local td = wfc(rep, "td")
-- 	local spring
	
-- 	local function refreshSpring()
-- 		print("new spring")
-- 		spring = requireGm("NumericSpring").new(f.Value, pd.Value, td.Value, {x0 = mouse.Y})
-- 	end
-- 	refreshSpring()
-- 	f.Changed:Connect(refreshSpring)
-- 	pd.Changed:Connect(refreshSpring)
-- 	td.Changed:Connect(refreshSpring)

-- 	function interpolatorSpring.step(dt, y)
-- 		return spring.step(dt, y)
-- 	end
-- end

local interpolatorPulse = {}
do
	local f  = wfc(rep, "f")
	local pd = wfc(rep, "pd")
	local td = wfc(rep, "td")
	local T = wfc(rep, "T")
	local pulse
	do -- init and reset
		local function refresh()
			print("new pulse")
			pulse = requireGm("NumericPulse").new(f.Value, pd.Value, td.Value, T.Value)
		end
		refresh()
		f.Changed:Connect(refresh)
		pd.Changed:Connect(refresh)
		td.Changed:Connect(refresh)
		T.Changed:Connect(refresh)
	end

	-- input
	local uis = game:GetService("UserInputService")
	uis.InputBegan:Connect(function(input, g)
		if g then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pulse.pulse()
		end		
	end)

	-- output
	function interpolatorPulse.step(dt)
		local sy = mouse.ViewSizeY
		local y = pulse.step(dt)
		printNum(y)
		return sy * 0.5 - y * sy * 0.25
	end
end

-- visualizr
-- requires the interpolator to have methods down below
--  .step(dt) => the height in pixels
local interpolator = interpolatorPulse
local visualizer = {}
do
	workspace.CurrentCamera.CFrame = CFrame.new(-184.552719, 51.1555328, -13.9272203, -0.120243356, 0.980522037, -0.155300975, -0, 0.156436011, 0.987688184, 0.992744505, 0.11876294, -0.0188103877)
	local sg = wfc(script, "ScreenGui")
	sg.Parent = wfc(lp, "PlayerGui")
	local holder = wfc(sg, "Holder")
	local dots = {}
	do -- new dot
		local id = 0
		local function getPos(y, x)
			return UDim2.new(1, -x, 0, y)
		end
		local dotTemp = wfc(sg, "Dot")
		dotTemp.Parent = nil
		local clone = game.Clone
		local destroy = game.Destroy
		function visualizer.newDot(y, x)
			local self = {}
			
			id = id + 1
			self.id = tostring(id)
			 
			local dot = clone(dotTemp)
			dot.Position = getPos(y, x)
			dot.Parent = holder
			
			function self.step()
				if dot.AbsolutePosition.X < 0 then
					self.destroy()
				end
			end
			
			function self.destroy()
				destroy(dot)
				dots[self.id] = nil
			end
			
			dots[self.id] = self
		end
	end

	spawn(function()
		local rs = game:GetService("RunService").RenderStepped
		local x = 0
		while true do
			local y = interpolator.step(wait(rs), mouse.Y)
			visualizer.newDot(y, x)
			for _, dot in pairs(dots) do
				dot.step()
			end
			holder.Position = UDim2.new(0, x, 0, 0)
			x = x - 3
		end
	end)
end