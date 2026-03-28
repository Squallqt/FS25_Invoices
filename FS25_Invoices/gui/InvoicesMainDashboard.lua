--[[
    InvoicesMainDashboard.lua
    Consolidated invoice creation dashboard
    Replaces WizardStep1-4 in a single view
    Author: Squallqt
]]

InvoicesMainDashboard = {}
local InvoicesMainDashboard_mt = Class(InvoicesMainDashboard, MessageDialog)

InvoicesMainDashboard.CONTROLS = {
    MAIN_TITLE_TEXT  = "mainTitleText",
    TITLE_SEP        = "titleSep",
    -- Selection lists
    LIST_FARMS       = "listFarms",
    LIST_WORK_TYPES  = "listWorkTypes",
    LIST_FIELDS      = "listFields",
    FARM_SLIDER_BOX  = "farmSliderBox",
    WORK_SLIDER_BOX  = "workSliderBox",
    FIELD_SLIDER_BOX = "fieldSliderBox",
    WORK_TYPES_ZONE  = "workTypesZone",
    FIELDS_PANEL     = "fieldsPanel",
    FIELDS_EMPTY_TEXT = "fieldsEmptyText",
    -- Recap
    LIST_ITEMS       = "listItems",
    ITEM_SLIDER_BOX  = "itemSliderBox",
    TEXT_FROM        = "textFrom",
    TEXT_TO          = "textTo",
    -- Edit fields
    INPUT_NOTE       = "inputNote",
    INPUT_PRICE      = "inputPrice",
    INPUT_QTY        = "inputQty",
    INPUT_VAT        = "inputVat",
    -- Total
    TEXT_TOTAL       = "textTotal",
    TEXT_VAT_HT      = "textVatHt",
    TEXT_VAT_TVA     = "textVatTva",
    TOTAL_SEP        = "totalSep",
    -- Buttons
    BTN_ADD          = "btnAdd",
    BTN_REMOVE       = "btnRemove",
    BTN_SEND         = "btnSend",
}

-- Context enum for Add/Remove routing
InvoicesMainDashboard.CONTEXT_FARMS = 1
InvoicesMainDashboard.CONTEXT_WORK_TYPES = 2
InvoicesMainDashboard.CONTEXT_FIELDS = 3
InvoicesMainDashboard.CONTEXT_ITEMS = 4

function InvoicesMainDashboard.new(target, customMt)
    local self = MessageDialog.new(target, customMt or InvoicesMainDashboard_mt)

    -- Data
    self.farms = {}
    self.workTypes = {}
    self.clientFields = {}
    self.otherFields = {}

    -- Selection state
    self.selectedFarm = nil
    self.selectedFarmIndex = -1
    self.selectedWorkIndex = -1
    self.selectedFieldIndex = -1
    self.selectedFieldSection = -1
    self.selectedItemIndex = -1
    self.selectedWorkItems = {}
    self.selectedFieldItems = {}
    self.lineItems = {}

    -- UI context
    self.activeContext = nil
    self.isSoloMode = false
    self.playerFarmId = nil
    self.suppressEditFieldUpdate = false

    return self
end

-- ===================== LIFECYCLE =====================

function InvoicesMainDashboard:onLoad()
    InvoicesMainDashboard:superClass().onLoad(self)
    self:registerControls(InvoicesMainDashboard.CONTROLS)
end

function InvoicesMainDashboard:onGuiSetupFinished()
    InvoicesMainDashboard:superClass().onGuiSetupFinished(self)

    if self.listFarms ~= nil then
        self.listFarms:setDataSource(self)
        self.listFarms:setDelegate(self)
    end
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:setDataSource(self)
        self.listWorkTypes:setDelegate(self)
    end
    if self.listFields ~= nil then
        self.listFields:setDataSource(self)
        self.listFields:setDelegate(self)
    end
    if self.listItems ~= nil then
        self.listItems:setDataSource(self)
        self.listItems:setDelegate(self)
    end

    self:setupNotePlaceholder()
    self:hookInputCapture()
end

