--[[
    InvoicesWizardStep4.lua
    Author: Squallqt
]]

InvoicesWizardStep4 = {}
local InvoicesWizardStep4_mt = Class(InvoicesWizardStep4, DialogElement)

InvoicesWizardStep4.CONTROLS = {
    TITLE_BADGE_BG = "titleBadgeBg",
    MAIN_TITLE_TEXT = "mainTitleText",
    LIST_ITEMS   = "listItems",
    SLIDER_BOX   = "sliderBox",
    TEXT_FROM    = "textFrom",
    TEXT_TO      = "textTo",
    INPUT_NOTE   = "inputNote",
    INPUT_PRICE  = "inputPrice",
    INPUT_QTY    = "inputQty",
    INPUT_VAT    = "inputVat",
    TEXT_TOTAL   = "textTotal",
    TEXT_VAT_HT  = "textVatHt",
    TEXT_VAT_TVA = "textVatTva",
    TOTAL_SEP    = "totalSep",
    BTN_SEND     = "btnSend",
}

function InvoicesWizardStep4.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesWizardStep4_mt)
    self.lineItems = {}
    self.selectedIndex = -1
    self.suppressEditFieldUpdate = false
    return self
end

function InvoicesWizardStep4:onLoad()
    InvoicesWizardStep4:superClass().onLoad(self)
    self:registerControls(InvoicesWizardStep4.CONTROLS)
end

function InvoicesWizardStep4:onGuiSetupFinished()
    InvoicesWizardStep4:superClass().onGuiSetupFinished(self)
    if self.listItems ~= nil then
        self.listItems:setDataSource(self)
        self.listItems:setDelegate(self)
    end
    self:setupNotePlaceholder()
end

function InvoicesWizardStep4:setupNotePlaceholder()
    if self.inputNote == nil then return end
    self._notePlaceholder = self.inputNote:getDescendantByName("notePlaceholder")
    if self._notePlaceholder == nil then return end

    local placeholder = self._notePlaceholder
    local origSetCaptureInput = self.inputNote.setCaptureInput
    self.inputNote.setCaptureInput = function(inputSelf, isCapturing)
        origSetCaptureInput(inputSelf, isCapturing)
        if isCapturing then
            placeholder:setVisible(false)
        else
            placeholder:setVisible(inputSelf.text == nil or inputSelf.text == "")
        end
    end
end

function InvoicesWizardStep4:resizeTitleBadge()
    if self.mainTitleText ~= nil and self.titleBadgeBg ~= nil then
        local textWidth = getTextWidth(self.mainTitleText.textSize, self.mainTitleText.text)
        local paddingX = self.mainTitleText.textSize * 0.8
        local badgeWidth = textWidth + paddingX * 2
        local badgeHeight = self.titleBadgeBg.absSize[2]
        self.titleBadgeBg:setSize(badgeWidth, badgeHeight)
    end
end

function InvoicesWizardStep4:onOpen()
    InvoicesWizardStep4:superClass().onOpen(self)
    self:resizeTitleBadge()

    local state = InvoicesWizardState.getInstance()
    self.lineItems = state.lineItems or {}
    self.selectedIndex = -1

    self:updateHeader()

    if self.listItems ~= nil then
        self.listItems:reloadData()
    end

    self:updateSliderVisibility()

    if self.inputNote ~= nil then
        self.inputNote:setText("")
    end
    if self._notePlaceholder ~= nil then
        self._notePlaceholder:setVisible(true)
    end

    self:updateEditFields()

    self:updateTotal()
end

function InvoicesWizardStep4:updateHeader()
    local state = InvoicesWizardState.getInstance()

    if self.textFrom ~= nil then
        local senderFarmId = 0
        if g_currentMission.getFarmId ~= nil then
            senderFarmId = g_currentMission:getFarmId()
        else
            local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
            if farm then senderFarmId = farm.farmId end
        end
        local senderFarm = g_farmManager:getFarmById(senderFarmId)
        local senderName = senderFarm and senderFarm.name or "?"
        self.textFrom:setText(string.format(g_i18n:getText("invoice_step4_from"), senderName))
    end

    if self.textTo ~= nil then
        self.textTo:setText(string.format(g_i18n:getText("invoice_step4_to"), state.recipientFarmName or "?"))
    end
