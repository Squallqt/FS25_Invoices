--[[
    InvoicesDetailDialog.lua
    Detail view dialog rendering line items, VAT breakdown, penalty bar, status badge, and pay action.
    Author: Squallqt
]]

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
    TEXT_VAT_HT  = "textVatHt",
    TEXT_VAT_TVA = "textVatTva",
    TOTAL_SEP    = "totalSep",
    PENALTY_BAR  = "penaltyBar",
    TEXT_PENALTY_BAR = "textPenaltyBar",
    BTN_PAY = "btnPay",
}

InvoicesDetailDialog.PENALTY_BAR_OFFSET = 28

InvoicesDetailDialog.COLOR_UNPAID  = {1.00, 0.66, 0.00, 1}
InvoicesDetailDialog.COLOR_PAID    = {0.40, 0.85, 0.40, 1}
InvoicesDetailDialog.COLOR_OVERDUE = {1.00, 0.30, 0.30, 1}
InvoicesDetailDialog.COLOR_PENALTY = {1.00, 0.40, 0.35, 1}

function InvoicesDetailDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or InvoicesDetailDialog_mt)
    return self
end

function InvoicesDetailDialog:onLoad()
    InvoicesDetailDialog:superClass().onLoad(self)
    self:registerControls(InvoicesDetailDialog.CONTROLS)
end

function InvoicesDetailDialog:onGuiSetupFinished()
    InvoicesDetailDialog:superClass().onGuiSetupFinished(self)

    if self.listItems ~= nil then
        self.listItems:setDataSource(self)
        self.listItems:setDelegate(self)
    end
end

function InvoicesDetailDialog:resizeTitleSep()
    if self.titleSep == nil or self.mainTitleText == nil then return end

    if self._titleSepHeight == nil then
        self._titleSepHeight = self.titleSep.absSize[2]
    end

    local text = self.mainTitleText.text or ""
    local textWidth = getTextWidth(self.mainTitleText.textSize, text)
    local padding = 20 * 2 * g_pixelSizeScaledX
    local newWidth = textWidth + padding

    self.titleSep:setSize(newWidth, self._titleSepHeight)
    if self.titleSep.parent ~= nil and self.titleSep.parent.invalidateLayout ~= nil then
        self.titleSep.parent:invalidateLayout()
    end
end

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

function InvoicesDetailDialog:resizeTotalSep(htText, tvaText, totalText)
    if self.totalSep == nil or self.textVatHt == nil then return end

    if self._sepOrigX == nil then
        self._sepOrigX = self.totalSep.position[1]
        self._sepOrigW = self.totalSep.size[1]
    end

    local textSize = self.textVatHt.textSize
    local htWidth = getTextWidth(textSize, htText)
    local tvaWidth = self.textVatTva ~= nil and getTextWidth(self.textVatTva.textSize, tvaText) or 0
    local totalWidth = self.textTotal ~= nil and getTextWidth(self.textTotal.textSize, totalText or self.textTotal.text or "") or 0
    totalWidth = totalWidth + (20 * g_pixelSizeScaledX)
    local maxTextWidth = math.max(htWidth, tvaWidth, totalWidth)

    local newW = math.min(maxTextWidth, self._sepOrigW)
    local newX = self._sepOrigX + self._sepOrigW - newW
    self.totalSep:setPosition(newX, self.totalSep.position[2])
    self.totalSep:setSize(newW, self.totalSep.size[2])
end

function InvoicesDetailDialog:onOpen()
    InvoicesDetailDialog:superClass().onOpen(self)
    self.invoice = nil
    self.items = {}
    self.displayItems = {}
    self:resizeTitleSep()
