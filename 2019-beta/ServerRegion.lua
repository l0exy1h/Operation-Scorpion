local sr = {}

-- nil by default
sr.region = nil 	-- should be used with 'or smt'

-- credits to wravager
local function getRegionFromLon(lon)
	if (lon > -180 and lon <= -105) then
		return 'WUS'
	elseif (lon > -105 and lon <= -90) then
		return 'CUS'
	elseif (lon > -90 and lon <= 0)then
		return 'EUS'
	elseif (lon <= 75 and lon > 0)then
		return 'EU'
	elseif (lon <= 180 and lon > 75)then
		return 'AS'
	end
end

-- get the region by api
local regionAPI  = 'http://ip-api.com/json/'
local h          = game:GetService("HttpService")
local fromJSON   = h.JSONDecode
local get        = h.GetAsync
local suc, msg = pcall(function()
	local ret = fromJSON(h, get(h, regionAPI))
	print("region api returns:", ret)

	local region = getRegionFromLon(ret.lon)
	print(string.format("lon = %d, region is %s", ret.lon, region))

	sr.region = region
end)

-- check
if not suc then
	warn("getting server region failed, msg = ", msg)
end

return sr