function InvoicesMainDashboard:onOpen()
    InvoicesMainDashboard:superClass().onOpen(self)

    if self._pendingSubdialog then
        self._pendingSubdialog = false
        return
    end

    self:resizeTitleSep()

    local state = InvoicesWizardState.getInstance()
    state:reset()

    -- Reset local state
    self.selectedFarm = nil
    self.selectedFarmIndex = -1
    self.selectedWorkIndex = -1
    self.selectedFieldIndex = -1
    self.selectedFieldSection = -1
    self.selectedItemIndex = -1
    self.selectedWorkItems = {}
    self.selectedFieldItems = {}
    self.lineItems = {}
    self.activeContext = InvoicesMainDashboard.CONTEXT_FARMS

    self:detectGameMode()
    self:loadFarms()
    self:loadWorkTypes()

    if self.listFarms ~= nil then
        self.listFarms:reloadData()
        self.listFarms:setSelectedIndex(0)
    end
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
        self.listWorkTypes:setSelectedIndex(0)
    end
    if self.listFields ~= nil then
        self.listFields:reloadData()
        self.listFields:setSelectedIndex(0)
    end
    if self.listItems ~= nil then
        self.listItems:reloadData()
        self.listItems:setSelectedIndex(0)
    end

    if self.farmSliderBox ~= nil then
        self.farmSliderBox:setVisible(#self.farms > 12)
    end

    self:handleAutoFarmSelection()
    self:updateFieldsPanel()
    self:updateHeader()
    self:rebuildLineItems()
    self:resetEditFields()
    self:updateTotal()
    self:updateButtonStates()
    self:updateSequentialLock()

    if self.listFarms ~= nil then
        FocusManager:setFocus(self.listFarms)
    end
end

function InvoicesMainDashboard:onClose()
    InvoicesMainDashboard:superClass().onClose(self)
end

function InvoicesMainDashboard:delete()
    self.farms = nil
    self.workTypes = nil
    self.clientFields = nil
    self.otherFields = nil
    self.selectedWorkItems = nil
    self.selectedFieldItems = nil
    self.lineItems = nil
    InvoicesMainDashboard:superClass().delete(self)
end

-- ===================== TITLE SEPARATOR =====================

function InvoicesMainDashboard:resizeTitleSep()
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

-- ===================== DATA LOADING (from Step1/2/3) =====================

function InvoicesMainDashboard:detectGameMode()
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
    if g_farmManager then
        for _, farm in pairs(g_farmManager:getFarms()) do
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

function InvoicesMainDashboard:loadFarms()
    self.farms = {}

    if g_farmManager == nil then return end

    local farms = g_farmManager:getFarms()

    local function isValidFarm(farm)
        return farm.farmId ~= nil
           and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID
           and farm.farmId ~= 0
           and farm.name ~= nil
           and farm.name ~= ""
    end

    if self.isSoloMode then
        for _, farm in pairs(farms) do
            if isValidFarm(farm) and farm.farmId == self.playerFarmId then
                table.insert(self.farms, { farmId = farm.farmId, name = farm.name, color = farm.color })
                break
            end
        end
        if #self.farms == 0 then
            for _, farm in pairs(farms) do
                if isValidFarm(farm) then
                    table.insert(self.farms, { farmId = farm.farmId, name = farm.name, color = farm.color })
                    break
                end
            end
        end
    else
        for _, farm in pairs(farms) do
            if isValidFarm(farm) and farm.farmId ~= self.playerFarmId then
                table.insert(self.farms, { farmId = farm.farmId, name = farm.name, color = farm.color })
            end
        end
    end

    table.sort(self.farms, function(a, b) return a.name < b.name end)
end

function InvoicesMainDashboard:loadWorkTypes()
    self.workTypes = {}
    local manager = g_currentMission.invoicesManager
    if manager then
        self.workTypes = manager:getWorkTypes()
    end
end

function InvoicesMainDashboard:loadFields()
    self.clientFields = {}
    self.otherFields = {}

    local state = InvoicesWizardState.getInstance()
    local recipientFarmId = state.recipientFarmId

    if recipientFarmId == nil then return end
    if g_farmlandManager == nil or g_farmlandManager.farmlands == nil then return end

    for farmlandId, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.field ~= nil then
            local field = farmland.field
            local ownerFarmId = farmland.farmId
            local area = field:getAreaHa()
            local fieldData = { id = farmlandId, area = area }

            if ownerFarmId == recipientFarmId then
                table.insert(self.clientFields, fieldData)
            else
                table.insert(self.otherFields, fieldData)
            end
        end
    end

    table.sort(self.clientFields, function(a, b) return a.id < b.id end)
    table.sort(self.otherFields, function(a, b) return a.id < b.id end)
end

function InvoicesMainDashboard:handleAutoFarmSelection()
    if self.isSoloMode and #self.farms == 1 then
        self.selectedFarmIndex = 1
        self.selectedFarm = self.farms[1]

        local state = InvoicesWizardState.getInstance()
        state:setRecipient(self.selectedFarm.farmId, self.selectedFarm.name)

        if self.listFarms ~= nil then
            self.listFarms:setSelectedIndex(1, 1, true)
        end

        self:loadFields()
    end
end

-- ===================== FIELDS PANEL =====================

function InvoicesMainDashboard:requiresFieldSelection()
    for _, workType in ipairs(self.selectedWorkItems) do
        if workType.unit == Invoice.UNIT_HECTARE then
            return true
        end
    end
    return false
end

function InvoicesMainDashboard:updateFieldsPanel()
    local needsFields = self:requiresFieldSelection()

    if self.listFields ~= nil then
        self.listFields:setVisible(needsFields)
    end
    if self.fieldsEmptyText ~= nil then
        self.fieldsEmptyText:setVisible(not needsFields)
    end

    if self.fieldSliderBox ~= nil then
        local totalFields = #self.clientFields + #self.otherFields
        self.fieldSliderBox:setVisible(needsFields and totalFields > 12)
    end

    if needsFields then
        self:loadFields()
        if self.listFields ~= nil then
            self.listFields:reloadData()
        end
    end
end

-- ===================== LINE ITEMS REBUILD =====================

function InvoicesMainDashboard:rebuildLineItems()
    local state = InvoicesWizardState.getInstance()

    state.selectedWorkTypes = self.selectedWorkItems

    if self:requiresFieldSelection() then
        state.selectedFields = self.selectedFieldItems
    else
        state.selectedFields = {}
    end

    state:buildAllLineItems()
    self.lineItems = state.lineItems or {}

    if self.listItems ~= nil then
        self.listItems:reloadData()
    end

    if #self.lineItems > 0 then
        self.selectedItemIndex = #self.lineItems
        if self.listItems ~= nil then
            self.suppressEditFieldUpdate = true
            self.listItems:setSelectedIndex(self.selectedItemIndex)
            self.suppressEditFieldUpdate = false
        end
        self:updateEditFields()
    else
        self.selectedItemIndex = -1
        self:resetEditFields()
    end

    self:updateTotal()
    self:updateButtonStates()
end

function InvoicesMainDashboard:updateSequentialLock()
    local locked = (self.selectedFarm == nil)
    if self.workTypesZone ~= nil then
        self.workTypesZone:setDisabled(locked)
    end
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:setDisabled(locked)
    end
    if self.workSliderBox ~= nil then
        self.workSliderBox:setDisabled(locked)
    end
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
    end
end

-- ===================== HEADER =====================

function InvoicesMainDashboard:updateHeader()
    if self.textFrom ~= nil then
        local senderFarmId = 0
        if g_currentMission.getFarmId ~= nil then
            senderFarmId = g_currentMission:getFarmId()
        else
            local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
            if farm then senderFarmId = farm.farmId end
        end
        local senderFarm = g_farmManager:getFarmById(senderFarmId)
        local senderName = senderFarm and senderFarm.name or "?"
        self.textFrom:setText(string.format(g_i18n:getText("invoice_step4_from"), senderName))
    end

    if self.textTo ~= nil then
        if self.selectedFarm ~= nil then
            self.textTo:setText(string.format(g_i18n:getText("invoice_step4_to"), self.selectedFarm.name))
        else
            self.textTo:setText(string.format(g_i18n:getText("invoice_step4_to"), "—"))
        end
    end
end

-- ===================== TOTAL (from Step4) =====================

function InvoicesMainDashboard:updateTotal()
    local state = InvoicesWizardState.getInstance()
    local total = state:getTotal()

    local totalHT = 0
    local totalVAT = 0
    for _, item in ipairs(state.lineItems) do
        local lineAmount = item.amount or 0
        local lineVatRate = item.vatRate or 0
        local lineVAT = 0
        if lineVatRate > 0 then
            lineVAT = math.floor(lineAmount * lineVatRate / (1 + lineVatRate) + 0.5)
        end
        totalHT = totalHT + (lineAmount - lineVAT)
        totalVAT = totalVAT + lineVAT
    end

    if self.textTotal ~= nil then
        self.textTotal:setText(g_i18n:formatMoney(total, 0, true, true))
    end

    if self.textVatHt ~= nil and self.textVatTva ~= nil then
        local vatEnabled = g_currentMission.invoicesManager ~= nil and g_currentMission.invoicesManager.service:isVatEnabled()

        if vatEnabled and totalVAT > 0 then
            local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), g_i18n:formatMoney(totalHT, 0, true, false))
            local tvaText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), g_i18n:formatMoney(totalVAT, 0, true, false))
            self.textVatHt:setText(htText)
            self.textVatTva:setText(tvaText)
            self.textVatHt:setVisible(true)
            self.textVatTva:setVisible(true)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, tvaText)
            end
        elseif not vatEnabled then
            local htText = string.format("%s :  —", g_i18n:getText("invoice_label_subtotal_ht"))
            local tvaText = string.format("%s :  —", g_i18n:getText("invoice_label_vat"))
            self.textVatHt:setText(htText)
            self.textVatTva:setText(tvaText)
            self.textVatHt:setVisible(true)
            self.textVatTva:setVisible(true)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, tvaText)
            end
        else
            local htText = string.format("%s :  —", g_i18n:getText("invoice_label_subtotal_ht"))
            local tvaText = string.format("%s :  —", g_i18n:getText("invoice_label_vat"))
            self.textVatHt:setText(htText)
            self.textVatTva:setText(tvaText)
            self.textVatHt:setVisible(true)
            self.textVatTva:setVisible(true)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, tvaText)
            end
        end
    end

    if self.btnSend ~= nil then
        local state = InvoicesWizardState.getInstance()
        self.btnSend:setDisabled(not state:canCreateInvoice())
    end
