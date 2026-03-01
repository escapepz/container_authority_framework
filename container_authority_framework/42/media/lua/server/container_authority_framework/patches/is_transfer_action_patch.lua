local patches = {}

function patches.serverSidePatch()
    local CAF = _G.ContainerAuthorityFramework

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
        -- ISInventoryTransferAction:new()
        -- function ISInventoryTransferAction:transferItem(item) calls ISTransferAction:transferItem already have guard isClient()
        if CAF then
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
        return original_ISTransferAction_transferItem(
            self,
            character,
            item,
            srcContainer,
            destContainer,
            dropSquare
        )
    end
end

return patches
