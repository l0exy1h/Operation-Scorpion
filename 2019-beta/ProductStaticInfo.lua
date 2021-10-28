local psi = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local ffc = game.FindFirstChild

local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

print("psi.1")

local weaponLib     = wfc(rep, "Weapons")
local attachmentLib = wfc(rep, "Attachments")
local skinLib       = requireGm("GunSkins")

print("psi.2")

local clone  = game.Clone
local ffcWia = game.FindFirstChildWhichIsA

do
	local prices = {
		M4A1                = 0,
		["USP .45"]         = 0,
		["MK16 Scar-L"]     = 750,
		["SIG MCX Virtus"]  = 2000,
		AK74N               = 7500,
		MP5A3               = 1250,
		["VSSM Vintorez"]   = 15000,
		["Kriss Vector G2"] = 10000000000,
		XM8                 = 1000000000,
		["FNX-45"]          = 35000,
		["UMP45"]           = 22000,
	}
	function psi.getWeaponPrice(name)
		return prices[name]
	end
end
do
	local reqs = {
		M4A1                = {},
		["USP .45"]         = {},
		["MK16 Scar-L"]     = {{key = "level", value = 3}},
		["SIG MCX Virtus"]  = {{key = "level", value = 7}},
		AK74N               = {{key = "level", value = 22}},
		MP5A3               = {{key = "level", value = 5}},
		["VSSM Vintorez"]   = {{key = "level", value = 35}},
		["Kriss Vector G2"] = {{key = "headshots", value = 199}},
		XM8                 = {{key = "alphaTester"}},
		["FNX-45"]          = {{key = "level", value = 50}},
		["UMP45"]           = {{key = "level", value = 42}},
	}
	function psi.getWeaponReqs(name)
		return reqs[name]
	end
	function psi.isWeaponReqMet(w, d) -- weapon, data
		local bool, msg = true, nil

		local r = psi.getWeaponReqs(w)
		local key = r[1].key
		local val = r[1].value
		if key == "level" then
			local l = d.level or 0
			bool = l >= val
			msg = string.format("Unlock: %d/%d Level", l, val)
		elseif key == "headshots" then
			local h = d.headshots or 0
			bool = h >= val
			msg = string.format("Unlock: %d/%d Headshots", h, val)
		elseif key == "alphaTester" then
			bool = d.first_login_version and d.first_login_version <= 0.01
			msg = "Pre-alpha excluive"
		end

		return bool, msg
	end
end
do
	local reqs = {
		["MG Angled Grip"]           = {{key = "weapon headshots", value = 50}},
		["DD Vertical Grip"]         = {{key = "weapon kills", value = 35}},
		["VD Jet Compensator"]       = {{key = "weapon kills", value = 80}},
		["M4SD Compensator"]         = {{key = "weapon kills", value = 20}},
		["KA Mams"]                  = {{key = "weapon kills", value = 100}},
		["MOE Carbine Stock"]        = {{key = "weapon headshots", value = 20}},
		["TA31H Acog"]               = {{key = "weapon kills", value = 55}},
		["ET Holographic Sight"]     = {{key = "weapon kills", value = 10}},
		["AK74N Tactical Mount"]     = {{key = "weapon headshots", value = 10}},
		["Sake ASR Suppressor"]      = {{key = "weapon kills", value = 70}},		
		["RX6 Reflex"]               = {{key = "weapon headshots", value = 30}},
		["MP5A3 Closed Stock"]       = {{key = "weapon kills", value = 15}},
		["MCX Closed Stock"]         = {{key = "weapon kills", value = 15}},
		["MOE Extended Stock"]       = {{key = "weapon kills", value = 25}},
		["M4A1 Extended Stock"]      = {{key = "weapon kills", value = 25}},
		["Osprey Suppressor"]        = {{key = "weapon headshots", value = 65}},
		["MP5A3 Tactical Handguard"] = {{key = "weapon kills", value = 75}},
		["AK74N Tactical Handguard"] = {{key = "weapon kills", value = 99}},
		["MCX Long Barrel"]          = {{key = "weapon headshots", value = 75}},
		["TR Battle Sight"]          = {{key = "weapon headshots", value = 15}},
		["SRS Red Dot"]              = {{key = "weapon kills", value = 100}},
		["Vector Extended Handguard"]= {{key = "weapon kills", value = 70}},
		["Vector Extended Muzzle"]   = {{key = "weapon kills", value = 200}},
		["M4A1 Short Barrel"]        = {{key = "weapon kills", value = 70}},
		["MK16 Short Barrel"]        = {{key = "weapon kills", value = 70}},
		["MOE AK Stock"]             = {{key = "weapon kills", value = 125}},
		["VSSM Extended Magazine"]   = {{key = "weapon kills", value = 100}},
		["UMP45 Folded Stock"]       = {{key = "weapon kills", value = 20}},
	}
	function psi.getAttachmentReqs(name)
		return reqs[name]
	end
	function psi.isAttachmentReqMet(w, a, d) 	-- weapon, attachment, data
		local bool, msg = true, nil

		-- get the req (a key/value pair) based on if the attc is skin or not
		local isSkin = psi.isSkin(a)
		local key, val, crateName
		if isSkin then
			key, val = skinLib.getSkinReq(a)
			crateName = skinLib.getSkin(a).crateName
		else
			local r = psi.getAttachmentReqs(a)
			key, val = r[1].key, r[1].value
		end

		-- evaluate the req or check if it exists
		if not key then -- no req -> not unlockable
			bool = false
			if isSkin then
				if crateName then
					msg = "Available from the ["..crateName.."] crate"
				end
			end
			if not msg then
				msg = "Not unlockable"
			end
		elseif key == "weapon headshots" then
			local h = d.weapons[w] and d.weapons[w].headshots or 0
			bool = h >= val
			msg = string.format("Unlock: %d/%d Headshots", h, val)
		elseif key == "weapon kills" then
			local k = d.weapons[w] and d.weapons[w].kills or 0
			bool = k >= val
			msg = string.format("Unlock: %d/%d Kills", k, val)
		end

		return bool, msg
	end

	-- @param: the name of the attachment
	-- determine if the "attachment" is actually a skin
	function psi.isSkin(a)
		return skinLib.skins[a] ~= nil
	end

	-- @param a: the name of the attachment
	-- @param data: the sql data of a plr
	-- @param weaponName: any attc/skin belongs to a weapon
	-- determins if the attachment is really "owned" (not through req met)
	function psi.isAttachmentOwned_(a, data, weaponName)
		return psi.isSkin(a) 
			and (data.gun_skins[weaponName] and data.gun_skins[weaponName][a])
			or (data.weapons[weaponName] and data.weapons[weaponName].attachments[a])
	end

	-- @param a: the name of the attachment
	-- @param data: the sql data of a plr
	-- @param weaponName: any attc/skin belongs to a weapon
	-- determins if the attachment is really "owned" or req met
	function psi.isAttachmentOwned(a, data, weaponName)
		return psi.isAttachmentOwned_(a, data, weaponName) or psi.isAttachmentReqMet(weaponName, a, data)
	end

	function psi.isAttachmentEquipped(a, data, slotId, attachpointName)
		return data.loadouts[1].weapons[slotId].attachments[attachpointName] == a
	end

	function psi.isAttachmentUnlockable(a)
		return psi.isSkin(a) and skinLib.getSkinReq(a) ~= nil or (psi.getAttachmentReqs(a) ~= nil)
	end
