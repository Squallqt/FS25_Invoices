-- Copyright © 2026 Squallqt. All rights reserved.
---Dialog for displaying invoice details and actions
InvoicesDetailDialog = {}
local InvoicesDetailDialog_mt = Class(InvoicesDetailDialog, MessageDialog)

InvoicesDetailDialog.CONTROLS = {
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP = "titleSep",
    TEXT_TITLE = "textTitle",
    TEXT_STATUS = "textStatus",
    TEXT_FROM = "textFrom",
    TEXT_TO = "textTo",
    TEXT_DATE = "textDate",
    LIST_ITEMS = "listItems",
    SLIDER_BOX = "sliderBox",
    TEXT_NOTES = "textNotes",
    TEXT_TOTAL_LABEL = "textTotalLabel",
    TEXT_TOTAL = "textTotal",
    TOTAL_RIGHT_COLUMN = "totalRightColumn",
    TEXT_VAT_HT  = "textVatHt",
    TEXT_DISCOUNT = "textDiscount",
    TEXT_VAT = "textVat",
    TOTAL_SEP    = "totalSep",
    PENALTY_BAR  = "penaltyBar",
    TEXT_PENALTY_BAR = "textPenaltyBar",
    BTN_PAY = "btnPay",
    BTN_VALIDATE = "btnValidate",
    SEP_VALIDATE_REFUSE = "sepValidateRefuse",
    BTN_REFUSE = "btnRefuse",
    SEP_CLOSE = "sepClose",
    BUTTON_BOX = "buttonBox",
}

InvoicesDetailDialog.PENALTY_BAR_OFFSET = 28

InvoicesDetailDialog.COLOR_UNPAID  = {1.00, 0.66, 0.00, 1}
InvoicesDetailDialog.COLOR_PAID    = {0.40, 0.85, 0.40, 1}
InvoicesDetailDialog.COLOR_OVERDUE = {1.00, 0.30, 0.30, 1}
InvoicesDetailDialog.COLOR_PENALTY = {1.00, 0.40, 0.35, 1}
InvoicesDetailDialog.COLOR_PROPOSED = {0.45, 0.70, 1.00, 1}

InvoicesDetailDialog.SECONDARY_CANCEL = 1
InvoicesDetailDialog.SECONDARY_REFUSE = 2

---Creates new invoice detail dialog instance
-- @param table target Parent target element
-- @param table? customMt Optional custom metatable
-- @return InvoicesDetailDialog New dialog instance
function InvoicesDetailDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or InvoicesDetailDialog_mt)
    return self
end

---Loads dialog controls
function InvoicesDetailDialog:onLoad()
    InvoicesDetailDialog:superClass().onLoad(self)
    self:registerControls(InvoicesDetailDialog.CONTROLS)
end

---Finalizes GUI setup
function InvoicesDetailDialog:onGuiSetupFinished()
    InvoicesDetailDialog:superClass().onGuiSetupFinished(self)

    if self.listItems ~= nil then
        self.listItems:setDataSource(self)
        self.listItems:setDelegate(self)
    end
end

---Resizes title separator to match title text width
function InvoicesDetailDialog:resizeTitleSep()
    InvoicesGuiUtils.resizeTitleSeparator(self.mainTitleText, self.titleSep)
end

---Resizes penalty bar to fit penalty text
-- @param string penaltyText Formatted penalty text
function InvoicesDetailDialog:resizePenaltyBar(penaltyText)
    if self.penaltyBar == nil or self.textPenaltyBar == nil then return end
    if self.penaltyBar.parent == nil then return end

    if self._penaltyBarHeight == nil then
        self._penaltyBarHeight = self.penaltyBar.absSize[2]
    end
    if self._penaltyTextHeight == nil then
        self._penaltyTextHeight = self.textPenaltyBar.absSize[2]
    end

    local rowWidth = self.penaltyBar.parent.absSize[1]
    local textWidth = getTextWidth(self.textPenaltyBar.textSize, penaltyText or "")
    local horizontalPadding = 20 * g_pixelSizeScaledX
    local newWidth = math.min(rowWidth, textWidth + horizontalPadding)
    local offsetX = rowWidth - newWidth

    self.penaltyBar:setSize(newWidth, self._penaltyBarHeight)
    self.textPenaltyBar:setSize(newWidth, self._penaltyTextHeight)
    self.penaltyBar:setPosition(offsetX, 0)
    self.textPenaltyBar:setPosition(offsetX, 0)

    if self.penaltyBar.parent.invalidateLayout ~= nil then
        self.penaltyBar.parent:invalidateLayout()
    end
