--[[
    InvoiceService.lua
    Business logic + pricing + server-authoritative money transfers.
    Author: Squallqt
]]

InvoiceService = {}
local InvoiceService_mt = Class(InvoiceService)

-- Base prices from French ETA rates, adjusted at runtime by economicDifficulty.
InvoiceService.WORK_TYPES = {
    {id = 1,   nameKey = "invoice_work_stoneCollection",     basePrice = 600, unit = Invoice.UNIT_HECTARE},
    {id = 2,   nameKey = "invoice_work_plowing",             basePrice = 850,  unit = Invoice.UNIT_HECTARE},
    {id = 3,   nameKey = "invoice_work_cultivating",         basePrice = 425,  unit = Invoice.UNIT_HECTARE},
    {id = 4,   nameKey = "invoice_work_mulching",            basePrice = 450,  unit = Invoice.UNIT_HECTARE},
    {id = 5,   nameKey = "invoice_work_rolling",             basePrice = 225,  unit = Invoice.UNIT_HECTARE},
    {id = 6,   nameKey = "invoice_work_harrowing",           basePrice = 300,  unit = Invoice.UNIT_HECTARE},
    {id = 7,   nameKey = "invoice_work_seeding",             basePrice = 450,  unit = Invoice.UNIT_HECTARE},
    {id = 8,   nameKey = "invoice_work_seedingPotato",       basePrice = 1775, unit = Invoice.UNIT_HECTARE},
    {id = 9,   nameKey = "invoice_work_seedingSugarcane",    basePrice = 1775, unit = Invoice.UNIT_HECTARE},
    {id = 10, nameKey = "invoice_work_seedingRice",         basePrice = 525,  unit = Invoice.UNIT_HECTARE},
    {id = 11, nameKey = "invoice_work_seedingRoot",         basePrice = 850,  unit = Invoice.UNIT_HECTARE},
    {id = 12, nameKey = "invoice_work_pruning",             basePrice = 1700, unit = Invoice.UNIT_HECTARE},
    {id = 13, nameKey = "invoice_work_spraying",            basePrice = 225,  unit = Invoice.UNIT_HECTARE},
    {id = 14, nameKey = "invoice_work_organicFertilizer",   basePrice = 725,  unit = Invoice.UNIT_HECTARE},
    {id = 15, nameKey = "invoice_work_mineralFertilizer",   basePrice = 250,  unit = Invoice.UNIT_HECTARE},
    {id = 16, nameKey = "invoice_work_mechanicalWeeding",   basePrice = 375,  unit = Invoice.UNIT_HECTARE},
    {id = 17, nameKey = "invoice_work_harvestGrain",        basePrice = 1900,  unit = Invoice.UNIT_HECTARE},
    {id = 18, nameKey = "invoice_work_harvestPotato",       basePrice = 3850, unit = Invoice.UNIT_HECTARE},
    {id = 19, nameKey = "invoice_work_harvestSugarbeet",    basePrice = 3250, unit = Invoice.UNIT_HECTARE},
    {id = 20, nameKey = "invoice_work_harvestSugarcane",    basePrice = 5000, unit = Invoice.UNIT_HECTARE},
    {id = 21, nameKey = "invoice_work_harvestCotton",       basePrice = 2950, unit = Invoice.UNIT_HECTARE},
    {id = 22, nameKey = "invoice_work_harvestGrape",        basePrice = 2150, unit = Invoice.UNIT_HECTARE},
    {id = 23, nameKey = "invoice_work_harvestOlive",        basePrice = 3250, unit = Invoice.UNIT_HECTARE},
    {id = 24, nameKey = "invoice_work_harvestRice",         basePrice = 1000, unit = Invoice.UNIT_HECTARE},
    {id = 25, nameKey = "invoice_work_harvestSpinach",      basePrice = 2950, unit = Invoice.UNIT_HECTARE},
    {id = 26, nameKey = "invoice_work_harvestPeas",         basePrice = 2950,  unit = Invoice.UNIT_HECTARE},
    {id = 27, nameKey = "invoice_work_harvestGreenBeans",   basePrice = 2950, unit = Invoice.UNIT_HECTARE},
    {id = 28, nameKey = "invoice_work_harvestVegetables",   basePrice = 4250, unit = Invoice.UNIT_HECTARE},
    {id = 29, nameKey = "invoice_work_harvestOnion",        basePrice = 3625, unit = Invoice.UNIT_HECTARE},
    {id = 30, nameKey = "invoice_work_chaffing",            basePrice = 2000, unit = Invoice.UNIT_HECTARE},
    {id = 31, nameKey = "invoice_work_mowing",              basePrice = 560,  unit = Invoice.UNIT_HECTARE},
    {id = 32, nameKey = "invoice_work_tedding",             basePrice = 200,  unit = Invoice.UNIT_HECTARE},
    {id = 33, nameKey = "invoice_work_windrowing",          basePrice = 225,  unit = Invoice.UNIT_HECTARE},
    {id = 34, nameKey = "invoice_work_baling",              basePrice = 85,   unit = Invoice.UNIT_PIECE},
    {id = 35, nameKey = "invoice_work_wrapping",            basePrice = 65,   unit = Invoice.UNIT_PIECE},
    {id = 36, nameKey = "invoice_work_buyBales",            basePrice = 45,   unit = Invoice.UNIT_PIECE},
    {id = 37, nameKey = "invoice_work_sellBales",           basePrice = 45,   unit = Invoice.UNIT_PIECE},
    {id = 38, nameKey = "invoice_work_animalFeeding",       basePrice = 175,  unit = Invoice.UNIT_HOUR},
    {id = 39, nameKey = "invoice_work_barnCleaning",        basePrice = 250,  unit = Invoice.UNIT_HOUR},
    {id = 40, nameKey = "invoice_work_animalTransport",     basePrice = 1250, unit = Invoice.UNIT_HOUR},
    {id = 41, nameKey = "invoice_work_snowRemoval",         basePrice = 1000, unit = Invoice.UNIT_HOUR},
    {id = 42, nameKey = "invoice_work_generalLabor",        basePrice = 1000, unit = Invoice.UNIT_HOUR},
    {id = 43, nameKey = "invoice_work_loaderWork",          basePrice = 1500, unit = Invoice.UNIT_HOUR},
    {id = 44, nameKey = "invoice_work_driving",             basePrice = 1000, unit = Invoice.UNIT_HOUR},
    {id = 45, nameKey = "invoice_work_siloWork",            basePrice = 900,  unit = Invoice.UNIT_HOUR},
    {id = 46, nameKey = "invoice_work_delivery",            basePrice = 900,  unit = Invoice.UNIT_HOUR},
    {id = 47, nameKey = "invoice_work_transport",           basePrice = 800,  unit = Invoice.UNIT_HOUR},
    {id = 48, nameKey = "invoice_work_equipmentRental",     basePrice = 500,  unit = Invoice.UNIT_HOUR},
    {id = 49, nameKey = "invoice_work_heapLoading",         basePrice = 1200, unit = Invoice.UNIT_HOUR},
    {id = 50, nameKey = "invoice_work_treePlanting",        basePrice = 300,  unit = Invoice.UNIT_PIECE},
    {id = 51, nameKey = "invoice_work_treeCutting",         basePrice = 700,  unit = Invoice.UNIT_PIECE},
    {id = 52, nameKey = "invoice_work_treeRemoval",         basePrice = 300,  unit = Invoice.UNIT_PIECE},
    {id = 53, nameKey = "invoice_work_goods",               basePrice = 0.5,  unit = Invoice.UNIT_LITER},
    {id = 54, nameKey = "invoice_work_miscellaneous",       basePrice = 100,  unit = Invoice.UNIT_PIECE},
}

