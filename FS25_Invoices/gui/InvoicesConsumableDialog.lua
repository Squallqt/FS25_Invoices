-- Copyright © 2026 Squallqt. All rights reserved.
-- Modal dialog for consumable selection (bales, pallets, bigBags).
-- Delegates all scanning/normalizing to InvoicesConsumablePipeline.
InvoicesConsumableDialog = {}
local InvoicesConsumableDialog_mt = Class(InvoicesConsumableDialog, InvoicesSelectionDialogBase)

InvoicesConsumableDialog.CONTROLS = {
    LIST_FILL_TYPES = "listFillTypes",
    BTN_SELECT      = "btnSelect",
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP       = "titleSep",
    QTY_SELECTOR    = "qtySelector",
    QTY_MAX_LABEL   = "qtyMaxLabel",
}

function InvoicesConsumableDialog.new(target, customMt)
    local self = InvoicesConsumableDialog:superClass().new(target, customMt or InvoicesConsumableDialog_mt)
    self.consumableGroups = {}
    self.quantityMap = {}
    self._selectedGroupIndex = nil
    self:setupSelectionDialog("consumableGroups", "loadConsumables")
    return self
end

function InvoicesConsumableDialog:resetSelectionState()
    self.quantityMap = {}
    self._selectedGroupIndex = 1
end

function InvoicesConsumableDialog:getSelectionMap()
    return self.quantityMap or {}
end

function InvoicesConsumableDialog:isSelectionValueActive(value)
    return value ~= nil and value > 0
end

function InvoicesConsumableDialog:applyInitialSelection(uniqueIdMap)
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

---Loads consumable groups from pipeline for current player farm
function InvoicesConsumableDialog:loadConsumables()
    self.consumableGroups = {}
    InvoicesConsumablePipeline.invalidateCache()

    local playerFarmId = self._playerFarmId
    if playerFarmId == nil or playerFarmId < 1 then return end

    local allItems = InvoicesConsumablePipeline.collectAll(playerFarmId)
    self.consumableGroups = InvoicesConsumablePipeline.groupItems(allItems)
    self:reloadSelectionList()
end

function InvoicesConsumableDialog:getSelectionIndicatorState(group, index)
    local qty = self.quantityMap[group.groupKey] or 0
    return qty > 0 and "" or "·", qty > 1 and string.format("x%d", qty) or "", qty == 1
end

function InvoicesConsumableDialog:populateAdditionalCellFields(group, index, cell)
    self:setCellText(cell, "cellStock", tostring(group.ownedCount))
end

function InvoicesConsumableDialog:getItemPrice(group, index)
    if group.ownedCount <= 0 then return 0 end

    local total = 0
    for _, item in ipairs(group.items) do
        total = total + item.unitPrice
    end
    return math.floor(total / group.ownedCount)
end

function InvoicesConsumableDialog:onSelectionIndexChanged(index)
    self._selectedGroupIndex = index
end

function InvoicesConsumableDialog:toggleItemSelection(group, index)
    local key = group.groupKey
    local currentQty = self.quantityMap[key] or 0
    if currentQty > 0 then
        self.quantityMap[key] = 0
    else
        self.quantityMap[key] = group.ownedCount
    end
    self._selectedGroupIndex = index
end

function InvoicesConsumableDialog:onConsumableListClicked(list, section, index)
    self:onSelectionListClicked(list, section, index)
end

function InvoicesConsumableDialog:buildSelectedItems()
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
    return selectedItems
end

function InvoicesConsumableDialog:updateSelectionControls()
    self:updateQtyControls()
end

function InvoicesConsumableDialog:getSelectedGroup()
    local index = self._selectedGroupIndex
    if index ~= nil and index >= 1 and index <= #self.consumableGroups then
        return self.consumableGroups[index]
    end
    return nil
end

---Updates quantity selector and max label for currently selected group
function InvoicesConsumableDialog:updateQtyControls()
    local group = self:getSelectedGroup()

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
    local group = self:getSelectedGroup()
    if group == nil then return end

    self.quantityMap[group.groupKey] = state - 1
    self:reloadAndRestoreSelection(self._selectedGroupIndex)
    self:updateButtonStates()
end