end

---Resizes total separator to fit VAT and total amounts
-- @param string htText Formatted HT amount text
-- @param string vatText Formatted VAT amount text
-- @param string totalText Formatted total amount text
function InvoicesDetailDialog:resizeTotalSep(htText, vatText, totalText)
    self._sepOrigX, self._sepOrigW = InvoicesGuiUtils.resizeTotalSeparator(
        self.totalSep,
        self.textVatHt,
        self.textVat,
        self.textTotal,
        htText,
        vatText,
        totalText,
        self._sepOrigX,
        self._sepOrigW
    )
end

---Shows or hides the discount line in the total breakdown
-- The BoxLayout reflows so the Discount line never leaves a gap when hidden.
-- @param number discountAmount Total discount in currency (>= 0); the line shows only when > 0
function InvoicesDetailDialog:layoutTotalBreakdown(discountAmount)
    InvoicesGuiUtils.layoutTotalBreakdown(
        self.totalRightColumn,
        self.textVatHt,
        self.textVat,
        self.textDiscount,
        discountAmount,
        {0.5, 0.5, 0.5, 1}
    )
end

---Called when dialog opens, resets invoice state
function InvoicesDetailDialog:onOpen()
    InvoicesDetailDialog:superClass().onOpen(self)
    self.invoice = nil
    self.items = {}
    self.displayItems = {}
    self.pendingSecondaryAction = nil
    self:resizeTitleSep()
end