InvoiceService.REMINDER_INTERVAL = 300000
InvoiceService.REMINDER_FIRST_DELAY = 60000

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

    return self
end

function InvoiceService:loadVatRates(xmlPath)
    local xmlFile = loadXMLFile("vatRates", xmlPath)
    if xmlFile == 0 then
        Logging.warning("[InvoiceService] Failed to load vatRates.xml from %s", xmlPath)
        return
    end

    self.vatGroups = {}
    self.workTypeGroups = {}

    local i = 0
    while true do
        local key = string.format("vatRates.groups.group(%d)", i)
        if not hasXMLProperty(xmlFile, key) then break end
        local name = getXMLString(xmlFile, key .. "#name")
        local rate = getXMLFloat(xmlFile, key .. "#defaultRate")
        if name ~= nil and rate ~= nil then
            self.vatGroups[name] = rate
        end
        i = i + 1
    end

    i = 0
    while true do
        local key = string.format("vatRates.workTypes.workType(%d)", i)
        if not hasXMLProperty(xmlFile, key) then break end
        local id = getXMLInt(xmlFile, key .. "#id")
        local group = getXMLString(xmlFile, key .. "#group")
        if id ~= nil and group ~= nil then
            self.workTypeGroups[id] = group
        end
        i = i + 1
    end

    delete(xmlFile)
    Logging.info("[InvoiceService] VAT rates loaded: %d groups, %d work type mappings", i, i)
