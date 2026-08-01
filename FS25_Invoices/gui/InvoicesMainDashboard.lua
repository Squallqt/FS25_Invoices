-- Copyright © 2026 Squallqt. All rights reserved.
---Dialog for creating and editing invoices
InvoicesMainDashboard = {}
local InvoicesMainDashboard_mt = Class(InvoicesMainDashboard, MessageDialog)

InvoicesMainDashboard.CONTROLS = {
    MAIN_TITLE_TEXT  = "mainTitleText",
    TITLE_SEP        = "titleSep",
    LIST_FARMS       = "listFarms",
    LIST_WORK_TYPES  = "listWorkTypes",
    LIST_FIELDS      = "listFields",
    WORK_SLIDER_BOX  = "workSliderBox",
    FIELD_SLIDER_BOX = "fieldSliderBox",
    WORK_TYPES_ZONE  = "workTypesZone",
    FIELDS_PANEL     = "fieldsPanel",
    FIELDS_EMPTY_TEXT = "fieldsEmptyText",
    LIST_ITEMS       = "listItems",
    ITEM_SLIDER_BOX  = "itemSliderBox",
    TEXT_FROM        = "textFrom",
    TEXT_TO          = "textTo",
    INPUT_NOTE       = "inputNote",
    INPUT_PRICE      = "inputPrice",
    INPUT_QTY        = "inputQty",
    INPUT_DISCOUNT   = "inputDiscount",
    INPUT_VAT        = "inputVat",
    TEXT_TOTAL       = "textTotal",
    TOTAL_RIGHT_COLUMN = "totalRightColumn",
    TEXT_VAT_HT      = "textVatHt",
    TEXT_DISCOUNT    = "textDiscount",
    TEXT_VAT         = "textVat",
    TOTAL_SEP        = "totalSep",
    BTN_SEND         = "btnSend",
    TEXT_COL_FARM    = "textColFarm",
    BTN_REMOVE       = "btnRemove",
    BTN_RENAME       = "btnRename",
    BTN_CANCEL       = "btnCancel",
}

InvoicesMainDashboard.CONTEXT_FARMS = 1
InvoicesMainDashboard.CONTEXT_WORK_TYPES = 2
InvoicesMainDashboard.CONTEXT_FIELDS = 3
InvoicesMainDashboard.CONTEXT_ITEMS = 4

---Creates new invoices main dashboard instance
-- @param table target Parent target element
-- @param table? customMt Optional custom metatable
-- @return InvoicesMainDashboard New dashboard instance
function InvoicesMainDashboard.new(target, customMt)
    local self = MessageDialog.new(target, customMt or InvoicesMainDashboard_mt)

    self.farms = {}
    self.workTypes = {}
    self.clientFields = {}
    self.otherFields = {}

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

    self.activeContext = nil
    self.isSoloMode = false
    self.playerFarmId = nil
    self.suppressEditFieldUpdate = false

    return self
end

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

---Called when dialog opens, initializes all panels from the current wizard state
function InvoicesMainDashboard:onOpen()
    InvoicesMainDashboard:superClass().onOpen(self)

    if self._pendingSubdialog then
        self._pendingSubdialog = false
        return
    end

    self:resizeTitleSep()

    local state = InvoicesWizardState.getInstance()
    self.isProposalMode = state:isProposalMode()

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
    self:restoreDraftState(state)

    if self.listFarms ~= nil then
        self.listFarms:reloadData()
        if self.selectedFarmIndex >= 1 and self.selectedFarmIndex <= #self.farms then
            self.listFarms:setSelectedIndex(self.selectedFarmIndex)
        elseif #self.farms > 0 then
            self.listFarms:setSelectedIndex(1)
        end
    end
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
        if #self.workTypes > 0 then
            self.listWorkTypes:setSelectedIndex(1)
        end
    end
    if self.listFields ~= nil then
        self.listFields:reloadData()
        if #self.clientFields > 0 then
            self.listFields:setSelectedItem(1, 1)
        elseif #self.otherFields > 0 then
            self.listFields:setSelectedItem(2, 1)
        end
    end
    if self.listItems ~= nil then
        self.listItems:reloadData()
        if #self.displayItems > 0 then
            self.listItems:setSelectedIndex(1)
        end
    end

    self:updateRecapSliderVisibility()
    if self.selectedFarm == nil then
        self:handleAutoFarmSelection()
    end
    self:updateFieldsPanel()
    self:updateHeader()
    self:updateModeUI()
    self:rebuildLineItems()
    self:updateTotal()
    self:updateButtonStates()
    self:updateSequentialLock()

    if self.listFarms ~= nil then
        FocusManager:setFocus(self.listFarms)
    end
end

---Called when dialog closes, preserving any unfinished invoice draft
function InvoicesMainDashboard:onClose()
    InvoicesMainDashboard:superClass().onClose(self)
    self._pendingSubdialog = false
end

---Restores persisted wizard selections into the dashboard UI state
-- @param table state Wizard state singleton
function InvoicesMainDashboard:restoreDraftState(state)
    if state == nil then return end

    self.selectedWorkItems = state.selectedWorkTypes or {}
    self.selectedFieldItems = state.selectedFields or {}
    self.lineItems = state.lineItems or {}

    local recipientFarmId = state.recipientFarmId
    if recipientFarmId == nil or recipientFarmId == 0 then
        return
    end

    for i, farm in ipairs(self.farms) do
        if farm.farmId == recipientFarmId then
            self.selectedFarm = farm
            self.selectedFarmIndex = i
            return
        end
    end
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

---Resizes title separator to match title text width
function InvoicesMainDashboard:resizeTitleSep()
    InvoicesGuiUtils.resizeTitleSeparator(self.mainTitleText, self.titleSep)
end

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

    -- Sort only the local UI copy to preserve source IDs; proposal mode forbids ownership transfers.
    for i = 1, #source do
        local wt = source[i]
        table.insert(self.workTypes, wt)
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

