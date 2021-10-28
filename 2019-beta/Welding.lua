local md = {}

local ffc            = game.FindFirstChild
local ffcWia         = game.FindFirstChildWhichIsA
local isA            = game.IsA
local newCf          = CFrame.new
local iCf            = newCf()
local invCf          = iCf.inverse
local _model         = Instance.new("Model")
local getDescendants = _model.GetDescendants
local pwd            = _model.GetFullName

function md.weldDontMove(part0, part1)
	local joint  = Instance.new("Motor6D")
	joint.Name   = "Weld"
	joint.C0     = invCf(part0.CFrame) * part1.CFrame
	joint.C1     = iCf
	joint.Part0  = part0
	joint.Part1  = part1
	joint.Parent = part1
end
local weld = md.weldDontMove

function md.weldModel(model, rp, verbose)		-- root part
	rp = rp or model.PrimaryPart
	assert(rp or warn("weldModel: need to specify or set a root part"))
	local function shouldWeld(part1)
		return ffcWia(part1, "JointInstance") == nil and part1 ~= rp
	end
	for _, v in ipairs(getDescendants(model)) do
		if isA(v, "BasePart") then 
			if shouldWeld(v) then
				weld(rp, v)
				if verbose then
					print(string.format("weldModel: welded %s", pwd(v)))
				end
			end
		end
	end
end

function md.deleteNonAnimatedWelds(model)
	for _, v in ipairs(getDescendants(model)) do
		local oldJoint = ffcWia(v, "Weld") or ffc(v, "Weld")
		if oldJoint then
			print("deleteNonMotor6dWeld: deleting", pwd(oldJoint))
			oldJoint:Destroy()
		end
	end
end

-- local ffc = game.FindFirstChild
-- local ffcWia = game.FindFirstChildWhichIsA("")
function md.setPartsProperty(model, properties)
	for _, v in ipairs(getDescendants(model)) do
		if isA(v, "BasePart") then
			for key, value in pairs(properties) do
				v[key] = value
			end
		-- elseif isA(v, "Texture") then
		-- 	local trans = properties.Transparency
		-- 	if trans then
		-- 		v.Transparency = 1 - (1 - 0.4) * (1 - trans)
		-- 	end
		end
	end
end
				-- if key == "Transparency" and (value == 0 or value == 1) then 		-- only support zero and one
				-- 	if ffcWia
				-- 	if value == 1 then
				-- 		local textures = ffc(v, "Textures")
				-- 		if textures 
				-- end

return md