end

function InvoicesMainDashboard:resizeTotalSep(htText, tvaText)
    if self.totalSep == nil or self.textVatHt == nil then return end

    if self._sepHeight == nil then
        self._sepHeight = self.totalSep.absSize[2]
    end

    local textSize = self.textVatHt.textSize
    local htWidth = getTextWidth(textSize, htText)
    local tvaWidth = self.textVatTva ~= nil and getTextWidth(self.textVatTva.textSize, tvaText) or 0
    local maxTextWidth = math.max(htWidth, tvaWidth)

    self.totalSep:setSize(maxTextWidth, self._sepHeight)
    if self.totalSep.parent ~= nil and self.totalSep.parent.invalidateLayout ~= nil then
        self.totalSep.parent:invalidateLayout()
    end
end

-- ===================== EDIT FIELDS (from Step4) =====================

function InvoicesMainDashboard:setupNotePlaceholder()
    if self.inputNote == nil then return end
    self._notePlaceholder = self.inputNote:getDescendantByName("notePlaceholder")
    if self._notePlaceholder == nil then return end

    local placeholder = self._notePlaceholder
    local origSetCaptureInput = self.inputNote.setCaptureInput
    self.inputNote.setCaptureInput = function(inputSelf, isCapturing)
        origSetCaptureInput(inputSelf, isCapturing)
        if isCapturing then
            placeholder:setVisible(false)
        else
            placeholder:setVisible(inputSelf.text == nil or inputSelf.text == "")
        end
    end
