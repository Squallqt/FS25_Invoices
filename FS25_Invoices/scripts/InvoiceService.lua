-- Copyright © 2026 Squallqt. All rights reserved.
-- Business logic: pricing, VAT rates, server-authoritative money transfers, penalty accrual, reminders, and notifications.
InvoiceService = {}
local InvoiceService_mt = Class(InvoiceService)

-- Base prices aligned with FS25 game contract rewardPerHa values, adjusted at runtime by economicDifficulty.
-- Verified in-game (Hard difficulty, multiplier 1.0).
-- Hourly rates based on AI worker cost references.
InvoiceService.WORK_TYPES = {
    {id = 1,  nameKey = "invoice_work_stoneCollection",     basePrice = 2200, unit = Invoice.UNIT_HECTARE},
    {id = 2,  nameKey = "invoice_work_plowing",             basePrice = 2800, unit = Invoice.UNIT_HECTARE},
    {id = 3,  nameKey = "invoice_work_cultivating",         basePrice = 2300, unit = Invoice.UNIT_HECTARE},
    {id = 4,  nameKey = "invoice_work_mulching",            basePrice = 2000, unit = Invoice.UNIT_HECTARE},
    {id = 5,  nameKey = "invoice_work_rolling",             basePrice = 1200, unit = Invoice.UNIT_HECTARE},
    {id = 6,  nameKey = "invoice_work_harrowing",           basePrice = 1800, unit = Invoice.UNIT_HECTARE},
    {id = 7,  nameKey = "invoice_work_seeding",             basePrice = 2000, unit = Invoice.UNIT_HECTARE},
    {id = 8,  nameKey = "invoice_work_seedingPotato",       basePrice = 2800, unit = Invoice.UNIT_HECTARE},
    {id = 9,  nameKey = "invoice_work_seedingSugarcane",    basePrice = 2800, unit = Invoice.UNIT_HECTARE},
    {id = 10, nameKey = "invoice_work_seedingRice",         basePrice = 2200, unit = Invoice.UNIT_HECTARE},
    {id = 11, nameKey = "invoice_work_seedingRoot",         basePrice = 2400, unit = Invoice.UNIT_HECTARE},
    {id = 12, nameKey = "invoice_work_pruning",             basePrice = 2500, unit = Invoice.UNIT_HECTARE},
    {id = 13, nameKey = "invoice_work_spraying",            basePrice = 1500, unit = Invoice.UNIT_HECTARE},
    {id = 14, nameKey = "invoice_work_organicFertilizer",   basePrice = 1800, unit = Invoice.UNIT_HECTARE},
    {id = 15, nameKey = "invoice_work_mineralFertilizer",   basePrice = 1500, unit = Invoice.UNIT_HECTARE},
    {id = 16, nameKey = "invoice_work_mechanicalWeeding",   basePrice = 1500, unit = Invoice.UNIT_HECTARE},
    {id = 17, nameKey = "invoice_work_harvestGrain",        basePrice = 2500, unit = Invoice.UNIT_HECTARE},
    {id = 18, nameKey = "invoice_work_harvestPotato",       basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 19, nameKey = "invoice_work_harvestSugarbeet",    basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 20, nameKey = "invoice_work_harvestSugarcane",    basePrice = 4500, unit = Invoice.UNIT_HECTARE},
    {id = 21, nameKey = "invoice_work_harvestCotton",       basePrice = 3200, unit = Invoice.UNIT_HECTARE},
    {id = 22, nameKey = "invoice_work_harvestGrape",        basePrice = 3000, unit = Invoice.UNIT_HECTARE},
    {id = 23, nameKey = "invoice_work_harvestOlive",        basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 24, nameKey = "invoice_work_harvestRice",         basePrice = 3600, unit = Invoice.UNIT_HECTARE},
    {id = 25, nameKey = "invoice_work_harvestSpinach",      basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 26, nameKey = "invoice_work_harvestPeas",         basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 27, nameKey = "invoice_work_harvestGreenBeans",   basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 28, nameKey = "invoice_work_harvestVegetables",   basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 29, nameKey = "invoice_work_harvestOnion",        basePrice = 3400, unit = Invoice.UNIT_HECTARE},
    {id = 30, nameKey = "invoice_work_chaffing",            basePrice = 2800, unit = Invoice.UNIT_HECTARE},
    {id = 31, nameKey = "invoice_work_mowing",              basePrice = 2500, unit = Invoice.UNIT_HECTARE},
    {id = 32, nameKey = "invoice_work_tedding",             basePrice = 1200, unit = Invoice.UNIT_HECTARE},
    {id = 33, nameKey = "invoice_work_windrowing",          basePrice = 1300, unit = Invoice.UNIT_HECTARE},
    {id = 34, nameKey = "invoice_work_baling",              basePrice = 200,  unit = Invoice.UNIT_PIECE},
    {id = 35, nameKey = "invoice_work_wrapping",            basePrice = 200,  unit = Invoice.UNIT_PIECE},
    {id = 36, nameKey = "invoice_work_buyBales",            basePrice = 100,  unit = Invoice.UNIT_PIECE},
    {id = 37, nameKey = "invoice_work_consumableSale",      basePrice = 0,    unit = Invoice.UNIT_PIECE, consumableDialog = true},
    {id = 38, nameKey = "invoice_work_animalFeeding",       basePrice = 1200, unit = Invoice.UNIT_HOUR},
    {id = 39, nameKey = "invoice_work_barnCleaning",        basePrice = 1200, unit = Invoice.UNIT_HOUR},
    {id = 40, nameKey = "invoice_work_animalTransport",     basePrice = 2200, unit = Invoice.UNIT_HOUR},
    {id = 41, nameKey = "invoice_work_snowRemoval",         basePrice = 1800, unit = Invoice.UNIT_HOUR},
    {id = 42, nameKey = "invoice_work_generalLabor",        basePrice = 1500, unit = Invoice.UNIT_HOUR},
    {id = 43, nameKey = "invoice_work_loaderWork",          basePrice = 2000, unit = Invoice.UNIT_HOUR},
    {id = 44, nameKey = "invoice_work_driving",             basePrice = 1200, unit = Invoice.UNIT_HOUR},
    {id = 45, nameKey = "invoice_work_siloWork",            basePrice = 1500, unit = Invoice.UNIT_HOUR},
    {id = 46, nameKey = "invoice_work_delivery",            basePrice = 1800, unit = Invoice.UNIT_HOUR},
    {id = 47, nameKey = "invoice_work_transport",           basePrice = 1600, unit = Invoice.UNIT_HOUR},
    {id = 48, nameKey = "invoice_work_equipmentRental",     basePrice = 800,  unit = Invoice.UNIT_HOUR},
    {id = 49, nameKey = "invoice_work_heapLoading",         basePrice = 1800, unit = Invoice.UNIT_HOUR},
    {id = 50, nameKey = "invoice_work_treePlanting",        basePrice = 300,  unit = Invoice.UNIT_PIECE},
    {id = 51, nameKey = "invoice_work_treeCutting",         basePrice = 300,  unit = Invoice.UNIT_PIECE},
    {id = 52, nameKey = "invoice_work_treeRemoval",         basePrice = 300,  unit = Invoice.UNIT_PIECE},
    {id = 53, nameKey = "invoice_work_goods",               basePrice = 0.5,  unit = Invoice.UNIT_LITER},
    {id = 54, nameKey = "invoice_work_miscellaneous",       basePrice = 100,  unit = Invoice.UNIT_PIECE},
    {id = 55, nameKey = "invoice_work_products",            basePrice = 0,    unit = Invoice.UNIT_LITER, fillTypeDialog = true},
    {id = 56, nameKey = "invoice_work_vehicleSale",         basePrice = 0,    unit = Invoice.UNIT_PIECE, vehicleDialog = true},
}

