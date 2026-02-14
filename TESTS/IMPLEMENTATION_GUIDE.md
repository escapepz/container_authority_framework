# How to Implement a Test Suite for Project Zomboid Lua 5.1 (Kahlua2)

A complete practical guide for building robust test suites for Project Zomboid mods using Lua 5.1 with the Kahlua2 VM.

---

## Table of Contents

1. [Overview](#overview)
2. [Core Concepts](#core-concepts)
3. [Architecture](#architecture)
4. [Implementation Steps](#implementation-steps)
5. [Test Framework](#test-framework)
6. [Mock/Stub Strategy](#mockstub-strategy)
7. [Testing Patterns](#testing-patterns)
8. [Best Practices](#best-practices)
9. [Examples](#examples)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### Why Test Project Zomboid Mods?

Project Zomboid runs Lua 5.1 code via the Kahlua2 Java VM bridge. Testing without the game runtime is challenging because:

- **No Direct Runtime Access**: Can't run PZ code in plain Lua
- **Complex API Surface**: Game APIs have Java classes (ArrayList, HashMap, etc.)
- **Integration Complexity**: Libraries interact with PZ engine objects

### The Solution: Stub-Based Testing

Create a test environment that:

1. **Mocks** the PZ Java APIs with Lua equivalents
2. **Validates** libraries work with those mocks
3. **Ensures** code will work in actual PZ runtime
4. **Runs** in plain Lua without game installation

---

## Core Concepts

### 1. Stubs vs Mocks

| Term | Meaning | Used For |
|------|---------|----------|
| **Stub** | Minimal implementation matching a real API contract | Defining what methods exist |
| **Mock** | Stub that tracks calls and validates behavior | Testing how code uses APIs |
| **Fake** | Working implementation for testing (not real) | Replacing expensive operations |

In PZ testing, we create **mocks** that implement **stub contracts**.

### 2. Contract-Based Design

A "contract" is the interface specification:

```lua
-- Stub contract for ArrayList
ArrayList contract:
  - add(item) -> boolean
  - get(index) -> Object
  - size() -> number
  - remove(index) -> Object

-- Mock implementation must match this contract exactly
```

### 3. Kahlua2 Limitations

Lua 5.1 via Kahlua2 has constraints:

- **No metatables** for userdata (Java objects)
- **Limited standard library** (no io, debug, etc.)
- **Strict type coercion** rules
- **No external module loading** (must be sandboxed)

Test strategy accounts for these:

- Use pure Lua objects for mocks
- Avoid stdlib functions Kahlua2 doesn't support
- Test with actual library loads as they run in PZ

---

## Architecture

### Directory Structure

```
TEST_SUITE/
├── tests/
│   ├── mock_pz.lua                 # PZ API stubs
│   ├── test_common_lib.lua         # Main test suite
│   ├── test_pz_utils_escape.lua    # Utility tests
│   ├── test_pz_utils_konijima.lua  # Utility tests
│   └── test_sandbox_vars_module.lua # Sandbox tests
├── examples/
│   └── example_usage.lua           # Real-world patterns
├── TESTING_SUITE.md                # Quick reference
├── TEST_ARCHITECTURE.md            # Detailed architecture
└── IMPLEMENTATION_GUIDE.md         # This file
```

### Components

#### 1. **mock_pz.lua** - The Stub Layer

Provides minimal implementations of PZ APIs:

```lua
-- Collections
ArrayList, HashMap

-- Geometry
Vector2f, Vector3f

-- Game Objects
Character, Item, GameState

-- Utilities
GetTickCount(), GetCurrentTimeMs()
```

#### 2. **test_*.lua** - Test Suites

Organized test files by module:

- `test_common_lib.lua` - Main integration tests (50+ cases)
- `test_pz_utils_escape.lua` - Logging/escaping utilities
- `test_pz_utils_konijima.lua` - Array/table utilities
- `test_sandbox_vars_module.lua` - Sandbox variable tests

#### 3. **example_usage.lua** - Reference Implementation

Demonstrates real-world patterns:

- JSON serialization
- Event systems
- OOP patterns
- Logging and debouncing
- Multi-library workflows

---

## Implementation Steps

### Step 1: Create Mock/Stub Layer

Create `tests/mock_pz.lua`:

```lua
-- mock_pz.lua
-- Minimal stubs for PZ APIs used in testing

local mock_pz = {}

-- ArrayList stub
local ArrayList = {}
ArrayList.__index = ArrayList

function ArrayList.new()
    return setmetatable({
        _items = {}
    }, ArrayList)
end

function ArrayList:add(item)
    table.insert(self._items, item)
    return true
end

function ArrayList:get(index)
    return self._items[index]
end

function ArrayList:size()
    return #self._items
end

function ArrayList:remove(index)
    local item = self._items[index]
    table.remove(self._items, index)
    return item
end

function ArrayList:toArray()
    return self._items
end

mock_pz.ArrayList = ArrayList

-- Vector2f stub
local Vector2f = {}
Vector2f.__index = Vector2f

function Vector2f.new(x, y)
    return setmetatable({
        x = x or 0,
        y = y or 0
    }, Vector2f)
end

function Vector2f:distance(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math.sqrt(dx * dx + dy * dy)
end

mock_pz.Vector2f = Vector2f

-- Setup global environment for test access
function mock_pz.setupGlobalEnvironment()
    _G.ArrayList = ArrayList
    _G.Vector2f = Vector2f
    -- Add other stubs as needed
end

return mock_pz
```

**Key Points**:

- Implement ONLY methods used by your code
- Match method signatures exactly
- Use Lua tables (not Java objects)
- Provide `setupGlobalEnvironment()` to inject globals

### Step 2: Create Test Framework

Create a simple test runner in `tests/test_framework.lua`:

```lua
-- test_framework.lua
-- Minimal test framework for PZ Lua testing

local TestRunner = {
    tests = {},
    passed = 0,
    failed = 0,
    errors = {}
}

function TestRunner.register(name, testFunc)
    table.insert(TestRunner.tests, {
        name = name,
        func = testFunc
    })
end

function TestRunner.assert_equals(actual, expected, message)
    if actual ~= expected then
        error(string.format(
            "%s\n  Expected: %s\n  Got: %s",
            message, tostring(expected), tostring(actual)
        ))
    end
end

function TestRunner.assert_true(value, message)
    if not value then
        error(message)
    end
end

function TestRunner.assert_not_nil(value, message)
    if value == nil then
        error(message)
    end
end

function TestRunner.assert_is_type(value, expectedType, message)
    if type(value) ~= expectedType then
        error(string.format(
            "%s\n  Expected type: %s\n  Got type: %s",
            message, expectedType, type(value)
        ))
    end
end

function TestRunner.run()
    print(string.rep("=", 70))
    print("TEST SUITE")
    print(string.rep("=", 70))
    print()
    
    for _, test in ipairs(TestRunner.tests) do
        local status, err = pcall(test.func)
        local result = status and "OK" or "FAIL"
        
        if status then
            TestRunner.passed = TestRunner.passed + 1
            print(string.format("%-50s %s", test.name, result))
        else
            TestRunner.failed = TestRunner.failed + 1
            print(string.format("%-50s %s", test.name, result))
            table.insert(TestRunner.errors, {
                name = test.name,
                error = err
            })
        end
    end
    
    print()
    print(string.rep("=", 70))
    print("TEST RESULTS")
    print(string.rep("=", 70))
    print(string.format("Passed: %d", TestRunner.passed))
    print(string.format("Failed: %d", TestRunner.failed))
    print(string.format("Total:  %d", TestRunner.passed + TestRunner.failed))
    print()
    
    if TestRunner.failed > 0 then
        print("FAILURES:")
        for _, failure in ipairs(TestRunner.errors) do
            print(string.format("\n%s:", failure.name))
            print(failure.error)
        end
        return false
    else
        print("✓ ALL TESTS PASSED")
        return true
    end
end

return TestRunner
```

### Step 3: Create Test Suite

Create `tests/test_common_lib.lua`:

```lua
-- test_common_lib.lua
-- Integration tests for pz_lua_commons

-- Setup paths
local testDir = debug.getinfo(1).source:match("@?(.*/)")
package.path = testDir .. "?.lua;" .. package.path
package.path = testDir .. "../../pz_lua_commons/common/media/lua/shared/?.lua;" .. package.path

-- Load test framework and mocks
local TestRunner = require("test_framework")
local mock_pz = require("mock_pz")
mock_pz.setupGlobalEnvironment()

-- Load the actual modules to test
local pz_commons = require("pz_lua_commons/shared")
local pz_utils = require("pz_utils/shared")

-- ============================================================================
-- MODULE LOADING TESTS
-- ============================================================================

TestRunner.register("Module loading: pz_lua_commons exists", function()
    TestRunner.assert_not_nil(pz_commons, "pz_commons should exist")
end)

TestRunner.register("Module loading: pz_utils exists", function()
    TestRunner.assert_not_nil(pz_utils, "pz_utils should exist")
end)

TestRunner.register("Module loading: lunajson available", function()
    local lunajson = pz_commons.grafi_tt.lunajson
    TestRunner.assert_not_nil(lunajson, "lunajson should be available")
end)

-- ============================================================================
-- LIBRARY TESTS
-- ============================================================================

TestRunner.register("lunajson: encode basic table", function()
    local lunajson = pz_commons.grafi_tt.lunajson
    local data = { x = 1, y = 2 }
    local encoded = lunajson.encode(data)
    TestRunner.assert_is_type(encoded, "string", "encoded should be string")
end)

TestRunner.register("lunajson: decode valid json", function()
    local lunajson = pz_commons.grafi_tt.lunajson
    local json = '{"x":1,"y":2}'
    local decoded = lunajson.decode(json)
    TestRunner.assert_equals(decoded.x, 1, "decoded.x should be 1")
    TestRunner.assert_equals(decoded.y, 2, "decoded.y should be 2")
end)

TestRunner.register("middleclass: create class", function()
    local middleclass = pz_commons.kikito.middleclass
    local Animal = middleclass("Animal")
    
    function Animal:initialize(name)
        self.name = name
    end
    
    local dog = Animal("Buddy")
    TestRunner.assert_equals(dog.name, "Buddy", "dog name should be Buddy")
end)

TestRunner.register("middleclass: inheritance", function()
    local middleclass = pz_commons.kikito.middleclass
    local Animal = middleclass("Animal")
    
    function Animal:initialize(name)
        self.name = name
    end
    
    function Animal:speak()
        return "sound"
    end
    
    local Dog = middleclass("Dog", Animal)
    
    function Dog:speak()
        return "woof"
    end
    
    local dog = Dog("Buddy")
    TestRunner.assert_equals(dog:speak(), "woof", "dog should speak woof")
    TestRunner.assert_equals(dog.name, "Buddy", "dog should have name")
end)

TestRunner.register("hump.signal: emit event", function()
    local signal = pz_commons.vrld.hump_signal
    local result = nil
    
    signal.register("test_event", function(value)
        result = value
    end)
    
    signal.emit("test_event", 42)
    TestRunner.assert_equals(result, 42, "event should pass value")
end)

-- ============================================================================
-- STUB COMPATIBILITY TESTS
-- ============================================================================

TestRunner.register("Stub: ArrayList works", function()
    local list = ArrayList.new()
    list:add("item1")
    list:add("item2")
    TestRunner.assert_equals(list:size(), 2, "ArrayList size should be 2")
end)

TestRunner.register("Stub: Vector2f distance", function()
    local v1 = Vector2f.new(0, 0)
    local v2 = Vector2f.new(3, 4)
    local dist = v1:distance(v2)
    TestRunner.assert_equals(dist, 5, "distance should be 5")
end)

-- ============================================================================
-- INTEGRATION TESTS
-- ============================================================================

TestRunner.register("Integration: JSON + ArrayList", function()
    local lunajson = pz_commons.grafi_tt.lunajson
    local list = ArrayList.new()
    
    list:add("apple")
    list:add("banana")
    
    local json = lunajson.encode({ items = list:toArray() })
    TestRunner.assert_is_type(json, "string", "should serialize to JSON")
end)

TestRunner.register("Integration: OOP + ArrayList", function()
    local middleclass = pz_commons.kikito.middleclass
    local Inventory = middleclass("Inventory")
    
    function Inventory:initialize()
        self.items = ArrayList.new()
    end
    
    function Inventory:addItem(item)
        self.items:add(item)
    end
    
    function Inventory:size()
        return self.items:size()
    end
    
    local inv = Inventory()
    inv:addItem("sword")
    inv:addItem("shield")
    TestRunner.assert_equals(inv:size(), 2, "inventory should have 2 items")
end)

-- Run all tests
TestRunner.run()
```

### Step 4: Add to Your Mod

In your mod's main script:

```lua
-- mod.lua
-- Include test suite if running in test mode

if IS_TEST_MODE then
    local testDir = "path/to/TEST_SUITE/tests"
    package.path = package.path .. ";" .. testDir .. "/?.lua"
    
    local TestRunner = require("test_framework")
    local test_suite = require("test_common_lib")
    -- Tests will be registered and run
end

-- Normal mod code continues...
local pz_commons = require("pz_lua_commons/shared")
```

---

## VSCode Configuration

### Setup for Test Execution

Configure VSCode to run and debug tests with keyboard shortcuts and task runners.

### 1. tasks.json - Run Tests

Create `.vscode/tasks.json`:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Run All Tests",
            "type": "shell",
            "command": "lua",
            "args": ["test_common_lib.lua"],
            "options": {
                "cwd": "${workspaceFolder}/TEST_SUITE/tests"
            },
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            },
            "problemMatcher": [],
            "group": {
                "kind": "test",
                "isDefault": true
            }
        },
        {
            "label": "Run Utils Tests",
            "type": "shell",
            "command": "lua",
            "args": ["test_pz_utils_escape.lua"],
            "options": {
                "cwd": "${workspaceFolder}/TEST_SUITE/tests"
            },
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            },
            "problemMatcher": []
        },
        {
            "label": "Run Array Tests",
            "type": "shell",
            "command": "lua",
            "args": ["test_pz_utils_konijima.lua"],
            "options": {
                "cwd": "${workspaceFolder}/TEST_SUITE/tests"
            },
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            },
            "problemMatcher": []
        },
        {
            "label": "Run Sandbox Tests",
            "type": "shell",
            "command": "lua",
            "args": ["test_sandbox_vars_module.lua"],
            "options": {
                "cwd": "${workspaceFolder}/TEST_SUITE/tests"
            },
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            },
            "problemMatcher": []
        }
    ]
}
```

**Key Settings**:

| Setting | Purpose |
|---------|---------|
| `"label"` | Task name shown in VSCode |
| `"type": "shell"` | Run as shell command |
| `"command": "lua"` | Execute `lua` binary |
| `"args"` | Arguments to lua (test file) |
| `"cwd"` | Working directory for test |
| `"presentation"` | How to show output |
| `"group": "test"` | Mark as test task |
| `"isDefault": true` | Run on `Ctrl+Shift+B` |

**Usage**:

- Press `Ctrl+Shift+B` to run default task (All Tests)
- Press `Ctrl+Shift+P` → "Tasks: Run Task" to select specific test
- Output appears in integrated terminal

### 2. launch.json - Debug Tests

Create `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug All Tests",
            "type": "lua",
            "request": "launch",
            "program": "${workspaceFolder}/TEST_SUITE/tests/test_common_lib.lua",
            "cwd": "${workspaceFolder}/TEST_SUITE/tests",
            "stopOnEntry": false
        },
        {
            "name": "Debug Utils Tests",
            "type": "lua",
            "request": "launch",
            "program": "${workspaceFolder}/TEST_SUITE/tests/test_pz_utils_escape.lua",
            "cwd": "${workspaceFolder}/TEST_SUITE/tests",
            "stopOnEntry": false
        },
        {
            "name": "Debug Array Tests",
            "type": "lua",
            "request": "launch",
            "program": "${workspaceFolder}/TEST_SUITE/tests/test_pz_utils_konijima.lua",
            "cwd": "${workspaceFolder}/TEST_SUITE/tests",
            "stopOnEntry": false
        },
        {
            "name": "Debug Sandbox Tests",
            "type": "lua",
            "request": "launch",
            "program": "${workspaceFolder}/TEST_SUITE/tests/test_sandbox_vars_module.lua",
            "cwd": "${workspaceFolder}/TEST_SUITE/tests",
            "stopOnEntry": false
        },
        {
            "name": "Debug Example",
            "type": "lua",
            "request": "launch",
            "program": "${workspaceFolder}/TEST_SUITE/examples/example_usage.lua",
            "cwd": "${workspaceFolder}",
            "stopOnEntry": false
        }
    ]
}
```

**Key Settings**:

| Setting | Purpose |
|---------|---------|
| `"name"` | Configuration shown in Run menu |
| `"type": "lua"` | Use Lua debugger |
| `"request": "launch"` | Start new process |
| `"program"` | Test file to debug |
| `"cwd"` | Working directory |
| `"stopOnEntry"` | Stop at first line (true/false) |

**Usage**:

- Press `F5` to start debugging (first config)
- Click "Run" → select config from dropdown
- Set breakpoints by clicking line numbers
- Step through code with F10/F11
- View variables in left panel

### 3. Required Extensions

Install VSCode extensions for Lua debugging:

**Extensions.json** - Auto-install on workspace load:

```json
{
    "recommendations": [
        "actboy168.lua-debug",
        "sumneko.lua",
        "dwenegar.simple-lua-debug"
    ]
}
```

**Install Manually**:

1. Press `Ctrl+Shift+X` (Extensions)
2. Search and install:
   - **Lua Debug** (actboy168) - For debugging
   - **Lua** (sumneko) - For IntelliSense

### 4. Keybindings for Testing

Add to `.vscode/keybindings.json`:

```json
[
    {
        "key": "ctrl+shift+b",
        "command": "workbench.action.tasks.runTask",
        "args": "Run All Tests"
    },
    {
        "key": "f5",
        "command": "workbench.action.debug.start"
    },
    {
        "key": "shift+f5",
        "command": "workbench.action.debug.stop"
    },
    {
        "key": "ctrl+alt+t",
        "command": "workbench.action.terminal.new"
    }
]
```

### 5. Workflow Example

**Run tests from VSCode**:

1. Open test file: `TEST_SUITE/tests/test_common_lib.lua`
2. Press `Ctrl+Shift+B` → Runs all tests in terminal
3. View output in integrated terminal
4. If test fails, check error message

**Debug tests from VSCode**:

1. Open test file
2. Click line number to set breakpoint (red dot)
3. Press `F5` → Starts debugger
4. Pauses at breakpoint
5. Step through with F10
6. View variables in "Variables" panel
7. Press F5 again to continue

**Custom keybindings**:

| Key | Action |
|-----|--------|
| `Ctrl+Shift+B` | Run default test task |
| `F5` | Start debugging |
| `Shift+F5` | Stop debugging |
| `F10` | Step over |
| `F11` | Step into |
| `Shift+F11` | Step out |

### 6. settings.json for Lua

Configure `.vscode/settings.json`:

```json
{
    "Lua.runtime.version": "Lua 5.1",
    "Lua.diagnostics.globals": ["require", "module", "_G"],
    "Lua.workspace.library": [
        "${workspaceFolder}/pz_lua_commons/common/media/lua/shared"
    ],
    "Lua.workspace.ignoreDir": [
        ".git",
        ".vscode",
        "node_modules"
    ],
    "editor.formatOnSave": true,
    "files.trimFinalNewlines": true,
    "files.trimTrailingWhitespace": true
}
```

---

## Test Framework

### Assertion API

```lua
-- Equality check
TestRunner.assert_equals(actual, expected, "message")

