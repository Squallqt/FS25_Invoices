--[[
    InvoicePenaltySyncEvent.lua
    Network event: server broadcasts penalty amount updates to clients.
    Author: Squallqt
]]

InvoicePenaltySyncEvent = {}
local InvoicePenaltySyncEvent_mt = Class(InvoicePenaltySyncEvent, Event)

InitEventClass(InvoicePenaltySyncEvent, "InvoicePenaltySyncEvent")

function InvoicePenaltySyncEvent.emptyNew()
    return Event.new(InvoicePenaltySyncEvent_mt)
end

function InvoicePenaltySyncEvent.new(updates)
    local self = InvoicePenaltySyncEvent.emptyNew()
    self.updates = updates or {}
    return self
end

function InvoicePenaltySyncEvent:readStream(streamId, connection)
    local count = streamReadInt16(streamId)
    self.updates = {}
    for _ = 1, count do
        table.insert(self.updates, {
            id = streamReadInt32(streamId),
            penaltyAmount = streamReadInt32(streamId)
        })
    end
    self:run(connection)
end

function InvoicePenaltySyncEvent:writeStream(streamId, connection)
    streamWriteInt16(streamId, #self.updates)
    for _, upd in ipairs(self.updates) do
        streamWriteInt32(streamId, upd.id)
        streamWriteInt32(streamId, upd.penaltyAmount)
    end
end

function InvoicePenaltySyncEvent:run(connection)
    if not connection:getIsServer() then return end
    local manager = g_currentMission.invoicesManager
    if manager == nil then return end
    manager.service:applyPenaltySync(self.updates)
end
