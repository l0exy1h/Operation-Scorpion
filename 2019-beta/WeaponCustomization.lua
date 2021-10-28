local wc          = {}
local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local getC        = game.GetChildren
local sub         = string.sub
local destroy     = game.Destroy
local ffcWia      = game.FindFirstChildWhichIsA
local setPrCFrame = Instance.new("Model").SetPrimaryPartCFrame  -- 
local isA         = game.IsA
local wfc         = game.WaitForChild
local pwd         = game.GetFullName
local newCf       = CFrame.new
local getD        = game.GetDescendants

local myMath      = requireGm("Math")
local printTable  = require(wfc(gm, "TableUtils")).printTable
local getSet      = requireGm("TableUtils").getSet
local cloneTableShallow = require(wfc(gm, "TableUtils")).cloneTableShallow
local weld        = require(wfc(gm, "Welding")).weldModel
local solvePaths  = require(wfc(gm, "StringPathSolver")).solveStringPaths
local solvePath   = require(wfc(gm, "StringPathSolver")).solveStringPath
local setPartsProperty = require(wfc(gm, "Welding")).setPartsProperty
local degToCf     = myMath.degToCf
local random      = math.random

local weaponLib     = wfc(rep, "Weapons")
local attachmentLib = wfc(rep, "Attachments")
local skinLib       = requireGm("GunSkins")

-- the weapon currently has equipped equippedAttachments
-- and now we want to set the attachpoint at a specific attachpointName to a
-- this function will return a new set of attachments
--   with the attc at that attachpoint garuanteed to be a
--   possibily taking out some other attachments considering the CONFLICTS
local specials = {Mount = 1, Barrel = 1,}
function wc.getPreviewAttachments(weaponName, equippedAttachments, attachpointName, a)
	local ret = cloneTableShallow(equippedAttachments)
	ret[attachpointName] = a

	-- skin should have no conflicts
	if attachpointName == "Skin" then
		return ret
	end

	local cas = require(weaponLib[weaponName]).getCompatibleAttachments()
	for k, attachment in pairs(ret) do
		if specials[k] then
			local attachmentData = require(attachmentLib[attachment])
			if attachmentData.getCompatibleAttachments then
				for attachpoint, t in pairs(attachmentData.getCompatibleAttachments()) do
					if t == false then
						cas[attachpoint] = nil
					else
						assert(type(t) == "table")
						cas[attachpoint] = t
					end
				end
			end
		end
	end
	for k, attachment in pairs(ret) do
		if not specials[k] then
			if k ~= "Skin" and (not cas[k] or not cas[k][attachment]) then
				ret[k] = nil
			end
		end
	end	
	return ret
end

