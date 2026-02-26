local CAF = require("container_authority_framework/container_authority")()
local ZUL = require("zul")
local logger = ZUL.new("container_authority_framework")

local isServer, isMultiplayer = isServer, isMultiplayer

-- Detour ISTransferAction:transferItem
local original_ISTransferAction_transferItem = ISTransferAction.transferItem

-- Override transferItem to validate shop ownership BEFORE transfer
---@param character IsoPlayer
---@param item InventoryItem
---@param srcContainer ItemContainer
---@param destContainer ItemContainer
---@param dropSquare IsoGridSquare?
---@return InventoryItem
function ISTransferAction:transferItem(character, item, srcContainer, destContainer, dropSquare)
	---@diagnostic disable-next-line: unnecessary-if
	-- Handle authoritative environments: Server (MP) or Local (SP)
	if CAF and (isServer() or not isMultiplayer()) then
		return CAF:processTransfer(
			character,
			item,
			srcContainer,
			destContainer,
			original_ISTransferAction_transferItem,
			dropSquare
		)
	end

	-- Client (MP) - just pass through, server will handle validation
	return original_ISTransferAction_transferItem(self, character, item, srcContainer, destContainer, dropSquare)
end

return function()
	logger:info("ISTransferAction:transferItem patched successfully.")
end
