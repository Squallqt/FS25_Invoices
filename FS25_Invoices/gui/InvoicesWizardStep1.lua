--[[
    InvoicesWizardStep1.lua
    Author: Squallqt
]]

InvoicesWizardStep1 = {}
local InvoicesWizardStep1_mt = Class(InvoicesWizardStep1, DialogElement)

InvoicesWizardStep1.CONTROLS = {
    TITLE_BADGE_BG = "titleBadgeBg",
    MAIN_TITLE_TEXT = "mainTitleText",
    LIST_FARMS = "listFarms",
    SLIDER_BOX = "sliderBox",
    BTN_NEXT = "btnNext",
}

InvoicesWizardStep1.LIST_HEIGHT = 334
InvoicesWizardStep1.ITEM_HEIGHT_ACTUAL = 38

function InvoicesWizardStep1.new(target, customMt)
    local self = DialogElement.new(target, customMt or InvoicesWizardStep1_mt)
    
    self.farms = {}
    self.selectedIndex = -1
    self.isSoloMode = false
    self.playerFarmId = nil
    
    return self
end

function InvoicesWizardStep1:onLoad()
    InvoicesWizardStep1:superClass().onLoad(self)
    self:registerControls(InvoicesWizardStep1.CONTROLS)
end

function InvoicesWizardStep1:onGuiSetupFinished()
    InvoicesWizardStep1:superClass().onGuiSetupFinished(self)
    
    if self.listFarms ~= nil then
        self.listFarms:setDataSource(self)
        self.listFarms:setDelegate(self)
    end
end

function InvoicesWizardStep1:resizeTitleBadge()
    if self.mainTitleText ~= nil and self.titleBadgeBg ~= nil then
        local textWidth = getTextWidth(self.mainTitleText.textSize, self.mainTitleText.text)
        local paddingX = self.mainTitleText.textSize * 0.8
        local badgeWidth = textWidth + paddingX * 2
        local badgeHeight = self.titleBadgeBg.absSize[2]
        self.titleBadgeBg:setSize(badgeWidth, badgeHeight)
    end
end

function InvoicesWizardStep1:onOpen()
    InvoicesWizardStep1:superClass().onOpen(self)
    self:resizeTitleBadge()
    
    local state = InvoicesWizardState.getInstance()
    state:reset()
    
    self.farms = {}
    self.selectedIndex = -1
    
    self:detectGameMode()
    self:loadFarms()
    
    if self.listFarms ~= nil then
        self.listFarms:reloadData()
    end
    
    self:configureSlider()
    self:handleAutoSelection()
    self:updateButtonStates()
    
    if self.listFarms ~= nil then
        FocusManager:setFocus(self.listFarms)
    end
end

function InvoicesWizardStep1:detectGameMode()
    self.playerFarmId = nil
    self.isSoloMode = false
    
    if g_currentMission ~= nil then
        if g_currentMission.getFarmId ~= nil then
            self.playerFarmId = g_currentMission:getFarmId()
        end
        if self.playerFarmId == nil and g_currentMission.player ~= nil then
            self.playerFarmId = g_currentMission.player.farmId
        end
        if self.playerFarmId == nil and g_farmManager ~= nil and g_currentMission.playerUserId ~= nil then
            local playerFarm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
            if playerFarm ~= nil then
                self.playerFarmId = playerFarm.farmId
            end
        end
    end
    
    local farmCount = 0
    local farmManager = g_farmManager
    if farmManager then
        local farms = farmManager:getFarms()
        for _, farm in pairs(farms) do
            if farm.farmId ~= nil 
               and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID 
               and farm.farmId ~= 0
               and farm.name ~= nil 
               and farm.name ~= "" then
                farmCount = farmCount + 1
            end
        end
    end
    
    self.isSoloMode = (farmCount <= 1)
end

function InvoicesWizardStep1:loadFarms()
    self.farms = {}
    
    local farmManager = g_farmManager
    if farmManager == nil then
        return
    end
    
    local farms = farmManager:getFarms()
    
    local function isValidFarm(farm)
        return farm.farmId ~= nil 
           and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID 
           and farm.farmId ~= 0
           and farm.name ~= nil 
           and farm.name ~= ""
    end
    
    if self.isSoloMode then
-- Solo mode
        for _, farm in pairs(farms) do
            if isValidFarm(farm) and farm.farmId == self.playerFarmId then
                table.insert(self.farms, {
                    farmId = farm.farmId,
                    name = farm.name,
                    color = farm.color
                })
                break
            end
        end
        
        if #self.farms == 0 then
            for _, farm in pairs(farms) do
                if isValidFarm(farm) then
                    table.insert(self.farms, {
                        farmId = farm.farmId,
                        name = farm.name,
                        color = farm.color
                    })
                    break
                end
            end
        end
    else
-- Multiplayer
        for _, farm in pairs(farms) do
            if isValidFarm(farm) and farm.farmId ~= self.playerFarmId then
                table.insert(self.farms, {
                    farmId = farm.farmId,
                    name = farm.name,
                    color = farm.color
                })
            end
        end
    end
    
    table.sort(self.farms, function(a, b)
        return a.name < b.name
    end)
end

function InvoicesWizardStep1:configureSlider()
    if self.sliderBox == nil then
        return
    end
    
    local maxVisibleItems = math.floor(InvoicesWizardStep1.LIST_HEIGHT / InvoicesWizardStep1.ITEM_HEIGHT_ACTUAL)
    local needsScroll = #self.farms > maxVisibleItems
    self.sliderBox:setVisible(needsScroll)
end

function InvoicesWizardStep1:handleAutoSelection()
    if self.isSoloMode and #self.farms == 1 then
        self.selectedIndex = 1
        
        if self.listFarms ~= nil then
            self.listFarms:setSelectedIndex(1, 1, true)
        end
    end
end

function InvoicesWizardStep1:updateButtonStates()
    if self.btnNext ~= nil then
        local hasValidSelection = self.selectedIndex >= 1 and self.selectedIndex <= #self.farms
        self.btnNext:setDisabled(not hasValidSelection)
    end
end

function InvoicesWizardStep1:getNumberOfSections()
    return 1
end

function InvoicesWizardStep1:getNumberOfItemsInSection(list, section)
    return #self.farms
end

function InvoicesWizardStep1:getTitleForSectionHeader(list, section)
    return nil
end

function InvoicesWizardStep1:getSectionHeaderHeight(list, section)
    return 0
end

function InvoicesWizardStep1:populateCellForItemInSection(list, section, index, cell)
    local farm = self.farms[index]
    if farm == nil then
        return
    end
    
    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(farm.name)
    end
end

function InvoicesWizardStep1:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateButtonStates()
end

function InvoicesWizardStep1:onClickNext()
    if self.selectedIndex < 1 or self.selectedIndex > #self.farms then
        return
    end
    
    local selectedFarm = self.farms[self.selectedIndex]
    
    local state = InvoicesWizardState.getInstance()
    state:setRecipient(selectedFarm.farmId, selectedFarm.name)
    
    self:close()
    g_gui:showDialog("InvoicesWizardStep2")
end

function InvoicesWizardStep1:onClickCancel()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self:close()
end

function InvoicesWizardStep1:delete()
    self.farms = nil
    InvoicesWizardStep1:superClass().delete(self)
end
