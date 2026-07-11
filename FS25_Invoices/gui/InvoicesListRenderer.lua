-- Copyright © 2026 Squallqt. All rights reserved.
-- SmoothList data source and delegate rendering invoice rows with status-driven color coding.
InvoicesListRenderer = {}
InvoicesListRenderer_mt = Class(InvoicesListRenderer)

InvoicesListRenderer.COLOR_UNPAID  = {1.00, 0.66, 0.00, 1}
InvoicesListRenderer.COLOR_PAID    = {0.40, 0.85, 0.40, 1}
InvoicesListRenderer.COLOR_OVERDUE = {1.00, 0.30, 0.30, 1}
InvoicesListRenderer.COLOR_PROPOSED = {0.45, 0.70, 1.00, 1}
InvoicesListRenderer.COLOR_UNPAID_SELECTED  = {0.45, 0.25, 0.00, 1}
InvoicesListRenderer.COLOR_PAID_SELECTED    = {0.10, 0.30, 0.10, 1}
InvoicesListRenderer.COLOR_OVERDUE_SELECTED = {0.45, 0.10, 0.10, 1}
InvoicesListRenderer.COLOR_PROPOSED_SELECTED = {0.10, 0.25, 0.45, 1}

---Creates new invoice list renderer instance
-- @return InvoicesListRenderer instance The new renderer instance
function InvoicesListRenderer.new()
    local self = {}
    setmetatable(self, InvoicesListRenderer_mt)

    self.data = {}
    self.selectedRow = -1
    self.indexChangedCallback = nil
    self.mode = "incoming"
    self.currentFarmId = -1

    return self
end

---Sets display mode for farm column
-- @param string mode "incoming" or "outgoing"
function InvoicesListRenderer:setMode(mode)
    self.mode = mode or "incoming"
end

---Sets the farm currently viewing the list.
-- @param integer farmId Farm identifier
function InvoicesListRenderer:setCurrentFarmId(farmId)
    self.currentFarmId = farmId or -1
end

---Sets invoice data and resets selection
-- @param table data Array of invoices
function InvoicesListRenderer:setData(data)
    self.data = data or {}
    self.selectedRow = -1
end

---Returns number of list sections
-- @return integer count Always 1
function InvoicesListRenderer:getNumberOfSections()
    return 1
end

---Returns number of items in a section
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer count Number of invoices
function InvoicesListRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