end

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

        local isPaid = (invoice.state == Invoice.STATE.PAID)
        local penaltyAmount = invoice.penaltyAmount or 0
        local isOverdue = (not isPaid and penaltyAmount > 0)
        if self.textStatus then
            local statusText
            local color
            if isPaid then
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

        if self.textVatHt ~= nil and self.textVatTva ~= nil then
            local vatAmount = invoice.vatAmount or 0
            if vatAmount > 0 then
                local totalHT = invoice.totalHT or invoice.totalAmount
                local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), g_i18n:formatMoney(totalHT, 0, true, false))
                local tvaText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), g_i18n:formatMoney(vatAmount, 0, true, false))
                self.textVatHt:setText(htText)
                self.textVatTva:setText(tvaText)
                self.textVatTva:setTextColor(0.5, 0.5, 0.5, 1)
                self.textVatHt:setVisible(true)
                self.textVatTva:setVisible(true)
                if self.totalSep ~= nil then
                    self.totalSep:setVisible(true)
                    self:resizeTotalSep(htText, tvaText, totalText)
                end
            else
                local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), g_i18n:getText("invoice_label_na"))
                local tvaText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), g_i18n:getText("invoice_label_na"))
                self.textVatHt:setText(htText)
                self.textVatTva:setText(tvaText)
                self.textVatTva:setTextColor(0.5, 0.5, 0.5, 1)
                self.textVatHt:setVisible(true)
                self.textVatTva:setVisible(true)
                if self.totalSep ~= nil then
                    self.totalSep:setVisible(true)
                    self:resizeTotalSep(htText, tvaText, totalText)
                end
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
        group.price = group.quantity > 0 and math.floor(group.amount / group.quantity) or 0
        table.insert(self.displayItems, group)
    end
end

function InvoicesDetailDialog:updateSliderVisibility()
    if self.sliderBox and self.listItems then
        local itemCount = #self.displayItems
        local maxVisibleItems = math.floor(284 / 32)
        local needsScroll = itemCount > maxVisibleItems
        self.sliderBox:setVisible(needsScroll)
    end
end

function InvoicesDetailDialog:getNumberOfSections()
    return 1
end

function InvoicesDetailDialog:getNumberOfItemsInSection(list, section)
    return #self.displayItems
end

function InvoicesDetailDialog:getTitleForSectionHeader(list, section)
    return nil
end

function InvoicesDetailDialog:getSectionHeaderHeight(list, section)
    return 0
end

