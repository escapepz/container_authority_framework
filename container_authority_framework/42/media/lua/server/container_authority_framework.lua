-- Container Authority Framework (CAF) Server Initialization
local caf = require("container_authority_framework/container_authority")()

-- Shared Patches (Loaded in all environments)
local shared_patches = require("container_authority_framework/patches/server_patches_init")
shared_patches()

return caf