---Measures current field ground inside a farmland parcel
-- @param integer farmlandId Farmland identifier
-- @param table farmland Farmland data
-- @return number Current field area in hectares
function InvoicesMainDashboard:measureFarmlandFieldAreaHa(farmlandId, farmland)
    local mission = g_currentMission
    local boundingBox = farmland ~= nil and farmland.boundingBox or nil
    if mission == nil or mission.fieldGroundSystem == nil or type(boundingBox) ~= "table" then return 0 end

    local mapId, firstChannel, numChannels = mission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
    local farmlandMap = g_farmlandManager:getLocalMap()
    local mapSize = mapId ~= nil and getDensityMapSize(mapId) or 0
    if mapId == nil or farmlandMap == nil or mapSize == nil or mapSize <= 0 then return 0 end

    local modifier = DensityMapModifier.new(mapId, firstChannel, numChannels, g_terrainNode)
    modifier:setParallelogramWorldCoords(
        boundingBox.minX, boundingBox.minZ,
        boundingBox.maxX, boundingBox.minZ,
        boundingBox.minX, boundingBox.maxZ,
        DensityCoordType.POINT_POINT_POINT)

    local fieldFilter = DensityMapFilter.new(mapId, firstChannel, numChannels)
    fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

    local farmlandFilter = DensityMapFilter.new(farmlandMap, 0, g_farmlandManager.numberOfBits)
    farmlandFilter:setValueCompareParams(DensityValueCompareType.EQUAL, farmlandId)

    local _, pixels = modifier:executeGet(fieldFilter, farmlandFilter)
    local pixelSize = mission.terrainSize / mapSize
    return MathUtil.areaToHa(pixels, pixelSize * pixelSize)
end

---Loads farmland fields split into client-owned and other categories
function InvoicesMainDashboard:loadFields()
    self.clientFields = {}
    self.otherFields = {}

    local state = InvoicesWizardState.getInstance()
    -- "Client fields" belong to the payer: the selected farm in create mode, but the player in proposal mode.
    local clientFarmId = state.recipientFarmId
    if state:isProposalMode() then
        clientFarmId = self.playerFarmId
    end

    if clientFarmId == nil then return end
    if g_farmlandManager == nil or g_farmlandManager.farmlands == nil then return end

    for farmlandId, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.field ~= nil then
            local ownerFarmId = farmland.farmId
            local area = self:measureFarmlandFieldAreaHa(farmlandId, farmland)
            local fieldData = { id = farmlandId, area = area }

            if ownerFarmId == clientFarmId then
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
    if self.selectedFarm ~= nil then return end

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

---Checks if any selected work type requires field-based hectare billing
-- @return boolean True when field selection is required
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

    if self.fieldsPanel ~= nil then
        self.fieldsPanel:setDisabled(not needsFields)
    end
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
        -- Suppress so reloadData cannot overwrite selectedItemIndex via onListSelectionChanged
        self.suppressEditFieldUpdate = true
        self.listItems:reloadData()
        self.suppressEditFieldUpdate = false
    end

    self:updateRecapSliderVisibility()

    if #self.displayItems > 0 then
        if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then
            -- Default to first row when the saved index becomes invalid (e.g. after row removal)
            self.selectedItemIndex = 1
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
                    discountRate   = item.discountRate,
                    -- Base unit price (before discount) so the P.U. column is not discounted.
                    price          = item.price or 0,
                    consumableFillTypeIndex = item.consumableFillTypeIndex,
                    consumableXmlFilename  = item.consumableXmlFilename,
                    consumableFillLevel    = item.consumableFillLevel,
                    quantity       = 0,
                    totalAmount    = 0,
                }
                table.insert(consumableOrder, gk)
            end
            local group = consumableGroups[gk]
            group.quantity = group.quantity + 1
            group.totalAmount = group.totalAmount + (item.amount or 0)
        else
            table.insert(self.displayItems, item)
        end
    end

    for _, gk in ipairs(consumableOrder) do
        local group = consumableGroups[gk]
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

---Updates the dialog title and send-button label for the current mode
function InvoicesMainDashboard:updateModeUI()
    if self.mainTitleText ~= nil then
        local titleKey = self.isProposalMode and "invoice_wizard_propose_title" or "invoice_wizard_mainTitle"
        self.mainTitleText:setText(g_i18n:getText(titleKey))
    end
    if self.btnSend ~= nil then
        local sendKey = self.isProposalMode and "invoice_btn_sendRequest" or "invoice_btn_sendInvoice"
        self.btnSend:setText(g_i18n:getText(sendKey))
    end
    -- In proposal mode the first column lists farms to select as the issuer, not the client.
    if self.textColFarm ~= nil then
        local colKey = self.isProposalMode
            and "invoice_wizard_step1_label_proposal"
            or  "invoice_wizard_step1_label"
        self.textColFarm:setText(g_i18n:getText(colKey))
    end
    self:resizeTitleSep()
end

---Updates sender and recipient farm name display
function InvoicesMainDashboard:updateHeader()
    -- From is the issuer and To is the payer; proposal mode reverses the selected and player farms.
    local playerFarmId = 0
    if g_currentMission.getFarmId ~= nil then
        playerFarmId = g_currentMission:getFarmId()
    else
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm then playerFarmId = farm.farmId end
    end
    local playerFarm = g_farmManager:getFarmById(playerFarmId)
    local playerName = playerFarm and playerFarm.name or "?"
    local selectedName = self.selectedFarm ~= nil and self.selectedFarm.name or "—"

    local fromName, toName
    if self.isProposalMode then
        fromName = selectedName
        toName = playerName
    else
        fromName = playerName
        toName = selectedName
    end

    if self.textFrom ~= nil then
        self.textFrom:setText(string.format(g_i18n:getText("invoice_step4_from"), fromName))
    end
    if self.textTo ~= nil then
        self.textTo:setText(string.format(g_i18n:getText("invoice_step4_to"), toName))
    end
end

