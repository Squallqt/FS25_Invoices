--[[
    InvoiceCreateEvent.lua
    Network event for invoice creation with server-authoritative ID assignment.
    Author: Squallqt
]]

InvoiceCreateEvent = {}
local InvoiceCreateEvent_mt = Class(InvoiceCreateEvent, Event)

InitEventClass(InvoiceCreateEvent, "InvoiceCreateEvent")

function InvoiceCreateEvent.emptyNew()
    local self = Event.new(InvoiceCreateEvent_mt)
    return self
end

function InvoiceCreateEvent.new(invoice)
    local self = InvoiceCreateEvent.emptyNew()
    self.invoice = invoice
    return self
end

function InvoiceCreateEvent:readStream(streamId, connection)
    self.invoice = Invoice.new()
    self.invoice:readStream(streamId)
    self:run(connection)
end

function InvoiceCreateEvent:writeStream(streamId, connection)
    self.invoice:writeStream(streamId)
end

function InvoiceCreateEvent:run(connection)
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return
    end

    if not connection:getIsServer() then
        local invoice = self.invoice
        if invoice.senderFarmId == nil or invoice.senderFarmId < 1 then
            Logging.warning("[InvoiceCreateEvent] Server rejected CREATE: invalid senderFarmId")
            return
        end
        if invoice.recipientFarmId == nil or invoice.recipientFarmId < 1 then
            Logging.warning("[InvoiceCreateEvent] Server rejected CREATE: invalid recipientFarmId")
            return
        end
        if invoice.senderFarmId == invoice.recipientFarmId then
            Logging.warning("[InvoiceCreateEvent] Server rejected CREATE: sender == recipient")
            return
        end
        
        if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
            Logging.warning("[InvoiceCreateEvent] Server rejected CREATE: player lacks farmManager permission")
            return
        end
        
        local player = g_currentMission.connectionsToPlayer[connection]
        if player == nil or player.farmId ~= invoice.senderFarmId then
            Logging.warning("[InvoiceCreateEvent] Server rejected CREATE: player farmId mismatch")
            return
        end
        
        -- Sanitize line items
        local items = invoice.lineItems or {}
        if #items > 100 then
            Logging.warning("[InvoiceCreateEvent] Server rejected CREATE: too many line items (%d)", #items)
            return
        end
        for _, item in ipairs(items) do
            if (item.amount or 0) < 0 or (item.price or 0) < 0 then
                Logging.warning("[InvoiceCreateEvent] Server rejected CREATE: negative amount/price")
                return
            end
        end
        
        -- Server-authoritative recalculation of totals
        local total = 0
        local totalHT = 0
        local totalVAT = 0
        for _, item in ipairs(invoice.lineItems or {}) do
            local lineAmount = item.amount or 0
            local lineVatRate = item.vatRate or 0
            local lineVAT = 0
            if lineVatRate > 0 then
                lineVAT = math.floor(lineAmount * lineVatRate / (1 + lineVatRate) + 0.5)
            end
            total = total + lineAmount
            totalHT = totalHT + (lineAmount - lineVAT)
            totalVAT = totalVAT + lineVAT
        end
        invoice.totalAmount = total
        invoice.totalHT = totalHT
        invoice.vatAmount = totalVAT
        
        manager.service:createAndSendInvoice(self.invoice, true)
        g_server:broadcastEvent(self, nil, connection)
    else
        manager.service:createAndSendInvoice(self.invoice, true)
    end
end
