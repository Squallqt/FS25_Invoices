--[[
    InvoiceConsumableTransferEvent.lua
    Network event: broadcasts consumable ownership transfer to clients.
    Business logic lives in InvoicesConsumablePipeline.transferByCriteria().
    Author: Squallqt
]]

InvoiceConsumableTransferEvent = {}
local InvoiceConsumableTransferEvent_mt = Class(InvoiceConsumableTransferEvent, Event)

InitEventClass(InvoiceConsumableTransferEvent, "InvoiceConsumableTransferEvent")

function InvoiceConsumableTransferEvent.emptyNew()
    local self = Event.new(InvoiceConsumableTransferEvent_mt)
    return self
end

function InvoiceConsumableTransferEvent.new(xmlFilename, fillTypeIndex, quantity, senderFarmId, recipientFarmId)
    local self = InvoiceConsumableTransferEvent.emptyNew()
    self.xmlFilename     = xmlFilename
    self.fillTypeIndex   = fillTypeIndex
    self.quantity        = quantity
    self.senderFarmId    = senderFarmId
    self.recipientFarmId = recipientFarmId
    return self
end

function InvoiceConsumableTransferEvent:readStream(streamId, connection)
    self.xmlFilename     = streamReadString(streamId)
    self.fillTypeIndex   = streamReadInt16(streamId)
    self.quantity        = streamReadInt16(streamId)
    self.senderFarmId    = streamReadInt32(streamId)
    self.recipientFarmId = streamReadInt32(streamId)
    self:run(connection)
end

function InvoiceConsumableTransferEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.xmlFilename or "")
    streamWriteInt16(streamId, self.fillTypeIndex or 0)
    streamWriteInt16(streamId, self.quantity or 0)
    streamWriteInt32(streamId, self.senderFarmId or 0)
    streamWriteInt32(streamId, self.recipientFarmId or 0)
end

function InvoiceConsumableTransferEvent:run(connection)
    if not connection:getIsServer() then
        if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
            Logging.warning("[InvoiceConsumableTransferEvent] Server rejected: player lacks farmManager permission")
            return
        end

        local player = g_currentMission.connectionsToPlayer[connection]
        if player == nil or player.farmId ~= self.senderFarmId then
            Logging.warning("[InvoiceConsumableTransferEvent] Server rejected: connection farmId mismatch")
            return
        end

        InvoicesConsumablePipeline.transferByCriteria(
            self.xmlFilename, self.fillTypeIndex,
            self.quantity, self.senderFarmId, self.recipientFarmId
        )

        g_server:broadcastEvent(InvoiceConsumableTransferEvent.new(
            self.xmlFilename, self.fillTypeIndex,
            self.quantity, self.senderFarmId, self.recipientFarmId
        ))
    else
        InvoicesConsumablePipeline.transferByCriteria(
            self.xmlFilename, self.fillTypeIndex,
            self.quantity, self.senderFarmId, self.recipientFarmId
        )
    end
end
