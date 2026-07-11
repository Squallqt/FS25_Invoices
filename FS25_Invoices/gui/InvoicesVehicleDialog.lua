-- Copyright © 2026 Squallqt. All rights reserved.
-- Modal dialog for multi-select vehicle picking with resale price display.
-- Flat list - one row per vehicle, selection by uniqueId. Consumables are excluded.
InvoicesVehicleDialog = {}
local InvoicesVehicleDialog_mt = Class(InvoicesVehicleDialog, InvoicesSelectionDialogBase)

InvoicesVehicleDialog.CONTROLS = {
    LIST_FILL_TYPES = "listFillTypes",
    BTN_SELECT      = "btnSelect",
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP       = "titleSep",
}

function InvoicesVehicleDialog.new(target, customMt)
    local self = InvoicesVehicleDialog:superClass().new(target, customMt or InvoicesVehicleDialog_mt)
    self.vehicles = {}
    self.selectedMap = {}
    self:setupSelectionDialog("vehicles", "loadVehicles")
    return self
end

function InvoicesVehicleDialog:getInitialSelectionKey(item, index)
    return item.uniqueId
end

function InvoicesVehicleDialog:getItemSelectionKey(item, index)
    return item.uniqueId
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
    self:reloadSelectionList()
end

function InvoicesVehicleDialog:onVehicleListClicked(list, section, index)
    self:onSelectionListClicked(list, section, index)
end

function InvoicesVehicleDialog:buildSelectedItems()
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
    return selectedItems
end
