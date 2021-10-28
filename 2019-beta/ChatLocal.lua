-- chat system
--------------------------

local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local plrs = game.Players
local lp   = plrs.LocalPlayer
local function requireGm(name)
	return require(wfc(gm, name))
end

local chatSender = {}

-- queue module
---------------------------
local queue = {}
do
	local myMath = requireGm("Math")
	local mod    = myMath.mod
	function queue.new(sz)
		local self = {
			cnt = 0,
		}

		local q  = {}
		local l  = 1
		local r  = 0

		do--configure the add / pop function
			local function inc(i)
				return mod(i, sz) + 1
			end
			function self.add(item)
				local nextr = inc(r)
				if q[nextr] then
					assert(l == nextr)
					warn("space exhausted, ditching spot at", nextr)
					l = inc(l)
				end
				r        = nextr
				q[nextr] = item
				self.cnt = self.cnt + 1
			end
			function self.pop()
				local ret = nil
				if q[l] then
					self.cnt = self.cnt - 1
					ret      = q[l]
					q[l]     = nil
					l        = inc(l)
				end
				return ret
			end
		end

		function self.callEach(funcName, ...)
			if r == 0 then return end;
			local _r = r < l and r + sz or r
			for i = l, _r do
				i = mod(i - 1, sz) + 1
				q[i][funcName](...)
			end
		end

		return self
	end
end

-- local suc, msg = pcall(function()
-- 	game:GetService('StarterGui'):SetCore("TopbarEnabled", false)
-- end)
-- if suc then
-- 	print("hide top bar")
-- else
-- 	print("failed to hide top bar", msg)
-- end


-- chatgui
----------------------------------
local chatGui = {
	addable = true
}
do
	local newU2  = UDim2.new
	local sg     = wfc(script, "ChatGui")
	sg.Parent    = wfc(lp, "PlayerGui")
	local Chat   = wfc(sg, "Chat")
	local holder = wfc(Chat, "Messages")
	chatGui.textbox = wfc(wfc(Chat, "Type"), "TextBox")
	local temps  = {
		Alpha   = holder.UIGridLayout.Alpha,
		Beta    = holder.UIGridLayout.Beta,
		Neutral = holder.UIGridLayout.Neutral,
	}
	local maxMessageCnt = 10 		-- gridlayout.sizey = 1 / 10 = 0.1

	local cnt = 0
	local o   = 0
	local o_  = 0

	do-- getMessageFrame(). returns a controller, support destroy, and set transparency
		local clone      = game.Clone
		local st         = requireGm("ShadedTexts")
		local setStText  = st.setStText
		local setStProps = st.setStProps
		local spacings   = {	-- spacings before
			tag     = 5,
			sender  = 5,
			message = 5,
		}
		local ySizes = {
			tag     = 0.9,
			sender  = 0.9,
			message = 0.9,
		}	
		function chatGui.getMessageFrame(item)
			local controller = {}

			local fr = clone(temps[item.team])
			if not fr then
				warn("team", item.team, "is not configured")
				return
			end
			fr.Parent = holder

			local sumx = 0

			-- do the tag
			if item.tag then
				local tag = "["..item.tag.."]"
				sumx = spacings.tag
				fr.Tag.Size = newU2(0, 1000, ySizes.tag, 0)
				setStText(fr.Tag, tag)
				local x = fr.Tag.text.TextBounds.X
				fr.Tag.Position = newU2(0, sumx, 0.5, 0)
				fr.Tag.Size     = newU2(0, x, ySizes.tag, 0)
				sumx = sumx + x
			else
				fr.Tag.Visible = false
			end

			-- do the sender
			do
				local sender = item.sender..":"
				sumx = sumx + spacings.sender
				fr.Sender.Size = newU2(0, 1000, ySizes.sender, 0)
				setStText(fr.Sender, sender)
				local x = fr.Sender.text.TextBounds.X
				fr.Sender.Position = newU2(0, sumx, 0.5, 0)
				fr.Sender.Size     = newU2(0, x, ySizes.sender, 0)
				sumx = sumx + x
			end

			do--do the msg
				local message        = item.message
				sumx                 = sumx + spacings.message
				fr.Message.Size      = newU2(0, 1000, ySizes.message, 0)
				fr.Message.text.Text = message
				fr.Message.Position  = newU2(0, sumx, 0.5, 0)
			end

			fr.LayoutOrder = -item.msgId
			fr.Name        = tostring(item.msgId)

			-- configure controller
			do-- configure the set Opacity fucntion
				local texts = {
					fr.Tag.text,
					fr.Tag.shade,
					fr.Sender.text,
					fr.Sender.shade,
					fr.Message.text,
				}
				function controller.setOpacity(opacity)
					for _, text in ipairs(texts) do
						text.TextTransparency = 1 - opacity
					end
					fr.ImageTransparency = 1 - opacity
				end
			end

			-- configure destoy
			do
				local destroy = game.Destroy
				function controller.destroy()
					cnt = cnt - 1 
					destroy(fr)
				end
			end

			controller.fr = fr

			return controller
		end
	end

	local lastShowTick = -1
	function chatGui.show()
		o_ = 1
		lastShowTick = tick()
	end

	local frames = queue.new(10)		-- a dictionary of frame controllers. (msgid -> controller)
	do-- configure add()
	 	local getFrame = chatGui.getMessageFrame
		function chatGui.add(item)
			chatGui.addable = false
			local frame = getFrame(item)
			if frames.cnt == maxMessageCnt then
				frames.pop().destroy()
			end
			frame.setOpacity(o)		-- o is the current opacity of the entire chat board
			-- frame.fr.Parent = holder
			frames.add(frame)
			chatGui.show()
			chatGui.addable = true
		end
	end

	do-- start the opacity thread
		local typeBar = wfc(Chat, "Type")
		local function setTypeBarOpacity(o)
			typeBar.ImageTransparency = 1 - o
			typeBar.TextBox.TextTransparency = 1 - o
		end
		setTypeBarOpacity(0)

		local sp     = 5		-- per second
		local hb     = game:GetService("RunService").Heartbeat
		local evwait = game.Changed.Wait
		local myMath = requireGm("Math")
		local clamp  = myMath.clamp
		local maxInactivityTime = 5
		spawn(function()
			local lastTick = tick()
			while evwait(hb) do

				-- set the opacity
				local now = tick()
				local dt = now - lastTick
				if o ~= o_ then
					if o < o_ then
						o = clamp(o + dt * sp, 0, o_)
					else
						o = clamp(o - dt * sp, o_, 1)
					end

					-- for msg frames
					frames.callEach("setOpacity", o)

					-- for input box
					setTypeBarOpacity(o)
				end

				-- inactivity > 5 secs thn
				if now - lastShowTick > maxInactivityTime and not chatGui.textbox:IsFocused() then
					o_ = 0
				end

				lastTick = now
			end
		end)
	end
