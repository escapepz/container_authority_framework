-- tests/test_rules_pruner.lua
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/TESTS/tests/?.lua;" .. package.path
package.path = "d:/DATA/2026/pz_mods_2026/container_authority_framework/container_authority_framework/42/media/lua/server/?.lua;"
	.. package.path
package.path = "d:/DATA/2026/pz_tools/pz_lua_commons/pz_lua_commons/common/media/lua/shared/?.lua;" .. package.path
package.path = "d:/DATA/2026/pz_mods_2026/zul/zul/42/media/lua/shared/?.lua;" .. package.path

local TestRunner = require("test_framework")

-- Setup PZ mocks first
local mock_pz = require("mock_pz")
mock_pz.setupGlobalEnvironment()

-- Mock dependencies
_G.pz_utils_shared = {
	escape = {
		EventManager = {
			createEvent = function() end, -- Stub
			events = {},
		},
		SafeLogger = {
			init = function() end,
			log = function() end,
			shouldLog = function()
				return true
			end,
		},
		SandboxVarsModule = {
			Init = function() end,
			Get = function()
				return 5
			end,
		}, -- Limit to 5
	},
	konijima = {},
}
-- We need the REAL EventManager logic to test pruning
-- So we load the EventManager from pz_utils_shared source if available, or mock it deeply.
-- Since pz_utils might not be in the workspace context directly accessible as file,
-- we will Mock a "Real" EventManager behavior locally for the pruner test.

local MockEventManager = {
	events = {},
}

function MockEventManager.getOrCreateEvent(name)
	if not MockEventManager.events[name] then
		MockEventManager.events[name] = {
			listeners = {},
			maxListeners = nil,
			Add = function(self, callback, priority)
				table.insert(self.listeners, { f = callback, p = priority })
				-- Sort by priority descending
				table.sort(self.listeners, function(a, b)
					return a.p > b.p
				end)
				self:_prune()
			end,
			SetMaxListeners = function(self, max)
				self.maxListeners = max
				self:_prune()
			end,
			_prune = function(self)
				if self.maxListeners and #self.listeners > self.maxListeners then
					-- Remove from end (lowest priority)
					table.remove(self.listeners)
				end
			end,
			GetListenerCount = function(self)
				return #self.listeners
			end,
		}
	end
	return MockEventManager.events[name]
end

function MockEventManager.setMaxListeners(name, max)
	local event = MockEventManager.getOrCreateEvent(name)
	event:SetMaxListeners(max)
end

function MockEventManager.on(name, callback, priority)
	local event = MockEventManager.getOrCreateEvent(name)
	event:Add(callback, priority)
end

_G.pz_utils_shared.escape.EventManager = MockEventManager

-- Force require to use our mocked pz_utils_shared (for EventManager)
package.loaded["pz_utils_shared"] = _G.pz_utils_shared

-- Reset global mock so that the real CAF can initialize
_G.ContainerAuthorityFramework = nil

-- Load CAF
local CAF_Init = require("caf/container_authority")
local CAF = CAF_Init()

-- To test pruner, we need to inspect the EventManager state after CAF sets limits
-- and after we flood it with rules.

TestRunner.register("Pruner: Enforces limit of 5 listeners", function()
	-- Initialize CAF manually to trigger loadConfig
	local cafInstance = _G.ContainerAuthorityFramework

	-- Mock loadConfig to set specific low limits for testing
	function cafInstance:loadConfig()
		local limit = 5
		MockEventManager.setMaxListeners(self.ValidationEvent, limit)
		self.isReady = true
	end

	cafInstance:loadConfig()

	-- Flood with 10 rules
	for i = 1, 10 do
		cafInstance:registerRule("validation", "rule_" .. i, function() end, i * 10)
	end
	-- Priorities: 10, 20, ... 100.
	-- Expected: Top 5 (100, 90, 80, 70, 60) should remain.
	-- Lower 5 (50, 40, 30, 20, 10) should be pruned.

	local event = MockEventManager.events["CAF:Validation"]

	---@diagnostic disable-next-line: need-check-nil
	TestRunner.assert_equals(#event.listeners, 5, "Should have exactly 5 listeners")
	---@diagnostic disable-next-line: need-check-nil, undefined-field
	TestRunner.assert_equals(event.listeners[1].p, 100, "Highest priority should remain")
	---@diagnostic disable-next-line: need-check-nil, undefined-field
	TestRunner.assert_equals(event.listeners[5].p, 60, "Lowest kept priority should be 60")
end)

TestRunner.run()
