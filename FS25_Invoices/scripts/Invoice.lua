--[[
    Invoice.lua
    Author: Squallqt
]]

Invoice = {}
local Invoice_mt = Class(Invoice)

Invoice.STATE = {
    NEW       = 1,
    SENT      = 2,
    PAID      = 3,
    CANCELLED = 4
}

-- Savegame v1 compatibility aliases
Invoice.STATE_UNPAID = Invoice.STATE.NEW
Invoice.STATE_PAID   = Invoice.STATE.PAID

Invoice.UNIT_PIECE = 1
Invoice.UNIT_HOUR = 2
Invoice.UNIT_HECTARE = 3
Invoice.UNIT_LITER = 4

function Invoice.new(customMt)
    local self = setmetatable({}, customMt or Invoice_mt)
    
    self.id = 0
    self.senderFarmId = 0
    self.recipientFarmId = 0
    self.state = Invoice.STATE.NEW
    self.totalAmount = 0
    self.lineItems = {}
    self.createdAt = {
        day = 0,
        hour = 0,
        minute = 0,
        period = 0,
        year = 0
    }
    
    return self
end

function Invoice:populateFromData(id, items, recipientFarmId, senderFarmId)
    self.id = id
    self.senderFarmId = senderFarmId
    self.recipientFarmId = recipientFarmId
    self.lineItems = items
    
    self.totalAmount = 0
    for _, item in pairs(items) do
        self.totalAmount = self.totalAmount + (item.amount or 0)
    end
    
    if g_currentMission and g_currentMission.environment then
        local env = g_currentMission.environment
        local monotonicDay = env.currentMonotonicDay or 0
        local dayInPeriod = 0
        if env.getDayInPeriodFromDay then
            dayInPeriod = env:getDayInPeriodFromDay(monotonicDay)
        end

        -- Convert agricultural period to calendar month
        local period = env.currentPeriod or 0
        local currentMonth = period + 2
        if currentMonth > 12 then
            currentMonth = currentMonth - 12
        end

        -- Convert agricultural year to calendar year
        local currentYear = env.currentYear or 1
        if currentMonth < 3 then
            currentYear = currentYear + 1
        end

        self.createdAt = {
            day = dayInPeriod,
            hour = env.currentHour or 0,
            minute = env.currentMinute or 0,
            period = currentMonth,
            year = currentYear
        }
    end
end

function Invoice:writeToXML(xmlFile, key)
    setXMLInt(xmlFile, key .. "#id", self.id)
    setXMLInt(xmlFile, key .. "#senderFarmId", self.senderFarmId)
    setXMLInt(xmlFile, key .. "#recipientFarmId", self.recipientFarmId)
    setXMLInt(xmlFile, key .. "#state", self.state)
    setXMLInt(xmlFile, key .. ".createdAt#day", self.createdAt.day)
    setXMLInt(xmlFile, key .. ".createdAt#hour", self.createdAt.hour)
    setXMLInt(xmlFile, key .. ".createdAt#minute", self.createdAt.minute)
    setXMLInt(xmlFile, key .. ".createdAt#period", self.createdAt.period or 0)
    setXMLInt(xmlFile, key .. ".createdAt#year", self.createdAt.year or 0)
    
    for i, item in ipairs(self.lineItems) do
        local itemKey = string.format("%s.lineItems.item(%d)", key, i - 1)
        setXMLInt(xmlFile, itemKey .. "#workTypeId", item.workTypeId or 0)
        setXMLFloat(xmlFile, itemKey .. "#amount", item.amount or 0)
        setXMLFloat(xmlFile, itemKey .. "#quantity", item.quantity or 0)
        setXMLInt(xmlFile, itemKey .. "#unitType", item.unitType or Invoice.UNIT_PIECE)
        setXMLInt(xmlFile, itemKey .. "#fieldId", item.fieldId or 0)
        setXMLFloat(xmlFile, itemKey .. "#fieldArea", item.fieldArea or 0)
        setXMLString(xmlFile, itemKey .. "#note", item.note or "")
    end
end