-- Boolean check
TestRunner.assert_true(value, "message")

-- Nil check
TestRunner.assert_not_nil(value, "message")

-- Type check
TestRunner.assert_is_type(value, "string", "should be string")

-- Custom assertion
local function assert_contains(list, item, message)
    for _, v in ipairs(list) do
        if v == item then return end
    end
    error(message)
end
```

### Test Registration

```lua
TestRunner.register("Feature: description", function()
    -- Test code here
    local result = someFunction()
    TestRunner.assert_equals(result, expected, "should return expected")
end)
```

### Running Tests

```bash
cd TEST_SUITE/tests
lua test_common_lib.lua
```

Output:

```
======================================================================
TEST SUITE
======================================================================

Module loading: pz_lua_commons exists              OK
Module loading: pz_utils exists                   OK
lunajson: encode basic table                      OK
...

======================================================================
TEST RESULTS
======================================================================
Passed: 50
Failed: 0
Total:  50

✓ ALL TESTS PASSED
```

---

## Mock/Stub Strategy

### 1. Contract-Based Mocks

Define what the stub must do:

```lua
-- Stub contract for Item
-- class Item {
--     String getName()
--     int getWeight()
--     int getValue()
-- }

-- Mock implementation
local Item = {}
Item.__index = Item

function Item.new(name, weight, value)
    return setmetatable({
        _name = name,
        _weight = weight,
        _value = value
    }, Item)
