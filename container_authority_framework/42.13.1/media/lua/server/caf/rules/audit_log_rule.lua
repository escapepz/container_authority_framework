local CAF = require("caf/container_authority")
local pz_utils = require("pz_utils_shared")
local SafeLogger = pz_utils.escape.SafeLogger
SafeLogger.init("ContainerAuthority")

---Post-transfer rule to log successful transfers for auditing.
local function logTransfer(context)
    local char = context.character
    local item = context.item
    local srcName = context.src:getType() or "unknown"
    local destName = context.dest:getType() or "unknown"
    
    SafeLogger.log(string.format("[CAF:Audit] Player %s moved %s from %s to %s", 
        char:getUsername(), 
        item:getFullType(), 
        srcName, 
        destName), 20)
end

-- Register the rule
CAF:registerRule("post", "audit_log", logTransfer, 500)

SafeLogger.log("[CAF] Audit Log Rule loaded.", 30)
