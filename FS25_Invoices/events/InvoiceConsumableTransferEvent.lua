-- Copyright © 2026 Squallqt. All rights reserved.
-- Network event: broadcasts consumable ownership transfer to clients.
-- Business logic lives in InvoicesConsumablePipeline.transferByCriteria().
InvoiceConsumableTransferEvent = {}
local InvoiceConsumableTransferEvent_mt = Class(InvoiceConsumableTransferEvent, Event)

InitEventClass(InvoiceConsumableTransferEvent, "InvoiceConsumableTransferEvent")

---Creates empty event instance
-- @return InvoiceConsumableTransferEvent instance Empty event
function InvoiceConsumableTransferEvent.emptyNew()
    local self = Event.new(InvoiceConsumableTransferEvent_mt)
    return self
end

---Creates initialized consumable transfer event
-- @param string xmlFilename Consumable XML definition file
-- @param integer fillTypeIndex Fill type index
-- @param integer quantity Quantity to transfer
-- @param integer senderFarmId Sender farm identifier
-- @param integer recipientFarmId Recipient farm identifier
-- @return InvoiceConsumableTransferEvent instance The new event instance
function InvoiceConsumableTransferEvent.new(xmlFilename, fillTypeIndex, quantity, senderFarmId, recipientFarmId)
    local self = InvoiceConsumableTransferEvent.emptyNew()
    self.xmlFilename     = xmlFilename
    self.fillTypeIndex   = fillTypeIndex
    self.quantity        = quantity
    self.senderFarmId    = senderFarmId
    self.recipientFarmId = recipientFarmId
    return self
end

---Reads consumable transfer data from network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceConsumableTransferEvent:readStream(streamId, connection)
    self.xmlFilename     = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId))
    self.fillTypeIndex   = streamReadInt16(streamId)
    self.quantity        = streamReadInt16(streamId)
    self.senderFarmId    = streamReadInt32(streamId)
    self.recipientFarmId = streamReadInt32(streamId)
    self:run(connection)
end

---Writes consumable transfer data to network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceConsumableTransferEvent:writeStream(streamId, connection)
    streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(self.xmlFilename or ""))
    streamWriteInt16(streamId, self.fillTypeIndex or 0)
    streamWriteInt16(streamId, self.quantity or 0)
    streamWriteInt32(streamId, self.senderFarmId or 0)
    streamWriteInt32(streamId, self.recipientFarmId or 0)
end

---Executes consumable transfer event
-- @param Connection connection Network connection
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
