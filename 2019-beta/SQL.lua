local sql = {}

-- this must be put on the server side
local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

-- const functions
local h          = game:GetService("HttpService")
local toJSON     = h.JSONEncode
local fromJSON   = h.JSONDecode
local post       = h.PostAsync
local gsub       = string.gsub
local format     = string.format

-- data server settings
local pwd = 'trolololol'
local sqlAddress = "REDACTED"

-- const table names
local debugSettings = requireGm("DebugSettings")()
local playerTable = debugSettings.tableNames.player
local serverTable = debugSettings.tableNames.server

-- the query function
function sql.query(q, ...)
	q = format(q, ...)
	q = gsub(q, "PLAYERTABLE", playerTable)
	q = gsub(q, "SERVERTABLE", serverTable)
	-- print("send query", q)
	local ret = fromJSON(h, post(h, sqlAddress, toJSON(h, {pwd = pwd, query = q})))
	if ret.err then
		warn("db query error:", ret.err)
	end
	return ret
end

return sql
