-- Container Authority Framework (CAF) Shared Initialization
local caf = require("container_authority_framework/container_authority")()
require("container_authority_framework/is_transfer_action_patch")()

return caf