end
do
	local prices = {
		["MG Angled Grip"]           = 1250,
		["DD Vertical Grip"]         = 300,
		["VD Jet Compensator"]       = 750,
		["M4SD Compensator"]         = 250,
		["KA Mams"]                  = 950,
		["MOE Carbine Stock"]        = 750,
		["TA31H Acog"]               = 500,
		["ET Holographic Sight"]     = 100,
		["AK74N Tactical Mount"]     = 300,
		["Sake ASR Suppressor"]      = 600,
		["RX6 Reflex"]               = 750,
		["MP5A3 Closed Stock"]       = 100,
		["MCX Closed Stock"]         = 100,
		["MOE Extended Stock"]       = 200,
		["M4A1 Extended Stock"]      = 200,
		["Osprey Suppressor"]        = 1500,
		["MP5A3 Tactical Handguard"] = 750,
		["AK74N Tactical Handguard"] = 990,
		["MCX Long Barrel"]          = 2500,
		["TR Battle Sight"]          = 400,
		["SRS Red Dot"]              = 1000,
		["Vector Extended Handguard"]= 700,
		["Vector Extended Muzzle"]   = 1700,
		["M4A1 Short Barrel"]        = 700,
		["MK16 Short Barrel"]        = 700,
		["MOE AK Stock"]             = 1250,
		["VSSM Extended Magazine"]   = 1000,
		["UMP45 Folded Stock"]       = 150,
	}
	function psi.getAttachmentPrice(name) -- only for attc
		return psi.isSkin(name) and skinLib.getSkin(name).price or prices[name]
	end

	-- returns the price
	function psi.isAttachmentBuyable(a) -- for skin and attc
		return psi.isSkin(a) and skinLib.getSkin(a).price or psi.getAttachmentPrice(a)
	end
end

print("psi.3")

local nothing = wfc(script, "DancePic")
-- Instance.new("ImageLabel")
-- nothing.Size = UDim2.new(0,0,0,0)
-- nothing.ImageTransparency = 1
-- nothing.BackgroundTransparency = 1
function psi.getWeaponPic(name)
	local a = ffcWia(weaponLib[name], "ImageLabel")
	if a then
		a.Visible = true
		return clone(a)
	else
		warn("getWeaponPic failed for", name)
		return clone(nothing)
	end
end
function psi.getAttachmentPic(name)
	if psi.isSkin(name) then
		local image = skinLib.getSkinImage(skinLib.getSkin(name))
		if image then
			return image
		end
	else
		local a = ffcWia(attachmentLib[name], "ImageLabel")
		if a then
			a.Visible = true
			return clone(a)
		end
	end
	warn("getAttachmentPic failed for", name)
	return clone(nothing)
end
function psi.getDefaultAttachmentPic(weaponName, attachpointName)
	local a = ffc(weaponLib[weaponName].DefaultAttcPics, attachpointName)
	if a then
		a.Visible = true
		return clone(a)
	else
		warn("getDefaultAttachmentPic failed for", weaponName, attachpointName)
		return clone(nothing)
	end
end
function psi.getDancePic()
	return clone(nothing)
	-- return clone(wfc(script, "DancePic"))
end

do
	local secondaries = {
		["USP .45"] = true,
		["FNX-45"]  = true,
	}
	function psi.isPrimary(name)
		return secondaries[name] == nil
	end
	function psi.isSecondary(name)
		return secondaries[name] ~= nil
	end
end

function psi.getDefaultWeaponTable(name)
	local get = require(weaponLib[name]).getDefaultWeaponTable
	return get and get() or {attachments = {}, skins = {}}
end

return psi