---Computes and displays subtotal HT, discount, VAT and total amounts
function InvoicesMainDashboard:updateTotal()
    local state = InvoicesWizardState.getInstance()
    local total, netHT, totalVAT = Invoice.computeTotals(state.lineItems)
    local totalText = g_i18n:formatMoney(total, 0, true, false)

    -- The discount line is the actual reduction between the original and discounted totals.
    local discountAmount = Invoice.computeTotalDiscountAmount(state.lineItems)

    if self.textTotal ~= nil then
        self.textTotal:setText(totalText)
    end

    if self.textVatHt ~= nil and self.textVat ~= nil then
        local vatEnabled = g_currentMission.invoicesManager ~= nil and g_currentMission.invoicesManager.service:isVatEnabled()
        local showRealVat = vatEnabled and totalVAT > 0

        local htValue = showRealVat and g_i18n:formatMoney(netHT, 0, true, false) or g_i18n:getText("invoice_label_na")
        local vatValue = showRealVat and g_i18n:formatMoney(totalVAT, 0, true, false) or g_i18n:getText("invoice_label_na")
        local htText = string.format("%s :  %s", g_i18n:getText("invoice_label_subtotal_ht"), htValue)
        local vatText = string.format("%s :  %s", g_i18n:getText("invoice_label_vat"), vatValue)
        self.textVatHt:setText(htText)
        self.textVat:setText(vatText)
        self.textVatHt:setVisible(true)
        self.textVat:setVisible(true)

        InvoicesGuiUtils.layoutTotalBreakdown(
            self.totalRightColumn,
            self.textVatHt,
            self.textVat,
            self.textDiscount,
            discountAmount
        )

        if self.totalSep ~= nil then
            self.totalSep:setVisible(true)
            self:resizeTotalSep(htText, vatText, totalText)
        end
    end

    self:updateButtonStates()
end

---Resizes total separator to fit VAT and total amount text
-- @param string htText Formatted HT amount text
-- @param string vatText Formatted VAT amount text
-- @param string totalText Formatted total amount text
function InvoicesMainDashboard:resizeTotalSep(htText, vatText, totalText)
    self._sepOrigX, self._sepOrigW = InvoicesGuiUtils.resizeTotalSeparator(
        self.totalSep,
        self.textVatHt,
        self.textVat,
        self.textTotal,
        htText,
        vatText,
        totalText,
        self._sepOrigX,
        self._sepOrigW
    )
end

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

---Hooks input capture on price, quantity, discount, VAT, and note fields to track active input
function InvoicesMainDashboard:hookInputCapture()
    self._activeInput = nil
    local inputs = {self.inputPrice, self.inputQty, self.inputDiscount, self.inputVat, self.inputNote}
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
-- @return boolean True when the input was consumed
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
    if self.inputDiscount ~= nil then
        self.inputDiscount:setText("")
        self.inputDiscount:setDisabled(true)
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

    if self.inputDiscount ~= nil then
        if item ~= nil then
            -- Empty field when there is no discount (no default "0").
            local discountPct = (item.discountRate or 0) * 100
            if discountPct > 0 then
                self.inputDiscount:setText(string.format("%.0f", discountPct))
            else
                self.inputDiscount:setText("")
            end
            self.inputDiscount:setDisabled(false)
        else
            self.inputDiscount:setText("")
            self.inputDiscount:setDisabled(true)
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

    local cellDiscount = cell:getDescendantByName("cellDiscount")
    if cellDiscount ~= nil then
        local discountRate = item.discountRate or 0
        if discountRate > 0 then
            cellDiscount:setText(string.format("%.0f%%", discountRate * 100))
        else
            cellDiscount:setText("—")
        end
    end
end

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

    if item.isConsumable and item.groupKey ~= nil then
        if value >= 0 then
            item.price = value
            item.amount = Invoice.computeLineAmount(value, item.quantity, item.unit, item.discountRate)
            for _, swi in ipairs(self.selectedWorkItems) do
                if swi.isConsumable and swi.groupKey == item.groupKey then
                    swi.customPrice = value
                end
            end
            self:rebuildLineItems()
        end
        return
    end

    if item.vehicleUniqueId ~= nil and item.vehicleUniqueId ~= "" then
        if value >= 0 then
            item.price = value
            item.amount = Invoice.computeLineAmount(value, item.quantity, item.unit, item.discountRate)
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

    if filtered == "" then
        -- Empty field: clear the override so rebuild falls back to the default price.
        if item.sourceIndex ~= nil and self.selectedWorkItems[item.sourceIndex] ~= nil then
            self.selectedWorkItems[item.sourceIndex].customPrice = nil
        end
        self:updateSelectedCellValues()
        self:updateTotal()
        return
    end
    if value >= 0 then
        item.price = value
    end
    item.amount = Invoice.computeLineAmount(item.price, item.quantity, item.unit, item.discountRate)

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

    if filtered == "" then
        -- Empty field: clear the override so rebuild falls back to the default quantity.
        if item.sourceIndex ~= nil and self.selectedWorkItems[item.sourceIndex] ~= nil then
            self.selectedWorkItems[item.sourceIndex].customQuantity = nil
        end
        self:updateSelectedCellValues()
        self:updateTotal()
        return
    end

    local value = tonumber(filtered or "") or 0

    if value >= 0 then
        item.quantity = value
    end
    item.amount = Invoice.computeLineAmount(item.price, item.quantity, item.unit, item.discountRate)

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

---Returns the seller farm ID: player farm in create mode, selected farm in proposal mode
function InvoicesMainDashboard:getSellerFarmId()
    if self.isProposalMode and self.selectedFarm ~= nil then
        return self.selectedFarm.farmId
    end
    return self.playerFarmId
end

