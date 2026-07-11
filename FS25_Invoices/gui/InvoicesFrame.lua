-- Copyright © 2026 Squallqt. All rights reserved.
-- InGameMenu tab frame: incoming/outgoing invoice lists with pay, delete, and detail navigation.
InvoicesFrame = {}
InvoicesFrame._mt = Class(InvoicesFrame, TabbedMenuFrameElement)

InvoicesFrame.TAB = {
    INCOMING = 1,
    OUTGOING = 2
}

InvoicesFrame.SCREEN_EDGE_SLIDER_MARGIN_X = 0
InvoicesFrame.NATIVE_DOCKED_SLIDER_OFFSET_Y = 10

---Creates new invoices frame instance
-- @param table i18n Internationalization context
-- @param table messageCenter Message center instance
-- @return InvoicesFrame instance The new frame instance
function InvoicesFrame.new(i18n, messageCenter)
    local self = InvoicesFrame:superClass().new(nil, InvoicesFrame._mt)
    
    self.name = "InvoicesFrame"
    self.i18n = i18n
    self.messageCenter = messageCenter
    
    self.listRenderer = InvoicesListRenderer.new()
    self.listRenderer2 = InvoicesListRenderer.new()
    
    self.selectedInvoice = nil
    self.currentTab = InvoicesFrame.TAB.INCOMING
    
    self.incomingInvoices = {}
    self.outgoingInvoices = {}
    self.invoiceSort = {
        [InvoicesFrame.TAB.INCOMING] = {column = "number", asc = false},
        [InvoicesFrame.TAB.OUTGOING] = {column = "number", asc = false}
    }
    
    return self
end

---Performs GUI setup after elements are initialized
function InvoicesFrame:onGuiSetupFinished()
    InvoicesFrame:superClass().onGuiSetupFinished(self)
    
    if self.listInvoices then
        self.listInvoices:setDataSource(self.listRenderer)
        self.listInvoices:setDelegate(self.listRenderer)
    end
    
    if self.listInvoices2 then
        self.listInvoices2:setDataSource(self.listRenderer2)
        self.listInvoices2:setDelegate(self.listRenderer2)
    end
    
    self.listRenderer.indexChangedCallback = function(index)
        self:onSelectionChanged(index)
    end
    self.listRenderer2.indexChangedCallback = function(index)
        self:onSelectionChanged(index)
    end

    self:bindSortHeaders(InvoicesFrame.TAB.INCOMING, self.incomingSortHeaders, self.incomingSortIcons)
    self:bindSortHeaders(InvoicesFrame.TAB.OUTGOING, self.outgoingSortHeaders, self.outgoingSortIcons)
end

---Initializes frame buttons, tabs, and menu button info
function InvoicesFrame:initialize()
    InvoicesFrame:superClass().initialize(self)

    for i, tab in pairs(self.subCategoryTabs) do
        tab:getDescendantByName("background").getIsSelected = function()
            return i == self.subCategoryPaging:getState()
        end
        function tab.getIsSelected()
            return i == self.subCategoryPaging:getState()
        end
    end

    self.btnBack = {
        inputAction = InputAction.MENU_BACK
    }
    
    self.btnNewInvoice = {
        text = self.i18n:getText("invoice_btn_newInvoice"),
        inputAction = InputAction.MENU_ACTIVATE,
        callback = function() self:onClickNewInvoice() end
    }
    
    self.btnPay = {
        text = self.i18n:getText("invoice_btn_payInvoice"),
        inputAction = InputAction.MENU_ACCEPT,
        disabled = true,
        callback = function() self:onClickPay() end
    }
    
    self.btnDelete = {
        text = self.i18n:getText("invoice_btn_cancel"),
        inputAction = InputAction.MENU_CANCEL,
        disabled = true,
        callback = function() self:onClickDelete() end
    }
    
    self.btnDetails = {
        text = self.i18n:getText("invoice_btn_showDetails"),
        inputAction = InputAction.MENU_EXTRA_1,
        disabled = true,
        callback = function() self:onClickDetails() end
    }
    
    self.btnNextPage = {
        inputAction = InputAction.MENU_PAGE_NEXT,
        text = self.i18n:getText("ui_ingameMenuNext"),
        callback = self.onPageNext
    }
    self.btnPrevPage = {
        inputAction = InputAction.MENU_PAGE_PREV,
        text = self.i18n:getText("ui_ingameMenuPrev"),
        callback = self.onPagePrevious
    }
    
    self.menuButtonInfo = {}
    self.menuButtonInfo[InvoicesFrame.TAB.INCOMING] = { self.btnBack, self.btnNextPage, self.btnPrevPage, self.btnNewInvoice, self.btnPay, self.btnDetails }
    self.menuButtonInfo[InvoicesFrame.TAB.OUTGOING] = { self.btnBack, self.btnNextPage, self.btnPrevPage, self.btnNewInvoice, self.btnDelete, self.btnDetails }
