local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local play = requireGm("AudioSystem").play
local connect = game.Changed.Connect

local md = {}

function md.addPurchaseSound(but)
	connect(but.MouseButton1Click, function()
		play("ClickButtonPurchase", "2D")
	end)
end

return md