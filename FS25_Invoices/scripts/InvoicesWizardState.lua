--[[
    InvoicesWizardState.lua
    Singleton wizard state managing multi-step invoice drafting: recipient, work type, fields, and line items.
    Author: Squallqt
]]

InvoicesWizardState = {}
InvoicesWizardState.instance = nil

function InvoicesWizardState.getInstance()
    if InvoicesWizardState.instance == nil then
        InvoicesWizardState.instance = InvoicesWizardState.new()
    end
    return InvoicesWizardState.instance
end

function InvoicesWizardState.new()
    local self = {}
    setmetatable(self, {__index = InvoicesWizardState})
    
    self:reset()
    
    return self
end

function InvoicesWizardState:reset()
    self.recipientFarmId = nil
    self.recipientFarmName = nil
    
    self.selectedWorkType = nil
    self.selectedWorkTypes = {}
    
    self.selectedFields = {}
    
    self.currentFieldId = nil
    self.currentFieldArea = nil
    self.currentQuantity = 1
    self.currentPrice = 0
    self.currentNote = ""
    
    self.lineItems = {}
    
    Logging.devInfo("[InvoicesWizardState] State reset")
end

function InvoicesWizardState:setRecipient(farmId, farmName)
    self.recipientFarmId = farmId
    self.recipientFarmName = farmName
    Logging.devInfo("[InvoicesWizardState] Recipient set: %s (id=%d)", farmName, farmId)
end

function InvoicesWizardState:buildAllLineItems()
    local manager = g_currentMission.invoicesManager

    self.lineItems = {}

    if manager == nil then
        return
    end

    local workTypes = self.selectedWorkTypes or {}
    local fields = self.selectedFields or {}

    for i, workType in ipairs(workTypes) do
        local adjustedPrice = workType.customPrice or manager:getAdjustedPrice(workType.id)
        local unit = workType.unit
        local displayName = workType.displayOverride or g_i18n:getText(workType.nameKey)
        local unitKey = manager:getUnitKey(unit)
        local unitStr = g_i18n:getText(unitKey)
        local vatRate = 0
        if manager.service:isVatEnabled() then
            vatRate = manager.service:getVatRateForWorkType(workType.id)
        end

        if unit == Invoice.UNIT_HECTARE then
            for _, field in ipairs(fields) do
                local roundedArea = MathUtil.round(field.area, 2)
                local amount = MathUtil.round(adjustedPrice * roundedArea)

                table.insert(self.lineItems, {
                    workTypeId = workType.id,
                    sourceIndex = i,
                    name = displayName,
                    quantity = roundedArea,
                    price = adjustedPrice,
                    unit = unit,
                    fieldId = field.id,
                    fieldArea = roundedArea,
                    amount = amount,
                    note = "",
                    vatRate = vatRate,
                    iconFilename = workType.iconFilename
                })
            end
        else
            local defaultQty = (unit == Invoice.UNIT_LITER) and 1000 or 1
            local customQty = workType.customQuantity or defaultQty
            local amount
            if unit == Invoice.UNIT_LITER then
                amount = MathUtil.round(adjustedPrice * customQty / 1000)
            else
                amount = MathUtil.round(adjustedPrice * customQty)
            end

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
                iconFilename = workType.iconFilename
            })
        end
    end

    Logging.devInfo("[InvoicesWizardState] Built %d line items, total: %.2f", #self.lineItems, self:getTotal())
end

function InvoicesWizardState:getTotal()
    local total = 0
    for _, item in ipairs(self.lineItems) do
        total = total + (item.amount or 0)
    end
    return total
end

function InvoicesWizardState:canCreateInvoice()
    return self.recipientFarmId ~= nil and #self.lineItems > 0
end

function InvoicesWizardState:createInvoice()
    if not self:canCreateInvoice() then
        return nil
    end

    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return nil
    end

    local senderFarmId = 0
    if g_currentMission.getFarmId ~= nil then
        senderFarmId = g_currentMission:getFarmId()
    else
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm then
            senderFarmId = farm.farmId
        end
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
            name = item.name or "",
            iconFilename = item.iconFilename or "",
            price = item.price or 0
        })
    end

    local invoice = Invoice.new()
    invoice:populateFromData(0, items, self.recipientFarmId, senderFarmId)

    manager:createAndSendInvoice(invoice)

    Logging.devInfo("[InvoicesWizardState] Invoice created and sent to farm %d", self.recipientFarmId)

    self:reset()

    return invoice
end