end

function InvoiceService:isVatEnabled()
    return g_currentMission.RedTape ~= nil
       and g_currentMission.RedTape.TaxSystem ~= nil
       and g_currentMission.RedTape.TaxSystem:isEnabled()
end

function InvoiceService:getVatRateForWorkType(workTypeId)
    if not self:isVatEnabled() then return 0 end
    local group = self.workTypeGroups[workTypeId]
    if group == nil then return 0 end
    return self.vatGroups[group] or 0
end

function InvoiceService:getWorkTypes()
    return InvoiceService.WORK_TYPES
end

function InvoiceService:getWorkTypeById(id)
    for _, workType in ipairs(InvoiceService.WORK_TYPES) do
        if workType.id == id then
            return workType
        end
    end
    return nil
end

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
function InvoiceService:getDifficultyMultiplier()
    local difficulty = 2
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        difficulty = g_currentMission.missionInfo.economicDifficulty or 2
    end
    return 1.3 - 0.1 * difficulty
end

function InvoiceService:getAdjustedPrice(workTypeId)
    local workType = self:getWorkTypeById(workTypeId)
    if workType == nil then
        return 0
    end
    return MathUtil.round(workType.basePrice * self:getDifficultyMultiplier(), 2)
end

function InvoiceService:createAndSendInvoice(invoice, noEventSend)
    invoice.id = self.repository:generateId()
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

function InvoiceService:payInvoice(invoiceId, noEventSend)
    if not self:executePayment(invoiceId, true) then
        return
    end
    
    if not (noEventSend == true) then
        if g_server ~= nil then
            g_server:broadcastEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_PAY))
        else
            g_client:getServerConnection():sendEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_PAY))
        end
    end
end

function InvoiceService:deleteInvoice(invoiceId, noEventSend)
    self:executeDelete(invoiceId)
    
    if not (noEventSend == true) then
        if g_server ~= nil then
            g_server:broadcastEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_DELETE))
        else
            g_client:getServerConnection():sendEvent(InvoiceStateEvent.new(invoiceId, InvoiceStateEvent.ACTION_DELETE))
        end
    end
end

-- Server-authoritative create (called by network events)
function InvoiceService:applyCreateAuthoritative(invoice)
    self.repository:add(invoice)
    self:notifyNewInvoice(invoice)
    self:notifyUI()
end