end

---Returns menu button info for the current tab
-- @return table buttonInfo Array of button definitions
function InvoicesFrame:getMenuButtonInfo()
    if self.menuButtonInfo == nil then
        return {}
    end
    return self.menuButtonInfo[self.currentTab] or {}
end

---Called when frame is opened, sets up tabs and loads data
function InvoicesFrame:onFrameOpen()
    InvoicesFrame:superClass().onFrameOpen(self)
    g_currentMission.invoicesFrame = self

    self.currentTab = InvoicesFrame.TAB.INCOMING

    if self.subCategoryPaging and self.subCategoryBox then
        local texts = {}
        for k, tab in pairs(self.subCategoryTabs) do
            tab:setVisible(true)
            table.insert(texts, tostring(k))
        end
        self.subCategoryBox:invalidateLayout()
        self.subCategoryPaging:setTexts(texts)
        self.subCategoryPaging:setSize(self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX)
    end

    self:updateBalanceDisplay()
    g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChanged, self)

    self.subCategoryPaging:setState(self.currentTab, true)
    for k, v in pairs(self.subCategoryPages) do
        v:setVisible(k == self.currentTab)
    end

    -- Reset sort to default (number desc) every time the menu is opened.
    self.invoiceSort = {
        [InvoicesFrame.TAB.INCOMING] = {column = "number", asc = false},
        [InvoicesFrame.TAB.OUTGOING] = {column = "number", asc = false}
    }
    self:bindSortHeaders(InvoicesFrame.TAB.INCOMING, self.incomingSortHeaders, self.incomingSortIcons)
    self:bindSortHeaders(InvoicesFrame.TAB.OUTGOING, self.outgoingSortHeaders, self.outgoingSortIcons)
    self:refreshList()
    self:updateScreenEdgeSliders()

    self:setMenuButtonInfoDirty()
end

---Called when frame is closed, unsubscribes from events
function InvoicesFrame:onFrameClose()
    InvoicesFrame:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
    g_currentMission.invoicesFrame = nil
end

function InvoicesFrame:update(dt)
    InvoicesFrame:superClass().update(self, dt)
    self:updateScreenEdgeSliders()
end

---Switches to incoming invoices tab
function InvoicesFrame:onClickIncoming()
    self.subCategoryPaging:setState(InvoicesFrame.TAB.INCOMING, true)
    self:setMenuButtonInfoDirty()
end

---Switches to outgoing invoices tab
function InvoicesFrame:onClickOutgoing()
    self.subCategoryPaging:setState(InvoicesFrame.TAB.OUTGOING, true)
    self:setMenuButtonInfoDirty()
end

---Updates page visibility based on current tab
function InvoicesFrame:updateSubCategoryPages()
    self.currentTab = self.subCategoryPaging:getState()
    
    for k, v in pairs(self.subCategoryPages) do
        v:setVisible(k == self.currentTab)
    end
    
    self:updateSortHeaders(self.currentTab)
    self:refreshList()
    self:setMenuButtonInfoDirty()
end

function InvoicesFrame:bindSortHeaders(tab, headers, icons)
    local sort = self.invoiceSort[tab]
    for index, header in ipairs(headers or {}) do
        header.onClickCallback = function()
            self:onClickInvoiceSort(tab, header)
        end

        local icon = icons ~= nil and icons[index] or nil
        if icon ~= nil then
            icon:setImageSlice(nil, "invoices.sortArrowDown")
            icon:setVisible(false)
        end

        if header.columnName == sort.column then
            sort.header = header
            header.sortingOrder = sort.asc and TableHeaderElement.SORTING_ASC or TableHeaderElement.SORTING_DESC
        else
            header:disableSorting()
        end
    end

    self:updateSortHeaders(tab)
