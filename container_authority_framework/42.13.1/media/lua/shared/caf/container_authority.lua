---@meta
local pz_utils = require("pz_utils_shared")
local pz_commons = require("pz_lua_commons_shared")

local middleclass = pz_commons.kikito.middleclass
local EventManager = pz_utils.escape.EventManager
local SafeLogger = pz_utils.escape.SafeLogger
SafeLogger.init("ContainerAuthority")

---@class ContainerAuthority
---@field private _isProcessing boolean Recursion guard
---@field private _rules table<string, table>
---@field public ValidationEvent string
---@field public PreTransferEvent string
---@field public PostTransferEvent string
local ContainerAuthority = middleclass("ContainerAuthority")

function ContainerAuthority:initialize()
    self._isProcessing = false
    self.ValidationEvent = "CAF:Validation"
    self.PreTransferEvent = "CAF:PreTransfer"
    self.PostTransferEvent = "CAF:PostTransfer"
    
    -- Initialize EventManager events
    EventManager.getOrCreateEvent(self.ValidationEvent)
    EventManager.getOrCreateEvent(self.PreTransferEvent)
    EventManager.getOrCreateEvent(self.PostTransferEvent)
    
    SafeLogger.log("[CAF] ContainerAuthority initialized.", 30)
end

---Processes a transfer request through the 3-phase pipeline.
---@param character IsoPlayer The player performing the transfer.
---@param item InventoryItem The item being transferred.
---@param src ItemContainer The source container.
---@param dest ItemContainer The destination container.
---@param originalFunc function The original transfer function to call if valid.
---@param ... any Additional arguments for the original function (e.g., dropSquare).
---@return any The result of the original transfer function or nil if rejected.
function ContainerAuthority:processTransfer(character, item, src, dest, originalFunc, ...)
    if self._isProcessing then
        return originalFunc(self, character, item, src, dest, ...)
    end

    self._isProcessing = true
    
    -- Create Context Object
    local context = {
        character = character,
        item = item,
        src = src,
        dest = dest,
        args = {...},
        metadata = {},
        flags = {
            rejected = false,
            reason = nil,
            adminOverride = false
        }
    }

    -- 1. VALIDATION PHASE (Blocking)
    local validationEvent = EventManager.getEvent(self.ValidationEvent)
    validationEvent:Trigger(context)

    if context.flags.rejected then
        SafeLogger.log(string.format("[CAF] Transfer rejected: %s", context.flags.reason or "Unknown reason"), 40)
        self._isProcessing = false
        return nil
    end

    -- 2. PRE-TRANSFER PHASE (Mutation/Auditing)
    local preEvent = EventManager.getEvent(self.PreTransferEvent)
    preEvent:Trigger(context)

    -- 3. EXECUTION
    local result = originalFunc(self, character, item, src, dest, unpack(context.args))

    -- 4. POST-TRANSFER PHASE (Reaction/Side-effects)
    -- We pass the result just in case
    context.result = result
    local postEvent = EventManager.getEvent(self.PostTransferEvent)
    postEvent:Trigger(context)

    self._isProcessing = false
    return result
end

---Registers a rule for a specific phase.
---@param phase string The phase ("validation", "pre", "post").
---@param id string A unique identifier for the rule.
---@param callback function The rule logic.
---@param priority number The priority (lower = earlier).
function ContainerAuthority:registerRule(phase, id, callback, priority)
    local eventName
    if phase == "validation" then eventName = self.ValidationEvent
    elseif phase == "pre" then eventName = self.PreTransferEvent
    elseif phase == "post" then eventName = self.PostTransferEvent
    else error("Invalid CAF phase: " .. tostring(phase)) end

    local event = EventManager.getEvent(eventName)
    event:Add(callback)
    
    SafeLogger.log(string.format("[CAF] Registered %s rule: %s (Priority: %d)", phase, id, priority or 50), 30)
end

---Engine Singleton
CAF = ContainerAuthority:new()

return CAF