---Sets invoice data and populates all display fields
-- @param table invoice Invoice to display
-- @param boolean isIncoming True if invoice is incoming
function InvoicesDetailDialog:setInvoice(invoice, isIncoming)
    self.invoice = invoice
    self.isIncoming = isIncoming or false
    self.items = invoice and invoice.lineItems or {}
    self:buildDisplayItems()

    if invoice then
        local invNumber = string.format(g_i18n:getText("invoice_format_inv_number"), invoice.id)
        if self.textTitle then
            self.textTitle:setText(invNumber)
        end

        local isProposed = (invoice.state == Invoice.STATE.PROPOSED)
        local isPaid = (invoice.state == Invoice.STATE.PAID)
        local penaltyAmount = invoice.penaltyAmount or 0
        local isOverdue = (not isPaid and not isProposed and penaltyAmount > 0)
        if self.textStatus then
            local statusText
            local color
            if isProposed then
                statusText = g_i18n:getText("invoice_status_proposed")
                color = InvoicesDetailDialog.COLOR_PROPOSED
            elseif isPaid then
                statusText = g_i18n:getText("invoice_status_paid")
                color = InvoicesDetailDialog.COLOR_PAID
            elseif isOverdue then
                statusText = g_i18n:getText("invoice_status_overdue")
                color = InvoicesDetailDialog.COLOR_OVERDUE
            else
                statusText = g_i18n:getText("invoice_status_unpaid")
                color = InvoicesDetailDialog.COLOR_UNPAID
            end
            self.textStatus:setText(statusText)
            self.textStatus:setTextColor(unpack(color))
        end

        local senderFarm = g_farmManager:getFarmById(invoice.senderFarmId)
        local senderName = senderFarm and senderFarm.name or "—"
        if self.textFrom then
            self.textFrom:setText(g_i18n:getText("invoice_label_from") .. " " .. senderName)
        end

        local recipientFarm = g_farmManager:getFarmById(invoice.recipientFarmId)
        local recipientName = recipientFarm and recipientFarm.name or "—"
        if self.textTo then
            self.textTo:setText(g_i18n:getText("invoice_label_to") .. " " .. recipientName)
        end

        local dateStr = ""
        if invoice.createdAt then
            local yr  = invoice.createdAt.year or 0
            local per = invoice.createdAt.period or 0
            local dy  = invoice.createdAt.day or 0
            local hr  = invoice.createdAt.hour or 0
            local mn  = invoice.createdAt.minute or 0

            if yr > 0 and per > 0 then
                dateStr = string.format(g_i18n:getText("invoice_format_date"), dy, per, yr, hr, mn)
            else
                dateStr = string.format(g_i18n:getText("invoice_format_date_legacy"), dy, hr, mn)
            end
        end
        if self.textDate then
            self.textDate:setText(dateStr)
        end

        local totalDue = (invoice.totalAmount or 0) + penaltyAmount
        local totalText = g_i18n:formatMoney(totalDue, 0, true, false)

        if self.textTotal then
            self.textTotal:setText(totalText)
        end

        if self.textTotalLabel then
            if isPaid then
                self.textTotalLabel:setText(g_i18n:getText("invoice_label_total_paid"))
            else
                self.textTotalLabel:setText(g_i18n:getText("invoice_label_total_due"))
            end
        end

        if self.textVatHt ~= nil and self.textVat ~= nil then
            local vatAmount = invoice.vatAmount or 0
            local discountAmount = Invoice.computeTotalDiscountAmount(invoice.lineItems)

            local htValue, vatValue
            if vatAmount > 0 then
                local totalHT = invoice.totalHT or invoice.totalAmount
                htValue = g_i18n:formatMoney(totalHT, 0, true, false)
                vatValue = g_i18n:formatMoney(vatAmount, 0, true, false)
            else
                htValue = g_i18n:getText("invoice_label_na")
                vatValue = g_i18n:getText("invoice_label_na")
            end
            local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), htValue)
            local vatText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), vatValue)
            self.textVatHt:setText(htText)
            self.textVat:setText(vatText)
            self.textVat:setTextColor(0.5, 0.5, 0.5, 1)
            self.textVatHt:setVisible(true)
            self.textVat:setVisible(true)

            self:layoutTotalBreakdown(discountAmount)

            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, vatText, totalText)
            end
        end

        if self.penaltyBar ~= nil and self.textPenaltyBar ~= nil then
            if penaltyAmount > 0 then
                local effectiveRate = 0
                local totalAmount = invoice.totalAmount or 0
                if totalAmount > 0 then
                    effectiveRate = math.floor(penaltyAmount / totalAmount * 100 + 0.5)
                end
                local penaltyText = string.format("%s : %s (%d%%)",
                    g_i18n:getText("invoice_label_penalty"), g_i18n:formatMoney(penaltyAmount, 0, true, false), effectiveRate)
                self.textPenaltyBar:setText(penaltyText)
                self:resizePenaltyBar(penaltyText)
                self.penaltyBar:setVisible(true)
                self.textPenaltyBar:setVisible(true)
            else
                self.penaltyBar:setVisible(false)
                self.textPenaltyBar:setVisible(false)
            end
        end

        if self.textNotes then
            local notesText = ""
            for i, item in ipairs(self.items) do
                if item.note and item.note ~= "" then
                    notesText = item.note
                    break
                end
            end
            self.textNotes:setText(notesText)
        end
    end

    local isProposalInvoice = (invoice ~= nil and invoice.state == Invoice.STATE.PROPOSED)
    local currentFarmId = self:getCurrentFarmId()
    local viewerIsSender = (invoice ~= nil and currentFarmId == invoice.senderFarmId)
    local viewerIsRecipient = (invoice ~= nil and currentFarmId == invoice.recipientFarmId)
    local secondaryAction, secondaryTextKey = self:getSecondaryActionInfo(currentFarmId)
    local showPay = self.isIncoming and viewerIsRecipient

    if self.btnPay then
        self.btnPay:setVisible(showPay)
        local canPay = showPay and not isProposalInvoice
            and invoice ~= nil and invoice.state == Invoice.STATE.NEW
        self.btnPay:setDisabled(not canPay)
    end

    -- Validate is sender-only; the secondary button is resolved as cancel/refuse below.
    local showValidate = isProposalInvoice and viewerIsSender
    if self.btnValidate then
        self.btnValidate:setVisible(showValidate)
    end
    if self.sepValidateRefuse then
        self.sepValidateRefuse:setVisible(showValidate and secondaryAction ~= nil)
    end
    if self.btnRefuse then
        self.btnRefuse:setVisible(secondaryAction ~= nil)
        if secondaryTextKey ~= nil then
            self.btnRefuse:setText(g_i18n:getText(secondaryTextKey))
        end
    end
    if self.sepClose then
        self.sepClose:setVisible(showPay or showValidate or secondaryAction ~= nil)
    end
    if self.buttonBox ~= nil and self.buttonBox.invalidateLayout ~= nil then
        self.buttonBox:invalidateLayout()
    end

    if self.listItems then
        self.listItems:reloadData()
    end

    self:updateSliderVisibility()
