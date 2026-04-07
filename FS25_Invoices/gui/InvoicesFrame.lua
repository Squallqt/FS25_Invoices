--[[
    InvoicesFrame.lua
    InGameMenu tab frame: incoming/outgoing invoice lists with pay, delete, and detail navigation.
    Author: Squallqt
]]

InvoicesFrame = {}
InvoicesFrame._mt = Class(InvoicesFrame, TabbedMenuFrameElement)

InvoicesFrame.TAB = {
    INCOMING = 1,
    OUTGOING = 2
}

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
    
    return self
end

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
end

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
        text = self.i18n:getText("invoice_btn_deleteInvoice"),
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

function InvoicesFrame:getMenuButtonInfo()
    if self.menuButtonInfo == nil then
        return {}
    end
    return self.menuButtonInfo[self.currentTab] or {}
end

function InvoicesFrame:onFrameOpen()
    InvoicesFrame:superClass().onFrameOpen(self)
    g_currentMission.invoicesFrame = self

    self.currentTab = InvoicesFrame.TAB.INCOMING

    if self.categoryHeaderIcon then
        local iconPath = Utils.getFilename('images/Icon_black.dds', Invoices.modDirectory)
        self.categoryHeaderIcon:setImageFilename(iconPath)
    end

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

    self:refreshList()

    self:setMenuButtonInfoDirty()
end

function InvoicesFrame:onFrameClose()
    InvoicesFrame:superClass().onFrameClose(self)
    g_messageCenter:unsubscribeAll(self)
    g_currentMission.invoicesFrame = nil
end

function InvoicesFrame:onClickIncoming()
    self.subCategoryPaging:setState(InvoicesFrame.TAB.INCOMING, true)
    self:setMenuButtonInfoDirty()
end

function InvoicesFrame:onClickOutgoing()
    self.subCategoryPaging:setState(InvoicesFrame.TAB.OUTGOING, true)
    self:setMenuButtonInfoDirty()
end

function InvoicesFrame:updateSubCategoryPages()
    self.currentTab = self.subCategoryPaging:getState()
    
    for k, v in pairs(self.subCategoryPages) do
        v:setVisible(k == self.currentTab)
    end
    
    self:refreshList()
    self:setMenuButtonInfoDirty()
end

function InvoicesFrame:onMoneyChanged()
    self:updateBalanceDisplay()
end

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

function InvoicesFrame:refreshList()
    self.selectedInvoice = nil
    
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        self.listRenderer:setData({})
        self.listRenderer2:setData({})
        if self.listInvoices then self.listInvoices:reloadData() end
        if self.listInvoices2 then self.listInvoices2:reloadData() end
        if self.invoiceListContainer then self.invoiceListContainer:setVisible(false) end
        if self.emptyListContainer then self.emptyListContainer:setVisible(true) end
        if self.invoiceListContainer2 then self.invoiceListContainer2:setVisible(false) end
        if self.emptyListContainer2 then self.emptyListContainer2:setVisible(true) end
        return
    end
    
    local currentFarmId = self:getCurrentFarmId()
    self.incomingInvoices = manager:getIncomingInvoices(currentFarmId)
    self.outgoingInvoices = manager:getOutgoingInvoices(currentFarmId)
    
    local sortFunc = function(a, b)
        return a.id > b.id
    end
    
    table.sort(self.incomingInvoices, sortFunc)
    table.sort(self.outgoingInvoices, sortFunc)
    
    self.listRenderer:setMode("incoming")
    self.listRenderer:setData(self.incomingInvoices)
    self.listRenderer2:setMode("outgoing")
    self.listRenderer2:setData(self.outgoingInvoices)
    
    if self.listInvoices then self.listInvoices:reloadData() end
    if self.listInvoices2 then self.listInvoices2:reloadData() end
    
    local hasIncoming = #self.incomingInvoices > 0
    if self.invoiceListContainer then self.invoiceListContainer:setVisible(hasIncoming) end
    if self.emptyListContainer then self.emptyListContainer:setVisible(not hasIncoming) end
    
    local hasOutgoing = #self.outgoingInvoices > 0
    if self.invoiceListContainer2 then self.invoiceListContainer2:setVisible(hasOutgoing) end
    if self.emptyListContainer2 then self.emptyListContainer2:setVisible(not hasOutgoing) end
    
    self:updateButtonStates()
end

function InvoicesFrame:onSelectionChanged(index)
    local renderer = (self.currentTab == InvoicesFrame.TAB.INCOMING) and self.listRenderer or self.listRenderer2
    self.selectedInvoice = renderer:getSelectedInvoice()
    self:updateButtonStates()
end

function InvoicesFrame:getCurrentFarmId()
    local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if farm then
        return farm.farmId
    end
    return -1
end

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
                   not isSpectator
    self.btnPay.disabled = not canPay
    
    local canDelete = self.currentTab == InvoicesFrame.TAB.OUTGOING and
                      self.selectedInvoice ~= nil and 
                      not isSpectator
    self.btnDelete.disabled = not canDelete
    
    self.btnDetails.disabled = self.selectedInvoice == nil
    
    self:setMenuButtonInfoDirty()
end

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
    local state = InvoicesWizardState.getInstance()
    state:reset()
    g_gui:showDialog("InvoicesMainDashboard")
end

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
    local totalDue = invoice.totalAmount + (invoice.penaltyAmount or 0)
    if not manager:farmHasSufficientBalance(currentFarmId, totalDue) then
        InfoDialog.show(g_i18n:getText("invoice_error_insufficient_funds"))
        return
    end
    local senderFarm = g_farmManager:getFarmById(invoice.senderFarmId)
    local farmName = senderFarm and senderFarm.name or ""
    local text = string.format(self.i18n:getText("invoice_confirm_pay"),
                               g_i18n:formatMoney(totalDue),
                               farmName)

    local details = {}
    if (invoice.vatAmount or 0) > 0 then
        local vatStr = g_i18n:formatMoney(invoice.vatAmount, 0, true, false)
        local vatLabel = g_i18n:getText("invoice_label_vat")
        table.insert(details, string.format(g_i18n:getText("invoice_notification_vat_incl"), vatLabel, vatStr))
    end
    if (invoice.penaltyAmount or 0) > 0 then
        local penStr = g_i18n:formatMoney(invoice.penaltyAmount, 0, true, false)
        table.insert(details, string.format(g_i18n:getText("invoice_notification_penalty_incl"), penStr))
    end
    if #details > 0 then
        text = text .. "\n(" .. table.concat(details, ", ") .. ")"
    end

    YesNoDialog.show(self.onPayConfirmed, self, text)
end

function InvoicesFrame:onPayConfirmed(confirmed)
    if confirmed and self.selectedInvoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:payInvoice(self.selectedInvoice.id)
        end
    end
end

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
    local text = self.i18n:getText("invoice_confirm_delete")
    YesNoDialog.show(self.onDeleteConfirmed, self, text)
end

function InvoicesFrame:onDeleteConfirmed(confirmed)
    if confirmed and self.selectedInvoice then
        local manager = g_currentMission.invoicesManager
        if manager then
            manager:deleteInvoice(self.selectedInvoice.id)
        end
    end
end

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

function InvoicesFrame:copyAttributes(src)
    InvoicesFrame:superClass().copyAttributes(self, src)
    self.i18n = src.i18n
    self.messageCenter = src.messageCenter
end

function InvoicesFrame:delete()
    self.listRenderer = nil
    self.listRenderer2 = nil
    self.incomingInvoices = nil
    self.outgoingInvoices = nil
    self.menuButtonInfo = nil
    InvoicesFrame:superClass().delete(self)
end
