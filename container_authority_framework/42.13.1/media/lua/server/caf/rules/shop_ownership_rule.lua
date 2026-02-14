local CAF = require("caf/container_authority")
local pz_utils = require("pz_utils_shared")
local SafeLogger = pz_utils.escape.SafeLogger
SafeLogger.init("ContainerAuthority")

---Validation rule to prevent players from taking items from shop containers they don't own.
local function validateShopOwnership(context)
    local item = context.item
    local src = context.src
    local character = context.character
    
    -- Admin override
    if character:getAccessLevel() ~= "None" and character:getAccessLevel() ~= "" then
        SafeLogger.log(string.format("[CAF] Admin %s bypassed shop validation.", character:getUsername()), 30)
        return
    end

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

-- Register the rule
CAF:registerRule("validation", "shop_ownership", validateShopOwnership, 100)

SafeLogger.log("[CAF] Shop Ownership Rule loaded.", 30)
