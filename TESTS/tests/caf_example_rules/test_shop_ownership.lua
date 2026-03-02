-- tests/caf_example_rules/test_shop_ownership.lua
local testDir = debug.getinfo(1).source:match("@?(.*/)")
package.path = testDir .. "?.lua;" .. package.path
package.path = testDir .. "../?.lua;" .. package.path
package.path = testDir
    .. "../../../container_authority_framework/42/media/lua/shared/?.lua;"
    .. package.path
package.path = testDir .. "../../../caf_example_rules/42/media/lua/client/?.lua;" .. package.path
package.path = testDir
    .. "../../../../../pz_tools/pz_lua_commons/pz_lua_commons/common/media/lua/shared/?.lua;"
    .. package.path
package.path = testDir .. "../../../../zul/zul/42/media/lua/shared/?.lua;" .. package.path

local TestRunner = require("test_framework")
local mock_pz = require("mock_pz")

-- Setup environment (Game Mocks)
mock_pz.setupGlobalEnvironment()

-- Reset CAF Global to ensure a fresh, real initialization
_G.ContainerAuthorityFramework = nil

-- Load Real CAF
local CAF_Init = require("container_authority_framework/container_authority")
local CAF = CAF_Init()

-- SPY on CAF.registerRule to capture registrations for verification
-- We do this because the rule function is local to the rule file, so we can't inspect equality easily.
local registeredSpy = {}
local real_registerRule = CAF.registerRule

function CAF:registerRule(phase, id, callback, priority)
    table.insert(registeredSpy, {
        phase = phase,
        id = id,
        callback = callback,
        priority = priority,
    })
    -- Call the real implementation to ensure actual registration logic runs
    real_registerRule(self, phase, id, callback, priority)
end

-- Load the rule file
local shop_ownership_rule = require("caf_example_rules/rules/shop_ownership_rule")

-- ============================================================================
-- TESTS for Shop Ownership Rule
-- ============================================================================

TestRunner.register("ShopOwnership: Registers correctly via OnInitGlobalModData", function()
    -- Reset spy and CAF state for test
    registeredSpy = {}
    CAF.pendingRules = {}
    CAF.isReady = false

    -- Call the rule's init wrapper
    shop_ownership_rule()

    -- Trigger the init event to simulate game start
    mock_pz.triggerOnInit()

    -- Verify via Spy
    local foundValidation = false
    local foundPre = false
    for _, rule in ipairs(registeredSpy) do
        if rule.id == "shop_ownership" then
            if rule.phase == "validation" then
                foundValidation = true
            elseif rule.phase == "pre" then
                foundPre = true
            end
        end
    end

    TestRunner.assert_true(foundValidation, "Shop ownership validation rule should be registered")
    TestRunner.assert_true(foundPre, "Shop ownership pre-transfer rule should be registered")
end)

TestRunner.register("ShopOwnership: Logic prevents theft", function()
    -- Setup context
    local thief = mock_pz.IsoPlayer.new("Thief")
    local shopOwner = mock_pz.IsoPlayer.new("ShopOwner")

    local shopContainerObj = mock_pz.IsoObject.new()
    shopContainerObj._modData.shopOwner = "ShopOwner"

    local container = mock_pz.ItemContainer.new("crate", shopContainerObj)
    local item = mock_pz.InventoryItem.new("Base.Apple")

    local destContainer = mock_pz.ItemContainer.new("inventory", nil)

    local context = {
        character = thief,
        item = item,
        src = container,
        dest = destContainer,
        flags = { rejected = false, reason = nil },
        metadata = {},
    }

    -- Capture the callback
    registeredSpy = {}
    CAF.pendingRules = {}
    CAF.isReady = false

    shop_ownership_rule()
    mock_pz.triggerOnInit()

    local validationCallback = nil
    for _, rule in ipairs(registeredSpy) do
        if rule.id == "shop_ownership" and rule.phase == "validation" then
            validationCallback = rule.callback
        end
    end

    TestRunner.assert_not_nil(validationCallback, "Validation callback must be captured")

    ---@diagnostic disable-next-line: need-check-nil
    -- Run validation logic
    validationCallback(context)

    TestRunner.assert_true(context.flags.rejected, "Should reject transfer from unowned shop")
    TestRunner.assert_equals(
        context.flags.reason,
        "This item belongs to ShopOwner's shop.",
        "Reason should match"
    )
end)

TestRunner.register("ShopOwnership: Allows owner access", function()
    local owner = mock_pz.IsoPlayer.new("ShopOwner")
    local shopContainerObj = mock_pz.IsoObject.new()
    shopContainerObj._modData.shopOwner = "ShopOwner"

    local container = mock_pz.ItemContainer.new("crate", shopContainerObj)
    local item = mock_pz.InventoryItem.new("Base.Apple")

    local destContainer = mock_pz.ItemContainer.new("inventory", nil)

    local context = {
        character = owner,
        item = item,
        src = container,
        dest = destContainer,
        flags = { rejected = false },
        metadata = {},
    }

    -- Get callback
    local validationCallback = nil
    for _, rule in ipairs(registeredSpy) do
        if rule.id == "shop_ownership" and rule.phase == "validation" then
            validationCallback = rule.callback
        end
    end

    TestRunner.assert_not_nil(validationCallback, "Validation callback must be present")

    ---@diagnostic disable-next-line: need-check-nil
    validationCallback(context)

    TestRunner.assert_true(not context.flags.rejected, "Should allow owner access")
end)

TestRunner.run()
