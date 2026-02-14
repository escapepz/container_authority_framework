---@meta
local pz_utils = require("pz_utils_shared")
local pz_commons = require("pz_lua_commons_shared")

local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local pairs = pairs

local middleclass = pz_commons.kikito.middleclass
-- Localize for speed (Kahlua2 optimization)
local EventManager = pz_utils.escape.EventManager
local SafeLogger = pz_utils.escape.SafeLogger

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

	-- Initialize and Cap EventManager events (Performance Pruning)
	EventManager.setMaxListeners(VALIDATION_EV, 25)
	EventManager.setMaxListeners(PRE_TRANSFER_EV, 50)
	EventManager.setMaxListeners(POST_TRANSFER_EV, 100)

	SafeLogger.log("[CAF] ContainerAuthority initialized.", 30)
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

	EventManager.on(eventName, callback, priority)

	SafeLogger.log(
		"[CAF] Registered "
			.. tostring(phase)
			.. " rule: "
			.. tostring(id)
			.. " (Priority: "
			.. tostring(priority or 0)
			.. ")",
		30
	)
end

---Engine Singleton
_G.CAF = ContainerAuthority:new()

return _G.CAF
