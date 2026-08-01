-- Copyright © 2026 Squallqt. All rights reserved.
---Base class for invoice selection dialogs
InvoicesSelectionDialogBase = {}
local InvoicesSelectionDialogBase_mt = Class(InvoicesSelectionDialogBase, DialogElement)

---Creates a selection dialog base instance
-- @param table target Parent target
-- @param table? customMt Custom metatable
-- @return InvoicesSelectionDialogBase Selection dialog instance
function InvoicesSelectionDialogBase.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesSelectionDialogBase_mt)
    self.callbackTarget = nil
    self.callbackFunc = nil
    self._isEditMode = false
    self._itemsProperty = nil
    self._loaderFunctionName = nil
    return self
end

---Configures the item storage and loader method
-- @param string itemsProperty Item array property name
-- @param string loaderFunctionName Loader method name
function InvoicesSelectionDialogBase:setupSelectionDialog(itemsProperty, loaderFunctionName)
    self._itemsProperty = itemsProperty
    self._loaderFunctionName = loaderFunctionName
end

---Loads dialog controls
function InvoicesSelectionDialogBase:onLoad()
    InvoicesSelectionDialogBase:superClass().onLoad(self)
    self:registerControls(self.CONTROLS)
end

---Connects the list data source and delegate
function InvoicesSelectionDialogBase:onGuiSetupFinished()
    InvoicesSelectionDialogBase:superClass().onGuiSetupFinished(self)
    if self.listFillTypes ~= nil then
        self.listFillTypes:setDataSource(self)
        self.listFillTypes:setDelegate(self)
    end
end

---Prepares selection state when the dialog opens
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

---Resizes the title separator
function InvoicesSelectionDialogBase:resizeTitleSep()
    InvoicesGuiUtils.resizeTitleSeparator(self.mainTitleText, self.titleSep)
end

---Sets the selection result callback
-- @param table target Callback target
-- @param function func Callback function
function InvoicesSelectionDialogBase:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc = func
end

---Sets the farm used to load selectable items
-- @param integer farmId Farm identifier
function InvoicesSelectionDialogBase:setPlayerFarmId(farmId)
    self._playerFarmId = farmId
end

---Clears the current selection
function InvoicesSelectionDialogBase:resetSelectionState()
    self.selectedMap = {}
end

---Returns the configured item array
-- @return table Selectable items
function InvoicesSelectionDialogBase:getItems()
    if self._itemsProperty ~= nil then
        return self[self._itemsProperty] or {}
    end
    return {}
end

---Reloads the selection list
function InvoicesSelectionDialogBase:reloadSelectionList()
    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
end

---Reloads the list and restores its selected row
-- @param integer index Item index
function InvoicesSelectionDialogBase:reloadAndRestoreSelection(index)
    if self.listFillTypes ~= nil then
        local section = self.listFillTypes.selectedSectionIndex or 1
        self.listFillTypes:reloadData()
        self.listFillTypes:setSelectedItem(section, index, true)
    end
end

---Applies an existing selection for edit mode
-- @param table? selectionMap Existing selection or nil
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

---Maps an existing selection onto loaded items
-- @param table selectionMap Existing selection
function InvoicesSelectionDialogBase:applyInitialSelection(selectionMap)
    for index, item in ipairs(self:getItems()) do
        local key = self:getInitialSelectionKey(item, index)
        if key ~= nil and selectionMap[key] then
            self:setItemSelected(item, index, true)
        end
    end
end

---Returns the key used to restore an item selection
-- @param table item Selectable item
-- @param integer index Item index
-- @return string|nil Selection key or nil
function InvoicesSelectionDialogBase:getInitialSelectionKey(item, index)
    return item.name
end

---Returns the active selection map
-- @return table Selection map
function InvoicesSelectionDialogBase:getSelectionMap()
    return self.selectedMap or {}
end

---Returns the key used to store an item selection
-- @param table item Selectable item
-- @param integer index Item index
-- @return integer Selection key
function InvoicesSelectionDialogBase:getItemSelectionKey(item, index)
    return index
end

---Sets the selection state of an item
-- @param table item Selectable item
-- @param integer index Item index
-- @param boolean selected Selection state
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

---Returns whether an item is selected
-- @param table item Selectable item
-- @param integer index Item index
-- @return boolean True when selected
function InvoicesSelectionDialogBase:isItemSelected(item, index)
    local key = self:getItemSelectionKey(item, index)
    return key ~= nil and self:isSelectionValueActive(self:getSelectionMap()[key])
end

---Returns whether a stored selection value is active
-- @param boolean? value Stored selection value
-- @return boolean True when active
function InvoicesSelectionDialogBase:isSelectionValueActive(value)
    return value == true
end

---Returns whether any item is selected
-- @return boolean True when a selection exists
function InvoicesSelectionDialogBase:hasActiveSelection()
    for _, value in pairs(self:getSelectionMap()) do
        if self:isSelectionValueActive(value) then
            return true
        end
    end
    return false
end

---Updates the select button state
function InvoicesSelectionDialogBase:updateButtonStates()
    if self.btnSelect ~= nil then
        self.btnSelect:setDisabled(not self._isEditMode and not self:hasActiveSelection())
    end
