-- Container Authority Framework (CAF) Shared Initialization
local caf = require("caf/container_authority")()
require("caf/is_transfer_action_patch")()

return caf
