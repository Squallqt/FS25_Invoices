-- Copyright © 2026 Squallqt. All rights reserved.
-- Consolidated invoice creation dialog: farm/work/field selection, line item editing, and send dispatch.
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
    BTN_SEND         = "btnSend",
}

-- Context enum for Add/Remove routing
InvoicesMainDashboard.CONTEXT_FARMS = 1
InvoicesMainDashboard.CONTEXT_WORK_TYPES = 2
InvoicesMainDashboard.CONTEXT_FIELDS = 3
InvoicesMainDashboard.CONTEXT_ITEMS = 4

---Creates new invoices main dashboard instance
-- @param table target Parent target element
-- @param table? customMt Optional custom metatable
-- @return InvoicesMainDashboard instance The new dashboard instance
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
    self.displayItems = {}

    -- UI context
    self.activeContext = nil
    self.isSoloMode = false
    self.playerFarmId = nil
    self.suppressEditFieldUpdate = false

    return self
end

-- Lifecycle

---Loads dialog controls
function InvoicesMainDashboard:onLoad()
    InvoicesMainDashboard:superClass().onLoad(self)
    self:registerControls(InvoicesMainDashboard.CONTROLS)
end

---Finalizes GUI setup
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

---Called when dialog opens, resets wizard state and initializes all panels
function InvoicesMainDashboard:onOpen()
    InvoicesMainDashboard:superClass().onOpen(self)

    if self._pendingSubdialog then
        self._pendingSubdialog = false
        return
    end

    self:resizeTitleSep()

    local state = InvoicesWizardState.getInstance()
    state:reset()

    self.selectedFarm = nil
    self.selectedFarmIndex = -1
    self.selectedWorkIndex = -1
    self.selectedFieldIndex = -1
    self.selectedFieldSection = -1
    self.selectedItemIndex = -1
    self.selectedWorkItems = {}
    self.selectedFieldItems = {}
    self.lineItems = {}
    self.displayItems = {}
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

    self:updateRecapSliderVisibility()

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

---Called when dialog closes, resets wizard state
function InvoicesMainDashboard:onClose()
    InvoicesMainDashboard:superClass().onClose(self)
    self._pendingSubdialog = false
    local state = InvoicesWizardState.getInstance()
    state:reset()
end

---Cleans up internal data tables and calls parent delete
function InvoicesMainDashboard:delete()
    self.farms = nil
    self.workTypes = nil
    self.clientFields = nil
    self.otherFields = nil
    self.selectedWorkItems = nil
    self.selectedFieldItems = nil
    self.lineItems = nil
    self.displayItems = nil
    InvoicesMainDashboard:superClass().delete(self)
end

-- Title separator

---Resizes title separator to match title text width
function InvoicesMainDashboard:resizeTitleSep()
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

-- Data loading

---Detects solo or multiplayer mode and resolves current player farm ID
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

---Loads available farms sorted by name, filtering based on game mode
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

---Loads work types from manager sorted by localized name
function InvoicesMainDashboard:loadWorkTypes()
    self.workTypes = {}

    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return
    end

    local source = manager:getWorkTypes() or {}

    -- Keep source order/IDs untouched: sort only the local UI copy.
    for i = 1, #source do
        self.workTypes[i] = source[i]
    end

    table.sort(self.workTypes, function(a, b)
        local aName = g_i18n:getText(a.nameKey or "") or ""
        local bName = g_i18n:getText(b.nameKey or "") or ""
        if aName == bName then
            return (a.id or 0) < (b.id or 0)
        end
        return aName < bName
    end)
end

---Loads farmland fields split into client-owned and other categories
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

---Auto-selects the only available farm in solo mode
function InvoicesMainDashboard:handleAutoFarmSelection()
    if self.isSoloMode and #self.farms == 1 then
        self.selectedFarmIndex = 1
        self.selectedFarm = self.farms[1]

        local state = InvoicesWizardState.getInstance()
        state:setRecipient(self.selectedFarm.farmId, self.selectedFarm.name)

        if self.listFarms ~= nil then
            self.listFarms:reloadData()
            self.listFarms:setSelectedIndex(1, 1, true)
        end

        self:loadFields()
    end
end

-- Fields panel state

---Checks if any selected work type requires field-based hectare billing
-- @return boolean needsFields True if field selection is needed
function InvoicesMainDashboard:requiresFieldSelection()
    for _, workType in ipairs(self.selectedWorkItems) do
        if workType.unit == Invoice.UNIT_HECTARE then
            return true
        end
    end
    return false
end

---Shows or hides field selection panel based on selected work types
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

-- Line item reconciliation

---Rebuilds all line items from wizard state and refreshes display
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
    self:buildDisplayItems()

    if self.listItems ~= nil then
        self.listItems:reloadData()
    end

    self:updateRecapSliderVisibility()

    if #self.displayItems > 0 then
        if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then
            self.selectedItemIndex = #self.displayItems
        end
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