end

function InvoicesWizardStep4:getNumberOfSections()
    return 1
end

function InvoicesWizardStep4:getNumberOfItemsInSection(list, section)
    return #self.lineItems
end

function InvoicesWizardStep4:getTitleForSectionHeader(list, section)
    return nil
end

function InvoicesWizardStep4:getSectionHeaderHeight(list, section)
    return 0
end

function InvoicesWizardStep4:populateCellForItemInSection(list, section, index, cell)
    local item = self.lineItems[index]
    if item == nil then return end

    if index == self.selectedIndex then
        self._selectedCell = cell
    end

    local manager = g_currentMission.invoicesManager

    local cellDesignation = cell:getDescendantByName("cellDesignation")
    if cellDesignation ~= nil then
        local workType = manager and manager:getWorkTypeById(item.workTypeId) or nil
        local name = workType and g_i18n:getText(workType.nameKey) or "?"
        cellDesignation:setText(name)
    end

    local cellField = cell:getDescendantByName("cellField")
    if cellField ~= nil then
        if item.fieldId ~= nil then
            local fieldLabel = string.format(g_i18n:getText("invoice_format_fieldId"), item.fieldId)
            cellField:setText(fieldLabel)
        else
            cellField:setText("—")
        end
    end

    local cellQty = cell:getDescendantByName("cellQty")
    if cellQty ~= nil then
        local qtyText
        if item.unit == Invoice.UNIT_HECTARE or item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER then
            qtyText = string.format("%.2f", item.quantity or 0)
        else
            qtyText = string.format("%.0f", item.quantity or 0)
        end
        cellQty:setText(qtyText)
    end

    local cellUnit = cell:getDescendantByName("cellUnit")
    if cellUnit ~= nil then
        local unitKey = manager and manager:getUnitKey(item.unit) or "invoice_invoices_unit_piece"
        local unitStr = g_i18n:getText(unitKey)
        cellUnit:setText(unitStr)
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(item.price or 0, 0, true, false))
    end

    local cellVat = cell:getDescendantByName("cellVat")
    if cellVat ~= nil then
        local vatEnabled = manager ~= nil and manager.service:isVatEnabled()
        if not vatEnabled then
            cellVat:setText("N/A")
        else
            local vatRate = item.vatRate or 0
            if vatRate > 0 then
                cellVat:setText(string.format("%.1f%%", vatRate * 100))
            else
                cellVat:setText("—")
            end
        end
    end

    local cellAmount = cell:getDescendantByName("cellAmount")
    if cellAmount ~= nil then
        cellAmount:setText(g_i18n:formatMoney(item.amount or 0, 0, true, false))
    end
end

function InvoicesWizardStep4:onListSelectionChanged(list, section, index)
    -- Refresh list to reflect any edits from previous selection
    if not self.suppressEditFieldUpdate and self.selectedIndex >= 1 and self.selectedIndex ~= index then
        self:refreshListKeepSelection()
    end
    self.selectedIndex = index
    if not self.suppressEditFieldUpdate then
        self:updateEditFields()
    end
end

function InvoicesWizardStep4:refreshListKeepSelection()
    if self.listItems == nil then return end
    local savedIndex = self.selectedIndex
    self.suppressEditFieldUpdate = true
    self.listItems:reloadData()
    if savedIndex >= 1 and savedIndex <= #self.lineItems then
        self.listItems:setSelectedIndex(savedIndex)
    end
    self.suppressEditFieldUpdate = false
end

function InvoicesWizardStep4:updateSelectedCellValues()
    local cell = self._selectedCell
    if cell == nil then return end
    local item = self.lineItems[self.selectedIndex]
    if item == nil then return end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(item.price or 0, 0, true, false))
    end

    local cellQty = cell:getDescendantByName("cellQty")
    if cellQty ~= nil then
        local qtyText
        if item.unit == Invoice.UNIT_HECTARE or item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER then
            qtyText = string.format("%.2f", item.quantity or 0)
        else
            qtyText = string.format("%.0f", item.quantity or 0)
        end
        cellQty:setText(qtyText)
    end

    local cellAmount = cell:getDescendantByName("cellAmount")
    if cellAmount ~= nil then
        cellAmount:setText(g_i18n:formatMoney(item.amount or 0, 0, true, false))
    end

    local cellVat = cell:getDescendantByName("cellVat")
    if cellVat ~= nil then
        local vatEnabled = g_currentMission.invoicesManager ~= nil and g_currentMission.invoicesManager.service:isVatEnabled()
        if not vatEnabled then
            cellVat:setText("N/A")
        else
            local vatRate = item.vatRate or 0
            if vatRate > 0 then
                cellVat:setText(string.format("%.1f%%", vatRate * 100))
            else
                cellVat:setText("—")
            end
        end
    end
