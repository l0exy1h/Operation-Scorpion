local skinLib = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local db         = requireGm("DebugSettings")()
local printTable = requireGm("TableUtils").printTable
local random     = math.random
math.randomseed(tick())


-- local inv360 = 1.0 / 360
local hsv   = Color3.fromHSV
local floor = math.floor
local newC3 = Color3.new
local wfc   = game.WaitForChild

-- add every key-value pair in A to B
local function addToTable(B, A)
	for key, value in pairs(A) do
		B[key] = value
	end
end

-- the skin table and the test allSkins
--------------------------------------
local allSkins = {
	sample = {
		-- for the part that has a texture object
		-- apply on texture.TextureID
		textureId      = "",
		
		-- for the part that has a texture object
		-- apply on texture.Color
		textureColor   = Color3.fromRGB(255, 0, 0),

		-- for the part that has a texture object
		-- apply on the part.Color
		primaryColor   = Color3.fromRGB(255, 0, 0),		
		
		-- for the part that does not have a texture object
		-- apply on the part.Color
		secondaryColor = Color3.fromRGB(0, 255, 0),
		
		-- for the part that has a decal object
		-- apply on the decal.Color
		tertiaryColor  = Color3.fromRGB(0, 0, 255),

		-- unlock req, if nil then this skin is not unlockable
		unlockReq = {key = "weapon kills", value = 1000},

		-- price in credits, if nil then this skin is not buyable
		price = 100,

		-- test skin. this will prevent the skin from showing in the lobby
		-- if debugsettings.showTestSkin is false
		isTestSkin = true,
	},
	dynamicTest1 = {
		-- a function that accepts total elapsed time and returns an color3
		primaryColor = function(tt) 
			local a = (1 / 50) * tt	
			return hsv(a - floor(a), 0.61, 0.73) 
		end,
		-- secondaryColor = hsv(0.63, 0.57, 1),
		isTestSkin = true,
	},
}
skinLib.skins = allSkins

