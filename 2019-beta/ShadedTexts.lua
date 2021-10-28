local shadedTexts = {}

function shadedTexts.setStProp(st, p, v)
	st.shade[p] = v
	st.text[p] = v
end
function shadedTexts.setStText(st, v)
	st.shade.Text = v
	st.text.Text  = v
end
function shadedTexts.setStPos(st, pos)
	local offset = st.shade.Position - st.text.Position
	st.text.Position = pos
	st.shade.Position = pos + offset
end
function shadedTexts.setStProps(st, properties)
	for key, value in pairs(properties) do
		if key == "Position" then
			shadedTexts.setStPos()
		else
			st.text[key] = value
			st.shade[key] = value
		end
	end
end


function shadedTexts.getShadePosition(pos, dx, dy)
	if dx == nil then dx = 1 end
	if dy == nil then dy = 2 end
	return UDim2.new(pos.X.Scale, pos.X.Offset + dx, pos.Y.Scale, pos.Y.Offset + dy)
end

function shadedTexts.setStPos(st, pos, dx, dy)
	st.text.Position = pos
	st.shade.Position = shadedTexts.getShadePosition(pos, dx, dy)
end

do
	local rep = game.ReplicatedStorage
	local wfc  = game.WaitForChild
	local gm  = wfc(rep, "GlobalModules")
	local function requireGm(name)
		return require(wfc(gm, name))
	end
	local tween = requireGm("Tweening").tween
	function shadedTexts.tween(st, time, properties)
		tween(st.text, time, properties)
		if properties.Position then
			properties.Position = properties.Position + (st.text.Position - st.shade.Position)
		end
		tween(st.shade, time, properties)
	end
end

return shadedTexts