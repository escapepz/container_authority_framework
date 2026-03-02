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

-- | Container Logic     | Lua Check                                                                    |
-- | ------------------- | ---------------------------------------------------------------------------- |
-- | **Player Main Inv** | `container == character:getInventory()`                                      |
-- | **Backpack (Worn)** | `instanceof(container:getParent(), "IsoPlayer")`                             |
-- | **Corpse**          | `container:isCorpse()` OR `instanceof(container:getParent(), "IsoDeadBody")` |
-- | **Floor**           | `container:getType() == "floor"`                                             |
-- | **Vehicle Trunk**   | `instanceof(container:getParent(), "BaseVehicle")`                           |
-- | **Crate / Shelf**   | `instanceof(container:getParent(), "IsoObject")`                             |

local function preTransfer(context)
    local item = context.item ---@type InventoryItem
    local src = context.src ---@type ItemContainer
    local dest = context.dest ---@type ItemContainer
    local character = context.character ---@type IsoPlayer

    -- Parent Objects
    local srcParent = src:getParent()
    local destParent = dest:getParent()

    -- Identification Logic
    local srcIsPlayer = instanceof(srcParent, "IsoPlayer")
    local destIsPlayer = instanceof(destParent, "IsoPlayer")

    local srcIsCorpse = src:isCorpse() or instanceof(srcParent, "IsoDeadBody")
    local destIsCorpse = dest:isCorpse() or instanceof(destParent, "IsoDeadBody")

    local srcIsFloor = src:getType() == "floor"
    local destIsFloor = dest:getType() == "floor"

    -- Logging
    safe_logger:log("--- Transfer Source ---", 30)
    safe_logger:log("Is Player: " .. tostring(srcIsPlayer), 30)
    safe_logger:log("Is Corpse: " .. tostring(srcIsCorpse), 30)
    safe_logger:log("Is Floor: " .. tostring(srcIsFloor), 30)
    safe_logger:log("Type: " .. tostring(src:getType()), 30)

    safe_logger:log("--- Transfer Destination ---", 30)
    safe_logger:log("Is Player: " .. tostring(destIsPlayer), 30)
    safe_logger:log("Is Corpse: " .. tostring(destIsCorpse), 30)
    safe_logger:log("Is Floor: " .. tostring(destIsFloor), 30)
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
        CAF:registerRule("pre", "shop_ownership", preTransfer, 100)

        safe_logger:log("[CAF] Shop Ownership Rule loaded.", 30)
    end
end