end

function InvoicesMainDashboard:hookInputCapture()
    self._activeInput = nil
    local inputs = {self.inputPrice, self.inputQty, self.inputVat, self.inputNote}
    for _, input in ipairs(inputs) do
        if input ~= nil then
            local origFn = input.setCaptureInput
            local selfRef = self
            local inputRef = input
            input.setCaptureInput = function(inputSelf, isCapturing)
                origFn(inputSelf, isCapturing)
                if isCapturing then
                    selfRef._activeInput = inputRef
                elseif selfRef._activeInput == inputRef then
                    selfRef._activeInput = nil
                end
            end
        end
    end
end

function InvoicesMainDashboard:inputEvent(action, value, direction, isAnalog, isMouse, deviceCategory, bindingName)
    if action == InputAction.MENU_CANCEL and self._activeInput ~= nil then
        return true
    end
    if action == InputAction.MENU_DELETE and self._activeInput == nil then
        if self.btnRemove ~= nil and not self.btnRemove.disabled then
            self:onClickRemove()
            return true
        end
    end
    return InvoicesMainDashboard:superClass().inputEvent(self, action, value, direction, isAnalog, isMouse, deviceCategory, bindingName)
end

function InvoicesMainDashboard:resetEditFields()
    if self.inputPrice ~= nil then
        self.inputPrice:setText("")
        self.inputPrice:setDisabled(true)
    end
    if self.inputQty ~= nil then
        self.inputQty:setText("")
        self.inputQty:setDisabled(true)
    end
    if self.inputVat ~= nil then
        self.inputVat:setText("")
        self.inputVat:setDisabled(true)
    end
    if self.inputNote ~= nil then
        self.inputNote:setText("")
    end
    if self._notePlaceholder ~= nil then
        self._notePlaceholder:setVisible(true)
    end
end

function InvoicesMainDashboard:updateEditFields()
    local item = nil
    if self.selectedItemIndex >= 1 and self.selectedItemIndex <= #self.lineItems then
        item = self.lineItems[self.selectedItemIndex]
    end

    if self.inputPrice ~= nil then
        if item ~= nil then
            self.inputPrice:setText(string.format("%.0f", item.price or 0))
            self.inputPrice:setDisabled(false)
        else
            self.inputPrice:setText("")
            self.inputPrice:setDisabled(true)
        end
    end

    if self.inputQty ~= nil then
        if item ~= nil then
            if item.unit == Invoice.UNIT_HECTARE then
                self.inputQty:setText(string.format("%.2f", item.quantity or 0))
                self.inputQty:setDisabled(true)
            elseif item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER then
                self.inputQty:setText(string.format("%.2f", item.quantity or 0))
                self.inputQty:setDisabled(false)
            else
                self.inputQty:setText(string.format("%.0f", item.quantity or 0))
                self.inputQty:setDisabled(false)
            end
        else
            self.inputQty:setText("")
            self.inputQty:setDisabled(true)
        end
    end

    if self.inputVat ~= nil then
        local vatEnabled = g_currentMission.invoicesManager ~= nil and g_currentMission.invoicesManager.service:isVatEnabled()
        if item ~= nil then
            self.inputVat:setText(string.format("%.1f", (item.vatRate or 0) * 100))
            self.inputVat:setDisabled(not vatEnabled)
        else
            self.inputVat:setText("")
            self.inputVat:setDisabled(true)
        end
    end
