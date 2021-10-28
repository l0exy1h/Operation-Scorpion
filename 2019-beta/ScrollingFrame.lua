-- scrolling frame
-- supporting 2 directions
----------------------------------

local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local plrs = game.Players
local lp   = plrs.LocalPlayer
local function requireGm(name)
	return require(wfc(gm, name))
end
local connect = game.Changed.Connect
local myMath = requireGm("Math")

local scrollingFrame = {}
function scrollingFrame.new(sfh, sf, dir, maxH, sp, decay)
	sp    = sp or 2.5 / 100
	decay = decay or 0.85
	maxH  = (maxH or 2) - 1

	local defPos = sf.Position
	local ds     = 0
	local s      = 0
	local unitX  = dir == "vertical" and 0 or 1
	local unitY  = dir == "horizontal" and 0 or 1
	assert(dir == "vertical" or dir == "horizontal" or warn("invalid dir type", type))

	local self = {
		scrollingEnabled = true
	}

	local cons = {}

	do-- listen to mouse. buggy
		cons[#cons+1] = connect(sfh.MouseWheelForward, function()
			if self.scrollingEnabled then
				ds = ds - sp
			end
		end)
		cons[#cons+1] = connect(sfh.MouseWheelBackward, function()
			if self.scrollingEnabled then
				ds = ds + sp
			end
		end)
	end

	do-- create step function to reduce speed every frame
		spawn(function()
			local hb     = game:GetService("RunService").Heartbeat
			local evwait = game.Changed.Wait
			local clamp  = myMath.clamp
			local newU2 = UDim2.new
			local abs   = math.abs
			spawn(function()
				while sf and sf.Parent == sfh and sfh.Parent and sfh.Parent.Parent and evwait(hb) do
					ds = ds * decay
					if abs(ds) < 1e-3 then
						ds = 0
					end
					s = clamp(s + ds, 0, maxH)
					sf.Position = defPos - newU2(unitX * s, 0, unitY * s, 0)
				end
			end)
		end)
	end

	function self.destroy()
		for _, con in pairs(cons) do
			con:Disconnect()
		end
	end

	return self
end
return scrollingFrame

-- -- test
-- local sfh = wfc(wfc(wfc(lp, "PlayerGui"), "ScreenGui"), "sfh")
-- local sf  = wfc(sfh, "sf")
-- local scrolling = scrollingFrame.new(sfh, sf, "horizontal")