end

function InvoicesFrame:getSortControls(tab)
    if tab == InvoicesFrame.TAB.INCOMING then
        return self.incomingSortHeaders, self.incomingSortIcons
    end

    return self.outgoingSortHeaders, self.outgoingSortIcons
end

function InvoicesFrame:updateSortHeaders(tab)
    local sort = self.invoiceSort[tab]
    local headers, icons = self:getSortControls(tab)

    for index, header in ipairs(headers or {}) do
        local selected = header.columnName == sort.column
        header:setSelected(selected)

        local icon = icons ~= nil and icons[index] or nil
        if icon ~= nil then
            icon:setVisible(selected)
            if selected then
                local sliceId = sort.asc and "invoices.sortArrowUp" or "invoices.sortArrowDown"
                icon:setImageSlice(nil, sliceId)
                self:positionSortIcon(header, icon)
            end
        end
    end
end

function InvoicesFrame:positionSortIcon(header, icon)
    local textX = header:getTextPositionX()
    local textWidth = header:getTextWidth()

    if header.textAlignment == RenderText.ALIGN_CENTER then
        textX = textX - textWidth * 0.5
    elseif header.textAlignment == RenderText.ALIGN_RIGHT then
        textX = textX - textWidth
    end

    local gap = 6 * g_pixelSizeX
    local x = textX - icon.absSize[1] - gap
    local y = header.absPosition[2] + (header.absSize[2] - icon.absSize[2]) * 0.5
    icon:setAbsolutePosition(x, y)
end

function InvoicesFrame:onClickInvoiceSort(tab, header)
    local sort = self.invoiceSort[tab]

    if sort.header ~= header then
        if sort.header ~= nil then
            sort.header:disableSorting()
        end
        sort.header = header
        header:disableSorting()
    end

    local sortingOrder = header:toggleSorting()
    if sortingOrder == TableHeaderElement.SORTING_OFF then
        sortingOrder = header:toggleSorting()
    end

    sort.column = header.columnName
    sort.asc = sortingOrder == TableHeaderElement.SORTING_ASC
    self:updateSortHeaders(tab)
    self:refreshList()
end

function InvoicesFrame:sortInvoicesForTab(invoices, tab)
    local sort = self.invoiceSort[tab]
    table.sort(invoices, function(a, b)
        local valueA = self:getInvoiceSortValue(a, tab, sort.column)
        local valueB = self:getInvoiceSortValue(b, tab, sort.column)
        local sortAsc = valueA < valueB
        if valueA == valueB then
            local idA = a.id or 0
            local idB = b.id or 0
            if idA == idB then
                return false
            end
            sortAsc = idA < idB
        end
        if sort.asc then
            return sortAsc
        end
        return not sortAsc
    end)
end

function InvoicesFrame:getDisplayFarmIdForTab(invoice, tab, currentFarmId)
    local viewerFarmId = currentFarmId or self:getCurrentFarmId()

    if invoice ~= nil and invoice.state == Invoice.STATE.PROPOSED then
        if viewerFarmId == invoice.senderFarmId then
            return invoice.recipientFarmId
        end
        if viewerFarmId == invoice.recipientFarmId then
            return invoice.senderFarmId
        end
    end

    if tab == InvoicesFrame.TAB.INCOMING then
        return invoice.senderFarmId
    end

    return invoice.recipientFarmId
end

function InvoicesFrame:getInvoiceSortValue(invoice, tab, column)
    if column == "number" then
        return invoice.id or 0
    elseif column == "date" then
        local createdAt = invoice.createdAt or {}
        return (((createdAt.year or 0) * 100 + (createdAt.period or 0)) * 100 + (createdAt.day or 0)) * 10000 + (createdAt.hour or 0) * 100 + (createdAt.minute or 0)
    elseif column == "farm" then
        local farmId = self:getDisplayFarmIdForTab(invoice, tab)
        local farm = farmId ~= nil and g_farmManager:getFarmById(farmId) or nil
        return string.lower(tostring(farm ~= nil and farm.name or ""))
    elseif column == "services" then
        return string.lower(tostring(self:getInvoiceServiceSortText(invoice)))
    elseif column == "status" then
        if invoice.state == Invoice.STATE.PROPOSED then
            return 3
        end
        if invoice.state == Invoice.STATE.PAID then
            return 2
        end

        return (invoice.penaltyAmount or 0) > 0 and 1 or 0
    end

    if column == "discount" then
        return Invoice.computeTotalDiscountAmount(invoice.lineItems)
    end

    if column == "amount" then
        return (invoice.totalAmount or 0) + (invoice.penaltyAmount or 0)
    end

    return 0