end

function InvoicesMainDashboard:updateSelectedCellValues()
    local cell = self._selectedCell
    if cell == nil then return end
    local item = self.lineItems[self.selectedItemIndex]
    if item == nil then return end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(item.price or 0, 0, true, false))
    end

    local cellQty = cell:getDescendantByName("cellQty")
    if cellQty ~= nil then
        local qtyText
        if item.unit == Invoice.UNIT_HECTARE or item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER then
            qtyText = string.format("%.2f", item.quantity or 0)
        else
            qtyText = string.format("%.0f", item.quantity or 0)
        end
        cellQty:setText(qtyText)
    end

    local cellAmount = cell:getDescendantByName("cellAmount")
    if cellAmount ~= nil then
        cellAmount:setText(g_i18n:formatMoney(item.amount or 0, 0, true, false))
    end

    local cellVat = cell:getDescendantByName("cellVat")
    if cellVat ~= nil then
        local vatEnabled = g_currentMission.invoicesManager ~= nil and g_currentMission.invoicesManager.service:isVatEnabled()
        if not vatEnabled then
            cellVat:setText("N/A")
        else
            local vatRate = item.vatRate or 0
            if vatRate > 0 then
                cellVat:setText(string.format("%.1f%%", vatRate * 100))
            else
                cellVat:setText("—")
            end
        end
    end
end

-- ===================== TEXT INPUT CALLBACKS (from Step4) =====================

function InvoicesMainDashboard:onPriceTextChanged(element, text)
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.lineItems then return end

    local filtered = string.gsub(text or "", "[^0-9]", "")
    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local item = self.lineItems[self.selectedItemIndex]
    local value = tonumber(filtered or "") or 0

    if value >= 0 then
        item.price = value
    end
    item.amount = MathUtil.round(item.price * item.quantity)

    self:updateSelectedCellValues()
    self:updateTotal()
end

function InvoicesMainDashboard:onQtyTextChanged(element, text)
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.lineItems then return end

    local item = self.lineItems[self.selectedItemIndex]
    if item.unit == Invoice.UNIT_HECTARE then return end

    local allowDecimal = (item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER)
    local filtered
    if allowDecimal then
        filtered = string.gsub(text or "", "[^0-9.]", "")
        local _, dotCount = string.gsub(filtered, "%.", "")
        if dotCount > 1 then
            filtered = string.gsub(filtered, "%.", "", dotCount - 1)
        end
    else
        filtered = string.gsub(text or "", "[^0-9]", "")
    end

    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local value = tonumber(filtered or "") or 0

    if value >= 0 then
        item.quantity = value
    end
    item.amount = MathUtil.round(item.price * item.quantity)

    self:updateSelectedCellValues()
    self:updateTotal()
end

function InvoicesMainDashboard:onVatRateTextChanged(element, text)
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.lineItems then return end

    local filtered = string.gsub(text or "", "[^0-9.]", "")
    local _, dotCount = string.gsub(filtered, "%.", "")
    if dotCount > 1 then
        filtered = string.gsub(filtered, "%.", "", dotCount - 1)
    end
    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local value = tonumber(filtered or "") or 0
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end

    local item = self.lineItems[self.selectedItemIndex]
    item.vatRate = value / 100

    self:updateSelectedCellValues()
    self:updateTotal()
end

-- ===================== DATA SOURCE (4 lists) =====================

function InvoicesMainDashboard:getNumberOfSections(list)
    if list == self.listFields then
        return 2
    end
    return 1
end

function InvoicesMainDashboard:getNumberOfItemsInSection(list, section)
    if list == self.listFarms then
        return #self.farms
    elseif list == self.listWorkTypes then
        return #self.workTypes
    elseif list == self.listFields then
        if section == 1 then
            return #self.clientFields
        elseif section == 2 then
            return #self.otherFields
        end
        return 0
    elseif list == self.listItems then
        return #self.lineItems
    end
    return 0
end

function InvoicesMainDashboard:getTitleForSectionHeader(list, section)
    if list == self.listFields then
        if section == 1 then
            return g_i18n:getText("invoice_wizard_client_fields")
        elseif section == 2 then
            return g_i18n:getText("invoice_wizard_other_fields")
        end
    end
    return nil
end

function InvoicesMainDashboard:getSectionHeaderHeight(list, section)
    if list == self.listFields then
        return 24
    end
    return 0
end

function InvoicesMainDashboard:getCellTypeForSectionHeader(list, section)
    if list == self.listFields then
        return "section"
    end
    return nil
end

function InvoicesMainDashboard:getCellTypeForItemInSection(list, section, index)
    if list == self.listFarms then
        return "farmTemplate"
    elseif list == self.listWorkTypes then
        return "workTypeTemplate"
    elseif list == self.listFields then
        return "fieldTemplate"
    elseif list == self.listItems then
        return "itemTemplate"
    end
    return nil
