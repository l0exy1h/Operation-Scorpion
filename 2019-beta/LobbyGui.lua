-- possible improvements:
--   - do a new page system (that acrosses all levels)
--     combined with camera system.
--   - attachment for secondaries!

-- lobby gui
-- contains everything lol
--------------------------------------


do-- hide top bar
	local suc, msg = pcall(function()
		game:GetService('StarterGui'):SetCore("TopbarEnabled", false)
	end)
	if suc then
		print("hide top bar")
	else
		print("failed to hide top bar", msg)
	end
end

local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local plrs = game.Players
local lp   = plrs.LocalPlayer
local function requireGm(name)
	return require(wfc(gm, name))
end
local getC = game.GetChildren
local newU2          = UDim2.new
local tween          = requireGm("Tweening").tween
local connect        = game.Changed.Connect
local myMath         = requireGm("Math")
local scrollingFrame = requireGm("ScrollingFrame")
local scrollingList  = requireGm("ScrollingList")
local pv          = requireGm("PublicVarsClient")
local printTable  = requireGm("TableUtils").printTable
local audioSys    = requireGm("AudioSystem")
audioSys.play("Lobby", "2D")
local buttonSounds = requireGm("ButtonSounds")

local sg 
do-- put the sg in starter player to playergui
	sg = wfc(game:GetService("StarterGui"), "LobbyGui")
	sg.Parent = wfc(lp, "PlayerGui")
end

local lobbyClient, fetchClient
do
	local events = wfc(rep, "Events")
	lobbyClient = requireGm("Network").loadRe(wfc(events, "LobbyRe"), {socketEnabled = true, rf = wfc(events, "LobbyRf2")})
	fetchClient = requireGm("FetchClient").loadRf(wfc(events, "LobbyRf"))
end

local dg = {}			-- guis that need updating when new data comes

local camera = {}
local showcase3D = {}
local popupGui = {}

local root = {}
local party = {}
local right = {}

local data = nil
local dataSystem = {}

local db = requireGm("DebugSettings")()

do-- popup windows
	local popupHolder = wfc(sg, "Popup")
	popupHolder.Visible = true

	do -- dim/undim bg
		local darkFr = wfc(popupHolder, "Dark")
		local dimTrans = darkFr.BackgroundTransparency
		local undimTrans = 1
		darkFr.BackgroundTransparency = undimTrans

		local defaultDimTime = 0.2

		function popupGui.dim(t)
			if dimTween then
				dimTween:Cancel()
			end
			dimTween = tween(darkFr, t or defaultDimTime, {BackgroundTransparency = dimTrans})
		end

		function popupGui.undim(t)
			if dimTween then
				dimTween:Cancel()
			end
			dimTween = tween(darkFr, t or defaultDimTime, {BackgroundTransparency = undimTrans})			
		end
	end

	local shownCnt = 0	 -- the # of activated and shown popup guis
	function popupGui.incShownCnt(d)
		shownCnt = shownCnt + d
		if shownCnt < 0 then
			warn("popupGui error: shownCnt < 0", shownCnt)
			return
		end
		if shownCnt == 0 then
			popupGui.undim()
		else
			popupGui.dim()
		end
	end

	-- functions that all popup modules can call
	local clone = game.Clone
	local setStText = requireGm("ShadedTexts").setStText
	local uis = game:GetService("UserInputService")

	do -- amount slider
		local guiTemp = wfc(popupHolder, "AmountSlider")
		local inPos  = guiTemp.Position
		local outPos = guiTemp.Position + UDim2.new(0, 0, 1, 0)
		guiTemp.Parent = nil

		local clamp = myMath.clamp
		local lerp = myMath.lerp
		local getPercentage = myMath.getPercentage
		local floor = math.floor
		local mouse = lp:GetMouse()

		local ts = {	-- timings.
			slideIn = 0.2,
			slideOut = 0.2,

			draggerTweenTime = 0.1,

			minPlusMinusHoldTime = 0.5, 	-- delay before repeating
			plusMinusHoldSpeed   = function(holdTime)  -- repeating rate (Hz)
				return lerp(0.1, 1, clamp((holdTime - 1.5) / 4, 0, 1))
			end;	-- returns [0,1]. will be multiplied with interval size.
		}


		function popupGui.amountSliderGetter(args)
			popupGui.incShownCnt(1)

			-- args
			args = args or {}
			local defaultAmount     = args.defaultAmount or 1
			local maxAmount         = args.maxAmount or 10
			local minAmount         = args.minAmount or 1
			local onConfirmed       = args.onConfirmed	-- a function that accepts an amount
			local confirmButtonText = args.confirmButtonText

			local intervalSize = maxAmount - minAmount

			local cons = {}
			local self = {}
			local running = true
			local gui  = clone(guiTemp)
			gui.Position = outPos
			gui.Parent = popupHolder

			local guiTween -- the tweenObj for moving in and out
			function self.animateShow()
				guiTween = tween(gui, ts.slideIn, {Position = inPos})
			end			
			self.animateShow()

			function self.animateDestroy()
				running = false
				if guiTween then
					guiTween:Cancel()
				end
				guiTween = tween(gui, ts.slideOut, {Position = outPos})
				popupGui.incShownCnt(-1)
				delay(ts.slideOut + 1e-2, function()
					gui:Destroy()
					self = nil
					for _, con in ipairs(cons) do
						con:Disconnect()
					end
				end)
			end

			-- slider module
			---------------------------------------
			local amount = nil 		-- the current amount

			-- texts
			local selectFr = wfc(wfc(gui, "Select"), "Frame")
			local amountTexts = wfc(wfc(selectFr, "Amount"), "Frame")

			-- plus / minus
			local plusMinusFr = wfc(selectFr, "Buttons")
			local plusBut = wfc(plusMinusFr, "Plus")
			local minusBut = wfc(plusMinusFr, "Minus")
			local isPlusButActivated, isMinusButActivated 
			local activatedTrans = minusBut.Frame.ImageLabel.ImageTransparency
			local deactivatedTrans = plusBut.Frame.ImageLabel.ImageTransparency
			function self.setPlusActivated(bool)
				if isPlusButActivated ~= bool then
					isPlusButActivated = bool
					local trans = bool and activatedTrans or deactivatedTrans
					for _, v in ipairs(plusBut.Frame:GetChildren()) do
						v.ImageTransparency = trans
					end
				end
			end
			function self.setMinusActivated(bool)
				if isMinusButActivated ~= bool then
					isMinusButActivated = bool
					local trans = bool and activatedTrans or deactivatedTrans
					minusBut.Frame.ImageLabel.ImageTransparency = trans
				end
			end

			-- the slider
			local sliderFr = wfc(selectFr, "Slider")
			local draggerBut = wfc(sliderFr, "Dragger")
			local draggerButPosY = draggerBut.Position.Y.Scale
			local blueFr = wfc(sliderFr, "Blue")
			local blueFrSizeY = blueFr.Size.Y.Scale
			-- local greyFr = wfc(sliderFr, "Grey") -- not needed for any animation
			local draggerButTween = nil
			local blueFrTween = nil

			function self.setSliderPositionByPercentage(p, disableAnimation)
				local draggerPos = newU2(p, 0, draggerButPosY, 0)
				local blueSize   = newU2(p, 0, blueFrSizeY, 0)
				if disableAnimation then
					draggerBut.Position = draggerPos
					blueFr.Size = blueSize
				else
					-- the dragger
					if draggerButTween then
						draggerButTween:Cancel()
					end
					draggerButTween = tween(draggerBut, ts.draggerTweenTime, {
						Position = draggerPos
					})

					-- the blue bar
					if blueFrTween then
						blueFrTween:Cancel()
					end
					blueFrTween = tween(blueFr, ts.draggerTweenTime, {
						Size = blueSize
					})
				end
			end

			function self.setSliderPosition(amount)
				amount = clamp(amount, minAmount, maxAmount)
				local p = (amount - minAmount) / (maxAmount - minAmount)
				self.setSliderPositionByPercentage(p)
			end

			function self.getAmountByPercentage(p)
				return clamp(floor(intervalSize * p + minAmount), minAmount, maxAmount)
			end

			function self.getPercentageByMouse(x)
				local apx = sliderFr.AbsolutePosition.X
				local asx = sliderFr.AbsoluteSize.X
				return clamp(getPercentage(x, apx, asx + apx), 0, 1)
			end

			-- drag -> change amount
			local isDragging = false
			cons[#cons + 1] = draggerBut.MouseButton1Down:Connect(function()
				isDragging = true
			end)
			cons[#cons + 1] = uis.InputEnded:Connect(function(input, g)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					isDragging = false
				end
			end) 


			function self.setAmount(amount_, inputFromSlider)
				amount = amount_

				-- change the displayed number
				setStText(amountTexts, tostring(amount))

				-- slider position
				if not inputFromSlider then
					self.setSliderPosition(amount)
				end

				-- activate/deactive some button
				self.setPlusActivated(amount ~= maxAmount)
				self.setMinusActivated(amount ~= minAmount)
			end
			self.setAmount(defaultAmount)

			-- click / hold, plus / minus
			local plusDownTick = 1									-- the tick when plus is pressed down
			local plusUpTick   = plusDownTick + 1		-- the tick when plus is released
			local lastPlusTick = plusDownTick - 1		-- the tick when the plus signal is sent
			cons[#cons + 1] = plusBut.MouseButton1Down:Connect(function()
				if isPlusButActivated then
					self.setAmount(amount + 1)
					plusDownTick = tick()
					lastPlusTick = plusDownTick - 1
				end
			end)
			cons[#cons + 1] = plusBut.MouseButton1Up:Connect(function()
				plusUpTick = tick()
			end)

			local minusDownTick = 1
			local minusUpTick = minusDownTick + 1		-- setting up > down so its not holding by default
			local lastMinusTick = minusDownTick - 1	-- lastminus tick should be before down tick when first clicking.
			cons[#cons + 1] = minusBut.MouseButton1Down:Connect(function()
				if isMinusButActivated then
					self.setAmount(amount - 1)
					minusDownTick = tick()
					lastMinusTick = minusDownTick - 1
				end
			end)
			cons[#cons + 1] = minusBut.MouseButton1Up:Connect(function()
				minusUpTick = tick()
			end)

			-- thread for 
			--  holding plus/minus button -> change amount
			--  dragging -> change amount (but not slider)
			spawn(function()
				local hb     = game:GetService("RunService").Heartbeat
				local evwait = game.Changed.Wait

				local function getFiringRate(holdTime)
					return clamp(intervalSize * ts.plusMinusHoldSpeed(holdTime), 5, 1000000)
				end

				while running do
					local dt = evwait(hb)
					local now = tick()

					-- dragging
					if isDragging then
						local p = self.getPercentageByMouse(mouse.X)
						self.setSliderPositionByPercentage(p, true)
						self.setAmount(self.getAmountByPercentage(p), true)
					end

					-- holding plus button
					if isPlusButActivated then
						local isPlusHolding = plusDownTick > plusUpTick
						local plusHoldTime = now - plusDownTick
						if isPlusHolding and plusHoldTime > ts.minPlusMinusHoldTime then  		-- press for a while first
							local f = getFiringRate(plusHoldTime)
							if now - lastPlusTick > 1 / f  then  -- limit the firing rate
								self.setAmount(amount + 1)
								lastPlusTick = now
							end
						end
					end

					-- holding minus button
					if isMinusButActivated then
						local isMinusHolding = minusDownTick > minusUpTick
						local minusHoldTime = now - minusDownTick
						if isMinusHolding and minusHoldTime > ts.minPlusMinusHoldTime then
							local f = getFiringRate(minusHoldTime)
							if now - lastMinusTick > 1 / f then
								self.setAmount(amount - 1)
								lastMinusTick = now
							end
						end
					end
				end
			end)

			-- connect cancel / buy buttons
			----------------------------------------
			local buttons = wfc(gui, "Buttons")
			local confirmButton = wfc(buttons, "Confirm")
			if confirmButtonText then
				setStText(wfc(confirmButton, "Frame"), confirmButtonText)
			end
			cons[#cons + 1] = confirmButton.MouseButton1Click:Connect(function()
				if onConfirmed then
					onConfirmed(amount)
				end
				self.animateDestroy()
			end)
			local cancelButton = wfc(buttons, "Cancel")
			cons[#cons + 1] = cancelButton.MouseButton1Click:Connect(function()
				self.animateDestroy()
			end)

			return self
		end
	end
	function popupGui.get(popupWindowName, args)		
		local getter = popupGui[popupWindowName.."Getter"]

		-- determine dark 

		if getter then
			return getter(args)
		else
			warn(popupWindowName, "is not found")
		end
	end
end

