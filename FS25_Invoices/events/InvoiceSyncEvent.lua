--[[
    InvoiceSyncEvent.lua
    Late-join full sync. Sends all invoices to newly connected clients.
    Author: Squallqt
]]

InvoiceSyncEvent = {}
local InvoiceSyncEvent_mt = Class(InvoiceSyncEvent, Event)

InitEventClass(InvoiceSyncEvent, "InvoiceSyncEvent")

function InvoiceSyncEvent.emptyNew()
    local self = Event.new(InvoiceSyncEvent_mt)
    return self
end

function InvoiceSyncEvent.new()
    local self = InvoiceSyncEvent.emptyNew()
    return self
end

function InvoiceSyncEvent:readStream(streamId, connection)
    -- Must read ALL stream data even if manager nil (prevents stream corruption)
    local nextId = streamReadInt32(streamId)
    local invoices = {}

    local count = streamReadInt16(streamId)
    for _ = 1, count do
        local invoice = Invoice.new()
        invoice:readStream(streamId)
        table.insert(invoices, invoice)
    end

    local manager = g_currentMission.invoicesManager
    if manager ~= nil then
        manager.service:applySyncData(invoices, nextId)
        Logging.devInfo("[Invoices] InvoiceSyncEvent: synced %d invoices (nextId=%d)", count, nextId)
    else
        Logging.warning("[Invoices] InvoiceSyncEvent: manager not available, %d invoices discarded", count)
    end
end

function InvoiceSyncEvent:writeStream(streamId, connection)
    local manager = g_currentMission.invoicesManager
    if manager == nil then
        streamWriteInt32(streamId, 1)
        streamWriteInt16(streamId, 0)
        return
    end

    local invoices, nextId = manager.service:getSyncData()

    streamWriteInt32(streamId, nextId)
    streamWriteInt16(streamId, #invoices)

    for _, invoice in ipairs(invoices) do
        invoice:writeStream(streamId)
    end
end