function InvoiceService:executePayment(invoiceId, isAuthoritative)
    local invoice = self.repository:getById(invoiceId)
    if invoice == nil then
        Logging.warning("[InvoiceService] executePayment: invoice %d not found", invoiceId)
        return false
    end

    if invoice.state == Invoice.STATE.PAID then
        Logging.devInfo("[InvoiceService] executePayment: invoice %d already paid (guard prevented duplicate)", invoiceId)
        return false
    end

    if isAuthoritative and g_server ~= nil then
        local recipientFarm = g_farmManager:getFarmById(invoice.recipientFarmId)
        if recipientFarm == nil or recipientFarm.money < invoice.totalAmount then
            Logging.warning("[InvoiceService] executePayment: insufficient balance (%.2f < %.2f)", recipientFarm and recipientFarm.money or 0, invoice.totalAmount)
            return false
        end
    end

    self.repository:setState(invoiceId, Invoice.STATE.PAID)

    if isAuthoritative and g_server ~= nil then
        local senderFarm = g_farmManager:getFarmById(invoice.senderFarmId)
        local recipientFarm = g_farmManager:getFarmById(invoice.recipientFarmId)

        if senderFarm and recipientFarm and invoice.totalAmount > 0 then
            local creditAmount = invoice.totalHT or invoice.totalAmount

            g_currentMission:addMoney(
                -invoice.totalAmount,
                invoice.recipientFarmId,
                MoneyType.INVOICE_EXPENSE,
                true,
                true
            )
            Logging.devInfo("[InvoiceService] Payer %s debited %d (TTC)", recipientFarm.name, invoice.totalAmount)

            g_currentMission:addMoney(
                creditAmount,
                invoice.senderFarmId,
                MoneyType.INVOICE_INCOME,
                true,
                true
            )
            Logging.devInfo("[InvoiceService] Provider %s credited %d (HT)", senderFarm.name, creditAmount)

            local vatLost = invoice.totalAmount - creditAmount
            if vatLost > 0 then
                Logging.devInfo("[InvoiceService] VAT %d removed from economy", vatLost)
            end
        else
            Logging.warning("[InvoiceService] executePayment: cannot transfer money for invoice %d (missing farm or zero amount)", invoiceId)
        end
    end

    if g_localPlayer ~= nil and g_localPlayer.farmId == invoice.recipientFarmId then
        local unpaidInvoices = self:getUnpaidInvoicesForFarm(invoice.recipientFarmId)
        if #unpaidInvoices == 0 and self.reminderFarmId == invoice.recipientFarmId then
            self:deactivateReminder()
        end
    end

    self:notifyUI()
    return true
end

function InvoiceService:executeDelete(invoiceId)
    local result = self.repository:removeById(invoiceId)
    self:notifyUI()
    return result
end

function InvoiceService:applySyncData(invoices, nextId)
    self.repository:replaceAll(invoices, nextId)
    self:notifyUI()
end

function InvoiceService:getSyncData()
    return self.repository:getAll(), self.repository:getNextInvoiceId()
end

function InvoiceService:notifyUI()
    if g_currentMission.invoicesFrame ~= nil then
        g_currentMission.invoicesFrame:refreshList()
    end
end

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

function InvoiceService:initializeReminderSystem()
    g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, self.onPlayerFarmChanged, self)
    Logging.devInfo("[InvoiceService] Reminder system initialized with PLAYER_FARM_CHANGED subscription")
    
    g_currentMission:addUpdateable(self)
    self.initialCheckDone = false
end