---Returns available stock count for a consumable group
-- @param string groupKey Consumable group key
-- @return integer Available stock
function InvoicesMainDashboard:getConsumableStock(groupKey)
    if g_currentMission == nil then return 0 end
    local sellerFarmId = self:getSellerFarmId()
    if sellerFarmId == nil or sellerFarmId < 1 then return 0 end
    InvoicesConsumablePipeline.invalidateCache()

    return InvoicesConsumablePipeline.getStockForGroup(groupKey, sellerFarmId)
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

    local available = InvoicesConsumablePipeline.getItemsForGroup(groupKey, self:getSellerFarmId(), targetQty)
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
-- @return integer Number of matching owned vehicles
function InvoicesMainDashboard:getVehicleStock(configFileName)
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then return 0 end
    local sellerFarmId = self:getSellerFarmId()
    if sellerFarmId == nil or sellerFarmId < 1 then return 0 end

    local count = 0
    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle ~= nil and not vehicle.isPallet then
            local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
            local propertyState = vehicle.getPropertyState ~= nil and vehicle:getPropertyState() or vehicle.propertyState
            if ownerFarmId == sellerFarmId and propertyState == VehiclePropertyState.OWNED and vehicle.configFileName == configFileName then
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

    if item.sourceIndex ~= nil and self.selectedWorkItems[item.sourceIndex] ~= nil then
        self.selectedWorkItems[item.sourceIndex].customVatRate = item.vatRate
    end

    self:updateSelectedCellValues()
    self:updateTotal()
end

---Called when discount input text changes, updates item discount and recalculates amount
-- @param table element Input element
-- @param string text New text value
function InvoicesMainDashboard:onDiscountRateTextChanged(element, text)
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then return end

    -- Discount percentage is an integer (no decimals).
    local filtered = string.gsub(text or "", "[^0-9]", "")
    if filtered ~= text then
        element:setText(filtered)
        return
    end

    local value = tonumber(filtered or "") or 0
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    local rate = value / 100

    local item = self.displayItems[self.selectedItemIndex]
    if item == nil then return end
    item.discountRate = rate
    item.amount = Invoice.computeLineAmount(item.price, item.quantity, item.unit, rate)

    if item.isConsumable and item.groupKey ~= nil then
        for _, swi in ipairs(self.selectedWorkItems) do
            if swi.isConsumable and swi.groupKey == item.groupKey then
                swi.customDiscountRate = rate
            end
        end
        self:rebuildLineItems()
        return
    end

    if item.vehicleUniqueId ~= nil and item.vehicleUniqueId ~= "" then
        for _, swi in ipairs(self.selectedWorkItems) do
            if swi.vehicleUniqueId == item.vehicleUniqueId then
                swi.customDiscountRate = rate
                break
            end
        end
        self:updateSelectedCellValues()
        self:updateTotal()
        return
    end

    if item.sourceIndex ~= nil and self.selectedWorkItems[item.sourceIndex] ~= nil then
        self.selectedWorkItems[item.sourceIndex].customDiscountRate = rate
    end

    self:updateSelectedCellValues()
    self:updateTotal()
end

---Returns number of sections for the given list
-- @param table list SmoothList element
-- @return integer Number of sections
function InvoicesMainDashboard:getNumberOfSections(list)
    if list == self.listFields then
        return 2
    end
    return 1
end

---Returns number of items in given section for the given list
-- @param table list SmoothList element
-- @param integer section Section index
-- @return integer Number of items
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
-- @return string|nil Section header title or nil
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

---Returns cell type identifier for item based on which list it belongs to
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
-- @return string|nil Cell type name or nil
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

---Populates a farm list cell with name
-- @param integer index Farm index
-- @param table cell Cell element to populate
function InvoicesMainDashboard:populateFarmCell(index, cell)
    local farm = self.farms[index]
    if farm == nil then return end

    local isSelected = self.selectedFarm ~= nil and self.selectedFarm.farmId == farm.farmId

    local cellDot = cell:getDescendantByName("cellDot")
    if cellDot ~= nil then cellDot:setText(isSelected and "" or "·") end

    local cellPrefix = cell:getDescendantByName("cellPrefix")
    if cellPrefix ~= nil then cellPrefix:setText("") end

    local cellCheck = cell:getDescendantByName("cellCheck")
    if cellCheck ~= nil then
        cellCheck:setVisible(isSelected)
    end

    local cellName = cell:getDescendantByName("cellName")
    if cellName ~= nil then cellName:setText(farm.name) end
end

---Populates a work type list cell with name and price per unit
-- @param integer index Work type index
-- @param table cell Cell element to populate
function InvoicesMainDashboard:populateWorkTypeCell(index, cell)
    local workType = self.workTypes[index]
    if workType == nil then return end

    local locked = (self.selectedFarm == nil)
    cell:setDisabled(locked)

    local count = 0
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey then
            count = count + 1
        end
    end

    local cellDot = cell:getDescendantByName("cellDot")
    if cellDot ~= nil then
        cellDot:setDisabled(locked)
        cellDot:setText(count > 0 and "" or "·")
    end

    local cellPrefix = cell:getDescendantByName("cellPrefix")
    if cellPrefix ~= nil then
        cellPrefix:setDisabled(locked)
        cellPrefix:setText(count > 1 and string.format("x%d", count) or "")
    end

    local cellCheck = cell:getDescendantByName("cellCheck")
    if cellCheck ~= nil then
        cellCheck:setVisible(count == 1 and not locked)
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
        if workType.fillTypeDialog or workType.vehicleDialog or workType.consumableDialog then
            priceStr = "—"
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
-- @return table|nil Selected work item or nil
function InvoicesMainDashboard:getSelectedWorkTypeEntry(workType)
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey then
            return item
        end
    end
    return nil
end

