--[[
    InvoicesDetailDialog.lua
    Author: Squallqt
]]

InvoicesDetailDialog = {}
local InvoicesDetailDialog_mt = Class(InvoicesDetailDialog, DialogElement)

InvoicesDetailDialog.CONTROLS = {
    TITLE_BADGE_BG = "titleBadgeBg",
    MAIN_TITLE_TEXT = "mainTitleText",
    DIALOG_TITLE = "dialogTitle",
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
    TEXT_VAT_HT  = "textVatHt",
    TEXT_VAT_TVA = "textVatTva",
    TOTAL_SEP    = "totalSep",
    BTN_PAY = "btnPay",
}

InvoicesDetailDialog.COLOR_UNPAID = {1.00, 0.66, 0.00, 1}
InvoicesDetailDialog.COLOR_PAID   = {0.40, 0.85, 0.40, 1}

function InvoicesDetailDialog.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesDetailDialog_mt)
    return self
end

function InvoicesDetailDialog:onLoad()
    InvoicesDetailDialog:superClass().onLoad(self)
    self:registerControls(InvoicesDetailDialog.CONTROLS)
    Logging.devInfo("[InvoicesDetailDialog] onLoad() - Controls registered")
end

function InvoicesDetailDialog:onGuiSetupFinished()
    InvoicesDetailDialog:superClass().onGuiSetupFinished(self)

    if self.listItems ~= nil then
        self.listItems:setDataSource(self)
        self.listItems:setDelegate(self)
    end
end

function InvoicesDetailDialog:resizeTitleBadge()
    if self.mainTitleText ~= nil and self.titleBadgeBg ~= nil then
        local textWidth = getTextWidth(self.mainTitleText.textSize, self.mainTitleText.text)
        local paddingX = self.mainTitleText.textSize * 0.8
        local badgeWidth = textWidth + paddingX * 2
        local badgeHeight = self.titleBadgeBg.absSize[2]
        self.titleBadgeBg:setSize(badgeWidth, badgeHeight)
    end
end

function InvoicesDetailDialog:onOpen()
    InvoicesDetailDialog:superClass().onOpen(self)
    self:resizeTitleBadge()
    self.invoice = nil
    self.items = {}
end

function InvoicesDetailDialog:setInvoice(invoice, isIncoming)
    self.invoice = invoice
    self.isIncoming = isIncoming or false
    self.items = invoice and invoice.lineItems or {}

    if invoice then
        local invNumber = string.format(g_i18n:getText("invoice_format_inv_number"), invoice.id)
        if self.textTitle then
            self.textTitle:setText(invNumber)
        end

        local isPaid = (invoice.state == Invoice.STATE.PAID)
        if self.textStatus then
            local statusText = isPaid and g_i18n:getText("invoice_status_paid") or g_i18n:getText("invoice_status_unpaid")
            self.textStatus:setText(statusText)
            local color = isPaid and InvoicesDetailDialog.COLOR_PAID or InvoicesDetailDialog.COLOR_UNPAID
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

        if self.textTotal then
            self.textTotal:setText(g_i18n:formatMoney(invoice.totalAmount or 0))
        end

        if self.textVatHt ~= nil and self.textVatTva ~= nil then
            local vatAmount = invoice.vatAmount or 0
            if vatAmount > 0 then
                local totalHT = invoice.totalHT or invoice.totalAmount
                local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), g_i18n:formatMoney(totalHT, 0, true, false))
                local tvaText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), g_i18n:formatMoney(vatAmount, 0, true, false))
                self.textVatHt:setText(htText)
                self.textVatTva:setText(tvaText)
                self.textVatHt:setVisible(true)
                self.textVatTva:setVisible(true)
                if self.totalSep ~= nil then
                    local htWidth = getTextWidth(self.textVatHt.textSize, htText)
                    local tvaWidth = getTextWidth(self.textVatTva.textSize, tvaText)
                    local totalWidth = getTextWidth(self.textTotal.textSize, self.textTotal.text or "")
                    local maxWidth = math.max(htWidth, tvaWidth, totalWidth)
                    local padding = self.textVatHt.textSize * 0.5
                    local sepWidth = maxWidth + padding
                    local containerRight = self.textVatHt.absPosition[1] + self.textVatHt.absSize[1]
                    local sepX = containerRight - sepWidth
                    self.totalSep:setPosition(sepX, self.totalSep.absPosition[2])
                    self.totalSep:setSize(sepWidth, self.totalSep.absSize[2])
                    self.totalSep:setVisible(true)
                end
            else
                self.textVatHt:setVisible(false)
                self.textVatTva:setVisible(false)
                if self.totalSep ~= nil then
                    self.totalSep:setVisible(false)
                end
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

    if self.btnPay then
        self.btnPay:setVisible(true)
        local canPay = (invoice ~= nil and self.isIncoming and invoice.state ~= Invoice.STATE.PAID)
        self.btnPay:setDisabled(not canPay)
    end

    if self.listItems then
        self.listItems:reloadData()
    end

    self:updateSliderVisibility()
