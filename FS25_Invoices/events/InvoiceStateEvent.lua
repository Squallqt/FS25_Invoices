-- Copyright © 2026 Squallqt. All rights reserved.
---Network event for server-authoritative invoice actions
InvoiceStateEvent = {}
local InvoiceStateEvent_mt = Class(InvoiceStateEvent, Event)

InitEventClass(InvoiceStateEvent, "InvoiceStateEvent")

InvoiceStateEvent.ACTION_PAY = 1
InvoiceStateEvent.ACTION_DELETE = 2
InvoiceStateEvent.ACTION_VALIDATE = 3
InvoiceStateEvent.ACTION_REFUSE = 4

---Creates empty event instance
-- @return InvoiceStateEvent Empty event instance
function InvoiceStateEvent.emptyNew()
    local self = Event.new(InvoiceStateEvent_mt)
    return self
end

---Creates initialized invoice state event
-- @param integer invoiceId Invoice identifier
-- @param integer action Action to perform
-- @return InvoiceStateEvent New event instance
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
                return
            end
            if invoice.state == Invoice.STATE.PAID then
                return
            end
            if invoice.state == Invoice.STATE.PROPOSED then
                return
            end

            if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
                return
            end
            
            local player = g_currentMission.connectionsToPlayer[connection]
            if player == nil or player.farmId ~= invoice.recipientFarmId then
                return
            end
            
            local totalDue = invoice.totalAmount + (invoice.penaltyAmount or 0)
            local farm = g_farmManager:getFarmById(invoice.recipientFarmId)
            if farm == nil or math.floor(farm.money) < math.floor(totalDue) then
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
                return
            end
            
            if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
                return
            end
            
            local player = g_currentMission.connectionsToPlayer[connection]
            if player == nil then
                return
            end

            local canCancel = false
            if invoice.state == Invoice.STATE.PROPOSED then
                canCancel = player.farmId == invoice.recipientFarmId
            elseif invoice.state == Invoice.STATE.NEW then
                canCancel = player.farmId == invoice.senderFarmId
            end

            if not canCancel then
                return
            end
            
            manager.service:deleteInvoice(self.invoiceId, true)
            g_server:broadcastEvent(self)
        else
            manager.service:deleteInvoice(self.invoiceId, true)
        end
    elseif self.action == InvoiceStateEvent.ACTION_VALIDATE then
        if not connection:getIsServer() then
            local invoice = manager.repository:getById(self.invoiceId)
            if invoice == nil then
                return
            end
            if invoice.state ~= Invoice.STATE.PROPOSED then
                return
            end

            if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
                return
            end

            -- Only the issuer (sender) farm may validate a proposal.
            local player = g_currentMission.connectionsToPlayer[connection]
            if player == nil or player.farmId ~= invoice.senderFarmId then
                return
            end

            manager.service:validateProposal(self.invoiceId, true)
            g_server:broadcastEvent(self)
        else
            manager.service:validateProposal(self.invoiceId, true)
        end
    elseif self.action == InvoiceStateEvent.ACTION_REFUSE then
        if not connection:getIsServer() then
            local invoice = manager.repository:getById(self.invoiceId)
            if invoice == nil then
                return
            end
            if invoice.state ~= Invoice.STATE.PROPOSED then
                return
            end

            if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
                return
            end

            -- Only the issuer (sender) farm may refuse a proposal.
            local player = g_currentMission.connectionsToPlayer[connection]
            if player == nil or player.farmId ~= invoice.senderFarmId then
                return
            end

            manager.service:refuseProposal(self.invoiceId, true)
            g_server:broadcastEvent(self)
        else
            manager.service:refuseProposal(self.invoiceId, true)
        end
    end
end