end

---Builds display items, grouping consumables by type
function InvoicesDetailDialog:buildDisplayItems()
    self.displayItems = {}
    local consumableGroups = {}
    local consumableOrder = {}

    for _, item in ipairs(self.items) do
        local xmlFn = item.consumableXmlFilename
        if xmlFn ~= nil and xmlFn ~= "" then
            local gk = xmlFn .. "|" .. tostring(item.consumableFillTypeIndex or 0) .. "|" .. tostring(item.consumableFillLevel or 0)
            if consumableGroups[gk] == nil then
                consumableGroups[gk] = {
                    workTypeId   = item.workTypeId,
                    name         = item.name,
                    iconFilename = item.iconFilename,
                    unitType     = item.unitType,
                    vatRate      = item.vatRate,
                    discountRate = item.discountRate,
                    fieldId      = 0,
                    fieldArea    = 0,
                    quantity     = 0,
                    price        = item.price or 0,
                    amount       = 0,
                    note         = item.note or "",
                    consumableXmlFilename   = item.consumableXmlFilename,
                    consumableFillTypeIndex = item.consumableFillTypeIndex,
                    consumableFillLevel     = item.consumableFillLevel,
                }
                table.insert(consumableOrder, gk)
            end
            local group = consumableGroups[gk]
            group.quantity = group.quantity + 1
            group.amount   = group.amount + (item.amount or 0)
        else
            table.insert(self.displayItems, item)
        end
    end

    for _, gk in ipairs(consumableOrder) do
        local group = consumableGroups[gk]
        -- Keep the base unit price captured at creation (not the discounted amount / qty).
        table.insert(self.displayItems, group)
    end
end

---Shows or hides scroll slider based on item count
function InvoicesDetailDialog:updateSliderVisibility()
    if self.sliderBox and self.listItems then
        local itemCount = #self.displayItems
        local maxVisibleItems = math.floor(284 / 32)
        local needsScroll = itemCount > maxVisibleItems
        self.sliderBox:setVisible(needsScroll)
    end
end

---Returns number of list sections
-- @return integer Number of sections
function InvoicesDetailDialog:getNumberOfSections()
    return 1
end

---Returns number of items in given section
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer Number of display items
function InvoicesDetailDialog:getNumberOfItemsInSection(list, section)
    return #self.displayItems
end

