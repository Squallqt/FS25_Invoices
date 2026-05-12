-- Copyright © 2026 Squallqt. All rights reserved.
-- Modal dialog for multi-select vehicle picking with resale price display.
-- Flat list — one row per vehicle, selection by uniqueId. Consumables are excluded.
InvoicesVehicleDialog = {}
local InvoicesVehicleDialog_mt = Class(InvoicesVehicleDialog, DialogElement)

InvoicesVehicleDialog.CONTROLS = {
    LIST_FILL_TYPES = "listFillTypes",
    BTN_SELECT      = "btnSelect",
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP       = "titleSep",
}

---Creates new vehicle selection dialog instance
-- @param table target Parent target element
-- @param table? customMt Optional custom metatable
-- @return InvoicesVehicleDialog instance The new dialog instance
function InvoicesVehicleDialog.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesVehicleDialog_mt)
    self.vehicles        = {}
    self.selectedMap     = {}
    self.callbackTarget  = nil
    self.callbackFunc    = nil
    return self
end

---Loads dialog controls
function InvoicesVehicleDialog:onLoad()
    InvoicesVehicleDialog:superClass().onLoad(self)
    self:registerControls(InvoicesVehicleDialog.CONTROLS)
end

---Finalizes GUI setup
function InvoicesVehicleDialog:onGuiSetupFinished()
    InvoicesVehicleDialog:superClass().onGuiSetupFinished(self)
    if self.listFillTypes ~= nil then
        self.listFillTypes:setDataSource(self)
        self.listFillTypes:setDelegate(self)
    end
end

---Called when dialog opens, resets selection and loads vehicles
function InvoicesVehicleDialog:onOpen()
    InvoicesVehicleDialog:superClass().onOpen(self)
    self:resizeTitleSep()
    self.selectedMap = {}
    self._isEditMode = false
    self:loadVehicles()
    if self.listFillTypes ~= nil then
        self.listFillTypes:setSelectedIndex(1)
    end
    self:updateButtonStates()
end

---Resizes title separator to match title text width
function InvoicesVehicleDialog:resizeTitleSep()
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
-- @param function func Callback function receiving selected vehicles
function InvoicesVehicleDialog:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc   = func
end

---Sets the player farm ID used to filter owned vehicles
-- @param integer farmId Player farm identifier
function InvoicesVehicleDialog:setPlayerFarmId(farmId)
    self._playerFarmId = farmId
end

---Pre-selects vehicles by unique ID map and enables edit mode
-- @param table uniqueIdMap Map of vehicle unique IDs to pre-select
function InvoicesVehicleDialog:setInitialSelection(uniqueIdMap)
    self._isEditMode = false
    if uniqueIdMap ~= nil then
        for _ in pairs(uniqueIdMap) do
            self._isEditMode = true
            break
        end
        for _, item in ipairs(self.vehicles) do
            if uniqueIdMap[item.uniqueId] then
                self.selectedMap[item.uniqueId] = true
            end
        end
    end
    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
    self:updateButtonStates()
end

---Loads owned vehicles for current player farm with sell prices
function InvoicesVehicleDialog:loadVehicles()
    self.vehicles = {}

    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then return end

    local playerFarmId = self._playerFarmId
    if playerFarmId == nil or playerFarmId < 1 then return end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle ~= nil and not vehicle.isPallet then
            local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
            local propertyState = vehicle.getPropertyState ~= nil and vehicle:getPropertyState() or vehicle.propertyState

            if ownerFarmId == playerFarmId and propertyState == VehiclePropertyState.OWNED then
                local uniqueId = vehicle:getUniqueId()
                if uniqueId ~= nil then
                    local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
                    local vehicleName = vehicle.getFullName ~= nil and vehicle:getFullName() or (storeItem and storeItem.name or "?")
                    local sellPrice = math.floor(vehicle:getSellPrice())
                    local iconFilename = storeItem and storeItem.imageFilename or ""

                    table.insert(self.vehicles, {
                        uniqueId       = uniqueId,
                        name           = vehicleName,
                        sellPrice      = sellPrice,
                        iconFilename   = iconFilename,
                        configFileName = vehicle.configFileName,
                    })
                end
            end
        end
    end

    table.sort(self.vehicles, function(a, b) return a.name < b.name end)

    if self.listFillTypes ~= nil then
        self.listFillTypes:reloadData()
    end
end

---Enables or disables select button based on current selection state
function InvoicesVehicleDialog:updateButtonStates()
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
function InvoicesVehicleDialog:getNumberOfSections()
    return 1
end

---Returns number of vehicles in given section
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer count Number of vehicles
function InvoicesVehicleDialog:getNumberOfItemsInSection(list, section)
    return #self.vehicles
end

---Returns title for given section header
-- @param table list SmoothList element
-- @param integer section Section index
-- @return string title Empty string
function InvoicesVehicleDialog:getTitleForSectionHeader(list, section)
    return ""
end

---Populates a list cell with vehicle name, icon, price and selection tick
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
-- @param table cell Cell element to populate
function InvoicesVehicleDialog:populateCellForItemInSection(list, section, index, cell)
    local item = self.vehicles[index]
    if item == nil then return end

    local isSelected = self.selectedMap[item.uniqueId] == true

    local cellTick = cell:getDescendantByName("cellTick")
    if cellTick ~= nil then
        cellTick:setVisible(isSelected)
    end

    local cellIcon = cell:getDescendantByName("cellIcon")
    if cellIcon ~= nil then
        if item.iconFilename ~= nil and item.iconFilename ~= "" then
            cellIcon:setImageFilename(item.iconFilename)
            cellIcon:setVisible(true)
        else
            cellIcon:setVisible(false)
        end
    end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(item.name)
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(item.sellPrice, 0, true, false))
    end
end

---Called when list selection changes, updates button states
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
function InvoicesVehicleDialog:onListSelectionChanged(list, section, index)
    self:updateButtonStates()
end

---Toggles selection state of vehicle at given index
-- @param integer index Vehicle index to toggle
function InvoicesVehicleDialog:toggleItemAtIndex(index)
    if index < 1 or index > #self.vehicles then return end
    local uid = self.vehicles[index].uniqueId
    if self.selectedMap[uid] then
        self.selectedMap[uid] = nil
    else
        self.selectedMap[uid] = true
    end
    local section = self.listFillTypes.selectedSectionIndex or 1
    self.listFillTypes:reloadData()
    self.listFillTypes:setSelectedItem(section, index, true)
    self:updateButtonStates()
end

---Handles click on vehicle list item, toggles its selection
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index within section
function InvoicesVehicleDialog:onVehicleListClicked(list, section, index)
    if list ~= self.listFillTypes or index == nil or index < 1 or index > #self.vehicles then return end
    self:toggleItemAtIndex(index)
end

---Confirms selection, closes dialog and invokes callback with selected vehicles
function InvoicesVehicleDialog:onClickSelect()
    local selectedItems = {}
    for _, item in ipairs(self.vehicles) do
        if self.selectedMap[item.uniqueId] then
            table.insert(selectedItems, {
                uniqueId       = item.uniqueId,
                name           = item.name,
                sellPrice      = item.sellPrice,
                iconFilename   = item.iconFilename,
                configFileName = item.configFileName,
            })
        end
    end
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selectedItems)
    end
end

---Cancels selection, closes dialog and invokes callback with nil
function InvoicesVehicleDialog:onClickBack()
    self:close()
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, nil)
    end
end
