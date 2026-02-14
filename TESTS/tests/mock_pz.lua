-- mock_pz.lua - Minimal stubs for PZ APIs logic
local mock_pz = {}

-- 1. Global Tables Stubs
_G.ZomboidGlobals = {}
_G.Events = {
	OnInitGlobalModData = {
		Add = function(func)
			-- Store initialization functions to run them manually in tests if needed
			if not _G._initCallbacks then
				_G._initCallbacks = {}
			end
			table.insert(_G._initCallbacks, func)
		end,
	},
}

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

-- 3. Globals Injection
function mock_pz.setupGlobalEnvironment()
	_G.InventoryItem = InventoryItem
	_G.ItemContainer = ItemContainer
	_G.IsoPlayer = IsoPlayer
	_G.IsoObject = IsoObject

	-- Mock SandboxVars
	_G.SandboxVars = {
		CAFExampleRules = {
			EnableShopOwnership = true,
			EnableAuditLog = true,
		},
	}

	-- Mock container_authority_framework singleton for rules to register against
	_G.ContainerAuthorityFramework = {
		registerRule = function(self, phase, id, callback, priority)
			if not self._registeredRules then
				self._registeredRules = {}
			end
			table.insert(self._registeredRules, {
				phase = phase,
				id = id,
				callback = callback,
				priority = priority,
			})
			print("[MOCK CAF] Registered rule: " .. id .. " (" .. phase .. ")")
		end,
	}

	-- Helper to trigger init events
	function mock_pz.triggerOnInit()
		if _G._initCallbacks then
			for _, func in ipairs(_G._initCallbacks) do
				func()
			end
		end
	end
end

return mock_pz