-- group 1 allSkins
--------------------------------------
local group1 = {
	Gold = {
		primaryColor   = newC3(0.6, 0.454902, 0.137255),
		secondaryColor = newC3(0.509804, 0.384314, 0.117647),
		tertiaryColor  = newC3(0.937255, 0.721569, 0.219608),
		unlockReq      = {key = "weapon headshots", value = 1111},
		-- crateName      = "Solid Colors",
		tier           = "Legendary",
	},

	Slime = {
		secondaryColor = newC3(0.297589, 0.424883, 0.290329),
		primaryColor   = newC3(0.5846, 0.720484, 0.172166),
		crateName      = "Solid Colors",
		tier = "Common",
	},
	Leather = {
		primaryColor = newC3( 0.693082, 0.486106, 0.303587),
		secondaryColor = newC3(0.752615, 0.626859, 0.523334),
		crateName      = "Solid Colors",
		tier = "Common",		
	},
	Aquantis = {  
		secondaryColor = newC3(0.203922, 0.203922, 0.203922),
		primaryColor = newC3(0.247059, 0.85098, 0.529412),
		crateName      = "Solid Colors",
		tier = "Common",
	},
	Pearberry  = {
		primaryColor = newC3( 0.886275, 0.419608, 0.34902 ),
		secondaryColor = newC3(0.780392, 0.333333, 0.0117647),
		crateName      = "Solid Colors",
		tier = "Common",

	},
	["Snow White"] = {
		primaryColor = newC3(0.85098, 0.85098, 0.85098),
		secondaryColor = newC3(0.721569, 0.721569, 0.721569),
		crateName      = "Solid Colors",
		tier = "Common",

	},
	Taro = {
		primaryColor = newC3(0.583989, 0.506602, 0.562043),
		secondaryColor = newC3(0.305882, 0.282353, 0.329412),
		crateName      = "Solid Colors",
		tier = "Common",

	},
	Tandoori = {
		primaryColor = newC3(0.767605, 0.303409, 0.164414),
		secondaryColor = newC3(0.823219, 0.733707, 0.00225173),
		crateName      = "Solid Colors",
		tier = "Common",

	},
	Picotin = {
		primaryColor = newC3(0.85098, 0.152941, 0.313726),
		secondaryColor = newC3(0.313726, 0.0431373, 0.160784),
		crateName      = "Solid Colors",
		tier = "Uncommon",
	},
	Prada = {
		primaryColor = newC3(0.678431, 0.12549, 0.12549),
		secondaryColor = newC3(0.454902, 0.0745098, 0.0745098),
		crateName      = "Solid Colors",
		tier = "Uncommon",

	},
	Sheer = {
		primaryColor = newC3(0.313726, 0.231373, 0.764706),
		secondaryColor = newC3(0.227451, 0.207843, 0.384314),
		crateName      = "Solid Colors",
		tier = "Uncommon",

	},
	["Black Ops"] = {
		primaryColor = newC3(0.141176, 0.141176, 0.141176),
		secondaryColor = newC3(0.192157, 0.192157, 0.192157),
		crateName      = "Solid Colors",
		tier = "Uncommon",

	},
	Hermes = {
		primaryColor = newC3(0.85098, 0.34902, 0.0941177),
		secondaryColor = newC3(0.690196, 0.603922, 0.545098),
		crateName      = "Solid Colors",
		tier = "Uncommon",
	},
	["Y0rks Blonde"] = {
		primaryColor   = newC3(0.946736, 0.71225, 0.181268),
		secondaryColor = newC3(0.742161, 0.598086, 0.505273),
		tier           = "Rare",
		crateName      = "Solid Colors",
	},
	Hellfire =   {
		primaryColor   = function(tt) 
			return Color3.fromHSV(
				((math.sin(tt / 3) + 1) / 2) * (12/256), 
				((math.sin(tt / 2) + 1) / 2) * 0.3 + 0.7, 
				0.87
			) 
		end,
		secondaryColor = newC3(0.305882, 0.282353, 0.329412),
		tier           = "Rare",
		crateName      = "Solid Colors",
  },
  Goo = {
    primaryColor = function(tt)
    	return Color3.fromHSV(
				((math.sin(tt / 2) + 1) / 2) * ((144-72)/360) + (72/360), 
				((math.sin(tt / 1.5) + 1) / 2) * 0.3 + 0.7, 
				0.44
			) 
	  end;
    secondaryColor = newC3(0.152941, 0.27451, 0.176471),
    tier = "Rare",
    crateName = "Solid Colors",
  },
	Ragnarok = { -- hidden
		primaryColor = function(tt) 
			local a = (1 / 50) * tt	
			return hsv(a - floor(a), 0.61, 0.73) 
		end,
		secondaryColor = Color3.new(0.305882, 0.282353, 0.329412),
		tier = "Legendary",
		-- crateName = "Solid Colors",
	},
}
addToTable(allSkins, group1)