---Populates a field list cell with field ID and area
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

    local isSelected = self:isFieldSelected(fieldData)

    local cellDot = cell:getDescendantByName("cellDot")
    if cellDot ~= nil then cellDot:setText(isSelected and "" or "·") end

    local cellPrefix = cell:getDescendantByName("cellPrefix")
    if cellPrefix ~= nil then cellPrefix:setText("") end

    local cellCheck = cell:getDescendantByName("cellCheck")
    if cellCheck ~= nil then
        cellCheck:setVisible(isSelected)
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
    local cellVat = cell:getDescendantByName("cellVat")
    local lineValues = InvoicesGuiUtils.formatLineItemValues(item, {
        unitField = "unit",
        vatEnabled = cellVat == nil or (manager ~= nil and manager.service:isVatEnabled())
    })

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
        if item.isConsumable and item.groupKey ~= nil then
            baseName = InvoicesGuiUtils.getParenthesizedDisplayName(name)
            if item.quantity > 1 then
                name = baseName .. string.format(" (x%d)", item.quantity)
            else
                name = baseName
            end
        elseif hasIcon and cellIcon ~= nil then
            baseName = InvoicesGuiUtils.getParenthesizedDisplayName(name)
        end
        if hasIcon and cellIcon ~= nil then
            cellIcon:setImageFilename(resolvedIcon)
            cellIcon:setVisible(true)
            name = InvoicesGuiUtils.getIconPaddedText(baseName, 13 * g_pixelSizeScaledY, true)
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
        cellQty:setText(lineValues.qty)
    end

    local cellUnit = cell:getDescendantByName("cellUnit")
    if cellUnit ~= nil then
        cellUnit:setText(lineValues.unit)
    end

    local cellPrice = cell:getDescendantByName("cellPrice")
    if cellPrice ~= nil then
        cellPrice:setText(lineValues.unitPrice)
    end

    if cellVat ~= nil then
        cellVat:setText(lineValues.vat)
    end

    local cellDiscount = cell:getDescendantByName("cellDiscount")
    if cellDiscount ~= nil then
        cellDiscount:setText(lineValues.discount)
    end

    local cellAmount = cell:getDescendantByName("cellAmount")
    if cellAmount ~= nil then
        cellAmount:setText(lineValues.amount)
    end
end

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
        if not self.suppressEditFieldUpdate then
            self.selectedItemIndex = index
            -- Reload so _selectedCell is updated for the new selection before edit fields read it
            self.suppressEditFieldUpdate = true
            self.listItems:reloadData()
            self.suppressEditFieldUpdate = false
            self:updateEditFields()
        end
    end

    self:updateButtonStates()
end

---Checks if a field is currently selected
-- @param table fieldData Field data to check
-- @return boolean True when the field is selected
function InvoicesMainDashboard:isFieldSelected(fieldData)
    for _, item in ipairs(self.selectedFieldItems) do
        if item.id == fieldData.id then
            return true
        end
    end
    return false
end

---Checks whether a field is still covered by at least one selected hectare work type
-- @param integer fieldId Field identifier
-- @return boolean True when a remaining hectare work type applies to the field
function InvoicesMainDashboard:isFieldUsedBySelectedWorkTypes(fieldId)
    if fieldId == nil then
        return false
    end

    for _, workType in ipairs(self.selectedWorkItems) do
        if workType.unit == Invoice.UNIT_HECTARE then
            local isExcluded = false

            if workType.excludedFields ~= nil then
                for _, excludedFieldId in ipairs(workType.excludedFields) do
                    if excludedFieldId == fieldId then
                        isExcluded = true
                        break
                    end
                end
            end

            if not isExcluded then
                return true
            end
        end
    end

    return false
end

---Removes a field from the global field selection and clears stale exclusions for that field
-- @param integer fieldId Field identifier
function InvoicesMainDashboard:removeSelectedFieldById(fieldId)
    if fieldId == nil then
        return
    end

    for i, item in ipairs(self.selectedFieldItems) do
        if item.id == fieldId then
            table.remove(self.selectedFieldItems, i)
            break
        end
    end

    for _, workType in ipairs(self.selectedWorkItems) do
        if workType.excludedFields ~= nil then
            for j = #workType.excludedFields, 1, -1 do
                if workType.excludedFields[j] == fieldId then
                    table.remove(workType.excludedFields, j)
                end
            end
        end
    end
end

---Returns field data for current field list selection
-- @return table|nil Selected field data or nil
function InvoicesMainDashboard:getSelectedFieldData()
    if self.selectedFieldSection == 1 then
        return self.clientFields[self.selectedFieldIndex]
    elseif self.selectedFieldSection == 2 then
        return self.otherFields[self.selectedFieldIndex]
    end
    return nil
end

---Updates disabled state of all bottom-bar buttons based on context and wizard state
function InvoicesMainDashboard:updateButtonStates()
    local state = InvoicesWizardState.getInstance()
    local context = self.activeContext

    if self.btnSend ~= nil then
        self.btnSend:setDisabled(not state:canCreateInvoice())
    end

    if self.btnRemove ~= nil then
        local canRemove = false
        if context == InvoicesMainDashboard.CONTEXT_FARMS then
            canRemove = self.selectedFarm ~= nil
        elseif context == InvoicesMainDashboard.CONTEXT_WORK_TYPES then
            if self.selectedWorkIndex >= 1 and self.selectedWorkIndex <= #self.workTypes then
                local nameKey = self.workTypes[self.selectedWorkIndex].nameKey
                for _, item in ipairs(self.selectedWorkItems) do
                    if item.nameKey == nameKey then
                        canRemove = true
                        break
                    end
                end
            end
        elseif context == InvoicesMainDashboard.CONTEXT_FIELDS then
            local fieldData = self:getSelectedFieldData()
            canRemove = fieldData ~= nil and self:isFieldSelected(fieldData)
        elseif context == InvoicesMainDashboard.CONTEXT_ITEMS then
            canRemove = self.selectedItemIndex >= 1 and self.selectedItemIndex <= #self.displayItems
        end
        self.btnRemove:setDisabled(not canRemove)
    end

    if self.btnRename ~= nil then
        local canRename = false
        if context == InvoicesMainDashboard.CONTEXT_ITEMS
           and self.selectedItemIndex >= 1 and self.selectedItemIndex <= #self.displayItems then
            local di = self.displayItems[self.selectedItemIndex]
            if di ~= nil and not di.isConsumable then
                local srcIndex = di.sourceIndex
                if srcIndex ~= nil and self.selectedWorkItems[srcIndex] ~= nil then
                    local swi = self.selectedWorkItems[srcIndex]
                    local hasOverride = swi.displayOverride ~= nil and swi.displayOverride ~= ""
                    local hasVehicle = swi.vehicleUniqueId ~= nil and swi.vehicleUniqueId ~= ""
                    local isConsum = swi.isConsumable == true
                    canRename = not (hasOverride or hasVehicle or isConsum)
                end
            end
        end
        self.btnRename:setDisabled(not canRename)
    end