end

function InvoicesDetailDialog:updateSliderVisibility()
    if self.sliderBox and self.listItems then
        local itemCount = #self.items
        local maxVisibleItems = math.floor(200 / 36)
        local needsScroll = itemCount > maxVisibleItems
        self.sliderBox:setVisible(needsScroll)
    end
end

function InvoicesDetailDialog:getNumberOfSections()
    return 1
end

function InvoicesDetailDialog:getNumberOfItemsInSection(list, section)
    return #self.items
end

function InvoicesDetailDialog:getTitleForSectionHeader(list, section)
    return nil
end

function InvoicesDetailDialog:getSectionHeaderHeight(list, section)
    return 0
end

function InvoicesDetailDialog:populateCellForItemInSection(list, section, index, cell)
    local item = self.items[index]
    if not item then return end

    local manager = g_currentMission.invoicesManager
    local workType = manager and manager:getWorkTypeById(item.workTypeId)
    local amount = item.amount or 0

    local designation = workType and g_i18n:getText(workType.nameKey) or "—"

    local fieldStr = ""
    if item.fieldId and item.fieldId > 0 then
        fieldStr = string.format(g_i18n:getText("invoice_format_fieldId"), item.fieldId)
    else
        fieldStr = "—"
    end

    local qtyStr = ""
    local unitStr = ""
    local unitPriceStr = ""

    if item.unitType == Invoice.UNIT_HECTARE then
        local area = item.fieldArea or 0
        qtyStr = string.format("%.2f", area)
        unitStr = g_i18n:getText("invoice_invoices_unit_hectare")
        if area > 0 then
            unitPriceStr = g_i18n:formatMoney(amount / area)
        end
    elseif item.unitType == Invoice.UNIT_LITER then
        local qty = item.quantity or 0
        qtyStr = string.format("%.0f", qty)
        unitStr = g_i18n:getText("invoice_invoices_unit_liter")
        if qty > 0 then
            unitPriceStr = g_i18n:formatMoney(amount / qty)
        end
    elseif item.unitType == Invoice.UNIT_HOUR then
        local qty = item.quantity or 0
        qtyStr = string.format("%.1f", qty)
        unitStr = g_i18n:getText("invoice_invoices_unit_hour")
        if qty > 0 then
            unitPriceStr = g_i18n:formatMoney(amount / qty)
        end
    else
        local qty = math.max(1, item.quantity or 1)
        qtyStr = string.format("%d", qty)
        unitStr = g_i18n:getText("invoice_invoices_unit_piece")
        if qty > 0 then
            unitPriceStr = g_i18n:formatMoney(amount / qty)
        end
    end

    local amountStr = g_i18n:formatMoney(amount)

    local cellDesignation = cell:getDescendantByName("cellDesignation")
    local cellField       = cell:getDescendantByName("cellField")
    local cellQty         = cell:getDescendantByName("cellQty")
    local cellUnit        = cell:getDescendantByName("cellUnit")
    local cellUnitPrice   = cell:getDescendantByName("cellUnitPrice")
    local cellAmount      = cell:getDescendantByName("cellAmount")

    if cellDesignation then cellDesignation:setText(designation) end
    if cellField       then cellField:setText(fieldStr) end
    if cellQty         then cellQty:setText(qtyStr) end
    if cellUnit        then cellUnit:setText(unitStr) end
    if cellUnitPrice   then cellUnitPrice:setText(unitPriceStr) end
    if cellAmount      then cellAmount:setText(amountStr) end
end

function InvoicesDetailDialog:onListSelectionChanged(list, section, index)
end

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
    if not manager:farmHasSufficientBalance(self.invoice.recipientFarmId, self.invoice.totalAmount) then
        InfoDialog.show(g_i18n:getText("invoice_error_insufficient_funds"))
        return
    end
    local senderFarm = g_farmManager:getFarmById(self.invoice.senderFarmId)
    local farmName = senderFarm and senderFarm.name or ""
    local confirmText = string.format(g_i18n:getText("invoice_confirm_pay"), 
                                     g_i18n:formatMoney(self.invoice.totalAmount), 
                                     farmName)
    YesNoDialog.show(self.onPayConfirmed, self, confirmText)
end

function InvoicesDetailDialog:onPayConfirmed(confirmed)
    if confirmed and self.invoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:payInvoice(self.invoice.id)
            self:close()
        end
    end
end

function InvoicesDetailDialog:onClickBack()
    self:close()
end
