-- Copyright © 2026 Squallqt. All rights reserved.
-- SmoothList data source and delegate rendering invoice rows with status-driven color coding.
InvoicesListRenderer = {}
InvoicesListRenderer_mt = Class(InvoicesListRenderer)

InvoicesListRenderer.COLOR_UNPAID  = {1.00, 0.66, 0.00, 1}
InvoicesListRenderer.COLOR_PAID    = {0.40, 0.85, 0.40, 1}
InvoicesListRenderer.COLOR_OVERDUE = {1.00, 0.30, 0.30, 1}
InvoicesListRenderer.COLOR_UNPAID_SELECTED  = {0.45, 0.25, 0.00, 1}
InvoicesListRenderer.COLOR_PAID_SELECTED    = {0.10, 0.30, 0.10, 1}
InvoicesListRenderer.COLOR_OVERDUE_SELECTED = {0.45, 0.10, 0.10, 1}

---Creates new invoice list renderer instance
-- @return InvoicesListRenderer instance The new renderer instance
function InvoicesListRenderer.new()
    local self = {}
    setmetatable(self, InvoicesListRenderer_mt)

    self.data = {}
    self.selectedRow = -1
    self.indexChangedCallback = nil
    self.mode = "incoming"

    return self
end

---Sets display mode for farm column
-- @param string mode "incoming" or "outgoing"
function InvoicesListRenderer:setMode(mode)
    self.mode = mode or "incoming"
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

---Returns section header title
-- @param table list SmoothList element
-- @param integer section Section index
-- @return string title Empty string
function InvoicesListRenderer:getTitleForSectionHeader(list, section)
    return ""
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
    local farmId
    if self.mode == "incoming" then
        farmId = invoice.senderFarmId
    else
        farmId = invoice.recipientFarmId
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
        local workTypeNames = {}
        local uniqueWorkTypes = {}
        
        if manager and invoice.lineItems then
            for _, lineItem in ipairs(invoice.lineItems) do
                local workTypeId = lineItem.workTypeId
                if workTypeId and not uniqueWorkTypes[workTypeId] then
                    uniqueWorkTypes[workTypeId] = true
                    local workType = manager.service:getWorkTypeById(workTypeId)
                    if workType and workType.nameKey then
                        local name = g_i18n:getText(workType.nameKey)
                        table.insert(workTypeNames, name)
                    end
                end
            end
        end
        
        if #workTypeNames == 0 then
            servicesStr = string.format(g_i18n:getText("invoice_format_services_count"), itemCount)
        elseif #workTypeNames == 1 then
            servicesStr = workTypeNames[1]
        elseif #workTypeNames <= 3 then
            servicesStr = table.concat(workTypeNames, ", ")
        else
            local firstTwo = {workTypeNames[1], workTypeNames[2]}
            local remaining = #workTypeNames - 2
            servicesStr = string.format("%s, +%d", table.concat(firstTwo, ", "), remaining)
        end
    end

    local statusStr = ""
    local isPaid = (invoice.state == Invoice.STATE.PAID)
    local penaltyAmount = invoice.penaltyAmount or 0
    local isOverdue = (not isPaid and penaltyAmount > 0)
    if isPaid then
        statusStr = g_i18n:getText("invoice_status_paid")
    elseif isOverdue then
        statusStr = g_i18n:getText("invoice_status_overdue")
    else
        statusStr = g_i18n:getText("invoice_status_unpaid")
    end

    local totalDue = (invoice.totalAmount or 0) + penaltyAmount
    local amountStr = g_i18n:formatMoney(totalDue)

    local cellNumber   = cell:getDescendantByName("cellNumber")
    local cellDate     = cell:getDescendantByName("cellDate")
    local cellFarm     = cell:getDescendantByName("cellFarm")
    local cellServices = cell:getDescendantByName("cellServices")
    local cellStatus   = cell:getDescendantByName("cellStatus")
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
        if isPaid then
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
