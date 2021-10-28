local rr3 = {}

local rep       = game.ReplicatedStorage
local wfc       = game.WaitForChild
local gm        = wfc(rep, "GlobalModules")
local myMath    = require(wfc(gm, "Math"))
local rotOnlyCf = myMath.rotOnlyCf
local clamped   = myMath.clamped
local newCf     = CFrame.new
local isA       = game.IsA
local newV3     = Vector3.new
local invCf     = CFrame.new().inverse
local wfc       = game.WaitForChild

function rr3.getCornerCf(part, showCorner)
	local partCf = part.CFrame
	return partCf - rotOnlyCf(partCf) * (part.Size / 2)
end

local getCornerCf = rr3.getCornerCf
function rr3.isPointInPart(p, part)
	if typeof(p) == "Instance" then
		p = p.Position
	end
	p = invCf(getCornerCf(part)) * p
	local sz = part.Size
	return clamped(p.X, 0, sz.X)
		 and clamped(p.Y, 0, sz.Y)
		 and clamped(p.Z, 0, sz.Z)
end

return rr3