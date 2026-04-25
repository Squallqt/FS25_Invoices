-- Copyright © 2026 Squallqt. All rights reserved.
-- Modal dialog for consumable selection (bales, pallets, bigBags).
-- Delegates all scanning/normalizing to InvoicesConsumablePipeline.
InvoicesConsumableDialog = {}
local InvoicesConsumableDialog_mt = Class(InvoicesConsumableDialog, DialogElement)

InvoicesConsumableDialog.CONTROLS = {
    LIST_FILL_TYPES = "listFillTypes",
    BTN_SELECT      = "btnSelect",
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP       = "titleSep",
    QTY_SELECTOR    = "qtySelector",
    QTY_MAX_LABEL   = "qtyMaxLabel",
    QTY_LABEL       = "qtyLabel",
}

---Creates new consumable selection dialog instance
-- @param table target Parent target element
-- @param table? customMt Optional custom metatable
-- @return InvoicesConsumableDialog instance The new dialog instance
function InvoicesConsumableDialog.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesConsumableDialog_mt)
    self.consumableGroups = {}
    self.quantityMap      = {}
    self.callbackTarget   = nil
    self.callbackFunc     = nil
    self._selectedGroupIndex = nil
    return self
end

---Loads dialog controls
function InvoicesConsumableDialog:onLoad()
    InvoicesConsumableDialog:superClass().onLoad(self)
    self:registerControls(InvoicesConsumableDialog.CONTROLS)
end

---Finalizes GUI setup
function InvoicesConsumableDialog:onGuiSetupFinished()
    InvoicesConsumableDialog:superClass().onGuiSetupFinished(self)
    if self.listFillTypes ~= nil then
        self.listFillTypes:setDataSource(self)
        self.listFillTypes:setDelegate(self)
    end
end

---Called when dialog opens, resets selection and loads consumables
function InvoicesConsumableDialog:onOpen()
    InvoicesConsumableDialog:superClass().onOpen(self)
    self:resizeTitleSep()
    self.quantityMap = {}
    self._isEditMode = false
    self._selectedGroupIndex = 1
    self:loadConsumables()
    if self.listFillTypes ~= nil then
        self.listFillTypes:setSelectedIndex(1)
    end
    self:updateQtyControls()
    self:updateButtonStates()
end

---Resizes title separator to match title text width
function InvoicesConsumableDialog:resizeTitleSep()
    if self.titleSep == nil or self.mainTitleText == nil then return end

    if self._titleSepHeight == nil then
        self._titleSepHeight = self.titleSep.absSize[2]
    end

    local text = self.mainTitleText.text or ""
    local textWidth = getTextWidth(self.mainTitleText.textSize, text)
    local padding = 20 * 2 * g_pixelSizeScaledX
    local newWidth = textWidth + padding

    self.titleSep:setSize(newWidth, self._titleSepHeight)
    if self.titleSep.parent ~= nil and self.titleSep.parent.invalidateLayout ~= nil then
        self.titleSep.parent:invalidateLayout()
    end
end

---Sets callback target and function for selection result
-- @param table target Callback target object
-- @param function func Callback function receiving selected consumables
function InvoicesConsumableDialog:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc   = func
end

---Sets the player farm ID used to filter owned consumables
-- @param integer farmId Player farm identifier
function InvoicesConsumableDialog:setPlayerFarmId(farmId)
    self._playerFarmId = farmId
end

---Pre-selects consumables by unique ID map and enables edit mode
-- @param table uniqueIdMap Map of consumable unique IDs to pre-select
function InvoicesConsumableDialog:setInitialSelection(uniqueIdMap)
    self._isEditMode = false
    if uniqueIdMap ~= nil then
        for _ in pairs(uniqueIdMap) do
            self._isEditMode = true
            break
        end
        for _, group in ipairs(self.consumableGroups) do
            local count = 0
            for _, item in ipairs(group.items) do
                if uniqueIdMap[item.uniqueId] then
                    count = count + 1
                end
            end
            if count > 0 then
                self.quantityMap[group.groupKey] = count
            end
        end
    end
    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
    self:updateQtyControls()
    self:updateButtonStates()
end

---Loads consumable groups from pipeline for current player farm
function InvoicesConsumableDialog:loadConsumables()
    self.consumableGroups = {}
    InvoicesConsumablePipeline.invalidateCache()

    local playerFarmId = self._playerFarmId
    if playerFarmId == nil or playerFarmId < 1 then return end

    local allItems = InvoicesConsumablePipeline.collectAll(playerFarmId)
    self.consumableGroups = InvoicesConsumablePipeline.groupItems(allItems)

    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
end

---Enables or disables select button based on current quantity selections
function InvoicesConsumableDialog:updateButtonStates()
    if self.btnSelect ~= nil then
        if self._isEditMode then
            self.btnSelect:setDisabled(false)
        else
            local hasQty = false
            for _, qty in pairs(self.quantityMap) do
                if qty > 0 then
                    hasQty = true
                    break
                end
            end
            self.btnSelect:setDisabled(not hasQty)
        end
    end
end

-- Data source

---Returns number of list sections
-- @return integer count Always 1
function InvoicesConsumableDialog:getNumberOfSections()
    return 1
end

---Returns number of consumable groups in given section
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer count Number of consumable groups
function InvoicesConsumableDialog:getNumberOfItemsInSection(list, section)
    return #self.consumableGroups
end

---Returns title for given section header
-- @param table list SmoothList element
-- @param integer section Section index
-- @return string title Empty string
function InvoicesConsumableDialog:getTitleForSectionHeader(list, section)
    return ""
