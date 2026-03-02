local CAF = require("container_authority_framework")
local pz_utils = require("pz_utils_shared")
local SafeLogger = pz_utils.escape.SafeLogger

local safe_logger = SafeLogger.new("caf_example_rules")

---Dummy validation rule for stress testing the pruner
local function createDummyValidator(ruleId)
    ---@param context table
    return function(context)
        -- This is a no-op validator for testing purposes
        -- It doesn't reject anything, just exists to test the pruner
        if SafeLogger.shouldLog and SafeLogger.shouldLog(10) then
            safe_logger:log("[CAF] Stress test rule " .. ruleId .. " executed", 10)
        end
    end
end

return function()
    if not CAF then
        safe_logger:log(
            "[CAF] Error: CAF singleton missing during stress_test_pruner registration!",
            50
        )
        return
    end

    -- Register 60 rules with LOW priority numbers (1-60)
    -- Convention: LOWER numbers = HIGHER priority (0 is highest)
    -- EventManager sorts DESCENDING (a.p > b.p): [n, n-1, ..., 1, 0]
    -- Pruning removes from INDEX 1 (highest number = lowest priority)
    --
    -- Priority comparison:
    -- - audit_log (500) - at index 1 after sort - PRUNED FIRST
    -- - shop_ownership (100) - at index 2 - PRUNED SECOND
    -- - stress_test_60 (60) - near start - PRUNED
    -- - stress_test_1 (1) - near end - KEPT
    --
    -- The default ValidationEventListenersMax is 25
    -- Expected result with limit of 25:
    -- - stress_test_1 through stress_test_25 (priorities 1-25) - KEPT (lowest numbers = highest priority)
    -- - stress_test_26 through stress_test_60 (priorities 26-60) - PRUNED
    -- - shop_ownership (priority 100) - PRUNED
    -- - audit_log (priority 500) - PRUNED
    for i = 1, 60 do
        local ruleId = "stress_test_" .. i
        local priority = i -- Priority from 1 to 60
        local validator = createDummyValidator(ruleId)

        CAF:registerRule("validation", ruleId, validator, priority)
    end

    safe_logger:log("[CAF] Stress Test Pruner: Registered 60 rules (priorities 1-60)", 30)
    safe_logger:log(
        "[CAF] Expected: With limit=25, keep LOWEST 25 priority numbers (stress_test_1 to stress_test_25), prune rest including shop_ownership and audit_log",
        30
    )

    -- Schedule a verification check after CAF initialization completes
    Events.OnInitGlobalModData.Add(function()
        -- This runs after CAF.loadConfig() completes
        local EventManager = pz_utils.escape.EventManager
        local valInfo = EventManager.getEventInfo("CAF:Validation")

        if valInfo then
            safe_logger:log(
                string.format(
                    "[CAF] STRESS TEST RESULT: Validation listeners = %d (expected: 25)",
                    valInfo.listeners
                ),
                30
            )

            if valInfo.listeners == 25 then
                safe_logger:log("[CAF] STRESS TEST: PRUNER WORKING CORRECTLY ✓", 30)
            else
                safe_logger:log(
                    string.format(
                        "[CAF] STRESS TEST: PRUNER FAILED! Expected 25, got %d ✗",
                        valInfo.listeners
                    ),
                    50
                )
            end
        end
    end)
end