end

function InvoicesMainDashboard:populateCellForItemInSection(list, section, index, cell)
    if list == self.listFarms then
        self:populateFarmCell(index, cell)
    elseif list == self.listWorkTypes then
        self:populateWorkTypeCell(index, cell)
    elseif list == self.listFields then
        self:populateFieldCell(section, index, cell)
    elseif list == self.listItems then
        self:populateLineItemCell(index, cell)
    end
end

function InvoicesMainDashboard:populateFarmCell(index, cell)
    local farm = self.farms[index]
    if farm == nil then return end

    local isConfirmed = (self.selectedFarm ~= nil and self.selectedFarm.farmId == farm.farmId)

    local cellTick = cell:getDescendantByName("cellTick")
    if cellTick ~= nil then
        cellTick:setVisible(isConfirmed)
    end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(farm.name)
    end
end

function InvoicesMainDashboard:populateWorkTypeCell(index, cell)
    local workType = self.workTypes[index]
    if workType == nil then return end

    local locked = (self.selectedFarm == nil)
    cell:setDisabled(locked)

    local isConfirmed = self:isWorkTypeSelected(workType)

    local cellTick = cell:getDescendantByName("cellTick")
    if cellTick ~= nil then
        cellTick:setVisible(isConfirmed)
    end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setDisabled(locked)
        cellName:setText(g_i18n:getText(workType.nameKey))
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setDisabled(locked)
        local manager = g_currentMission.invoicesManager
        local unitKey = manager and manager:getUnitKey(workType.unit) or "invoices_unit_piece"
        local unitStr = g_i18n:getText(unitKey)

        local selectedEntry = self:getSelectedWorkTypeEntry(workType)
        local price = (selectedEntry and selectedEntry.customPrice)
            or (manager and manager:getAdjustedPrice(workType.id))
            or workType.basePrice or 0

        local priceStr
        if workType.unit == Invoice.UNIT_LITER then
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price, 2), unitStr)
        else
            priceStr = string.format("%s / %s", g_i18n:formatMoney(price), unitStr)
        end
        cellPrice:setText(priceStr)
    end
end

function InvoicesMainDashboard:getSelectedWorkTypeEntry(workType)
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey then
            return item
        end
    end
    return nil
end

function InvoicesMainDashboard:populateFieldCell(section, index, cell)
    local fieldData = nil
    if section == 1 then
        fieldData = self.clientFields[index]
    elseif section == 2 then
        fieldData = self.otherFields[index]
    end
    if fieldData == nil then return end

    local isConfirmed = self:isFieldSelected(fieldData)

    local cellTick = cell:getDescendantByName("cellTick")
    if cellTick ~= nil then
        cellTick:setVisible(isConfirmed)
    end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then
        cellName:setText(string.format(g_i18n:getText("invoice_format_field_id"), fieldData.id))
    end

    local cellArea = cell:getDescendantByName("cellArea")
    if cellArea ~= nil then
        cellArea:setText(string.format("%.2f ha", fieldData.area))
    end
end

function InvoicesMainDashboard:populateLineItemCell(index, cell)
    local item = self.lineItems[index]
    if item == nil then return end

    if index == self.selectedItemIndex then
        self._selectedCell = cell
    end

    local manager = g_currentMission.invoicesManager

    local cellDesignation = cell:getDescendantByName("cellDesignation")
    if cellDesignation ~= nil then
        local name = item.name
        if name == nil or name == "" then
            local workType = manager and manager:getWorkTypeById(item.workTypeId) or nil
            name = workType and g_i18n:getText(workType.nameKey) or "?"
        end
        cellDesignation:setText(name)
    end

    local cellField = cell:getDescendantByName("cellField")
    if cellField ~= nil then
        if item.fieldId ~= nil then
            cellField:setText(string.format(g_i18n:getText("invoice_format_fieldId"), item.fieldId))
        else
            cellField:setText("—")
        end
    end

    local cellQty = cell:getDescendantByName("cellQty")
    if cellQty ~= nil then
        local qtyText
        if item.unit == Invoice.UNIT_HECTARE or item.unit == Invoice.UNIT_HOUR or item.unit == Invoice.UNIT_LITER then
            qtyText = string.format("%.2f", item.quantity or 0)
        else
            qtyText = string.format("%.0f", item.quantity or 0)
        end
        cellQty:setText(qtyText)
    end

    local cellUnit = cell:getDescendantByName("cellUnit")
    if cellUnit ~= nil then
        local unitKey = manager and manager:getUnitKey(item.unit) or "invoice_invoices_unit_piece"
        cellUnit:setText(g_i18n:getText(unitKey))
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(item.price or 0, 0, true, false))
    end

    local cellVat = cell:getDescendantByName("cellVat")
    if cellVat ~= nil then
        local vatEnabled = manager ~= nil and manager.service:isVatEnabled()
        if not vatEnabled then
            cellVat:setText("N/A")
        else
            local vatRate = item.vatRate or 0
            if vatRate > 0 then
                cellVat:setText(string.format("%.1f%%", vatRate * 100))
            else
                cellVat:setText("—")
            end
        end
    end

    local cellAmount = cell:getDescendantByName("cellAmount")
    if cellAmount ~= nil then
        cellAmount:setText(g_i18n:formatMoney(item.amount or 0, 0, true, false))
    end
