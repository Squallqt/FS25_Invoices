-- Copyright © 2026 Squallqt. All rights reserved.
-- Mode-scoped wizard state managing multi-step invoice drafts: recipient, work type, fields, and line items.
InvoicesWizardState = {}

-- Wizard modes. "create": the player issues a normal invoice (player = sender).
-- "proposal": the player proposes an invoice they will pay (player = recipient), to be
-- validated by the selected farm (= sender/issuer). In both modes recipientFarmId stores
-- the farm selected in the list; roles are resolved at createInvoice time.
InvoicesWizardState.MODE_CREATE = "create"
InvoicesWizardState.MODE_PROPOSAL = "proposal"

InvoicesWizardState.instances = {}
InvoicesWizardState.activeMode = InvoicesWizardState.MODE_CREATE

---Normalizes unknown modes to the default invoice creation draft.
-- @param string? mode Requested wizard mode
-- @return string mode Normalized wizard mode
function InvoicesWizardState.normalizeMode(mode)
    if mode == InvoicesWizardState.MODE_PROPOSAL then
        return InvoicesWizardState.MODE_PROPOSAL
    end
    return InvoicesWizardState.MODE_CREATE
end

---Returns or creates the wizard state for the active/requested mode.
-- @param string? mode Optional mode to activate before returning the draft
-- @return InvoicesWizardState instance
function InvoicesWizardState.getInstance(mode)
    mode = InvoicesWizardState.normalizeMode(mode or InvoicesWizardState.activeMode)
    InvoicesWizardState.activeMode = mode

    if InvoicesWizardState.instances[mode] == nil then
        InvoicesWizardState.instances[mode] = InvoicesWizardState.new(mode)
    end

    return InvoicesWizardState.instances[mode]
end

---Clears all preserved drafts.
function InvoicesWizardState.resetAll()
    InvoicesWizardState.instances = {}
    InvoicesWizardState.activeMode = InvoicesWizardState.MODE_CREATE
end

---Creates a new wizard state instance
-- @param string? mode Wizard mode for this draft
-- @return InvoicesWizardState instance
function InvoicesWizardState.new(mode)
    local self = {}
    setmetatable(self, {__index = InvoicesWizardState})
    self.mode = InvoicesWizardState.normalizeMode(mode)
    
    self:reset()
    
    return self
end

---Resets wizard state to initial values
function InvoicesWizardState:reset()
    self.recipientFarmId = nil
    self.recipientFarmName = nil
    self.selectedWorkTypes = {}
    self.selectedFields = {}
    self.lineItems = {}
    self.mode = InvoicesWizardState.normalizeMode(self.mode)
end

---Returns whether the wizard is in proposal mode
-- @return boolean isProposal
function InvoicesWizardState:isProposalMode()
    return self.mode == InvoicesWizardState.MODE_PROPOSAL
end

---Sets the invoice recipient farm
-- @param integer farmId Recipient farm identifier
-- @param string farmName Recipient farm name
function InvoicesWizardState:setRecipient(farmId, farmName)
    self.recipientFarmId = farmId
    self.recipientFarmName = farmName
end