-- tells how we perform union operation on stats
-- nil means +
-- "set" means set
local statsUnionMethods = {
	aimMult = "set",
	magSize = "set",
}
-- @param attcs is a dictionary: eg. Optic -> Reflex
-- return: model, stats, aniData, compatibleAttachments
-- @param [args.skinTOffset]: the offset of tt, for customizatino
function wc.get(weaponName, attachments, pp, args)
	args = args or {}
	if type(args) ~= "table" then
		error("wrong args")
	end

	local weaponData = require(weaponLib[weaponName])

	-- initial states
	local model                 = weaponData.getModel("fpp") 	-- tpp guns are disabled
	local compatibleAttachments = weaponData.getCompatibleAttachments()
	local defaultAttachments    = solvePaths(weaponData.getDefaultAttachments(), model)
	local stats                 = weaponData.getStats()
	local aniData               = weaponData.getAniData()
	-- warn(aniData.fppAnimations.holding[1])
	-- warn(aniData.fppAnimations.holding[1].goalC0)
	-- warn(aniData.fppAnimations.holding[1].goalC0.FppLeftArm)
	local invisibleAniparts     = aniData.invisibleAniparts
	local attachpoints          = {}
	local sightChanged          = false
	local rotateMuzzleQ         = false
	for _, v in ipairs(getC(model.attachpoints)) do
		attachpoints[v.Name] = v  -- lding[1].goalC0)
	end

	-- apply attachments
	-- old aniparts are not removed
	-- attachTo points are all removed
	-- attachpoints will only be relocated but not deleted
	-- new attachpoints will be removed
	-- the only anipart that's in the attachpoints folder is the muzzle (as the firepoint)
	local function addAttachment(attachment, attachToName)
		if attachToName == "Skin" then
			print("skipped skin. (skin is not a physical attc)")
			return
		end

		local attachmentData = require(attachmentLib[attachment])
		local attachmentAniData = attachmentData.getAniData()

		-- change stats
		local attachmentStats = attachmentData.getStats()
		for k, v in pairs(attachmentStats) do
			if typeof(v) == "number" then
				if stats[k] then
					local method = statsUnionMethods[k] or "add"
					if method == "add" then
						stats[k] = stats[k] + v
					elseif method == "set" then
						stats[k] = v
					else
						error(string.format("wc: cannot find statsUnionMethods for %s. aborted", k))
					end
				else
					error(string.format("cant find %s in weaponstats", k))
				end
			elseif typeof(v) == "boolean" then
				stats[k] = v
			else
				print("attachment stat type", typeof(v), "not supported.", attachment, k)
			end
			-- print("attachment", attachment, "changed", k, "to", stats[k])
		end

		-- remove default attachment if there is
		if defaultAttachments[attachToName] then
			defaultAttachments[attachToName]:Destroy()
		end

		-- placement
		local newAttachpoints = {}  -- contains new or shifted attachpoints
		local attachTo        = nil
		attachment        = attachmentData.getModel()
		attachment.Parent = model
		for _, v in ipairs(getC(attachment)) do
			local vName = v.Name
			if sub(vName, 1, 2) == "__" then  -- new or shifted attachpoints
				newAttachpoints[sub(vName, 3)] = v
			elseif sub(vName, 1, 1) == "_" then   -- "attach to"
				if sub(vName, 2) == attachToName then
					attachTo = v
				else
					print(string.format("weapon.get: attaching %s to %s, destroying %s", 
						attachment.Name, attachToName, pwd(v)))
					destroy(v)
				end
			end
		end
		assert(attachTo, string.format("weapon.get: attaching %s to %s, but %s attachpoint is not found", attachment.Name, attachToName, attachToName))

		-- place the attachment based on the part named _attachto...
		attachment.PrimaryPart = attachTo
		setPrCFrame(
			attachment, 
			attachpoints[attachToName].CFrame 
				* degToCf(0, 0, (attachToName == "Muzzle" and rotateMuzzleQ and not attachmentAniData.dontRotate) and 180 or 0)
		)

		-- place the new/shifted attachpoints
		for attachpointName, attachpointNew in pairs(newAttachpoints) do
			local attachpointOld = attachpoints[attachpointName]
			if attachpointOld then
				destroy(attachpointOld)
			end
			attachpoints[attachpointName] = attachpointNew
			attachpointNew.Parent = model.attachpoints
			attachpointNew.Name = attachpointName	 -- get rid of the __

			-- shifting barrel may require repositioning the default muzzle
			if attachpointName == "Muzzle" and (defaultAttachments.Muzzle and not attachments.Muzzle) then
				local muzzle = defaultAttachments.Muzzle
				local _muzzle = nil
				for _, v in ipairs(getC(muzzle)) do
					if sub(v.Name, 1, 1) == "_" then
						_muzzle = v
						break
					end
				end
				if _muzzle then
					muzzle.PrimaryPart = _muzzle
					setPrCFrame(muzzle, attachpointNew.CFrame) -- attachpointNew is the new attachpoint for muzzle
					print("wc: shifted the default muzzle for", weaponName, "and", attachment)
				else
					warn("wc: attempted to reposition the muzzle for", weaponName, "but _Muzzle is not found")
				end
			end
		end

		-- modify compatible parts. (for mount and barrel)
		if attachmentData.getCompatibleAttachments then
			for attachpoint, t in pairs(attachmentData.getCompatibleAttachments()) do
				if t == false then
					compatibleAttachments[attachpoint] = nil
				else
					assert(type(t) == "table")
					compatibleAttachments[attachpoint] = t
				end
			end
		end

		-- modify "fppAnimations, tppAnimations, aniparts"
		local defaultFields = {fppAnimations = 1, tppAnimations = 1, aniparts = 1,}
		for field, _ in pairs(defaultFields) do
			local src = attachmentAniData[field]
			if src then
				local dest = aniData[field]
				for k, v in pairs(src) do
					dest[k] = v
				end
			end
		end
		for k, v in pairs(attachmentAniData) do
			-- print("got", k, v)
			if not defaultFields[k] then
				aniData[k] = v
				if k == "moveLeftHandDown" then
					assert(v[weaponName], string.format("left hand down position for %s is not configured for %s", attachment.Name, weaponName))
					do
						local cf = aniData.fppAnimations.holding[1].goalC0.FppLeftArm
						aniData.fppAnimations.holding[1].goalC0.FppLeftArm = v[weaponName] * cf
					end
					do
						if aniData.tppAnimations then
							local cf = aniData.tppAnimations.holding[1].goalC0.LeftUpperArm
							aniData.tppAnimations.holding[1].goalC0.LeftUpperArm = v[weaponName] * cf
						end
					end
				end
			end
		end

		if attachToName == "Optic" then
			sightChanged = true
		end

		-- for rotating muzzles (eg vector with ext handguard and osprey)
		if attachmentAniData.rotateMuzzle then
			print(attachment.Name, "set rotateMuzzleQ to true")
			rotateMuzzleQ = attachmentAniData.rotateMuzzle
		end
	end
	for attachpoint, attachment in pairs(attachments) do
		if attachpoint == "Mount" or attachpoint == "Barrel" then
			addAttachment(attachment, attachpoint)
		end
	end
	for attachpoint, attachment in pairs(attachments) do
		if attachpoint ~= "Mount" and attachpoint ~= "Barrel" then
			addAttachment(attachment, attachpoint)
		end
	end
	-- print(aniData.fppAnimations.holding[1].goalC0.FppLeftArm)

	-- lower the sight is sight is changed
	local defSights = weaponData.getDefaultSight()
	if defSights then
		solvePaths(defSights, model)
		if sightChanged then
			destroy(defSights.raised)
		else
			destroy(defSights.lowered)
		end
	end

	-- delete all invisible "attachTo" parts
	for _, v in ipairs(model:GetDescendants()) do
		if isA(v, "BasePart") then
			if sub(v.Name, 1, 1) == "_" then
				destroy(v)
			end
		end
	end

	-- weld the model
	weld(model)
	setPartsProperty(model, {CanCollide = false, Anchored = false})

	-- path solving for aniparts
	solvePaths(aniData.aniparts, model)
	if aniData.reticle then
		print("get reticle")
		aniData.reticle = solvePath(aniData.reticle, model)
		aniData.reticle.Transparency = 1
	end
	if aniData.reticleExt then
		-- print("get reticleExt")
		assert(typeof(aniData.reticleExt) == "table")
		solvePaths(aniData.reticleExt, model)
		for _, v in pairs(aniData.reticleExt) do
			v.Transparency = 1
		end
	end
	-- if aniData.sounds then
	-- 	print("weapon sounds loaded")
	-- 	printTable(aniData.sounds)
	-- end

	-- apply skin and configure skinStep()
	local skinStep
	local skinName = attachments.Skin
	if skinName then
		local skin = skinLib.getSkin(skinName)
		if skin then
			-- these parts won't get skinned
			local nonSkinParts = getSet({
				aniData.reticle,
				aniData.reticleExt,
			}, 10)

			local primaryColor   = skin.primaryColor
			local secondaryColor = skin.secondaryColor
			local tertiaryColor  = skin.tertiaryColor
			local textureColor   = skin.textureColor
			local textureId      = skin.textureId

			local dynamicParts = {}
			local isDynamic = typeof(primaryColor) == 'function'

			-- loop for every part and assign skin/color
			for _, v in ipairs(getD(model)) do
				if isA(v, "BasePart") and not nonSkinParts[v] then
					local texture = ffcWia(v, "Texture")
					if texture then
						if primaryColor then
							if isDynamic then
								dynamicParts[#dynamicParts + 1] = v 
							else
								v.Color = primaryColor
							end
						end
						if textureColor then
							texture.Color3 = textureColor
						end
						if textureId then
							texture.Texture = textureId
						end

					else
						if secondaryColor then
							v.Color = secondaryColor
						end
					end

					local decal = ffcWia(v, "Decal")
					if decal and isA(v, "MeshPart") and tertiaryColor and ffcWia(v, "SpecialMesh") then
						decal.Color3 = tertiaryColor
					end
				end
			end

			-- setup the skin step if it is dynamic
			if #dynamicParts > 0 then
				local tt = args.skinTOffset or 0
				local n  = #dynamicParts
				skinStep = function(dt)
					tt = tt + dt
					local color = primaryColor(tt)
					for i = 1, n do
						dynamicParts[i].Color = color
					end
					return tt
				end
				print("wc: skinStep loaded")
		 	end			
		end
	end

	-- treat the skin as an attachment.
	-- fill cas.Skin with all skins in the gunskin lib
	compatibleAttachments.Skin = {}  -- this empty skin table is for showDots() to show the skin dot
	-- for skinName, _ in pairs(skinLib.skins) do
	-- 	compatibleAttachments.Skin[skinName] = true
	-- end
	-- done in lobby gui. primary/secondaryAttc.load()

	if pp == "tpp" then
		local aniparts = aniData.aniparts
		aniparts.WeaponMain:FindFirstChildWhichIsA("Motor6D"):Destroy()
		local tppMainJoint = script.TppMainJoint:Clone()
		tppMainJoint.Parent = aniparts.WeaponMain
		tppMainJoint.Part1  = aniparts.WeaponMain
		print("wc: replace fpp joint with tpp joint")
	end

	return model, stats, aniData, compatibleAttachments, skinStep
end

return wc