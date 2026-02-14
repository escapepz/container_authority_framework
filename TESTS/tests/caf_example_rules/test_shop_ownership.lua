-- tests/caf_example_rules/test_shop_ownership.lua
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/TESTS/tests/?.lua;" .. package.path
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/container_authority_framework/42.13.1/media/lua/server/?.lua;"
	.. package.path
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/caf_example_rules/42.13.1/media/lua/server/?.lua;"
	.. package.path
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/.tmp/pz_lua_commons/common/media/lua/shared/?.lua;"
	.. package.path

local TestRunner = require("test_framework")
local mock_pz = require("mock_pz")

-- Setup environment
mock_pz.setupGlobalEnvironment()

-- Mock dependencies required by the rules
_G.pz_utils_shared = {
	escape = {
		SafeLogger = {
			init = function() end,
			log = function() end,
			shouldLog = function()
				return true
			end,
		},
		SandboxVarsModule = {
			Init = function() end,
			Get = function(key, default)
				return _G.SandboxVars.CAFExampleRules[key] or default
			end,
		},
	},
	konijima = {
		Utilities = {
			IsPlayerAdmin = function(player)
				return player:getAccessLevel() == "Admin"
			end,
		},
	},
}
_G["pz_utils_shared"] = _G.pz_utils_shared -- Ensure global access for require

-- Mock the CAF Module require result
package.preload["container_authority_framework"] = function()
	return _G.ContainerAuthorityFramework
end

-- Load the rule file
local shop_ownership_rule = require("caf/rules/shop_ownership_rule")

-- ============================================================================
-- TESTS for Shop Ownership Rule
-- ============================================================================

TestRunner.register("ShopOwnership: Registers correctly via OnInitGlobalModData", function()
	-- Reset registration log
	_G.ContainerAuthorityFramework._registeredRules = {}

	-- Call the rule's init wrapper
	shop_ownership_rule()

	-- Trigger the init event to simulate game start
	mock_pz.triggerOnInit()

	local registered = _G.ContainerAuthorityFramework._registeredRules
	local found = false
	for _, rule in ipairs(registered) do
		if rule.id == "shop_ownership" and rule.phase == "validation" then
			found = true
			break
		end
	end

	TestRunner.assert_true(found, "Shop ownership rule should be registered")
end)

TestRunner.register("ShopOwnership: Logic prevents theft", function()
	-- Setup context
	local thief = mock_pz.IsoPlayer.new("Thief")
	local shopOwner = mock_pz.IsoPlayer.new("ShopOwner")

	local shopContainerObj = mock_pz.IsoObject.new()
	shopContainerObj._modData.shopOwner = "ShopOwner"

	local container = mock_pz.ItemContainer.new("crate", shopContainerObj)
	local item = mock_pz.InventoryItem.new("Base.Apple")

	local context = {
		character = thief,
		item = item,
		src = container,
		flags = { rejected = false, reason = nil },
	}

	-- Get the validation function directly from registration for testing logic
	local registeredCallback = nil

	-- Re-register to capture callback
	_G.ContainerAuthorityFramework._registeredRules = {}
	shop_ownership_rule()
	mock_pz.triggerOnInit()

	for _, rule in ipairs(_G.ContainerAuthorityFramework._registeredRules) do
		if rule.id == "shop_ownership" then
			registeredCallback = rule.callback
		end
	end

	TestRunner.assert_not_nil(registeredCallback, "Callback must be captured")

	-- Run validation logic
	registeredCallback(context)

	TestRunner.assert_true(context.flags.rejected, "Should reject transfer from unowned shop")
	TestRunner.assert_equals(context.flags.reason, "This item belongs to ShopOwner's shop.", "Reason should match")
end)

TestRunner.register("ShopOwnership: Allows owner access", function()
	local owner = mock_pz.IsoPlayer.new("ShopOwner")
	local shopContainerObj = mock_pz.IsoObject.new()
	shopContainerObj._modData.shopOwner = "ShopOwner"

	local container = mock_pz.ItemContainer.new("crate", shopContainerObj)
	local item = mock_pz.InventoryItem.new("Base.Apple")

	local context = {
		character = owner,
		item = item,
		src = container,
		flags = { rejected = false },
	}

	-- Get callback
	local registeredCallback = nil
	for _, rule in ipairs(_G.ContainerAuthorityFramework._registeredRules) do
		if rule.id == "shop_ownership" then
			registeredCallback = rule.callback
		end
	end

	registeredCallback(context)

	TestRunner.assert_true(not context.flags.rejected, "Should allow owner access")
end)

TestRunner.run()
