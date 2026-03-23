--[[
    InvoicesWizardStep2.lua
    Author: Squallqt
]]

InvoicesWizardStep2 = {}
local InvoicesWizardStep2_mt = Class(InvoicesWizardStep2, MessageDialog)

InvoicesWizardStep2.CONTROLS = {
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP = "titleSep",
    LIST_WORK_TYPES = "listWorkTypes",
    SUMMARY_LIST = "summaryList",
    SUMMARY_SLIDER_BOX = "summarySliderBox",
    BTN_NEXT = "btnNext",
    BTN_ADD = "btnAdd",
    BTN_REMOVE = "btnRemove",
    DIALOG_TEXT_ELEMENT = "dialogTextElement",
}

function InvoicesWizardStep2.new(target, customMt)
    local self = MessageDialog.new(target, customMt or InvoicesWizardStep2_mt)
    
    self.workTypes = {}
    self.selectedIndex = -1
    self.selectedItems = {}
    
    return self
end

function InvoicesWizardStep2:onLoad()
    InvoicesWizardStep2:superClass().onLoad(self)
    self:registerControls(InvoicesWizardStep2.CONTROLS)
end

function InvoicesWizardStep2:onGuiSetupFinished()
    InvoicesWizardStep2:superClass().onGuiSetupFinished(self)
    
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:setDataSource(self)
        self.listWorkTypes:setDelegate(self)
    end

    if self.summaryList ~= nil then
        self.summaryList:setDataSource(self)
    end
end

function InvoicesWizardStep2:resizeTitleSep()
    if self.titleSep == nil or self.mainTitleText == nil then return end

    if self._titleSepHeight == nil then
        self._titleSepHeight = self.titleSep.absSize[2]
    end

    local text = self.mainTitleText.text or ""
    local textWidth = getTextWidth(self.mainTitleText.textSize, text)
    local padding = 10 * 2 * g_pixelSizeScaledX
    local newWidth = textWidth + padding

    self.titleSep:setSize(newWidth, self._titleSepHeight)
    if self.titleSep.parent ~= nil and self.titleSep.parent.invalidateLayout ~= nil then
        self.titleSep.parent:invalidateLayout()
    end
end

function InvoicesWizardStep2:onOpen()
    InvoicesWizardStep2:superClass().onOpen(self)

    self:resizeTitleSep()

    self.selectedIndex = -1
    self.selectedItems = {}

    local state = InvoicesWizardState.getInstance()
    if state.selectedWorkTypes ~= nil and #state.selectedWorkTypes > 0 then
        for _, item in ipairs(state.selectedWorkTypes) do
            table.insert(self.selectedItems, item)
        end
    end

    self:loadWorkTypes()

    if self.listWorkTypes ~= nil and #self.workTypes > 0 then
        self.listWorkTypes:setSelectedIndex(1, 1, false)
    end

    self:updateButtonStates()
    self:updateSummaryText()
end

function InvoicesWizardStep2:onClose()
    InvoicesWizardStep2:superClass().onClose(self)
    
    local state = InvoicesWizardState.getInstance()
    state.selectedWorkTypes = self.selectedItems
end

function InvoicesWizardStep2:loadWorkTypes()
    self.workTypes = {}
    
    local manager = g_currentMission.invoicesManager
    if manager then
        self.workTypes = manager:getWorkTypes()
    end
    
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
    end
end

function InvoicesWizardStep2:isItemSelected(workType)
    for _, item in ipairs(self.selectedItems) do
        if item.nameKey == workType.nameKey then
            return true
        end
    end
    return false
end