-- group 2
--------------------------------------
local group2 = {
	["Lime - Hunters Camo"] = {
		primaryColor = Color3.new(0.543852, 0.868452, 0.0309185),
		textureColor = Color3.new(0.709547, 0.978716, 0.600448),
		secondaryColor = Color3.new(0.503442, 0.804194, 0.293437),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Uncommon",
	},
	["Slasher - Hunters Camo"] = {
		primaryColor = Color3.new(0.753929, 0.100151, 0.321945),
		textureColor = Color3.new(0.862418, 0.275667, 0.343769),
		secondaryColor = Color3.new(0.858824, 0.482353, 0.470588),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Uncommon",
	},
	["Bloodtrail - Hunters Camo"] = {
		primaryColor = Color3.new(0.842965, 0.884205, 0.961821),
		textureColor = Color3.new(0.719685, 0.0867037, 0.229623),
		secondaryColor = Color3.new(0.713726, 0.72549, 0.741176),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Common",
	},
	["Tiedye - Hunters Camo"] = {
		primaryColor = Color3.new(0.816543, 0.469854, 0.811252),
		textureColor = Color3.new(0.191226, 0.994007, 0.544722),
		secondaryColor = Color3.new(0.0705882, 0.92549, 0.745098),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Uncommon",
	},
	["Allure - Hunters Camo"] = {
		primaryColor = Color3.new(0.313735, 0.0384221, 0.668474),
		textureColor = Color3.new(0.748017, 0.316103, 0.784566),
		secondaryColor = Color3.new(0.254902, 0.247059, 0.368627),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Common",
	},
	["Curry - Hunters Camo"] = {
		primaryColor = Color3.new(0.819513, 0.647418, 0.053183),
		textureColor = Color3.new(0.877805, 0.50222, 0.241865),
		secondaryColor = Color3.new(0.623529, 0.333333, 0),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Common",
	},
	["Grapefruit - Hunters Camo"] = {
		primaryColor = Color3.new(0.615875, 0.406497, 0.588931),
		textureColor = Color3.new(0.752482, 0.864196, 0.995028),
		secondaryColor = Color3.new( 0.655256, 0.680304, 0.7599),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Common",
	},
	["Pacific - Hunters Camo"] = {
		primaryColor = Color3.new(0.00937114, 0.51304, 0.807963),
		textureColor = Color3.new(0.368371, 0.81242, 0.94582),
		secondaryColor = Color3.new(0.159906, 0.0876129, 0.117055),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Uncommon",
	},
	["Portal - Hunters Camo"] = {
		primaryColor = Color3.new(0.56486, 0.310515, 0.878877),
		textureColor = Color3.new(0.434603, 0.258923, 0.983039),
		secondaryColor = Color3.new(0.611765, 0, 1),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Uncommon",
	},
	["Nova - Hunters Camo"] = {
		primaryColor = Color3.new(0.829217, 0.111801, 0.511865),
		textureColor = Color3.new(0.553213, 0.442155, 0.859028),
		secondaryColor = Color3.new(0.864332, 0.0227322, 0.561299),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Uncommon",
	},
	["Quasar - Hunters Camo"] = {
		primaryColor = Color3.new(0.712256, 0.619417, 0.652535),
		textureColor = Color3.new(0.84485, 0.256559, 0.267705),
		secondaryColor = Color3.new( 0.697848, 0.0118967, 0.0996158),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Common",
	},
	["Evergreen - Hunters Camo"] = {
		primaryColor = Color3.new(0.0487593, 0.388761, 0.309172),
		textureColor = Color3.new(0.0792816, 0.306458, 0.102208),
		secondaryColor = Color3.new(0.855185, 0.719815, 0.476504),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Common",
	},
	["Mainframe - Hunters Camo"] = {
		primaryColor = Color3.new(1, 0.690196, 0),
		-- textureColor = Color3.new(0.368627, 0.345098, 0.321569),
		secondaryColor = Color3.new(0.792157, 0.796079, 0.819608),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Rare",
	},
	["Raw - Hunters Camo"] = {
		secondaryColor = Color3.new(0.623529, 0.631373, 0.67451),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Rare",
	},
	["A-Team - Hunters Camo"] = {
		primaryColor = Color3.new(0.2, 0.196078, 0.172549),
		textureColor = Color3.new(0.34902, 0.364706, 0.329412),
		secondaryColor = Color3.new(0.388235, 0.372549, 0.384314),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Uncommon",
	},
	["Heartstroke - Hunters Camo"] = {
		primaryColor = Color3.new(0.924767, 0.460884, 0.505069),
		textureColor = Color3.new(0.857581, 0.0220149, 0.471916),
		secondaryColor = Color3.new(0.670588, 0.329412, 0.45098),
		textureId = "rbxassetid://2779326419",
		crateName = "Hunters Camo",
		tier = "Rare",
	},
	["Hellfire - Hunters Camo"] = {
		textureId = "rbxassetid://2779326419",
		primaryColor = function(tt) 
			return Color3.fromHSV(
				((math.sin(tt / 3) + 1) / 2) * (12/256), 
				((math.sin(tt / 2) + 1) / 2) * 0.3 + 0.7, 
				0.87
			) 
		end,
		textureColor   = Color3.new(1, 0.690196, 0),
		secondaryColor = Color3.new(0.388235, 0.372549, 0.384314),
		tier           = "Legendary",
		crateName      = "Hunters Camo",
  },
  --     secondaryColor (userdata) : 1, 0.737255, 0.815686
  --     textureColor (userdata) : 1, 1, 1
  --     textureId (string) : rbxassetid://2879291869
  -- }
}
addToTable(allSkins, group2)

local specials = {
	["onlyU"] = {
		secondaryColor = Color3.new(1, 0.737255, 0.815686),
		textureId      = "rbxassetid://2879291869",
	}
}
addToTable(allSkins, specials)