end

function InvoicesFrame:getInvoiceServiceSortText(invoice)
    local manager = g_currentMission.invoicesManager
    local service = manager ~= nil and manager.service or nil
    for _, lineItem in ipairs(invoice.lineItems or {}) do
        local name = lineItem.name
        if (name == nil or name == "") and service ~= nil and lineItem.workTypeId ~= nil then
            local workType = service:getWorkTypeById(lineItem.workTypeId)
            name = workType ~= nil and workType.nameKey ~= nil and g_i18n:getText(workType.nameKey) or name
        end

        if name ~= nil and name ~= "" then
            return name
        end
    end

    return ""
end

---Called when player money changes
function InvoicesFrame:onMoneyChanged()
    self:updateBalanceDisplay()
end

---Updates balance display with current farm money
function InvoicesFrame:updateBalanceDisplay()
    if self.currentBalanceText == nil then
        return
    end
    if g_localPlayer ~= nil then
        local farm = g_farmManager:getFarmById(g_localPlayer.farmId)
        if farm then
            if farm.money <= -1 then
                self.currentBalanceText:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE, nil, true)
            else
                self.currentBalanceText:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY, nil, true)
            end
            local moneyText = g_i18n:formatMoney(farm.money, 0, true, false)
            self.currentBalanceText:setText(moneyText)
            if self.shopMoneyBox ~= nil then
                self.shopMoneyBox:invalidateLayout()
                self.shopMoneyBoxBg:setSize(self.shopMoneyBox.flowSizes[1] + 60 * g_pixelSizeScaledX)
            end
        end
    end
end

---Reloads invoice lists and updates visibility
function InvoicesFrame:refreshList()
    self.selectedInvoice = nil
    
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        self.listRenderer:setData({})
        self.listRenderer2:setData({})
        if self.listInvoices then self.listInvoices:reloadData() end
        if self.listInvoices2 then self.listInvoices2:reloadData() end
        self:refreshInvoiceSliders()
        if self.invoiceListContainer then self.invoiceListContainer:setVisible(false) end
        if self.emptyListContainer then self.emptyListContainer:setVisible(true) end
        if self.invoiceListContainer2 then self.invoiceListContainer2:setVisible(false) end
        if self.emptyListContainer2 then self.emptyListContainer2:setVisible(true) end
        self:updateSliderVisibility()
        return
    end
    
    local currentFarmId = self:getCurrentFarmId()
    self.incomingInvoices = manager:getIncomingInvoices(currentFarmId)
    self.outgoingInvoices = manager:getOutgoingInvoices(currentFarmId)
    
    self:sortInvoicesForTab(self.incomingInvoices, InvoicesFrame.TAB.INCOMING)
    self:sortInvoicesForTab(self.outgoingInvoices, InvoicesFrame.TAB.OUTGOING)
    
    self.listRenderer:setMode("incoming")
    self.listRenderer:setCurrentFarmId(currentFarmId)
    self.listRenderer:setData(self.incomingInvoices)
    self.listRenderer2:setMode("outgoing")
    self.listRenderer2:setCurrentFarmId(currentFarmId)
    self.listRenderer2:setData(self.outgoingInvoices)
    
    if self.listInvoices then self.listInvoices:reloadData() end
    if self.listInvoices2 then self.listInvoices2:reloadData() end
    self:refreshInvoiceSliders()
    
    local hasIncoming = #self.incomingInvoices > 0
    if self.invoiceListContainer then self.invoiceListContainer:setVisible(hasIncoming) end
    if self.emptyListContainer then self.emptyListContainer:setVisible(not hasIncoming) end
    
    local hasOutgoing = #self.outgoingInvoices > 0
    if self.invoiceListContainer2 then self.invoiceListContainer2:setVisible(hasOutgoing) end
    if self.emptyListContainer2 then self.emptyListContainer2:setVisible(not hasOutgoing) end

    self:updateSliderVisibility()
    self:updateButtonStates()