---Populates a list cell with line item data including icon, designation, quantity, unit, VAT and amount
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
-- @param table cell Cell element to populate
function InvoicesDetailDialog:populateCellForItemInSection(list, section, index, cell)
    local item = self.displayItems[index]
    if not item then return end

    local manager = g_currentMission.invoicesManager
    local workType = manager and manager:getWorkTypeById(item.workTypeId)

    local designation
    if item.name ~= nil and item.name ~= "" then
        designation = item.name
    else
        designation = workType and g_i18n:getText(workType.nameKey) or "—"
    end

    -- Icon handling (resolve locally for multiplayer — sender paths may not exist here)
    local resolvedIcon = Invoice.resolveLocalIcon(item)
    local cellIcon = cell:getDescendantByName("cellIcon")
    local hasIcon = resolvedIcon ~= ""
    if cellIcon ~= nil then
        cellIcon:setVisible(false)
    end

    local fieldStr = ""
    if item.fieldId and item.fieldId > 0 then
        fieldStr = string.format(g_i18n:getText("invoice_format_fieldId"), item.fieldId)
    else
        fieldStr = "—"
    end

    local lineValues = InvoicesGuiUtils.formatLineItemValues(item, {
        unitField = "unitType",
        useFieldAreaForHectare = true,
        minPieceQuantity = true,
        rebuildUnitPriceFromAmount = true,
        pieceQuantityFormat = "%d",
        zeroVatText = g_i18n:getText("invoice_label_na"),
        useDefaultMoneyFormat = true
    })

    local cellDesignation = cell:getDescendantByName("cellDesignation")
    if cellDesignation ~= nil then
        if hasIcon and cellIcon ~= nil then
            local baseName = InvoicesGuiUtils.getParenthesizedDisplayName(designation)
            cellIcon:setImageFilename(resolvedIcon)
            cellIcon:setVisible(true)
            designation = InvoicesGuiUtils.getIconPaddedText(baseName, 14 * g_pixelSizeScaledY, false)
        end
        cellDesignation:setText(designation)
    end

    local cellField       = cell:getDescendantByName("cellField")
    local cellQty         = cell:getDescendantByName("cellQty")
    local cellUnit        = cell:getDescendantByName("cellUnit")
    local cellUnitPrice   = cell:getDescendantByName("cellUnitPrice")
    local cellDiscount    = cell:getDescendantByName("cellDiscount")
    local cellVat         = cell:getDescendantByName("cellVat")
    local cellAmount      = cell:getDescendantByName("cellAmount")

    if cellField       then cellField:setText(fieldStr) end
    if cellQty         then cellQty:setText(lineValues.qty) end
    if cellUnit        then cellUnit:setText(lineValues.unit) end
    if cellUnitPrice   then cellUnitPrice:setText(lineValues.unitPrice) end
    if cellDiscount    then cellDiscount:setText(lineValues.discount) end
    if cellVat         then cellVat:setText(lineValues.vat) end
    if cellAmount      then cellAmount:setText(lineValues.amount) end
end

---Called when list selection changes
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
function InvoicesDetailDialog:onListSelectionChanged(list, section, index)
end

---Handles pay button click, validates permissions and balance then shows confirmation
function InvoicesDetailDialog:onClickPay()
    if self.invoice == nil then
        return
    end
    if self.invoice.state == Invoice.STATE.PAID then
        return
    end
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return
    end
    if not manager:getHasFarmManagerPermission() then
        InfoDialog.show(g_i18n:getText("invoice_error_permission_required"))
        return
    end
    local totalDue = self.invoice.totalAmount + (self.invoice.penaltyAmount or 0)
    if not manager:farmHasSufficientBalance(self.invoice.recipientFarmId, totalDue) then
        InfoDialog.show(g_i18n:getText("invoice_error_insufficient_funds"))
        return
    end
    local confirmText = manager.service:buildPaymentConfirmText(self.invoice, g_i18n)

    YesNoDialog.show(self.onPayConfirmed, self, confirmText)
end

---Callback for pay confirmation dialog, executes payment if confirmed
-- @param boolean confirmed True if user confirmed payment
function InvoicesDetailDialog:onPayConfirmed(confirmed)
    if confirmed and self.invoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:payInvoice(self.invoice.id)
            self:close()
        end
    end
