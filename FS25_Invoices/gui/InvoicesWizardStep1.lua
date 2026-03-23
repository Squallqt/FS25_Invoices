--[[
    InvoicesWizardStep1.lua
    Author: Squallqt
]]

InvoicesWizardStep1 = {}
local InvoicesWizardStep1_mt = Class(InvoicesWizardStep1, MessageDialog)

InvoicesWizardStep1.CONTROLS = {
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP = "titleSep",
    LIST_FARMS = "listFarms",
    BTN_NEXT = "btnNext",
    BTN_ADD = "btnAdd",
    BTN_REMOVE = "btnRemove",
    SLIDER_BOX = "sliderBox",
}

InvoicesWizardStep1.LIST_HEIGHT = 376
InvoicesWizardStep1.ITEM_HEIGHT_ACTUAL = 38

function InvoicesWizardStep1.new(target, customMt)
    local self = MessageDialog.new(target, customMt or InvoicesWizardStep1_mt)

    self.farms = {}
    self.selectedIndex = -1
    self.selectedFarm = nil
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

function InvoicesWizardStep1:resizeTitleSep()
    if self.titleSep == nil or self.mainTitleText == nil then return end

    if self._titleSepHeight == nil then
        self._titleSepHeight = self.titleSep.absSize[2]
    end

    local text = self.mainTitleText.text or ""
    local textWidth = getTextWidth(self.mainTitleText.textSize, text)
    local padding = 10 * 2 * g_pixelSizeScaledX
    local newWidth = textWidth + padding

    self.titleSep:setSize(newWidth, self._titleSepHeight)
    if self.titleSep.parent ~= nil and self.titleSep.parent.invalidateLayout ~= nil then
        self.titleSep.parent:invalidateLayout()
    end
end

function InvoicesWizardStep1:onOpen()
    InvoicesWizardStep1:superClass().onOpen(self)

    self:resizeTitleSep()

    local state = InvoicesWizardState.getInstance()
    state:reset()

    self.selectedFarm = nil
    self.selectedIndex = -1

    self:detectGameMode()
    self:loadFarms()

    if self.listFarms ~= nil then
        self.listFarms:reloadData()
        if #self.farms > 0 then
            self.listFarms:setSelectedIndex(1, 1, false)
        end
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
        self.selectedFarm = self.farms[1]

        if self.listFarms ~= nil then
            self.listFarms:setSelectedIndex(1, 1, true)
        end
    end
end

function InvoicesWizardStep1:updateButtonStates()
    local hasSelection = (self.selectedIndex >= 1 and self.selectedIndex <= #self.farms)
    local isSelectedFarm = false

    if hasSelection and self.selectedFarm ~= nil then
        isSelectedFarm = (self.farms[self.selectedIndex].farmId == self.selectedFarm.farmId)
    end

    if self.btnNext ~= nil then
        self.btnNext:setDisabled(false)
    end
    if self.btnAdd ~= nil then
        self.btnAdd:setDisabled(not hasSelection)
    end
    if self.btnRemove ~= nil then
        self.btnRemove:setDisabled(self.selectedFarm == nil or not hasSelection or not isSelectedFarm)
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

function InvoicesWizardStep1:onClickAdd()
    if self.selectedIndex < 1 or self.selectedIndex > #self.farms then
        return
    end

    local farm = self.farms[self.selectedIndex]

    if self.selectedFarm ~= nil and self.selectedFarm.farmId == farm.farmId then
        InfoDialog.show(string.format(g_i18n:getText("invoice_popup_already_selected"), farm.name))
        return
    end

    self.selectedFarm = farm

    self:updateButtonStates()

    InfoDialog.show(string.format(g_i18n:getText("invoice_popup_added"), farm.name))
end

function InvoicesWizardStep1:onClickRemove()
    if self.selectedFarm == nil then
        return
    end

    local name = self.selectedFarm.name
    self.selectedFarm = nil

    self:updateButtonStates()

    InfoDialog.show(string.format(g_i18n:getText("invoice_popup_removed"), name))
end

function InvoicesWizardStep1:onClickNext()
    if self.selectedFarm == nil then
        InfoDialog.show(g_i18n:getText("invoice_error_select_farm"))
        return
    end

    local state = InvoicesWizardState.getInstance()
    state:setRecipient(self.selectedFarm.farmId, self.selectedFarm.name)

    self:close()
    g_gui:showDialog("InvoicesWizardStep2")
end

function InvoicesWizardStep1:onClickBack()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self:close()
    g_gui:showGui("InGameMenu")
    g_inGameMenu:goToPage(g_inGameMenu.InvoicesFrame)
end

function InvoicesWizardStep1:onClickCancel()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self.selectedFarm = nil
    self.selectedIndex = -1
    self:close()
end

function InvoicesWizardStep1:delete()
    self.farms = nil
    self.selectedFarm = nil
    InvoicesWizardStep1:superClass().delete(self)
end
