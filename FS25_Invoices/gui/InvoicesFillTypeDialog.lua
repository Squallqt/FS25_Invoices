-- Copyright © 2026 Squallqt. All rights reserved.
-- Modal dialog for multi-select fill type picking with market price display and edit mode support.
InvoicesFillTypeDialog = {}
local InvoicesFillTypeDialog_mt = Class(InvoicesFillTypeDialog, DialogElement)

InvoicesFillTypeDialog.CONTROLS = {
    LIST_FILL_TYPES = "listFillTypes",
    BTN_SELECT      = "btnSelect",
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP       = "titleSep",
}

---Creates new fill type selection dialog instance
-- @param table target Parent target element
-- @param table? customMt Optional custom metatable
-- @return InvoicesFillTypeDialog instance The new dialog instance
function InvoicesFillTypeDialog.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesFillTypeDialog_mt)
    self.fillTypes       = {}
    self.selectedMap     = {}
    self.callbackTarget  = nil
    self.callbackFunc    = nil
    return self
end

---Loads dialog controls
function InvoicesFillTypeDialog:onLoad()
    InvoicesFillTypeDialog:superClass().onLoad(self)
    self:registerControls(InvoicesFillTypeDialog.CONTROLS)
end

---Finalizes GUI setup
function InvoicesFillTypeDialog:onGuiSetupFinished()
    InvoicesFillTypeDialog:superClass().onGuiSetupFinished(self)
    if self.listFillTypes ~= nil then
        self.listFillTypes:setDataSource(self)
        self.listFillTypes:setDelegate(self)
    end
end

---Called when dialog opens, resets selection and loads fill types
function InvoicesFillTypeDialog:onOpen()
    InvoicesFillTypeDialog:superClass().onOpen(self)
    self:resizeTitleSep()
    self.selectedMap = {}
    self._isEditMode = false
    self:loadFillTypes()
    if self.listFillTypes ~= nil then
        self.listFillTypes:setSelectedIndex(1)
    end
    self:updateButtonStates()
end

---Resizes title separator to match title text width
function InvoicesFillTypeDialog:resizeTitleSep()
    if self.titleSep == nil or self.mainTitleText == nil then return end

    if self._titleSepHeight == nil then
        self._titleSepHeight = self.titleSep.absSize[2]
    end
    if self._titleSepBaseWidth == nil then
        self._titleSepBaseWidth = self.titleSep.absSize[1]
    end

    local text = self.mainTitleText.text or ""
    local textWidth = getTextWidth(self.mainTitleText.textSize, text)
    local padding = 20 * 2 * g_pixelSizeScaledX
    local newWidth = math.max(self._titleSepBaseWidth, textWidth + padding)

    self.titleSep:setSize(newWidth, self._titleSepHeight)
    if self.titleSep.parent ~= nil and self.titleSep.parent.invalidateLayout ~= nil then
        self.titleSep.parent:invalidateLayout()
    end
end

---Sets callback target and function for selection result
-- @param table target Callback target object
-- @param function func Callback function receiving selected items
function InvoicesFillTypeDialog:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc   = func
end

---Pre-selects fill types by name map and enables edit mode
-- @param table nameMap Map of fill type names to pre-select
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

---Loads available fill types from fill type manager with market prices
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

---Enables or disables select button based on current selection state
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

---Returns number of list sections
-- @return integer count Always 1
function InvoicesFillTypeDialog:getNumberOfSections()
    return 1
end

---Returns number of fill types in given section
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer count Number of fill types
function InvoicesFillTypeDialog:getNumberOfItemsInSection(list, section)
    return #self.fillTypes
end

---Returns title for given section header
-- @param table list SmoothList element
-- @param integer section Section index
-- @return string title Empty string
function InvoicesFillTypeDialog:getTitleForSectionHeader(list, section)
    return ""
end

---Populates a list cell with fill type name, icon, price and selection tick
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
-- @param table cell Cell element to populate
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

---Called when list selection changes, updates button states
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
function InvoicesFillTypeDialog:onListSelectionChanged(list, section, index)
    self:updateButtonStates()
end

---Toggles selection state of fill type at given index
-- @param integer index Fill type index to toggle
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

---Handles click on fill type list item, toggles its selection
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
function InvoicesFillTypeDialog:onFillTypeListClicked(list, section, index)
    if list ~= self.listFillTypes or index == nil or index < 1 or index > #self.fillTypes then return end
    self:toggleItemAtIndex(index)
end

---Confirms selection, closes dialog and invokes callback with selected fill types
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

---Cancels selection, closes dialog and invokes callback with nil
function InvoicesFillTypeDialog:onClickBack()
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, nil)
    end
end