function InvoicesWizardStep2:updateButtonStates()
    local hasSelection = (self.selectedIndex >= 1 and self.selectedIndex <= #self.workTypes)
    local hasItems = (#self.selectedItems > 0)
    local isInSummary = false
    
    if hasSelection then
        isInSummary = self:isItemSelected(self.workTypes[self.selectedIndex])
    end
    
    if self.btnNext ~= nil then
        self.btnNext:setDisabled(false)
    end
    if self.btnAdd ~= nil then
        self.btnAdd:setDisabled(not hasSelection)
    end
    if self.btnRemove ~= nil then
        self.btnRemove:setDisabled(not hasSelection or not isInSummary)
    end
end

function InvoicesWizardStep2:updateSummaryText()
    if self.summaryList ~= nil then
        self.summaryList:reloadData()
    end
    self:updateSummarySliderVisibility()
end

function InvoicesWizardStep2:updateSummarySliderVisibility()
    if self.summarySliderBox ~= nil then
        local maxVisible = math.floor(362 / 24)
        self.summarySliderBox:setVisible(#self.selectedItems > maxVisible)
    end
end

function InvoicesWizardStep2:getNumberOfSections()
    return 1
end

function InvoicesWizardStep2:getNumberOfItemsInSection(list, section)
    if list == self.summaryList then
        return #self.selectedItems
    end
    return #self.workTypes
end

function InvoicesWizardStep2:getTitleForSectionHeader(list, section)
    return nil
end

function InvoicesWizardStep2:getSectionHeaderHeight(list, section)
    return 0
end

function InvoicesWizardStep2:populateCellForItemInSection(list, section, index, cell)
    if list == self.summaryList then
        local workType = self.selectedItems[index]
        if workType == nil then return end

        local name = g_i18n:getText(workType.nameKey)
        local manager = g_currentMission.invoicesManager
        local unitKey = manager and manager:getUnitKey(workType.unit) or "invoices_unit_piece"
        local unitStr = g_i18n:getText(unitKey)
        local price = manager and manager:getAdjustedPrice(workType.id) or workType.basePrice or 0

        local priceStr
        if workType.unit == Invoice.UNIT_LITER then
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price, 1), unitStr)
        else
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price), unitStr)
        end

        local cellText = cell:getDescendantByName("cellText")
        if cellText ~= nil then
            cellText:setText(string.format("·  %s  —  %s", name, priceStr))
        end
        return
    end

    local workType = self.workTypes[index]
    if workType == nil then
        return
    end
    
    local cellName = cell:getDescendantByName("cellName")
    local cellPrice = cell:getDescendantByName("cellPrice")
    
    if cellName ~= nil then
        cellName:setText(g_i18n:getText(workType.nameKey))
    end
    
    if cellPrice ~= nil then
        local manager = g_currentMission.invoicesManager
        local unitKey = manager and manager:getUnitKey(workType.unit) or "invoices_unit_piece"
        local unitStr = g_i18n:getText(unitKey)
        local price = manager and manager:getAdjustedPrice(workType.id) or workType.basePrice or 0
        
        local priceStr
        if workType.unit == Invoice.UNIT_LITER then
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price, 1), unitStr)
        else
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price), unitStr)
        end
        
        cellPrice:setText(priceStr)
    end
end

function InvoicesWizardStep2:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateButtonStates()
end

function InvoicesWizardStep2:onClickNext()
    if #self.selectedItems < 1 then
        InfoDialog.show(g_i18n:getText("invoice_error_select_work"))
        return
    end
    
    local state = InvoicesWizardState.getInstance()
    state.selectedWorkTypes = self.selectedItems
    
    self:close()
    
    if not state:requiresFieldSelection() then
        state.selectedFields = {}
        state:buildAllLineItems()
        g_gui:showDialog("InvoicesWizardStep4")
    else
        g_gui:showDialog("InvoicesWizardStep3")
    end
end

function InvoicesWizardStep2:onClickAdd()
    if self.selectedIndex < 1 or self.selectedIndex > #self.workTypes then
        return
    end
    
    local workType = self.workTypes[self.selectedIndex]
    
    if self:isItemSelected(workType) then
        local name = g_i18n:getText(workType.nameKey)
        InfoDialog.show(string.format(g_i18n:getText("invoice_popup_already_selected"), name))
        return
    end
    
    table.insert(self.selectedItems, workType)
    self:updateSummaryText()
    self:updateButtonStates()
    
    local name = g_i18n:getText(workType.nameKey)
    InfoDialog.show(string.format(g_i18n:getText("invoice_popup_added"), name))
end

function InvoicesWizardStep2:onClickRemove()
    if self.selectedIndex < 1 or self.selectedIndex > #self.workTypes then
        return
    end
    
    local workType = self.workTypes[self.selectedIndex]
    
    for i, item in ipairs(self.selectedItems) do
        if item.nameKey == workType.nameKey then
            table.remove(self.selectedItems, i)
            break
        end
    end
    
    self:updateSummaryText()
    self:updateButtonStates()
    
    local name = g_i18n:getText(workType.nameKey)
    InfoDialog.show(string.format(g_i18n:getText("invoice_popup_removed"), name))
end

function InvoicesWizardStep2:onClickBack()
    self:close()
    g_gui:showDialog("InvoicesWizardStep1")
end

function InvoicesWizardStep2:onClickCancel()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self.selectedItems = {}
    self:close()
end

function InvoicesWizardStep2:delete()
    self.workTypes = nil
    self.selectedItems = nil
    InvoicesWizardStep2:superClass().delete(self)
end