end

---Routes the REMOVE action to the appropriate handler based on active context
function InvoicesMainDashboard:onClickRemove()
    if self.activeContext == InvoicesMainDashboard.CONTEXT_FARMS then
        self:removeFarm()
    elseif self.activeContext == InvoicesMainDashboard.CONTEXT_WORK_TYPES then
        self:removeWorkType()
    elseif self.activeContext == InvoicesMainDashboard.CONTEXT_FIELDS then
        self:removeField()
    elseif self.activeContext == InvoicesMainDashboard.CONTEXT_ITEMS then
        self:removeSelectedLineItem()
    end
end

---Opens a native TextInputDialog to edit the customLabel of the currently selected recap line
function InvoicesMainDashboard:onClickRename()
    if self.activeContext ~= InvoicesMainDashboard.CONTEXT_ITEMS then return end
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then return end

    local di = self.displayItems[self.selectedItemIndex]
    if di == nil then return end
    if di.isConsumable then return end

    local srcIndex = di.sourceIndex
    if srcIndex == nil or self.selectedWorkItems[srcIndex] == nil then return end

    local swi = self.selectedWorkItems[srcIndex]
    -- Disabled if entry came from sub-dialog (vehicle/consumable/fillType already enrich the label)
    if swi.displayOverride ~= nil and swi.displayOverride ~= "" then return end
    if swi.vehicleUniqueId ~= nil and swi.vehicleUniqueId ~= "" then return end
    if swi.isConsumable then return end

    local fieldId = di.fieldId
    local defaultText
    if fieldId ~= nil and swi.customLabelByField ~= nil and swi.customLabelByField[fieldId] ~= nil then
        defaultText = swi.customLabelByField[fieldId]
    else
        defaultText = swi.customLabel or ""
    end
    if defaultText == "" then
        defaultText = g_i18n:getText(swi.nameKey) or ""
    end

    self._pendingRenameIndex = srcIndex
    self._pendingRenameFieldId = fieldId
    self._pendingSubdialog = true
    TextInputDialog.show(
        self.onRenameEntered,
        self,
        defaultText,
        g_i18n:getText("invoice_dialog_rename_prompt"),
        nil,
        60,
        g_i18n:getText("button_ok")
    )
end

---Handles the TextInputDialog result for the rename action
-- @param string text Entered label text
-- @param boolean confirmed True if user confirmed
function InvoicesMainDashboard:onRenameEntered(text, confirmed)
    self._pendingSubdialog = false
    local srcIndex = self._pendingRenameIndex
    local fieldId = self._pendingRenameFieldId
    self._pendingRenameIndex = nil
    self._pendingRenameFieldId = nil
    if not confirmed then return end
    if srcIndex == nil or self.selectedWorkItems[srcIndex] == nil then return end
    local trimmed = string.gsub(text or "", "^%s*(.-)%s*$", "%1")
    local swi = self.selectedWorkItems[srcIndex]
    if fieldId ~= nil then
        -- Hectare: each (workType, field) row gets its own label, leaving sibling rows untouched
        swi.customLabelByField = swi.customLabelByField or {}
        swi.customLabelByField[fieldId] = trimmed
    else
        swi.customLabel = trimmed
    end
    self:rebuildLineItems()
end

---Handles click on farm list item, selecting the clicked recipient directly
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Farm index
function InvoicesMainDashboard:onFarmListClicked(list, section, index)
    if list ~= self.listFarms or index == nil or index < 1 or index > #self.farms then return end
    self.activeContext = InvoicesMainDashboard.CONTEXT_FARMS
    self.selectedFarmIndex = index
    local farm = self.farms[index]
    if self.selectedFarm == nil or self.selectedFarm.farmId ~= farm.farmId then
        self:addFarm()
    else
        self:updateButtonStates()
    end
end

---Handles click on work type list item, adding one occurrence or opening its sub-dialog
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Work type index
function InvoicesMainDashboard:onWorkTypeListClicked(list, section, index)
    if list ~= self.listWorkTypes or index == nil or index < 1 or index > #self.workTypes then return end
    self.activeContext = InvoicesMainDashboard.CONTEXT_WORK_TYPES
    self.selectedWorkIndex = index
    if self.selectedFarm == nil then
        self:updateButtonStates()
        return
    end
    self:addWorkType()
end

---Handles click on field list item, adding the clicked field when not already selected
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Field index
function InvoicesMainDashboard:onFieldListClicked(list, section, index)
    if list ~= self.listFields or index == nil or index < 1 then return end
    self.activeContext = InvoicesMainDashboard.CONTEXT_FIELDS
    self.selectedFieldSection = section
    self.selectedFieldIndex = index
    local fieldData = self:getSelectedFieldData()
    if fieldData ~= nil and not self:isFieldSelected(fieldData) then
        self:addField()
    else
        self:updateButtonStates()
    end
end

---Handles click on recap line item — fires even when the same row is clicked again
-- @param table list SmoothList element
-- @param integer section Section index
-- @param integer index Item index
function InvoicesMainDashboard:onItemListClicked(list, section, index)
    if list ~= self.listItems or index == nil or index < 1 or index > #self.displayItems then return end
    self.activeContext = InvoicesMainDashboard.CONTEXT_ITEMS
    self.selectedItemIndex = index
    self:updateButtonStates()
