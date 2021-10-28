local countdown = {}
function countdown.new(args)
	local self = {timeup = false}
	local announceFunc = args.announceFunc

	-- consts
	local internalTick = args.internalTick or 0.5
	local announceTick = args.announceTick or 1
	local floor = math.floor
	-- vars
	local time
	local id = -1
	function self.set(_time)
		time   = _time
		id     = id + 1
		self.timeup = _time == 0 and true or false
		if announceFunc then
			announceFunc(time)
		end
	end
	function self.run()
		local _id = id
		local st = tick()
		local lastAnnounceTick = -1
		spawn(function()
			while _id == id do
				-- time elapsed
				local dt = wait(internalTick)
				time = time - dt
				if time < 0 then
					time   = 0
					self.timeup = true
					break
				end
				
				-- annonuce
				if announceFunc then
					local now = tick()
					if now - lastAnnounceTick > announceTick then
						lastAnnounceTick = now
						announceFunc(time)
					end	
				end
			end
		end)
	end
	function self.getTime()
		return time
	end
	return self
end		
return countdown