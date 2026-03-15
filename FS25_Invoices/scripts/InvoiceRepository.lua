--[[
    InvoiceRepository.lua
    CRUD + XML persistence. No business logic. No network.
    Author: Squallqt
]]

InvoiceRepository = {}
local InvoiceRepository_mt = Class(InvoiceRepository)

InvoiceRepository.SAVE_VERSION = 3

function InvoiceRepository.new()
    local self = setmetatable({}, InvoiceRepository_mt)

    self.invoices = {}
    self.nextInvoiceId = 1

    return self
end

function InvoiceRepository:clear()
    self.invoices = {}
    self.nextInvoiceId = 1
end

function InvoiceRepository:generateId()
    local id = self.nextInvoiceId
    self.nextInvoiceId = self.nextInvoiceId + 1
    return id
end

function InvoiceRepository:add(invoice)
    if invoice.id == 0 then
        invoice.id = self:generateId()
    end
    table.insert(self.invoices, invoice)
end

function InvoiceRepository:getById(id)
    for _, invoice in ipairs(self.invoices) do
        if invoice.id == id then
            return invoice
        end
    end
    return nil
end

function InvoiceRepository:removeById(id)
    for i, invoice in ipairs(self.invoices) do
        if invoice.id == id then
            table.remove(self.invoices, i)
            return true
        end
    end
    return false
end

function InvoiceRepository:setState(id, newState)
    local invoice = self:getById(id)
    if invoice then
        invoice.state = newState
        return true
    end
    return false
end

function InvoiceRepository:getByRecipientFarm(farmId)
    local result = {}
    for _, invoice in ipairs(self.invoices) do
        if invoice.recipientFarmId == farmId then
            table.insert(result, invoice)
        end
    end
    return result
end

function InvoiceRepository:getBySenderFarm(farmId)
    local result = {}
    for _, invoice in ipairs(self.invoices) do
        if invoice.senderFarmId == farmId then
            table.insert(result, invoice)
        end
    end
    return result
end

function InvoiceRepository:getAll()
    return self.invoices
end

function InvoiceRepository:getNextInvoiceId()
    return self.nextInvoiceId
end

function InvoiceRepository:setNextInvoiceId(id)
    self.nextInvoiceId = id
end

function InvoiceRepository:replaceAll(invoices, nextId)
    self.invoices = invoices
    self.nextInvoiceId = nextId
end

function InvoiceRepository:saveToXML(savegamePath)
    local filePath = savegamePath .. "invoices.xml"
    local xmlFile = createXMLFile("invoices", filePath, "invoices")

    if xmlFile == nil then
        Logging.error("[Invoices] Failed to create save file: %s", filePath)
        return
    end

    setXMLInt(xmlFile, "invoices#version", InvoiceRepository.SAVE_VERSION)
    setXMLInt(xmlFile, "invoices#nextId", self.nextInvoiceId)

    for i, invoice in ipairs(self.invoices) do
        local key = string.format("invoices.invoice(%d)", i - 1)
        invoice:writeToXML(xmlFile, key)
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function InvoiceRepository:loadFromXML(savegamePath)
    local filePath = savegamePath .. "invoices.xml"

    if not fileExists(filePath) then
        return
    end

    local xmlFile = loadXMLFile("invoices", filePath)
    if xmlFile == nil then
        Logging.warning("[Invoices] Failed to load save file: %s", filePath)
        return
    end

    local version = getXMLInt(xmlFile, "invoices#version") or 1

    if version > InvoiceRepository.SAVE_VERSION then
        Logging.warning("[Invoices] Save file version %d is newer than supported version %d. Some data may be ignored.", version, InvoiceRepository.SAVE_VERSION)
    end

    self.nextInvoiceId = getXMLInt(xmlFile, "invoices#nextId") or 1
    self.invoices = {}

    local i = 0
    while true do
        local key = string.format("invoices.invoice(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local invoice = Invoice.new()
        invoice:readFromXML(xmlFile, key)

        -- Savegame migration v1→v2: UNPAID(1)→NEW, PAID(2)→PAID(3)
        if version < 2 then
            if invoice.state == 2 then
                invoice.state = Invoice.STATE.PAID
            else
                invoice.state = Invoice.STATE.NEW
            end
        end

            if invoice.id >= self.nextInvoiceId then
            self.nextInvoiceId = invoice.id + 1
        end

        table.insert(self.invoices, invoice)

        i = i + 1
    end

    Logging.info("[Invoices] Loaded %d invoices from %s (format v%d)", #self.invoices, filePath, version)
    delete(xmlFile)
end
