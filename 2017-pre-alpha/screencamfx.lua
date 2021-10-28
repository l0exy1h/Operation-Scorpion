-- handles non character related camera and lighting effects

local md = {}

local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local ga = require(gm:WaitForChild("GeneralAnimation"))

local lighting = game.Lighting

local cam = workspace.CurrentCamera

function md.setLighting(preset)
	if preset == "Match" then
		game.Lighting.EmotionColor.Enabled      = true
		game.Lighting.DirtBlur.Enabled          = true
		game.Lighting.DirtBloom.Enabled         = true
		--game.Lighting.ColorCorrection.Enabled = true
		game.Lighting.Blur4Round.Enabled        = false
	elseif preset == "Heli" then
		lighting.NV_CC.Enabled             = false
		lighting.NV_Bloom.Enabled          = false
		lighting.EmotionColor.Enabled      = false
		lighting.DirtBlur.Enabled          = false
		lighting.DirtBloom.Enabled         = false
		--lighting.ColorCorrection.Enabled = false
		lighting.Blur4Round.Enabled        = false

		lighting.HeliFade.Enabled = true
	elseif preset == "Final" then
		md.setLighting("Heli")
		lighting.HeliFade.Enabled = false
	else
		error(string.format("preset %s not found", preset))
	end
end

function md.setCameraFx(preset)
	if preset == "Match" then

	elseif preset == "Heli" then
		fpsGui.Lenses.Visible = false
	elseif preset == "Final" then
		fpsGui.Lenses.Visible = false
		cam.FieldOfView = 85
	else
		error(string.format("preset %s not found", preset))
	end
end

return md