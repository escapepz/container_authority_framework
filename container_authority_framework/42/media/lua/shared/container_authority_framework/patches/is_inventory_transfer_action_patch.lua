local patches = {}

function patches.clientSidePatch()
    ---@type ContainerAuthority
    local CAF = _G.ContainerAuthorityFramework

    ---@class ISInventoryTransferAction
    ---@field caf_ctx ContainerAuthorityContext the CAF cached context

    local original_ISInventoryTransferAction_isValid = ISInventoryTransferAction.isValid
    function ISInventoryTransferAction:isValid()
        ---@cast self ISInventoryTransferAction

        -- 1. Framework Guard
        if not CAF then
            return original_ISInventoryTransferAction_isValid(self)
        end

        -- 2. Cached Rejection Guard (Level 1)
        -- If context exists and is already rejected, fast-fail immediately
        if self.caf_ctx and self.caf_ctx.flags.rejected then
            return false
        end

        -- 3. Cached Success Guard (Level 1)
        -- If context exists and is NOT rejected, run vanilla immediately
        ---@diagnostic disable-next-line: unnecessary-if
        if self.caf_ctx then
            return original_ISInventoryTransferAction_isValid(self)
        end

        -- 4. Context Creation & Validation (First-time run only)
        self.caf_ctx = CAF:createContext(
            "Transfer",
            self,
            self.item,
            self.character,
            self.srcContainer,
            self.destContainer,
            nil
        )
        CAF:processAction("validate", self.caf_ctx)

        -- 5. Final Rejection Check
        if self.caf_ctx.flags.rejected then
            return false
        end

        return original_ISInventoryTransferAction_isValid(self)
    end

    local original_ISInventoryTransferAction_transferItem = ISInventoryTransferAction.transferItem
    ---@param item InventoryItem
    function ISInventoryTransferAction:transferItem(item)
        ---@cast self ISInventoryTransferAction

        -- 1. Framework Guard
        if not CAF then
            return original_ISInventoryTransferAction_transferItem(self, item)
        end

        -- 2. Context Preparation
        -- Re-use cached context if available, otherwise create new
        local ctx = self.caf_ctx
            or CAF:createContext(
                "Transfer",
                self,
                item,
                self.character,
                self.srcContainer,
                self.destContainer,
                nil
            )
        self.caf_ctx = ctx -- Cache it for consistency

        -- 3. Pre-Action Phase & Rejection Guard
        CAF:processAction("pre", ctx)

        if ctx.flags.rejected then
            ---@diagnostic disable-next-line: unnecessary-if
            -- Stop the action if the internal Java action exists
            -- if self.started then
            self:stop()
            -- end
            return
        end

        -- 4. Vanilla Execution
        local result = original_ISInventoryTransferAction_transferItem(self, item)

        -- 5. Post-Action Phase (Side-effects)
        -- Fire only if the vanilla transfer actually succeeded
        -- original_ISInventoryTransferAction_transferItem have no return
        -- if result ~= false then
        CAF:processAction("post", ctx)
        -- end

        return result
    end
end

return patches
