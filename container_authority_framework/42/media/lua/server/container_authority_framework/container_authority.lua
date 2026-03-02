---@meta
local pz_utils = require("pz_utils_shared")
local pz_commons = require("pz_lua_commons_shared")
local ZUL = require("zul")

local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local table_insert = table.insert

local middleclass = pz_commons.kikito.middleclass
local EventManager = pz_utils.escape.EventManager
local SandboxVarsModule = pz_utils.escape.SandboxVarsModule

local logger = ZUL.new("container_authority_framework")

-- A single reusable table to prevent GC pressure
local reusableContext = {
    flags = { rejected = false, reason = nil, adminOverride = false },
    metadata = {},
}

-- Localize strings for hot-path performance
local VALIDATION_EV = "CAF:Validation"
local PRE_TRANSFER_EV = "CAF:PreTransfer"
local POST_TRANSFER_EV = "CAF:PostTransfer"

---@class ContainerAuthorityFlags
---@field rejected boolean Whether the action is rejected.
---@field reason string The reason for rejection.
---@field adminOverride boolean Whether the action is overridden by an admin.

---@class ContainerAuthorityMetadata
---@field table metadata for the context.

---@class ContainerAuthorityContext
---@field actionName string The name of the action (e.g. "Transfer", "Dismantle").
---@field action table The timed action instance.
---@field item InventoryItem|nil The item being manipulated.
---@field character IsoPlayer The player performing the action.
---@field src ItemContainer The source container.
---@field dest ItemContainer The destination container.
---@field dropSquare IsoGridSquare|nil Optional square to drop the item on.
---@field flags ContainerAuthorityFlags The flags for the context.
---@field metadata ContainerAuthorityMetadata The metadata for the context.
---@field result any The result of the original transfer function.

---@class ContainerAuthority
---@field private _isProcessing boolean Recursion guard
---@field private _rules table<string, table>
---@field public ValidationEvent string
---@field public PreTransferEvent string
---@field public PostTransferEvent string
local ContainerAuthority = middleclass("ContainerAuthority")

function ContainerAuthority:initialize()
    self._isProcessing = false
    self.ValidationEvent = VALIDATION_EV
    self.PreTransferEvent = PRE_TRANSFER_EV
    self.PostTransferEvent = POST_TRANSFER_EV
    self.isReady = false
    self.pendingRules = {} -- Queue for early registrations
end

---Creates a transfer context for an action.
---@type ContainerAuthorityContext
---@return ContainerAuthorityContext The context object.
function ContainerAuthority:createContext(
    actionName,
    action,
    item,
    character,
    src,
    dest,
    dropSquare
)
    local ctx = reusableContext
    ctx.actionName = actionName
    ctx.action = action
    ctx.item = item
    ctx.character = character
    ctx.src = src
    ctx.dest = dest
    ctx.dropSquare = dropSquare

    -- Reset flags
    local flags = ctx.flags
    flags.rejected = false
    flags.reason = nil
    flags.adminOverride = false

    -- Reset metadata (efficient clearing)
    for k in pairs(ctx.metadata) do
        ctx.metadata[k] = nil
    end

    return ctx
end

---Processes a specific phase of a transfer request.
---@param phase string The phase ("validate", "pre", "post").
---@param ctx table The context object created via createContext.
function ContainerAuthority:processAction(phase, ctx)
    local eventName
    if phase == "validate" then
        eventName = VALIDATION_EV
    elseif phase == "pre" then
        eventName = PRE_TRANSFER_EV
    elseif phase == "post" then
        eventName = POST_TRANSFER_EV
    else
        error("Invalid CAF phase: " .. tostring(phase))
    end

    EventManager.trigger(eventName, ctx)

    if phase == "validate" and ctx.flags.rejected then
        logger:warn("Action rejected", {
            action = ctx.actionName,
            reason = ctx.flags.reason or "Unknown reason",
        })
    end
end