end

function InvoicesWizardStep4:updateEditFields()
    local item = nil
    if self.selectedIndex >= 1 and self.selectedIndex <= #self.lineItems then
        item = self.lineItems[self.selectedIndex]
    end

    if self.inputPrice ~= nil then
        if item ~= nil then
            self.inputPrice:setText(string.format("%.0f", item.price or 0))
            self.inputPrice:setDisabled(false)
        else
            self.inputPrice:setText("")
            self.inputPrice:setDisabled(true)
        end
    end

    if self.inputQty ~= nil then
        if item ~= nil then
            if item.unit == Invoice.UNIT_HECTARE then
                self.inputQty:setText(string.format("%.2f", item.quantity or 0))
                self.inputQty:setDisabled(true)
            elseif item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER then
                self.inputQty:setText(string.format("%.2f", item.quantity or 0))
                self.inputQty:setDisabled(false)
            else
                self.inputQty:setText(string.format("%.0f", item.quantity or 0))
                self.inputQty:setDisabled(false)
            end
        else
            self.inputQty:setText("")
            self.inputQty:setDisabled(true)
        end
    end

    if self.inputVat ~= nil then
        local vatEnabled = g_currentMission.invoicesManager ~= nil and g_currentMission.invoicesManager.service:isVatEnabled()
        if item ~= nil then
            self.inputVat:setText(string.format("%.1f", (item.vatRate or 0) * 100))
            self.inputVat:setDisabled(not vatEnabled)
        else
            self.inputVat:setText("")
            self.inputVat:setDisabled(true)
        end
    end
end

function InvoicesWizardStep4:resizeTotalSep(htText, tvaText)
    if self.totalSep == nil or self.textVatHt == nil then return end

    if self._sepHeight == nil then
        self._sepHeight = self.totalSep.absSize[2]
    end

    local textSize = self.textVatHt.textSize
    local htWidth = getTextWidth(textSize, htText)
    local tvaWidth = self.textVatTva ~= nil and getTextWidth(self.textVatTva.textSize, tvaText) or 0
    local maxTextWidth = math.max(htWidth, tvaWidth)

    self.totalSep:setSize(maxTextWidth, self._sepHeight)
    if self.totalSep.parent ~= nil and self.totalSep.parent.invalidateLayout ~= nil then
        self.totalSep.parent:invalidateLayout()
    end
end

function InvoicesWizardStep4:updateTotal()
    local state = InvoicesWizardState.getInstance()
    local total = state:getTotal()

    -- Compute HT/TVA breakdown from line items
    local totalHT = 0
    local totalVAT = 0
    for _, item in ipairs(state.lineItems) do
        local lineAmount = item.amount or 0
        local lineVatRate = item.vatRate or 0
        local lineVAT = 0
        if lineVatRate > 0 then
            lineVAT = math.floor(lineAmount * lineVatRate / (1 + lineVatRate) + 0.5)
        end
        totalHT = totalHT + (lineAmount - lineVAT)
        totalVAT = totalVAT + lineVAT
    end

    if self.textTotal ~= nil then
        self.textTotal:setText(g_i18n:formatMoney(total, 0, true, true))
    end

    if self.textVatHt ~= nil and self.textVatTva ~= nil then
        local vatEnabled = g_currentMission.invoicesManager ~= nil and g_currentMission.invoicesManager.service:isVatEnabled()

        if vatEnabled and totalVAT > 0 then
            local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), g_i18n:formatMoney(totalHT, 0, true, false))
            local tvaText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), g_i18n:formatMoney(totalVAT, 0, true, false))
            self.textVatHt:setText(htText)
            self.textVatTva:setText(tvaText)
            self.textVatHt:setVisible(true)
            self.textVatTva:setVisible(true)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, tvaText)
            end
        elseif not vatEnabled then
            local htText = string.format("%s :  —", g_i18n:getText("invoice_label_subtotal_ht"))
            local tvaText = string.format("%s :  —", g_i18n:getText("invoice_label_vat"))
            self.textVatHt:setText(htText)
            self.textVatTva:setText(tvaText)
            self.textVatHt:setVisible(true)
            self.textVatTva:setVisible(true)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, tvaText)
            end
        else
            self.textVatHt:setVisible(false)
            self.textVatTva:setVisible(false)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(false)
            end
        end
    end

    if self.btnSend ~= nil then
        self.btnSend:setDisabled(not state:canCreateInvoice())
    end
