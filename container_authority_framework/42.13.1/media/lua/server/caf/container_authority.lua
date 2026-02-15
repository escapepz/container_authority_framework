---@meta
local pz_utils = require("pz_utils_shared")
local pz_commons = require("pz_lua_commons_shared")

local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local table_insert = table.insert

local middleclass = pz_commons.kikito.middleclass
local EventManager = pz_utils.escape.EventManager
local SafeLogger = pz_utils.escape.SafeLogger
local SandboxVarsModule = pz_utils.escape.SandboxVarsModule

-- Monkey-patch SafeLogger to support conditional logging if not present
if not SafeLogger.shouldLog then
	-- Try to reference ZUL to respect sandbox settings
	local hasZUL, ZUL = pcall(require, "ZUL")

	function SafeLogger.shouldLog(level)
		local numericLevel = tonumber(level) or 30

		if hasZUL and ZUL then
			return ZUL.isLoggingEnabled("ContainerAuthority", numericLevel)
		end

		-- Default threshold matches SafeLogger implementation (INFO = 30)
		return numericLevel >= 30
	end
end

-- A single reusable table to prevent GC pressure
local reusableContext = {
	flags = { rejected = false, reason = nil, adminOverride = false },
	metadata = {},
}

-- Localize strings for hot-path performance
local VALIDATION_EV = "CAF:Validation"
local PRE_TRANSFER_EV = "CAF:PreTransfer"
local POST_TRANSFER_EV = "CAF:PostTransfer"

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
	self.ValidationEvent = VALIDATION_EV
	self.PreTransferEvent = PRE_TRANSFER_EV
	self.PostTransferEvent = POST_TRANSFER_EV
	self.isReady = false
	self.pendingRules = {} -- Queue for early registrations
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
	SafeLogger.log("[CAF] ContainerAuthority initialized and ready.", 30)
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
	SafeLogger.log("[CAF] Registered rule: " .. tostring(id) .. " (Priority: " .. tostring(priority or 0) .. ")", 30)
end

---Processes a transfer request through the 3-phase pipeline.
---@param character IsoPlayer The player performing the transfer.
---@param item InventoryItem The item being transferred.
---@param src ItemContainer The source container.
---@param dest ItemContainer The destination container.
---@param originalFunc function The original transfer function to call if valid.
---@param dropSquare IsoGridSquare|nil Optional square to drop the item on.
---@return any The result of the original transfer function or nil if rejected.
-- Internal protected function to avoid closure allocations in pcall
local function protectedTransferLogic(self, character, item, src, dest, originalFunc, dropSquare)
	-- Update reusable object instead of allocating {}
	local ctx = reusableContext
	ctx.character = character
	ctx.item = item
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

	-- 1. VALIDATION PHASE (Blocking)
	EventManager.trigger(VALIDATION_EV, ctx)

	if ctx.flags.rejected then
		-- Only format string IF we are actually logging (Save string allocations)
		if not SafeLogger.shouldLog or SafeLogger.shouldLog(40) then
			SafeLogger.log("[CAF] Transfer rejected: " .. tostring(ctx.flags.reason or "Unknown reason"), 40)
		end
		return nil
	end

	-- 2. PRE-TRANSFER PHASE (Mutation/Auditing)
	EventManager.trigger(PRE_TRANSFER_EV, ctx)

	-- 3. EXECUTION
	-- Direct call with explicit args is faster than ... or unpack(args)
	local result = originalFunc(self, character, item, src, dest, dropSquare)

	-- 4. POST-TRANSFER PHASE (Reaction/Side-effects)
	ctx.result = result
	EventManager.trigger(POST_TRANSFER_EV, ctx)

	return result
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

	-- Wrap in pcall to ensure recursion guard is ALWAYS released, even on error
	local success, result = pcall(protectedTransferLogic, self, character, item, src, dest, originalFunc, dropSquare)

	self._isProcessing = false

	if not success then
		SafeLogger.log("[CAF] Critical Error in processTransfer: " .. tostring(result), 50)
		-- Optional: Re-throw if you want to hard-crash or notify vanilla error handler
		-- error(result)
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
		SafeLogger.log("[CAF] Queued rule for registration: " .. tostring(id), 30)
	end
end

---Engine Singleton Initialization
local function init()
	if not _G.ContainerAuthorityFramework then
		_G.ContainerAuthorityFramework = ContainerAuthority:new()
		_G.ContainerAuthorityFramework:initialize()

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