InvoiceService.REMINDER_INTERVAL = 300000
InvoiceService.REMINDER_FIRST_DELAY = 60000
InvoiceService.PENALTY_CHECK_INTERVAL = 10000

---Creates new invoice service instance
-- @param table repository Invoice repository instance
-- @return InvoiceService instance
function InvoiceService.new(repository)
    local self = setmetatable({}, InvoiceService_mt)

    self.repository = repository

    self.reminderTimer = 0
    self.reminderActive = false
    self.reminderFarmId = nil
    self.firstReminderSent = false
    self.initialCheckDone = false
    self.lastNotifiedFarmId = nil

    self.vatGroups = {}
    self.workTypeGroups = {}

    self.penaltyTimer = 0
    self.lastPenaltyDay = -1

    return self
end

---Loads VAT rates from XML configuration
-- @param string xmlPath Path to VAT rates XML file
function InvoiceService:loadVatRates(xmlPath)
    local xmlFile = loadXMLFile("vatRates", xmlPath)
    if xmlFile == nil or xmlFile == 0 then
        Logging.warning("[InvoiceService] Failed to load vatRates.xml from %s", xmlPath)
        return
    end

    self.vatGroups = {}
    self.workTypeGroups = {}

    local groupCount = 0
    while true do
        local key = string.format("vatRates.groups.group(%d)", groupCount)
        if not hasXMLProperty(xmlFile, key) then break end
        local name = getXMLString(xmlFile, key .. "#name")
        local rate = getXMLFloat(xmlFile, key .. "#defaultRate")
        if name ~= nil and rate ~= nil then
            self.vatGroups[name] = rate
        end
        groupCount = groupCount + 1
    end

    local wtCount = 0
    while true do
        local key = string.format("vatRates.workTypes.workType(%d)", wtCount)
        if not hasXMLProperty(xmlFile, key) then break end
        local id = getXMLInt(xmlFile, key .. "#id")
        local group = getXMLString(xmlFile, key .. "#group")
        if id ~= nil and group ~= nil then
            self.workTypeGroups[id] = group
        end
        wtCount = wtCount + 1
    end

    delete(xmlFile)
    Logging.info("[InvoiceService] VAT rates loaded: %d groups, %d work type mappings", groupCount, wtCount)
