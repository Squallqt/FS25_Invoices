-- Copyright © 2026 Squallqt. All rights reserved.
-- Network event: server broadcasts penalty amount updates to clients.
InvoicePenaltySyncEvent = {}
local InvoicePenaltySyncEvent_mt = Class(InvoicePenaltySyncEvent, Event)

InitEventClass(InvoicePenaltySyncEvent, "InvoicePenaltySyncEvent")

---Creates empty event instance
-- @return InvoicePenaltySyncEvent instance Empty event
function InvoicePenaltySyncEvent.emptyNew()
    return Event.new(InvoicePenaltySyncEvent_mt)
end

---Creates initialized penalty sync event
-- @param table updates Array of penalty update records
-- @return InvoicePenaltySyncEvent instance The new event instance
function InvoicePenaltySyncEvent.new(updates)
    local self = InvoicePenaltySyncEvent.emptyNew()
    self.updates = updates or {}
    return self
end

---Reads penalty updates from network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
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

---Writes penalty updates to network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoicePenaltySyncEvent:writeStream(streamId, connection)
    streamWriteInt16(streamId, #self.updates)
    for _, upd in ipairs(self.updates) do
        streamWriteInt32(streamId, upd.id)
        streamWriteInt32(streamId, upd.penaltyAmount)
    end
end

---Executes penalty sync event
-- @param Connection connection Network connection
function InvoicePenaltySyncEvent:run(connection)
    if not connection:getIsServer() then return end
    local manager = g_currentMission.invoicesManager
    if manager == nil then return end
    manager.service:applyPenaltySync(self.updates)
end