end

function InvoicesFrame:refreshInvoiceSliders()
    if self.invoiceSlider ~= nil and self.listInvoices ~= nil then
        self.invoiceSlider:onBindUpdate(self.listInvoices)
    end
    if self.invoiceSlider2 ~= nil and self.listInvoices2 ~= nil then
        self.invoiceSlider2:onBindUpdate(self.listInvoices2)
    end
end

function InvoicesFrame:updateSliderVisibility()
    if self.invoiceSliderBox then
        self.invoiceSliderBox:setVisible(self.currentTab == InvoicesFrame.TAB.INCOMING)
    end
    if self.invoiceSliderBox2 then
        self.invoiceSliderBox2:setVisible(self.currentTab == InvoicesFrame.TAB.OUTGOING)
    end
end

function InvoicesFrame:updateScreenEdgeSliders()
    local sliderBoxes = {
        self.invoiceSliderBox,
        self.invoiceSliderBox2
    }

    for _, sliderBox in ipairs(sliderBoxes) do
        if sliderBox ~= nil
            and sliderBox.absPosition ~= nil
            and sliderBox.absSize ~= nil
            and sliderBox.absSize[1] ~= nil then
            sliderBox:updateAbsolutePosition()

            local x = 1 - sliderBox.absSize[1] - InvoicesFrame.SCREEN_EDGE_SLIDER_MARGIN_X
            local y = sliderBox.absPosition[2] + InvoicesFrame.NATIVE_DOCKED_SLIDER_OFFSET_Y * (g_pixelSizeScaledY or 0)

            sliderBox:setAbsolutePosition(x, y)

            for _, child in ipairs(sliderBox.elements) do
                child:updateAbsolutePosition()
            end
        end
    end
end

---Called when list selection changes
-- @param integer index Selected row index
function InvoicesFrame:onSelectionChanged(index)
    local renderer = (self.currentTab == InvoicesFrame.TAB.INCOMING) and self.listRenderer or self.listRenderer2
    self.selectedInvoice = renderer:getSelectedInvoice()
    self:updateButtonStates()
end

---Returns the current player farm ID
-- @return integer farmId
function InvoicesFrame:getCurrentFarmId()
    local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if farm then
        return farm.farmId
    end
    return -1
end

function InvoicesFrame:canCancelInvoice(invoice, farmId)
    if invoice == nil then
        return false
    end

    if invoice.state == Invoice.STATE.PROPOSED then
        return farmId == invoice.recipientFarmId
    end

    return invoice.state == Invoice.STATE.NEW and farmId == invoice.senderFarmId
end

---Updates button enabled/disabled states based on selection
function InvoicesFrame:updateButtonStates()
    if self.btnNewInvoice == nil then
        return
    end

    local currentFarmId = self:getCurrentFarmId()
    local isSpectator = currentFarmId == FarmManager.SPECTATOR_FARM_ID or currentFarmId < 1
    
    self.btnNewInvoice.disabled = isSpectator

    local canPay = self.currentTab == InvoicesFrame.TAB.INCOMING and
                   self.selectedInvoice ~= nil and
                   self.selectedInvoice.state == Invoice.STATE.NEW and
                   currentFarmId == self.selectedInvoice.recipientFarmId and
                   not isSpectator
    local canValidate = self.currentTab == InvoicesFrame.TAB.INCOMING and
                        self.selectedInvoice ~= nil and
                        self.selectedInvoice.state == Invoice.STATE.PROPOSED and
                        currentFarmId == self.selectedInvoice.senderFarmId and
                        not isSpectator
    self.btnPay.text = self.i18n:getText(canValidate and "invoice_btn_validate" or "invoice_btn_payInvoice")
    self.btnPay.disabled = not (canPay or canValidate)
    
    local canCancel = self.currentTab == InvoicesFrame.TAB.OUTGOING and
                      self:canCancelInvoice(self.selectedInvoice, currentFarmId) and
                      not isSpectator
    self.btnDelete.text = self.i18n:getText("invoice_btn_cancel")
    self.btnDelete.disabled = not canCancel
    
    self.btnDetails.disabled = self.selectedInvoice == nil
    
    self:setMenuButtonInfoDirty()