---Builds display items from line items, grouping consumables by group key
function InvoicesMainDashboard:buildDisplayItems()
    self.displayItems = {}

    local consumableGroups = {}
    local consumableOrder = {}

    for _, item in ipairs(self.lineItems) do
        if item.isConsumable and item.groupKey ~= nil then
            local gk = item.groupKey
            if consumableGroups[gk] == nil then
                consumableGroups[gk] = {
                    isConsumable   = true,
                    groupKey       = gk,
                    workTypeId     = item.workTypeId,
                    name           = item.name,
                    iconFilename   = item.iconFilename,
                    unit           = item.unit,
                    vatRate        = item.vatRate,
                    consumableFillTypeIndex = item.consumableFillTypeIndex,
                    consumableXmlFilename  = item.consumableXmlFilename,
                    consumableFillLevel    = item.consumableFillLevel,
                    quantity       = 0,
                    totalAmount    = 0,
                    lineIndices    = {},
                }
                table.insert(consumableOrder, gk)
            end
            local group = consumableGroups[gk]
            group.quantity = group.quantity + 1
            group.totalAmount = group.totalAmount + (item.amount or 0)
            table.insert(group.lineIndices, #self.lineItems)
        else
            table.insert(self.displayItems, item)
        end
    end

    for _, gk in ipairs(consumableOrder) do
        local group = consumableGroups[gk]
        group.price = group.quantity > 0 and math.floor(group.totalAmount / group.quantity) or 0
        group.amount = group.totalAmount
        table.insert(self.displayItems, group)
    end
end

---Shows or hides recap list scroll slider based on item count
function InvoicesMainDashboard:updateRecapSliderVisibility()
    if self.itemSliderBox ~= nil and self.listItems ~= nil then
        local itemCount = #self.displayItems
        local maxVisibleItems = math.floor(282 / 32)
        self.itemSliderBox:setVisible(itemCount > maxVisibleItems)
    end
end

---Locks work type panel when no farm is selected
function InvoicesMainDashboard:updateSequentialLock()
    local locked = (self.selectedFarm == nil)
    local savedContext = self.activeContext
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
    self.activeContext = savedContext
    self:updateButtonStates()
end

-- Header display

---Updates sender and recipient farm name display
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

-- Total computation and VAT display

---Computes and displays HT, VAT and total amounts
function InvoicesMainDashboard:updateTotal()
    local state = InvoicesWizardState.getInstance()
    local total = state:getTotal()
    local totalText = g_i18n:formatMoney(total, 0, true, false)

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
        self.textTotal:setText(totalText)
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
                self:resizeTotalSep(htText, tvaText, totalText)
            end
        elseif not vatEnabled then
            local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), g_i18n:getText("invoice_label_na"))
            local tvaText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), g_i18n:getText("invoice_label_na"))
            self.textVatHt:setText(htText)
            self.textVatTva:setText(tvaText)
            self.textVatHt:setVisible(true)
            self.textVatTva:setVisible(true)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, tvaText, totalText)
            end
        else
            local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), g_i18n:getText("invoice_label_na"))
            local tvaText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), g_i18n:getText("invoice_label_na"))
            self.textVatHt:setText(htText)
            self.textVatTva:setText(tvaText)
            self.textVatHt:setVisible(true)
            self.textVatTva:setVisible(true)
            if self.totalSep ~= nil then
                self.totalSep:setVisible(true)
                self:resizeTotalSep(htText, tvaText, totalText)
            end
        end
    end

    if self.btnSend ~= nil then
        local state = InvoicesWizardState.getInstance()
        self.btnSend:setDisabled(not state:canCreateInvoice())
    end
end

---Resizes total separator to fit VAT and total amount text
-- @param string htText Formatted HT amount text
-- @param string tvaText Formatted TVA amount text
-- @param string totalText Formatted total amount text
function InvoicesMainDashboard:resizeTotalSep(htText, tvaText, totalText)
    if self.totalSep == nil or self.textVatHt == nil then return end

    if self._sepOrigX == nil then
        self._sepOrigX = self.totalSep.position[1]
        self._sepOrigW = self.totalSep.size[1]
    end

    local textSize = self.textVatHt.textSize
    local htWidth = getTextWidth(textSize, htText)
    local tvaWidth = self.textVatTva ~= nil and getTextWidth(self.textVatTva.textSize, tvaText) or 0
    local totalWidth = self.textTotal ~= nil and getTextWidth(self.textTotal.textSize, totalText or self.textTotal.text or "") or 0
    totalWidth = totalWidth + (20 * g_pixelSizeScaledX)
    local maxTextWidth = math.max(htWidth, tvaWidth, totalWidth)

    local newW = math.min(maxTextWidth, self._sepOrigW)
    local newX = self._sepOrigX + self._sepOrigW - newW
    self.totalSep:setPosition(newX, self.totalSep.position[2])
    self.totalSep:setSize(newW, self.totalSep.size[2])
end

-- Edit field management

---Sets up note input placeholder visibility toggle on focus
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

---Hooks input capture on price, quantity, VAT and note fields to track active input
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

---Intercepts MENU_CANCEL while an input field is active
-- @param integer action Input action identifier
-- @param float value Input value
-- @param integer direction Input direction
-- @param boolean isAnalog True if analog input
-- @param boolean isMouse True if mouse input
-- @param integer deviceCategory Device category
-- @param string bindingName Binding name
-- @return boolean consumed True if input was consumed
function InvoicesMainDashboard:inputEvent(action, value, direction, isAnalog, isMouse, deviceCategory, bindingName)
    if action == InputAction.MENU_CANCEL and self._activeInput ~= nil then
        return true
    end
    return InvoicesMainDashboard:superClass().inputEvent(self, action, value, direction, isAnalog, isMouse, deviceCategory, bindingName)
end

---Resets all edit fields to empty and disabled state
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