end

---Returns the current player's farm ID
-- @return integer Player farm identifier or -1
function InvoicesDetailDialog:getCurrentFarmId()
    if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil then
        return g_localPlayer.farmId
    end
    if g_farmManager ~= nil and g_currentMission ~= nil then
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm ~= nil then
            return farm.farmId
        end
    end
    return -1
end

---Returns the available negative action for the current viewer
-- @param integer? currentFarmId Current viewer farm id
-- @return integer|nil Secondary action identifier or nil
-- @return string|nil Button localization key or nil
-- @return string|nil Confirmation localization key or nil
function InvoicesDetailDialog:getSecondaryActionInfo(currentFarmId)
    if self.invoice == nil then
        return nil, nil, nil
    end

    currentFarmId = currentFarmId or self:getCurrentFarmId()
    if self.invoice.state == Invoice.STATE.PROPOSED then
        if currentFarmId == self.invoice.senderFarmId then
            return InvoicesDetailDialog.SECONDARY_REFUSE, "invoice_btn_refuse", "invoice_confirm_refuse"
        end
        if currentFarmId == self.invoice.recipientFarmId then
            return InvoicesDetailDialog.SECONDARY_CANCEL, "invoice_btn_cancel", "invoice_confirm_cancel_proposal"
        end
    elseif self.invoice.state == Invoice.STATE.NEW and currentFarmId == self.invoice.senderFarmId then
        return InvoicesDetailDialog.SECONDARY_CANCEL, "invoice_btn_cancel", "invoice_confirm_cancel_invoice"
    end

    return nil, nil, nil
end

---Handles validate button click for a proposal (issuer/sender only)
function InvoicesDetailDialog:onClickValidate()
    if self.invoice == nil or self.invoice.state ~= Invoice.STATE.PROPOSED then
        return
    end
    local manager = g_currentMission.invoicesManager
    if manager == nil then return end
    if not manager:getHasFarmManagerPermission() then
        InfoDialog.show(g_i18n:getText("invoice_error_permission_required"))
        return
    end
    -- Authority is enforced server-side; this is the UI guard.
    if self:getCurrentFarmId() ~= self.invoice.senderFarmId then
        return
    end
    YesNoDialog.show(self.onValidateConfirmed, self, g_i18n:getText("invoice_confirm_validate"))
end

---Callback for validate confirmation dialog
-- @param boolean confirmed True if user confirmed validation
function InvoicesDetailDialog:onValidateConfirmed(confirmed)
    if confirmed and self.invoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:validateProposal(self.invoice.id)
            self:close()
        end
    end
end

---Handles the negative action button click (cancel/refuse)
function InvoicesDetailDialog:onClickRefuse()
    local action, _, confirmKey = self:getSecondaryActionInfo()
    if action == nil then
        return
    end
    local manager = g_currentMission.invoicesManager
    if manager == nil then return end
    if not manager:getHasFarmManagerPermission() then
        InfoDialog.show(g_i18n:getText("invoice_error_permission_required"))
        return
    end
    self.pendingSecondaryAction = action
    YesNoDialog.show(self.onSecondaryActionConfirmed, self, g_i18n:getText(confirmKey))
end

---Callback for negative action confirmation dialog
-- @param boolean confirmed True if user confirmed the action
function InvoicesDetailDialog:onSecondaryActionConfirmed(confirmed)
    local action = self.pendingSecondaryAction
    self.pendingSecondaryAction = nil

    if confirmed and self.invoice and action ~= nil then
        local manager = g_currentMission.invoicesManager
        if manager then
            if action == InvoicesDetailDialog.SECONDARY_REFUSE then
                manager:refuseProposal(self.invoice.id)
            else
                manager:deleteInvoice(self.invoice.id)
            end
            self:close()
        end
    end
end

---Closes the detail dialog
function InvoicesDetailDialog:onClickBack()
    self:close()
end