end

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

---Adds a new instance of the currently highlighted work type to selection or opens its sub-dialog
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
        local selectedWorkType = {}
        for k, v in pairs(workType) do
            selectedWorkType[k] = v
        end
        selectedWorkType.customLabel = ""
        -- Per-field exclusions allow removing a single (workType, field) line from the recap
        if workType.unit == Invoice.UNIT_HECTARE then
            selectedWorkType.excludedFields = {}
            selectedWorkType.customLabelByField = {}
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

---Copies a work type for dialog selection
-- @param table workType Work type definition
-- @return table Work type copy
function InvoicesMainDashboard:copyDialogWorkType(workType)
    local wt = {}
    for k, v in pairs(workType) do wt[k] = v end
    wt.customLabel = ""
    return wt
end

---Collects existing selection keys for a dialog work type
-- @param table workType Work type definition
-- @param string existingKey Existing item key name
-- @param function? getSelectionKey Selection key resolver
-- @return table Existing selection keys
function InvoicesMainDashboard:collectDialogSelectionKeys(workType, existingKey, getSelectionKey)
    local previousSelection = {}
    for _, item in ipairs(self.selectedWorkItems) do
        if item.nameKey == workType.nameKey and item[existingKey] ~= nil then
            local selectionKey = item[existingKey]
            if getSelectionKey ~= nil then
                selectionKey = getSelectionKey(self, item)
            end
            if selectionKey ~= nil then
                previousSelection[selectionKey] = true
            end
        end
    end
    return previousSelection
end

