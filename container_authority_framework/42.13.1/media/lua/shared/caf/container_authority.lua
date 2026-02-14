---@meta
local pz_utils = require("pz_utils_shared")
local pz_commons = require("pz_lua_commons_shared")

local error, unpack, tostring = error, unpack, tostring
local string_format = string.format

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

	-- Initialize and Cap EventManager events (Performance Pruning)
	EventManager.setMaxListeners(self.ValidationEvent, 25)
	EventManager.setMaxListeners(self.PreTransferEvent, 50)
	EventManager.setMaxListeners(self.PostTransferEvent, 100)

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
		args = { ... },
		metadata = {},
		flags = {
			rejected = false,
			reason = nil,
			adminOverride = false,
		},
	}

	-- 1. VALIDATION PHASE (Blocking)
	EventManager.trigger(self.ValidationEvent, context)

	if context.flags.rejected then
		SafeLogger.log(string_format("[CAF] Transfer rejected: %s", context.flags.reason or "Unknown reason"), 40)
		self._isProcessing = false
		return nil
	end

	-- 2. PRE-TRANSFER PHASE (Mutation/Auditing)
	EventManager.trigger(self.PreTransferEvent, context)

	-- 3. EXECUTION
	local result = originalFunc(self, character, item, src, dest, unpack(context.args))

	-- 4. POST-TRANSFER PHASE (Reaction/Side-effects)
	-- We pass the result just in case
	context.result = result
	EventManager.trigger(self.PostTransferEvent, context)

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
	if phase == "validation" then
		eventName = self.ValidationEvent
	elseif phase == "pre" then
		eventName = self.PreTransferEvent
	elseif phase == "post" then
		eventName = self.PostTransferEvent
	else
		error("Invalid CAF phase: " .. tostring(phase))
	end

	EventManager.on(eventName, callback, priority)

	SafeLogger.log(string_format("[CAF] Registered %s rule: %s (Priority: %d)", phase, id, priority or 0), 30)
end

---Engine Singleton
_G.CAF = ContainerAuthority:new()

return _G.CAF
