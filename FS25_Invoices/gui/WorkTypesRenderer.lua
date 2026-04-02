--[[
    WorkTypesRenderer.lua
    SmoothList renderer for work type selection, displaying name and difficulty-adjusted unit price.
    Author: Squallqt
]]

WorkTypesRenderer = {}
WorkTypesRenderer_mt = Class(WorkTypesRenderer)

function WorkTypesRenderer.new()
    local self = {}
    setmetatable(self, WorkTypesRenderer_mt)
    
    self.data = {}
    self.selectedRow = -1
    self.indexChangedCallback = nil
    
    return self
end

function WorkTypesRenderer:setData(data)
    self.data = data or {}
end

function WorkTypesRenderer:getNumberOfSections()
    return 1
end

function WorkTypesRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function WorkTypesRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function WorkTypesRenderer:populateCellForItemInSection(list, section, index, cell)
    local workType = self.data[index]
    if workType == nil then
        return
    end
    
    local manager = g_currentMission.invoicesManager
    local unitKey = manager:getUnitKey(workType.unit) or "invoices_unit_piece"
    local unitStr = g_i18n:getText(unitKey)
    local adjustedPrice = manager:getAdjustedPrice(workType.id)
    
    local priceStr
    if workType.unit == Invoice.UNIT_LITER then
        priceStr = string.format("%s / %s", g_i18n:formatMoney(adjustedPrice, 1), unitStr)
    else
        priceStr = string.format("%s / %s", g_i18n:formatMoney(adjustedPrice), unitStr)
    end
    
    local cellName = cell:getDescendantByName("cellName")
    local cellPrice = cell:getDescendantByName("cellPrice")
    
    if cellName then
        cellName:setText(g_i18n:getText(workType.nameKey))
    end
    if cellPrice then
        cellPrice:setText(priceStr)
    end
end

function WorkTypesRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end

function WorkTypesRenderer:getSelectedWorkType()
    if self.selectedRow > 0 and self.selectedRow <= #self.data then
        return self.data[self.selectedRow]
    end
    return nil
end