end

---Returns whether VAT simulation is enabled
-- @return boolean isEnabled
function InvoiceService:isVatEnabled()
    if g_currentMission == nil or g_currentMission.invoiceSettings == nil then
        return true
    end
    return g_currentMission.invoiceSettings.invoiceVatSimulated ~= false
end

-- Grace period: 1 month (period). Cap: 25% of invoice amount.
InvoiceService.PENALTY_GRACE_PERIODS = 1
InvoiceService.PENALTY_CAP_PERCENT = 25

---Returns whether penalty system is enabled
-- @return boolean isEnabled
function InvoiceService:isPenaltyEnabled()
    if g_currentMission == nil or g_currentMission.invoiceSettings == nil then
        return false
    end
    return g_currentMission.invoiceSettings.invoicePenalties ~= false
end

---Returns monthly penalty rate in percent
-- @return integer rate Penalty rate
function InvoiceService:getPenaltyRate()
    return 5
end

---Returns planned days per period from environment
-- @return integer daysPerPeriod
function InvoiceService:getDaysPerPeriod()
    if g_currentMission ~= nil and g_currentMission.environment ~= nil then
        return g_currentMission.environment.plannedDaysPerPeriod or 1
    end
    return 1
end

---Processes penalty accrual on unpaid invoices (server only)
function InvoiceService:processPenalties()
    if g_server == nil then return end
    if not self:isPenaltyEnabled() then return end

    local env = g_currentMission.environment
    if env == nil then return end

    local currentDay = env.currentDay or 0
    if currentDay <= 0 then return end

    if currentDay == self.lastPenaltyDay then return end
    self.lastPenaltyDay = currentDay

    local daysPerPeriod = math.max(1, self:getDaysPerPeriod())

    -- Only process on the last day of a period
    if daysPerPeriod > 1 then
        local dayInPeriod = 0
        if env.getDayInPeriodFromDay then
            dayInPeriod = env:getDayInPeriodFromDay(currentDay)
        end
        if dayInPeriod ~= daysPerPeriod then return end
    end

    local monthlyRate = self:getPenaltyRate() / 100
    local maxRate = InvoiceService.PENALTY_CAP_PERCENT / 100
    local gracePeriods = InvoiceService.PENALTY_GRACE_PERIODS

    local allInvoices = self.repository:getAll()
    local changed = false
    local penaltyUpdates = {}

    for _, invoice in ipairs(allInvoices) do
        if invoice.state ~= Invoice.STATE.PAID and invoice.state ~= Invoice.STATE.CANCELLED then
            local createdDay = invoice.createdDay or 0
            local elapsedDays = currentDay - createdDay
            if createdDay >= 0 and elapsedDays > 0 then
                local elapsedMonths = math.floor(elapsedDays / daysPerPeriod)
                local penaltyMonths = elapsedMonths - gracePeriods
                if penaltyMonths > 0 then
                    local rawRate = monthlyRate * penaltyMonths
                    local cappedRate = math.min(rawRate, maxRate)
                    local newPenalty = math.floor(cappedRate * invoice.totalAmount + 0.5)
                    if newPenalty ~= invoice.penaltyAmount then
                        local oldPenalty = invoice.penaltyAmount or 0
                        invoice.penaltyAmount = newPenalty
                        changed = true
                        table.insert(penaltyUpdates, {id = invoice.id, penaltyAmount = newPenalty})
                        if oldPenalty == 0 and newPenalty > 0 then
                            local ok, err = pcall(self.notifyOverdue, self, invoice)
                            if not ok then
                                Logging.warning("[InvoiceService] notifyOverdue error: %s", tostring(err))
                            end
                        end
                    end
                end
            end
        end
    end

    if changed then
        self:notifyUI()
        if g_server ~= nil and #penaltyUpdates > 0 then
            g_server:broadcastEvent(InvoicePenaltySyncEvent.new(penaltyUpdates))
        end
    end
