--[[
    InvoicesWizardStep2.lua
    Author: Squallqt
]]

InvoicesWizardStep2 = {}
local InvoicesWizardStep2_mt = Class(InvoicesWizardStep2, DialogElement)

InvoicesWizardStep2.CONTROLS = {
    TITLE_BADGE_BG = "titleBadgeBg",
    MAIN_TITLE_TEXT = "mainTitleText",
    LIST_WORK_TYPES = "listWorkTypes",
    SUMMARY_TEXT = "summaryText",
    BTN_NEXT = "btnNext",
    BTN_ADD = "btnAdd",
    BTN_REMOVE = "btnRemove",
    DIALOG_TEXT_ELEMENT = "dialogTextElement",
}

function InvoicesWizardStep2.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesWizardStep2_mt)
    
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
end

function InvoicesWizardStep2:resizeTitleBadge()
    if self.mainTitleText ~= nil and self.titleBadgeBg ~= nil then
        local textWidth = getTextWidth(self.mainTitleText.textSize, self.mainTitleText.text)
        local paddingX = self.mainTitleText.textSize * 0.8
        local badgeWidth = textWidth + paddingX * 2
        local badgeHeight = self.titleBadgeBg.absSize[2]
        self.titleBadgeBg:setSize(badgeWidth, badgeHeight)
    end
end

function InvoicesWizardStep2:onOpen()
    InvoicesWizardStep2:superClass().onOpen(self)
    self:resizeTitleBadge()
    
    self.selectedIndex = -1
    
    local state = InvoicesWizardState.getInstance()
    if state.selectedWorkTypes ~= nil and #state.selectedWorkTypes > 0 then
        self.selectedItems = state.selectedWorkTypes
    else
        self.selectedItems = {}
    end
    
    self:loadWorkTypes()
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
    if self.summaryText == nil then
        return
    end
    
    if #self.selectedItems == 0 then
        self.summaryText:setText("")
        return
    end
    
    local lines = {}
    local manager = g_currentMission.invoicesManager
    
    for _, workType in ipairs(self.selectedItems) do
        local name = g_i18n:getText(workType.nameKey)
        local unitKey = manager and manager:getUnitKey(workType.unit) or "invoices_unit_piece"
        local unitStr = g_i18n:getText(unitKey)
        local price = manager and manager:getAdjustedPrice(workType.id) or workType.basePrice or 0
        
        local priceStr
        if workType.unit == Invoice.UNIT_LITER then
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price, 1), unitStr)
        else
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price), unitStr)
        end
        
        table.insert(lines, string.format("·  %s  —  %s", name, priceStr))
    end
    
    self.summaryText:setText(table.concat(lines, "\n"))
end

function InvoicesWizardStep2:getNumberOfSections()
    return 1
end

function InvoicesWizardStep2:getNumberOfItemsInSection(list, section)
    return #self.workTypes
end

function InvoicesWizardStep2:getTitleForSectionHeader(list, section)
    return nil
end

function InvoicesWizardStep2:getSectionHeaderHeight(list, section)
    return 0
end

function InvoicesWizardStep2:populateCellForItemInSection(list, section, index, cell)
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
    self:close()
end

function InvoicesWizardStep2:delete()
    self.workTypes = nil
    self.selectedItems = nil
    InvoicesWizardStep2:superClass().delete(self)
end
