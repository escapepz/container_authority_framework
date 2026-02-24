local CAF = require("container_authority_framework")
local pz_utils = require("pz_utils_shared")
local SafeLogger = pz_utils.escape.SafeLogger
local KUtilities = pz_utils.konijima.Utilities
SafeLogger.init("caf_example_rules")

local tostring = tostring

---Validation rule to prevent players from taking items from shop containers they don't own.
local function validateShopOwnership(context)
	local item = context.item
	local src = context.src
	local character = context.character

	-- Admin override
	-- if KUtilities.IsPlayerAdmin(character) then
	-- 	---@diagnostic disable-next-line: unnecessary-if
	-- 	if not SafeLogger.shouldLog or SafeLogger.shouldLog(30) then
	-- 		SafeLogger.log("[CAF] Admin " .. tostring(character:getUsername()) .. " bypassed shop validation.", 10)
	-- 	end
	-- 	return
	-- end

	-- Check if source container belongs to a shop
	local parent = src:getParent()
	if parent and parent:getModData() and parent:getModData().shopOwner then
		local owner = parent:getModData().shopOwner
		if owner ~= character:getUsername() then
			context.flags.rejected = true
			context.flags.reason = "This item belongs to " .. tostring(owner) .. "'s shop."
		end
	end
end

return function()
	if not CAF then
		SafeLogger.log("[CAF] Error: CAF singleton missing during shop_ownership registration!", 50)
		return
	end

	-- Register the rule
	CAF:registerRule("validation", "shop_ownership", validateShopOwnership, 100)

	SafeLogger.log("[CAF] Shop Ownership Rule loaded.", 30)
end
