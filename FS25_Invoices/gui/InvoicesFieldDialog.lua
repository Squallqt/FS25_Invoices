--[[
    InvoicesFieldDialog.lua
    Author: Squallqt
]]

InvoicesFieldDialog = {}
local InvoicesFieldDialog_mt = Class(InvoicesFieldDialog, DialogElement)

InvoicesFieldDialog.CONTROLS = {
    LIST_FIELDS = "listFields",
    BTN_SELECT = "btnSelect",
}

function InvoicesFieldDialog.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesFieldDialog_mt)
    
    self.fields = {}
    self.selectedIndex = -1
    self.callbackTarget = nil
    self.callbackFunc = nil
    
    return self
end

function InvoicesFieldDialog:onLoad()
    InvoicesFieldDialog:superClass().onLoad(self)
    self:registerControls(InvoicesFieldDialog.CONTROLS)
    
    Logging.devInfo("[InvoicesFieldDialog] onLoad() - Controls registered")
end

function InvoicesFieldDialog:onGuiSetupFinished()
    InvoicesFieldDialog:superClass().onGuiSetupFinished(self)
    
    if self.listFields ~= nil then
        self.listFields:setDataSource(self)
        self.listFields:setDelegate(self)
    end
    
    Logging.devInfo("[InvoicesFieldDialog] onGuiSetupFinished() - List configured")
end

function InvoicesFieldDialog:onOpen()
    InvoicesFieldDialog:superClass().onOpen(self)
    
    self.selectedIndex = -1
    self:loadFields()
    self:updateButtonStates()
end

function InvoicesFieldDialog:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc = func
end

function InvoicesFieldDialog:loadFields()
    self.fields = {}
    
    local fieldManager = g_fieldManager
    if fieldManager == nil then
        return
    end
    
    local currentFarmId = g_currentMission:getFarmId()
    
    local fields = fieldManager:getFields()
    if fields then
        for _, field in pairs(fields) do
            if field.fieldId and field.fieldArea then
                local farmId = 0
                if field.farmland then
                    farmId = field.farmland.farmId or 0
                end
                
                if farmId == currentFarmId then
                    table.insert(self.fields, {
                        id = field.fieldId,
                        area = field.fieldArea,
                        farmId = farmId
                    })
                end
            end
        end
    end
    
    table.sort(self.fields, function(a, b)
        return a.id < b.id
    end)
    
    if self.listFields ~= nil then
        self.listFields:reloadData()
    end
end

function InvoicesFieldDialog:updateButtonStates()
    if self.btnSelect ~= nil then
        self.btnSelect:setDisabled(self.selectedIndex < 1 or self.selectedIndex > #self.fields)
    end
end

function InvoicesFieldDialog:getNumberOfSections()
    return 1
end

function InvoicesFieldDialog:getNumberOfItemsInSection(list, section)
    return #self.fields
end

function InvoicesFieldDialog:getTitleForSectionHeader(list, section)
    return ""
end

function InvoicesFieldDialog:populateCellForItemInSection(list, section, index, cell)
    local field = self.fields[index]
    if field == nil then
        return
    end
    
    local cellId = cell:getDescendantByName("cellId")
    local cellArea = cell:getDescendantByName("cellArea")
    
    if cellId ~= nil then
        cellId:setText(string.format(g_i18n:getText("invoice_format_fieldId"), field.id))
    end
    
    if cellArea ~= nil then
        cellArea:setText(string.format("%.2f ha", field.area))
    end
end

function InvoicesFieldDialog:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateButtonStates()
end

function InvoicesFieldDialog:onClickSelect()
    if self.selectedIndex < 1 or self.selectedIndex > #self.fields then
        return
    end
    
    local selectedField = self.fields[self.selectedIndex]
    
    self:close()
    
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selectedField)
    end
end

function InvoicesFieldDialog:onClickBack()
    self:close()
end
