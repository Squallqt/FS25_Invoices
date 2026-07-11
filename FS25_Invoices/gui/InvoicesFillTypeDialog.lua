-- Copyright © 2026 Squallqt. All rights reserved.
-- Modal dialog for multi-select fill type picking with market price display and edit mode support.
InvoicesFillTypeDialog = {}
local InvoicesFillTypeDialog_mt = Class(InvoicesFillTypeDialog, InvoicesSelectionDialogBase)

InvoicesFillTypeDialog.CONTROLS = {
    LIST_FILL_TYPES = "listFillTypes",
    BTN_SELECT      = "btnSelect",
    MAIN_TITLE_TEXT = "mainTitleText",
    TITLE_SEP       = "titleSep",
}

-- Fill types kept hidden from the in-game price table that must still be invoiceable as products
InvoicesFillTypeDialog.EXTRA_FILL_TYPES = {
    CHAFF = true,
}

function InvoicesFillTypeDialog.new(target, customMt)
    local self = InvoicesFillTypeDialog:superClass().new(target, customMt or InvoicesFillTypeDialog_mt)
    self.fillTypes = {}
    self.selectedMap = {}
    self:setupSelectionDialog("fillTypes", "loadFillTypes")
    return self
end

---Loads available fill types from fill type manager with market prices
function InvoicesFillTypeDialog:loadFillTypes()
    self.fillTypes = {}

    local fillTypeManager = g_fillTypeManager
    if fillTypeManager == nil then return end

    for _, fillType in pairs(fillTypeManager.fillTypes) do
        if fillType ~= nil and (fillType.showOnPriceTable or InvoicesFillTypeDialog.EXTRA_FILL_TYPES[fillType.name]) then
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
                isPalletType     = fillType.isPalletType or false,
                isBaleType       = fillType.isBaleType or false,
                iconFilename     = fillType.hudOverlayFilename,
            })
        end
    end

    table.sort(self.fillTypes, function(a, b) return a.name < b.name end)
    self:reloadSelectionList()
end

function InvoicesFillTypeDialog:getItemPrice(item, index)
    return (item.pricePerLiter or 0) * 1000
end

function InvoicesFillTypeDialog:onFillTypeListClicked(list, section, index)
    self:onSelectionListClicked(list, section, index)
end

function InvoicesFillTypeDialog:buildSelectedItems()
    local selectedItems = {}
    for idx, _ in pairs(self.selectedMap) do
        local ft = self.fillTypes[idx]
        if ft ~= nil then
            table.insert(selectedItems, ft)
        end
    end
    return selectedItems
end