---Loads configuration from SandboxVars and sets up EventManager limits.
---Should be called during OnInitGlobalModData.
function ContainerAuthority:loadConfig()
    -- 1. Initialize SandboxVars Config using factory pattern
    local cafSandbox

    if SandboxVarsModule then
        cafSandbox = SandboxVarsModule.Create("ContainerAuthorityFramework", {
            ValidationEventListenersMax = 25,
            PreTransferEventListenersMax = 50,
            PostTransferEventListenersMax = 100,
        })
    end

    -- 2. Retrieve values from sandbox or use defaults
    local validationMax = 25
    local preTransferMax = 50
    local postTransferMax = 100

    if cafSandbox then
        validationMax = cafSandbox.Get("ValidationEventListenersMax", 25)
        preTransferMax = cafSandbox.Get("PreTransferEventListenersMax", 50)
        postTransferMax = cafSandbox.Get("PostTransferEventListenersMax", 100)
    end

    -- 3. Apply Limits from Sandbox
    EventManager.setMaxListeners(VALIDATION_EV, validationMax)
    EventManager.setMaxListeners(PRE_TRANSFER_EV, preTransferMax)
    EventManager.setMaxListeners(POST_TRANSFER_EV, postTransferMax)

    self.isReady = true
    self:_processPendingRules()
    logger:info("ContainerAuthority initialized and ready.")
end

---Internal: Registers all pending rules from the queue.
function ContainerAuthority:_processPendingRules()
    for _, rule in pairs(self.pendingRules) do
        self:_registerEvent(rule.eventName, rule.id, rule.callback, rule.priority)
    end
    -- Clear queue to free memory
    self.pendingRules = {}
end

---Internal helper to actually register with EventManager
function ContainerAuthority:_registerEvent(eventName, id, callback, priority)
    EventManager.on(eventName, callback, priority)
    logger:info("Registered rule", { id = tostring(id), priority = tostring(priority or 0) })
end

---Processes a transfer request through the 3-phase pipeline.
---@param character IsoPlayer The player performing the transfer.
---@param item InventoryItem The item being transferred.
---@param src ItemContainer The source container.
---@param dest ItemContainer The destination container.
---@param originalFunc function The original transfer function to call if valid.
---@param dropSquare IsoGridSquare|nil Optional square to drop the item on.
---@return any The result of the original transfer function or nil if rejected.
function ContainerAuthority:processTransfer(character, item, src, dest, originalFunc, dropSquare)
    if self._isProcessing then
        return originalFunc(self, character, item, src, dest, dropSquare)
    end

    self._isProcessing = true

    -- Backwards compatibility wrapper using the new split logic
    local success, result = pcall(function()
        local ctx = self:createContext("Transfer", nil, item, character, src, dest, dropSquare)

        -- 1. VALIDATION PHASE
        self:processAction("validate", ctx)
        if ctx.flags.rejected then
            return nil
        end

        -- 2. PRE-TRANSFER PHASE
        self:processAction("pre", ctx)

        -- 3. EXECUTION
        local res = originalFunc(self, character, item, src, dest, dropSquare)

        -- 4. POST-TRANSFER PHASE
        ctx.result = res
        self:processAction("post", ctx)

        return res
    end)

    self._isProcessing = false

    if not success then
        logger:error("Critical Error in processTransfer", { error = tostring(result) })
        return nil
    end

    return result
end

---Registers a rule for a specific phase.
---@param phase string The phase ("validation", "pre", "post").
---@param id string A unique identifier for the rule.
---@param callback function The rule logic.
---@param priority number The priority (lower = earlier).
function ContainerAuthority:registerRule(phase, id, callback, priority)
    local eventName
    if phase == "validation" then
        eventName = VALIDATION_EV
    elseif phase == "pre" then
        eventName = PRE_TRANSFER_EV
    elseif phase == "post" then
        eventName = POST_TRANSFER_EV
    else
        error("Invalid CAF phase: " .. tostring(phase))
    end

    if self.isReady then
        self:_registerEvent(eventName, id, callback, priority)
    else
        table_insert(self.pendingRules, {
            eventName = eventName,
            id = id,
            callback = callback,
            priority = priority,
        })
        logger:info("Queued rule for registration", { id = tostring(id) })
    end
end

---Engine Singleton Initialization
local function init()
    if not _G.ContainerAuthorityFramework then
        _G.ContainerAuthorityFramework = ContainerAuthority()

        Events.OnInitGlobalModData.Add(function()
            if _G.ContainerAuthorityFramework then
                -- This is where the queue is processed and isReady becomes true
                _G.ContainerAuthorityFramework:loadConfig()
            end
        end)
    end

    return _G.ContainerAuthorityFramework
end

return init