---Builds line items from selected work types and fields
function InvoicesWizardState:buildAllLineItems()
    local manager = g_currentMission.invoicesManager

    self.lineItems = {}

    if manager == nil then
        return
    end

    local workTypes = self.selectedWorkTypes or {}
    local fields = self.selectedFields or {}

    for i, workType in ipairs(workTypes) do
        local adjustedPrice = workType.customPrice ~= nil and workType.customPrice or manager:getAdjustedPrice(workType.id)
        local unit = workType.unit
        local customLabel = workType.customLabel
        local displayName
        if customLabel ~= nil and customLabel ~= "" then
            displayName = customLabel
        else
            displayName = workType.displayOverride or g_i18n:getText(workType.nameKey)
        end
        local unitKey = manager:getUnitKey(unit)
        local unitStr = g_i18n:getText(unitKey)
        local vatRate = 0
        if manager.service:isVatEnabled() then
            if workType.customVatRate ~= nil then
                vatRate = workType.customVatRate
            else
                vatRate = manager.service:getVatRateForWorkType(workType.id)
            end
        end

        -- Per-line commercial discount (0..1). Defaults to 0 when not set by the user.
        local discountRate = Invoice.sanitizeDiscountRate(workType.customDiscountRate)

        if unit == Invoice.UNIT_HECTARE then
            local excluded = workType.excludedFields or {}
            for _, field in ipairs(fields) do
                local isExcluded = false
                for _, exId in ipairs(excluded) do
                    if exId == field.id then
                        isExcluded = true
                        break
                    end
                end
                if not isExcluded then
                    local roundedArea = MathUtil.round(field.area, 2)
                    local amount = Invoice.computeLineAmount(adjustedPrice, roundedArea, unit, discountRate)

                    -- Per-field label takes priority so each field row can be renamed independently
                    local fieldLabel = workType.customLabelByField and workType.customLabelByField[field.id]
                    local lineName = (fieldLabel ~= nil and fieldLabel ~= "") and fieldLabel or displayName

                    table.insert(self.lineItems, {
                        workTypeId = workType.id,
                        sourceIndex = i,
                        name = lineName,
                        quantity = roundedArea,
                        price = adjustedPrice,
                        unit = unit,
                        fieldId = field.id,
                        fieldArea = roundedArea,
                        amount = amount,
                        note = "",
                        vatRate = vatRate,
                        discountRate = discountRate,
                        iconFilename = workType.iconFilename
                    })
                end
            end
        else
            local defaultQty = (unit == Invoice.UNIT_LITER) and 1000 or 1
            local customQty = workType.customQuantity ~= nil and workType.customQuantity or defaultQty
            local amount = Invoice.computeLineAmount(adjustedPrice, customQty, unit, discountRate)

            table.insert(self.lineItems, {
                workTypeId = workType.id,
                sourceIndex = i,
                name = displayName,
                quantity = customQty,
                price = adjustedPrice,
                unit = unit,
                fieldId = nil,
                fieldArea = 0,
                amount = amount,
                note = "",
                vatRate = vatRate,
                discountRate = discountRate,
                iconFilename = workType.iconFilename,
                vehicleUniqueId = workType.vehicleUniqueId,
                isConsumable = workType.isConsumable,
                groupKey = workType.groupKey,
                consumableXmlFilename = workType.consumableXmlFilename,
                consumableFillTypeIndex = workType.consumableFillTypeIndex,
                consumableFillLevel = workType.consumableFillLevel
            })
        end
    end
end

---Checks if invoice creation is allowed
-- @return boolean canCreate True if recipient is set and items exist
function InvoicesWizardState:canCreateInvoice()
    return self.recipientFarmId ~= nil and #self.lineItems > 0
end

---Creates and sends invoice from wizard state
-- @return Invoice|nil invoice Created invoice or nil on failure
function InvoicesWizardState:createInvoice()
    if not self:canCreateInvoice() then
        return nil
    end

    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return nil
    end

    local playerFarmId = 0
    if g_currentMission.getFarmId ~= nil then
        playerFarmId = g_currentMission:getFarmId()
    else
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm then
            playerFarmId = farm.farmId
        end
    end

    -- Resolve invoice roles from the wizard mode.
    -- create:   player issues the invoice -> sender = player,        recipient = selected farm
    -- proposal: player proposes to pay    -> sender = selected farm, recipient = player
    local isProposal = self:isProposalMode()
    local invSenderFarmId, invRecipientFarmId
    if isProposal then
        invSenderFarmId    = self.recipientFarmId
        invRecipientFarmId = playerFarmId
    else
        invSenderFarmId    = playerFarmId
        invRecipientFarmId = self.recipientFarmId
    end

    -- Payment always flows recipient -> sender; the two must differ.
    if invSenderFarmId == nil or invRecipientFarmId == nil or invSenderFarmId == invRecipientFarmId then
        return nil
    end

    local items = {}
    for _, item in ipairs(self.lineItems) do
        table.insert(items, {
                workTypeId = item.workTypeId or 0,
                amount = item.amount or 0,
                quantity = item.quantity or 0,
                unitType = item.unit or Invoice.UNIT_PIECE,
                fieldArea = item.fieldArea or 0,
                fieldId = item.fieldId or 0,
                note = item.note or "",
                vatRate = item.vatRate or 0,
                discountRate = item.discountRate or 0,
                name = item.name or "",
                iconFilename = item.iconFilename or "",
                price = item.price or 0,
                vehicleUniqueId = item.vehicleUniqueId or "",
                consumableXmlFilename = item.consumableXmlFilename or "",
                consumableFillTypeIndex = item.consumableFillTypeIndex or 0,
                consumableFillLevel = item.consumableFillLevel or 0
            })
    end

    if #items == 0 then
        return nil
    end

    local invoice = Invoice.new()
    invoice:populateFromData(0, items, invRecipientFarmId, invSenderFarmId)
    if isProposal then
        invoice.state = Invoice.STATE.PROPOSED
    end

    manager:createAndSendInvoice(invoice)

    self:reset()

    return invoice
end