local group3 = {
	["Molten - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.827451, 0.658824, 0.0509804),
		textureId = "rbxassetid://2921129483",
		tier = "Common",
		crateName = "Crazy Ones",
	},	
	["Nano - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.529412, 0.572549, 0.690196),
		textureId = "rbxassetid://2920992895",
		tier = "Common",
		crateName = "Crazy Ones",
	},	
	["Twilly - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.815686, 0.815686, 0.635294),
		textureId = "rbxassetid://2921043161",
		tier = "Common",
		crateName = "Crazy Ones",
	},	
	["Lucent - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.678431, 0.560784, 0.976471),
		textureId = "rbxassetid://2921086513",
		tier = "Common",
		crateName = "Crazy Ones",
	},	
	["Marcie - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.796079, 0.796079, 0.117647),
		textureId = "rbxassetid://2921128421",
		tier = "Common",
		crateName = "Crazy Ones",
	},	
	["Citron Noir - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.215686, 0.545098, 0.972549),
		textureId = "rbxassetid://2921043514",
		tier = "Common",
		crateName = "Crazy Ones",
	},	

	["Ecarlate - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.972549, 0.486275, 0.498039),
		textureId = "rbxassetid://2921043514",
		tier = "Uncommon",
		crateName = "Crazy Ones",
	},	
	["Acqua - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.976471, 0.976471, 0.976471),
		textureId = "rbxassetid://2921085166",
		tier = "Uncommon",
		crateName = "Crazy Ones",
	},	
	["Phantom - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.72549, 0.105882, 0.835294),
		textureId = "rbxassetid://2921042288",
		tier = "Uncommon",
		crateName = "Crazy Ones",
	},	

	["Poison - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new( 0.207843, 0.835294, 0.196078),
		textureId = "rbxassetid://2921042288",
		tier = "Rare",
		crateName = "Crazy Ones",
	},	
	["Dysfunctional - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.729412, 0.776471, 0.827451),
		textureId = "rbxassetid://2921084340",
		tier = "Rare",
		crateName = "Crazy Ones",
	},	
	["Wave Trip - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.976471, 0.0627451, 0.933333),
		textureId = "rbxassetid://2921085746",
		tier = "Rare",
		crateName = "Crazy Ones",
	},	
	["Black Cherry - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.976471, 0.0509804, 0.686275),
		textureId = "rbxassetid://2921086253",
		tier = "Rare",
		crateName = "Crazy Ones",
	},	

	["Elixir - Crazy Ones"] = {
		secondaryColor = Color3.new(0.180392, 0.180392, 0.188235),
		textureColor = Color3.new(0.796079, 0.615686, 0.972549),
		textureId = "rbxassetid://2921044896",
		tier = "Legendary",
		crateName = "Crazy Ones",
	},	
}
addToTable(allSkins, group3)

local group4 = {
	["Cow"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989086103",
		tier = "Common",
		crateName = "Animals",
	},	
	["Rabbit"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989090214",
		tier = "Common",
		crateName = "Animals",
	},	
	["Sloth"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989090844",
		tier = "Common",
		crateName = "Animals",
	},	


	["Bear"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989087852",
		tier = "Uncommon",
		crateName = "Animals",
	},	
	["Zebra"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989086674",
		tier = "Uncommon",
		crateName = "Animals",
	},	


	["Tiger"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989091049",
		tier = "Rare",
		crateName = "Animals",
	},	
	["Wolf"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989088605",
		tier = "Rare",
		crateName = "Animals",
	},	
	["Cheetah"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989085868",
		tier = "Rare",
		crateName = "Animals",
	},	


	["James"] = {
		primaryColor = Color3.new(0.0666667, 0.0666667, 0.0666667),
		secondaryColor = Color3.new(0.160784, 0.160784, 0.164706),
		textureId = "rbxassetid://2989089576",
		tier = "Legendary",
		crateName = "Animals",
	},	
	["Chameleon"] = {
		primaryColor = function(tt) 
			local a = (1 / 50) * tt	
			return hsv(a - floor(a), 0.61, 0.73) 
		end,
		secondaryColor = Color3.new(0.305882, 0.282353, 0.329412),
		-- textureId = "rbxassetid://2989089576",
		tier = "Legendary",
		crateName = "Animals",
	},
}
addToTable(allSkins, group4)

