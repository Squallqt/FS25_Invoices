--[[
    LineItemsRenderer.lua
    SmoothList renderer for invoice line items, displaying service label and TTC amount per entry.
    Author: Squallqt
]]

LineItemsRenderer = {}
LineItemsRenderer_mt = Class(LineItemsRenderer)

function LineItemsRenderer.new()
    local self = {}
    setmetatable(self, LineItemsRenderer_mt)
    
    self.data = {}
    self.selectedRow = -1
    self.indexChangedCallback = nil
    
    return self
end

function LineItemsRenderer:setData(data)
    self.data = data or {}
end

function LineItemsRenderer:getNumberOfSections()
    return 1
end

function LineItemsRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function LineItemsRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function LineItemsRenderer:populateCellForItemInSection(list, section, index, cell)
    local item = self.data[index]
    if item == nil then
        return
    end
    
    local cellName = cell:getDescendantByName("cellName")
    local cellAmount = cell:getDescendantByName("cellAmount")
    
    if cellName then
        cellName:setText(item.displayName or "")
    end
    if cellAmount then
        cellAmount:setText(g_i18n:formatMoney(item.amount or 0))
    end
end

function LineItemsRenderer:onListSelectionChanged(list, section, index)
    self.selectedRow = index
    if self.indexChangedCallback ~= nil then
        self.indexChangedCallback(index)
    end
end

function LineItemsRenderer:getSelectedIndex()
    return self.selectedRow
end

function LineItemsRenderer:getSelectedItem()
    if self.selectedRow > 0 and self.selectedRow <= #self.data then
        return self.data[self.selectedRow]
    end
    return nil
end
