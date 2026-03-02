local is_inventory_transfer_action_patch =
    require("container_authority_framework/patches/is_inventory_transfer_action_patch")

local ZUL = require("zul")
local pz_utils = require("pz_utils_shared")

local KUtilities = pz_utils.konijima.Utilities
local logger = ZUL.new("container_authority_framework")

return function()
    logger:debug("Initializing Shared Patches Hook...")

    if KUtilities.IsClientOrSinglePlayer() then
        Events.OnGameStart.Add(function()
            logger:info("Applying shared client-side patches...")
            is_inventory_transfer_action_patch.clientSidePatch()
        end)
    end
end
