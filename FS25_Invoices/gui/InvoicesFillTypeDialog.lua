--[[
    InvoicesFillTypeDialog.lua
    Author: Squallqt
]]

InvoicesFillTypeDialog = {}
local InvoicesFillTypeDialog_mt = Class(InvoicesFillTypeDialog, DialogElement)

InvoicesFillTypeDialog.CONTROLS = {
    LIST_FILL_TYPES = "listFillTypes",
    BTN_SELECT      = "btnSelect",
}

function InvoicesFillTypeDialog.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesFillTypeDialog_mt)
    self.fillTypes      = {}
    self.selectedIndex  = -1
    self.callbackTarget = nil
    self.callbackFunc   = nil
    return self
end

function InvoicesFillTypeDialog:onLoad()
    InvoicesFillTypeDialog:superClass().onLoad(self)
    self:registerControls(InvoicesFillTypeDialog.CONTROLS)
end

function InvoicesFillTypeDialog:onGuiSetupFinished()
    InvoicesFillTypeDialog:superClass().onGuiSetupFinished(self)
    if self.listFillTypes ~= nil then
        self.listFillTypes:setDataSource(self)
        self.listFillTypes:setDelegate(self)
    end
end

function InvoicesFillTypeDialog:onOpen()
    InvoicesFillTypeDialog:superClass().onOpen(self)
    self.selectedIndex = -1
    self:loadFillTypes()
    self:updateButtonStates()
end

function InvoicesFillTypeDialog:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc   = func
end

function InvoicesFillTypeDialog:loadFillTypes()
    self.fillTypes = {}

    local fillTypeManager = g_fillTypeManager
    if fillTypeManager == nil then return end

    for _, fillType in pairs(fillTypeManager.fillTypes) do
        if fillType ~= nil and fillType.showOnPriceTable then
            local pricePerLiter = 0
            if g_currentMission ~= nil and g_currentMission.economyManager ~= nil then
                pricePerLiter = g_currentMission.economyManager:getPricePerLiter(fillType.index) or 0
            end
            if pricePerLiter <= 0 and g_priceManager ~= nil then
                pricePerLiter = g_priceManager:getPricePerLiter(fillType.index) or 0
            end
            table.insert(self.fillTypes, {
                index         = fillType.index,
                name          = fillType.title or fillType.name or "?",
                pricePerLiter = pricePerLiter,
            })
        end
    end

    table.sort(self.fillTypes, function(a, b) return a.name < b.name end)

    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
end

function InvoicesFillTypeDialog:updateButtonStates()
    if self.btnSelect ~= nil then
        self.btnSelect:setDisabled(self.selectedIndex < 1 or self.selectedIndex > #self.fillTypes)
    end
end

function InvoicesFillTypeDialog:getNumberOfSections()
    return 1
end

function InvoicesFillTypeDialog:getNumberOfItemsInSection(list, section)
    return #self.fillTypes
end

function InvoicesFillTypeDialog:getTitleForSectionHeader(list, section)
    return ""
end

function InvoicesFillTypeDialog:populateCellForItemInSection(list, section, index, cell)
    local ft = self.fillTypes[index]
    if ft == nil then return end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(ft.name)
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(ft.pricePerLiter * 1000, 2, true, false))
    end
end

function InvoicesFillTypeDialog:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateButtonStates()
end

function InvoicesFillTypeDialog:onClickSelect()
    if self.selectedIndex < 1 or self.selectedIndex > #self.fillTypes then return end
    local selected = self.fillTypes[self.selectedIndex]
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selected)
    end
end

function InvoicesFillTypeDialog:onClickBack()
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, nil)
    end
end
