--[[
    InvoicesManager.lua
    Lightweight facade. Owns Repository + Service, exposed on g_currentMission.
    Author: Squallqt
]]

InvoicesManager = {}
local InvoicesManager_mt = Class(InvoicesManager)

function InvoicesManager.new()
    local self = setmetatable({}, InvoicesManager_mt)

    self.repository = InvoiceRepository.new()
    self.service = InvoiceService.new(self.repository)
    self.isInitialized = false

    return self
end

function InvoicesManager:initialize()
    if self.isInitialized then
        return
    end

    self.repository:clear()
    self.isInitialized = true
end

function InvoicesManager:cleanup()
    self.repository:clear()
    self.isInitialized = false
end

function InvoicesManager:createAndSendInvoice(invoice)
    return self.service:createAndSendInvoice(invoice)
end

function InvoicesManager:payInvoice(invoiceId)
    return self.service:payInvoice(invoiceId)
end

function InvoicesManager:deleteInvoice(invoiceId)
    return self.service:deleteInvoice(invoiceId)
end

function InvoicesManager:getWorkTypes()
    return self.service:getWorkTypes()
end

function InvoicesManager:getWorkTypeById(id)
    return self.service:getWorkTypeById(id)
end

function InvoicesManager:getUnitKey(unitType)
    return self.service:getUnitKey(unitType)
end

function InvoicesManager:getDifficultyMultiplier()
    return self.service:getDifficultyMultiplier()
end

function InvoicesManager:getAdjustedPrice(workTypeId)
    return self.service:getAdjustedPrice(workTypeId)
end

function InvoicesManager:getInvoiceById(id)
    return self.repository:getById(id)
end

function InvoicesManager:getIncomingInvoices(farmId)
    return self.repository:getByRecipientFarm(farmId)
end

function InvoicesManager:getOutgoingInvoices(farmId)
    return self.repository:getBySenderFarm(farmId)
end

function InvoicesManager:generateId()
    return self.repository:generateId()
end

function InvoicesManager:getHasFarmManagerPermission()
    if g_currentMission == nil or g_currentMission.getHasPlayerPermission == nil then
        return true
    end
    return g_currentMission:getHasPlayerPermission("farmManager")
end

function InvoicesManager:farmHasSufficientBalance(farmId, amount)
    if g_farmManager == nil then
        return false
    end
    local farm = g_farmManager:getFarmById(farmId)
    if farm == nil then
        return false
    end
    return (farm.money or 0) >= amount
end

function InvoicesManager:saveToXML(savegamePath)
    return self.repository:saveToXML(savegamePath)
end

function InvoicesManager:loadFromXML(savegamePath)
    return self.repository:loadFromXML(savegamePath)
end
