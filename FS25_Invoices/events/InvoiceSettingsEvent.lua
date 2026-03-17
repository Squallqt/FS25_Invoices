--[[
    InvoiceSettingsEvent.lua
    Network event for settings synchronization.
    Author: Squallqt
]]

InvoiceSettingsEvent = {}
local InvoiceSettingsEvent_mt = Class(InvoiceSettingsEvent, Event)

InitEventClass(InvoiceSettingsEvent, "InvoiceSettingsEvent")

function InvoiceSettingsEvent.emptyNew()
    local self = Event.new(InvoiceSettingsEvent_mt)
    return self
end

function InvoiceSettingsEvent.new(settings)
    local self = InvoiceSettingsEvent.emptyNew()
    self.settings = settings or {}
    return self
end

function InvoiceSettingsEvent:readStream(streamId, connection)
    self.settings = {}
    self.settings.invoiceVatSimulated = streamReadBool(streamId)
    self.settings.invoiceReminders = streamReadBool(streamId)
    self:run(connection)
end

function InvoiceSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.settings.invoiceVatSimulated ~= false)
    streamWriteBool(streamId, self.settings.invoiceReminders ~= false)
end

function InvoiceSettingsEvent:run(connection)
    if not connection:getIsServer() then
        if not g_currentMission:getHasPlayerPermission("farmManager", connection) then
            Logging.warning("[InvoiceSettingsEvent] Server rejected: player lacks farmManager permission")
            return
        end

        InvoiceSettings:applySettings(self.settings, true)
    else
        InvoiceSettings:applySettings(self.settings, false)
    end
end
