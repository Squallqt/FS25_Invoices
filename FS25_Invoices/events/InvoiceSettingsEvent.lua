-- Copyright © 2026 Squallqt. All rights reserved.
-- Network event propagating VAT, reminder, and penalty flag changes from client to server and broadcast.
InvoiceSettingsEvent = {}
local InvoiceSettingsEvent_mt = Class(InvoiceSettingsEvent, Event)

InitEventClass(InvoiceSettingsEvent, "InvoiceSettingsEvent")

---Creates empty event instance
-- @return InvoiceSettingsEvent instance Empty event
function InvoiceSettingsEvent.emptyNew()
    local self = Event.new(InvoiceSettingsEvent_mt)
    return self
end

---Creates initialized settings event
-- @param table settings Settings configuration table
-- @return InvoiceSettingsEvent instance The new event instance
function InvoiceSettingsEvent.new(settings)
    local self = InvoiceSettingsEvent.emptyNew()
    self.settings = settings or {}
    return self
end

---Reads settings data from network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceSettingsEvent:readStream(streamId, connection)
    self.settings = {}
    self.settings.invoiceVatSimulated = streamReadBool(streamId)
    self.settings.invoiceReminders = streamReadBool(streamId)
    self.settings.invoicePenalties = streamReadBool(streamId)
    self:run(connection)
end

---Writes settings data to network stream
-- @param integer streamId Network stream identifier
-- @param Connection connection Network connection
function InvoiceSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.settings.invoiceVatSimulated ~= false)
    streamWriteBool(streamId, self.settings.invoiceReminders ~= false)
    streamWriteBool(streamId, self.settings.invoicePenalties ~= false)
end

---Executes settings event
-- @param Connection connection Network connection
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
