local wfc = game.WaitForChild
local db = require(wfc(wfc(game.ReplicatedStorage, "GlobalModules"), "DebugSettings"))()

return {
	-- fpp
	sprint        = Enum.KeyCode.LeftShift,
	pause         = Enum.KeyCode.BackSlash,
	crouch        = Enum.KeyCode.LeftControl,
	crouch2       = Enum.KeyCode.C,
	moveForward   = Enum.KeyCode.W,
	moveLeft      = Enum.KeyCode.A,
	moveRight     = Enum.KeyCode.D,
	moveBack      = Enum.KeyCode.S,
	weapon1       = Enum.KeyCode.One,
	weapon2       = Enum.KeyCode.Two,
	equipment     = Enum.KeyCode.Three,
	leanLeft      = Enum.KeyCode.Q,
	leanRight     = Enum.KeyCode.E,
	aimKey        = Enum.KeyCode.LeftAlt,
	cycleFireMode = Enum.KeyCode.B,
	reload        = Enum.KeyCode.R,
	jump          = Enum.KeyCode.Space,
	plantOrDefuse = Enum.KeyCode.V,
	dropBomb      = Enum.KeyCode.G,

	dance         = Enum.KeyCode.T,

	weaponPickUp  = Enum.KeyCode.X,
	
	camLock       = db.fppCamToggle and Enum.KeyCode.O or -1,
	toggleTpp = Enum.KeyCode.LeftBracket,
	toggleFpp = Enum.KeyCode.RightBracket,

	toggleChat = Enum.KeyCode.Comma,
	globalChat = Enum.KeyCode.Slash,
	teamChat   = Enum.KeyCode.Period,

	toggleScoreboard = Enum.KeyCode.Tab,
}
