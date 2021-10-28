local bulletHoleSystem = {}
local holes = {}
local wfc = game.WaitForChild
local holder = Instance.new("Folder")
do
	holder.Name = "BulletHoles"
	holder.Parent = wfc(workspace, "NonHitbox")
end

local maxHoleCnt = 150
local holeTemp = wfc(script, "BulletHole")

do -- new Hole
	local clone = game.Clone
	function bulletHoleSystem.newHole(rayP1)
		local hole = clone(holeTemp)
		hole.Position = rayP1
		hole.Parent = holder
		return hole
	end
end

do-- onhit
	local insert = table.insert
	local newHole = bulletHoleSystem.newHole
	local destroy = game.Destroy
	function bulletHoleSystem.onHit(rayP1)
		insert(holes, 0, newHole(rayP1))
		if #holes == maxHoleCnt then
			destroy(holes[#holes])
			holes[#holes] = nil
		end
	end
end

return bulletHoleSystem