end

---Applies penalty sync updates received from server
-- @param table updates Array of penalty update records
function InvoiceService:applyPenaltySync(updates)
    for _, upd in ipairs(updates) do
        local invoice = self.repository:getById(upd.id)
        if invoice ~= nil then
            local oldPenalty = invoice.penaltyAmount or 0
            invoice.penaltyAmount = upd.penaltyAmount
            if oldPenalty == 0 and upd.penaltyAmount > 0 then
                self:notifyOverdue(invoice)
            end
        end
    end
    self:notifyUI()
end

---Shows overdue notification to recipient farm player
-- @param table invoice Invoice with overdue penalty
function InvoiceService:notifyOverdue(invoice)
    if invoice == nil then return end
    if g_localPlayer == nil then return end
    if g_localPlayer.farmId ~= invoice.recipientFarmId then return end

    local senderFarm = g_farmManager:getFarmById(invoice.senderFarmId)
    local senderName = senderFarm and senderFarm.name or "?"
    local penaltyAmount = invoice.penaltyAmount or 0
    local totalDue = (invoice.totalAmount or 0) + penaltyAmount
    local amountStr = g_i18n:formatMoney(totalDue)
    local text = string.format(g_i18n:getText("invoice_notification_overdue"), senderName, amountStr)

    if penaltyAmount > 0 then
        local penStr = g_i18n:formatMoney(penaltyAmount, 0, true, false)
        local penDetail = string.format(g_i18n:getText("invoice_notification_penalty_incl"), penStr)
        text = text .. " (" .. penDetail .. ")"
    end

    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)
end

---Returns VAT rate for a work type
-- @param integer workTypeId Work type identifier
-- @return float rate VAT rate or 0
function InvoiceService:getVatRateForWorkType(workTypeId)
    local group = self.workTypeGroups[workTypeId]
    if group == nil then return 0 end
    return self.vatGroups[group] or 0
end

---Returns all available work types
-- @return table workTypes Array of work type definitions
function InvoiceService:getWorkTypes()
    return InvoiceService.WORK_TYPES
end

---Returns work type definition by identifier
-- @param integer id Work type identifier
-- @return table|nil workType Work type definition or nil
function InvoiceService:getWorkTypeById(id)
    for _, workType in ipairs(InvoiceService.WORK_TYPES) do
        if workType.id == id then
            return workType
        end
    end
    return nil
end

---Returns i18n key for a unit type
-- @param integer unitType Unit type constant
-- @return string key Localization key
function InvoiceService:getUnitKey(unitType)
    if unitType == Invoice.UNIT_PIECE then
        return "invoice_invoices_unit_piece"
    elseif unitType == Invoice.UNIT_HOUR then
        return "invoice_invoices_unit_hour"
    elseif unitType == Invoice.UNIT_HECTARE then
        return "invoice_invoices_unit_hectare"
    elseif unitType == Invoice.UNIT_LITER then
        return "invoice_invoices_unit_liter"
    end
    return "invoice_invoices_unit_piece"
end

-- Matches FS25 AbstractFieldMission:getReward() formula
---Returns economic difficulty multiplier
-- @return float multiplier Difficulty-adjusted price multiplier
function InvoiceService:getDifficultyMultiplier()
    local difficulty = 2
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        difficulty = g_currentMission.missionInfo.economicDifficulty or 2
    end
    return 1.3 - 0.1 * difficulty
end

---Returns difficulty-adjusted price for a work type
-- @param integer workTypeId Work type identifier
-- @return float price Adjusted price
function InvoiceService:getAdjustedPrice(workTypeId)
    local workType = self:getWorkTypeById(workTypeId)
    if workType == nil then
        return 0
    end
    return MathUtil.round(workType.basePrice * self:getDifficultyMultiplier(), 2)
end