end


local buffer = queue.new(20)		-- the message fetched from online network which hasn't been added yet
-- constantly check the queue if there're anything new.
-- if there is then display it
do
	local hb     = game:GetService("RunService").Heartbeat
	local evwait = game.Changed.Wait
	spawn(function()
		while evwait(hb) do
			if chatGui.addable then
				local peak = buffer.pop()
				if peak then
					chatGui.add(peak)
				end
			end
		end
	end)
end

-- listen to online events
-------------------
local events     = wfc(rep, "Events")
local chatClient = requireGm("Network").loadRe(wfc(events, "Chat"), {socketEnabled = true})	
do
	local msgId = 0
	local function onNewMessageFetched(tag, sender, message, team) 	-- these are all strings
		assert(sender, "sender is nil")
		assert(message, "message is nil")
		assert(team, "team is nil")
		msgId = msgId + 1 
		buffer.add({tag = tag, sender = sender, message = message, team = team, msgId = msgId})
	end
	chatClient.listen("chat", onNewMessageFetched)
	wfc(rep, "LocalDebugLocal").OnInvoke = onNewMessageFetched
end

-- anti spam: s2 s1 now
-------------------------
local s1 = nil
local s2 = nil
local function isSpamming()
	local now = tick()
	local b = false
	if s2 then
		b = now - s2 < 1
	end
	s2 = s1
	s1 = now
	return b
end

-- chat sender
--------------------
do
	local textbox = chatGui.textbox
	local channel = "global" --global / team
	local function sendChat(text)
		chatClient.fireServer("chat", channel, text)
	end
	local defPlaceHolder = textbox.PlaceholderText
	textbox.FocusLost:Connect(function(enter)
		if enter then
			local str = textbox.Text
			if #str > 0 and not isSpamming() then
				sendChat(str)
			end
		end
		textbox.Text = ""
		textbox.PlaceholderText = defPlaceHolder
	end)


	local function firstToUpper(str)
	  return str:gsub("^%l", string.upper)
	end
	local function startTyping(channel_)
		channel = channel_
		chatGui.show()
		textbox:CaptureFocus()
		textbox.PlaceholderText = firstToUpper(channel).." chat"
	end
	local kb = requireGm("Keybindings")
	local uis = game:GetService("UserInputService")
	local itKeyboard = Enum.UserInputType.Keyboard
	uis.InputBegan:Connect(function(input, g)
		if g then return end
		local it = input.UserInputType
		if it == itKeyboard then
			local keyDown = input.KeyCode
			if keyDown == kb.toggleChat then
				chatGui.show()
			elseif keyDown == kb.globalChat then
				startTyping("global")
			elseif keyDown == kb.teamChat then
				startTyping("team")
			end
		end
	end)
end