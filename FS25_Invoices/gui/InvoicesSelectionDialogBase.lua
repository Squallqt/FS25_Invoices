-- Copyright © 2026 Squallqt. All rights reserved.
-- Shared behavior for invoice selection dialogs backed by a single SmoothList.
InvoicesSelectionDialogBase = {}
local InvoicesSelectionDialogBase_mt = Class(InvoicesSelectionDialogBase, DialogElement)

function InvoicesSelectionDialogBase.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesSelectionDialogBase_mt)
    self.callbackTarget = nil
    self.callbackFunc = nil
    self._isEditMode = false
    self._itemsProperty = nil
    self._loaderFunctionName = nil
    return self
end

function InvoicesSelectionDialogBase:setupSelectionDialog(itemsProperty, loaderFunctionName)
    self._itemsProperty = itemsProperty
    self._loaderFunctionName = loaderFunctionName
end

function InvoicesSelectionDialogBase:onLoad()
    InvoicesSelectionDialogBase:superClass().onLoad(self)
    self:registerControls(self.CONTROLS)
end

function InvoicesSelectionDialogBase:onGuiSetupFinished()
    InvoicesSelectionDialogBase:superClass().onGuiSetupFinished(self)
    if self.listFillTypes ~= nil then
        self.listFillTypes:setDataSource(self)
        self.listFillTypes:setDelegate(self)
    end
end

function InvoicesSelectionDialogBase:onOpen()
    InvoicesSelectionDialogBase:superClass().onOpen(self)
    self:resizeTitleSep()
    self:resetSelectionState()
    self._isEditMode = false

    local loader = self._loaderFunctionName ~= nil and self[self._loaderFunctionName] or nil
    if loader ~= nil then
        loader(self)
    end

    if self.listFillTypes ~= nil then
        self.listFillTypes:setSelectedIndex(1)
    end
    self:updateSelectionControls()
    self:updateButtonStates()
end

function InvoicesSelectionDialogBase:resizeTitleSep()
    InvoicesGuiUtils.resizeTitleSeparator(self.mainTitleText, self.titleSep)
end

function InvoicesSelectionDialogBase:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc = func
end

function InvoicesSelectionDialogBase:setPlayerFarmId(farmId)
    self._playerFarmId = farmId
end

function InvoicesSelectionDialogBase:resetSelectionState()
    self.selectedMap = {}
end

function InvoicesSelectionDialogBase:getItems()
    if self._itemsProperty ~= nil then
        return self[self._itemsProperty] or {}
    end
    return {}
end

function InvoicesSelectionDialogBase:reloadSelectionList()
    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
end

function InvoicesSelectionDialogBase:reloadAndRestoreSelection(index)
    if self.listFillTypes ~= nil then
        local section = self.listFillTypes.selectedSectionIndex or 1
        self.listFillTypes:reloadData()
        self.listFillTypes:setSelectedItem(section, index, true)
    end
end

function InvoicesSelectionDialogBase:setInitialSelection(selectionMap)
    self._isEditMode = false
    if selectionMap ~= nil then
        for _ in pairs(selectionMap) do
            self._isEditMode = true
            break
        end
        self:applyInitialSelection(selectionMap)
    end
    self:reloadSelectionList()
    self:updateSelectionControls()
    self:updateButtonStates()
end

function InvoicesSelectionDialogBase:applyInitialSelection(selectionMap)
    for index, item in ipairs(self:getItems()) do
        local key = self:getInitialSelectionKey(item, index)
        if key ~= nil and selectionMap[key] then
            self:setItemSelected(item, index, true)
        end
    end
end

function InvoicesSelectionDialogBase:getInitialSelectionKey(item, index)
    return item.name
end

function InvoicesSelectionDialogBase:getSelectionMap()
    return self.selectedMap or {}
end

function InvoicesSelectionDialogBase:getItemSelectionKey(item, index)
    return index
end

function InvoicesSelectionDialogBase:setItemSelected(item, index, selected)
    local key = self:getItemSelectionKey(item, index)
    if key == nil then return end

    local selectionMap = self:getSelectionMap()
    if selected then
        selectionMap[key] = true
    else
        selectionMap[key] = nil
    end
end

function InvoicesSelectionDialogBase:isItemSelected(item, index)
    local key = self:getItemSelectionKey(item, index)
    return key ~= nil and self:isSelectionValueActive(self:getSelectionMap()[key])
end

function InvoicesSelectionDialogBase:isSelectionValueActive(value)
    return value == true
