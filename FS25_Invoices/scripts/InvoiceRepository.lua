-- Copyright © 2026 Squallqt. All rights reserved.
-- CRUD + XML persistence. No business logic. No network.
InvoiceRepository = {}
local InvoiceRepository_mt = Class(InvoiceRepository)

InvoiceRepository.SAVE_VERSION = 4

---Create repository instance
-- @return InvoiceRepository instance Repository for managing invoices
function InvoiceRepository.new()
    local self = setmetatable({}, InvoiceRepository_mt)

    self.invoices = {}
    self.nextInvoiceId = 1

    return self
end

---Clear all invoices and reset ID counter
function InvoiceRepository:clear()
    self.invoices = {}
    self.nextInvoiceId = 1
end

---Generate next unique invoice ID
-- @return integer id The generated ID
function InvoiceRepository:generateId()
    local id = self.nextInvoiceId
    self.nextInvoiceId = self.nextInvoiceId + 1
    return id
end

---Add invoice to repository
-- @param Invoice invoice The invoice to add
function InvoiceRepository:add(invoice)
    if invoice.id == 0 then
        invoice.id = self:generateId()
    end
    table.insert(self.invoices, invoice)
end

---Retrieve invoice by ID
-- @param integer id Invoice ID
-- @return Invoice|nil invoice The invoice or nil if not found
function InvoiceRepository:getById(id)
    for _, invoice in ipairs(self.invoices) do
        if invoice.id == id then
            return invoice
        end
    end
    return nil
end

---Remove invoice by ID
-- @param integer id Invoice ID
-- @return boolean success True if removed, false otherwise
function InvoiceRepository:removeById(id)
    for i, invoice in ipairs(self.invoices) do
        if invoice.id == id then
            table.remove(self.invoices, i)
            return true
        end
    end
    return false
end

---Update invoice state by ID
-- @param integer id Invoice ID
-- @param integer newState New state value
-- @return boolean success True if updated, false otherwise
function InvoiceRepository:setState(id, newState)
    local invoice = self:getById(id)
    if invoice then
        invoice.state = newState
        return true
    end
    return false
end

---Get invoices for a recipient farm
-- @param integer farmId Farm ID
-- @return table invoices Invoices where this farm is recipient
function InvoiceRepository:getByRecipientFarm(farmId)
    local result = {}
    for _, invoice in ipairs(self.invoices) do
        if invoice.recipientFarmId == farmId then
            table.insert(result, invoice)
        end
    end
    return result
end

---Get invoices for a sender farm
-- @param integer farmId Farm ID
-- @return table invoices Invoices where this farm is sender
function InvoiceRepository:getBySenderFarm(farmId)
    local result = {}
    for _, invoice in ipairs(self.invoices) do
        if invoice.senderFarmId == farmId then
            table.insert(result, invoice)
        end
    end
    return result
end

---Get all invoices
-- @return table invoices All invoices in repository
function InvoiceRepository:getAll()
    return self.invoices
end

---Get next invoice ID counter
-- @return integer id Next ID to be assigned
function InvoiceRepository:getNextInvoiceId()
    return self.nextInvoiceId
end

---Set next invoice ID counter
-- @param integer id ID to set
function InvoiceRepository:setNextInvoiceId(id)
    self.nextInvoiceId = id
end

---Replace all invoices and set ID counter
-- @param table invoices Array of invoices
-- @param integer nextId Next ID counter value
function InvoiceRepository:replaceAll(invoices, nextId)
    self.invoices = invoices
    self.nextInvoiceId = nextId
end

---Save invoices to XML file
-- @param string savegamePath Path to savegame directory
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

---Save invoices and settings to XML file
-- @param string savegamePath Path to savegame directory
-- @param table? settings Optional settings table
function InvoiceRepository:saveToXMLWithSettings(savegamePath, settings)
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

    local s = settings or {}
    setXMLBool(xmlFile, "invoices.settings#vatSimulated", s.invoiceVatSimulated ~= false)
    setXMLBool(xmlFile, "invoices.settings#reminders", s.invoiceReminders ~= false)
    setXMLBool(xmlFile, "invoices.settings#penalties", s.invoicePenalties ~= false)

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

---Load invoices from XML file
-- @param string savegamePath Path to savegame directory
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

---Saves settings to existing invoices XML file
-- @param string savegamePath Path to savegame directory
-- @param table settings Settings table to persist
-- @return boolean success True if saved
function InvoiceRepository:saveSettingsToXML(savegamePath, settings)
    local filePath = savegamePath .. "invoices.xml"
    local xmlFile = nil

    if fileExists(filePath) then
        xmlFile = loadXMLFile("invoices", filePath)
    else
        xmlFile = createXMLFile("invoices", filePath, "invoices")
    end

    if xmlFile == nil then
        Logging.warning("[Invoices] Failed to save settings to %s", filePath)
        return false
    end

    if getXMLInt(xmlFile, "invoices#version") == nil then
        setXMLInt(xmlFile, "invoices#version", InvoiceRepository.SAVE_VERSION)
    end
    if getXMLInt(xmlFile, "invoices#nextId") == nil then
        setXMLInt(xmlFile, "invoices#nextId", self.nextInvoiceId or 1)
    end

    local s = settings or {}
    setXMLBool(xmlFile, "invoices.settings#vatSimulated", s.invoiceVatSimulated ~= false)
    setXMLBool(xmlFile, "invoices.settings#reminders", s.invoiceReminders ~= false)
    setXMLBool(xmlFile, "invoices.settings#penalties", s.invoicePenalties ~= false)

    saveXMLFile(xmlFile)
    delete(xmlFile)
    return true
end

---Loads settings from invoices XML file
-- @param string savegamePath Path to savegame directory
-- @return table|nil settings Loaded settings or nil
function InvoiceRepository:loadSettingsFromXML(savegamePath)
    local filePath = savegamePath .. "invoices.xml"
    if not fileExists(filePath) then
        return nil
    end

    local xmlFile = loadXMLFile("invoices", filePath)
    if xmlFile == nil then
        Logging.warning("[Invoices] Failed to load settings from %s", filePath)
        return nil
    end

    local hasAny = hasXMLProperty(xmlFile, "invoices.settings#vatSimulated")
        or hasXMLProperty(xmlFile, "invoices.settings#reminders")
        or hasXMLProperty(xmlFile, "invoices.settings#penalties")

    if not hasAny then
        delete(xmlFile)
        return nil
    end

    local settings = {
        invoiceVatSimulated = getXMLBool(xmlFile, "invoices.settings#vatSimulated"),
        invoiceReminders = getXMLBool(xmlFile, "invoices.settings#reminders"),
        invoicePenalties = getXMLBool(xmlFile, "invoices.settings#penalties")
    }

    delete(xmlFile)
    return settings
end
