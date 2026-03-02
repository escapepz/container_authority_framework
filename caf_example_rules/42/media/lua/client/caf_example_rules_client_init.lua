local pz_utils = require("pz_utils_shared")
local KUtilities = pz_utils.konijima.Utilities

---@param playerIndex integer
---@param context ISContextMenu
---@param worldObject IsoObject
local function DoContextMenu(playerIndex, context, worldObject)
    local playerObj = getSpecificPlayer(playerIndex)
    local isAdmin = KUtilities.IsPlayerAdmin(playerObj)

    local username = playerObj:getUsername()
    local modData = worldObject:getModData()
    local shopOwner = modData.shopOwner or nil

    -- Submenu (Registration/NPC/Management)
    local jOption = context:addOption("[SP] CAF Example Rules", worldObject, nil)
    local jMenu = ISContextMenu:getNew(context)
    context:addSubMenu(jOption, jMenu)

    -- jMenu:addOption(entityFullTypeDebug, worldObject, function() end)

    jMenu:addOption("set shopOwner [" .. tostring(shopOwner) .. "]", worldObject, function()
        modData.shopOwner = username
    end)

    jMenu:addOption("unset shopOwner", worldObject, function()
        modData.shopOwner = nil
    end)

    jMenu:addOption("set shopOwner random", worldObject, function()
        modData.shopOwner = tostring(ZombRandBetween(1, 500))
    end)

    -- Submenu (Admin Only)
    if isAdmin then
    end
end

local function onFillWorldObjectContextMenu(playerIndex, context, worldObjects)
    if worldObjects and #worldObjects > 0 then
        ---@type IsoObject
        local wObj = worldObjects and worldObjects[1] or nil
        ---@diagnostic disable-next-line: unnecessary-if
        if wObj then --and wObj:getContainer() then
            DoContextMenu(playerIndex, context, wObj)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