end

-- ===================== LIST DELEGATES =====================

function InvoicesMainDashboard:onListSelectionChanged(list, section, index)
    if list == self.listFarms then
        self.activeContext = InvoicesMainDashboard.CONTEXT_FARMS
        self.selectedFarmIndex = index
    elseif list == self.listWorkTypes then
        self.activeContext = InvoicesMainDashboard.CONTEXT_WORK_TYPES
        self.selectedWorkIndex = index
    elseif list == self.listFields then
        self.activeContext = InvoicesMainDashboard.CONTEXT_FIELDS
        self.selectedFieldSection = section
        self.selectedFieldIndex = index
    elseif list == self.listItems then
        self.activeContext = InvoicesMainDashboard.CONTEXT_ITEMS
        self.selectedItemIndex = index
        if not self.suppressEditFieldUpdate then
            self:refreshItemListKeepSelection()
            self:updateEditFields()
        end
    end

    self:updateButtonStates()
end

function InvoicesMainDashboard:refreshItemListKeepSelection()
    if self.listItems == nil then return end
    local savedIndex = self.selectedItemIndex
    self.suppressEditFieldUpdate = true
    self.listItems:reloadData()
    if savedIndex >= 1 and savedIndex <= #self.lineItems then
        self.listItems:setSelectedIndex(savedIndex)
    end
    self.suppressEditFieldUpdate = false
end

-- ===================== SELECTION HELPERS =====================

function InvoicesMainDashboard:isWorkTypeSelected(workType)
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey then
            return true
        end
    end
    return false
end

function InvoicesMainDashboard:isFieldSelected(fieldData)
    for _, item in ipairs(self.selectedFieldItems) do
        if item.id == fieldData.id then
            return true
        end
    end
    return false
end

function InvoicesMainDashboard:getSelectedFieldData()
    if self.selectedFieldSection == 1 then
        return self.clientFields[self.selectedFieldIndex]
    elseif self.selectedFieldSection == 2 then
        return self.otherFields[self.selectedFieldIndex]
    end
    return nil
end

-- ===================== BUTTON STATES =====================

