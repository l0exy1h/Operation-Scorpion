local ffs = {}

local rep         = game.ReplicatedStorage
local wfc         = game.WaitForChild
local gm          = wfc(rep, "GlobalModules")
local printTable  = require(wfc(gm, "TableUtils")).printTable
local getChildren = game.GetChildren

local footstepsLib = wfc(wfc(rep, "Sounds"), "FootSteps")
local footsteps    = {}   --footsteps[matPreset][stance]
for _, u in ipairs(getChildren(footstepsLib)) do
	local t1 = {}
	for _, v in ipairs(getChildren(u)) do
		t1[v.Name] = getChildren(v)
	end
	footsteps[u.Name] = t1
end

local matPresets = {
	Plastic       = "Stone",
	Wood          = "Wood",
	Slate         = "Stone",
	Concrete      = "Stone",
	CorrodedMetal = "Metal",
	DiamondPlate  = "Metal",
	Foil          = "Stone",
	Grass         = "Grass",
	Ice           = "Ice",
	Marble        = "Stone",
	Granite       = "Stone",
	Brick         = "Stone",
	Pebble        = "Stone",
	Sand          = "Sand",
	Fabric        = "Stone",
	SmoothPlastic = "Stone",
	Metal         = "Metal",
	WoodPlanks    = "Wood",
	Cobblestone   = "Stone",
	Water         = "Water",
	Rock          = "Stone",
	Glacier       = "Ice",
	Snow          = "Snow",
	Sandstone     = "Stone",
	Mud           = "Mud",
	Basalt        = "Stone",
	CrackedLava   = "Mud",
	Neon          = "Stone",
	Glass         = "Stone",
	Asphalt       = "Stone",
	LeafyGrass    = "Grass",
	Salt          = "Ice",
	Limestone     = "Stone",
	Pavement      = "Stone",
	Air           = "Air",
}
function ffs.getStepSound(mat, stance)
	assert(typeof(mat) == "EnumItem" or warn("mat =", mat))
	assert(stance == "Crouch" or stance == "Walk" or stance == "Run" or warn("invalid stance", stance))
	local matPreset = matPresets[mat.Name] or "Wood"
	return footsteps[matPreset][stance]
end

return ffs