end

function InvoicesSelectionDialogBase:hasActiveSelection()
    for _, value in pairs(self:getSelectionMap()) do
        if self:isSelectionValueActive(value) then
            return true
        end
    end
    return false
end

function InvoicesSelectionDialogBase:updateButtonStates()
    if self.btnSelect ~= nil then
        self.btnSelect:setDisabled(not self._isEditMode and not self:hasActiveSelection())
    end
end

function InvoicesSelectionDialogBase:getNumberOfSections()
    return 1
end

function InvoicesSelectionDialogBase:getNumberOfItemsInSection(list, section)
    return #self:getItems()
end

function InvoicesSelectionDialogBase:populateCellForItemInSection(list, section, index, cell)
    local item = self:getItems()[index]
    if item == nil then return end

    self:populateSelectionIndicator(cell, item, index)
    self:populateCellIcon(cell, item.iconFilename)
    self:setCellText(cell, "cellName", item.name or item.displayName or "")
    self:populateAdditionalCellFields(item, index, cell)
    self:setCellText(cell, "cellPrice", self:getItemPriceText(item, index))
end

function InvoicesSelectionDialogBase:populateSelectionIndicator(cell, item, index)
    local dotText, prefixText, checkVisible = self:getSelectionIndicatorState(item, index)
    self:setCellText(cell, "cellDot", dotText)
    self:setCellText(cell, "cellPrefix", prefixText)

    local cellCheck = cell:getDescendantByName("cellCheck")
    if cellCheck ~= nil then
        cellCheck:setVisible(checkVisible)
    end
end

function InvoicesSelectionDialogBase:getSelectionIndicatorState(item, index)
    local isSelected = self:isItemSelected(item, index)
    return isSelected and "" or "·", "", isSelected
end

function InvoicesSelectionDialogBase:populateCellIcon(cell, iconFilename)
    local cellIcon = cell:getDescendantByName("cellIcon")
    if cellIcon ~= nil then
        if iconFilename ~= nil and iconFilename ~= "" then
            cellIcon:setImageFilename(iconFilename)
            cellIcon:setVisible(true)
        else
            cellIcon:setVisible(false)
        end
    end
end

function InvoicesSelectionDialogBase:setCellText(cell, name, text)
    local element = cell:getDescendantByName(name)
    if element ~= nil and text ~= nil then
        element:setText(text)
    end
end

function InvoicesSelectionDialogBase:getItemPrice(item, index)
    return item.sellPrice or item.price or 0
end

function InvoicesSelectionDialogBase:getItemPriceText(item, index)
    return g_i18n:formatMoney(self:getItemPrice(item, index), 0, true, false)
end

function InvoicesSelectionDialogBase:populateAdditionalCellFields(item, index, cell)
end

function InvoicesSelectionDialogBase:onListSelectionChanged(list, section, index)
    self:onSelectionIndexChanged(index)
    self:updateSelectionControls()
    self:updateButtonStates()
end

function InvoicesSelectionDialogBase:onSelectionIndexChanged(index)
end

function InvoicesSelectionDialogBase:toggleItemAtIndex(index)
    local items = self:getItems()
    if index < 1 or index > #items then return end

    local item = items[index]
    self:toggleItemSelection(item, index)
    self:reloadAndRestoreSelection(index)
    self:updateSelectionControls()
    self:updateButtonStates()
end

function InvoicesSelectionDialogBase:toggleItemSelection(item, index)
    self:setItemSelected(item, index, not self:isItemSelected(item, index))
end

function InvoicesSelectionDialogBase:onSelectionListClicked(list, section, index)
    local items = self:getItems()
    if list ~= self.listFillTypes or index == nil or index < 1 or index > #items then return end
    self:toggleItemAtIndex(index)
end

function InvoicesSelectionDialogBase:updateSelectionControls()
end

function InvoicesSelectionDialogBase:onClickSelect()
    self:closeWithSelection(self:buildSelectedItems())
end

function InvoicesSelectionDialogBase:buildSelectedItems()
    local selectedItems = {}
    for index, item in ipairs(self:getItems()) do
        if self:isItemSelected(item, index) then
            table.insert(selectedItems, item)
        end
    end
    return selectedItems
end

function InvoicesSelectionDialogBase:onClickBack()
    self:closeWithSelection(nil)
end

function InvoicesSelectionDialogBase:closeWithSelection(selectedItems)
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selectedItems)
    end
end