end

function Item:getName()
    return self._name
end

function Item:getWeight()
    return self._weight
end

function Item:getValue()
    return self._value
end

return Item
```

### 2. Minimal Implementation

Only implement what's actually used:

```lua
-- BAD: Over-implementation
function Item:setName(name) end
function Item:setWeight(weight) end
function Item:setDurability(d) end
function Item:repair() end
function Item:isWeapon() end
-- ... 10 more methods

-- GOOD: Only what's tested
function Item:getName()
    return self._name
end

function Item:getWeight()
    return self._weight
end
```

### 3. Behavior Matching

Mock behavior must match real stub:

```lua
-- Stub behavior: ArrayList add always returns boolean
function ArrayList:add(item)
    table.insert(self._items, item)
    return true  -- Matches stub contract
end

-- Test verifies this
local result = list:add("item")
TestRunner.assert_equals(type(result), "boolean")
```

### 4. Java Collection Mocks

Map common Java classes:

```lua
-- ArrayList -> Lua table wrapper
function ArrayList:toArray()
    return self._items
end

function ArrayList:iterator()
    -- Simple iterator
    local index = 0
    return function()
        index = index + 1
        return self._items[index]
    end
end

-- HashMap -> Lua table wrapper
function HashMap:keySet()
    local keys = {}
    for k in pairs(self._map) do
        table.insert(keys, k)
    end
    return keys
