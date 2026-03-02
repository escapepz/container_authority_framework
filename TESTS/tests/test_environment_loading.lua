---@diagnostic disable: global-in-non-module
-- TESTS/tests/test_environment_loading.lua
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/TESTS/tests/?.lua;"
    .. package.path
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/container_authority_framework/42/media/lua/server/?.lua;"
    .. package.path
package.path = "d:/DATA/2026/pz_tools/pz_lua_commons/pz_lua_commons/common/media/lua/shared/?.lua;"
    .. package.path
package.path = "d:/DATA/2026/pz_mods_2026/zul/zul/42/media/lua/shared/?.lua;" .. package.path

local TestRunner = require("test_framework")
local mock_pz = require("mock_pz")

-- Setup environment
mock_pz.setupGlobalEnvironment()

-- We need to mock the patch module so we can spy on it
local is_inventory_transfer_action_patch =
    require("container_authority_framework/patches/is_inventory_transfer_action_patch")
local patchApplied = { server = false }
local original_serverSidePatch = is_inventory_transfer_action_patch.serverSidePatch

function is_inventory_transfer_action_patch.serverSidePatch()
    patchApplied.server = true
    -- Don't call original to avoid crashing on missing ISInventoryTransferAction in pure Lua
end

-- Load the init module
local server_patches_init = require("container_authority_framework/patches/server_patches_init")

TestRunner.register("EnvLoading: Singleplayer Mode (Local)", function()
    -- Reset state
    patchApplied.server = false
    _G._eventCallbacks = {} -- Clear registered events

    -- Set SP Environment
    mock_pz.setServer(false)
    mock_pz.setClient(false)
    mock_pz.setMultiplayer(false)

    -- Run Init
    server_patches_init()

    -- Verify OnGameBoot registration
    TestRunner.assert_not_nil(
        _G._eventCallbacks["OnGameBoot"],
        "OnGameBoot should be registered in SP"
    )
    mock_pz.triggerEvent("OnGameBoot")
    TestRunner.assert_true(patchApplied.server, "Patch should apply on OnGameBoot (SP)")

    -- Reset and verify OnGameStart (for Local fallback/SP specific init)
    patchApplied.server = false
    TestRunner.assert_not_nil(
        _G._eventCallbacks["OnGameStart"],
        "OnGameStart should be registered in SP"
    )
    mock_pz.triggerEvent("OnGameStart")
    TestRunner.assert_true(patchApplied.server, "Patch should apply on OnGameStart (SP)")
end)

TestRunner.register("EnvLoading: Multiplayer Server Mode", function()
    -- Reset state
    patchApplied.server = false
    _G._eventCallbacks = {}

    -- Set MP Server Environment
    mock_pz.setServer(true)
    mock_pz.setClient(false)
    mock_pz.setMultiplayer(true)

    -- Run Init
    server_patches_init()

    -- Verify OnGameBoot registration
    TestRunner.assert_not_nil(
        _G._eventCallbacks["OnGameBoot"],
        "OnGameBoot should be registered on Server"
    )
    mock_pz.triggerEvent("OnGameBoot")
    TestRunner.assert_true(patchApplied.server, "Patch should apply on OnGameBoot (Server)")

    -- Verify OnGameStart is NOT registered (not SP)
    TestRunner.assert_nil(
        _G._eventCallbacks["OnGameStart"],
        "OnGameStart should NOT be registered on Server"
    )
end)

TestRunner.register("EnvLoading: Multiplayer Client Mode (Should skip)", function()
    -- Reset state
    patchApplied.server = false
    _G._eventCallbacks = {}

    -- Set MP Client Environment
    mock_pz.setServer(false)
    mock_pz.setClient(true)
    mock_pz.setMultiplayer(true)

    -- Run Init
    server_patches_init()

    -- Verify nothing registered
    TestRunner.assert_nil(
        _G._eventCallbacks["OnGameBoot"],
        "OnGameBoot should NOT be registered on Client"
    )
    TestRunner.assert_nil(
        _G._eventCallbacks["OnGameStart"],
        "OnGameStart should NOT be registered on Client"
    )
end)

TestRunner.run()