---Updates edit fields with values from currently selected display item
function InvoicesMainDashboard:updateEditFields()
    if self._updatingEditFields then return end
    self._updatingEditFields = true

    local item = nil
    if self.selectedItemIndex >= 1 and self.selectedItemIndex <= #self.displayItems then
        item = self.displayItems[self.selectedItemIndex]
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
            elseif item.unit == Invoice.UNIT_HOUR then
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

    self._updatingEditFields = false
end

---Updates price, quantity, VAT and amount text in the currently selected list cell
function InvoicesMainDashboard:updateSelectedCellValues()
    local cell = self._selectedCell
    if cell == nil then return end
    local item = self.displayItems[self.selectedItemIndex]
    if item == nil then return end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(g_i18n:formatMoney(item.price or 0, 0, true, false))
    end

    local cellQty = cell:getDescendantByName("cellQty")
    if cellQty ~= nil then
        local qtyText
        if item.unit == Invoice.UNIT_HECTARE or item.unit == Invoice.UNIT_HOUR then
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
            cellVat:setText(g_i18n:getText("invoice_label_na"))
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

-- Text input callbacks

---Called when price input text changes, updates item price and recalculates amount
-- @param table element Input element
-- @param string text New text value
function InvoicesMainDashboard:onPriceTextChanged(element, text)
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then return end

    local filtered = string.gsub(text or "", "[^0-9]", "")
    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local item = self.displayItems[self.selectedItemIndex]
    if item == nil then return end

    local value = tonumber(filtered or "") or 0

    -- Consumable grouped row: update price on all underlying selectedWorkItems
    if item.isConsumable and item.groupKey ~= nil then
        if value >= 0 then
            item.price = value
            item.amount = MathUtil.round(value * item.quantity)
            for _, swi in ipairs(self.selectedWorkItems) do
                if swi.isConsumable and swi.groupKey == item.groupKey then
                    swi.customPrice = value
                end
            end
            self:rebuildLineItems()
        end
        return
    end

    -- Vehicle row: update price on the specific selectedWorkItem
    if item.vehicleUniqueId ~= nil and item.vehicleUniqueId ~= "" then
        if value >= 0 then
            item.price = value
            item.amount = MathUtil.round(value * item.quantity)
            for _, swi in ipairs(self.selectedWorkItems) do
                if swi.vehicleUniqueId == item.vehicleUniqueId then
                    swi.customPrice = value
                    break
                end
            end
        end
        self:updateSelectedCellValues()
        self:updateTotal()
        return
    end

    -- Standard workType
    if value >= 0 then
        item.price = value
    end
    if item.unit == Invoice.UNIT_LITER then
        item.amount = MathUtil.round(item.price * item.quantity / 1000)
    else
        item.amount = MathUtil.round(item.price * item.quantity)
    end

    if item.sourceIndex ~= nil and self.selectedWorkItems[item.sourceIndex] ~= nil then
        self.selectedWorkItems[item.sourceIndex].customPrice = item.price
    end

    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
        if self.selectedWorkIndex ~= nil and self.selectedWorkIndex >= 1 and self.selectedWorkIndex <= #self.workTypes then
            self.listWorkTypes:setSelectedIndex(self.selectedWorkIndex)
        end
    end

    self:updateSelectedCellValues()
    self:updateTotal()
end

---Called when quantity input text changes, updates item quantity and recalculates amount
-- @param table element Input element
-- @param string text New text value
function InvoicesMainDashboard:onQtyTextChanged(element, text)
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then return end

    local item = self.displayItems[self.selectedItemIndex]
    if item == nil then return end
    if item.unit == Invoice.UNIT_HECTARE then return end

    -- Consumable grouped line: qty change rebuilds selection
    if item.isConsumable and item.groupKey ~= nil then
        local filtered = string.gsub(text or "", "[^0-9]", "")
        if filtered ~= text then
            element:setText(filtered)
            return
        end
        if filtered == "" then return end
        local newQty = tonumber(filtered) or 0
        if newQty < 0 then newQty = 0 end

        local maxStock = self:getConsumableStock(item.groupKey)
        if newQty > maxStock then
            newQty = maxStock
            element:setText(string.format("%.0f", newQty))
        end

        self:rebuildConsumableSelection(item.groupKey, newQty)
        return
    end

    -- Vehicle line: qty change rebuilds selection
    if item.vehicleUniqueId ~= nil and item.vehicleUniqueId ~= "" and item.configFileName ~= nil then
        local filtered = string.gsub(text or "", "[^0-9]", "")
        if filtered ~= text then
            element:setText(filtered)
            return
        end
        if filtered == "" then return end
        local newQty = tonumber(filtered) or 0
        if newQty < 0 then newQty = 0 end

        local maxStock = self:getVehicleStock(item.configFileName)
        if newQty > maxStock then
            newQty = maxStock
            element:setText(string.format("%.0f", newQty))
        end

        self:rebuildVehicleSelection(item.configFileName, newQty)
        return
    end

    local allowDecimal = (item.unit == Invoice.UNIT_HOUR)
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
    if item.unit == Invoice.UNIT_LITER then
        item.amount = MathUtil.round(item.price * item.quantity / 1000)
    else
        item.amount = MathUtil.round(item.price * item.quantity)
    end

    if item.sourceIndex ~= nil and self.selectedWorkItems[item.sourceIndex] ~= nil then
        self.selectedWorkItems[item.sourceIndex].customQuantity = item.quantity
    end

    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
        if self.selectedWorkIndex ~= nil and self.selectedWorkIndex >= 1 and self.selectedWorkIndex <= #self.workTypes then
            self.listWorkTypes:setSelectedIndex(self.selectedWorkIndex)
        end
    end

    self:updateSelectedCellValues()
    self:updateTotal()