---Creates invoice, assigns ID, and broadcasts event
-- @param table invoice Invoice to create
-- @param boolean noEventSend If true skip network broadcast
function InvoiceService:createAndSendInvoice(invoice, noEventSend)
    if invoice.id == 0 then
        invoice.id = self.repository:generateId()
    else
        if invoice.id >= self.repository:getNextInvoiceId() then
            self.repository:setNextInvoiceId(invoice.id + 1)
        end
    end
    self.repository:add(invoice)
    self:notifyNewInvoice(invoice)
    self:notifyUI()
    
    if not (noEventSend == true) then
        if g_server ~= nil then
            g_server:broadcastEvent(InvoiceCreateEvent.new(invoice))
        else
            g_client:getServerConnection():sendEvent(InvoiceCreateEvent.new(invoice))
        end
    end
end

---Pays invoice, transfers money, and broadcasts event
-- @param integer invoiceId Invoice identifier
-- @param boolean noEventSend If true skip network broadcast
function InvoiceService:payInvoice(invoiceId, noEventSend)
    if g_server == nil and not (noEventSend == true) then
        g_client:getServerConnection():sendEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_PAY))
        return
    end

    if not self:executePayment(invoiceId, true) then
        return
    end

    if not (noEventSend == true) then
        g_server:broadcastEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_PAY))
    end
end

---Deletes invoice and broadcasts event
-- @param integer invoiceId Invoice identifier
-- @param boolean noEventSend If true skip network broadcast
function InvoiceService:deleteInvoice(invoiceId, noEventSend)
    if g_server == nil and not (noEventSend == true) then
        g_client:getServerConnection():sendEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_DELETE))
        return
    end
    self:executeDelete(invoiceId)
    if not (noEventSend == true) then
        g_server:broadcastEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_DELETE))
    end
end

-- Server-authoritative create (called by network events)
---Applies incoming invoice on server side
-- @param table invoice Invoice to add
function InvoiceService:applyCreateAuthoritative(invoice)
    self.repository:add(invoice)
    self:notifyNewInvoice(invoice)
    self:notifyUI()
end

