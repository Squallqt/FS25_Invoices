-- Copyright © 2026 Squallqt. All rights reserved.
-- Lightweight facade. Owns Repository + Service, exposed on g_currentMission.
InvoicesManager = {}
local InvoicesManager_mt = Class(InvoicesManager)

---Creates new invoices manager instance
-- @return InvoicesManager instance The new manager instance
function InvoicesManager.new()
    local self = setmetatable({}, InvoicesManager_mt)

    self.repository = InvoiceRepository.new()
    self.service = InvoiceService.new(self.repository)
    self.isInitialized = false

    return self
end

---Initializes manager data
function InvoicesManager:initialize()
    if self.isInitialized then
        return
    end

    self.repository:clear()
    self.isInitialized = true
end

---Cleans up manager data
function InvoicesManager:cleanup()
    self.repository:clear()
    self.isInitialized = false
end

---Creates and sends invoice via service
-- @param table invoice Invoice to create
function InvoicesManager:createAndSendInvoice(invoice)
    return self.service:createAndSendInvoice(invoice)
end

---Pays invoice via service
-- @param integer invoiceId Invoice identifier
function InvoicesManager:payInvoice(invoiceId)
    return self.service:payInvoice(invoiceId)
end

---Deletes invoice via service
-- @param integer invoiceId Invoice identifier
function InvoicesManager:deleteInvoice(invoiceId)
    return self.service:deleteInvoice(invoiceId)
end

---Returns all work types
-- @return table workTypes
function InvoicesManager:getWorkTypes()
    return self.service:getWorkTypes()
end

---Returns work type by identifier
-- @param integer id Work type identifier
-- @return table|nil workType
function InvoicesManager:getWorkTypeById(id)
    return self.service:getWorkTypeById(id)
end

---Returns i18n key for a unit type
-- @param integer unitType Unit type constant
-- @return string key
function InvoicesManager:getUnitKey(unitType)
    return self.service:getUnitKey(unitType)
end

---Returns economic difficulty multiplier
-- @return float multiplier
function InvoicesManager:getDifficultyMultiplier()
    return self.service:getDifficultyMultiplier()
end

---Returns difficulty-adjusted price for a work type
-- @param integer workTypeId Work type identifier
-- @return float price
function InvoicesManager:getAdjustedPrice(workTypeId)
    return self.service:getAdjustedPrice(workTypeId)
end

---Returns invoice by identifier
-- @param integer id Invoice identifier
-- @return Invoice|nil invoice Invoice instance or nil
function InvoicesManager:getInvoiceById(id)
    return self.repository:getById(id)
end

---Returns incoming invoices for farm
-- @param integer farmId Farm identifier
-- @return table invoices Incoming invoices
function InvoicesManager:getIncomingInvoices(farmId)
    return self.repository:getByRecipientFarm(farmId)
end

---Returns outgoing invoices for farm
-- @param integer farmId Farm identifier
-- @return table invoices Outgoing invoices
function InvoicesManager:getOutgoingInvoices(farmId)
    return self.repository:getBySenderFarm(farmId)
end

---Generates next unique invoice ID
-- @return integer id
function InvoicesManager:generateId()
    return self.repository:generateId()
end

---Returns whether player has farmManager permission
-- @return boolean hasPermission
function InvoicesManager:getHasFarmManagerPermission()
    if g_currentMission == nil or g_currentMission.getHasPlayerPermission == nil then
        return true
    end
    return g_currentMission:getHasPlayerPermission("farmManager")
end

---Returns whether a farm can afford a given amount
-- @param integer farmId Farm identifier
-- @param integer amount Amount to check
-- @return boolean hasFunds
function InvoicesManager:farmHasSufficientBalance(farmId, amount)
    if g_farmManager == nil then
        return false
    end
    local farm = g_farmManager:getFarmById(farmId)
    if farm == nil then
        return false
    end
    return math.floor(farm.money or 0) >= math.floor(amount)
end

---Saves invoices and optional settings to XML
-- @param string savegamePath Path to savegame directory
-- @param table? settings Optional settings to include
function InvoicesManager:saveToXML(savegamePath, settings)
    if settings ~= nil then
        return self.repository:saveToXMLWithSettings(savegamePath, settings)
    end
    return self.repository:saveToXML(savegamePath)
end

---Loads invoices from XML file
-- @param string savegamePath Path to savegame directory
function InvoicesManager:loadFromXML(savegamePath)
    return self.repository:loadFromXML(savegamePath)
end
