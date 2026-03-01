local is_transfer_action_patch =
    require("container_authority_framework/patches/is_transfer_action_patch")

local ZUL = require("zul")
local pz_utils = require("pz_utils_shared")

local KUtilities = pz_utils.konijima.Utilities
local logger = ZUL.new("container_authority_framework")

return function()
    if KUtilities.IsServerOrSinglePlayer() then
        logger:info("Initializing Shared Patches Hook...")

        Events.OnGameBoot.Add(function()
            logger:info("Applying shared server-side patches (Server Environment)...")
            is_transfer_action_patch.serverSidePatch()
        end)

        if KUtilities.IsSinglePlayer() then
            Events.OnGameStart.Add(function()
                logger:info("Applying shared server-side patches (SP/Local)...")
                is_transfer_action_patch.serverSidePatch()
            end)
        end
    end
end