end

function InvoicesWizardStep4:updateSliderVisibility()
    if self.sliderBox and self.listItems then
        local itemCount = #self.lineItems
        local maxVisibleItems = math.floor(248 / 32)
        local needsScroll = itemCount > maxVisibleItems
        self.sliderBox:setVisible(needsScroll)
    end
end

function InvoicesWizardStep4:onPriceTextChanged(element, text)
    if self.selectedIndex < 1 or self.selectedIndex > #self.lineItems then return end

    local filtered = string.gsub(text or "", "[^0-9]", "")
    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local item = self.lineItems[self.selectedIndex]
    local value = tonumber(filtered or "") or 0

    if value >= 0 then
        item.price = value
    end
    item.amount = MathUtil.round(item.price * item.quantity)

    self:updateSelectedCellValues()
    self:updateTotal()
end

function InvoicesWizardStep4:onQtyTextChanged(element, text)
    if self.selectedIndex < 1 or self.selectedIndex > #self.lineItems then return end

    local item = self.lineItems[self.selectedIndex]
    if item.unit == Invoice.UNIT_HECTARE then return end

    local allowDecimal = (item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER)
    local filtered
    if allowDecimal then
        filtered = string.gsub(text or "", "[^0-9.]", "")
        -- Allow only one decimal point
        local _, dotCount = string.gsub(filtered, "%.", "")
        if dotCount > 1 then
            filtered = string.gsub(filtered, "%.", "", dotCount - 1)
        end
    else
        filtered = string.gsub(text or "", "[^0-9]", "")
    end

    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local value = tonumber(filtered or "") or 0

    if value >= 0 then
        item.quantity = value
    end
    item.amount = MathUtil.round(item.price * item.quantity)

    self:updateSelectedCellValues()
    self:updateTotal()
end

function InvoicesWizardStep4:onVatRateTextChanged(element, text)
    if self.selectedIndex < 1 or self.selectedIndex > #self.lineItems then return end

    local filtered = string.gsub(text or "", "[^0-9.]", "")
    local _, dotCount = string.gsub(filtered, "%.", "")
    if dotCount > 1 then
        filtered = string.gsub(filtered, "%.", "", dotCount - 1)
    end
    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local value = tonumber(filtered or "") or 0
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end

    local item = self.lineItems[self.selectedIndex]
    item.vatRate = value / 100

    self:updateSelectedCellValues()
    self:updateTotal()
end

function InvoicesWizardStep4:onClickSend()
    local state = InvoicesWizardState.getInstance()

    local note = ""
    if self.inputNote ~= nil then
        note = self.inputNote.text or ""
    end

    for _, item in ipairs(state.lineItems) do
        item.note = note
    end

    local invoice = state:createInvoice()

    if invoice then
        self:close()
        InfoDialog.show(g_i18n:getText("invoice_wizard_invoice_created"))
    else
        InfoDialog.show(g_i18n:getText("invoice_wizard_invoice_failed"))
    end
end

function InvoicesWizardStep4:onClickBack()
    self:close()
    local state = InvoicesWizardState.getInstance()
    if not state:requiresFieldSelection() then
        g_gui:showDialog("InvoicesWizardStep2")
    else
        g_gui:showDialog("InvoicesWizardStep3")
    end
end

function InvoicesWizardStep4:onClickCancel()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self:close()
end

function InvoicesWizardStep4:delete()
    self.lineItems = nil
    InvoicesWizardStep4:superClass().delete(self)
end
