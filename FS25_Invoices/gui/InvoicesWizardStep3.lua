--[[
    InvoicesWizardStep3.lua
    Author: Squallqt
]]

InvoicesWizardStep3 = {}
local InvoicesWizardStep3_mt = Class(InvoicesWizardStep3, DialogElement)

InvoicesWizardStep3.CONTROLS = {
    TITLE_BADGE_BG = "titleBadgeBg",
    MAIN_TITLE_TEXT = "mainTitleText",
    LIST_FIELDS = "listFields",
    SUMMARY_TEXT = "summaryText",
    BTN_NEXT = "btnNext",
    BTN_ADD = "btnAdd",
    BTN_REMOVE = "btnRemove",
    DIALOG_TEXT_ELEMENT = "dialogTextElement",
}

function InvoicesWizardStep3.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesWizardStep3_mt)
    
    self.clientFields = {}
    self.otherFields = {}
    self.selectedIndex = -1
    self.selectedSection = -1
    self.selectedItems = {}
    
    return self
end

function InvoicesWizardStep3:onLoad()
    InvoicesWizardStep3:superClass().onLoad(self)
    self:registerControls(InvoicesWizardStep3.CONTROLS)
end

function InvoicesWizardStep3:onGuiSetupFinished()
    InvoicesWizardStep3:superClass().onGuiSetupFinished(self)
    
    if self.listFields ~= nil then
        self.listFields:setDataSource(self)
        self.listFields:setDelegate(self)
    end
end

function InvoicesWizardStep3:resizeTitleBadge()
    if self.mainTitleText ~= nil and self.titleBadgeBg ~= nil then
        local textWidth = getTextWidth(self.mainTitleText.textSize, self.mainTitleText.text)
        local paddingX = self.mainTitleText.textSize * 0.8
        local badgeWidth = textWidth + paddingX * 2
        local badgeHeight = self.titleBadgeBg.absSize[2]
        self.titleBadgeBg:setSize(badgeWidth, badgeHeight)
    end
end

function InvoicesWizardStep3:onOpen()
    InvoicesWizardStep3:superClass().onOpen(self)
    self:resizeTitleBadge()
    
    self.selectedIndex = -1
    self.selectedSection = -1
    
    local state = InvoicesWizardState.getInstance()
    if state.selectedFields ~= nil and #state.selectedFields > 0 then
        self.selectedItems = state.selectedFields
    else
        self.selectedItems = {}
    end
    
    self:loadFields()
    self:updateButtonStates()
    self:updateSummaryText()
end

function InvoicesWizardStep3:onClose()
    InvoicesWizardStep3:superClass().onClose(self)
    
    local state = InvoicesWizardState.getInstance()
    state.selectedFields = self.selectedItems
end

function InvoicesWizardStep3:loadFields()
    self.clientFields = {}
    self.otherFields = {}
    
    local state = InvoicesWizardState.getInstance()
    local recipientFarmId = state.recipientFarmId
    
    if recipientFarmId == nil then
        Logging.warning("[InvoicesWizardStep3] No recipient selected, cannot load fields")
        return
    end
    
    if g_farmlandManager == nil or g_farmlandManager.farmlands == nil then
        return
    end
    
    for farmlandId, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.field ~= nil then
            local field = farmland.field
            local ownerFarmId = farmland.farmId
            local area = field:getAreaHa()
            
            local fieldData = {
                id = farmlandId,
                area = area,
            }
            
            if ownerFarmId == recipientFarmId then
                table.insert(self.clientFields, fieldData)
            else
                table.insert(self.otherFields, fieldData)
            end
        end
    end
    
    table.sort(self.clientFields, function(a, b) return a.id < b.id end)
    table.sort(self.otherFields, function(a, b) return a.id < b.id end)
    
    if self.listFields ~= nil then
        self.listFields:reloadData()
    end
end

function InvoicesWizardStep3:getSelectedFieldData()
    if self.selectedSection == 1 then
        return self.clientFields[self.selectedIndex]
    elseif self.selectedSection == 2 then
        return self.otherFields[self.selectedIndex]
    end
    return nil
end

function InvoicesWizardStep3:isItemSelected(fieldData)
    for _, item in ipairs(self.selectedItems) do
        if item.id == fieldData.id then
            return true
        end
    end
    return false
end

