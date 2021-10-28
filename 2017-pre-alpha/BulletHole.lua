local md = {}

local holeFolder = workspace:WaitForChild("BulletHoles")
local hole = script:WaitForChild("Hole") 
local maxHoleCnt = 150
local holes = {}
local enabled = true

local function makeHoleObj(point)
	local newHole = hole:Clone()
	newHole.Position = point
	newHole.Parent = holeFolder
	return newHole
end

function md.makeHole(point)
	table.insert(holes, 0, makeHoleObj(point))
	if #holes == maxHoleCnt + 1 then
		holes[#holes]:Destroy()
		holes[#holes] = nil
	end
end

return md