function Invoice:readFromXML(xmlFile, key)
    self.id = getXMLInt(xmlFile, key .. "#id") or 0
    self.senderFarmId = getXMLInt(xmlFile, key .. "#senderFarmId") or 0
    self.recipientFarmId = getXMLInt(xmlFile, key .. "#recipientFarmId") or 0
    self.state = getXMLInt(xmlFile, key .. "#state") or Invoice.STATE.NEW

    -- Validate state bounds
    if self.state < Invoice.STATE.NEW or self.state > Invoice.STATE.CANCELLED then
        Logging.warning("[Invoices] Invalid state %d for invoice %d, defaulting to NEW", self.state, self.id)
        self.state = Invoice.STATE.NEW
    end

    self.createdAt = {
        day = getXMLInt(xmlFile, key .. ".createdAt#day") or 0,
        hour = getXMLInt(xmlFile, key .. ".createdAt#hour") or 0,
        minute = getXMLInt(xmlFile, key .. ".createdAt#minute") or 0,
        period = getXMLInt(xmlFile, key .. ".createdAt#period") or 0,
        year = getXMLInt(xmlFile, key .. ".createdAt#year") or 0
    }
    
    self.lineItems = {}
    self.totalAmount = 0
    
    local i = 0
    while true do
        local itemKey = string.format("%s.lineItems.item(%d)", key, i)
        if not hasXMLProperty(xmlFile, itemKey) then
            break
        end
        
        local amount = getXMLFloat(xmlFile, itemKey .. "#amount") or 0
        local item = {
            workTypeId = getXMLInt(xmlFile, itemKey .. "#workTypeId") or 0,
            amount = amount,
            quantity = getXMLFloat(xmlFile, itemKey .. "#quantity") or 0,
            unitType = getXMLInt(xmlFile, itemKey .. "#unitType") or Invoice.UNIT_PIECE,
            fieldId = getXMLInt(xmlFile, itemKey .. "#fieldId") or 0,
            fieldArea = getXMLFloat(xmlFile, itemKey .. "#fieldArea") or 0,
            note = getXMLString(xmlFile, itemKey .. "#note") or ""
        }
        
        table.insert(self.lineItems, item)
        self.totalAmount = self.totalAmount + amount
        i = i + 1
    end
end

function Invoice:writeStream(streamId)
    streamWriteInt32(streamId, self.id)
    streamWriteInt32(streamId, self.senderFarmId)
    streamWriteInt32(streamId, self.recipientFarmId)
    streamWriteInt8(streamId, self.state)
    streamWriteInt8(streamId, self.createdAt.day)
    streamWriteInt8(streamId, self.createdAt.hour)
    streamWriteInt8(streamId, self.createdAt.minute)
    streamWriteInt8(streamId, self.createdAt.period or 0)
    streamWriteInt16(streamId, self.createdAt.year or 0)
    
    streamWriteInt16(streamId, #self.lineItems)
    for _, item in ipairs(self.lineItems) do
        streamWriteInt16(streamId, item.workTypeId or 0)
        streamWriteFloat32(streamId, item.amount or 0)
        streamWriteFloat32(streamId, item.quantity or 0)
        streamWriteInt8(streamId, item.unitType or Invoice.UNIT_PIECE)
        streamWriteInt16(streamId, item.fieldId or 0)
        streamWriteFloat32(streamId, item.fieldArea or 0)
        streamWriteString(streamId, item.note or "")
    end
end

function Invoice:readStream(streamId)
    self.id = streamReadInt32(streamId)
    self.senderFarmId = streamReadInt32(streamId)
    self.recipientFarmId = streamReadInt32(streamId)
    self.state = streamReadInt8(streamId)
    
    self.createdAt = {
        day = streamReadInt8(streamId),
        hour = streamReadInt8(streamId),
        minute = streamReadInt8(streamId),
        period = streamReadInt8(streamId),
        year = streamReadInt16(streamId)
    }
    
    self.lineItems = {}
    self.totalAmount = 0
    
    local count = streamReadInt16(streamId)
    for _ = 1, count do
        local workTypeId = streamReadInt16(streamId)
        local amount = streamReadFloat32(streamId)
        local item = {
            workTypeId = workTypeId,
            amount = amount,
            quantity = streamReadFloat32(streamId),
            unitType = streamReadInt8(streamId),
            fieldId = streamReadInt16(streamId),
            fieldArea = streamReadFloat32(streamId),
            note = streamReadString(streamId)
        }
        
        table.insert(self.lineItems, item)
        self.totalAmount = self.totalAmount + amount
    end
end
