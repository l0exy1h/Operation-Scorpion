local md = {}

function md.play(a, t)
	spawn(function()
		a.PlaybackSpeed = 1
		local startTime = tick()
		for i = 1, 5, 0.2 do
			a.PlaybackSpeed = i
			wait(0.1)
			if tick() - startTime > t then break end
		end
	end)
	spawn(function()
		a:Play()
		local startTime = tick()
		repeat
			wait(0.1)
		until tick() - startTime > t
		a:Stop() 
	end)  
end

return md