function InvoicesDetailDialog:populateCellForItemInSection(list, section, index, cell)
    local item = self.displayItems[index]
    if not item then return end

    local manager = g_currentMission.invoicesManager
    local workType = manager and manager:getWorkTypeById(item.workTypeId)
    local amount = item.amount or 0

    -- Use persisted name (with product in parentheses), fallback to workType nameKey
    local designation
    if item.name ~= nil and item.name ~= "" then
        designation = item.name
    else
        designation = workType and g_i18n:getText(workType.nameKey) or "—"
    end

    -- Icon handling
    local cellIcon = cell:getDescendantByName("cellIcon")
    local hasIcon = item.iconFilename ~= nil and item.iconFilename ~= ""
    if cellIcon ~= nil then
        cellIcon:setVisible(false)
    end

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
        if item.price ~= nil and item.price > 0 then
            unitPriceStr = g_i18n:formatMoney(item.price)
        elseif area > 0 then
            unitPriceStr = g_i18n:formatMoney(amount / area)
        end
    elseif item.unitType == Invoice.UNIT_LITER then
        local qty = item.quantity or 0
        qtyStr = string.format("%.0f", qty)
        unitStr = g_i18n:getText("invoice_invoices_unit_liter")
        if item.price ~= nil and item.price > 0 then
            unitPriceStr = g_i18n:formatMoney(item.price)
        elseif qty > 0 then
            unitPriceStr = g_i18n:formatMoney(amount * 1000 / qty)
        end
    elseif item.unitType == Invoice.UNIT_HOUR then
        local qty = item.quantity or 0
        qtyStr = string.format("%.2f", qty)
        unitStr = g_i18n:getText("invoice_invoices_unit_hour")
        if item.price ~= nil and item.price > 0 then
            unitPriceStr = g_i18n:formatMoney(item.price)
        elseif qty > 0 then
            unitPriceStr = g_i18n:formatMoney(amount / qty)
        end
    else
        local qty = math.max(1, item.quantity or 1)
        qtyStr = string.format("%d", qty)
        unitStr = g_i18n:getText("invoice_invoices_unit_piece")
        if item.price ~= nil and item.price > 0 then
            unitPriceStr = g_i18n:formatMoney(item.price)
        elseif qty > 0 then
            unitPriceStr = g_i18n:formatMoney(amount / qty)
        end
    end

    local amountStr = g_i18n:formatMoney(amount)

    local vatRate = item.vatRate or 0
    local vatStr = g_i18n:getText("invoice_label_na")
    if vatRate > 0 then
        vatStr = string.format("%.1f%%", vatRate * 100)
    end

    local cellDesignation = cell:getDescendantByName("cellDesignation")
    if cellDesignation ~= nil then
        if hasIcon and cellIcon ~= nil then
            local baseName = designation
            local parenStart = string.find(designation, "%(")
            if parenStart ~= nil then
                local inner = string.sub(designation, parenStart + 1, #designation - 1)
                if inner ~= "" then
                    baseName = inner
                end
            end
            local textSize = 14 * g_pixelSizeScaledY
            setTextBold(false)
            local spaceWidth = getTextWidth(textSize, " ")
            local iconPadding = 22 * g_pixelSizeScaledX
            local numSpaces = math.ceil(iconPadding / spaceWidth)
            cellIcon:setImageFilename(item.iconFilename)
            cellIcon:setVisible(true)
            designation = string.rep(" ", numSpaces) .. baseName
        end
        cellDesignation:setText(designation)
    end

    local cellField       = cell:getDescendantByName("cellField")
    local cellQty         = cell:getDescendantByName("cellQty")
    local cellUnit        = cell:getDescendantByName("cellUnit")
    local cellUnitPrice   = cell:getDescendantByName("cellUnitPrice")
    local cellVat         = cell:getDescendantByName("cellVat")
    local cellAmount      = cell:getDescendantByName("cellAmount")

    if cellField       then cellField:setText(fieldStr) end
    if cellQty         then cellQty:setText(qtyStr) end
    if cellUnit        then cellUnit:setText(unitStr) end
    if cellUnitPrice   then cellUnitPrice:setText(unitPriceStr) end
    if cellVat         then cellVat:setText(vatStr) end
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
    local totalDue = self.invoice.totalAmount + (self.invoice.penaltyAmount or 0)
    if not manager:farmHasSufficientBalance(self.invoice.recipientFarmId, totalDue) then
        InfoDialog.show(g_i18n:getText("invoice_error_insufficient_funds"))
        return
    end
    local senderFarm = g_farmManager:getFarmById(self.invoice.senderFarmId)
    local farmName = senderFarm and senderFarm.name or ""
    local confirmText = string.format(g_i18n:getText("invoice_confirm_pay"),
                                     g_i18n:formatMoney(totalDue),
                                     farmName)

    local details = {}
    if (self.invoice.vatAmount or 0) > 0 then
        local vatStr = g_i18n:formatMoney(self.invoice.vatAmount, 0, true, false)
        local vatLabel = g_i18n:getText("invoice_label_vat")
        table.insert(details, string.format(g_i18n:getText("invoice_notification_vat_incl"), vatLabel, vatStr))
    end
    if (self.invoice.penaltyAmount or 0) > 0 then
        local penStr = g_i18n:formatMoney(self.invoice.penaltyAmount, 0, true, false)
        table.insert(details, string.format(g_i18n:getText("invoice_notification_penalty_incl"), penStr))
    end
    if #details > 0 then
        confirmText = confirmText .. "\n(" .. table.concat(details, ", ") .. ")"
    end

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