end

---Returns available stock count for a consumable group
-- @param string groupKey Consumable group key
-- @return integer count Available stock
function InvoicesMainDashboard:getConsumableStock(groupKey)
    if g_currentMission == nil then return 0 end
    local playerFarmId = self.playerFarmId
    if playerFarmId == nil or playerFarmId < 1 then return 0 end
    InvoicesConsumablePipeline.invalidateCache()

    return InvoicesConsumablePipeline.getStockForGroup(groupKey, playerFarmId)
end

---Rebuilds consumable selection for a group to match target quantity
-- @param string groupKey Consumable group key
-- @param integer targetQty Desired quantity
function InvoicesMainDashboard:rebuildConsumableSelection(groupKey, targetQty)
    local workTypeTemplate = nil
    for i = #self.selectedWorkItems, 1, -1 do
        local item = self.selectedWorkItems[i]
        if item.isConsumable and item.groupKey == groupKey then
            if workTypeTemplate == nil then
                workTypeTemplate = {}
                for k, v in pairs(item) do workTypeTemplate[k] = v end
            end
            table.remove(self.selectedWorkItems, i)
        end
    end

    if workTypeTemplate == nil or targetQty <= 0 then
        self:rebuildLineItems()
        return
    end

    local available = InvoicesConsumablePipeline.getItemsForGroup(groupKey, self.playerFarmId, targetQty)
    local workTypeName = g_i18n:getText(workTypeTemplate.nameKey or "")

    for _, obj in ipairs(available) do
        local wt = {}
        for k, v in pairs(workTypeTemplate) do wt[k] = v end
        wt.vehicleUniqueId = obj.uniqueId
        wt.customPrice = obj.unitPrice
        wt.displayOverride = workTypeName .. " (" .. obj.displayName .. ")"
        wt.iconFilename = ""
        wt.consumableXmlFilename = obj.xmlFilename or ""
        wt.consumableFillTypeIndex = obj.fillTypeIndex or 0
        wt.consumableFillLevel = obj.fillLevel or 0
        table.insert(self.selectedWorkItems, wt)
    end

    self:rebuildLineItems()
end

---Returns count of owned vehicles matching given config file
-- @param string configFileName Vehicle config XML filename
-- @return integer count Number of matching owned vehicles
function InvoicesMainDashboard:getVehicleStock(configFileName)
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then return 0 end
    local playerFarmId = self.playerFarmId
    if playerFarmId == nil or playerFarmId < 1 then return 0 end

    local count = 0
    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle ~= nil and not vehicle.isPallet then
            local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
            local propertyState = vehicle.getPropertyState ~= nil and vehicle:getPropertyState() or vehicle.propertyState
            if ownerFarmId == playerFarmId and propertyState == VehiclePropertyState.OWNED and vehicle.configFileName == configFileName then
                count = count + 1
            end
        end
    end
    return count
end

