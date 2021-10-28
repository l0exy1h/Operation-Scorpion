-- scrolling frame
-- supporting 2 directions
----------------------------------
local scrollingList = {}

local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local plrs = game.Players
local lp   = plrs.LocalPlayer
local function requireGm(name)
	return require(wfc(gm, name))
end
local connect = game.Changed.Connect
local myMath  = requireGm("Math")
local ffcWia  = game.FindFirstChildWhichIsA
local newU2   = UDim2.new
local clone   = game.Clone

-- constants
local sp    = 2 / 100
local decay = 0.85

-- @param: sf: should be a list that contains a list ui layout.
--             PADDING MUST BE SCALE
--             and contains initially no gui items
-- @param: [args.transparentOnSides]
function scrollingList.new(sfh, sf, args)
	args = args or {}

	local uiListLayout = ffcWia(sf, "UIListLayout")
	assert(uiListLayout, "scrollingList requires a UIListLayout in sf")

	local dir = uiListLayout.FillDirection == Enum.FillDirection.Horizontal and "horizontal" or "vertical"
	local isCentered = dir == "horizontal" 
		and (uiListLayout.HorizontalAlignment == Enum.HorizontalAlignment.Center) 
		or  (uiListLayout.VerticalAlignment   == Enum.VerticalAlignment.Center)
	local transparentOnSides = args.transparentOnSides

	local defPos = sf.Position
	local ds     = 0		-- speed (varying/decaying)
	local s      = 0 		-- current offset in the direction of dir
	local unitX  = dir == "vertical" and 0 or 1
	local unitY  = dir == "horizontal" and 0 or 1
	local axis   = dir == "horizontal" and "X" or "Y"

	local self = {}
	local cons = {}
	local running = true

	do-- listen to mouse
		local mouse = lp:GetMouse() -- for mouse location
		local uis = game:GetService("UserInputService")
		local function isIn(x, y, g)
			local ap = g.AbsolutePosition
			local as = g.AbsoluteSize
			local b1 = as.X >= 0 and (ap.X <= x and x <= ap.X + as.X) or (ap.X + as.X <= x and x <= ap.X)
			local b2 = as.Y >= 0 and (ap.Y <= y and y <= ap.Y + as.Y) or (ap.Y + as.Y <= y and y <= ap.Y)
			return b1 and b2
		end
		local itMouseWheel = Enum.UserInputType.MouseWheel
		connect(uis.InputChanged, function(input, g)
			if input.UserInputType == itMouseWheel then	
				if isIn(mouse.X, mouse.Y, sfh) then
					ds = ds - input.Position.z * sp
				end
			end
		end)
	end

	do-- clear all children
		for _, v in ipairs(sf:GetChildren()) do
			if v ~= uiListLayout then
				v:Destroy()
			end
		end
	end

	-- only addable. not substractable
	local items = {}
	local gap   = uiListLayout.Padding.Scale
	local listH = -gap --+ (isCentered and 0.2 or 0) 	-- the height (or the width of the list) (scale only)
	do
		local function getListHInc(fr)
			return gap + fr.AbsoluteSize[axis] / sfh.AbsoluteSize[axis]
		end

		local newV2 = Vector2.new
		-- @param: fr: size should be scale only?
		-- @param: opacityController(gui, opacity): don't contain the g as an upvalue 
		function self.add(fr, opacityController)
			fr.Parent = sf

			local item = {
				opacityController = opacityController,
				fr = fr,
			}
			items[#items + 1] = item

			-- update listH
			listH = listH + getListHInc(fr)

			fr.AnchorPoint = newV2(0.5, 0.5)
			function item.getRelPos()
				return (fr.AbsolutePosition[axis] + 0.5 * fr.AbsoluteSize[axis] - sfh.AbsolutePosition[axis]) / sfh.AbsoluteSize[axis]
			end
		end
		function self.clear()
			listH = -gap
			for i, item in ipairs(items) do
				if item.fr and item.fr.Name ~= "PaddingFrame" then
					item.fr:Destroy()
					items[i] = nil
				end
			end
		end

		-- handle window resizing -> recalc the listH
		local cam = workspace.CurrentCamera
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			wait(0.25)
			listH = -gap
			for _, item in ipairs(items) do
				listH = listH + getListHInc(item.fr)
			end
		end)
	end

	do-- create step function to reduce speed every frame and set the opacity
		local hb     = game:GetService("RunService").Heartbeat
		local evwait = game.Changed.Wait
		local clamp  = myMath.clamp
		local newU2  = UDim2.new
		local abs    = math.abs
		local max    = math.max
		local function isRunning()
			return running and sf and sf.Parent == sfh and sfh.Parent and sfh.Parent.Parent
		end

		local a = 0.1                   -- 0.1..0.9 is opaque
		local function opacityCurve(x) 	-- give x. return opacity
			if x < 0 or x > 1 then
				return 0
			elseif x < a then
				return x / a
			elseif x > 1 - a then
				return (1 - x) / a
			else
				return 1 
			end
		end
		
		spawn(function()
			while evwait(hb) and isRunning() do
				-- the speed of scrolling
				ds = ds * decay
				if abs(ds) < 1e-3 then
					ds = 0
				end

				-- calc the offset
				local maxS = max(listH - 1, 0)	-- the maximum offset
				s = s + ds
				if isCentered then
					s = clamp(s, -maxS / 2, maxS/2)
				else
					s = clamp(s, 0, maxS)
				end

				-- the actual offset considering transparency padding
				local _s = s 
				if transparentOnSides and not isCentered then
					_s = s - a
				end
				sf.Position = defPos - newU2(unitX * _s, 0, unitY * _s, 0)

				-- tweak the opacity
				for _, item in ipairs(items) do
					if item.opacityController then
						item.opacityController(item.fr, opacityCurve(item.getRelPos()))
					end
				end
			end
		end)
	end

	function self.destroy()
		self.clear()
		for _, con in pairs(cons) do
			con:Disconnect()
		end
		running = false
	end

	return self
end
return scrollingList