---Executes payment with money transfer (server-authoritative)
-- @param integer invoiceId Invoice identifier
-- @param boolean isAuthoritative If true performs money transfer
-- @return boolean success True if payment succeeded
function InvoiceService:executePayment(invoiceId, isAuthoritative)
    local invoice = self.repository:getById(invoiceId)
    if invoice == nil then
        Logging.warning("[InvoiceService] executePayment: invoice %d not found", invoiceId)
        return false
    end

    if invoice.state == Invoice.STATE.PAID then
        return false
    end

    local penaltyAmount = invoice.penaltyAmount or 0
    local totalDue = invoice.totalAmount + penaltyAmount

    if isAuthoritative and g_server ~= nil then
        local recipientFarm = g_farmManager:getFarmById(invoice.recipientFarmId)
        if recipientFarm == nil or math.floor(recipientFarm.money) < math.floor(totalDue) then
            Logging.warning("[InvoiceService] executePayment: insufficient balance (%.2f < %.2f)", recipientFarm and recipientFarm.money or 0, totalDue)
            return false
        end
    end

    self.repository:setState(invoiceId, Invoice.STATE.PAID)

    if isAuthoritative and g_server ~= nil then
        local senderFarm = g_farmManager:getFarmById(invoice.senderFarmId)
        local recipientFarm = g_farmManager:getFarmById(invoice.recipientFarmId)

        if senderFarm and recipientFarm and totalDue > 0 then
            local creditAmount = (invoice.totalHT or invoice.totalAmount) + penaltyAmount
            local vatAmount = invoice.vatAmount or 0

            local hasPaymentDetails = (vatAmount > 0) or (penaltyAmount > 0)

            local localPlayer = g_localPlayer
            local localIsRecipient = localPlayer ~= nil and localPlayer.farmId == invoice.recipientFarmId
            local localIsSender = localPlayer ~= nil and localPlayer.farmId == invoice.senderFarmId

            g_currentMission:addMoney(
                -totalDue,
                invoice.recipientFarmId,
                MoneyType.INVOICE_EXPENSE,
                true,
                not hasPaymentDetails
            )

            g_currentMission:addMoney(
                creditAmount,
                invoice.senderFarmId,
                MoneyType.INVOICE_INCOME,
                true,
                not hasPaymentDetails
            )

        else
            Logging.warning("[InvoiceService] executePayment: cannot transfer money for invoice %d (missing farm or zero amount)", invoiceId)
        end

        local consumableGroups = {}
        for _, item in ipairs(invoice.lineItems or {}) do
            local cXml = item.consumableXmlFilename or ""
            if cXml ~= "" then
                local key = cXml .. "|" .. tostring(item.consumableFillTypeIndex or 0)
                if consumableGroups[key] == nil then
                    consumableGroups[key] = {
                        xmlFilename   = cXml,
                        fillTypeIndex = item.consumableFillTypeIndex or 0,
                        quantity      = 0
                    }
                end
                consumableGroups[key].quantity = consumableGroups[key].quantity + (item.quantity or 1)
            elseif item.vehicleUniqueId ~= nil and item.vehicleUniqueId ~= "" then
                self:transferVehicleOwnership(item.vehicleUniqueId, invoice.senderFarmId, invoice.recipientFarmId)
            end
        end

        for key, group in pairs(consumableGroups) do
            InvoicesConsumablePipeline.transferByCriteria(
                group.xmlFilename, group.fillTypeIndex,
                group.quantity, invoice.senderFarmId, invoice.recipientFarmId
            )
            g_server:broadcastEvent(InvoiceConsumableTransferEvent.new(
                group.xmlFilename, group.fillTypeIndex,
                group.quantity, invoice.senderFarmId, invoice.recipientFarmId
            ))
        end
    end

    if g_localPlayer ~= nil and g_localPlayer.farmId == invoice.recipientFarmId then
        local unpaidInvoices = self:getUnpaidInvoicesForFarm(invoice.recipientFarmId)
        if #unpaidInvoices == 0 and self.reminderFarmId == invoice.recipientFarmId then
            self:deactivateReminder()
        end
    end

    if g_localPlayer ~= nil then
        local vatAmount = invoice.vatAmount or 0
        local creditAmount = (invoice.totalHT or invoice.totalAmount) + penaltyAmount
        local hasPaymentDetails = (vatAmount > 0) or (penaltyAmount > 0)

        if hasPaymentDetails then
            local localIsRecipient = g_localPlayer.farmId == invoice.recipientFarmId
            local localIsSender = g_localPlayer.farmId == invoice.senderFarmId
            local vatLabel = g_i18n:getText("invoice_label_vat")
            local detailsRecipient = {}
            local detailsSender = {}

            if vatAmount > 0 then
                local vatStr = g_i18n:formatMoney(vatAmount, 0, true, false)
                table.insert(detailsRecipient, string.format(g_i18n:getText("invoice_notification_vat_incl"), vatLabel, vatStr))
                table.insert(detailsSender, string.format(g_i18n:getText("invoice_notification_vat_excl"), vatLabel, vatStr))
            end

            if penaltyAmount > 0 then
                local penStr = g_i18n:formatMoney(penaltyAmount, 0, true, false)
                local penDetail = string.format(g_i18n:getText("invoice_notification_penalty_incl"), penStr)
                table.insert(detailsRecipient, penDetail)
                table.insert(detailsSender, penDetail)
            end

            if localIsRecipient and #detailsRecipient > 0 then
                local totalStr = g_i18n:formatMoney(totalDue, 0, true, false)
                g_currentMission:addIngameNotification(
                    FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                    "-" .. totalStr .. " (" .. g_i18n:getText("invoice_label_invoice") .. " " .. table.concat(detailsRecipient, ", ") .. ")"
                )
            end

            if localIsSender and #detailsSender > 0 then
                local creditStr = g_i18n:formatMoney(creditAmount, 0, true, false)
                g_currentMission:addIngameNotification(
                    FSBaseMission.INGAME_NOTIFICATION_OK,
                    "+" .. creditStr .. " (" .. g_i18n:getText("invoice_label_invoice") .. " " .. table.concat(detailsSender, ", ") .. ")"
                )
            end
        end
    end

    self:notifyUI()
    return true
end

---Transfers vehicle ownership between farms
-- @param string vehicleUniqueId Vehicle unique identifier
-- @param integer senderFarmId Current owner farm identifier
-- @param integer recipientFarmId New owner farm identifier
function InvoiceService:transferVehicleOwnership(vehicleUniqueId, senderFarmId, recipientFarmId)
    local vehicle = g_currentMission.vehicleSystem:getVehicleByUniqueId(vehicleUniqueId)
    if vehicle == nil then
        Logging.warning("[InvoiceService] transferVehicleOwnership: vehicle not found (uid=%s)", vehicleUniqueId)
        return
    end

    local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
    if ownerFarmId ~= senderFarmId then
        Logging.warning("[InvoiceService] transferVehicleOwnership: vehicle not owned by sender farm %d (owner=%d)", senderFarmId, ownerFarmId or -1)
        return
    end

    vehicle:setOwnerFarmId(recipientFarmId, true)
    g_server:broadcastEvent(InvoiceVehicleTransferEvent.new(vehicleUniqueId, senderFarmId, recipientFarmId))
