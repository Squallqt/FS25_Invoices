--[[
    InvoiceVehicleTransferEvent.lua
    Network event for vehicle ownership transfer upon invoice payment.
    Author: Squallqt
]]

InvoiceVehicleTransferEvent = {}
local InvoiceVehicleTransferEvent_mt = Class(InvoiceVehicleTransferEvent, Event)

InitEventClass(InvoiceVehicleTransferEvent, "InvoiceVehicleTransferEvent")

function InvoiceVehicleTransferEvent.emptyNew()
    local self = Event.new(InvoiceVehicleTransferEvent_mt)
    return self
end

function InvoiceVehicleTransferEvent.new(vehicleUniqueId, senderFarmId, recipientFarmId)
    local self = InvoiceVehicleTransferEvent.emptyNew()
    self.vehicleUniqueId = vehicleUniqueId
    self.senderFarmId    = senderFarmId
    self.recipientFarmId = recipientFarmId
    return self
end

function InvoiceVehicleTransferEvent:readStream(streamId, connection)
    self.vehicleUniqueId = streamReadString(streamId)
    self.senderFarmId    = streamReadInt32(streamId)
    self.recipientFarmId = streamReadInt32(streamId)
    self:run(connection)
end

function InvoiceVehicleTransferEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.vehicleUniqueId or "")
    streamWriteInt32(streamId, self.senderFarmId or 0)
    streamWriteInt32(streamId, self.recipientFarmId or 0)
end

function InvoiceVehicleTransferEvent:run(connection)
    if not connection:getIsServer() then
        local player = g_currentMission.connectionsToPlayer[connection]
        if player == nil or player.farmId ~= self.senderFarmId then
            Logging.warning("[InvoiceVehicleTransferEvent] Server rejected: connection farmId mismatch (claimed=%d)", self.senderFarmId or -1)
            return
        end

        if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
            Logging.warning("[InvoiceVehicleTransferEvent] Server rejected: player lacks farmManager permission")
            return
        end

        local vehicle = g_currentMission.vehicleSystem:getVehicleByUniqueId(self.vehicleUniqueId)
        if vehicle == nil then
            Logging.warning("[InvoiceVehicleTransferEvent] Server rejected: vehicle not found (uid=%s)", self.vehicleUniqueId)
            return
        end

        local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
        if ownerFarmId ~= self.senderFarmId then
            Logging.warning("[InvoiceVehicleTransferEvent] Server rejected: vehicle not owned by sender farm %d", self.senderFarmId)
            return
        end

        vehicle:setOwnerFarmId(self.recipientFarmId, true)

        g_server:broadcastEvent(InvoiceVehicleTransferEvent.new(self.vehicleUniqueId, self.senderFarmId, self.recipientFarmId))
    else
        local vehicle = g_currentMission.vehicleSystem:getVehicleByUniqueId(self.vehicleUniqueId)
        if vehicle ~= nil then
            vehicle:setOwnerFarmId(self.recipientFarmId, true)
        end
    end
end