function InvoiceService:activateReminder(farmId)
    if g_localPlayer == nil then return end
    
    local targetFarmId = farmId or g_localPlayer.farmId
    
    local unpaidInvoices = self:getUnpaidInvoicesForFarm(targetFarmId)
    if #unpaidInvoices == 0 then 
        Logging.devInfo("[InvoiceService] No unpaid invoices for farm %d, reminder not activated", targetFarmId)
        return 
    end
    
    if not self.reminderActive or self.reminderFarmId ~= targetFarmId then
        self.reminderActive = true
        self.reminderFarmId = targetFarmId
        self.reminderTimer = InvoiceService.REMINDER_FIRST_DELAY
        self.firstReminderSent = false
        g_currentMission:addUpdateable(self)
        Logging.devInfo("[InvoiceService] Reminder activated for farm %d (%d unpaid invoice(s))", targetFarmId, #unpaidInvoices)
    end
end

function InvoiceService:deactivateReminder()
    if self.reminderActive then
        local wasFarmId = self.reminderFarmId
        self.reminderActive = false
        self.reminderFarmId = nil
        g_currentMission:removeUpdateable(self)
        Logging.devInfo("[InvoiceService] Reminder deactivated for farm %d", wasFarmId or 0)
    end
end

function InvoiceService:cleanupReminderSystem()
    self.reminderActive = false
    self.reminderFarmId = nil
    self.initialCheckDone = false
    self.lastNotifiedFarmId = nil
    g_messageCenter:unsubscribe(MessageType.PLAYER_FARM_CHANGED, self)
    g_currentMission:removeUpdateable(self)
    Logging.devInfo("[InvoiceService] Reminder system cleaned up")
end

-- Guard against duplicate PLAYER_FARM_CHANGED events from engine
function InvoiceService:onPlayerFarmChanged(player)
    if player ~= g_localPlayer then return end
    if g_localPlayer == nil then return end
    
    local currentFarmId = g_localPlayer.farmId
    
    if self.lastNotifiedFarmId == currentFarmId then
        Logging.devInfo("[InvoiceService] Duplicate farm change event ignored for farm %d", currentFarmId)
        return
    end
    
    self.initialCheckDone = true
    self.lastNotifiedFarmId = currentFarmId
    
    Logging.devInfo("[InvoiceService] Player farm changed to farm %d", currentFarmId)
    
    local unpaidInvoices = self:getUnpaidInvoicesForFarm(currentFarmId)
    
    if #unpaidInvoices > 0 then
        local totalAmount = 0
        for _, invoice in ipairs(unpaidInvoices) do
            totalAmount = totalAmount + (invoice.totalAmount or 0)
        end
        
        local amountStr = g_i18n:formatMoney(totalAmount)
        local text
        if #unpaidInvoices == 1 then
            text = string.format(g_i18n:getText("invoice_reminder_single"), amountStr)
        else
            text = string.format(g_i18n:getText("invoice_reminder_multiple"), #unpaidInvoices, amountStr)
        end
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)
        Logging.devInfo("[InvoiceService] Immediate notification shown: %d invoice(s), total %s", #unpaidInvoices, amountStr)
        
        self:activateReminder(currentFarmId)
    else
        if self.reminderFarmId == currentFarmId then
            self:deactivateReminder()
        end
    end
end

-- Handles initial connection check (PLAYER_FARM_CHANGED not fired on first join)
function InvoiceService:update(dt)
    if not self.initialCheckDone then
        if g_localPlayer ~= nil and g_localPlayer.farmId ~= FarmManager.SPECTATOR_FARM_ID then
            self.initialCheckDone = true
            local currentFarmId = g_localPlayer.farmId
            Logging.devInfo("[InvoiceService] Initial connection check for farm %d", currentFarmId)
            
            local unpaidInvoices = self:getUnpaidInvoicesForFarm(currentFarmId)
            if #unpaidInvoices > 0 then
                local totalAmount = 0
                for _, invoice in ipairs(unpaidInvoices) do
                    totalAmount = totalAmount + (invoice.totalAmount or 0)
                end
                
                local amountStr = g_i18n:formatMoney(totalAmount)
                local text
                if #unpaidInvoices == 1 then
                    text = string.format(g_i18n:getText("invoice_reminder_single"), amountStr)
                else
                    text = string.format(g_i18n:getText("invoice_reminder_multiple"), #unpaidInvoices, amountStr)
                end
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)
                Logging.devInfo("[InvoiceService] Initial notification shown: %d invoice(s), total %s", #unpaidInvoices, amountStr)
                
                self:activateReminder(currentFarmId)
            else
                g_currentMission:removeUpdateable(self)
                Logging.devInfo("[InvoiceService] No unpaid invoices on connection, updateable removed")
            end
        end
        return
    end
    
    if not self.reminderActive then return end
    if g_localPlayer == nil then return end
    
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
                totalAmount = totalAmount + (invoice.totalAmount or 0)
            end
            
            local amountStr = g_i18n:formatMoney(totalAmount)
            local text
            if #unpaidInvoices == 1 then
                text = string.format(g_i18n:getText("invoice_reminder_single"), amountStr)
            else
                text = string.format(g_i18n:getText("invoice_reminder_multiple"), #unpaidInvoices, amountStr)
            end
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)
            Logging.devInfo("[InvoiceService] Reminder displayed for farm %d: %d invoice(s), total %s", self.reminderFarmId, #unpaidInvoices, amountStr)
            
            self.firstReminderSent = true
            self.reminderTimer = InvoiceService.REMINDER_INTERVAL
        else
            self:deactivateReminder()
        end
    end
end

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