---Populates cell with invoice data and status colors
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
-- @param table cell Cell element to populate
function InvoicesListRenderer:populateCellForItemInSection(list, section, index, cell)
    local invoice = self.data[index]
    if invoice == nil then
        return
    end

    local numberStr = string.format(g_i18n:getText("invoice_format_inv_number"), invoice.id)

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

    local farmName = ""
    local farmId = invoice.recipientFarmId
    if invoice.state == Invoice.STATE.PROPOSED then
        if self.currentFarmId == invoice.senderFarmId then
            farmId = invoice.recipientFarmId
        elseif self.currentFarmId == invoice.recipientFarmId then
            farmId = invoice.senderFarmId
        end
    elseif self.mode == "incoming" then
        farmId = invoice.senderFarmId
    end
    if farmId then
        local farm = g_farmManager:getFarmById(farmId)
        if farm then
            farmName = farm.name
        end
    end

    local servicesStr = ""
    local itemCount = invoice.lineItems and #invoice.lineItems or 0
    
    if itemCount == 0 then
        servicesStr = g_i18n:getText("invoice_empty_list")
    else
        local manager = g_currentMission.invoicesManager
        local serviceNames = {}
        local uniqueServiceNames = {}
        
        if manager and invoice.lineItems then
            for _, lineItem in ipairs(invoice.lineItems) do
                local name = lineItem.name
                if (name == nil or name == "") and lineItem.workTypeId ~= nil then
                    local workType = manager.service:getWorkTypeById(lineItem.workTypeId)
                    if workType and workType.nameKey then
                        name = g_i18n:getText(workType.nameKey)
                    end
                end

                if name ~= nil and name ~= "" and not uniqueServiceNames[name] then
                    uniqueServiceNames[name] = true
                    table.insert(serviceNames, name)
                end
            end
        end
        
        if #serviceNames == 0 then
            servicesStr = string.format(g_i18n:getText("invoice_format_services_count"), itemCount)
        elseif #serviceNames == 1 then
            servicesStr = serviceNames[1]
        elseif #serviceNames <= 3 then
            servicesStr = table.concat(serviceNames, ", ")
        else
            local firstTwo = {serviceNames[1], serviceNames[2]}
            local remaining = #serviceNames - 2
            servicesStr = string.format("%s, +%d", table.concat(firstTwo, ", "), remaining)
        end
    end

    local statusStr = ""
    local isProposed = (invoice.state == Invoice.STATE.PROPOSED)
    local isPaid = (invoice.state == Invoice.STATE.PAID)
    local penaltyAmount = invoice.penaltyAmount or 0
    local isOverdue = (not isPaid and not isProposed and penaltyAmount > 0)
    if isProposed then
        statusStr = g_i18n:getText("invoice_status_proposed")
    elseif isPaid then
        statusStr = g_i18n:getText("invoice_status_paid")
    elseif isOverdue then
        statusStr = g_i18n:getText("invoice_status_overdue")
    else
        statusStr = g_i18n:getText("invoice_status_unpaid")
    end

    local totalDue = (invoice.totalAmount or 0) + penaltyAmount
    local amountStr = g_i18n:formatMoney(totalDue)

    -- Total discount of the invoice = real reduction (before - after), shown as a negative amount.
    local discountAmount = Invoice.computeTotalDiscountAmount(invoice.lineItems)
    local discountStr = "—"
    if discountAmount > 0 then
        discountStr = "-" .. g_i18n:formatMoney(discountAmount, 0, true, false)
    end

    local cellNumber   = cell:getDescendantByName("cellNumber")
    local cellDate     = cell:getDescendantByName("cellDate")
    local cellFarm     = cell:getDescendantByName("cellFarm")
    local cellServices = cell:getDescendantByName("cellServices")
    local cellStatus   = cell:getDescendantByName("cellStatus")
    local cellDiscount = cell:getDescendantByName("cellDiscount")
    local cellAmount   = cell:getDescendantByName("cellAmount")

    if cellNumber then
        cellNumber:setText(numberStr)
    end
    if cellDate then
        cellDate:setText(dateStr)
    end
    if cellFarm then
        cellFarm:setText(farmName)
    end
    if cellServices then
        cellServices:setText(servicesStr)
    end
    if cellStatus then
        cellStatus:setText(statusStr)
        if isProposed then
            cellStatus:setTextColor(unpack(InvoicesListRenderer.COLOR_PROPOSED))
            cellStatus.textSelectedColor = InvoicesListRenderer.COLOR_PROPOSED_SELECTED
        elseif isPaid then
            cellStatus:setTextColor(unpack(InvoicesListRenderer.COLOR_PAID))
            cellStatus.textSelectedColor = InvoicesListRenderer.COLOR_PAID_SELECTED
        elseif isOverdue then
            cellStatus:setTextColor(unpack(InvoicesListRenderer.COLOR_OVERDUE))
            cellStatus.textSelectedColor = InvoicesListRenderer.COLOR_OVERDUE_SELECTED
        else
            cellStatus:setTextColor(unpack(InvoicesListRenderer.COLOR_UNPAID))
            cellStatus.textSelectedColor = InvoicesListRenderer.COLOR_UNPAID_SELECTED
        end
    end
    if cellDiscount then
        cellDiscount:setText(discountStr)
    end
    if cellAmount then
        cellAmount:setText(amountStr)
    end
end

---Called when list selection changes
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Selected item index
function InvoicesListRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end

---Returns currently selected invoice
-- @return table|nil invoice Selected invoice or nil
function InvoicesListRenderer:getSelectedInvoice()
    if self.selectedRow > 0 and self.selectedRow <= #self.data then
        return self.data[self.selectedRow]
    end
    return nil
end
