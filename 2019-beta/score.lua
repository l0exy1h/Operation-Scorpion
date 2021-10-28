local lp = game.Players.LocalPlayer
local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local ev = wfc(rep, "Event")
local connect = game.Changed.Connect
local tween = requireGm("Tweening").tween

-- for this code only
local sg = wfc(wfc(lp, "PlayerGui"), 'ScreenGui')

local bigScore = {}
do
	local scoreFr   = wfc(sg, "Score")
	local scoreText = wfc(scoreFr, "TextLabel")
	scoreText.TextTransparency = 1


	local val = Instance.new("IntValue")
	local accVal = 0
	local tws = {}
	local id = 0

	local timings = {
		transIn = 0.1,
		transOut = 0.5,
		val = 0.5,
		delay = 5.1,
	}

	connect(val.Changed, function()
		scoreText.Text = tostring(val.Value)
	end)

	local function clearTweens()
		for i, tw in ipairs(tws) do 
			tw:Cancel()
			tws[i] = nil
		end
	end

	function bigScore.onScoreChanged(inc)
		id = id + 1
		clearTweens()

		tws[#tws + 1] = tween(scoreText, timings.transIn, {TextTransparency = 0})
		tws[#tws + 1] = tween(val, timings.val, {Value = accVal + inc})
		accVal = accVal + inc

		local savedId = id
		delay(timings.delay, function()
			if savedId == id then
				clearTweens()
				tws[#tws + 1] = tween(scoreText, timings.transOut, {TextTransparency = 1})
				delay(timings.transOut + 0.02, function()
					if savedId == id then
						accVal = 0
						val.Value = 0
					end
				end)
			end
		end)
	end
end

local feed = {}
do
	local feedFr = wfc(sg, "Feed")

	local maxFeedCnt = 3 + 1
	local timings = {
		movingDown = 0.19,
		delay = 5,
		hideDelta = 0.05,
		show = 0.3,
		hide = 0.5,
	}

	local id = 0
	local addable = true
	local feeds   = {}


	do -- get feed fr
		local feedTemp = wfc(feedFr, "Frame")
		local grid = wfc(feedFr, "UIGridLayout")
		local gridY = grid.CellSize.Y.Scale
		feedTemp.Size = grid.CellSize
		feedTemp.Parent = nil
		feedFr:ClearAllChildren()
		local clone = game.Clone
		local format = string.format
		local typeToText = {
			hit = "ENEMY HIT",
			plant = "BOMB PLANTED",
			defuse = "BOMB DEFUSED",
			["round.win"] = "ROUND VICTORY",
			["match.win"] = "MATCH VICTORY",
		}

		function feed.format(inc, type)
			return format("%s +%d", typeToText[type], inc)
		end

		function feed.getFeedFr(inc, type)
			local fr = clone(feedTemp)
			fr.TextLabel.Text = feed.format(inc, type)
			return fr
		end

		local newU2 = UDim2.new
		function feed.getPos(i)
			return newU2(0, 0, (i - 1 + 0.5) * gridY, 0)
		end
	end

	function feed.showAll()
		for _, v in ipairs(feeds) do
			v.show()
		end
	end

	do -- add feed
		local getFeedFr = feed.getFeedFr
		local getPos    = feed.getPos
		function feed.addFeed(inc, type)
			addable = false

			-- combine the lastfeed is type is the same
			-- local lastFeed = feeds[1]
			-- if lastFeed then
			-- 	if lastFeed.type == type then
			-- 		lastFeed.updateValue(inc)
			-- 		addable = true
			-- 		return
			-- 	end
			-- end

			local self = {type = type}
			local fr = getFeedFr(inc, type)
			local idx = nil

			-- move down & destroy & show
			for i = #feeds, 1, -1 do
				local feed = feeds[i]
				feed.setIdx(i+1)
				feed.moveToIdx()
				feed.show()
				if i + 1 > maxFeedCnt then
					feed.destroy()
				end
			end

			function self.setIdx(i)
				feeds[i] = self
				if idx then
					feeds[idx] = nil
				end
				idx = i
			end
			self.setIdx(1)

			do -- moving down
				local tw = nil
				function self.moveToIdx()
					if tw then
						tw:Cancel()
						tw = nil
					end
					tw = tween(fr, timings.movingDown, {Position = getPos(idx)})
				end
			end

			function self.parentToFeedFr()
				-- fr.TextLabel.TextTransparency = 1
				fr.LayoutOrder = -id
				fr.Parent = feedFr
				fr.Position = getPos(0)
				self.moveToIdx()	-- should be one here
			end

			-- mainly the transparency step
			do
				local a = 0.15
				local b = 0.3
				-- local c = 0.3
				local function opacityCurve(y)
					-- y = y + c
					if y <= 0 then
						return 0
					elseif y <= a then
						return y / a
					elseif y <= 1 - b then
						return 1
					elseif y <= 1 then
						return (1 - y) / b
					else
						return 0
					end
				end

				local masterOpacity = Instance.new("NumberValue")
				do
					masterOpacity.Value = 1
					local tw = nil
					function self.show()
						if tw then
							tw:Cancel()
							tw = nil
						end
						if tw ~= 1 then
							tw = tween(masterOpacity, timings.show, {Value = 1})
						end
					end
					function self.hide()
						if tw then
							tw:Cancel()
							tw = nil
						end
						if tw ~= 0 then
							tw = tween(masterOpacity, timings.hide, {Value = 0})
						end
					end
				end

				local textLabel = fr.TextLabel
				function self.step()
					if fr.Parent == nil then
						self.parentToFeedFr()
					end
					-- set transparency here
					textLabel.TextTransparency = 1 - opacityCurve(fr.Position.Y.Scale) * masterOpacity.Value
				end
			end

			do
				local destroy = game.Destroy
				function self.destroy()
					if idx then
						feeds[idx] = nil
					end
					destroy(fr)
				end
			end

			-- helper function for combining the lastfeed
			local accVal = inc
			function self.updateValue(inc2)
				accVal = accVal + inc2
				fr.TextLabel.Text = feed.format(accVal, type)
			end

			addable = true
		end
	end

	function feed.onScoreChanged(inc, type)
		id = id + 1

		-- hide after a few seconds
		local savedId = id
		delay(timings.delay, function()
			if savedId == id then
				for i = #feeds, 1, -1 do
					local feed = feeds[i]
					if savedId == id then
						feed.hide()
						delay(timings.hide + 0.02, function()
							if savedId == id then
								feed.destroy()
							end
						end)
						wait(timings.hideDelta)
					else
						break
					end
				end
			end
		end)
		
		if type ~= "kill" then
			if not addable then
				repeat
					wait()
				until addable
			end
			feed.addFeed(inc, type)
		else
			feed.showAll()
		end
	end

	function feed.step()
		for _, v in ipairs(feeds) do
			v.step()
		end
	end
end

local bigFeed = {}
do
	local tw = nil
	local bigFeedFr = wfc(sg, "BigFeed")
	local textLabel = wfc(bigFeedFr, "TextLabel")
	textLabel.Transparency = 1

	local timings = {
		show = 0.4,
		delay = 5.5,
		hide = 0.4,
	}

	local id = 0
	local format = string.format
	function bigFeed.onScoreChanged(inc, type, args)
		id = id + 1
		local savedId = id
		delay(timings.delay, function()
			if savedId == id then
				if tw then tw:Cancel(); tw = nil end
				tw = tween(textLabel, timings.show, {TextTransparency = 1})
			end
		end)

		tw = tween(textLabel, timings.show, {TextTransparency = 0})
		if type == "kill" then
			if tw then tw:Cancel(); tw = nil end
			textLabel.Text = format("%s +%d", args.victim.Name, inc)
		end
	end
end

local iconFeed = {}
do
	local iconFeedFr = wfc(sg, "IconFeed")

	-- local id = 0
	local skullZoom = 3
	local timings = {
		delay = 6,
		show = 0.4,
		hide = 0.2, 	-- cant be >= 0.2, will lag
	}
	-- local icons = {}

	do
		local iconTemp = wfc(iconFeedFr, "Frame")
		local maxWidth = iconTemp.Size.X.Scale
		iconTemp.Parent = nil
		local getC = game.GetChildren
		local destroy = game.Destroy
		local clone = game.Clone
		local newU2 = UDim2.new
		local audioSys = requireGm("AudioSystem")
		for _, v in ipairs(getC(iconFeedFr)) do
			if v.Name ~= "UIListLayout" then
				destroy(v)
			end
		end
		function iconFeed.addIcon(inc, type, args)
			local fr = clone(iconTemp)
			local isHeadshot = args and args.hitName == "Head"

			-- set up visibility function
			local vis = Instance.new("NumberValue")
			vis.Value = 0
			local function setVisibility(v)
				fr.Skull.ImageTransparency = (1 - v^2)
				fr.Size = newU2(v * maxWidth, 0, 1, 0)
			end
			setVisibility(0)
			vis.Changed:connect(setVisibility)

			-- add to icons (show)
			local tws = {}
			tws[#tws + 1] = tween(vis, timings.show, {Value = 1})
			fr.Skull.Size = newU2(skullZoom, 0, skullZoom, 0)
			tws[#tws + 1] = tween(fr.Skull, timings.show, {Size = newU2(1, 0, 1, 0)})
			if isHeadshot then
				tween(fr.Circle, timings.show, {ImageTransparency = 0, Size = newU2(0, 0, 0, 0)})
				audioSys.play("KilledByLpHead", "2D")
			else
				fr.Circle.ImageTransparency = 1
				audioSys.play("KilledByLp", "2D")
			end
			fr.Parent = iconFeedFr

			-- hide and then delete
			delay(timings.delay, function()
				for i, tw in ipairs(tws) do
					tw:Cancel()
					tws[i] = nil
				end
				tws[#tws + 1] = tween(vis, timings.hide, {Value = 0})
				delay(timings.hide + 0.01, function() 	-- delete
					destroy(fr)
				end)
			end)
		end
	end

	local icons = {}
	function iconFeed.onScoreChanged(inc, type, args)
		if type == "kill" then
			-- id = id + 1
			iconFeed.addIcon(inc, type, args)
		end
	end
end

-- use listen (score.inc) in the actual code
connect(ev.Event, function(_, inc, type, args)
	bigScore.onScoreChanged(inc)
	feed.onScoreChanged(inc, type)
	bigFeed.onScoreChanged(inc, type, args)
	iconFeed.onScoreChanged(inc, type, args)
end)

-- put this into the hbthread
spawn(function()
	local hb = game:GetService("RunService").Heartbeat
	local evwait = game.Changed.Wait
	while evwait(hb) do
		feed.step()
	end
end)