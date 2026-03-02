-- mock_pz.lua - Minimal stubs for PZ APIs logic
local mock_pz = {}

-- 1. Global Tables Stubs
_G.ZomboidGlobals = {}
local function eventStub_Add(event_name)
    return {
        Add = function(func)
            if not _G._eventCallbacks then
                ---@diagnostic disable-next-line: global-in-non-module
                _G._eventCallbacks = {}
            end
            if not _G._eventCallbacks[event_name] then
                _G._eventCallbacks[event_name] = {}
            end
            table.insert(_G._eventCallbacks[event_name], func)
        end,
    }
end

_G.Events = {
    OnInitGlobalModData = eventStub_Add("OnInitGlobalModData"),
    OnGameBoot = eventStub_Add("OnGameBoot"),
    OnGameStart = eventStub_Add("OnGameStart"),
}
_G.ISTransferAction = {
    transferItem = function() end,
}
_G.isServer = function()
    return false
end
_G.isMultiplayer = function()
    return false
end
_G.isClient = function()
    return false
end

function mock_pz.setMultiplayer(active)
    _G.isMultiplayer = function()
        return active
    end
end

function mock_pz.setServer(active)
    _G.isServer = function()
        return active
    end
end

function mock_pz.setClient(active)
    _G.isClient = function()
        return active
    end
end
_G.writeLog = function(category, message)
    -- Capture logs for testing if needed
    if not _G._testLogs then
        ---@diagnostic disable-next-line: global-in-non-module
        _G._testLogs = {}
    end
    table.insert(_G._testLogs, { category = category, message = message })
end

-- 2. PZ Class Stubs
-- InventoryItem
local InventoryItem = {}
InventoryItem.__index = InventoryItem
function InventoryItem.new(fullType)
    return setmetatable({ _fullType = fullType }, InventoryItem)
end
function InventoryItem:getFullType()
    return self._fullType
end
mock_pz.InventoryItem = InventoryItem

-- ItemContainer
local ItemContainer = {}
ItemContainer.__index = ItemContainer
function ItemContainer.new(type, parent)
    return setmetatable({ _type = type, _parent = parent }, ItemContainer)
end
function ItemContainer:getType()
    return self._type
end
function ItemContainer:getParent()
    return self._parent
end
mock_pz.ItemContainer = ItemContainer

-- IsoPlayer (Character)
local IsoPlayer = {}
IsoPlayer.__index = IsoPlayer
function IsoPlayer.new(username)
    return setmetatable({ _username = username, _isAdmin = false }, IsoPlayer)
end
function IsoPlayer:getUsername()
    return self._username
end
function IsoPlayer:getAccessLevel()
    return self._isAdmin and "Admin" or "None"
end
mock_pz.IsoPlayer = IsoPlayer

-- IsoObject (Parent object for containers)
local IsoObject = {}
IsoObject.__index = IsoObject
function IsoObject.new()
    return setmetatable({ _modData = {} }, IsoObject)
end
function IsoObject:getModData()
    return self._modData
end
mock_pz.IsoObject = IsoObject

-- IsoDeadBody
local IsoDeadBody = {}
IsoDeadBody.__index = IsoDeadBody
function IsoDeadBody.new()
    return setmetatable({ _modData = {}, _isDeadBody = true }, IsoDeadBody)
end
function IsoDeadBody:getModData()
    return self._modData
end
mock_pz.IsoDeadBody = IsoDeadBody

-- 3. Globals Injection
function mock_pz.setupGlobalEnvironment()
    _G.InventoryItem = InventoryItem
    _G.ItemContainer = ItemContainer
    _G.IsoPlayer = IsoPlayer
    _G.IsoObject = IsoObject
    _G.IsoDeadBody = IsoDeadBody

    ---@diagnostic disable-next-line: global-in-non-module
    _G.instanceof = function(obj, className)
        if not obj then
            return false
        end
        local mt = getmetatable(obj)
        if className == "IsoPlayer" then
            return mt == IsoPlayer
        end
        if className == "IsoDeadBody" then
            return mt == IsoDeadBody or obj._isDeadBody == true
        end
        if className == "IsoObject" then
            return mt == IsoObject or mt == IsoDeadBody or mt == IsoPlayer
        end
        return false
    end

    ---@diagnostic disable-next-line: global-in-non-module
    -- Mock SandboxVars
    _G.SandboxVars = {
        CAFExampleRules = {
            EnableShopOwnership = true,
            EnableAuditLog = true,
        },
    }

    -- Set Default Environment: SP (All false)
    mock_pz.setServer(false)
    mock_pz.setClient(false)
    mock_pz.setMultiplayer(false)

    ---@diagnostic disable-next-line: global-in-non-module
    -- Mock container_authority_framework singleton for rules to register against
    _G.ContainerAuthorityFramework = {}
end

-- Helper to trigger events
function mock_pz.triggerEvent(event_name)
    if _G._eventCallbacks and _G._eventCallbacks[event_name] then
        for _, func in ipairs(_G._eventCallbacks[event_name]) do
            func()
        end
    end
end

function mock_pz.triggerOnInit()
    mock_pz.triggerEvent("OnInitGlobalModData")
end

return mock_pz
