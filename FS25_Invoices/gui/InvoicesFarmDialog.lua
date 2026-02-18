--[[
    InvoicesFarmDialog.lua
    Author: Squallqt
]]

InvoicesFarmDialog = {}
local InvoicesFarmDialog_mt = Class(InvoicesFarmDialog, DialogElement)

InvoicesFarmDialog.CONTROLS = {
    LIST_FARMS = "listFarms",
    BTN_SELECT = "btnSelect",
}

function InvoicesFarmDialog.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesFarmDialog_mt)
    
    self.farms = {}
    self.selectedIndex = -1
    self.callbackTarget = nil
    self.callbackFunc = nil
    
    return self
end

function InvoicesFarmDialog:onLoad()
    InvoicesFarmDialog:superClass().onLoad(self)
    self:registerControls(InvoicesFarmDialog.CONTROLS)
    
    Logging.devInfo("[InvoicesFarmDialog] onLoad() - Controls registered")
end

function InvoicesFarmDialog:onGuiSetupFinished()
    InvoicesFarmDialog:superClass().onGuiSetupFinished(self)
    
    if self.listFarms ~= nil then
        self.listFarms:setDataSource(self)
        self.listFarms:setDelegate(self)
    end
    
    Logging.devInfo("[InvoicesFarmDialog] onGuiSetupFinished() - List configured")
end

function InvoicesFarmDialog:onOpen()
    InvoicesFarmDialog:superClass().onOpen(self)
    
    self.selectedIndex = -1
    self:loadFarms()
    self:updateButtonStates()
end

function InvoicesFarmDialog:setCallback(target, func)
    self.callbackTarget = target
    self.callbackFunc = func
end

function InvoicesFarmDialog:loadFarms()
    self.farms = {}
    
    local farmManager = g_farmManager
    if farmManager == nil then
        return
    end
    
    local currentFarmId = -1
    local playerFarm = farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if playerFarm then
        currentFarmId = playerFarm.farmId
    end
    
    local farms = farmManager:getFarms()
    if farms then
        for _, farm in pairs(farms) do
            if farm.farmId ~= FarmManager.SPECTATOR_FARM_ID and 
               farm.farmId ~= currentFarmId then
                table.insert(self.farms, {
                    farmId = farm.farmId,
                    name = farm.name,
                    money = farm.money or 0
                })
            end
        end
    end
    
    table.sort(self.farms, function(a, b)
        return a.name < b.name
    end)
    
    if self.listFarms ~= nil then
        self.listFarms:reloadData()
    end
end

function InvoicesFarmDialog:updateButtonStates()
    if self.btnSelect ~= nil then
        self.btnSelect:setDisabled(self.selectedIndex < 1 or self.selectedIndex > #self.farms)
    end
end

function InvoicesFarmDialog:getNumberOfSections()
    return 1
end

function InvoicesFarmDialog:getNumberOfItemsInSection(list, section)
    return #self.farms
end

function InvoicesFarmDialog:getTitleForSectionHeader(list, section)
    return ""
end

function InvoicesFarmDialog:populateCellForItemInSection(list, section, index, cell)
    local farm = self.farms[index]
    if farm == nil then
        return
    end
    
    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(farm.name)
    end
end

function InvoicesFarmDialog:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateButtonStates()
end

function InvoicesFarmDialog:onClickSelect()
    if self.selectedIndex < 1 or self.selectedIndex > #self.farms then
        return
    end
    
    local selectedFarm = self.farms[self.selectedIndex]
    
    self:close()
    
    if self.callbackTarget ~= nil and self.callbackFunc ~= nil then
        self.callbackFunc(self.callbackTarget, selectedFarm)
    end
end

function InvoicesFarmDialog:onClickBack()
    self:close()
end
