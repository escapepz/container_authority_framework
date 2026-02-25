# Container Authority Framework

A modding framework for Project Zomboid that intercepts and controls item transfers between containers through a flexible three-phase event pipeline.

## Overview

Container Authority Framework (CAF) provides API hooks to validate, audit, and react to container interactions. It enables complex storage systems without modifying the game's core container logic.

**Core Use Cases:**

- Rank-locked armories (faction-based access control)
- One-way donation boxes (deposit-only containers)
- Daily withdrawal caps on shared supplies
- Theft detection and alerting systems
- Realism penalties (cold hands, clumsiness, stress)
- Economy systems with custom transfer rules

## How It Works

CAF intercepts item transfers through a three-phase pipeline:

### 1. Validation Phase

- Triggered **before** the transfer occurs
- Allows rules to **block** unauthorized transfers
- Use case: permission checks, rank requirements, weight limits

### 2. Pre-Transfer Phase

- Triggered **after validation**, **before** execution
- Allows rules to audit or modify the context
- Use case: deducting currency, logging intent, applying penalties

### 3. Post-Transfer Phase

- Triggered **after** the transfer completes
- Allows rules to react with side effects
- Use case: applying stress, attracting zombies, updating metadata

## Installation

**Requirements:**

- Project Zomboid Build 42.13.1+
- `zul` mod - [Zomboid Unified Logging](https://steamcommunity.com/sharedfiles/filedetails/?id=3653948326)
- `pz_lua_commons` mod - [PZ Lua Commons](https://steamcommunity.com/sharedfiles/filedetails/?id=3672788969)

**Add to `mod.info`**

```
require=\container_authority_framework
```

## Usage for Modders

### Registering a Rule

```lua
local caf = require("container_authority_framework")

-- Validation rule (blocking)
caf:registerRule("validation", "my_mod_rank_check", function(ctx)
    local player = ctx.character
    local requiredRank = 5

    if player:getAdmin() == false and getPlayerRank(player) < requiredRank then
        ctx.flags.rejected = true
        ctx.flags.reason = "Insufficient rank"
    end
end, 10) -- priority 10

-- Pre-Transfer rule (logging)
caf:registerRule("pre", "my_mod_audit_log", function(ctx)
    print("Player " .. ctx.character:getUsername() .. " transferring " .. ctx.item:getType())
end, 20)

-- Post-Transfer rule (side effects)
caf:registerRule("post", "my_mod_stress_penalty", function(ctx)
    if ctx.result then
        ctx.character:getStats():setStress(ctx.character:getStats():getStress() + 10)
    end
end, 30)
```

### Context Object

All callbacks receive a context table with:

```lua
ctx = {
    character = IsoPlayer,      -- The player performing the transfer
    item = InventoryItem,       -- The item being transferred
    src = ItemContainer,        -- Source container
    dest = ItemContainer,       -- Destination container
    dropSquare = IsoGridSquare, -- Optional drop location
    result = any,               -- Post-transfer only: transfer result

    flags = {
        rejected = boolean,     -- Set to true to block transfer
        reason = string,        -- Rejection reason (for logging)
        adminOverride = boolean -- Admin bypass flag
    },

    metadata = {}               -- Custom data passed between phases
}
```

### Priority System

Lower priority values execute first. Use this to control rule order:

- Validation rules: 0-50 (permission checks first)
- Pre-Transfer rules: 50-100 (logging/auditing)
- Post-Transfer rules: 100+ (side effects last)

## Configuration

Server admins can configure listener limits via sandbox options:

- `ValidationEventListenersMax` (default: 25)
- `PreTransferEventListenersMax` (default: 50)
- `PostTransferEventListenersMax` (default: 100)

These limits prevent performance degradation if too many rules are registered.

## Example Mods Built with CAF

- **JASM**: Just Another Shop Mod

## Architecture

- **Event-driven**: Rules register as listeners to three distinct events
- **Reusable context**: Single reusable context object to minimize GC pressure
- **Recursion guard**: Prevents infinite loops from nested transfer calls
- **Error handling**: Critical errors logged without crashing the server
- **Sandbox integration**: Admin-configurable limits per event phase

## Performance

- Context object reused across transfers (minimal allocations)
- Direct EventManager integration (no closure overhead)
- Configurable listener limits prevent bottlenecks
- Efficient flag/metadata clearing between transfers

## License

See LICENSE file for details.

## Author

escapepz
