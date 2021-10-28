local sql = {}

-- this must be put on the server side

local h          = game:GetService("HttpService")
local toJSON     = h.JSONEncode
local fromJSON   = h.JSONDecode
local post       = h.PostAsync
local gsub       = string.gsub
local format     = string.format

local rep  = game.ReplicatedStorage
local wfc  = game.WaitForChild
local gm   = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local sqlAddress = "REDACTED"
local debugSettings = requireGm("DebugSettings")()
local playerTable = debugSettings.tableNames.player
local serverTable = debugSettings.tableNames.server

function sql.query(q, ...)
	q = format(q, ...)
	q = gsub(q, "PLAYERTABLE", playerTable)
	q = gsub(q, "SERVERTABLE", serverTable)
	-- print("send query", q)
	return fromJSON(h, post(h, sqlAddress, toJSON(h, {query = q})))
end

return sql