function InvoicesMainDashboard:updateButtonStates()
    local canAdd = false

    if self.activeContext == InvoicesMainDashboard.CONTEXT_FARMS then
        local validIndex = (self.selectedFarmIndex >= 1 and self.selectedFarmIndex <= #self.farms)
        local farm = validIndex and self.farms[self.selectedFarmIndex] or nil
        local alreadySelected = farm ~= nil and self.selectedFarm ~= nil and self.selectedFarm.farmId == farm.farmId
        canAdd = validIndex and not alreadySelected
    elseif self.activeContext == InvoicesMainDashboard.CONTEXT_WORK_TYPES then
        local validIndex = (self.selectedFarm ~= nil and self.selectedWorkIndex >= 1 and self.selectedWorkIndex <= #self.workTypes)
        local wt = validIndex and self.workTypes[self.selectedWorkIndex] or nil
        local alreadySelected = wt ~= nil and self:isWorkTypeSelected(wt)
        canAdd = validIndex and not alreadySelected
    elseif self.activeContext == InvoicesMainDashboard.CONTEXT_FIELDS then
        local validIndex = (self.selectedFieldSection > 0 and self.selectedFieldIndex > 0)
        local fieldData = validIndex and self:getSelectedFieldData() or nil
        local alreadySelected = fieldData ~= nil and self:isFieldSelected(fieldData)
        canAdd = validIndex and not alreadySelected
    end

    if self.btnAdd ~= nil then
        self.btnAdd:setDisabled(not canAdd)
    end
    if self.btnRemove ~= nil then
        local canRemove = (self.selectedItemIndex >= 1 and self.selectedItemIndex <= #self.lineItems)
        self.btnRemove:setDisabled(not canRemove)
    end
    if self.btnSend ~= nil then
        local state = InvoicesWizardState.getInstance()
        self.btnSend:setDisabled(not state:canCreateInvoice())
    end
end

-- ===================== BUTTON ACTIONS =====================

function InvoicesMainDashboard:onClickAdd()
    if self.activeContext == InvoicesMainDashboard.CONTEXT_FARMS then
        self:toggleFarm()
    elseif self.activeContext == InvoicesMainDashboard.CONTEXT_WORK_TYPES then
        self:toggleWorkType()
    elseif self.activeContext == InvoicesMainDashboard.CONTEXT_FIELDS then
        self:toggleField()
    end
end

function InvoicesMainDashboard:onClickRemove()
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.lineItems then return end

    local item = self.lineItems[self.selectedItemIndex]
    if item == nil then return end

    if item.unit == Invoice.UNIT_HECTARE and item.fieldId ~= nil and item.fieldId ~= 0 then
        -- Remove the field that generated this line item
        for i, f in ipairs(self.selectedFieldItems) do
            if f.id == item.fieldId then
                table.remove(self.selectedFieldItems, i)
                break
            end
        end
    else
        -- Remove the work type that generated this line item
        for i, wt in ipairs(self.selectedWorkItems) do
            if wt.id == item.workTypeId then
                table.remove(self.selectedWorkItems, i)
                break
            end
        end
    end

    self:rebuildLineItems()

    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
    end
    if self.listFields ~= nil then
        self.listFields:reloadData()
    end
end

-- Farm toggle
function InvoicesMainDashboard:toggleFarm()
    if self.selectedFarmIndex < 1 or self.selectedFarmIndex > #self.farms then return end

    local farm = self.farms[self.selectedFarmIndex]
    -- Add-only: if already selected, do nothing
    if self.selectedFarm ~= nil and self.selectedFarm.farmId == farm.farmId then return end

    local state = InvoicesWizardState.getInstance()
    self.selectedFarm = farm
    state:setRecipient(farm.farmId, farm.name)
    self.selectedFieldItems = {}

    self:loadFields()
    self:updateFieldsPanel()
    self:updateHeader()
    self:rebuildLineItems()

    if self.listFarms ~= nil then
        self.listFarms:reloadData()
        self.listFarms:setSelectedIndex(self.selectedFarmIndex)
    end

    self:updateButtonStates()
    self:updateSequentialLock()
end

-- Work type toggle
function InvoicesMainDashboard:toggleWorkType()
    if self.selectedFarm == nil then return end
    if self.selectedWorkIndex < 1 or self.selectedWorkIndex > #self.workTypes then return end

    local workType = self.workTypes[self.selectedWorkIndex]

    -- Add-only: skip if already selected
    if self:isWorkTypeSelected(workType) then return end

    if workType.fillTypeDialog then
        self:openFillTypeDialog(workType)
    else
        table.insert(self.selectedWorkItems, workType)
        self:updateFieldsPanel()
        self:rebuildLineItems()
        if self.listWorkTypes ~= nil then
            self.listWorkTypes:reloadData()
            self.listWorkTypes:setSelectedIndex(self.selectedWorkIndex)
        end
    end
end

function InvoicesMainDashboard:openFillTypeDialog(workType)
    self._pendingSubdialog = true
    local savedWorkIndex = self.selectedWorkIndex
    local dialog = g_gui:showDialog("InvoicesFillTypeDialog")
    if dialog ~= nil and dialog.target ~= nil then
        dialog.target:setCallback(self, function(dashSelf, fillType)
            dashSelf._pendingSubdialog = false
            if fillType == nil then return end
            local wt = {}
            for k, v in pairs(workType) do wt[k] = v end
            wt.customPrice = fillType.pricePerLiter
            wt.displayOverride = g_i18n:getText(workType.nameKey) .. " (" .. fillType.name .. ")"
            table.insert(dashSelf.selectedWorkItems, wt)
            dashSelf:updateFieldsPanel()
            dashSelf:rebuildLineItems()
            if dashSelf.listWorkTypes ~= nil then
                dashSelf.listWorkTypes:reloadData()
                dashSelf.listWorkTypes:setSelectedIndex(savedWorkIndex)
            end
        end)
    else
        self._pendingSubdialog = false
    end
end

-- Field toggle
function InvoicesMainDashboard:toggleField()
    local fieldData = self:getSelectedFieldData()
    if fieldData == nil then return end

    -- Add-only: skip if already selected
    if self:isFieldSelected(fieldData) then return end

    table.insert(self.selectedFieldItems, fieldData)
    self:rebuildLineItems()

    if self.listFields ~= nil then
        self.listFields:reloadData()
        self.listFields:setSelectedIndex(self.selectedFieldIndex, self.selectedFieldSection)
    end
end

-- ===================== SEND / CANCEL =====================

function InvoicesMainDashboard:onClickSend()
    local state = InvoicesWizardState.getInstance()

    local note = ""
    if self.inputNote ~= nil then
        note = self.inputNote.text or ""
    end

    for _, item in ipairs(state.lineItems) do
        item.note = note
    end

    local invoice = state:createInvoice()

    if invoice then
        self:close()
        InfoDialog.show(g_i18n:getText("invoice_wizard_invoice_created"))
    else
        InfoDialog.show(g_i18n:getText("invoice_wizard_invoice_failed"))
    end
end

function InvoicesMainDashboard:onClickCancel()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self:close()
end