end

---Opens invoice creation wizard
function InvoicesFrame:onClickNewInvoice()
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return
    end
    if not manager:getHasFarmManagerPermission() then
        InfoDialog.show(g_i18n:getText("invoice_error_permission_required"))
        return
    end
    local isMultiplayer = g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer
    if isMultiplayer then
        local farmCount = 0
        if g_farmManager then
            for _, farm in pairs(g_farmManager:getFarms()) do
                if farm.farmId ~= nil and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID and farm.farmId ~= 0 and farm.name ~= nil and farm.name ~= "" then
                    farmCount = farmCount + 1
                end
            end
        end
        if farmCount <= 1 then
            InfoDialog.show(g_i18n:getText("invoice_error_single_farm"))
            return
        end
    end
    -- Intermediate choice: create a normal invoice, or propose an invoice to be validated.
    g_gui:showDialog("InvoicesChoiceDialog")
end

---Shows payment confirmation dialog for selected invoice
function InvoicesFrame:onClickPay()
    if self.selectedInvoice == nil then
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
    local invoice = self.selectedInvoice
    local currentFarmId = self:getCurrentFarmId()
    if invoice.state == Invoice.STATE.PROPOSED then
        if currentFarmId ~= invoice.senderFarmId then
            return
        end
        YesNoDialog.show(self.onValidateConfirmed, self, self.i18n:getText("invoice_confirm_validate"))
        return
    end
    local totalDue = invoice.totalAmount + (invoice.penaltyAmount or 0)
    if not manager:farmHasSufficientBalance(currentFarmId, totalDue) then
        InfoDialog.show(g_i18n:getText("invoice_error_insufficient_funds"))
        return
    end
    local text = manager.service:buildPaymentConfirmText(invoice, self.i18n)

    YesNoDialog.show(self.onPayConfirmed, self, text)
end

---Handles payment confirmation result
-- @param boolean confirmed True if user confirmed
function InvoicesFrame:onPayConfirmed(confirmed)
    if confirmed and self.selectedInvoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:payInvoice(self.selectedInvoice.id)
        end
    end
end

---Handles proposal validation confirmation result
-- @param boolean confirmed True if user confirmed
function InvoicesFrame:onValidateConfirmed(confirmed)
    if confirmed and self.selectedInvoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:validateProposal(self.selectedInvoice.id)
        end
    end
end

---Shows delete confirmation dialog for selected invoice
function InvoicesFrame:onClickDelete()
    if self.selectedInvoice == nil then
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
    if not self:canCancelInvoice(self.selectedInvoice, self:getCurrentFarmId()) then
        return
    end
    local confirmKey = self.selectedInvoice.state == Invoice.STATE.PROPOSED
        and "invoice_confirm_cancel_proposal"
        or "invoice_confirm_cancel_invoice"
    local text = self.i18n:getText(confirmKey)
    YesNoDialog.show(self.onDeleteConfirmed, self, text)
end

---Handles delete confirmation result
-- @param boolean confirmed True if user confirmed
function InvoicesFrame:onDeleteConfirmed(confirmed)
    if confirmed and self.selectedInvoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:deleteInvoice(self.selectedInvoice.id)
        end
    end
end

---Opens detail dialog for selected invoice
function InvoicesFrame:onClickDetails()
    if self.selectedInvoice == nil then
        return
    end

    local invoice = self.selectedInvoice
    local isIncoming = (self.currentTab == InvoicesFrame.TAB.INCOMING)

    local dialog = g_gui:showDialog("InvoicesDetailDialog")
    if dialog and dialog.target then
        dialog.target:setInvoice(invoice, isIncoming)
    end
end

---Copies frame attributes from source element
-- @param table src Source element
function InvoicesFrame:copyAttributes(src)
    InvoicesFrame:superClass().copyAttributes(self, src)
    self.i18n = src.i18n
    self.messageCenter = src.messageCenter
end

---Deletes frame and cleans up references
function InvoicesFrame:delete()
    self.listRenderer = nil
    self.listRenderer2 = nil
    self.incomingInvoices = nil
    self.outgoingInvoices = nil
    self.menuButtonInfo = nil
    InvoicesFrame:superClass().delete(self)
end
