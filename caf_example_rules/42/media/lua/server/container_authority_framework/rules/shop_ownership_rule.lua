local CAF = require("container_authority_framework")
local pz_utils = require("pz_utils_shared")
local SafeLogger = pz_utils.escape.SafeLogger
local KUtilities = pz_utils.konijima.Utilities

local safe_logger = SafeLogger.new("caf_example_rules")

local tostring = tostring

---Validation rule to prevent players from taking items from shop containers they don't own.
local function validateShopOwnership(context)
    local item = context.item ---@type InventoryItem
    local src = context.src ---@type ItemContainer
    local dest = context.dest ---@type ItemContainer
    local character = context.character ---@type IsoPlayer

    -- Admin override
    -- if KUtilities.IsPlayerAdmin(character) then
    -- 	---@diagnostic disable-next-line: unnecessary-if
    -- 	if not SafeLogger.shouldLog or SafeLogger.shouldLog(30) then
    -- 		safe_logger:log("[CAF] Admin " .. tostring(character:getUsername()) .. " bypassed shop validation.", 10)
    -- 	end
    -- 	return
    -- end

    safe_logger:log(
        "should run here when ever container transfer src " .. tostring(src:getType()),
        30
    )

    safe_logger:log(
        "should run here when ever container transfer dest " .. tostring(dest:getType()),
        30
    )

    -- Check if source container belongs to a shop
    -- local parent = src:getParent()
    -- if parent and parent:getModData() and parent:getModData().shopOwner then
    -- local owner = parent:getModData().shopOwner
    --     if owner ~= character:getUsername() then
    context.flags.rejected = true
    context.flags.reason = "This item belongs to a shop."
    -- end
    -- end
end

return function()
    if not CAF then
        safe_logger:log(
            "[CAF] Error: CAF singleton missing during shop_ownership registration!",
            50
        )
        return
    end

    if KUtilities.IsServerOrSinglePlayer() then
        -- Register the rule
        CAF:registerRule("validation", "shop_ownership", validateShopOwnership, 100)

        safe_logger:log("[CAF] Shop Ownership Rule loaded.", 30)
    end
end