-- helper functions
--------------------------------------

function skinLib.getSkin(skinName)
	local skin = allSkins[skinName]
	if skin then
		return skin
	else
		warn("skinLib error: no skin is named", skinName)
	end
end

function skinLib.getSkinReq(skinName)
	local skin = skinLib.getSkin(skinName)
	if not skin then
		warn("skinLib.getSkinReq failed because", skinName, "is not found")
		return 
	end
	local r = skin.unlockReq 
	if r then
		return r.key, r.value
	end
end

-- pre process the base iamges
local baseImages = {}
for _, v in ipairs(wfc(script, "BaseImages"):GetChildren()) do
	if v:IsA("ImageLabel") then
		baseImages[v.Name] = v
	end
end

-- @param skin: a skin table
-- returns the image of the skin based on the color and baseimage
-- may return nil is color or baseimage is not found.
function skinLib.getSkinImage(skin)
	local baseImage = skin.crateName and baseImages[skin.crateName] or nil
	if baseImage then
		local color
		if skin.primaryColor and typeof(skin.primaryColor) == "Color3" then
			color = skin.primaryColor
		elseif skin.textureColor and typeof(skin.textureColor) == "Color3" then
			color = skin.textureColor
		elseif skin.secondaryColor and typeof(skin.secondaryColor) == "Color3" then
			color = skin.secondaryColor
		elseif skin.tertiaryColor and typeof(skin.tertiaryColor) == "Color3" then
			color = skin.tertiaryColor
		end
		if color then
			baseImage = baseImage:Clone()
			baseImage.ImageColor3 = color
			return baseImage
		end
	end
end

function skinLib.getSourceCrate(skinName)
	local skin = skinLib.getSkin(skinName)
	if not skin then
		return 
	end
	return skin.crateName
end

-- crate logic
-- all the chances are * 100 (percentages)
-----------------------------
local defaultTierDistr = {
	Common    = 75,
	Uncommon  = 22,
	Rare      = 2.23,
	Legendary = 0.77,
}
local tierColors = { 	-- put all colors here
	Common    = Color3.fromRGB(230, 230, 230),
	Uncommon  = Color3.fromRGB(255, 170, 0),
	Rare      = Color3.fromRGB(230, 61, 31),
	Legendary = Color3.fromRGB(230, 13, 64),	
}
function skinLib.getTierColor(tier)
	return tierColors[tier] or Color3.new(1, 1, 1)
end

local defaultCratePrice = 200
-- skinLib.defaultCratePrice = defaultCratePrice
local skinRefundMoneyMult = 0.25
-- skinLib.skinRefundMoneyMult = skinRefundMoneyMult

function skinLib.getRefund(crate)
	return (crate.price or defaultCratePrice) * skinRefundMoneyMult
end

-- will have a chances[skinName] = chance
-- if not, the code will try to configure based on tierDistr
-- 	  and the tiers in the skin 
local allCrates = {
	["Solid Colors"] = {
		price = defaultCratePrice,
	},
	["Hunters Camo"] = {
		price = defaultCratePrice,
	},
	["Crazy Ones"] = {
		price = defaultCratePrice * 2,
	},
	["Animals"] = {
		price = defaultCratePrice * 2,
	},
}

