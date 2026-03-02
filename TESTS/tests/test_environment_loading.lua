---@diagnostic disable: global-in-non-module
-- TESTS/tests/test_environment_loading.lua
local testDir = debug.getinfo(1).source:match("@?(.*/)")
package.path = testDir .. "?.lua;" .. package.path
package.path = testDir
    .. "../../container_authority_framework/42/media/lua/shared/?.lua;"
    .. package.path
package.path = testDir
    .. "../../../../pz_tools/pz_lua_commons/pz_lua_commons/common/media/lua/shared/?.lua;"
    .. package.path
package.path = testDir .. "../../../zul/zul/42/media/lua/shared/?.lua;" .. package.path

local TestRunner = require("test_framework")
local mock_pz = require("mock_pz")

-- Setup environment
mock_pz.setupGlobalEnvironment()

-- We need to mock the patch module so we can spy on it
local is_inventory_transfer_action_patch =
    require("container_authority_framework/patches/is_inventory_transfer_action_patch")
local patchApplied = { server = false, client = false }

function is_inventory_transfer_action_patch.serverSidePatch()
    patchApplied.server = true
end

function is_inventory_transfer_action_patch.clientSidePatch()
    patchApplied.client = true
end

-- Load the init module
local shared_patches_init = require("container_authority_framework/patches/shared_patches_init")

TestRunner.register("EnvLoading: Singleplayer Mode (Local)", function()
    -- Reset state
    patchApplied.client = false
    _G._eventCallbacks = {} -- Clear registered events

    -- Set SP Environment
    mock_pz.setServer(false)
    mock_pz.setClient(false)
    mock_pz.setMultiplayer(false)

    -- Run Init
    shared_patches_init()

    -- Verify OnGameBoot is NOT registered (now using OnGameStart only)
    TestRunner.assert_nil(
        _G._eventCallbacks["OnGameBoot"],
        "OnGameBoot should NOT be registered in SP"
    )

    -- Verify OnGameStart
    TestRunner.assert_not_nil(
        _G._eventCallbacks["OnGameStart"],
        "OnGameStart should be registered in SP"
    )
    mock_pz.triggerEvent("OnGameStart")
    TestRunner.assert_true(patchApplied.client, "Patch should apply on OnGameStart (SP)")
end)

TestRunner.register("EnvLoading: Multiplayer Server Mode", function()
    -- Reset state
    patchApplied.client = false
    _G._eventCallbacks = {}

    -- Set MP Server Environment
    mock_pz.setServer(true)
    mock_pz.setClient(false)
    mock_pz.setMultiplayer(true)

    -- Run Init
    shared_patches_init()

    -- Verify nothing registered on Server (Dedicated) for shared patches
    TestRunner.assert_nil(
        _G._eventCallbacks["OnGameBoot"],
        "OnGameBoot should NOT be registered on Server"
    )
    TestRunner.assert_nil(
        _G._eventCallbacks["OnGameStart"],
        "OnGameStart should NOT be registered on Server"
    )
end)

TestRunner.register("EnvLoading: Multiplayer Client Mode", function()
    -- Reset state
    patchApplied.client = false
    _G._eventCallbacks = {}

    -- Set MP Client Environment
    mock_pz.setServer(false)
    mock_pz.setClient(true)
    mock_pz.setMultiplayer(true)

    -- Run Init
    shared_patches_init()

    -- Verify OnGameStart registered for Client
    TestRunner.assert_not_nil(
        _G._eventCallbacks["OnGameStart"],
        "OnGameStart should be registered on Client"
    )
    mock_pz.triggerEvent("OnGameStart")
    TestRunner.assert_true(patchApplied.client, "Patch should apply on OnGameStart (Client)")

    -- Verify OnGameBoot is NOT registered
    TestRunner.assert_nil(
        _G._eventCallbacks["OnGameBoot"],
        "OnGameBoot should NOT be registered on Client"
    )
end)

TestRunner.run()