do-- right panel
	local rightFr   = wfc(sg, "Right")
	local topFr     = wfc(rightFr, "Top")
	local blankBack = wfc(rightFr, "Back")
	blankBack.Visible = false
	local buttonsFr   = wfc(rightFr, "Buttons")
	local invitablesHolder   = wfc(rightFr, "Holder")
	invitablesHolder.Visible = false

	local showPos   = rightFr.Position
	local hidePos   = showPos + newU2(rightFr.Size.X.Scale, 0, 0, 0)
	rightFr.Visible = true
	rightFr.Position = hidePos

	local tweenObj  = nil
	local at        = 0.2

	do-- invitable table
		local invitablesList   = wfc(invitablesHolder, "Invitables")
		local invitableTemp    = wfc(invitablesList, "TextButton")
		invitableTemp.Parent   = nil
		local clone = game.Clone
		local sl    = scrollingList.new(invitablesHolder, invitablesList, {transparentOnSides = true})
		local function getInvitableFr(plr)
			local fr = clone(invitableTemp)
			fr.TextLabel.Text = plr.Name.."   +"
			local clicked = false
			connect(fr.MouseButton1Click, function()
				if not clicked then
					clicked = true
					lobbyClient.fireServer("party.sendInvitation", plr)
				end
			end)
			return fr
		end
		local function isInvitable(plr)
			return pv.waitForP(plr, "InRoom") == false
				and  pv.waitForP(plr, "InQuickjoin") == false
				and  pv.waitForP(plr, "IsSingle") == true
		end
		function right.showWithInvitables()
			sl.clear()
			for _, plr in ipairs(getC(plrs)) do
				if isInvitable(plr) and plr ~= lp then
					sl.add(getInvitableFr(plr), function(g, o)
						g.TextLabel.TextTransparency = 1 - o
					end)
				end
			end
			invitablesHolder.Visible = true
			buttonsFr.Visible = false
			right.show()
			root.playHomeSf.scrollingEnabled = false
		end
	end

	do-- show and hide
		local showId = 0
		function right.showNormal()
			invitablesHolder.Visible = false
			buttonsFr.Visible = true
			right.show()
		end
		function right.show()
			showId = showId + 1
			blankBack.Visible = true
			if tweenObj then
				tweenObj:Cancel()
			end
			tweenObj = tween(rightFr, at, {Position = showPos})
		end
		function right.hide()
			showId = showId + 1
			if tweenObj then
				tweenObj:Cancel()
			end
			tweenObj = tween(rightFr, at, {Position = hidePos})
			local savedShowId = showId
			delay(at, function()
				if savedShowId == showId then
					blankBack.Visible = false
				end
			end)
			root.playHomeSf.scrollingEnabled = true
		end
	end

	do -- money
		local setStText = requireGm("ShadedTexts").setStText
		local moneyFr = wfc(topFr, "Money")
		dg[#dg + 1] = function()
			print("updating money")
			-- the money bar
			setStText(moneyFr, "$ "..data.money.."   +")			
		end
		connect(moneyFr.MouseButton1Click, function()
			root.gotoPage("shop", "credits")
			right.hide()
		end)
	end
	do --level
		local prg = requireGm("Progression")
		local levelFr = wfc(rightFr, "Level")
		local levelText = wfc(levelFr, "Number")
		local levelCirc = wfc(levelFr, "Rot")
		local levelUnitDeg = wfc(levelCirc, "ImageLabel")
		levelUnitDeg.Parent = nil
		local setStText = requireGm("ShadedTexts").setStText
		local done = false
		dg[#dg + 1] = function(d)
			if not done then
				print("updating level")
				done = true
				
				-- set the level text
				setStText(levelText, prg.getLevelInt(data.exp))

				-- set the level circular gui
				local clone = game.Clone
				local p = prg.getPercentage(data.exp)
				print(p)
				for i = 0, 359, 1 do
					if i / 360 <= p then
						local unit = clone(levelUnitDeg)
						unit.Name = tostring(i)
						unit.Rotation =i 
						unit.Parent = levelCirc
					else
						break
					end
				end
			end
		end
	end

	connect(wfc(wfc(sg, "Top"), "RightPanelExpand").MouseButton1Click, right.showNormal)
	connect(wfc(rightFr, "Back").MouseButton1Click, right.hide) 
	connect(wfc(topFr, "Back").MouseButton1Click, right.hide)
end

do-- root level pages
	local rootPagesFr = wfc(sg, "Pages")
	local home      = {}
	local play      = {}
	local shop      = {}
	local customize = {}
	local learnMore = {}
	local crateOpening = {}
	local rootPages = {
		home = home,
		play = play,
		shop = shop,
		customize = customize,
		learnMore = learnMore,
		crateOpening = crateOpening,
	}

	do-- configure the top bar and gotoPage() 
		local pageIndex = {	-- for JumpToIndex. it starts at 0
			home = 0,
			play = 1,
			shop = 2,
			customize = 3,
			learnMore = 4,
			crateOpening = 5,
		}
		local uiPageLayout = wfc(rootPagesFr, "UIPageLayout")
		local jumpToIndex = uiPageLayout.JumpToIndex
		local currPage -- a string
		function root.gotoPage(pageName, ...)		-- page name in pages
			if pageName ~= currPage then 
				jumpToIndex(uiPageLayout, pageIndex[pageName])
				if currPage and rootPages[currPage].onLeft then
					rootPages[currPage].onLeft(pageName)
				end
				if pageName and rootPages[pageName].onEntered then
					rootPages[pageName].onEntered(pageName)
				end
				currPage = pageName
			end
			if pageName and rootPages[pageName].gotoPage and #{...} > 0 then
				rootPages[pageName].gotoPage(...)
			end
		end
		-- connect the top buttons
		local buttonsGui = wfc(wfc(sg, "Top"), "Buttons")
		local buttons = {
			home = buttonsGui.Home,
			play = buttonsGui.Play,
			shop = buttonsGui.Shop,
			customize = buttonsGui.Customize,
		}
		for pageName, button in pairs(buttons) do
			connect(button.MouseButton1Click, function()
				root.gotoPage(pageName)
			end)
		end
	end

	do-- configure home
		local home = wfc(rootPagesFr, "Home")
		local content = wfc(home, "sf")
		local sf = scrollingFrame.new(home, content, "vertical", 1.06) -- setup scrolling for home page

		do -- setup the redeem shit (wip)
			local redeemTextBox = wfc(wfc(content, "Redeem"), "TextBox")
			connect(redeemTextBox.FocusLost, function(enter)
				redeemTextBox.Text = ""
				redeemTextBox.PlaceholderText = "Working in Progress. Follow our twitters for updates!"
			end)
		end

		do -- play button -> play page
			local playButton = wfc(content, "Play")
			local gotoPage = root.gotoPage
			connect(playButton.MouseButton1Click, function()
				gotoPage("play")
			end)
		end
	end

	do-- configure play
		local playFr = wfc(rootPagesFr, "Play")
		local playPagesFr = wfc(playFr, "Pages")
		local freshstart = {}
		local quickjoin = {}
		local playHome  = {}
		local playPages = {
			freshstart = freshstart,
			quickjoin = quickjoin,
			playHome = playHome,
		}

		do-- configure the page transition for play\
			local pageIndex = {	-- for JumpToIndex. it starts at 0
				playHome = 0,
				quickjoin = 1,
				freshstart = 2,
			}
			local uiPageLayout = wfc(playPagesFr, "UIPageLayout")
			local jumpToIndex = uiPageLayout.JumpToIndex
			local currPage -- a string
			function play.gotoPage(pageName) 
				if pageName == currPage then return end
				print(pageName, pageIndex[pageName])
				jumpToIndex(uiPageLayout, pageIndex[pageName])
				if currPage and playPages[currPage].onLeft then
					playPages[currPage].onLeft(pageName)
				end
				if pageName and playPages[pageName].onEntered then
					playPages[pageName].onEntered(pageName)
				end
				currPage = pageName
			end
		end

		do-- configure play.playHome
			local playHomeFr = wfc(playPagesFr, "Home")
			local holder = wfc(playHomeFr, "sl")
			local content = wfc(holder, "Frame")
			local buttonsFr = wfc(wfc(content, "Invade"), "Buttons")
			local quickjoinBut = wfc(buttonsFr, "Quickjoin")
			local waitingFr = wfc(wfc(content, "Invade"), "Waiting")

			do-- configure sliding
				local sf = scrollingFrame.new(holder, content, "vertical", 1.6)
				root.playHomeSf = sf
			end

			do-- connect the buttons in the playhome screen\
				local buttons = {
					quickjoin = buttonsFr.Quickjoin,
					freshstart = buttonsFr.Freshstart,
				}
				for p, button in pairs(buttons) do
					connect(button.MouseButton1Click, function()
						lobbyClient.fireServer(p..".start")
					end)
				end
			end
			
			-- party
			local partyList = {}
			do
				local partyFr = wfc(playHomeFr, "Party")
				local slots = {}

				-- setup the kick and leave button templates
				local leaveTemp = partyFr["0"].Leave
				leaveTemp.Parent = nil
				local kickTemp  = partyFr["1"].Kick
				kickTemp.Parent = nil
				local defPos = leaveTemp.Position
				local toRight = newU2(0.5, 0, 0, 0)
				local clone = game.Clone
				local function setTrans(but, t)
					but.Frame.text.TextTransparency = t
					but.ImageTransparency = t
				end
				local at = 0.2
				local function tweenTrans(but, t)
					return tween(but.Frame.text, 0.2, {TextTransparency = t}),
					       tween(but, 0.2, {ImageTransparency = t})
				end

				-- configure the four slots
				for i = 0, 4 do
					local slotFr = partyFr[tostring(i)]
					local slot = {}
					local avatar = wfc(slotFr, "ImageLabel") 
					local plus = wfc(slotFr, "Plus")
					local currPlr = nil

					-- setPlayer
					function slot.setPlayer(plr)
						currPlr = plr
						if plr == nil then
							avatar.Visible = false
							plus.Visible = true
						else
							plus.Visible = false
							avatar.Visible = true
							avatar.Image = pv.waitForP(plr, "Avatar") 
						end
					end
					slot.setPlayer(nil)

					do-- kick and leave button
						local leave = clone(leaveTemp)
						leave.Visible = false
						connect(leave.MouseButton1Click, function()
							lobbyClient.fireServer("party.leave")
							slot.hideLeave()
						end)
						local leaveTweens = {}
						local leaveShowId = 0
						function slot.showLeave()
							leaveShowId = leaveShowId + 1
							leave.Visible = true
							for _, t in ipairs(leaveTweens) do
								t:Cancel()
							end
							-- leave.Position = defPos + toRight
							local t1, t2 = tweenTrans(leave, 0)
							leaveTweens[#leaveTweens + 1] = tween(leave, at, {Position = defPos}) 
							leaveTweens[#leaveTweens + 1] = t1
							leaveTweens[#leaveTweens + 1] = t2
						end
						function slot.hideLeave()
							leaveShowId = leaveShowId + 1
							for _, t in ipairs(leaveTweens) do
								t:Cancel()
							end
							local t1, t2 = tweenTrans(leave, 1)
							leaveTweens[#leaveTweens + 1] = tween(leave, at, {Position = defPos + toRight})
							leaveTweens[#leaveTweens + 1] = t1
							leaveTweens[#leaveTweens + 1] = t2
							local savedLeaveShowId = leaveShowId
							delay(at, function()
								if leaveShowId == savedLeaveShowId then
									leave.Visible = false
								end
							end)
						end
						for _, back in ipairs(getC(leave.Backs)) do
							connect(back.MouseButton1Click, slot.hideLeave)
						end
						leave.Parent = slotFr

						local kick = clone(kickTemp)
						kick.Visible = false
						connect(kick.MouseButton1Click, function()
							lobbyClient.fireServer("party.kick", currPlr)
							slot.hideKick()
						end)
						local kickTweens = {}
						local kickShowId = 0
						function slot.showKick()
							kickShowId = kickShowId + 1
							kick.Visible = true
							kick.Backs.Visible = true
							for _, t in ipairs(kickTweens) do
								t:Cancel()
							end
							-- kick.Position = defPos + toRight
							local t1, t2 = tweenTrans(kick, 0)
							kickTweens[#kickTweens + 1] = tween(kick, at, {Position = defPos}) 
							kickTweens[#kickTweens + 1] = t1
							kickTweens[#kickTweens + 1] = t2
						end
						function slot.hideKick()
							kickShowId = kickShowId + 1
							kick.Backs.Visible = false
							for _, t in ipairs(kickTweens) do
								t:Cancel()
							end
							local t1, t2 = tweenTrans(kick, 1)
							kickTweens[#kickTweens + 1] = tween(kick, at, {Position = defPos + toRight})
							kickTweens[#kickTweens + 1] = t1
							kickTweens[#kickTweens + 1] = t2
							local savedKickShowId = kickShowId
							delay(at, function()
								if kickShowId == savedKickShowId then
									kick.Visible = false
								end
							end)
						end
						for _, back in ipairs(getC(kick.Backs)) do
							connect(back.MouseButton1Click, slot.hideKick)
						end
						kick.Parent = slotFr
					end

					-- clicked
					local function onClicked()
						print("onclick")
						if currPlr == nil then
							right.showWithInvitables()
						elseif currPlr == lp then
							if party.memberCnt > 1 then
								slot.showLeave()
							end
						else
							if party.isLeader then
								slot.showKick()
							end
						end
					end
					connect(slotFr.MouseButton1Click, onClicked)

					slots[i] = slot
				end

				function partyList.onPartyUpdated()
					-- re-construct the list
					slots[0].setPlayer(party.leader)
					local i = 0
					for plrName, plr in pairs(party.members) do
						if plr ~= party.leader then
							i = i + 1
							slots[i].setPlayer(plr)
						end
					end
					for j = i + 1, 4 do
						slots[j].setPlayer(nil)
					end
				end
			end

			do-- invitation
				local clone = game.Clone
				local destroy = game.Destroy

				local at               = 0.2
				local maxInvitations   = 3

				local modifiable           = true
				local invitations          = {} 		-- an array of size 3
				local hasInvitationFromPlr = {}
				
				local invitationsFr    = wfc(playHomeFr, "Invitations")
				local invitationTemp   = wfc(invitationsFr, "Invitation")
				invitationTemp.Parent  = nil
				local uiGridLayout     = wfc(invitationsFr, "UIGridLayout")
				local gap              = uiGridLayout.CellPadding.Y.Scale
				local invitationFrSize = uiGridLayout.CellSize
				local height           = invitationFrSize.Y.Scale 
				destroy(uiGridLayout)
				invitationTemp.Size    = invitationFrSize
				local defFrTrans = invitationTemp.ImageTransparency

				local function addInvitation(plr)
					modifiable = false
					local self = {}
					hasInvitationFromPlr[plr.Name] = true

					do-- destroy the last one if its max
						if #invitations == maxInvitations then
							local last = invitations[maxInvitations]
							last.fadeOut(at)
							wait(at)
							last.destroy() -- simply destroys that gui and set invitations[idx] to ni
						end
					end

					do-- move down the invitations
						for i = #invitations, 1, -1 do
							local invitation = invitations[i]
							invitation.setIdx(i + 1)
							invitation.moveToIdx(at)
						end
						wait(at)
					end

					-- add the current one
					function self.setIdx(i)
						invitations[i] = self
						if self.idx then
							invitations[self.idx] = nil
						end
						self.idx = i
					end
					self.setIdx(1)

					-- configure visuals
					local fr = clone(invitationTemp)
					do-- initialze the gui
						fr.Bar1.BackgroundTransparency           = 1
						fr.Bar2.BackgroundTransparency           = 1
						fr.AvatarHolder.Avatar.ImageTransparency = 1
						fr.Accept.TextTransparency               = 1
						fr.Decline.TextTransparency              = 1
						fr.TextLabel.TextTransparency            = 1
						fr.Inviter.TextTransparency              = 1
						fr.ImageTransparency                     = 1

						fr.AvatarHolder.Avatar.Image = pv.waitForP(plr, "Avatar")
						fr.Inviter.Text = plr.Name
						fr.Parent       = invitationsFr
					end

					function self.fadeIn(T)
						tween(fr.Bar1, T, {BackgroundTransparency = 0})
						tween(fr.Bar2, T, {BackgroundTransparency = 0})
						tween(fr.AvatarHolder.Avatar, T, {ImageTransparency = 0})
						tween(fr.Accept, T, {TextTransparency = 0})
						tween(fr.Decline, T, {TextTransparency = 0})
						tween(fr.TextLabel, T, {TextTransparency = 0})
						tween(fr.Inviter, T, {TextTransparency = 0})
						tween(fr, T, {ImageTransparency = defFrTrans})
					end
					function self.fadeOut(T)
						tween(fr.Bar1, T, {BackgroundTransparency = 1})
						tween(fr.Bar2, T, {BackgroundTransparency = 1})
						tween(fr.AvatarHolder.Avatar, T, {ImageTransparency = 1})
						tween(fr.Accept, T, {TextTransparency = 1})
						tween(fr.Decline, T, {TextTransparency = 1})
						tween(fr.TextLabel, T, {TextTransparency = 1})
						tween(fr.Inviter, T, {TextTransparency = 1})
						tween(fr, T, {ImageTransparency = 1})
					end
					function self.moveToIdx()
						local pos = newU2(0, 0, (self.idx - 1) * (gap + height), 0)
						tween(fr, at, {Position = pos})
					end
					function self.destroy()
						fr:Destroy()
						invitations[self.idx] = nil
						hasInvitationFromPlr[plr.Name] = false
					end

					connect(fr.Accept.MouseButton1Click, function()
						if modifiable then
							modifiable = false

							lobbyClient.fireServer("party.acceptInvitation", plr)
							for _, invitation in ipairs(invitations) do
								invitation.fadeOut(at)
							end
							wait(at)
							for _, invitation in ipairs(invitations) do
								invitation.destroy()
							end

							modifiable = true
						end
					end)
					connect(fr.Decline.MouseButton1Click, function()
						if modifiable then
							modifiable = false

							self.fadeOut(at)
							wait(at)
							local idx = self.idx
							local invitationsN = #invitations
							self.destroy()

							for i = idx + 1, invitationsN do
								local invitation = invitations[i]
								invitation.setIdx(i - 1)
								invitation.moveToIdx(at)
							end
							wait(at)

							modifiable = true
						end
					end)

					self.fadeIn(at)
					wait(at)

					modifiable = true
				end
				lobbyClient.listen("party.receiveInvitationFrom", function(inviter)
					if not hasInvitationFromPlr[inviter.Name] then
						repeat 
							wait(0.2)
						until modifiable
						if not hasInvitationFromPlr[inviter.Name] then
							addInvitation(inviter)
						end
					end
				end)
			end

			function playHome.onPartyUpdated()
				buttonsFr.Visible = party.isLeader
				waitingFr.Visible = not party.isLeader
				quickjoinBut.Visible = party.memberCnt <= 2
				partyList.onPartyUpdated()
			end
		end

		do-- configure play.quickjoin
			local quickjoinFr = wfc(playPagesFr, "Quickjoin")
			local statusText = wfc(wfc(wfc(wfc(quickjoinFr, "Main"), "Right"), "Dynamic"), "text")
			local quitFr = wfc(quickjoinFr, "Quit")
			local quitText = wfc(wfc(quitFr, "Frame"), "text")

			lobbyClient.listen("quickjoin.start", function()
				-- init quickjoin page
				statusText.Text = "Searching..."
				play.gotoPage("quickjoin")
			end)
			lobbyClient.listen("quickjoin.cancel", function()
				play.gotoPage("playHome")
			end)
			lobbyClient.listen("quickjoin.serverNotFound", function()
				statusText.Text = "No server is found in your region. Retrying in a few seconds..."
			end)
			lobbyClient.listen("quickjoin.serverFound", function()
				statusText.Text = "A match server is found. Teleporting!"
			end)
			function quickjoin.onPartyUpdated()
				if party.isLeader then
					quitText.Text = "Leave"
				else
					quitText.Text = "Disband"
				end
			end
			connect(quitFr.MouseButton1Click, function()
				lobbyClient.fireServer("quickjoin.cancel")
				if not party.isLeader then
					lobbyClient.fireServer("party.leave")
				end
			end)
		end

		do-- configure fresh start
			local freshstartFr = wfc(playPagesFr, "Freshstart")
			local quitFr       = wfc(freshstartFr, "Quit")
			local quitText     = wfc(wfc(quitFr, "Frame"), "text")
			local freshstartMainFr = wfc(freshstartFr, "Main")
			local voteFr = wfc(freshstartMainFr, "Vote")
			local vote = nil
			local phase = nil

			do-- handleteams()
				local frames = {
					alpha = wfc(wfc(freshstartMainFr, "Alpha"), "ImageLabel"),
					beta  = wfc(wfc(freshstartMainFr, "Beta"), "ImageLabel"),
				}
				local cnts = {
					alpha = wfc(frames.alpha, "PlayerCnt"),
					beta  = wfc(frames.beta, "PlayerCnt"),
				}
				local playerLists = {
					alpha = wfc(frames.alpha, "Players"),
					beta  = wfc(frames.beta, "Players")
				}
				local playerTemp = wfc(playerLists.alpha, "Frame")
				local playerTempParty = wfc(playerLists.beta, "Frame")
				playerTemp.Parent = nil
				playerTempParty.Parent = nil
				local ffc = game.FindFirstChild
				local clone = game.Clone
				local destroy = game.Destroy
				function freshstart.handleTeams(teams)
					-- teamlist
					for teamName, team in pairs(teams) do
						local playerList = playerLists[teamName]
						-- delete removed players
						for _, fr in ipairs(getC(playerList)) do
							if fr.Name ~= "UIGridLayout" and not team[fr.Name] then
								destroy(fr)
							end
						end
						-- add new players
						-- local cnt = 0
						for plrName, plr in pairs(team.players) do
							-- cnt = cnt + 1
							if ffc(playerList, plrName) == nil then
								local playerFr = clone(party.members[plrName] and playerTempParty or playerTemp)
								playerFr.Name = plrName
								playerFr.TextLabel.Text = plrName
								playerFr.Parent = playerList
							end
						end
						-- teamcount
						cnts[teamName].Text = team.playerCnt.."/7"
					end
				end
			end
			do-- options and voting
				local optionsFr = wfc(voteFr, "Options")
				local optionFrs = {
					[1] = wfc(optionsFr, "Office"),
					[2] = wfc(optionsFr, "Metro"),	
					[3] = wfc(optionsFr, "Yacht"),
					[4] = wfc(optionsFr, "Resort"),
				}
				local checks = {
					[1] = wfc(optionFrs[1], "Checks"),
					[2] = wfc(optionFrs[2], "Checks"),
					[3] = wfc(optionFrs[3], "Checks"),
					[4] = wfc(optionFrs[4], "Checks"),
				}
				local checkN = {
					[1] = 0,
					[2] = 0,
					[3] = 0,
					[4] = 0,
				}
				local clone = game.Clone
				local destroy = game.Destroy
				local ffcWia = game.FindFirstChildWhichIsA
				local checkTemp = wfc(checks[1], "Check")
				checkTemp.Parent = nil

				-- connect vote buttons
				for i, optionFr in ipairs(optionFrs) do
					connect(optionFr.MouseButton1Click, function()
						if vote ~= i and (phase == "voting" or phase == "waiting") then
							vote = i
							lobbyClient.fireServer("freshstart.vote", i)
						end
					end)
				end

				function freshstart.handleOptions(options)
					for i, option in ipairs(options) do
						local optionFr = optionFrs[i]
						local vote     = option.vote
						if vote < checkN[i] then
							for _ = 1, checkN[i] - vote do
								local check = ffcWia(checks[i], "ImageLabel")
								destroy(check)
							end
						elseif vote > checkN[i] then
							for _ = 1, vote - checkN[i] do
								clone(checkTemp).Parent = checks[i]
							end							
						end
						checkN[i] = vote
						-- optionFr.Visible = true
					end
				end
				function freshstart.hideOtherOptions(mpIdx)
					for i, optionFr in ipairs(optionFrs) do
						if i ~= mpIdx then
							optionFr.Visible = false
						end
					end
				end
				function freshstart.showAllOptions()
					for i, optionFr in ipairs(optionFrs) do
						optionFr.Visible = true
					end
				end
			end
			do --title
				local title     = wfc(voteFr, "Title")
				local setStText = requireGm("ShadedTexts").setStText
				function freshstart.setTitle(phase, timer)
					local timer = math.floor(timer + 0.5)
					if phase == "waiting" then
						setStText(title, "WAITING FOR MORE PLAYERS")
					elseif phase == "voting" then
						setStText(title, timer.." SECONDS LEFT TO VOTE")
					elseif phase == "starting" then
						setStText(title, "TELEPORTING TO MATCH")-- MATCH STARTING IN "..timer.." SECONDS")
					else
						error(string.foramt("invalid phase %s", phase))
					end
				end
			end
			do-- handle phase
				function freshstart.handlePhase(room)
					phase = room.phase
					if room.phase == "starting" then
						freshstart.hideOtherOptions(room.mpIdx)
					else
						freshstart.showAllOptions()
					end
					freshstart.setTitle(room.phase, room.timer)
				end
			end

			function freshstart.onPartyUpdated()
				if party.isLeader then
					quitText.Text = "Leave"
				else
					quitText.Text = "Disband"
				end
			end
			connect(quitFr.MouseButton1Click, function()
				if not party.isLeader then
					lobbyClient.fireServer("party.leave")
				end
				lobbyClient.fireServer("freshstart.cancel")
			end)
			lobbyClient.listen("freshstart.start", function(room)
				-- init room gui here
				freshstart.handlePhase(room)
				
				freshstart.handleTeams(room.teams)
				freshstart.setTitle(room.phase, room.timer)
				freshstart.handleOptions(room.options)

				vote = nil
				play.gotoPage("freshstart")
			end)
			lobbyClient.listen("room.phase", freshstart.handlePhase)

			lobbyClient.listen("room.teams", freshstart.handleTeams)
			lobbyClient.listen("room.timer", freshstart.setTitle)
			lobbyClient.listen("room.votes", freshstart.handleOptions)

			lobbyClient.listen("freshstart.cancel", function()
				play.gotoPage("playHome")
			end)
		end

		function play.onPartyUpdated()
			playHome.onPartyUpdated()
			freshstart.onPartyUpdated()
			quickjoin.onPartyUpdated()
		end
	end

	function root.onPartyUpdated()
		print("party updated, leader =", party.leader)
		printTable(party.members)
		play.onPartyUpdated()
	end

	do-- configure the shop page
		local shopFr = wfc(rootPagesFr, "Shop")
		local shopTopFr = wfc(wfc(shopFr, "Top"), "Frame")

		local shopPagesFr = wfc(shopFr, "Pages")
		local credits = {}
		local dances = {}
		local editions = {}
		local crates = {}
		local weapons = {}
		local shopPages = {
			credits = credits,
			dances = dances,
			crates = crates,
			weapons = weapons,
			editions = editions,
		}
		do-- configure shop gotopage
			local pageIndex = {	-- for JumpToIndex. it starts at 0
				credits  = 0,
				weapons  = 1,
				editions = 2,
				dances   = 3,
				crates = 4,
			}
			local uiPageLayout = wfc(shopPagesFr, "UIPageLayout")
			local jumpToIndex = uiPageLayout.JumpToIndex
			local currPage -- a string
			function shop.gotoPage(pageName) 
				if pageName == currPage then return end
				print(pageName, pageIndex[pageName])
				jumpToIndex(uiPageLayout, pageIndex[pageName])
				if currPage and shopPages[currPage].onLeft then
					shopPages[currPage].onLeft(pageName)
				end
				if pageName and shopPages[pageName].onEntered then
					shopPages[pageName].onEntered(pageName)
				end
				currPage = pageName
			end
		end
		do-- configure top
			local buttons = {
				credits = wfc(shopTopFr, "Credits"),
				dances = wfc(shopTopFr, "Dances"),
				editions = wfc(shopTopFr, "Editions"),
				crates = wfc(shopTopFr, "Crates"),
				weapons = wfc(shopTopFr, "Weapons"),
			}
			for name, but in pairs(buttons) do
				connect(but.MouseButton1Click, function()
					shop.gotoPage(name)
				end)
			end

			local defPos = shopTopFr.Position
			local tweens = {}
			function shop.onEntered()
				print("onEntered")
				for i, tween in ipairs(tweens) do
					tween:Cancel()
					tweens[i] = nil
				end
				shopTopFr.Position = defPos + newU2(0.1, 0, 0, 0)
				tweens[#tweens + 1] = tween(shopTopFr, 0.3, {Position = defPos})
				for _, v in pairs(buttons) do
					v.ImageLabel.ImageLabel.ImageTransparency = 1
					v.ImageLabel.xiao.text.TextTransparency = 1
					tweens[#tweens + 1] = tween(v.ImageLabel.ImageLabel, 0.4, {ImageTransparency = 0})
					tweens[#tweens + 1] = tween(v.ImageLabel.xiao.text, 0.4, {TextTransparency = 0})
				end
			end
		end

		-- credits
		local mp = requireGm("MonetizationProducts")
		local mps = game:GetService("MarketplaceService")
		local buyProduct = mps.PromptProductPurchase
		local buyPass = mps.PromptGamePassPurchase
		do
			local creditsFr = wfc(shopPagesFr, "Credits")
			local content   = wfc(creditsFr, "Frame")
			local sl        = scrollingFrame.new(creditsFr, content, "vertical", 1.52)

			local ffc = game.FindFirstChild

			local list = wfc(content, "List")
			local products  = mp.getCreditProducts()
			for i, product in ipairs(products) do
				local fr = ffc(list, tostring(product.money), true)
				do
					local cnt = 0
					while not fr do
						fr = ffc(list, tostring(product.money), true)
						wait(1)
						cnt = cnt + 1
						if cnt == 3 then
							warn("shop: getting", product.money, "has been searching for gui for", cnt, "times")
						end
					end
					if cnt >= 3 then
						warn("shop: got", product.money, "'sgui")
					end
				end
				buttonSounds.addPurchaseSound(fr.Frame.Buy)
				connect(fr.Frame.Buy.MouseButton1Click, function()
					buyProduct(mps, lp, product.id)
				end)
			end
		end

		-- weapons
		local psi = requireGm("ProductStaticInfo")
		do
			local weaponsFr = wfc(shopPagesFr, "Weapons")
			local content   = wfc(weaponsFr, "Frame")
			local sl        = scrollingFrame.new(weaponsFr, content, "vertical", 3)

			local list = wfc(content, "List")
			local checkTemp = wfc(wfc(wfc(list, "carbine1"), "M4A1"), "Check")
			checkTemp.Parent = nil

			local ffc = game.FindFirstChild
			local clone = game.Clone
			local exclusives = {
				XM8 = true,
				["Kriss Vector G2"] = true,
			}
			for _, name in ipairs({
				"XM8", "MK16 Scar-L", "SIG MCX Virtus", "AK74N",
				"M4A1",
				"MP5A3", "Kriss Vector G2", "UMP45",
				"USP .45", "FNX-45",
				"VSSM Vintorez",
				}) do
				local price = psi.getWeaponPrice(name)
				local isExclusive = exclusives[name]

				-- get the weapon frame
				local fr = ffc(list, name, true)
				do
					local cnt = 0
					while not fr do
						fr = ffc(list, name, true)
						wait(1)
						cnt = cnt + 1
						if cnt == 3 then
							warn("shop: getting", name, "has been searching for gui for", cnt, "times")
						end
					end
					if cnt >= 3 then
						warn("shop: got", name, "'sgui")
					end
				end

				-- configure the updater
				dg[#dg + 1] = function()
					local isOwned = data.weapons[name] ~= nil
					if not isExclusive then
						fr.Frame.Money.TextLabel.Visible = not isOwned
						fr.Frame.Buttons.Buy.Visible = not isOwned
					end
					local check = ffc(fr, "Check")
					if not check then
						check = clone(checkTemp)
						check.Parent = fr
					end
					check.Visible = isOwned
				end

				-- configure the learn more button
				connect(fr.Frame.Buttons.LearnMore.MouseButton1Click, function()
					learnMore.load("weapon", name)
				end)

				-- configure the buy button
				if not isExclusive then
					buttonSounds.addPurchaseSound(fr.Frame.Buttons.Buy)
					connect(fr.Frame.Buttons.Buy.MouseButton1Click, function()
						if data.money >= price then
							lobbyClient.fireServer("buy.weapon", name)
						else
							root.gotoPage("shop", "credits")
						end
					end)
				else
					fr.Frame.Buttons.Buy.Visible = false
					fr.Frame.Money.TextLabel.Visible = false
				end

				-- configure the learn more button
			end
		end

		-- editions
		do
			local editionsFr = wfc(wfc(wfc(shopPagesFr, "Editions"), "Frame"), "Frame")
			local checkTemp = wfc(wfc(wfc(editionsFr, "Free"), "Frame"), "Check")
			local ffc = game.FindFirstChild
			local clone = game.Clone

			for i, product in ipairs(mp.getEditionProducts()) do
				local id = product.id
				local edition = product.edition

				local fr = ffc(editionsFr, edition, true)
				local cnt = 0
				while not fr do
					fr = ffc(editionsFr, edition, true)
					wait(1)
					cnt = cnt + 1
					if cnt == 3 then
						warn("shop: getting", edition, "has been searching for gui for", cnt, "times")
					end
				end
				if cnt >= 3 then
					warn("shop: got", edition, "'sgui")
				end

				dg[#dg + 1] = function()
					local isOwned = data.highestEditionLevel >= i
					fr.Frame.Buy.Visible = not isOwned
					local check = ffc(fr, "Check")
					if not check then
						check = clone(checkTemp)
						check.Parent = fr
					end
					check.Visible = isOwned
				end

				buttonSounds.addPurchaseSound(fr.Frame.Buy)
				connect(fr.Frame.Buy.MouseButton1Click, function()
					if data.highestEditionLevel < i then
						buyProduct(mps, lp, id)
					else
						warn("client: buy.editions: try to buy edtiion", i, "but already have", data.highestEditionLevel)
					end
				end)

				-- -- currently only editions are game passes. 
				-- -- so i put this under editions
				-- function mps.PromptGamePassPurchaseFinished(plr, )

				-- end
			end
		end

		-- dances
		do
			local dancesFr = wfc(shopPagesFr, "Dances")
			local content   = wfc(dancesFr, "Frame")
			local sl        = scrollingFrame.new(dancesFr, content, "vertical", 2.5)

			local list = wfc(content, "List")
			local checkTemp = wfc(wfc(wfc(list, "dances1"), "Default"), "Check")
			checkTemp.Parent = nil

			local ffc = game.FindFirstChild
			local clone = game.Clone
			for i, product in ipairs(mp.getDanceProducts()) do
				local dance = product.dance

				local fr = ffc(list, dance, true)
				local cnt = 0
				while not fr do
					fr = ffc(list, dance, true)
					wait(1)
					cnt = cnt + 1
					if cnt == 3 then
						warn("shop: getting", dance, "has been searching for gui for", cnt, "times")
					end
				end
				if cnt >= 3 then
					warn("shop: got", dance, "'sgui")
				end

				dg[#dg + 1] = function()
					local isOwned = data.dances[dance] ~= nil
					fr.Frame.Money.TextLabel.Visible = not isOwned
					fr.Frame.Buttons.Buy.Visible = not isOwned
					local check = ffc(fr, "Check")
					if not check then
						check = clone(checkTemp)
						check.Parent = fr
					end
					check.Visible = isOwned
				end

				-- learn more
				connect(fr.Frame.Buttons.LearnMore.MouseButton1Click, function()
					learnMore.load("dance", dance)
				end)

				if product.id then 	-- only default's id is nil
					buttonSounds.addPurchaseSound(fr.Frame.Buttons.Buy)
					connect(fr.Frame.Buttons.Buy.MouseButton1Click, function()
						buyProduct(mps, lp, product.id)
					end)
				end
			end
		end

		-- crates
		do
			local cratesFr = wfc(shopPagesFr, "Crates")
			local content = wfc(cratesFr, "Frame")
			local sl      = scrollingFrame.new(cratesFr, content, "vertical", 1)

			local list = wfc(content, "List")

			local ffc = game.FindFirstChild
			local skinLib = requireGm("GunSkins")
			local clamp = myMath.clamp
			local floor = math.floor

			for crateName, _ in pairs(skinLib.crates) do
				local crate = skinLib.getCrate(crateName)
				assert(crate, "invalidCrateName "..crateName)
				local price = crate and crate.price
				assert(price, "crate "..crateName.." has no price")

				-- get the crate frame
				local fr = ffc(list, crateName, true)
				do
					local cnt = 0
					while not fr do
						fr = ffc(list, crateName, true)
						wait(1)
						cnt = cnt + 1
						if cnt == 3 then
							warn("shop: getting", crateName, "has been searching for gui for", cnt, "times")
						end
					end
					if cnt >= 3 then
						warn("shop: got", crateName, "'sgui")
					end
				end

				-- auto configure the price
				local centralFr = wfc(fr, "Frame")
				local priceFr   = wfc(centralFr, 'Money')
				local priceText = wfc(priceFr, 'TextLabel')
				priceText.Text  = string.format("$%d", price)

				-- configure the updater
				local amountFr = wfc(fr, "Amount")
				local amountText = wfc(amountFr, 'TextLabel')
				local openBut = wfc(wfc(centralFr, 'Buttons1'), 'Open')
				dg[#dg + 1] = function()
					-- modify amount. hide if 0 
					local amount = data.crates[crateName] or 0
					amountFr.Visible = amount > 0
					amountText.Text = amount

					-- dim modify open button if no crate
					openBut.TextTransparency = amount > 0 and 0 or 0.7
				end

				local learnMoreFr = wfc(wfc(centralFr, "Buttons2"), "LearnMore")
				learnMoreFr.MouseButton1Click:Connect(function()
					learnMore.load("crate", crateName)
				end)

				local buyFr = wfc(wfc(centralFr, "Buttons1"), "Buy")
				buyFr.MouseButton1Click:Connect(function()
					local maxAmount = floor(data.money / price)
					if maxAmount <= 0 then
						root.gotoPage("shop", "credits")
					else
						popupGui.get("amountSlider", {
							defaultAmount = 1,
							minAmount = 1,
							maxAmount = clamp(maxAmount, 1, 100), 
							onConfirmed = function(amount)
								print("request buying", amount)
								lobbyClient.fireServer("crate.buy", crateName, amount)
							end;
						})
					end
				end)

				local openBut = wfc(wfc(centralFr, "Buttons1"), "Open")
				openBut.MouseButton1Click:Connect(function()
					crateOpening.load(crateName)
				end)
			end
		end
	end

	do -- configure the learnmore page
		local learnMoreFr = wfc(rootPagesFr, "LearnMore")

		-- stats panel
		local statsFr     = wfc(wfc(learnMoreFr, "Main"), "Stats")

		-- name
		local nameFr      = wfc(learnMoreFr, "NameFrame")
		local setStText   = requireGm("ShadedTexts").setStText

		-- slidinglist
		local sliderFr    = wfc(learnMoreFr, "Sliding")
		local listFr      = wfc(sliderFr, "List")
		local itemFrTemp  = wfc(listFr, "XM8")
		itemFrTemp.Parent = nil
		local clone       = game.Clone
		local sl          = scrollingList.new(sliderFr, listFr)

		-- preview crate
		do
			local skinLib = requireGm("GunSkins")
			local psi = requireGm("ProductStaticInfo")
			local cloneTableShallow = requireGm("TableUtils").cloneTableShallow
			local gun

			-- @param skin: a skin object instead of a skinName
			local function preview(skinName)
				if gun then
					gun.destroy()
				end

				local weaponName = skinLib.getRandomWeaponName({ownedOnly = true, weapons = data.weapons})

				-- insert the skin into the temp attachments table
				local savedAttachments = data.weapons[weaponName].savedAttachments
				local attachments = savedAttachments and cloneTableShallow(savedAttachments) or {} 
				attachments.Skin = skinName

				gun = showcase3D.spawnWeapon(
					weaponName,
					"CrateLm",
					{
						attachments = attachments,
						rotChannel  = weaponName,
					}
				)
			end

			function learnMore.previewCrate(crateName)
				local self = {}

				-- init slider
				sl.clear()
				local crate = skinLib.getCrate(crateName)
				assert(crate, "invalid crateName "..crateName)

				-- add skin buttons to the slider
				local lastSkin
				for i, skinName in ipairs(crate.sortedSkins) do
					local itemFr = clone(itemFrTemp)
					local skin = skinLib.getSkin(skinName)
					assert(skin, "invalid skinName "..skinName)

					-- put name
					setStText(itemFr.Title, string.format("[%s] %s", skin.tier, skinName))

					-- put image
					psi.getAttachmentPic(skinName).Parent = itemFr.Preview
					-- skinLib.getSkinImage(skin).

					-- connect
					itemFr.MouseButton1Click:Connect(function()
						preview(skinName)
					end)

					sl.add(itemFr)
					lastSkin = skinName
				end

				preview(lastSkin)

				function self.destroy()
					if gun then
						gun.destroy()
						gun = nil
					end
				end

				return self
			end
		end

		local dancer       = nil
		local weapon       = nil
		local cratePreview = nil

		function learnMore.load(itemType, name)
			root.gotoPage("learnMore")

			statsFr.Visible = itemType == "crate"
			nameFr.Visible = itemType == "crate" or itemType == "dance"
			sliderFr.Visible = itemType == "crate"

			if itemType == "weapon" then
				camera.goto("WeaponLm")
				camera.setZoomable()
				weapon = showcase3D.spawnWeapon(name, "WeaponLm", {showStats = true, statsFr = statsFr})
			elseif itemType == "dance" then
				camera.goto("DanceLm")
				camera.setZoomable()
				setStText(nameFr, name)
				dancer = showcase3D.spawnDancer(name, "DanceLm")
			elseif itemType == "crate" then
				camera.goto("CrateLm")
				camera.setZoomable()
				setStText(nameFr, name.." Crate")
				cratePreview = learnMore.previewCrate(name)
			end
		end
		function learnMore.onLeft(page)
			if dancer then
				dancer.destroy()
			end
			if weapon then
				weapon.destroy()
			end
			if cratePreview then
				cratePreview.destroy()
			end
			camera.setNonZoomable()
			if page ~= "Customize" then
				-- camera.goto("Empty")
			end
		end
	end

	do-- configure the customization page
		local customizeFr      = wfc(rootPagesFr, "Customize")
		root.customizeFr       = customizeFr
		local customizePagesFr = wfc(customizeFr, "Pages")
		local primary          = {}
		local secondary        = {}
		local dances           = {}
		local primaryAttachments   = {}
		local secondaryAttachments = {}
		local custPages = {
			primary   = primary,
			secondary = secondary,
			dances    = dances,
			primaryAttachments   = primaryAttachments,
			secondaryAttachments = secondaryAttachments,
		}

		local psi           = requireGm("ProductStaticInfo")
		local scrollingList = requireGm("ScrollingList")
		local skinLib       = requireGm("GunSkins")
		local currPage      = "primary"-- a string

		do-- configure the page transition for customization\
			local pageIndex = {	-- for JumpToIndex. it starts at 0
				dances               = 2,
				secondary            = 1,
				primary              = 0,
				primaryAttachments   = 3,
				secondaryAttachments = 4,
			}
			local uiPageLayout = wfc(customizePagesFr, "UIPageLayout")
			local jumpToIndex = uiPageLayout.JumpToIndex
			function customize.gotoPage(pageName) 
				if pageName == currPage then return end
				print(pageName, pageIndex[pageName])
				jumpToIndex(uiPageLayout, pageIndex[pageName])
				if currPage and custPages[currPage].onLeft then
					custPages[currPage].onLeft(pageName)
				end
				if pageName and custPages[pageName].onEntered then
					custPages[pageName].onEntered(currPage)
				end
				currPage = pageName
			end
		end

		local customizeTopFr = wfc(wfc(customizeFr, "Top"), "Frame")
		do-- configure top
			local buttons = {
				primary   = wfc(customizeTopFr, "Primary"),
				dances    = wfc(customizeTopFr, "Dances"),
				secondary = wfc(customizeTopFr, "Secondary"),
			}
			for name, but in pairs(buttons) do
				connect(but.MouseButton1Click, function()
					customize.gotoPage(name)
				end)
			end

			local defPos = customizeTopFr.Position
			local tweens = {}
			function customize.onEntered()
				print("onEntered")
				for i, tween in ipairs(tweens) do
					tween:Cancel()
					tweens[i] = nil
				end
				customizeTopFr.Position = defPos + newU2(0.1, 0, 0, 0)
				tweens[#tweens + 1] = tween(customizeTopFr, 0.3, {Position = defPos})
				for _, v in pairs(buttons) do
					v.ImageLabel.ImageLabel.ImageTransparency = 1
					v.ImageLabel.xiao.text.TextTransparency = 1
					tweens[#tweens + 1] = tween(v.ImageLabel.ImageLabel, 0.4, {ImageTransparency = 0})
					tweens[#tweens + 1] = tween(v.ImageLabel.xiao.text, 0.4, {TextTransparency = 0})
				end
				custPages[currPage].onEntered()
			end
		end

		local itemFrTemp, checkEquippedTemp, checkOwnedTemp
		local plusTemp 
		do-- configure primary
			local primaryFr = wfc(customizePagesFr, "Primary")
			local statsFr   = wfc(primaryFr, "Stats")
			local sliderFr  = wfc(primaryFr, "Sliding")
			local listFr    = wfc(sliderFr, "List")

			-- scrollinglist
			itemFrTemp               = wfc(listFr, "XM8")
			itemFrTemp.Parent        = nil
			checkEquippedTemp        = wfc(itemFrTemp, "CheckEquipped")
			checkEquippedTemp.Parent = nil
			checkOwnedTemp           = wfc(wfc(listFr, "M4A1 Carbine"), "CheckOwned")
			checkOwnedTemp.Parent    = nil
			plusTemp                 = wfc(listFr, "Plus")
			plusTemp.Parent          = nil
			local clone              = game.Clone
			local sl                 = scrollingList.new(sliderFr, listFr)
			-- local items = {}

			-- current weapon 
			primary.cur = nil

			-- the equip button
			local equipFr = wfc(primaryFr, "Equip")
			local equippedFr = wfc(primaryFr, "Equipped")
			connect(equipFr.MouseButton1Click, function()
				if primary.cur then
					lobbyClient.fireServer("equip.weapon", primary.cur.weaponName, 1)
				else
					warn("customize.primary: weird, player clicks the equip button but curr weapon is nil")
				end
			end)

			-- onclick
			local function previewWeapon(weaponName, attachments)
				local isEquipped = data.loadouts[1].weapons[1].weaponName == weaponName
				if primary.cur then
					print("destroying weapon")
					primary.cur.destroy()
					primary.cur = nil
				end
				print("showing weapon with saved attachments")
				primary.cur = showcase3D.spawnWeapon(weaponName, "Primary", {
					attachments = attachments,
					showStats   = true,
					statsFr     = statsFr,
					showDots    = isEquipped,
					rotChannel  = weaponName,
					-- skinTOffset = primary.skinTOffset,
				})
				equipFr.Visible = not isEquipped
				equippedFr.Visible = isEquipped
			end

			-- load equipped primary with attc, dots, and stats panel.
			local function loadEquippedWeapon()
				local equippedPrimary = data.loadouts[1].weapons[1]
				if not primaryAttachments.loaded then
					previewWeapon(equippedPrimary.weaponName, equippedPrimary.attachments)
				end
			end

			-- local isEqualShallow = requireGm("TableUtils").isEqualShallow
			dg[#dg + 1] = function()
				loadEquippedWeapon()
				local equippedPrimary = data.loadouts[1].weapons[1]

				-- load the slider
				sl.clear()
				-- print("customize.primary: clear slider")
				for weaponName, _ in pairs(data.weapons) do
				-- for _, v in pairs(wfc(rep, "Weapons"):GetChildren()) do
				-- 	local weaponName = v.Name
					if psi.isPrimary(weaponName) and data.weapons[weaponName] then
						-- (data.weapons[weaponName] or psi.isWeaponReqMet(weaponName, data)) then
						-- print("customize.primary: loading", weaponName)

						-- local item = {}
						local itemFr = clone(itemFrTemp)
						itemFr.Title.text.Text = weaponName
						itemFr.Preview:ClearAllChildren()
						psi.getWeaponPic(weaponName).Parent = itemFr.Preview

						local isEquipped = equippedPrimary.weaponName == weaponName
						if isEquipped then
							clone(checkEquippedTemp).Parent = itemFr
						end

						-- slider button onclick
						connect(itemFr.MouseButton1Click, function()
							previewWeapon(weaponName, data.weapons[weaponName].savedAttachments or {})
						end)

						sl.add(itemFr)
					end
				end

				-- add button. should be a universal temp
				local addFr = clone(plusTemp)
				connect(addFr.MouseButton1Click, function()
					root.gotoPage("shop", "weapons")
				end)
				sl.add(addFr)
			end

			function primary.onEntered(from) 	-- wip: make cam smoother
				camera.goto("Primary", {sudden = true})
				if not primary.cur then
					loadEquippedWeapon()
				end
			end
		end

		do-- configure secondary
			local secondaryFr = wfc(customizePagesFr, "Secondary")
			local statsFr     = wfc(secondaryFr, "Stats")
			local sliderFr    = wfc(secondaryFr, "Sliding")
			local listFr      = wfc(sliderFr, "List")

			-- scrollinglist
			local clone = game.Clone
			local sl    = scrollingList.new(sliderFr, listFr)
			-- local items = {}

			-- current weapon 
			secondary.cur = nil

			-- the equip button
			local equipFr      = wfc(secondaryFr, "Equip")
			equipFr.Visible    = false
			local equippedFr   = wfc(secondaryFr, "Equipped")
			equippedFr.Visible = false
			connect(equipFr.MouseButton1Click, function()
				if secondary.cur then
					lobbyClient.fireServer("equip.weapon", secondary.cur.weaponName, 2)
				else
					warn("customize.secondary: weird, player clicks the equip button but curr weapon is nil")
				end
			end)

			local function previewWeapon(weaponName, attachments)
				local isEquipped = data.loadouts[1].weapons[2].weaponName == weaponName
				if secondary.cur then
					print("destroying weapon")
					secondary.cur.destroy()
					secondary.cur = nil
				end
				secondary.cur = showcase3D.spawnWeapon(weaponName, "Secondary", {
					attachments = attachments,
					showStats   = true,
					statsFr     = statsFr,
					showDots    = isEquipped,
					rotChannel  = weaponName,
					-- skinTOffset = secondary.skinTOffset,
				})
				equipFr.Visible = not isEquipped
				equippedFr.Visible = isEquipped			
			end

			local function loadEquippedWeapon()
				local equippedSecondary = data.loadouts[1].weapons[2]
				if not secondaryAttachments.loaded then
					previewWeapon(equippedSecondary.weaponName, equippedSecondary.attachments)
				end
			end

			dg[#dg + 1] = function()
				loadEquippedWeapon()
				local equippedSecondary = data.loadouts[1].weapons[2]

				sl.clear()
				print("customize.secondary: clear slider")
				for weaponName, _ in pairs(data.weapons) do
					if psi.isSecondary(weaponName) and data.weapons[weaponName] then
						print("customize.secondary: loading", weaponName)

						-- local item = {}
						local itemFr = clone(itemFrTemp)
						itemFr.Title.text.Text = weaponName
						itemFr.Preview:ClearAllChildren()
						psi.getWeaponPic(weaponName).Parent = itemFr.Preview

						local isEquipped = equippedSecondary.weaponName == weaponName
						if isEquipped then
							clone(checkEquippedTemp).Parent = itemFr
						end

						-- slider button onclick
						connect(itemFr.MouseButton1Click, function()
							previewWeapon(weaponName, data.weapons[weaponName].savedAttachments or {})
						end)

						sl.add(itemFr)
					end
				end

				-- add button. should be a universal temp
				local addFr = clone(plusTemp)
				connect(addFr.MouseButton1Click, function()
					root.gotoPage("shop", "weapons")
				end)
				sl.add(addFr)
			end

			function secondary.onEntered(from) 	-- wip: make cam smoother
				camera.goto("Secondary", {sudden = true})
				if not secondary.cur then
					loadEquippedWeapon()
				end
			end
		end

		local isAttachmentEquipped   = psi.isAttachmentEquipped
		local isAttachmentOwned      = psi.isAttachmentOwned
		local isAttachmentBuyable    = psi.isAttachmentBuyable
		local isAttachmentUnlockable = psi.isAttachmentUnlockable
		local isAttachmentReqMet     = psi.isAttachmentReqMet
		local getAttachmentPrice     = psi.getAttachmentPrice
		local getDefaultAttachmentPic= psi.getDefaultAttachmentPic
		local getAttachmentPic       = psi.getAttachmentPic

		root.primaryAttachments = primaryAttachments
		do-- configure primaryAttachments
			local primaryAttachmentsFr = wfc(customizePagesFr, "PrimaryAttachments")
			local statsFr              = wfc(primaryAttachmentsFr, "Stats")
			local sliderFr             = wfc(primaryAttachmentsFr, "Sliding")
			local listFr               = wfc(sliderFr, "List")
			local sl                   = scrollingList.new(sliderFr, listFr)

			local clone = game.Clone
			local wc    = requireGm("WeaponCustomization")

			-- VAAAAARRRRS
			-- local primary.cur = nil
			local weaponName, equippedAttachments, attachpointName, cas
			local pa  = nil  -- previewAttachment
			local pas = nil  -- previewAttachments = equippedAttachment + pa - conficts
			primaryAttachments.loaded = false

			-- buttons
			local equipFr    = wfc(primaryAttachmentsFr, "Equip")
			local equippedFr = wfc(primaryAttachmentsFr, "Equipped")
			local buyFr      = wfc(primaryAttachmentsFr, "Buy")
			local buyCrateFr = wfc(primaryAttachmentsFr, "BuyCrate")
			do
				equipFr.Visible    = false
				equippedFr.Visible = false
				buyFr.Visible      = false
				buyCrateFr.Visible = false
				connect(equipFr.MouseButton1Click, function() 
					if weaponName and pas then
						lobbyClient.fireServer("equip.attachment", weaponName, pas, 1)
					else
						warn("customize.primaryAttachments: weird, player clicks the equip button but curr weapon or pas is nil", weaponName, pas)
					end
				end)
				buttonSounds.addPurchaseSound(buyFr)
				connect(buyFr.MouseButton1Click, function()
					if primary.cur then
						if data.money >= psi.getAttachmentPrice(pa) then
							lobbyClient.fireServer("buy.attachment", weaponName, pa, 1)
						else
							root.gotoPage("shop", "credits")
						end
					else
						warn("customize.primaryAttachments: weird, player clicks the buy button but curr weapon or pa is nil", weaponName, pa)
					end					
				end)
				connect(buyCrateFr.MouseButton1Click, function()
					root.gotoPage("shop", "crates")
				end)				
			end

			-- reqs
			local unlockFr  = wfc(primaryAttachmentsFr, "Unlock")
			local priceFr   = wfc(unlockFr, "Price")
			priceFr.Visible = false
			local reqFr     = wfc(unlockFr, "Req")
			reqFr.Visible   = false

			-- @param: data, weaponName, equippedAttachments, attachpointName
			-- @param a: the name of the attachment. nil refers to the default attc. 
			local function previewAttachment(a)
				pa = a
				pas = wc.getPreviewAttachments(weaponName, equippedAttachments, attachpointName, a)

				local isEquipped   = isAttachmentEquipped(a, data, 1, attachpointName)
				local isOwned      = not a or isAttachmentOwned(a, data, weaponName)  -- default attc is always owned
				local isBuyable    = isAttachmentBuyable(a)
				local isUnlockable = isAttachmentUnlockable(a)
				local isAvailableFromCrate = skinLib.getSourceCrate(a)

				if primary.cur then
					print("destroying primary")
					primary.cur.destroy()
					primary.cur = nil
				end
				print("showing primary with pa")
				primary.cur   = showcase3D.spawnWeapon(weaponName, "Primary", {
					attachments = pas,
					showStats   = true,
					statsFr     = statsFr,
					showDots    = isEquipped,
					selectedDot = attachpointName,
					rotChannel  = weaponName,
				})

				equippedFr.Visible = isEquipped
				equipFr.Visible    = isEquipped or isOwned
				buyFr.Visible      = isBuyable and not (isEquipped or isOwned)
				reqFr.Visible      = not (isEquipped or isOwned)   -- theres no "and is unlockable" because we want to show "available from crates"
				priceFr.Visible    = isBuyable and not (isEquipped or isOwned)
				buyCrateFr.Visible = not isOwned and not isEquipped and isAvailableFromCrate
				if reqFr.Visible then
					local _, msg = isAttachmentReqMet(weaponName, a, data)
					if msg == "Not unlockable" then
						reqFr.Visible = false
					else
						reqFr.TextLabel.Text = a and msg or "error"
					end
				end
				if priceFr.Visible then
					priceFr.TextLabel.Text = a and "$ "..getAttachmentPrice(a).." " or "error"
				end
			end

			-- @param: cas, data, weaponName
			local function loadSlider() 
				sl.clear()
				-- print("customize.primaryAttachments: clear slider")

				-- @param attachmentName: nil stands for default
				local function loadAttachmentFr(attachmentName)
					-- print("customize.primaryAttachments: loading", attachmentName)

					-- set the name and the pic
					local itemFr = clone(itemFrTemp)
					itemFr.Title.text.Text = attachmentName or "Default"
					itemFr.Preview:ClearAllChildren()
					if attachmentName then
						getAttachmentPic(attachmentName).Parent = itemFr.Preview -- @todo
					else
						getDefaultAttachmentPic(weaponName, attachpointName).Parent = itemFr.Preview
					end

					-- put checkmarks
					local isEquipped = isAttachmentEquipped(attachmentName, data, 1, attachpointName)
					local isOwned = not attachmentName or isAttachmentOwned(attachmentName, data, weaponName)
					if isEquipped then
						clone(checkEquippedTemp).Parent = itemFr
					elseif isOwned then
						clone(checkOwnedTemp).Parent = itemFr
					else
						if psi.isSkin(attachmentName) then
							itemFr:Destroy() 		-- dont show un-owned skins
							return
						end
					end

					-- slider button onclick
					connect(itemFr.MouseButton1Click, function()
						previewAttachment(attachmentName)
					end)

					sl.add(itemFr)
				end

				loadAttachmentFr(nil) -- the default attachment
				for attachmentName, v in pairs(attachpointName == "Skin" and skinLib.skins or cas[attachpointName]) do
					if not (attachpointName == "Skin" and v.isTestSkin and not db.showTestSkins) then
						loadAttachmentFr(attachmentName)
					end
				end
			end

			function primaryAttachments.load(weaponName_, equippedAttachments_, attachpointName_, cas_)
				customize.gotoPage("primaryAttachments")
				primaryAttachments.loaded = true

				weaponName          = weaponName_
				equippedAttachments = equippedAttachments_
				attachpointName     = attachpointName_
				cas                 = cas_
				previewAttachment(equippedAttachments[attachpointName]) -- set to the equiped one by default (could be nil)
				loadSlider()	
			end

			dg[#dg + 1] = function()
				if primaryAttachments.loaded then
					previewAttachment(pa)
					loadSlider()
				end
			end

			function primaryAttachments.onEntered()
				-- camera.goto("PrimaryAttachments", {sudden = true})
				camera.goto("Primary", {sudden = true})
			end
			function primaryAttachments.onLeft()
				if primaryAttachments.loaded then
					weaponName          = nil
					equippedAttachments = nil
					attachpointName     = nil
					cas                 = nil
					primaryAttachments.loaded = false
					if primary.cur then
						primary.cur.destroy()
						primary.cur = nil
					else
						warn("primaryAttachments: weird. left configuring attachments but weapon hasn't spawned")
					end
				end
			end
		end

		root.secondaryAttachments = secondaryAttachments
		do-- configure secondaryAttachments
			local secondaryAttachmentsFr = wfc(customizePagesFr, "SecondaryAttachments")
			local statsFr                = wfc(secondaryAttachmentsFr, "Stats")
			local sliderFr               = wfc(secondaryAttachmentsFr, "Sliding")
			local listFr                 = wfc(sliderFr, "List")
			local sl                     = scrollingList.new(sliderFr, listFr)

			local clone = game.Clone
			local wc    = requireGm("WeaponCustomization")

			-- VAAAAARRRRS
			-- local secondary.cur = nil
			local weaponName, equippedAttachments, attachpointName, cas
			local pa  = nil  -- previewAttachment
			local pas = nil  -- previewAttachments = equippedAttachment + pa - conficts
			secondaryAttachments.loaded = false

			-- buttons
			local equipFr    = wfc(secondaryAttachmentsFr, "Equip")
			local equippedFr = wfc(secondaryAttachmentsFr, "Equipped")
			local buyFr      = wfc(secondaryAttachmentsFr, "Buy")
			local buyCrateFr = wfc(secondaryAttachmentsFr, "BuyCrate")
			do
				equipFr.Visible    = false
				equippedFr.Visible = false
				buyFr.Visible      = false
				buyCrateFr.Visible = false
				connect(equipFr.MouseButton1Click, function() 
					if weaponName and pas then
						lobbyClient.fireServer("equip.attachment", weaponName, pas, 2)
					else
						warn("customize.secondaryAttachments: weird, player clicks the equip button but curr weapon or pas is nil", weaponName, pas)
					end
				end)
				buttonSounds.addPurchaseSound(buyFr)
				connect(buyFr.MouseButton1Click, function()
					if secondary.cur then
						if data.money >= psi.getAttachmentPrice(pa) then
							lobbyClient.fireServer("buy.attachment", weaponName, pa, 2)
						else
							root.gotoPage("shop", "credits")
						end
					else
						warn("customize.secondaryAttachments: weird, player clicks the buy button but curr weapon or pa is nil", weaponName, pa)
					end					
				end)
				connect(buyCrateFr.MouseButton1Click, function()
					root.gotoPage("shop", "crates")
				end)				
			end

			-- reqs
			local unlockFr  = wfc(secondaryAttachmentsFr, "Unlock")
			local priceFr   = wfc(unlockFr, "Price")
			priceFr.Visible = false
			local reqFr     = wfc(unlockFr, "Req")
			reqFr.Visible   = false

			-- @param: data, weaponName, equippedAttachments, attachpointName
			local function previewAttachment(a)
				pa = a
				pas = wc.getPreviewAttachments(weaponName, equippedAttachments, attachpointName, a)

				local isEquipped   = isAttachmentEquipped(a, data, 2, attachpointName)
				local isOwned      = not a or isAttachmentOwned(a, data, weaponName)  -- default attc is always owned
				local isBuyable    = isAttachmentBuyable(a)
				local isUnlockable = isAttachmentUnlockable(a)
				local isAvailableFromCrate = skinLib.getSourceCrate(a)

				if secondary.cur then
					print("destroying secondary")
					secondary.cur.destroy()
					secondary.cur = nil
				end
				print("showing secondary with pa")
				secondary.cur = showcase3D.spawnWeapon(weaponName, "Secondary", {
					attachments = pas,
					showStats   = true,
					statsFr     = statsFr,
					showDots    = isEquipped,
					selectedDot = attachpointName,
					rotChannel  = weaponName,
				})

				-- for button and req and price @todo
				equippedFr.Visible = isEquipped
				equipFr.Visible    = isEquipped or isOwned
				buyFr.Visible      = isBuyable and not (isEquipped or isOwned)
				reqFr.Visible      = not (isEquipped or isOwned)   -- theres no "and is unlockable" because we want to show "available from crates"
				priceFr.Visible    = isBuyable and not (isEquipped or isOwned)
				buyCrateFr.Visible = not isOwned and not isEquipped and isAvailableFromCrate
				if reqFr.Visible then
					local _, msg = isAttachmentReqMet(weaponName, a, data)
					if msg == "Not unlockable" then
						reqFr.Visible = false
					else
						reqFr.TextLabel.Text = a and msg or "error"
					end
				end
				if priceFr.Visible then
					priceFr.TextLabel.Text = a and "$ "..getAttachmentPrice(a).." " or "error"
				end
			end

			-- @param: cas, data, weaponName
			local function loadSlider() 
				sl.clear()
				-- print("customize.secondaryAttachments: clear slider")

				local function loadAttachmentFr(attachmentName)
					-- print("customize.secondaryAttachments: loading", attachmentName)

					-- set the name and the pic
					local itemFr = clone(itemFrTemp)
					itemFr.Title.text.Text = attachmentName or "Default"
					itemFr.Preview:ClearAllChildren()
					if attachmentName then
						psi.getAttachmentPic(attachmentName).Parent = itemFr.Preview
					else
						psi.getDefaultAttachmentPic(weaponName, attachpointName).Parent = itemFr.Preview
					end

					-- put checkmarks
					local isEquipped = isAttachmentEquipped(attachmentName, data, 2, attachpointName)
					local isOwned = not attachmentName or isAttachmentOwned(attachmentName, data, weaponName)
					if isEquipped then
						clone(checkEquippedTemp).Parent = itemFr
					elseif isOwned then
						clone(checkOwnedTemp).Parent = itemFr
					else
						if psi.isSkin(attachmentName) then
							itemFr:Destroy() 		-- dont show un-owned skins
							return
						end
					end
					
					-- slider button onclick
					connect(itemFr.MouseButton1Click, function()
						previewAttachment(attachmentName)
					end)

					sl.add(itemFr)
				end

				loadAttachmentFr(nil) -- the default attachment
				for attachmentName, v in pairs(attachpointName == "Skin" and skinLib.skins or cas[attachpointName]) do
					if not (attachpointName == "Skin" and v.isTestSkin and not db.showTestSkins) then
						loadAttachmentFr(attachmentName)
					end
				end
			end

			function secondaryAttachments.load(weaponName_, equippedAttachments_, attachpointName_, cas_)
				customize.gotoPage("secondaryAttachments")
				secondaryAttachments.loaded = true

				weaponName          = weaponName_
				equippedAttachments = equippedAttachments_
				attachpointName     = attachpointName_
				cas                 = cas_
				previewAttachment(equippedAttachments[attachpointName]) -- set to the equiped one by default (could be nil)
				loadSlider()	
			end

			dg[#dg + 1] = function()
				if secondaryAttachments.loaded then
					previewAttachment(pa)
					loadSlider()
				end
			end

			function secondaryAttachments.onEntered()
				-- camera.goto("SecondaryAttachments", {sudden = true})
				camera.goto("Secondary", {sudden = true})
			end
			function secondaryAttachments.onLeft()
				if secondaryAttachments.loaded then
					weaponName          = nil
					equippedAttachments = nil
					attachpointName     = nil
					cas                 = nil
					secondaryAttachments.loaded = false
					if secondary.cur then
						secondary.cur.destroy()
						secondary.cur = nil
					else
						warn("secondaryAttachments: weird. left configuring attachments but weapon hasn't spawned")
					end
				end
			end
		end

		do-- configure dances
			local dancesFr = wfc(customizePagesFr, "Dances")
			local sliderFr = wfc(dancesFr, "Sliding")
			local listFr = wfc(sliderFr, "List")

			-- scrolling list
			local clone = game.Clone
			local sl = scrollingList.new(sliderFr, listFr)

			-- current dancer
			local cur = nil

			-- the equip button
			local equipFr = wfc(dancesFr, "Equip")
			local equippedFr = wfc(dancesFr, "Equipped")
			connect(equipFr.MouseButton1Click, function()
				if cur then
					lobbyClient.fireServer("equip.dance", cur.danceName, 2)
				else
					warn("customize.secondary: weird, player clicks the equip button but curr weapon is nil")
				end
			end)

			-- onclick
			local function previewDance(danceName)
				if cur then
					cur.destroy()
				end
				cur = showcase3D.spawnDancer(danceName, "Dance")

				local isEquipped = data.loadouts[1].dance == danceName 

				equipFr.Visible    = not isEquipped
				equippedFr.Visible = isEquipped
			end

			-- load the slider
			dg[#dg + 1] = function()
				previewDance(data.loadouts[1].dance)

				sl.clear()
				for danceName, _ in pairs(data.dances) do
					local itemFr = clone(itemFrTemp)
					itemFr.Title.text.Text = danceName
					itemFr.Preview:ClearAllChildren()
					psi.getDancePic(danceName).Parent = itemFr.Preview 		-- @todo

					local isEquipped = data.loadouts[1].dance == danceName   -- @important
					if isEquipped then
						clone(checkEquippedTemp).Parent = itemFr
					end

					--slider button onclick
					connect(itemFr.MouseButton1Click, function()
						previewDance(danceName)
					end)

					sl.add(itemFr)
				end

				-- add button. should be a universal temp
				local addFr = clone(plusTemp)
				connect(addFr.MouseButton1Click, function()
					root.gotoPage("shop", "dances")
				end)
				sl.add(addFr)
			end			

			function dances.onEntered()
				camera.goto("Dance")
			end
		end

		function customize.onEntered()
			camera.setZoomable()
			print("customize.onEntered()")
			if currPage and custPages[currPage].onEntered then
				print(currPage)
				custPages[currPage].onEntered()
			end
		end
		function customize.onLeft()
			camera.goto("Empty")
			camera.setNonZoomable()
		end
	end

	do -- configure the crateopening page
		local crateOpeningFr = wfc(rootPagesFr, "CrateOpening")
		local crateNameFr = wfc(crateOpeningFr, "CrateName")
		local skinNameFr = wfc(crateOpeningFr, "SkinName")

		local skinLib = requireGm("GunSkins")
		local tweenModelCf = requireGm("Tweening").tweenModelCf

		-- vars
		local gun       = nil
		local cons      = {}
		local crateName = nil 		-- the crate thats currently opening
															-- non-nil iff curretnly-opening


		-- timings
		local ts = {
			packup           = 0.5,
			packdown         = 0.5,
			gunDown          = 2,
			gunForward       = 0.3,
			beforeGunForward = 0.2,
			dragleft         = 0.05,
			dragright        = 1,
			showButtonDelay  = 0.1,
			showButtonDur    = 0.2,
			particleDur      = 0.05,
			openAllDelay     = 2.33,
		}

		-- buttons
		local openButs   = wfc(crateOpeningFr, "OpenButtons")
		local openBut    = wfc(openButs, "Open")
		local openAllBut = wfc(openButs, "OpenAll")
		-- leave button. static connection
		local leaveButs  = wfc(crateOpeningFr, "LeaveButtons")
		local leaveBut   = wfc(leaveButs, "Leave")
		leaveBut.MouseButton1Click:Connect(function()
			root.gotoPage("shop", "crates")
		end)
		local setStText = requireGm("ShadedTexts").setStText
		do -- buttons
			-- local openTweens s {}
			function crateOpening.showOpen(bool)
				openButs.Visible = bool
			end
			function crateOpening.showLeave(bool)
				leaveButs.Visible = bool
			end
		end

		-- drag and pack poses
		local crateOpeningParts = wfc(workspace, "CrateOpening")
		local packPos 	 -- "up" / "down"
		do -- pack
			local packModel = wfc(crateOpeningParts, "Model")
			local packPoses = {
				up = packModel.PrimaryPart.CFrame,
				down = packModel.PrimaryPart.CFrame - Vector3.new(0, 10, 0),
			}
			local packTween  -- the tween object

			function crateOpening.animatePackPos(posName)
				if packPos ~= posName then
					packPos = posName
				
					local pos = packPoses[posName]

					if packTween then
						packTween.cancel()
						packTween = nil
					end
					local T = ts['pack'..posName]
					packTween = tweenModelCf(packModel, T, pos)
					wait(T)
				end
			end

			local dragHolder = wfc(packModel, "Drag")
			local dragPosDef = dragHolder.CFrame
			local dragPoses  = {
				left = dragPosDef - Vector3.new(0, 10, 0),
				right = dragPosDef + Vector3.new(0, 0, 2),
			}
			local dragTween = nil
			function crateOpening.setDragPos(posName)
				if dragTween then
					dragTween:Cancel()
					dragTween = nil
				end
				local pos = dragPoses[posName]
				local T = ts["drag"..posName]
				dragTween = tween(dragHolder, T, {CFrame = pos})
				wait(T)
			end
		end

		-- title (SkinName)
		do -- 
			local skinNameFr = wfc(crateOpeningFr, "SkinName")
			function crateOpening.setTitle(str, color)
				color = color or Color3.fromRGB(230, 230, 230)

				setStText(skinNameFr, str)
				skinNameFr.text.TextColor3 = color
			end
		end
		crateOpening.setTitle("")


		function crateOpening.playInitAni()
			crateOpening.animatePackPos('down')
			crateOpening.setDragPos('left')
			crateOpening.setTitle("")
			crateOpening.showOpen(false)
			crateOpening.showLeave(false)
		end
		spawn(crateOpening.playInitAni)
		function crateOpening.playReadyAnimation()  -- animati0n before opening
			crateOpening.animatePackPos('up')
			crateOpening.setTitle("")
			wait(ts.showButtonDelay)
			crateOpening.showOpen(true)
		end
		function crateOpening.playOpeningAni()
			crateOpening.setTitle("")

			if gun then
				gun.moveTo("CrateResultDown", ts.gunDown)  -- async
			end
			crateOpening.animatePackPos("up")

			wait(ts.delayBeforeDrag)
			crateOpening.setDragPos('right')
		end
		local particles = {}
		do
			for _, v in ipairs(crateOpeningParts:GetChildren()) do
				if v.Name == "eff" then
					for _, u in ipairs(v:GetChildren()) do
						particles[#particles + 1] = u
					end
				end
			end
			function crateOpening.setParticlesEnabled(bool)
				for _, v in ipairs(particles) do
					v.Enabled = bool
				end
			end
		end
		function crateOpening.playOpenedAni(skinName, weaponName)
			-- particles
			spawn(function()
				crateOpening.setParticlesEnabled(true)
				wait(ts.particleDur)
				crateOpening.setParticlesEnabled(false)
			end)

			do -- get the gun with that skin
				if gun then gun.destroy() end
				local cloneTableShallow = requireGm("TableUtils").cloneTableShallow
				local savedAttachments = data.weapons[weaponName] and data.weapons[weaponName].savedAttachments
				local attachments = savedAttachments and cloneTableShallow(savedAttachments) or {} 
				attachments.Skin = skinName
				gun = showcase3D.spawnWeapon(
					weaponName,
					"CrateResult1",
					{
						attachments = attachments,
						-- rotChannel = weaponName,
					}
				)
			end

			wait(ts.beforeGunForward)
			gun.moveTo("CrateResult2", ts.gunForward)
			crateOpening.animatePackPos("down")
			crateOpening.setDragPos('left')
		end

		-- data updated -> update the number of crates
		local function getAmountLeft()
			return data.crates[crateName] or 0
		end
		local function updateCrateText()
			if crateName then
				setStText(crateNameFr, string.format("%s Crate [x%d]", crateName, getAmountLeft()))
			end
		end
		dg[#dg + 1] = updateCrateText

		function crateOpening.load(crateName_)
			
			root.gotoPage("crateOpening")
			camera.goto("CrateOpening")
			camera.setZoomable()

			-- shows the name of the crate with amount
			crateName = crateName_
			updateCrateText()

			-- move the pack from down to up
			crateOpening.playReadyAnimation()

			local id = 0
			-- buttons
			local openId = 0
			cons[#cons + 1] = openBut.MouseButton1Click:Connect(function()
				openId = id
			end)
			cons[#cons + 1] = openAllBut.MouseButton1Click:Connect(function()
				openId = 'all'
				crateOpening.showOpen(false)
			end)

			while getAmountLeft() > 0 do
				id = id + 1

				if openId == 'all' then
					wait(ts.openAllDelay)
				else
					repeat wait(0.2) until openId == id or openId == 'all'
				end

				-- request using the crate
				local suc, a1, a2, a3, a4
				spawn(function()
					suc, a1, a2, a3, a4 = lobbyClient.invokeServer("crate.use", crateName)
					print("get: ", suc, a1, a2, a3, a4)
				end)

				-- play the animation
				crateOpening.playOpeningAni()

				-- wait for server
				repeat wait(0.2) until suc

				-- show the result
				if suc == "gotSkin" or suc == "gotCreditRefund" then
					local skinName, weaponName = a1, a2

					local skin = skinLib.getSkin(skinName)
					local tier = skin.tier
					local titleStr = string.format("[%s] %s - %s", tier, skinName, weaponName)

					if suc == "gotSkin" then
					else
						local refund = a3
						titleStr = titleStr..string.format(" (Duplicated skin: refunded $%d)", refund)
					end
					crateOpening.setTitle(titleStr, skinLib.getTierColor(tier))

					crateOpening.playOpenedAni(skinName, weaponName)
				else
					crateOpening.setTitle("ERR: "..(suc or "unknown"))
					wait(3)
					root.gotoPage("shop", "crates")
				end
			end

			crateOpening.showLeave(true)
			crateOpening.showOpen(false)
		end

		function crateOpening.onLeft()
			camera.setNonZoomable()
			for i, con in ipairs(cons) do
				con:Disconnect()
				cons[i] = nil
			end
			crateName = nil
			if gun then
				gun.destroy()
				gun = nil
			end
			spawn(crateOpening.playInitAni)
		end
	end

	do-- goto home page by default
		root.gotoPage("home")
	end
end

do-- camera
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable

	do -- goto
		local ffcWia = game.FindFirstChildWhichIsA
		local poses = {}
		for _, v in ipairs(wfc(workspace, "CamPositions"):GetChildren()) do
			poses[v.Name] = v.CFrame
			if ffcWia(v, "Decal") then
				ffcWia(v, "Decal"):Destroy()
			end
			v.Transparency = 1
		end

		local camTween = nil
		local tween = requireGm("Tweening").tween
		local at = 0.4
		function camera.goto(pos, args)
			print("cam goto", pos)
			args = args or {}
			if camTween then
				camTween:Cancel()
			end
			-- if args.sudden then
			-- 	cam.CFrame = poses[pos]
			-- 	print(1)
			-- else
				camTween = tween(cam, at, {CFrame = poses[pos]})
			-- 	print(2)
			-- end
		end
		camera.goto("Empty")
	end

	do -- zoom
		local defFov = 70
		local minFov = 50
		local maxFov = 90
		cam.FieldOfView = 70

		local cons = {}
		local p = 0.5
		local p_ = 0.5
		local myMath = requireGm("Math")
		local clamp = myMath.clamp
		local lerp = myMath.lerp
		local smoother = requireGm("Interpolation").getSmoother(10, 0.8)

		local uis = game:GetService("UserInputService")
		local mouse = lp:GetMouse()
		local itMouseWheel = Enum.UserInputType.MouseWheel

		local oid = 0
		function camera.setZoomable()
			oid = oid + 1
			cons[#cons + 1] = connect(uis.InputChanged, function(input, g)
				-- if g then return end
				local it = input.UserInputType
				if it == itMouseWheel then
					if mouse.Y / mouse.ViewSizeY <= 0.83 then -- temp solution for not conflicting with sliding bars
						p_ = clamp(p_ - input.Position.z / 10, 0, 1)
					end
				end
			end)
			spawn(function()
				local hb = game:GetService("RunService").Heartbeat
				local evwait = game.Changed.Wait
				while #cons > 0 do
					local dt = evwait(hb)
					p = smoother(p, p_, dt)
					cam.FieldOfView = lerp(minFov, maxFov, p)
				end
			end)
		end
		function camera.setNonZoomable()
			oid = oid + 1
			for i, con in ipairs(cons) do
				con:Disconnect()
				local savedOid = oid
				delay(1, function()
					if oid == savedOid then
						cons[i] = nil
					end
				end)
			end
			p_ = 0.5
		end
	end
end

do-- showcase3D
	local myMath = requireGm("Math")

	local spawns = {}
	local ffcWia = game.FindFirstChildWhichIsA
	for _, v in ipairs(wfc(workspace, "Spawns"):GetChildren()) do
		spawns[v.Name] = v.CFrame
		v.Transparency = 1
		if ffcWia(v, "Decal") then
			ffcWia(v, "Decal"):Destroy()
		end
	end

	do-- spawnDancer: should not be your char but npc humanoid
		local charTemp          = game.StarterPlayer.StarterCharacter
		local clone             = game.Clone
		local destroy           = game.Destroy
		local spcf              = Instance.new("Model").SetPrimaryPartCFrame
		local rigHelper         = requireGm("RigHelper")
		local keyframeAnimation = requireGm("KeyframeAnimation")
		local animations        = requireGm("TppAnimations")()

		function showcase3D.spawnDancer(danceName, spawnName)
			local self = {
				danceName = danceName
			}

			local char = clone(charTemp)
			spcf(char, spawns[spawnName])
			char.HumanoidRootPart.Anchored = true

			local aniparts, joints, defC0, sounds, stash = {}, {}, {}, {}, {}
			do
				rigHelper.initRig(char, aniparts, joints, defC0)
				rigHelper.setCharVisibility("tpp", true, char, aniparts)
				rigHelper.setCharVisibility("fpp", false, char, aniparts)
		  end

		  local kfs = keyframeAnimation.new(aniparts, joints, defC0, stash)
		  kfs.load(animations, danceName, {snapFirstFrame = true})

		  char.Parent = workspace

		  local running = true
		  spawn(function()
		  	local rs = game:GetService("RunService").RenderStepped
		  	local evwait = game.Changed.Wait
		  	while running do
		  		local dt = evwait(rs)
		  		kfs.playAnimation(dt)
		  	end
		  end)

			function self.destroy()
				running = false
				destroy(char)
			end

			return self
		end
	end

	do-- rotable
		local abs = math.abs
		local cylToCf = myMath.cylToCf
		local spcf = Instance.new("Model").SetPrimaryPartCFrame

		local itRMB           = Enum.UserInputType.MouseButton2
		local itMouseMovement = Enum.UserInputType.MouseMovement
		local itMouseWheel    = Enum.UserInputType.MouseWheel
		-- local mbLockCenter          = Enum.MouseBehavior.LockCenter
		local mbLockCurrentPosition = Enum.MouseBehavior.LockCurrentPosition
		local mbDefault             = Enum.MouseBehavior.Default

		-- local T = 0
		-- local mouseT = -1
		local savedY = {}
		local savedX = {}

		function showcase3D.setRotable(model, channel, self)
			local cons = {}

			local y, x

			if channel then
				y, x = savedY[channel] or 0, savedX[channel] or 0
			else
				y, x = 0, 0
			end	
			local sy, sx = 0, 0

			self.defCf = model.PrimaryPart.CFrame
			spcf(model, self.defCf * cylToCf(y, x))

			local uis = game:GetService("UserInputService")
			cons[#cons + 1] = connect(uis.InputBegan, function(input, g)
				-- if g then return end
				local it = input.UserInputType

				if it == itRMB then
					rmbHold  = true
					uis.MouseBehavior = mbLockCurrentPosition
					uis.MouseIconEnabled = false
					sy, sx = 0, 0
				end
			end)
			cons[#cons + 1] = connect(uis.InputEnded, function(input, g)
				-- if g then return end
				local it = input.UserInputType

				if it == itRMB then
					rmbHold  = false
					uis.MouseBehavior = mbDefault
					uis.MouseIconEnabled = true
				end
			end)
			cons[#cons + 1] = connect(uis.InputChanged, function(input, g)
				-- if g then return end
				local it = input.UserInputType

				if it == itMouseMovement then
					local mult = 0.5
					
					local rawy = mult * input.Delta.x
					local rawx = mult * input.Delta.y

					if sy == 0 and sx == 0 then
						if abs(rawy) > abs(rawx) then
							sy = 1
							sx = 0
						elseif abs(rawy) < abs(rawx) then
							sy = 0
							sx = 1
						end
					end

					y = y + rawy * sy
					x = x + rawx * sx

					if model and model.PrimaryPart and not self.isTweening then
						spcf(model, self.defCf * cylToCf(y, x))
						if channel then
							savedY[channel], savedX[channel] = y, x
						end
					end
				end
			end)

			-- local hb = game:GetService("RunService").Heartbeat
			-- local evwait = game.Changed.Wait
			-- spawn(function()
			-- 	while evwait(hb) do

			-- 		T = T + 1
			-- 	end
			-- end)
			return cons
		end
	end

	do-- spawn weapon
		local wc = requireGm("WeaponCustomization")
		local destroy = game.Destroy
		local spcf = Instance.new("Model").SetPrimaryPartCFrame
		local tweenModelCf = requireGm("Tweening").tweenModelCf

		local skinTOffset

		function showcase3D.spawnWeapon(weaponName, spawnName, args)
			args.attachments = args.attachments or {}

			local self = {
				weaponName = weaponName,
				attachments = args.attachments,
				isTweening = false,
			}

			local model, stats, _, cas, skinStep = wc.get(weaponName, args.attachments, "fpp", {skinTOffset = skinTOffset})
			model.PrimaryPart.Anchored = true
			model.Parent = workspace
			spcf(model, spawns[spawnName])

			local cons = {}
			-- if args.rotChannel then
			 	cons = showcase3D.setRotable(model, args.rotChannel, self)
			-- end

			args = args or {}
			args.slotId = spawnName == "Primary" and 1 or 2
			local statsController = nil
			if args.showStats then
				statsController = showcase3D.showStats(args.statsFr, stats, args.selectedDot or "weapon")
			end

			local dotsController = nil
			if args.showDots then
				dotsController = showcase3D.showDots(model, weaponName, cas, args)
			end

			if skinStep then
				spawn(function()
					local hb = game:GetService("RunService").Heartbeat
					local evwait = game.Changed.Wait
					while skinStep do
						skinTOffset = skinStep(evwait(hb))
					end
				end)
			else
				skinTOffset = 0
			end

			local tweenModelObj 
			function self.moveTo(spawnName, T)
				if tweenModelObj then
					tweenModelObj.cancel()
				end
				self.isTweening = true
				tweenModelObj = tweenModelCf(model, T, spawns[spawnName], {callback = function()
					self.isTweening = false
					self.defCf = model.PrimaryPart.CFrame
				end})
			end

			function self.destroy()
				destroy(model)
				for i, con in ipairs(cons) do
					con:Disconnect()
					cons[i] = nil
				end
				if statsController then
					statsController.destroy()
				end
				if dotsController then
					dotsController.destroy()
				end
				if skinStep then
					skinStep = nil
				end
				if tweenModelObj then
					tweenModelObj.cancel()
				end
				self = nil
			end

			return self
		end
	end

	do-- show dots
		local clone = game.Clone
		local destroy = game.Destroy
		local countDictSize = requireGm("TableUtils").countDictSize
		local dotsHolder = wfc(root.customizeFr, "DotsHolder")
		local selectedDotTemp = wfc(dotsHolder, "Selected")
		local nonSelectedDotTemp = wfc(dotsHolder, "NonSelected")
		selectedDotTemp.Parent = nil
		nonSelectedDotTemp.Parent = nil
		local setStText = requireGm("ShadedTexts").setStText

		local mouse = lp:GetMouse()
		local newV2 = Vector2.new
		local R     = 20
		local function isMouseNearGui(g)
			return (newV2(mouse.X, mouse.Y) - g.AbsolutePosition).magnitude^2 <= R*R
		end

		function showcase3D.showDots(model, weaponName, cas, args)
			local self = {}

			local running = true
			function self.destroy()
				running = false
			end

			local dots = {}
			for attachpointName, attachments in pairs(cas) do
				if countDictSize(attachments) > 0 or attachpointName == "Skin" then
					-- print("showing", attachpointName)
					local dot = {}

					local isSelectedDot = args.selectedDot == attachpointName
					local dotFr = clone(isSelectedDot and selectedDotTemp or nonSelectedDotTemp)
					-- dot.fr = 
					local attachpointNameFr = dotFr.Frame
					setStText(attachpointNameFr, attachpointName)
					attachpointNameFr.text.TextTransparency = 1
					attachpointNameFr.shade.TextTransparency = 1
					dotFr.Visible = false

					-- local setId = 0
					local visible = false
					local transTweens = {}
					local function setAttachpointNameFrVisible(visible_)
						-- setId = setId + 1
						if visible ~= visible_ then
							visible = visible_
							for _, v in ipairs(transTweens) do
								v:Cancel()
							end
							local trans = visible and 0 or 1
							transTweens[#transTweens + 1] = tween(attachpointNameFr.text, 0.2, {TextTransparency = trans})
							transTweens[#transTweens + 1] = tween(attachpointNameFr.shade, 0.2, {TextTransparency = trans})
						end
					end
					-- follow the attachpoint 
						-- and fade in attachpoint name when hovering
					local attachpoint = attachpointName ~= "Skin" and model.attachpoints[attachpointName] or model.primary
					local cam = workspace.Camera
					local w2s = cam.WorldToViewportPoint
					function dot.step()
						local v3, onscreen = w2s(cam, attachpoint.Position)
						dotFr.Position = newU2(0, v3.x, 0, v3.y)
						dotFr.Visible = onscreen
						setAttachpointNameFrVisible(isMouseNearGui(dotFr))
					end

					-- -- hover animation
					-- local cons = {}
					-- cons[#cons + 1] = connect(dotFr.)

					connect(dotFr.MouseButton1Click, function()
						root[args.slotId == 1 and "primaryAttachments" or "secondaryAttachments"].load(weaponName, args.attachments, attachpointName, cas)
					end)

					function dot.destroy()
						destroy(dotFr)
					end

					dotFr.Parent = dotsHolder
					dots[#dots + 1] = dot
				else
					print("skipping", attachpointName)
				end
			end
			spawn(function()
				local rs = game:GetService("RunService").RenderStepped
				local evwait = game.Changed.Wait
				while running do
					local dt = evwait(rs)
					for _, dot in ipairs(dots) do
						dot.step(dt)
					end
				end
				for _, dot in ipairs(dots) do
					dot.destroy()
				end
				print("dotsThread ended, dots destroyed")
			end)

			return self
		end
	end

	do-- show stats
		local getC = game.GetChildren
		local destroy = game.Destroy
		local format = string.format
		local ffc = game.FindFirstChild
		local myMath = requireGm("Math")
		local pwd = game.GetFullName

		local barTemp = sg.Pages.LearnMore.Main.Stats.Damage_Bar
		barTemp.Parent = nil
		local textTemp = sg.Pages.LearnMore.Main.Stats["Fire Type_Text"]
		textTemp.Parent = nil

		local clamp = myMath.clamp
		local clone = game.Clone
		local newU2 = UDim2.new
		local getPercentage = myMath.getPercentage
		-- local logistic = myMath.getLogisticFunction(0.5, 2, 0, 0.5)
		local logisticRecoilX = myMath.getLogisticFunction2(0.75, 0.25, 25, 13, 0.25)
		local logisticRecoilY = myMath.getLogisticFunction2(0.85, 0.15, 2, 1, 0.15)
		local logisticSpread = myMath.getLogisticFunction(0.5, 9, 9, 0.5)
		local getAverageRecoils = requireGm("ShootingSimulator").getAverageRecoils

		local at = 0.2

		-- args.getNum, getP, title, numFormatter
		local function gengenBar1(args)
			args.numFormatter = args.numFormatter or function(num)
				return format("%.1f", num)
			end
			local function gen(stats)
				local fr  = clone(barTemp)
				local num = args.getNum(stats)
				local p   = args.getP(num)
				fr.Top.Title.text.Text  = args.title
				fr.Top.Number.text.Text = args.numFormatter(num)
				fr.Bar.Base.Position    = newU2(p, 0, 0, 0)
				fr.Bar.Cover.Size       = newU2(p, 0, 1, 0)
				fr.Name = args.title
				return fr
			end
			-- accepts the new frame f and old frame oldF
			-- f contains the new value
			-- oldF contains the old value
			-- this function resets f to the old values and tweens f to the new value
			local function tween_(f, oldF) 	
				local newPos = f.Bar.Base.Position
				local oldPos = oldF.Bar.Base.Position
				f.Bar.Base.Position = oldPos
				tween(f.Bar.Base, at, {Position = newPos})
				local newSize = f.Bar.Cover.Size
				local oldSize = oldF.Bar.Cover.Size
				f.Bar.Cover.Size = oldSize
				tween(f.Bar.Cover, at, {Size = newSize})
			end 
			return {tween = tween_, gen = gen}
		end
		local function gengenText1(args)
			local function gen(stats)
				local fr = clone(textTemp)
				fr.Top.Title.text.Text = args.title
				fr.Bottom.Desc.text.Text = args.getText(stats)
				return fr
			end
			return {tween = false, gen = gen}
		end

		local statsGenerators = {
			damage = gengenBar1({
				getNum       = function(stats) return stats.dmg0 end,
				getP         = function(num) return num / 100 end,
				title        = "Damage",
				numFormatter = function(num) return format("%.1f", num) end
			});
			rpm = gengenBar1({
				getNum       = function(stats) return stats.rps * 60 end,
				getP         = function(num) return num / 1200 end,
				title        = "RPM",
				numFormatter = function(num) return format("%d", num) end
			});
			aimTime = gengenBar1({
				getNum       = function(stats) return stats.aimTime end,
				getP         = function(num) return num / 0.7 end,
				title        = "Aim Time",
				numFormatter = function(num) return format("%.2f", num) end
			}),
			range = gengenBar1({
				getNum       = function(stats) return stats.dist0 end,
				getP         = function(num) return num / 2000 end,
				title        = "Effective Range",
				numFormatter = function(num) return format("%d", num) end
			}),		
			weight = gengenBar1({
				getNum       = function(stats) return stats.weight end,
				getP         = function(num) return getPercentage(num, 0.8, 1.2) end,
				title        = "Weight",
				numFormatter = function(num) return format("%.3f", num) end
			}),
			fireType = gengenText1({
				title = "Fire types",
				getText = function(stats)
					local displayNames = {
						auto = "Auto",
						burst = "Burst",
						single = "Semi",
					}
					local ret = ""
					local s = stats.supportedFireModes
					for _, v in ipairs({"auto", "burst", "single"}) do
						if s[v] then
							if ret == "" then
								ret = displayNames[v]
							else
								ret = ret.." / "..displayNames[v]
							end
						end
					end
					return ret
				end,
			});
			stability = gengenBar1({
				getNum       = function(stats)
					local x, y = getAverageRecoils(stats)
					return (2 - (logisticRecoilX(x) * 1.5 + logisticRecoilY(y) * 0.5)) * 10
				end,
				getP         = function(num) return getPercentage(num, 0, 20) end,
				title        = "Stability",
				numFormatter = function(num) return format("%.0f", num) end
			}),
			spread = gengenBar1({
				getNum       = function(stats) return stats.spread end,
				getP         = function(num) return logisticSpread(num) end,
				title        = "Spread",
				numFormatter = function(num) return format("%.1f", num) end
			});
			verticalRecoil = gengenBar1({
				getNum       = function(stats) 
					local x, _ = getAverageRecoils(stats)
					return x
				end,
				getP         = function(num) return logisticRecoilX(num) end,
				title        = "Vertical Recoil",
				numFormatter = function(num) return format("%.0f", num) end
			});
			horizontalRecoil = gengenBar1({
				getNum       = function(stats) 
					local _, y = getAverageRecoils(stats)
					return y
				end,
				getP         = function(num) return logisticRecoilY(num) end,
				title        = "Horizontal Recoil",
				numFormatter = function(num) return format("%.1f", num) end
			});
			kickback = gengenBar1({
				getNum       = function(stats) return stats.recoilZ end,
				getP         = function(num) return getPercentage(num, 0.15, 0.35) end,
				title        = "Kickback",
				numFormatter = function(num) return format("%.1f", num) end
			});
			magnification = gengenBar1({
				getNum       = function(stats) return stats.aimMult end,
				getP         = function(num) return getPercentage(num, 0, 5) end,
				title        = "Magnification",
				numFormatter = function(num) return format("%.1f", num) end
			});	
			bulletSpeed = gengenBar1({
				getNum       = function(stats) return stats.bulletSpeed end,
				getP         = function(num) return getPercentage(num, 200, 2000) end,
				title        = "Bullet Speed",
				numFormatter = function(num) return format("%.0f", num) end
			});	
			penetration = gengenBar1({
				getNum       = function(stats) return stats.bulletPen end,
				getP         = function(num) return getPercentage(num, 0, 20) end,
				title        = "Penetration",
				numFormatter = function(num) return format("%.0f", num) end
			});
			magSize = gengenBar1({
				getNum       = function(stats) return stats.magSize end,
				getP         = function(num) return getPercentage(num, 0, 50) end,
				title        = "Magazine Size",
				numFormatter = function(num) return format("%d", num) end
			});
		}

		local presets = {
			weapon = {
				"damage", 
				"aimTime",
				"rpm", 
				"bulletSpeed",
				"range",
				"weight",
				"stability", -- recoilx, recoily, spread
				"fireType",
			},
			Underbarrel = {
				"spread",
				"verticalRecoil",
				"horizontalRecoil",
				"kickback",
				"weight",
			},
			Muzzle = {
				"damage",
				"range",
				"spread",
				"verticalRecoil",
				"horizontalRecoil",
				"penetration",
				"bulletSpeed",
				"weight",
			},
			Stock = {
				"spread",
				"verticalRecoil",
				"horizontalRecoil",
				"weight",
			},
			Optic = {
				"aimTime",
				"magnification",
				"weight",
			},
			Mount = {
				"weight",
			},
			Barrel = {
				"damage", 
				"aimTime",
				"bulletSpeed",
				"range",
				"weight",
			},
			Magazine = {
				"magSize",
				"weight",
			},
			Skin = {

			},
		}

		function showcase3D.showStats(fr, stats, presetName)
			local self = {}

			for _, v in ipairs(getC(fr)) do
				if v.Name ~= "UIGridLayout" then
					v.Visible = false
				end
			end				

			local preset = presets[presetName]
			if not preset then
				warn("preset name", presetName, "not found. loading preset as weapon.")
				preset = presets.weapon
			end

			local i = 0
			for _, v in pairs(preset) do
				i = i + 1
				local s = statsGenerators[v]
				local f = s.gen(stats) 	-- gets the new frame
				if s.tween then 				-- if there's a tween function available
					local oldF = ffc(fr, f.Name)	-- try to get the old frame
					if oldF then
						s.tween(f, oldF)						-- tween the new frame
						destroy(oldF)
					end					
				end				
				f.LayoutOrder = i
				f.Parent = fr
			end 

			function self.destroy()
				for _, v in ipairs(getC(fr)) do
					if v.Name ~= "UIGridLayout" then
						v.Visible = false 		-- dont destroy because we need them for tweening
					end
				end				
			end

			return self
		end
	end
end

-- keep the party info up to date from the server
do
	local function process(_party)
		_party.isLeader = _party.leader == lp
		return _party
	end
	party = process(fetchClient.fetch("party", {wait = true}))
	root.onPartyUpdated()
	lobbyClient.listen("party", function(_party)
		party = process(_party)
		root.onPartyUpdated()
	end)
end

do-- sync with datastore
	data = fetchClient.fetch("data", {wait = true})
	local function onDataUpdated()
		print("new data fetched")
		for _, v in ipairs(dg) do
			v()
		end
		print("new data processed")
	end
	onDataUpdated()
	lobbyClient.listen("data", function(_data)
		data = _data
		onDataUpdated()
	end)
end


-- lobbyClient.fireServer("crate.buy", "Solid Colors", 100)
-- for i = 1, 100 do
-- 	print(lobbyClient.invokeServer("crate.use", "Solid Colors"))
-- end