do -- sortSkinsInCrate
	-- currently only support the default tiers.
	-- if going to add more tier options, override crate.getTierOrderDef (the function)
	local function getTierOrderDef(tier)
		return -(tier and defaultTierDistr[tier] or 0)  -- 'after legendary'
	end
	function skinLib.sortSkinsInCrate(crate)
		if type(crate) == 'string' then
			crate = allCrates[crate]
		end
		local ret = {}
		for skinName, _ in pairs(crate.chances) do
			ret[#ret + 1] = skinName
		end
		local getTierOrder = getTierOrderDef
		table.sort(ret, function(sn1, sn2)
			local skin1, skin2   = skinLib.getSkin(sn1), skinLib.getSkin(sn2)
			local order1, order2 = getTierOrder(skin1.tier), getTierOrder(skin2.tier)
			return order1 < order2 or (order1 == order2 and sn1 < sn2)
		end)
		return ret
	end
end

-- preprocess all crate to get the chances[skinName] = chance table
-- and the L[], R[] table
for crateName, crate in pairs(allCrates) do
	if not crate.chances then
		-- setup the chances dict
		local chances = {}
		crate.chances = chances

		-- support custom tierDistr table
		local tierDistr = crate.tierDistr or defaultTierDistr

		-- init skins in tiers
		local skinsInTiers = {}
		local cntInTiers = {}
		local Empty = 0
		for tier, tierChance in pairs(tierDistr) do
			cntInTiers[tier] = 0
			skinsInTiers[tier] = {}
		end

		-- get the skins in this crate in each tier based on the name
		for skinName, skin in pairs(allSkins) do
			if skin.crateName == crateName then
				local tier = skin.tier
				if tier then
					local distr = tierDistr[tier]
					local skinsInTier = skinsInTiers[tier]
					if distr then
						cntInTiers[tier] = cntInTiers[tier] + 1
						skinsInTier[skinName] = skin
					end
				end
			end
		end

		-- chances in each tier
		-- this will take into account that some tier might contain no skins.
		local totalChanceNonEmptyTiers = 0
		for tier, skinsInTier in pairs( skinsInTiers ) do
			if cntInTiers[tier] > 0 then
				totalChanceNonEmptyTiers = totalChanceNonEmptyTiers + tierDistr[tier]
			end
		end
		local chanceForTier = {}
		for tier, tierChance in pairs(tierDistr) do
			chanceForTier[tier] = 100 * (cntInTiers[tier] > 0 and tierChance or 0) / totalChanceNonEmptyTiers
			-- print("chance for tier", tier, "is", chanceForTier[tier])
		end


		-- compute the chances[]
		for tier, skinsInTier in pairs( skinsInTiers ) do
			if cntInTiers[tier] <= 0 then
				warn("crate", crateName, "has a tier", tier, "that has no skins inside")
			else
				local chance = chanceForTier[tier] / cntInTiers[tier]
				for skinName, skin in pairs(skinsInTier) do
					chances[skinName] = chance
				end
			end
		end
	end

	local chances = crate.chances
	if db.isServer then  -- debug output only on server
		print("\n\tSkin system: configured crate", crateName)
		printTable(crate.chances)
	end

	-- by now the crate has a chances table
	-- compute L, R for crate.open()
	local L, R = {}, {}
	crate.L, crate.R = L, R
	do
		local x = 0
		for skinName, chance in pairs(chances) do
			L[skinName] = x

			x = x + chance
			R[skinName] = x 
			-- print(crateName, ".", skinName, "chance = ", chance, "interval =", L[skinName], R[skinName])
		end
	end

	crate.sortedSkins = skinLib.sortSkinsInCrate(crate)
end

function skinLib.getCrate(crateName)
	return allCrates[crateName]
end

do -- getRandomWeaponName
	local weaponLibCh = wfc(rep, "Weapons"):GetChildren()
	local n = #weaponLibCh

	-- @param [args.weapons] (a table with keys being weaponName), required by owned only
	function skinLib.getRandomWeaponName(args)
		args = args or {}
		local ownedOnly = args.weapons ~= nil
		if ownedOnly then
			local weapons = args.weapons
			assert(weapons, "invalid argument. missing args.weapons")
			local ret = {}
			for weaponName, _ in pairs(weapons) do
				ret[#ret + 1] = weaponName
			end
			return ret[random(1, #ret)]
		else
			return weaponLibCh[random(1, #weaponLibCh)].Name
		end
	end
end

-- @param [args.weapons] (a table with keys being weaponName)
function skinLib.openCrate(crate, args)
	if type(crate) == 'string' then
		crate = allCrates[crate]
	end
	local L, R = crate.L, crate.R
	local r = random() * 100
	local k -- 	let k be the skin name such that L[k] <= r <= R[k]
	-- print(r)
	for skinName, _ in pairs(crate.chances) do
		if L[skinName] <= r and r < R[skinName] then
			k = skinName
			break
		end
	end
	return k, skinLib.getRandomWeaponName(args)
end
skinLib.crates = allCrates

return skinLib