end

---Deletes invoice from repository
-- @param integer invoiceId Invoice identifier
-- @return boolean success True if deleted
function InvoiceService:executeDelete(invoiceId)
    local result = self.repository:removeById(invoiceId)
    self:notifyUI()
    return result
end

---Replaces all invoices with sync data from server
-- @param table invoices Array of invoices
-- @param integer nextId Next invoice ID counter
function InvoiceService:applySyncData(invoices, nextId)
    self.repository:replaceAll(invoices, nextId)

    if self.initialCheckDone and g_localPlayer ~= nil then
        local farmId = g_localPlayer.farmId
        if farmId ~= nil and farmId ~= FarmManager.SPECTATOR_FARM_ID then
            local unpaidInvoices = self:getUnpaidInvoicesForFarm(farmId)
            if #unpaidInvoices > 0 then
                self.initialCheckDone = false
            end
        end
    end

    self:notifyUI()
end

---Returns all invoices and next ID for sync
-- @return table invoices All invoices
-- @return integer nextId Next invoice ID counter
function InvoiceService:getSyncData()
    return self.repository:getAll(), self.repository:getNextInvoiceId()
end

---Refreshes invoice list UI if available
function InvoiceService:notifyUI()
    if g_currentMission.invoicesFrame ~= nil then
        g_currentMission.invoicesFrame:refreshList()
    end
end

---Shows new invoice notification to recipient farm player
-- @param table invoice Newly created invoice
function InvoiceService:notifyNewInvoice(invoice)
    if invoice == nil then return end
    if g_localPlayer == nil then return end

    local localFarmId = g_localPlayer.farmId
    if localFarmId ~= invoice.recipientFarmId then return end

    local senderFarm = g_farmManager:getFarmById(invoice.senderFarmId)
    local senderName = senderFarm and senderFarm.name or "?"
    local amountStr = g_i18n:formatMoney(invoice.totalAmount or 0)
    local text = string.format(g_i18n:getText("invoice_notification_new"), senderName, amountStr)

    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)
    
    self:activateReminder()
end

---Initializes reminder system and subscribes to farm changes
function InvoiceService:initializeReminderSystem()
    g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, self.onPlayerFarmChanged, self)

    g_currentMission:addUpdateable(self)
    self.initialCheckDone = false
end

---Returns whether invoice reminders are enabled
-- @return boolean isEnabled
function InvoiceService:isRemindersEnabled()
    if g_currentMission == nil or g_currentMission.invoiceSettings == nil then
        return true
    end
    return g_currentMission.invoiceSettings.invoiceReminders ~= false
end

---Activates periodic reminder for unpaid invoices
-- @param integer? farmId Target farm identifier
function InvoiceService:activateReminder(farmId)
    if g_localPlayer == nil then return end
    if not self:isRemindersEnabled() then return end
    
    local targetFarmId = farmId or g_localPlayer.farmId
    
    local unpaidInvoices = self:getUnpaidInvoicesForFarm(targetFarmId)
    if #unpaidInvoices == 0 then 
        return 
    end
    
    if not self.reminderActive or self.reminderFarmId ~= targetFarmId then
        self.reminderActive = true
        self.reminderFarmId = targetFarmId
        self.reminderTimer = InvoiceService.REMINDER_FIRST_DELAY
        self.firstReminderSent = false
    end
end

---Deactivates periodic invoice reminder
function InvoiceService:deactivateReminder()
    if self.reminderActive then
        self.reminderActive = false
        self.reminderFarmId = nil
    end
end

---Cleans up reminder system and unsubscribes from events
function InvoiceService:cleanupReminderSystem()
    self.reminderActive = false
    self.reminderFarmId = nil
    self.initialCheckDone = false
    self.lastNotifiedFarmId = nil
    g_messageCenter:unsubscribe(MessageType.PLAYER_FARM_CHANGED, self)
    g_currentMission:removeUpdateable(self)
end

---Called when player changes farm, resets reminder state
function InvoiceService:onPlayerFarmChanged()
    self:deactivateReminder()
    self.initialCheckDone = false
    self.lastNotifiedFarmId = nil
end