end

---Populates a list cell with consumable group name, icon, stock count, price and selection tick
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
-- @param table cell Cell element to populate
function InvoicesConsumableDialog:populateCellForItemInSection(list, section, index, cell)
    local group = self.consumableGroups[index]
    if group == nil then return end

    local qty = self.quantityMap[group.groupKey] or 0

    local cellTick = cell:getDescendantByName("cellTick")
    if cellTick ~= nil then
        cellTick:setVisible(qty > 0)
    end

    local cellIcon = cell:getDescendantByName("cellIcon")
    if cellIcon ~= nil then
        if group.iconFilename ~= nil and group.iconFilename ~= "" then
            cellIcon:setImageFilename(group.iconFilename)
            cellIcon:setVisible(true)
        else
            cellIcon:setVisible(false)
        end
    end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(group.displayName)
    end

    local cellStock = cell:getDescendantByName("cellStock")
    if cellStock ~= nil then
        cellStock:setText(tostring(group.ownedCount))
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        local avgPrice = 0
        if group.ownedCount > 0 then
            local total = 0
            for _, item in ipairs(group.items) do
                total = total + item.unitPrice
            end
            avgPrice = math.floor(total / group.ownedCount)
        end
        cellPrice:setText(g_i18n:formatMoney(avgPrice, 0, true, false))
    end
end

---Called when list selection changes, updates quantity controls and button states
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
function InvoicesConsumableDialog:onListSelectionChanged(list, section, index)
    self._selectedGroupIndex = index
    self:updateQtyControls()
    self:updateButtonStates()
end

---Toggles selection of consumable group at given index between 0 and max quantity
-- @param integer index Group index to toggle
function InvoicesConsumableDialog:toggleItemAtIndex(index)
    if index < 1 or index > #self.consumableGroups then return end
    local group = self.consumableGroups[index]
    local key = group.groupKey
    local currentQty = self.quantityMap[key] or 0
    if currentQty > 0 then
        self.quantityMap[key] = 0
    else
        self.quantityMap[key] = group.ownedCount
    end
    self._selectedGroupIndex = index
    local section = self.listFillTypes.selectedSectionIndex or 1
    self.listFillTypes:reloadData()
    self.listFillTypes:setSelectedItem(section, index, true)
    self:updateQtyControls()
    self:updateButtonStates()
end

---Handles click on consumable list item, toggles its selection
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
function InvoicesConsumableDialog:onConsumableListClicked(list, section, index)
    if list ~= self.listFillTypes or index == nil or index < 1 or index > #self.consumableGroups then return end
    self:toggleItemAtIndex(index)
end

---Confirms selection, resolves individual consumable items and invokes callback
function InvoicesConsumableDialog:onClickSelect()
    local selectedItems = {}
    for _, group in ipairs(self.consumableGroups) do
        local qty = self.quantityMap[group.groupKey] or 0
        if qty > 0 then
            local resolveCount = math.min(qty, #group.items)
            for i = 1, resolveCount do
                local item = group.items[i]
                table.insert(selectedItems, {
                    uniqueId      = item.uniqueId,
                    name          = item.displayName,
                    sellPrice     = item.unitPrice,
                    iconFilename  = item.iconFilename,
                    groupKey      = item.groupKey,
                    xmlFilename   = item.xmlFilename,
                    fillTypeIndex = item.fillTypeIndex,
                    fillLevel     = item.fillLevel,
                })
            end
        end
    end
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selectedItems)
    end
end

---Updates quantity selector and max label for currently selected group
function InvoicesConsumableDialog:updateQtyControls()
    local group = nil
    if self._selectedGroupIndex ~= nil and self._selectedGroupIndex >= 1 and self._selectedGroupIndex <= #self.consumableGroups then
        group = self.consumableGroups[self._selectedGroupIndex]
    end

    if self.qtySelector ~= nil then
        if group ~= nil then
            local texts = {}
            for i = 0, group.ownedCount do
                table.insert(texts, tostring(i))
            end
            self.qtySelector:setTexts(texts)
            local qty = self.quantityMap[group.groupKey] or 0
            self.qtySelector:setState(qty + 1)
            self.qtySelector:setDisabled(false)
        else
            self.qtySelector:setTexts({"0"})
            self.qtySelector:setState(1)
            self.qtySelector:setDisabled(true)
        end
    end

    if self.qtyMaxLabel ~= nil then
        if group ~= nil then
            self.qtyMaxLabel:setText(string.format("/ %d", group.ownedCount))
        else
            self.qtyMaxLabel:setText("")
        end
    end
end

---Called when quantity selector value changes, updates quantity map
-- @param integer state New selector state (1-indexed)
function InvoicesConsumableDialog:onQtySelectorChanged(state)
    local group = nil
    if self._selectedGroupIndex ~= nil and self._selectedGroupIndex >= 1 and self._selectedGroupIndex <= #self.consumableGroups then
        group = self.consumableGroups[self._selectedGroupIndex]
    end
    if group == nil then return end

    local newQty = state - 1
    self.quantityMap[group.groupKey] = newQty

    local section = self.listFillTypes.selectedSectionIndex or 1
    self.listFillTypes:reloadData()
    self.listFillTypes:setSelectedItem(section, self._selectedGroupIndex, true)
    self:updateButtonStates()
end

---Cancels selection, closes dialog and invokes callback with nil
function InvoicesConsumableDialog:onClickBack()
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, nil)
    end
end
