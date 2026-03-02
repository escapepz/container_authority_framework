local patches = {}

function patches.serverSidePatch()
    ---@type ContainerAuthority
    local CAF = _G.ContainerAuthorityFramework

    ---@class ISInventoryTransferAction
    ---@field caf_ctx ContainerAuthorityContext the CAF cached context

    -- [Performance Intel]
    -- ISDismantleAction:getDuration() is called many times (not just one time).
    -- We can return 1 here if the manipulation is rejected by MAF, allowing the
    -- action to quickly "complete" and be stopped by the server-side validator.
    -- The actual dismantle prevention is handled in :complete().
    -- Should be lightweight
    -- Should return only number
    local original_ISInventoryTransferAction_isValid = ISInventoryTransferAction.isValid
    function ISInventoryTransferAction:isValid()
        ---@diagnostic disable-next-line: unnecessary-if
        ---@cast self ISInventoryTransferAction
        if self.caf_ctx then
            if self.caf_ctx.flags.rejected then
                return false
            end
            ---@diagnostic disable-next-line: unnecessary-if
            if original_ISInventoryTransferAction_isValid then
                return original_ISInventoryTransferAction_isValid(self)
            end
            -- reject if original function not found or no hook ?
            return false
        end

        ---@diagnostic disable-next-line: unnecessary-if
        if CAF then
            local ctx = CAF:createContext(
                "Transfer",
                self,
                self.item,
                self.character,
                self.srcContainer,
                self.destContainer,
                nil
            )
            CAF:processAction("validate", ctx)
            self.caf_ctx = ctx

            if ctx.flags.rejected then
                return false
            end
        end

        ---@diagnostic disable-next-line: unnecessary-if
        if original_ISInventoryTransferAction_isValid then
            return original_ISInventoryTransferAction_isValid(self)
        end
        -- reject if original function not found or no hook ?
        return false
    end

    local original_ISInventoryTransferAction_complete = ISInventoryTransferAction.complete
    function ISInventoryTransferAction:complete()
        ---@diagnostic disable-next-line: unnecessary-if
        ---@cast self ISInventoryTransferAction
        if CAF then
            -- Re-use cached context if available, otherwise create new
            local ctx = self.caf_ctx
                or CAF:createContext(
                    "Transfer",
                    self,
                    self.item,
                    self.character,
                    self.srcContainer,
                    self.destContainer,
                    nil
                )

            -- Fire Pre-Action phase
            CAF:processAction("pre", ctx)

            if ctx.flags.rejected then
                ---@diagnostic disable-next-line: unnecessary-if
                if self.started then
                    self:stop()
                end
                return false
            end

            -- Run Vanilla Logic
            -- reject if original function not found or no hook ?
            local result = false
            ---@diagnostic disable-next-line: unnecessary-if
            if original_ISInventoryTransferAction_complete then
                result = original_ISInventoryTransferAction_complete(self)
            end

            -- Fire Post-Action phase (Side-effects)
            if result ~= false then
                ctx.result = result
                -- Only fires if vanilla logic didn't return false (unlikely in this class but safe)
                CAF:processAction("post", ctx)
            end

            return result
        end

        ---@diagnostic disable-next-line: unnecessary-if
        if original_ISInventoryTransferAction_complete then
            return original_ISInventoryTransferAction_complete(self)
        end
        -- reject if original function not found or no hook ?
        return false
    end
end

return patches
