-- Copyright © 2026 Squallqt. All rights reserved.
-- Network event for pay/delete with server-authoritative money transfers.
InvoiceStateEvent = {}
local InvoiceStateEvent_mt = Class(InvoiceStateEvent, Event)

InitEventClass(InvoiceStateEvent, "InvoiceStateEvent")

InvoiceStateEvent.ACTION_PAY = 1
InvoiceStateEvent.ACTION_DELETE = 2

---Creates empty event instance
-- @return InvoiceStateEvent instance Empty event
function InvoiceStateEvent.emptyNew()
    local self = Event.new(InvoiceStateEvent_mt)
    return self
end

---Creates initialized invoice state event
-- @param integer invoiceId Invoice identifier
-- @param integer action Action to perform
-- @return InvoiceStateEvent instance The new event instance
function InvoiceStateEvent.new(invoiceId, action)
    local self = InvoiceStateEvent.emptyNew()
    self.invoiceId = invoiceId
    self.action = action
    return self
end

---Reads invoice state data from network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceStateEvent:readStream(streamId, connection)
    self.invoiceId = streamReadInt32(streamId)
    self.action = streamReadInt8(streamId)
    self:run(connection)
end

---Writes invoice state data to network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceStateEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.invoiceId)
    streamWriteInt8(streamId, self.action)
end

---Executes invoice state event
-- @param Connection connection Network connection
function InvoiceStateEvent:run(connection)
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        return
    end

    if self.action == InvoiceStateEvent.ACTION_PAY then
        if not connection:getIsServer() then
            local invoice = manager.repository:getById(self.invoiceId)
            if invoice == nil then
                Logging.warning("[InvoiceStateEvent] Server rejected PAY: invoice %d not found", self.invoiceId)
                return
            end
            if invoice.state == Invoice.STATE.PAID then
                Logging.warning("[InvoiceStateEvent] Server rejected PAY: invoice %d already paid", self.invoiceId)
                return
            end
            
            if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
                Logging.warning("[InvoiceStateEvent] Server rejected PAY: player lacks farmManager permission")
                return
            end
            
            local player = g_currentMission.connectionsToPlayer[connection]
            if player == nil or player.farmId ~= invoice.recipientFarmId then
                Logging.warning("[InvoiceStateEvent] Server rejected PAY: player farmId mismatch")
                return
            end
            
            local totalDue = invoice.totalAmount + (invoice.penaltyAmount or 0)
            local farm = g_farmManager:getFarmById(invoice.recipientFarmId)
            if farm == nil or math.floor(farm.money) < math.floor(totalDue) then
                Logging.warning("[InvoiceStateEvent] Server rejected PAY: insufficient balance (%.2f < %.2f)", farm and farm.money or 0, totalDue)
                return
            end
            
            manager.service:payInvoice(self.invoiceId, true)
            g_server:broadcastEvent(self)
        else
            manager.service:payInvoice(self.invoiceId, true)
        end
    elseif self.action == InvoiceStateEvent.ACTION_DELETE then
        if not connection:getIsServer() then
            local invoice = manager.repository:getById(self.invoiceId)
            if invoice == nil then
                Logging.warning("[InvoiceStateEvent] Server rejected DELETE: invoice %d not found", self.invoiceId)
                return
            end
            
            if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
                Logging.warning("[InvoiceStateEvent] Server rejected DELETE: player lacks farmManager permission")
                return
            end
            
            local player = g_currentMission.connectionsToPlayer[connection]
            if player == nil or (player.farmId ~= invoice.senderFarmId and player.farmId ~= invoice.recipientFarmId) then
                Logging.warning("[InvoiceStateEvent] Server rejected DELETE: player not in sender or recipient farm")
                return
            end
            
            manager.service:deleteInvoice(self.invoiceId, true)
            g_server:broadcastEvent(self)
        else
            manager.service:deleteInvoice(self.invoiceId, true)
        end
    end
end