---Rebuilds vehicle selection for a config file to match target quantity
-- @param string configFileName Vehicle config XML filename
-- @param integer targetQty Desired quantity
function InvoicesMainDashboard:rebuildVehicleSelection(configFileName, targetQty)
    -- Remove all existing selectedWorkItems for this configFileName (vehicles only)
    local workTypeTemplate = nil
    for i = #self.selectedWorkItems, 1, -1 do
        local item = self.selectedWorkItems[i]
        if not item.isConsumable and item.configFileName == configFileName and item.vehicleUniqueId ~= nil then
            if workTypeTemplate == nil then
                workTypeTemplate = {}
                for k, v in pairs(item) do workTypeTemplate[k] = v end
            end
            table.remove(self.selectedWorkItems, i)
        end
    end

    if workTypeTemplate == nil or targetQty <= 0 then
        self:rebuildLineItems()
        return
    end

    -- Scan real objects, sorted by sellPrice ascending
    local available = {}
    if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil then
        local playerFarmId = self.playerFarmId
        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            if vehicle ~= nil and not vehicle.isPallet and vehicle.configFileName == configFileName then
                local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
                local propertyState = vehicle.getPropertyState ~= nil and vehicle:getPropertyState() or vehicle.propertyState
                if ownerFarmId == playerFarmId and propertyState == VehiclePropertyState.OWNED then
                    local uniqueId = vehicle:getUniqueId()
                    if uniqueId ~= nil then
                        local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
                        local vehicleName = vehicle.getFullName ~= nil and vehicle:getFullName() or (storeItem and storeItem.name or "?")
                        local sellPrice = math.floor(vehicle:getSellPrice())
                        local iconFilename = storeItem and storeItem.imageFilename or ""
                        table.insert(available, {
                            uniqueId     = uniqueId,
                            name         = vehicleName,
                            sellPrice    = sellPrice,
                            iconFilename = iconFilename,
                        })
                    end
                end
            end
        end
    end

    table.sort(available, function(a, b) return a.sellPrice < b.sellPrice end)

    -- Take first N
    local actualQty = math.min(targetQty, #available)
    local workTypeName = g_i18n:getText(workTypeTemplate.nameKey or "")
    for i = 1, actualQty do
        local obj = available[i]
        local wt = {}
        for k, v in pairs(workTypeTemplate) do wt[k] = v end
        wt.vehicleUniqueId = obj.uniqueId
        wt.customPrice = obj.sellPrice
        wt.displayOverride = workTypeName .. " (" .. obj.name .. ")"
        wt.iconFilename = ""
        wt.configFileName = configFileName
        table.insert(self.selectedWorkItems, wt)
    end

    self:rebuildLineItems()
end

---Called when VAT rate input text changes, updates item VAT rate
-- @param table element Input element
-- @param string text New text value
function InvoicesMainDashboard:onVatRateTextChanged(element, text)
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then return end

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

    local item = self.displayItems[self.selectedItemIndex]
    if item == nil then return end
    item.vatRate = value / 100

    self:updateSelectedCellValues()
    self:updateTotal()
end

-- Data source: four SmoothList implementations

---Returns number of sections for the given list
-- @param table list SmoothList element
-- @return integer count Number of sections
function InvoicesMainDashboard:getNumberOfSections(list)
    if list == self.listFields then
        return 2
    end
    return 1
end

---Returns number of items in given section for the given list
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer count Number of items
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
        return #self.displayItems
    end
    return 0
end

---Returns localized title for given section header
-- @param table list SmoothList element
-- @param integer section Section index
-- @return string title Section header title or nil
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

---Returns height in pixels for given section header
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer height Header height
function InvoicesMainDashboard:getSectionHeaderHeight(list, section)
    if list == self.listFields then
        return 24
    end
    return 0
end

---Returns cell type identifier for section header
-- @param table list SmoothList element
-- @param integer section Section index
-- @return string cellType Cell type name or nil
function InvoicesMainDashboard:getCellTypeForSectionHeader(list, section)
    if list == self.listFields then
        return "section"
    end
    return nil
end

---Returns cell type identifier for item based on which list it belongs to
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
-- @return string cellType Cell type name or nil
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

---Routes cell population to the appropriate list-specific populate method
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
-- @param table cell Cell element to populate
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

---Populates a farm list cell with name and selection tick
-- @param integer index Farm index
-- @param table cell Cell element to populate
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

---Populates a work type list cell with name, price per unit and selection tick
-- @param integer index Work type index
-- @param table cell Cell element to populate
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
        local priceStr
        if workType.fillTypeDialog then
            local count = 0
            for _, item in ipairs(self.selectedWorkItems) do
                if item.nameKey == workType.nameKey then
                    count = count + 1
                end
            end
            priceStr = count > 0 and string.format("× %d", count) or "—"
        elseif workType.vehicleDialog then
            local count = 0
            for _, item in ipairs(self.selectedWorkItems) do
                if item.nameKey == workType.nameKey then
                    count = count + 1
                end
            end
            priceStr = count > 0 and string.format("× %d", count) or "—"
        elseif workType.consumableDialog then
            local count = 0
            for _, item in ipairs(self.selectedWorkItems) do
                if item.nameKey == workType.nameKey then
                    count = count + 1
                end
            end
            priceStr = count > 0 and string.format("× %d", count) or "—"
        else
            local manager = g_currentMission.invoicesManager
            local unitKey = manager and manager:getUnitKey(workType.unit) or "invoice_invoices_unit_piece"
            local unitStr = g_i18n:getText(unitKey)

            local selectedEntry = self:getSelectedWorkTypeEntry(workType)
            local price = (selectedEntry and selectedEntry.customPrice)
                or (manager and manager:getAdjustedPrice(workType.id))
                or workType.basePrice or 0

            if workType.unit == Invoice.UNIT_LITER then
                local isCustom = selectedEntry and selectedEntry.customPrice
                local displayPrice = isCustom and price or (price * 1000)
                priceStr = string.format("%s /1000 %s", g_i18n:formatMoney(displayPrice, 0), unitStr)
            else
                priceStr = string.format("%s /%s", g_i18n:formatMoney(price, 0), unitStr)
            end
        end
        cellPrice:setText(priceStr)
    end
end

---Finds the selected work item entry matching given work type
-- @param table workType Work type definition
-- @return table entry Selected work item or nil
function InvoicesMainDashboard:getSelectedWorkTypeEntry(workType)
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey then
            return item
        end
    end
    return nil
end

---Populates a field list cell with field ID, area and selection tick
-- @param integer section Section index (1=client, 2=other)
-- @param integer index Field index within section
-- @param table cell Cell element to populate
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
        cellArea:setText(string.format("%.2f %s", fieldData.area, g_i18n:getText("invoice_invoices_unit_hectare")))
    end
end

---Populates a recap line item cell with designation, icon, quantity, unit, price, VAT and amount
-- @param integer index Display item index
-- @param table cell Cell element to populate
function InvoicesMainDashboard:populateLineItemCell(index, cell)
    local item = self.displayItems[index]
    if item == nil then return end

    if index == self.selectedItemIndex then
        self._selectedCell = cell
    end

    local manager = g_currentMission.invoicesManager

    local resolvedIcon = Invoice.resolveLocalIcon(item)
    local cellIcon = cell:getDescendantByName("cellIcon")
    local hasIcon = resolvedIcon ~= ""
    if cellIcon ~= nil then
        cellIcon:setVisible(false)
    end

    local cellDesignation = cell:getDescendantByName("cellDesignation")
    if cellDesignation ~= nil then
        local name = item.name
        if name == nil or name == "" then
            local workType = manager and manager:getWorkTypeById(item.workTypeId) or nil
            name = workType and g_i18n:getText(workType.nameKey) or "?"
        end
        local baseName = name
        -- Consumable grouped row: strip sub-dialog suffix, show count
        if item.isConsumable and item.groupKey ~= nil then
            -- Use base name (without workType prefix from displayOverride)
            local parenStart = string.find(name, "%(")
            if parenStart ~= nil then
                local inner = string.sub(name, parenStart + 1, #name - 1)
                if inner ~= "" then
                    baseName = inner
                end
            end
            if item.quantity > 1 then
                name = baseName .. string.format(" (x%d)", item.quantity)
            else
                name = baseName
            end
        elseif hasIcon and cellIcon ~= nil then
            local parenStart = string.find(name, "%(")
            if parenStart ~= nil then
                local inner = string.sub(name, parenStart + 1, #name - 1)
                if inner ~= "" then
                    baseName = inner
                end
            end
        end
        if hasIcon and cellIcon ~= nil then
            local textSize = 13 * g_pixelSizeScaledY
            setTextBold(true)
            local spaceWidth = getTextWidth(textSize, " ")
            setTextBold(false)
            local iconPadding = 22 * g_pixelSizeScaledX
            local numSpaces = math.ceil(iconPadding / spaceWidth)
            cellIcon:setImageFilename(resolvedIcon)
            cellIcon:setVisible(true)
            name = string.rep(" ", numSpaces) .. baseName
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
        if item.unit == Invoice.UNIT_HECTARE or item.unit == Invoice.UNIT_HOUR then
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
            cellVat:setText(g_i18n:getText("invoice_label_na"))
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

---Called when any list selection changes, updates active context and edit fields
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
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

---Reloads item list data while preserving current selection index
function InvoicesMainDashboard:refreshItemListKeepSelection()
    if self.listItems == nil then return end
    local savedIndex = self.selectedItemIndex
    self.suppressEditFieldUpdate = true
    self.listItems:reloadData()
    if savedIndex >= 1 and savedIndex <= #self.displayItems then
        self.listItems:setSelectedIndex(savedIndex)
    end
    self.suppressEditFieldUpdate = false
end

-- ===================== SELECTION HELPERS =====================

---Checks if a work type is currently selected
-- @param table workType Work type definition to check
-- @return boolean selected True if work type is selected
function InvoicesMainDashboard:isWorkTypeSelected(workType)
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey then
            return true
        end
    end
    return false
end

---Checks if a field is currently selected
-- @param table fieldData Field data to check
-- @return boolean selected True if field is selected
function InvoicesMainDashboard:isFieldSelected(fieldData)
    for _, item in ipairs(self.selectedFieldItems) do
        if item.id == fieldData.id then
            return true
        end
    end
    return false
end

---Returns field data for current field list selection
-- @return table fieldData Selected field data or nil
function InvoicesMainDashboard:getSelectedFieldData()
    if self.selectedFieldSection == 1 then
        return self.clientFields[self.selectedFieldIndex]
    elseif self.selectedFieldSection == 2 then
        return self.otherFields[self.selectedFieldIndex]
    end
    return nil
end

-- ===================== BUTTON STATES =====================

---Enables or disables send button based on wizard state readiness
function InvoicesMainDashboard:updateButtonStates()
    if self.btnSend ~= nil then
        local state = InvoicesWizardState.getInstance()
        self.btnSend:setDisabled(not state:canCreateInvoice())
    end
end

-- ===================== LIST CLICK HANDLERS =====================

---Handles click on farm list item, toggles farm selection
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Farm index
function InvoicesMainDashboard:onFarmListClicked(list, section, index)
    if list ~= self.listFarms or index == nil or index < 1 or index > #self.farms then return end
    self.activeContext = InvoicesMainDashboard.CONTEXT_FARMS
    self.selectedFarmIndex = index
    local farm = self.farms[index]
    if self.selectedFarm ~= nil and self.selectedFarm.farmId == farm.farmId then
        self:removeFarm()
    else
        self:addFarm()
    end
end

---Handles click on work type list item, opens sub-dialog or toggles selection
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Work type index
function InvoicesMainDashboard:onWorkTypeListClicked(list, section, index)
    if list ~= self.listWorkTypes or index == nil or index < 1 or index > #self.workTypes then return end
    self.activeContext = InvoicesMainDashboard.CONTEXT_WORK_TYPES
    self.selectedWorkIndex = index
    local wt = self.workTypes[index]
    if wt.fillTypeDialog then
        self:openFillTypeDialog(wt)
    elseif wt.vehicleDialog then
        self:openVehicleDialog(wt)
    elseif wt.consumableDialog then
        self:openConsumableDialog(wt)
    elseif self:isWorkTypeSelected(wt) then
        self:removeWorkType()
    else
        self:addWorkType()
    end
end

---Handles click on field list item, toggles field selection
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Field index
function InvoicesMainDashboard:onFieldListClicked(list, section, index)
    if list ~= self.listFields or index == nil or index < 1 then return end
    self.activeContext = InvoicesMainDashboard.CONTEXT_FIELDS
    self.selectedFieldSection = section
    self.selectedFieldIndex = index
    local fieldData = self:getSelectedFieldData()
    if fieldData == nil then return end
    if self:isFieldSelected(fieldData) then
        self:removeField()
    else
        self:addField()
    end
end

-- Farm toggle
---Selects the currently highlighted farm as invoice recipient
function InvoicesMainDashboard:addFarm()
    if self.selectedFarmIndex < 1 or self.selectedFarmIndex > #self.farms then return end
    local farm = self.farms[self.selectedFarmIndex]
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
        local savedIdx = self.selectedFarmIndex
        self.listFarms:reloadData()
        self.listFarms:setSelectedIndex(savedIdx)
    end

    self:updateButtonStates()
    self:updateSequentialLock()
end

---Deselects the current recipient farm and clears all selections
function InvoicesMainDashboard:removeFarm()
    if self.selectedFarm == nil then return end
    local farm = self.farms[self.selectedFarmIndex]
    if farm == nil or self.selectedFarm.farmId ~= farm.farmId then return end

    local state = InvoicesWizardState.getInstance()
    self.selectedFarm = nil
    state:setRecipient(0, "")
    self.selectedWorkItems = {}
    self.selectedFieldItems = {}

    self:loadFields()
    self:updateFieldsPanel()
    self:updateHeader()
    self:rebuildLineItems()

    if self.listFarms ~= nil then
        local savedIdx = self.selectedFarmIndex
        self.listFarms:reloadData()
        self.listFarms:setSelectedIndex(savedIdx)
    end

    self:updateButtonStates()
    self:updateSequentialLock()
end

---Adds the currently highlighted work type to selection or opens its sub-dialog
function InvoicesMainDashboard:addWorkType()
    if self.selectedFarm == nil then return end
    if self.selectedWorkIndex < 1 or self.selectedWorkIndex > #self.workTypes then return end

    local workType = self.workTypes[self.selectedWorkIndex]

    if workType.fillTypeDialog then
        self:openFillTypeDialog(workType)
    elseif workType.vehicleDialog then
        self:openVehicleDialog(workType)
    elseif workType.consumableDialog then
        self:openConsumableDialog(workType)
    else
        if self:isWorkTypeSelected(workType) then return end
        local selectedWorkType = {}
        for k, v in pairs(workType) do
            selectedWorkType[k] = v
        end
        table.insert(self.selectedWorkItems, selectedWorkType)
        self:updateFieldsPanel()
        self:rebuildLineItems()
        if self.listWorkTypes ~= nil then
            self.listWorkTypes:reloadData()
            self.listWorkTypes:setSelectedIndex(self.selectedWorkIndex)
        end
    end
end

---Opens fill type selection sub-dialog for given work type
-- @param table workType Work type definition with fillTypeDialog flag
function InvoicesMainDashboard:openFillTypeDialog(workType)
    self._pendingSubdialog = true
    local savedWorkIndex = self.selectedWorkIndex

    -- Collect previously selected fill type names for this workType
    local previousNames = {}
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey and item.displayOverride ~= nil then
            local ftName = item.displayOverride:match("%((.+)%)$")
            if ftName then
                previousNames[ftName] = true
            end
        end
    end

    local dialog = g_gui:showDialog("InvoicesFillTypeDialog")
    if dialog ~= nil and dialog.target ~= nil then
        dialog.target:setInitialSelection(previousNames)
        dialog.target:setCallback(self, function(dashSelf, selectedItems)
            dashSelf._pendingSubdialog = false
            if selectedItems == nil then return end

            -- Remove all previous fillType entries for this workType
            for i = #dashSelf.selectedWorkItems, 1, -1 do
                if dashSelf.selectedWorkItems[i].nameKey == workType.nameKey and dashSelf.selectedWorkItems[i].displayOverride ~= nil then
                    table.remove(dashSelf.selectedWorkItems, i)
                end
            end

            -- Add new selections
            for _, fillType in ipairs(selectedItems) do
                local wt = {}
                for k, v in pairs(workType) do wt[k] = v end
                wt.customPrice = MathUtil.round(fillType.pricePerLiter * 1000)
                if fillType.isBulkType then
                    wt.unit = Invoice.UNIT_LITER
                else
                    wt.unit = Invoice.UNIT_PIECE
                end
                wt.displayOverride = g_i18n:getText(workType.nameKey) .. " (" .. fillType.name .. ")"
                wt.iconFilename = fillType.iconFilename
                table.insert(dashSelf.selectedWorkItems, wt)
            end

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

---Opens vehicle selection sub-dialog for given work type
-- @param table workType Work type definition with vehicleDialog flag
function InvoicesMainDashboard:openVehicleDialog(workType)
    self._pendingSubdialog = true
    local savedWorkIndex = self.selectedWorkIndex

    local previousIds = {}
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey and item.vehicleUniqueId ~= nil then
            previousIds[item.vehicleUniqueId] = true
        end
    end

    local dialog = g_gui:showDialog("InvoicesVehicleDialog")
    if dialog ~= nil and dialog.target ~= nil then
        dialog.target:setPlayerFarmId(self.playerFarmId)
        dialog.target:loadVehicles()
        dialog.target:setInitialSelection(previousIds)
        dialog.target:setCallback(self, function(dashSelf, selectedItems)
            dashSelf._pendingSubdialog = false
            if selectedItems == nil then return end

            for i = #dashSelf.selectedWorkItems, 1, -1 do
                if dashSelf.selectedWorkItems[i].nameKey == workType.nameKey and dashSelf.selectedWorkItems[i].vehicleUniqueId ~= nil then
                    table.remove(dashSelf.selectedWorkItems, i)
                end
            end

            local workTypeName = g_i18n:getText(workType.nameKey)
            for _, vehicle in ipairs(selectedItems) do
                local wt = {}
                for k, v in pairs(workType) do wt[k] = v end
                wt.vehicleUniqueId = vehicle.uniqueId
                wt.customPrice = vehicle.sellPrice
                wt.unit = Invoice.UNIT_PIECE
                wt.displayOverride = workTypeName .. " (" .. vehicle.name .. ")"
                wt.iconFilename = vehicle.iconFilename or ""
                wt.configFileName = vehicle.configFileName
                table.insert(dashSelf.selectedWorkItems, wt)
            end

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

---Opens consumable selection sub-dialog for given work type
-- @param table workType Work type definition with consumableDialog flag
function InvoicesMainDashboard:openConsumableDialog(workType)
    self._pendingSubdialog = true
    local savedWorkIndex = self.selectedWorkIndex

    local previousIds = {}
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey and item.vehicleUniqueId ~= nil then
            previousIds[item.vehicleUniqueId] = true
        end
    end

    local dialog = g_gui:showDialog("InvoicesConsumableDialog")
    if dialog ~= nil and dialog.target ~= nil then
        dialog.target:setPlayerFarmId(self.playerFarmId)
        dialog.target:loadConsumables()
        dialog.target:setInitialSelection(previousIds)
        dialog.target:setCallback(self, function(dashSelf, selectedItems)
            dashSelf._pendingSubdialog = false
            if selectedItems == nil then return end

            for i = #dashSelf.selectedWorkItems, 1, -1 do
                if dashSelf.selectedWorkItems[i].nameKey == workType.nameKey and dashSelf.selectedWorkItems[i].vehicleUniqueId ~= nil then
                    table.remove(dashSelf.selectedWorkItems, i)
                end
            end

            local workTypeName = g_i18n:getText(workType.nameKey)
            for _, consumable in ipairs(selectedItems) do
                local wt = {}
                for k, v in pairs(workType) do wt[k] = v end
                wt.vehicleUniqueId = consumable.uniqueId
                wt.customPrice = consumable.sellPrice
                wt.unit = Invoice.UNIT_PIECE
                wt.displayOverride = workTypeName .. " (" .. consumable.name .. ")"
                wt.iconFilename = ""
                wt.groupKey = consumable.groupKey
                wt.isConsumable = true
                wt.consumableXmlFilename = consumable.xmlFilename or ""
                wt.consumableFillTypeIndex = consumable.fillTypeIndex or 0
                wt.consumableFillLevel = consumable.fillLevel or 0
                table.insert(dashSelf.selectedWorkItems, wt)
            end

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

---Removes the currently highlighted work type from selection
function InvoicesMainDashboard:removeWorkType()
    if self.selectedWorkIndex < 1 or self.selectedWorkIndex > #self.workTypes then return end
    local workType = self.workTypes[self.selectedWorkIndex]
    if not self:isWorkTypeSelected(workType) then return end

    for i, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey then
            table.remove(self.selectedWorkItems, i)
            break
        end
    end
    self:updateFieldsPanel()
    self:rebuildLineItems()
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
        self.listWorkTypes:setSelectedIndex(self.selectedWorkIndex)
    end
end

---Adds the currently highlighted field to selection
function InvoicesMainDashboard:addField()
    local fieldData = self:getSelectedFieldData()
    if fieldData == nil then return end
    if self:isFieldSelected(fieldData) then return end

    table.insert(self.selectedFieldItems, fieldData)
    self:rebuildLineItems()

    if self.listFields ~= nil then
        self.listFields:reloadData()
        self.listFields:setSelectedItem(self.selectedFieldSection, self.selectedFieldIndex)
    end
end

---Removes the currently highlighted field from selection
function InvoicesMainDashboard:removeField()
    local fieldData = self:getSelectedFieldData()
    if fieldData == nil then return end
    if not self:isFieldSelected(fieldData) then return end

    for i, item in ipairs(self.selectedFieldItems) do
        if item.id == fieldData.id then
            table.remove(self.selectedFieldItems, i)
            break
        end
    end
    self:rebuildLineItems()
    if self.listFields ~= nil then
        self.listFields:reloadData()
        self.listFields:setSelectedItem(self.selectedFieldSection, self.selectedFieldIndex)
    end
end

-- ===================== SEND / CANCEL =====================

---Handles send button click, validates and shows confirmation dialog
function InvoicesMainDashboard:onClickSend()
    local state = InvoicesWizardState.getInstance()
    if not state:canCreateInvoice() then return end

    local manager = g_currentMission.invoicesManager
    local recipientFarm = g_farmManager:getFarmById(state.recipientFarmId)
    local farmName = recipientFarm and recipientFarm.name or "?"
    local total = state:getTotal()
    local confirmText = string.format(g_i18n:getText("invoice_confirm_send"), g_i18n:formatMoney(total, 0, true, false), farmName)

    YesNoDialog.show(self.onSendConfirmed, self, confirmText)
end

---Callback for send confirmation dialog, creates and dispatches invoice
-- @param boolean confirmed True if user confirmed sending
function InvoicesMainDashboard:onSendConfirmed(confirmed)
    if not confirmed then return end

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

---Cancels invoice creation, resets wizard state and closes dialog
function InvoicesMainDashboard:onClickCancel()
    local state = InvoicesWizardState.getInstance()
    state:reset()
    self:close()
end
