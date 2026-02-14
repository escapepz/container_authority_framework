local CAF = require("caf/container_authority")
local pz_utils = require("pz_utils_shared")
local SafeLogger = pz_utils.escape.SafeLogger
SafeLogger.init("ContainerAuthority")

local tostring = tostring

---Post-transfer rule to log successful transfers for auditing.
local function logTransfer(context)
	if SafeLogger.shouldLog and not SafeLogger.shouldLog(20) then
		return
	end

	local char = context.character
	local item = context.item
	local srcName = context.src:getType() or "unknown"
	local destName = context.dest:getType() or "unknown"

	SafeLogger.log(
		"[CAF:Audit] Player "
			.. tostring(char:getUsername())
			.. " moved "
			.. tostring(item:getFullType())
			.. " from "
			.. tostring(srcName)
			.. " to "
			.. tostring(destName),
		20
	)
end

return function()
	-- Register the rule
	CAF:registerRule("post", "audit_log", logTransfer, 500)

	SafeLogger.log("[CAF] Audit Log Rule loaded.", 30)
end
