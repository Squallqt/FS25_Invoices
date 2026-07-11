-- Copyright © 2026 Squallqt. All rights reserved.
-- Network event for invoice creation with server-authoritative ID assignment.
InvoiceCreateEvent = {}
local InvoiceCreateEvent_mt = Class(InvoiceCreateEvent, Event)

InitEventClass(InvoiceCreateEvent, "InvoiceCreateEvent")

---Creates empty event instance
-- @return InvoiceCreateEvent instance Empty event
function InvoiceCreateEvent.emptyNew()
    local self = Event.new(InvoiceCreateEvent_mt)
    return self
end

---Creates initialized invoice create event
-- @param Invoice invoice The invoice to create
-- @return InvoiceCreateEvent instance The new event instance
function InvoiceCreateEvent.new(invoice)
    local self = InvoiceCreateEvent.emptyNew()
    self.invoice = invoice
    return self
end

---Reads invoice data from network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceCreateEvent:readStream(streamId, connection)
    self.invoice = Invoice.new()
    self.invoice:readStream(streamId)
    self:run(connection)
end

---Writes invoice data to network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceCreateEvent:writeStream(streamId, connection)
    self.invoice:writeStream(streamId)
end

---Executes invoice creation event
-- @param Connection connection Network connection
function InvoiceCreateEvent:run(connection)
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return
    end

    if not connection:getIsServer() then
        local invoice = self.invoice
        if invoice.senderFarmId == nil or invoice.senderFarmId < 1 then
            return
        end
        if invoice.recipientFarmId == nil or invoice.recipientFarmId < 1 then
            return
        end
        if invoice.senderFarmId == invoice.recipientFarmId then
            return
        end

        -- Only NEW (normal invoice) or PROPOSED (proposal) may be created.
        local isProposal = (invoice.state == Invoice.STATE.PROPOSED)
        if invoice.state ~= Invoice.STATE.NEW and not isProposal then
            return
        end

        if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
            return
        end

        -- Normal invoice: the issuer (sender) creates it. Proposal: the payer (recipient) creates it.
        local requiredFarmId = isProposal and invoice.recipientFarmId or invoice.senderFarmId
        local player = g_currentMission.connectionsToPlayer[connection]
        if player == nil or player.farmId ~= requiredFarmId then
            return
        end

        -- Sanitize line items
        local items = invoice.lineItems or {}
        if #items > 100 then
            return
        end
        for _, item in ipairs(items) do
            if (item.amount or 0) < 0 or (item.price or 0) < 0 then
                return
            end
            -- Server-authoritative discount: clamp to [0,1] and rebuild the line
            -- amount from price/quantity/discount so the client cannot forge the total.
            item.discountRate = Invoice.sanitizeDiscountRate(item.discountRate)
            item.amount = Invoice.computeLineAmount(item.price, item.quantity, item.unitType, item.discountRate)
        end

        -- Server-authoritative recalculation of totals
        local total, totalHT, totalVAT = Invoice.computeTotals(invoice.lineItems or {})
        invoice.totalAmount = total
        invoice.totalHT = totalHT
        invoice.vatAmount = totalVAT
        
        invoice.id = 0
        if manager.service:createAndSendInvoice(invoice, true) then
            g_server:broadcastEvent(InvoiceCreateEvent.new(invoice))
        end
    else
        manager.service:createAndSendInvoice(self.invoice, true)
    end
end