---Checks if any invoice in the list has a penalty
-- @param table unpaidInvoices Array of unpaid invoices
-- @return boolean hasOverdue True if any has penalty > 0
function InvoiceService:hasOverdueInvoices(unpaidInvoices)
    for _, invoice in ipairs(unpaidInvoices or {}) do
        if (invoice.penaltyAmount or 0) > 0 then
            return true
        end
    end
    return false
end

---Builds reminder notification text with amounts and overdue info
-- @param table unpaidInvoices Array of unpaid invoices
-- @param integer totalAmount Total amount due
-- @return string text Formatted notification text
function InvoiceService:buildReminderText(unpaidInvoices, totalAmount)
    local amountStr = g_i18n:formatMoney(totalAmount or 0)
    local text

    if #unpaidInvoices == 1 then
        text = string.format(g_i18n:getText("invoice_reminder_single"), amountStr)
    else
        text = string.format(g_i18n:getText("invoice_reminder_multiple"), #unpaidInvoices, amountStr)
    end

    if self:hasOverdueInvoices(unpaidInvoices) then
        local overdueStatus = g_i18n:getText("invoice_status_overdue")
        local overdueWarn = g_i18n:getText("invoice_notification_overdue_warning")

        if overdueStatus ~= nil and overdueStatus ~= "" then
            text = text .. " (" .. overdueStatus .. ")"
        end
        if overdueWarn ~= nil and overdueWarn ~= "" then
            text = text .. " : " .. overdueWarn
        end
    end

    return text
end

-- Handles initial connection check (PLAYER_FARM_CHANGED not fired on first join)
---Called each frame to process penalties and reminders
-- @param float dt Delta time in milliseconds
function InvoiceService:update(dt)
    -- Penalty accrual (server only, throttled)
    if g_server ~= nil then
        self.penaltyTimer = self.penaltyTimer - dt
        if self.penaltyTimer <= 0 then
            self.penaltyTimer = InvoiceService.PENALTY_CHECK_INTERVAL
            local ok, err = pcall(self.processPenalties, self)
            if not ok then
                Logging.warning("[InvoiceService] processPenalties error: %s", tostring(err))
            end
        end
    end

    if not self.initialCheckDone then
        if g_localPlayer ~= nil and g_localPlayer.farmId ~= FarmManager.SPECTATOR_FARM_ID then
            self.initialCheckDone = true
            local currentFarmId = g_localPlayer.farmId
            self.lastNotifiedFarmId = currentFarmId
            
            local unpaidInvoices = self:getUnpaidInvoicesForFarm(currentFarmId)
            if #unpaidInvoices > 0 then
                local totalAmount = 0
                for _, invoice in ipairs(unpaidInvoices) do
                    totalAmount = totalAmount + (invoice.totalAmount or 0) + (invoice.penaltyAmount or 0)
                end

                local text = self:buildReminderText(unpaidInvoices, totalAmount)
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)

                self:activateReminder(currentFarmId)
            end
        end
        return
    end
    
    if not self.reminderActive then return end
    if g_localPlayer == nil then return end
    if not self:isRemindersEnabled() then
        self:deactivateReminder()
        return
    end
    
    if self.reminderFarmId ~= g_localPlayer.farmId then
        self:deactivateReminder()
        return
    end
    
    self.reminderTimer = self.reminderTimer - dt
    
    if self.reminderTimer <= 0 then
        local unpaidInvoices = self:getUnpaidInvoicesForFarm(self.reminderFarmId)
        
        if #unpaidInvoices > 0 then
            local totalAmount = 0
            for _, invoice in ipairs(unpaidInvoices) do
                totalAmount = totalAmount + (invoice.totalAmount or 0) + (invoice.penaltyAmount or 0)
            end

            local text = self:buildReminderText(unpaidInvoices, totalAmount)
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)

            self.firstReminderSent = true
            self.reminderTimer = InvoiceService.REMINDER_INTERVAL
        else
            self:deactivateReminder()
        end
    end
end

---Returns unpaid invoices for a recipient farm
-- @param integer farmId Recipient farm identifier
-- @return table unpaidInvoices Array of unpaid invoices
function InvoiceService:getUnpaidInvoicesForFarm(farmId)
    local unpaidInvoices = {}
    local invoices = self.repository:getByRecipientFarm(farmId)
    
    for _, invoice in ipairs(invoices) do
        if invoice.state ~= Invoice.STATE.PAID and invoice.state ~= Invoice.STATE.CANCELLED then
            table.insert(unpaidInvoices, invoice)
        end
    end
    
    return unpaidInvoices
end