end

function HashMap:entrySet()
    local entries = {}
    for k, v in pairs(self._map) do
        table.insert(entries, { key = k, value = v })
    end
    return entries
end
```

### 5. Global Setup

Inject mocks into global scope:

```lua
-- mock_pz.lua
function mock_pz.setupGlobalEnvironment()
    _G.ArrayList = ArrayList
    _G.HashMap = HashMap
    _G.Vector2f = Vector2f
    _G.Vector3f = Vector3f
    _G.Character = Character
    _G.Item = Item
    _G.GameState = GameState
    _G.GetTickCount = GetTickCount
    _G.GetCurrentTimeMs = GetCurrentTimeMs
end

-- In test file
local mock_pz = require("mock_pz")
mock_pz.setupGlobalEnvironment()

-- Now ArrayList, Vector2f, etc. are globally available
```

---

## Testing Patterns

### Pattern 1: Unit Testing a Library

Test individual library features in isolation:

```lua
TestRunner.register("lunajson: handle nested tables", function()
    local lunajson = pz_commons.grafi_tt.lunajson
    
    local data = {
        user = {
            name = "Bob",
            age = 30,
            inventory = {"sword", "shield"}
        }
    }
    
    local json = lunajson.encode(data)
    local decoded = lunajson.decode(json)
    
    TestRunner.assert_equals(decoded.user.name, "Bob")
    TestRunner.assert_equals(decoded.user.age, 30)
    TestRunner.assert_equals(#decoded.user.inventory, 2)
end)
```

### Pattern 2: Testing with Mocks

Test code that uses game objects:

```lua
TestRunner.register("Integration: Inventory with ArrayList", function()
    -- Create mock objects
    local inv = ArrayList.new()
    
    -- Populate
    inv:add(Item.new("sword", 5, 100))
    inv:add(Item.new("shield", 8, 75))
    
    -- Test
    TestRunner.assert_equals(inv:size(), 2)
    local item1 = inv:get(1)
    TestRunner.assert_equals(item1:getName(), "sword")
end)
```

### Pattern 3: Testing Real Library + Mocks

Test that real libraries work with mock objects:

```lua
TestRunner.register("Integration: JSON serialize mock objects", function()
    local lunajson = pz_commons.grafi_tt.lunajson
    
    -- Create mock
    local char = Character.new("Player", 100, 100)
    
    -- Use real library with mock
    local data = {
        name = char:getName(),
        health = char:getHealth(),
        position = {
            x = char:getX(),
            y = char:getY()
        }
    }
    
    local json = lunajson.encode(data)
    
    -- Verify
    TestRunner.assert_is_type(json, "string")
    local decoded = lunajson.decode(json)
    TestRunner.assert_equals(decoded.name, "Player")
end)
```

### Pattern 4: Testing OOP with Mocks

Test classes that use game APIs:

```lua
TestRunner.register("Integration: Custom class with mock objects", function()
    local middleclass = pz_commons.kikito.middleclass
    
    -- Define custom class using mocks
    local Survivor = middleclass("Survivor")
    
    function Survivor:initialize(name, maxHealth)
        self.name = name
        self.character = Character.new(name, maxHealth, maxHealth)
        self.inventory = ArrayList.new()
    end
    
    function Survivor:takeDamage(amount)
        self.character:takeDamage(amount)
        return self.character:isAlive()
    end
    
    function Survivor:addItem(item)
        self.inventory:add(item)
    end
    
    -- Test the class
    local survivor = Survivor("Bob", 100)
    
    survivor:addItem(Item.new("water", 1, 10))
    TestRunner.assert_equals(survivor.inventory:size(), 1)
    
    survivor:takeDamage(50)
    TestRunner.assert_equals(survivor.character:getHealth(), 50)
end)
```

### Pattern 5: Event Testing

Test event systems:

```lua
TestRunner.register("Integration: Event system with mocks", function()
    local signal = pz_commons.vrld.hump_signal
    local EventManager = pz_utils.escape.EventManager
    
    -- Setup event listeners
    local events = EventManager.new()
    local itemAdded = nil
    
    signal.register("item_added", function(item)
        itemAdded = item
    end)
    
    -- Trigger event with mock object
    local item = Item.new("potion", 2, 50)
    signal.emit("item_added", item)
    
    -- Verify
    TestRunner.assert_equals(itemAdded:getName(), "potion")
end)
```

---

## Best Practices

### 1. Test Organization

Group related tests:

```lua
-- ✓ GOOD: Clear sections
-- ============================================================================
-- LOADING TESTS
-- ============================================================================
TestRunner.register("Load: pz_commons", function() ... end)
TestRunner.register("Load: pz_utils", function() ... end)

-- ============================================================================
-- LIBRARY TESTS
-- ============================================================================
TestRunner.register("Library: lunajson encode", function() ... end)
TestRunner.register("Library: lunajson decode", function() ... end)

-- ============================================================================
-- STUB TESTS
-- ============================================================================
TestRunner.register("Stub: ArrayList operations", function() ... end)

-- ✗ BAD: Random order
TestRunner.register("Some test 1", function() ... end)
TestRunner.register("Random test 2", function() ... end)
TestRunner.register("Another test 1", function() ... end)
```

### 2. Clear Test Names

Use consistent naming:

```lua
-- ✓ GOOD: {Category}: {Feature} {Behavior}
TestRunner.register("Library: lunajson encodes basic types", function()
TestRunner.register("Stub: ArrayList removes items correctly", function()
TestRunner.register("Integration: JSON + ArrayList serialize", function()

-- ✗ BAD: Vague names
TestRunner.register("test 1", function()
TestRunner.register("thing works", function()
TestRunner.register("check it", function()
```

### 3. One Assertion Focus

Each test should focus on one thing:

```lua
-- ✓ GOOD: One responsibility
TestRunner.register("ArrayList: add returns true", function()
    local list = ArrayList.new()
    local result = list:add("item")
    TestRunner.assert_equals(result, true)
end)

TestRunner.register("ArrayList: add increases size", function()
    local list = ArrayList.new()
    list:add("item")
    TestRunner.assert_equals(list:size(), 1)
end)

-- ✗ BAD: Multiple concerns
TestRunner.register("ArrayList: add works", function()
    local list = ArrayList.new()
    local result = list:add("item")
    TestRunner.assert_equals(result, true)
    TestRunner.assert_equals(list:size(), 1)
    TestRunner.assert_equals(list:get(1), "item")
    -- If this fails, which part broke?
end)
```

### 4. Mock Contract Validation

Always verify mocks match stubs:

```lua
-- Document what stub defines
-- Stub contract for ArrayList:
--   add(item) -> boolean
--   get(index) -> Object | nil
--   size() -> number
--   remove(index) -> Object | nil

-- Verify mock matches contract
TestRunner.register("Stub Contract: ArrayList.add returns boolean", function()
    local list = ArrayList.new()
    local result = list:add("item")
    TestRunner.assert_is_type(result, "boolean")
end)

TestRunner.register("Stub Contract: ArrayList.get returns Object or nil", function()
    local list = ArrayList.new()
    list:add("item")
    local result = list:get(1)
    TestRunner.assert_not_nil(result)
    TestRunner.assert_equals(result, "item")
    
    local notFound = list:get(999)
    TestRunner.assert_equals(notFound, nil)
end)
```

### 5. Path Management

Handle paths consistently:

```lua
-- ✓ GOOD: Relative to test file
local testDir = debug.getinfo(1).source:match("@?(.*/)")
package.path = testDir .. "?.lua;" .. package.path

-- Add commons path
package.path = testDir .. "../../pz_lua_commons/common/media/lua/shared/?.lua;" 
             .. package.path

-- ✗ BAD: Hardcoded absolute paths
package.path = "C:\\Users\\Bob\\Project\\TEST_SUITE\\tests\\?.lua;" .. package.path
-- Breaks on different machines
```

### 6. Error Messages

Provide clear error context:

```lua
-- ✓ GOOD: Descriptive
TestRunner.assert_equals(list:size(), 2, 
    "ArrayList should contain 2 items after adding twice")

TestRunner.assert_equals(char:getHealth(), 75,
    "Character health should be 75 after taking 25 damage from 100")

-- ✗ BAD: Vague
TestRunner.assert_equals(list:size(), 2)
TestRunner.assert_equals(char:getHealth(), 75)
```

### 7. Setup and Teardown

Clean state between tests:

```lua
-- Create helper for test setup
local function setupTestCharacter(name, health)
    return Character.new(name, health, health)
end

-- Use in tests
TestRunner.register("Character: takes damage", function()
    local char = setupTestCharacter("Bob", 100)
    char:takeDamage(25)
    TestRunner.assert_equals(char:getHealth(), 75)
end)

TestRunner.register("Character: tracks position", function()
    local char = setupTestCharacter("Alice", 100)
    char:setPosition(10, 20)
    TestRunner.assert_equals(char:getX(), 10)
    TestRunner.assert_equals(char:getY(), 20)
end)
```

---

## Examples

### Complete Test File

See `examples/example_usage.lua` for real-world patterns:

```lua
-- example_usage.lua
-- Real-world integration patterns for PZ mods

local pz_commons = require("pz_lua_commons/shared")
local lunajson = pz_commons.grafi_tt.lunajson
local middleclass = pz_commons.kikito.middleclass
local signal = pz_commons.vrld.hump_signal
local SafeLogger = pz_utils.escape.SafeLogger
local Debounce = pz_utils.escape.Debounce

-- ============================================================================
-- EXAMPLE 1: JSON Serialization
-- ============================================================================

local function exportPlayerData(player)
    local data = {
        name = player:getName(),
        health = player:getHealth(),
        position = {
            x = player:getX(),
            y = player:getY()
        },
        inventory = {}
    }
    
    for i = 1, player:getInventorySize() do
        local item = player:getInventoryItem(i)
        table.insert(data.inventory, {
            name = item:getName(),
            weight = item:getWeight()
        })
    end
    
    return lunajson.encode(data)
end

-- ============================================================================
-- EXAMPLE 2: OOP with Middleclass
-- ============================================================================

local Character = middleclass("Character")

function Character:initialize(name, maxHealth)
    self.name = name
    self.maxHealth = maxHealth
    self.health = maxHealth
    self.equipment = {}
end

function Character:takeDamage(amount)
    self.health = math.max(0, self.health - amount)
end

function Character:heal(amount)
    self.health = math.min(self.maxHealth, self.health + amount)
end

function Character:isAlive()
    return self.health > 0
end

-- ============================================================================
-- EXAMPLE 3: Event System
-- ============================================================================

local EventDispatcher = middleclass("EventDispatcher")

function EventDispatcher:initialize()
    self.listeners = {}
end

function EventDispatcher:on(event, callback)
    signal.register(event, callback)
end

function EventDispatcher:emit(event, ...)
    signal.emit(event, ...)
end

-- ============================================================================
-- EXAMPLE 4: Logging and Debouncing
-- ============================================================================

local logger = SafeLogger.new("MyMod", "DEBUG")
local debouncedSave = Debounce.new(5000, function()
    logger:info("Saving game state")
    -- Save logic
end)

-- Register debounced function
signal.register("player_moved", function()
    logger:debug("Player moved")
    debouncedSave:call()
end)

-- ============================================================================
-- EXAMPLE 5: Combined Workflow
-- ============================================================================

local Inventory = middleclass("Inventory")

function Inventory:initialize(owner)
    self.owner = owner
    self.items = {}
    self.logger = SafeLogger.new("Inventory")
end

function Inventory:addItem(item)
    table.insert(self.items, item)
    self.logger:info(string.format(
        "Added %s to %s inventory",
        item:getName(),
        self.owner:getName()
    ))
    signal.emit("inventory_changed", self)
end

function Inventory:toJSON()
    local data = {}
    for _, item in ipairs(self.items) do
        table.insert(data, {
            name = item:getName(),
            weight = item:getWeight()
        })
    end
    return lunajson.encode(data)
end

-- Use in test
local function testCompleteWorkflow()
    local player = Character("Hero", 100)
    local inventory = Inventory(player)
    
    inventory:addItem(MockItem("sword", 10))
    inventory:addItem(MockItem("shield", 8))
    
    local json = inventory:toJSON()
    local data = lunajson.decode(json)
    
    assert(#data == 2, "Should have 2 items")
    assert(data[1].name == "sword", "First item should be sword")
end
```

---

## Troubleshooting

### Problem: "module not found"

**Cause**: Incorrect package path

**Solution**:

```lua
-- Add correct path before require
local testDir = debug.getinfo(1).source:match("@?(.*/)")
package.path = testDir .. "?.lua;" 
             .. testDir .. "../../pz_lua_commons/common/media/lua/shared/?.lua;"
             .. package.path

local pz_commons = require("pz_lua_commons/shared")
```

### Problem: Tests pass locally but fail in PZ

**Cause**: Using non-stub APIs or Kahlua2-incompatible features

**Solution**:

1. Check `TEST_ARCHITECTURE.md` for stub contract rules
2. Verify method exists in actual PZ stub documentation
3. Avoid:
   - `io` library (file operations)
   - `debug` library
   - `os` library
   - Luajit-specific features
4. Add test case for the failing pattern

### Problem: Mock behavior differs from PZ

**Cause**: Mock doesn't match actual stub implementation

**Solution**:

1. Update mock_pz.lua to match actual stub
2. Add test case verifying new behavior
3. Document the contract at top of mock:

```lua
-- ArrayList mock
-- Based on: projectzomboid_lua_stub.xml
-- Contract:
--   new() -> ArrayList
--   add(item) -> boolean
--   get(index) -> Object|nil
--   etc.

local ArrayList = {}
```

### Problem: Kahlua2 doesn't support feature

**Cause**: Using Lua feature not available in Kahlua2

**Examples**:

- ✗ `io.open()` - Kahlua2 blocks I/O
- ✗ `os.exit()` - Not available
- ✗ `debug.getlocal()` - No debug library
- ✓ `table.insert()` - Standard library OK
- ✓ `string.sub()` - String library OK
- ✓ `math.sqrt()` - Math library OK

**Solution**: Use only stdlib that Kahlua2 provides

---

## Summary

### Quick Implementation Checklist

- [ ] Create `mock_pz.lua` with stub implementations
- [ ] Create `test_framework.lua` with assertion helpers
- [ ] Create `test_*.lua` files with organized tests
- [ ] Implement `TestRunner.register()` to add tests
- [ ] Use `TestRunner.run()` to execute all tests
- [ ] Run: `cd TEST_SUITE/tests && lua test_common_lib.lua`
- [ ] Verify: All tests pass (0 failures)
- [ ] Add more tests as you add features

### Key Principles

1. **Mock Only What's Needed**: Minimal implementations save maintenance
2. **Match Stub Contracts**: Your mocks must follow real API signatures
3. **Test Real Libraries**: Load actual pz_lua_commons, not copies
4. **No Invented APIs**: Only use stubs and Lua standard library
5. **Clear Test Names**: `{Category}: {Feature} {Behavior}`
6. **One Focus Per Test**: Each test validates one thing
7. **Consistent Organization**: Group tests by category
8. **Good Error Messages**: Describe what should happen

### Next Steps

1. Copy `TEST_SUITE/tests/mock_pz.lua` as base
2. Adapt mocks for your specific mod APIs
3. Create test file following patterns shown
4. Add tests incrementally as you develop
5. Run before committing code
6. Update mocks when PZ stub changes

