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
    self.fillTypes       = {}
    self.selectedMap     = {}
    self.callbackTarget  = nil
    self.callbackFunc    = nil
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
    self.selectedMap = {}
    self._isEditMode = false
    self:loadFillTypes()
    if self.listFillTypes ~= nil then
        self.listFillTypes:setSelectedIndex(1)
    end
    self:updateButtonStates()
end

function InvoicesFillTypeDialog:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc   = func
end

function InvoicesFillTypeDialog:setInitialSelection(nameMap)
    self._isEditMode = false
    if nameMap ~= nil then
        for _ in pairs(nameMap) do
            self._isEditMode = true
            break
        end
        for idx, ft in ipairs(self.fillTypes) do
            if nameMap[ft.name] then
                self.selectedMap[idx] = true
            end
        end
    end
    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
    self:updateButtonStates()
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
            local isBulk = fillType.isBulkType or false
            table.insert(self.fillTypes, {
                index            = fillType.index,
                name             = fillType.title or fillType.name or "?",
                pricePerLiter    = pricePerLiter,
                isBulkType       = isBulk,
                iconFilename     = fillType.hudOverlayFilename,
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
        if self._isEditMode then
            self.btnSelect:setDisabled(false)
        else
            local hasSelection = false
            for _ in pairs(self.selectedMap) do
                hasSelection = true
                break
            end
            self.btnSelect:setDisabled(not hasSelection)
        end
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

    local isSelected = self.selectedMap[index] == true

    local cellTick = cell:getDescendantByName("cellTick")
    if cellTick ~= nil then
        cellTick:setVisible(isSelected)
    end

    local cellIcon = cell:getDescendantByName("cellIcon")
    if cellIcon ~= nil then
        if ft.iconFilename ~= nil and ft.iconFilename ~= "" then
            cellIcon:setImageFilename(ft.iconFilename)
            cellIcon:setVisible(true)
        else
            cellIcon:setVisible(false)
        end
    end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(ft.name)
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(ft.pricePerLiter * 1000, 0, true, false))
    end
end

function InvoicesFillTypeDialog:onListSelectionChanged(list, section, index)
    self:updateButtonStates()
end

function InvoicesFillTypeDialog:toggleItemAtIndex(index)
    if index < 1 or index > #self.fillTypes then return end
    if self.selectedMap[index] then
        self.selectedMap[index] = nil
    else
        self.selectedMap[index] = true
    end
    local section = self.listFillTypes.selectedSectionIndex or 1
    self.listFillTypes:reloadData()
    self.listFillTypes:setSelectedItem(section, index, true)
    self:updateButtonStates()
end

function InvoicesFillTypeDialog:onFillTypeListClicked(list, section, index)
    if list ~= self.listFillTypes or index == nil or index < 1 or index > #self.fillTypes then return end
    self:toggleItemAtIndex(index)
end

function InvoicesFillTypeDialog:onClickSelect()
    local selectedItems = {}
    for idx, _ in pairs(self.selectedMap) do
        local ft = self.fillTypes[idx]
        if ft ~= nil then
            table.insert(selectedItems, ft)
        end
    end
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selectedItems)
    end
end

function InvoicesFillTypeDialog:onClickBack()
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, nil)
    end
end