function InvoicesWizardStep3:updateButtonStates()
    local hasSelection = (self.selectedSection > 0 and self.selectedIndex > 0)
    local hasItems = (#self.selectedItems > 0)
    local isInSummary = false
    
    if hasSelection then
        local fieldData = self:getSelectedFieldData()
        if fieldData ~= nil then
            isInSummary = self:isItemSelected(fieldData)
        end
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

function InvoicesWizardStep3:updateSummaryText()
    if self.summaryText == nil then
        return
    end
    
    if #self.selectedItems == 0 then
        self.summaryText:setText("")
        return
    end
    
    local lines = {}
    
    for _, fieldData in ipairs(self.selectedItems) do
        local fieldName = string.format(g_i18n:getText("invoice_format_field_id"), fieldData.id)
        local areaText = string.format("%.2f ha", fieldData.area)
        table.insert(lines, string.format("·  %s  —  %s", fieldName, areaText))
    end
    
    self.summaryText:setText(table.concat(lines, "\n"))
end

function InvoicesWizardStep3:getNumberOfSections()
    return 2
end

function InvoicesWizardStep3:getNumberOfItemsInSection(list, section)
    if section == 1 then
        return #self.clientFields
    elseif section == 2 then
        return #self.otherFields
    end
    return 0
end

function InvoicesWizardStep3:getTitleForSectionHeader(list, section)
    if section == 1 then
        return g_i18n:getText("invoice_wizard_client_fields")
    elseif section == 2 then
        return g_i18n:getText("invoice_wizard_other_fields")
    end
    return ""
end

function InvoicesWizardStep3:getSectionHeaderHeight(list, section)
    return 30
end

function InvoicesWizardStep3:getCellTypeForSectionHeader(list, section)
    return "section"
end

function InvoicesWizardStep3:getCellTypeForItemInSection(list, section, index)
    return "fieldTemplate"
end

function InvoicesWizardStep3:populateCellForItemInSection(list, section, index, cell)
    local fieldData = nil
    
    if section == 1 then
        fieldData = self.clientFields[index]
    elseif section == 2 then
        fieldData = self.otherFields[index]
    end
    
    if fieldData == nil then
        return
    end
    
    local cellName = cell:getDescendantByName("cellName")
    local cellArea = cell:getDescendantByName("cellArea")
    
    if cellName ~= nil then
        cellName:setText(string.format(g_i18n:getText("invoice_format_field_id"), fieldData.id))
    end
    
    if cellArea ~= nil then
        cellArea:setText(string.format("%.2f ha", fieldData.area))
    end
end

function InvoicesWizardStep3:onListSelectionChanged(list, section, index)
    self.selectedSection = section
    self.selectedIndex = index
    self:updateButtonStates()
end

function InvoicesWizardStep3:onClickNext()
    if #self.selectedItems < 1 then
        InfoDialog.show(g_i18n:getText("invoice_wizard_no_items"))
        return
    end
    
    local state = InvoicesWizardState.getInstance()
    state.selectedFields = self.selectedItems
    state:buildAllLineItems()
    
    self:close()
    g_gui:showDialog("InvoicesWizardStep4")
end

function InvoicesWizardStep3:onClickAdd()
    local fieldData = self:getSelectedFieldData()
    if fieldData == nil then
        return
    end
    
    if self:isItemSelected(fieldData) then
        local text = string.format(g_i18n:getText("invoice_format_field"), fieldData.id, fieldData.area)
        InfoDialog.show(string.format(g_i18n:getText("invoice_popup_already_selected"), text))
        return
    end
    
    table.insert(self.selectedItems, fieldData)
    self:updateSummaryText()
    self:updateButtonStates()
    
    local text = string.format(g_i18n:getText("invoice_format_field"), fieldData.id, fieldData.area)
    InfoDialog.show(string.format(g_i18n:getText("invoice_popup_added"), text))
end

function InvoicesWizardStep3:onClickRemove()
    local fieldData = self:getSelectedFieldData()
    if fieldData == nil then
        return
    end
    
    for i, item in ipairs(self.selectedItems) do
        if item.id == fieldData.id then
            table.remove(self.selectedItems, i)
            break
        end
    end
    
    self:updateSummaryText()
    self:updateButtonStates()
    
    local text = string.format(g_i18n:getText("invoice_format_field"), fieldData.id, fieldData.area)
    InfoDialog.show(string.format(g_i18n:getText("invoice_popup_removed"), text))
end

function InvoicesWizardStep3:onClickBack()
    self:close()
    g_gui:showDialog("InvoicesWizardStep2")
end

function InvoicesWizardStep3:onClickCancel()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self:close()
end

function InvoicesWizardStep3:delete()
    self.clientFields = nil
    self.otherFields = nil
    self.selectedItems = nil
    InvoicesWizardStep3:superClass().delete(self)
end