---Opens and configures a work item selection dialog
-- @param table workType Work type definition
-- @param table options Dialog configuration
function InvoicesMainDashboard:openWorkItemSelectionDialog(workType, options)
    self._pendingSubdialog = true
    local savedWorkIndex = self.selectedWorkIndex
    local previousSelection = self:collectDialogSelectionKeys(workType, options.existingKey, options.getSelectionKey)

    local dialog = g_gui:showDialog(options.dialogName)
    if dialog ~= nil and dialog.target ~= nil then
        if options.loadDialogItems ~= nil then
            dialog.target:setPlayerFarmId(self:getSellerFarmId())
            dialog.target[options.loadDialogItems](dialog.target)
        end
        dialog.target:setInitialSelection(previousSelection)
        dialog.target:setCallback(self, function(dashSelf, selectedItems)
            dashSelf._pendingSubdialog = false
            if selectedItems == nil then return end

            local existing = {}
            for _, item in ipairs(dashSelf.selectedWorkItems) do
                if item.nameKey == workType.nameKey and item[options.existingKey] ~= nil then
                    local key = options.getSelectionKey ~= nil and options.getSelectionKey(dashSelf, item) or item[options.existingKey]
                    existing[key] = item
                end
            end

            for i = #dashSelf.selectedWorkItems, 1, -1 do
                local item = dashSelf.selectedWorkItems[i]
                if item.nameKey == workType.nameKey and item[options.existingKey] ~= nil then
                    table.remove(dashSelf.selectedWorkItems, i)
                end
            end

            for _, selectedItem in ipairs(selectedItems) do
                local entry = options.createWorkItem(dashSelf, workType, selectedItem)
                local key = options.getSelectionKey ~= nil and options.getSelectionKey(dashSelf, entry) or entry[options.existingKey]
                -- Reuse the already-present entry so its edits (price, discount, VAT, quantity) survive.
                table.insert(dashSelf.selectedWorkItems, existing[key] or entry)
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

---Creates a work item from a selected fill type
-- @param table workType Work type definition
-- @param table fillType Selected fill type
-- @return table Work item
function InvoicesMainDashboard:createFillTypeDialogWorkItem(workType, fillType)
    local wt = self:copyDialogWorkType(workType)
    wt.customPrice = MathUtil.round(fillType.pricePerLiter * 1000)
    -- Price-table goods are volumetric unless packaged; isBulkType keeps conflicting modded goods billed in litres.
    if not fillType.isBulkType and (fillType.isPalletType or fillType.isBaleType) then
        wt.unit = Invoice.UNIT_PIECE
    else
        wt.unit = Invoice.UNIT_LITER
    end
    wt.displayOverride = g_i18n:getText(workType.nameKey) .. " (" .. fillType.name .. ")"
    wt.iconFilename = fillType.iconFilename
    return wt
end

---Creates a work item from a selected vehicle
-- @param table workType Work type definition
-- @param table vehicle Selected vehicle
-- @return table Work item
function InvoicesMainDashboard:createVehicleDialogWorkItem(workType, vehicle)
    local wt = self:copyDialogWorkType(workType)
    wt.vehicleUniqueId = vehicle.uniqueId
    wt.customPrice = vehicle.sellPrice
    wt.unit = Invoice.UNIT_PIECE
    wt.displayOverride = g_i18n:getText(workType.nameKey) .. " (" .. vehicle.name .. ")"
    wt.iconFilename = vehicle.iconFilename or ""
    wt.configFileName = vehicle.configFileName
    return wt
end

---Creates a work item from a selected consumable
-- @param table workType Work type definition
-- @param table consumable Selected consumable
-- @return table Work item
function InvoicesMainDashboard:createConsumableDialogWorkItem(workType, consumable)
    local wt = self:copyDialogWorkType(workType)
    wt.vehicleUniqueId = consumable.uniqueId
    wt.customPrice = consumable.sellPrice
    wt.unit = Invoice.UNIT_PIECE
    wt.displayOverride = g_i18n:getText(workType.nameKey) .. " (" .. consumable.name .. ")"
    wt.iconFilename = ""
    wt.groupKey = consumable.groupKey
    wt.isConsumable = true
    wt.consumableXmlFilename = consumable.xmlFilename or ""
    wt.consumableFillTypeIndex = consumable.fillTypeIndex or 0
    wt.consumableFillLevel = consumable.fillLevel or 0
    return wt
end

---Opens fill type selection sub-dialog for given work type
-- @param table workType Work type definition with fillTypeDialog flag
function InvoicesMainDashboard:openFillTypeDialog(workType)
    self:openWorkItemSelectionDialog(workType, {
        dialogName = "InvoicesFillTypeDialog",
        existingKey = "displayOverride",
        getSelectionKey = function(_, item) return item.displayOverride:match("%((.+)%)$") end,
        createWorkItem = InvoicesMainDashboard.createFillTypeDialogWorkItem
    })
end

---Opens vehicle selection sub-dialog for given work type
-- @param table workType Work type definition with vehicleDialog flag
function InvoicesMainDashboard:openVehicleDialog(workType)
    self:openWorkItemSelectionDialog(workType, {
        dialogName = "InvoicesVehicleDialog",
        existingKey = "vehicleUniqueId",
        loadDialogItems = "loadVehicles",
        createWorkItem = InvoicesMainDashboard.createVehicleDialogWorkItem
    })
end

---Opens consumable selection sub-dialog for given work type
-- @param table workType Work type definition with consumableDialog flag
function InvoicesMainDashboard:openConsumableDialog(workType)
    self:openWorkItemSelectionDialog(workType, {
        dialogName = "InvoicesConsumableDialog",
        existingKey = "vehicleUniqueId",
        loadDialogItems = "loadConsumables",
        createWorkItem = InvoicesMainDashboard.createConsumableDialogWorkItem
    })
end

---Removes the last instance of the currently highlighted work type from selection (LIFO)
function InvoicesMainDashboard:removeWorkType()
    if self.selectedWorkIndex < 1 or self.selectedWorkIndex > #self.workTypes then return end
    local workType = self.workTypes[self.selectedWorkIndex]

    for i = #self.selectedWorkItems, 1, -1 do
        if self.selectedWorkItems[i].nameKey == workType.nameKey then
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

---Removes the line item currently selected in the recap list (precise instance via sourceIndex)
function InvoicesMainDashboard:removeSelectedLineItem()
    if self.selectedItemIndex < 1 or self.selectedItemIndex > #self.displayItems then return end
    local displayItem = self.displayItems[self.selectedItemIndex]
    if displayItem == nil then return end

    if displayItem.isConsumable and displayItem.groupKey ~= nil then
        local gk = displayItem.groupKey
        for i = #self.selectedWorkItems, 1, -1 do
            local swi = self.selectedWorkItems[i]
            if swi.isConsumable and swi.groupKey == gk then
                table.remove(self.selectedWorkItems, i)
            end
        end
    else
        local srcIndex = displayItem.sourceIndex
        if srcIndex == nil or self.selectedWorkItems[srcIndex] == nil then return end
        local swi = self.selectedWorkItems[srcIndex]

        -- Hectare row: exclude only this field for this workType; the workType keeps its other fields
        if swi.unit == Invoice.UNIT_HECTARE and displayItem.fieldId ~= nil then
            swi.excludedFields = swi.excludedFields or {}

            local alreadyExcluded = false
            for _, exId in ipairs(swi.excludedFields) do
                if exId == displayItem.fieldId then
                    alreadyExcluded = true
                    break
                end
            end
            if not alreadyExcluded then
                table.insert(swi.excludedFields, displayItem.fieldId)
            end

            -- Drop the whole workType when every selected field has been excluded
            local remaining = 0
            for _, field in ipairs(self.selectedFieldItems) do
                local fieldIsExcluded = false
                for _, exId in ipairs(swi.excludedFields) do
                    if exId == field.id then
                        fieldIsExcluded = true
                        break
                    end
                end
                if not fieldIsExcluded then
                    remaining = remaining + 1
                end
            end
            if remaining == 0 then
                table.remove(self.selectedWorkItems, srcIndex)
            end
        else
            table.remove(self.selectedWorkItems, srcIndex)
        end
    end

    if displayItem.fieldId ~= nil and not self:isFieldUsedBySelectedWorkTypes(displayItem.fieldId) then
        self:removeSelectedFieldById(displayItem.fieldId)
    end

    self:updateFieldsPanel()
    self:rebuildLineItems()
    if self.listWorkTypes ~= nil then
        self.listWorkTypes:reloadData()
        if self.selectedWorkIndex >= 1 and self.selectedWorkIndex <= #self.workTypes then
            self.listWorkTypes:setSelectedIndex(self.selectedWorkIndex)
        end
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

    self:removeSelectedFieldById(fieldData.id)

    self:rebuildLineItems()
    if self.listFields ~= nil then
        self.listFields:reloadData()
        self.listFields:setSelectedItem(self.selectedFieldSection, self.selectedFieldIndex)
    end
end

---Handles send button click, validates and shows confirmation dialog
function InvoicesMainDashboard:onClickSend()
    local state = InvoicesWizardState.getInstance()
    if not state:canCreateInvoice() then return end

    local manager = g_currentMission.invoicesManager
    local recipientFarm = g_farmManager:getFarmById(state.recipientFarmId)
    local farmName = recipientFarm and recipientFarm.name or "?"
    local total = Invoice.computeTotals(state.lineItems)
    local confirmKey = state:isProposalMode() and "invoice_confirm_propose" or "invoice_confirm_send"
    local confirmText = string.format(g_i18n:getText(confirmKey), g_i18n:formatMoney(total, 0, true, false), farmName)

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

    -- Capture mode before createInvoice (which resets the wizard back to create mode).
    local wasProposal = state:isProposalMode()
    local invoice = state:createInvoice()

    if invoice then
        self:close()
        local okKey = wasProposal and "invoice_propose_sent" or "invoice_wizard_invoice_created"
        InfoDialog.show(g_i18n:getText(okKey))
    else
        InfoDialog.show(g_i18n:getText("invoice_wizard_invoice_failed"))
    end
end

---Closes invoice creation without resetting the current draft
function InvoicesMainDashboard:onClickCancel()
    self:close()
end
