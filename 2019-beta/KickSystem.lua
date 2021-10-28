local kickSystem = {}

-- @todo wip args: log this message into the sql
-- combine this with the admin system
function kickSystem.kick(plr, reason, args)
	if not plr then
		return
	end
	reason = reason or ""

	plr:Kick(reason)
	warn(plr, "is kicked for", reason)
end

return kickSystem