end

---Returns the number of list sections
-- @return integer Number of sections
function InvoicesSelectionDialogBase:getNumberOfSections()
    return 1
end

---Returns the number of items in a list section
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer Number of items
function InvoicesSelectionDialogBase:getNumberOfItemsInSection(list, section)
    return #self:getItems()
end

---Populates a selection list cell
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
-- @param table cell List cell
function InvoicesSelectionDialogBase:populateCellForItemInSection(list, section, index, cell)
    local item = self:getItems()[index]
    if item == nil then return end

    self:populateSelectionIndicator(cell, item, index)
    self:populateCellIcon(cell, item.iconFilename)
    self:setCellText(cell, "cellName", item.name or item.displayName or "")
    self:populateAdditionalCellFields(item, index, cell)
    self:setCellText(cell, "cellPrice", self:getItemPriceText(item, index))
end

---Populates the selection indicator of a list cell
-- @param table cell List cell
-- @param table item Selectable item
-- @param integer index Item index
function InvoicesSelectionDialogBase:populateSelectionIndicator(cell, item, index)
    local dotText, prefixText, checkVisible = self:getSelectionIndicatorState(item, index)
    self:setCellText(cell, "cellDot", dotText)
    self:setCellText(cell, "cellPrefix", prefixText)

    local cellCheck = cell:getDescendantByName("cellCheck")
    if cellCheck ~= nil then
        cellCheck:setVisible(checkVisible)
    end
end

---Returns selection indicator values for an item
-- @param table item Selectable item
-- @param integer index Item index
-- @return string Dot text
-- @return string Prefix text
-- @return boolean Checkmark visibility
function InvoicesSelectionDialogBase:getSelectionIndicatorState(item, index)
    local isSelected = self:isItemSelected(item, index)
    return isSelected and "" or "·", "", isSelected
end

---Populates the icon of a list cell
-- @param table cell List cell
-- @param string? iconFilename Icon filename
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

---Sets a named text element in a list cell
-- @param table cell List cell
-- @param string name Element name
-- @param string? text Element text
function InvoicesSelectionDialogBase:setCellText(cell, name, text)
    local element = cell:getDescendantByName(name)
    if element ~= nil and text ~= nil then
        element:setText(text)
    end
end

---Returns the price of a selectable item
-- @param table item Selectable item
-- @param integer index Item index
-- @return number Item price
function InvoicesSelectionDialogBase:getItemPrice(item, index)
    return item.sellPrice or item.price or 0
end

---Returns the formatted price of a selectable item
-- @param table item Selectable item
-- @param integer index Item index
-- @return string Formatted item price
function InvoicesSelectionDialogBase:getItemPriceText(item, index)
    return g_i18n:formatMoney(self:getItemPrice(item, index), 0, true, false)
end

---Populates subclass-specific list cell fields
-- @param table item Selectable item
-- @param integer index Item index
-- @param table cell List cell
function InvoicesSelectionDialogBase:populateAdditionalCellFields(item, index, cell)
end

---Handles a list selection change
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
function InvoicesSelectionDialogBase:onListSelectionChanged(list, section, index)
    self:onSelectionIndexChanged(index)
    self:updateSelectionControls()
    self:updateButtonStates()
end

---Handles a selected item index change
-- @param integer index Item index
function InvoicesSelectionDialogBase:onSelectionIndexChanged(index)
end

---Toggles the item at a list index
-- @param integer index Item index
function InvoicesSelectionDialogBase:toggleItemAtIndex(index)
    local items = self:getItems()
    if index < 1 or index > #items then return end

    local item = items[index]
    self:toggleItemSelection(item, index)
    self:reloadAndRestoreSelection(index)
    self:updateSelectionControls()
    self:updateButtonStates()
end

---Toggles the selection state of an item
-- @param table item Selectable item
-- @param integer index Item index
function InvoicesSelectionDialogBase:toggleItemSelection(item, index)
    self:setItemSelected(item, index, not self:isItemSelected(item, index))
end

---Handles a click in the selection list
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
function InvoicesSelectionDialogBase:onSelectionListClicked(list, section, index)
    local items = self:getItems()
    if list ~= self.listFillTypes or index == nil or index < 1 or index > #items then return end
    self:toggleItemAtIndex(index)
end

---Updates subclass-specific selection controls
function InvoicesSelectionDialogBase:updateSelectionControls()
end

---Confirms the current selection
function InvoicesSelectionDialogBase:onClickSelect()
    self:closeWithSelection(self:buildSelectedItems())
end

---Builds the selected item array
-- @return table Selected items
function InvoicesSelectionDialogBase:buildSelectedItems()
    local selectedItems = {}
    for index, item in ipairs(self:getItems()) do
        if self:isItemSelected(item, index) then
            table.insert(selectedItems, item)
        end
    end
    return selectedItems
end

---Closes the dialog without a selection
function InvoicesSelectionDialogBase:onClickBack()
    self:closeWithSelection(nil)
end

---Closes the dialog and invokes the selection callback
-- @param table? selectedItems Selected items or nil when cancelled
function InvoicesSelectionDialogBase:closeWithSelection(selectedItems)
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selectedItems)
    end
end
