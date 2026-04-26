-- Copyright © 2026 Squallqt. All rights reserved.
-- Domain model: invoice state, line items, VAT totals, XML/stream serialization, and savegame retrocompat.
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

---Create invoice instance
-- @param table? customMt Optional custom metatable
-- @return Invoice instance The created invoice
function Invoice.new(customMt)
    local self = setmetatable({}, customMt or Invoice_mt)
    
    self.id = 0
    self.senderFarmId = 0
    self.recipientFarmId = 0
    self.state = Invoice.STATE.NEW
    self.totalAmount = 0
    self.vatAmount = 0
    self.totalHT = 0
    self.lineItems = {}
    self.createdAt = {
        day = 0,
        hour = 0,
        minute = 0,
        period = 0,
        year = 0
    }
    self.createdDay = 0
    self.penaltyAmount = 0

    return self
end

---Populate invoice from data with calculated totals
-- @param integer id Invoice ID
-- @param table items Line items array
-- @param integer recipientFarmId Recipient farm ID
-- @param integer senderFarmId Sender farm ID
function Invoice:populateFromData(id, items, recipientFarmId, senderFarmId)
    self.id = id
    self.senderFarmId = senderFarmId
    self.recipientFarmId = recipientFarmId
    self.lineItems = items
    
    self.totalAmount = 0
    self.vatAmount = 0
    self.totalHT = 0
    for _, item in pairs(items) do
        local lineAmount = item.amount or 0
        local lineVatRate = item.vatRate or 0
        local lineVAT = 0
        if lineVatRate > 0 then
            lineVAT = math.floor(lineAmount * lineVatRate / (1 + lineVatRate) + 0.5)
        end
        local lineHT = lineAmount - lineVAT
        self.totalAmount = self.totalAmount + lineAmount
        self.vatAmount = self.vatAmount + lineVAT
        self.totalHT = self.totalHT + lineHT
    end
    
    if g_currentMission and g_currentMission.environment then
        local env = g_currentMission.environment
        local currentDay = env.currentDay or 0
        local dayInPeriod = 0
        if env.getDayInPeriodFromDay then
            dayInPeriod = env:getDayInPeriodFromDay(currentDay)
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
        self.createdDay = env.currentDay or 0
    end
end

---Serialize invoice data to XML file
-- @param integer xmlFile XML file handle
-- @param string key XML key path
function Invoice:writeToXML(xmlFile, key)
    setXMLInt(xmlFile, key .. "#id", self.id)
    setXMLInt(xmlFile, key .. "#senderFarmId", self.senderFarmId)
    setXMLInt(xmlFile, key .. "#recipientFarmId", self.recipientFarmId)
    setXMLInt(xmlFile, key .. "#state", self.state)
    setXMLInt(xmlFile, key .. "#vatAmount", self.vatAmount or 0)
    setXMLInt(xmlFile, key .. "#totalHT", self.totalHT or 0)
    setXMLInt(xmlFile, key .. ".createdAt#day", self.createdAt.day)
    setXMLInt(xmlFile, key .. ".createdAt#hour", self.createdAt.hour)
    setXMLInt(xmlFile, key .. ".createdAt#minute", self.createdAt.minute)
    setXMLInt(xmlFile, key .. ".createdAt#period", self.createdAt.period or 0)
    setXMLInt(xmlFile, key .. ".createdAt#year", self.createdAt.year or 0)
    setXMLInt(xmlFile, key .. "#createdDay", self.createdDay or 0)
    setXMLInt(xmlFile, key .. "#penaltyAmount", self.penaltyAmount or 0)
    
    for i, item in ipairs(self.lineItems) do
        local itemKey = string.format("%s.lineItems.item(%d)", key, i - 1)
        setXMLInt(xmlFile, itemKey .. "#workTypeId", item.workTypeId or 0)
        setXMLFloat(xmlFile, itemKey .. "#amount", item.amount or 0)
        setXMLFloat(xmlFile, itemKey .. "#quantity", item.quantity or 0)
        setXMLInt(xmlFile, itemKey .. "#unitType", item.unitType or Invoice.UNIT_PIECE)
        setXMLInt(xmlFile, itemKey .. "#fieldId", item.fieldId or 0)
        setXMLFloat(xmlFile, itemKey .. "#fieldArea", item.fieldArea or 0)
        setXMLString(xmlFile, itemKey .. "#note", item.note or "")
        setXMLFloat(xmlFile, itemKey .. "#vatRate", item.vatRate or 0)
        setXMLString(xmlFile, itemKey .. "#name", item.name or "")
        setXMLString(xmlFile, itemKey .. "#iconFilename", item.iconFilename or "")
        setXMLFloat(xmlFile, itemKey .. "#price", item.price or 0)
        setXMLString(xmlFile, itemKey .. "#vehicleUniqueId", item.vehicleUniqueId or "")
        local xmlFn = item.consumableXmlFilename or ""
        if xmlFn ~= "" then
            xmlFn = NetworkUtil.convertToNetworkFilename(xmlFn)
        end
        setXMLString(xmlFile, itemKey .. "#consumableXmlFilename", xmlFn)
        setXMLInt(xmlFile, itemKey .. "#consumableFillTypeIndex", item.consumableFillTypeIndex or 0)
        setXMLFloat(xmlFile, itemKey .. "#consumableFillLevel", item.consumableFillLevel or 0)
    end
end

---Deserialize invoice from XML file
-- @param XMLFile xmlFile XML file handle
-- @param string key XML key path
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
    
    self.vatAmount = getXMLInt(xmlFile, key .. "#vatAmount") or 0
    self.totalHT = getXMLInt(xmlFile, key .. "#totalHT") or 0

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
            note = getXMLString(xmlFile, itemKey .. "#note") or "",
            vatRate = getXMLFloat(xmlFile, itemKey .. "#vatRate") or 0,
            name = getXMLString(xmlFile, itemKey .. "#name") or "",
            iconFilename = getXMLString(xmlFile, itemKey .. "#iconFilename") or "",
            price = getXMLFloat(xmlFile, itemKey .. "#price") or 0,
            vehicleUniqueId = getXMLString(xmlFile, itemKey .. "#vehicleUniqueId") or "",
            consumableFillTypeIndex = getXMLInt(xmlFile, itemKey .. "#consumableFillTypeIndex") or 0,
            consumableFillLevel = getXMLFloat(xmlFile, itemKey .. "#consumableFillLevel") or 0
        }

        local rawXmlFn = getXMLString(xmlFile, itemKey .. "#consumableXmlFilename") or ""
        if rawXmlFn ~= "" then
            item.consumableXmlFilename = NetworkUtil.convertFromNetworkFilename(rawXmlFn)
        else
            item.consumableXmlFilename = ""
        end

        table.insert(self.lineItems, item)
        self.totalAmount = self.totalAmount + amount
        i = i + 1
    end

    self.createdDay = getXMLInt(xmlFile, key .. "#createdDay") or 0
    self.penaltyAmount = getXMLInt(xmlFile, key .. "#penaltyAmount") or 0

    -- Retrocompat v2: recalculate totalHT if missing
    if self.totalHT == 0 and self.totalAmount > 0 then
        self.totalHT = self.totalAmount
    end

    -- Retrocompat v3: estimate createdDay from createdAt for pre-penalty saves
    if self.createdDay == 0 and self.createdAt.year > 0 and self.createdAt.period > 0 then
        if g_currentMission and g_currentMission.environment then
            local env = g_currentMission.environment
            local daysPerPeriod = env.plannedDaysPerPeriod or 1

            -- Convert calendar month back to agricultural period
            local calMonth = self.createdAt.period
            local agPeriod = calMonth - 2
            if agPeriod <= 0 then
                agPeriod = agPeriod + 12
            end

            -- Convert calendar year back to agricultural year
            local agYear = self.createdAt.year
            if calMonth < 3 then
                agYear = agYear - 1
            end

            -- Estimate monotonic day from year/period/dayInPeriod
            local yearDiff = agYear - 1
            local estimatedDay = (yearDiff * 12 * daysPerPeriod) + ((agPeriod - 1) * daysPerPeriod) + (self.createdAt.day or 1)

            if estimatedDay > 0 then
                self.createdDay = estimatedDay
            end
        end
    end
end

---Serialize invoice data to network stream
-- @param integer streamId Network stream identifier
function Invoice:writeStream(streamId)
    streamWriteInt32(streamId, self.id)
    streamWriteInt32(streamId, self.senderFarmId)
    streamWriteInt32(streamId, self.recipientFarmId)
    streamWriteInt8(streamId, self.state)
    streamWriteInt32(streamId, self.vatAmount or 0)
    streamWriteInt32(streamId, self.totalHT or 0)
    streamWriteInt8(streamId, self.createdAt.day)
    streamWriteInt8(streamId, self.createdAt.hour)
    streamWriteInt8(streamId, self.createdAt.minute)
    streamWriteInt8(streamId, self.createdAt.period or 0)
    streamWriteInt16(streamId, self.createdAt.year or 0)

    streamWriteInt32(streamId, self.createdDay or 0)
    streamWriteInt32(streamId, self.penaltyAmount or 0)

    streamWriteInt16(streamId, #self.lineItems)
    for _, item in ipairs(self.lineItems) do
        streamWriteInt16(streamId, item.workTypeId or 0)
        streamWriteFloat32(streamId, item.amount or 0)
        streamWriteFloat32(streamId, item.quantity or 0)
        streamWriteInt8(streamId, item.unitType or Invoice.UNIT_PIECE)
        streamWriteInt16(streamId, item.fieldId or 0)
        streamWriteFloat32(streamId, item.fieldArea or 0)
        streamWriteString(streamId, item.note or "")
        streamWriteFloat32(streamId, item.vatRate or 0)
        streamWriteString(streamId, item.name or "")
        streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(item.iconFilename or ""))
        streamWriteFloat32(streamId, item.price or 0)

        local vehicleNetId = 0
        local uid = item.vehicleUniqueId or ""
        if uid ~= "" and g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil then
            local vehicle = g_currentMission.vehicleSystem:getVehicleByUniqueId(uid)
            if vehicle ~= nil then
                vehicleNetId = NetworkUtil.getObjectId(vehicle)
            end
        end
        streamWriteInt32(streamId, vehicleNetId)

        streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(item.consumableXmlFilename or ""))
        streamWriteInt16(streamId, item.consumableFillTypeIndex or 0)
        streamWriteFloat32(streamId, item.consumableFillLevel or 0)
    end
end

---Deserialize invoice data from network stream
-- @param integer streamId Network stream identifier
function Invoice:readStream(streamId)
    self.id = streamReadInt32(streamId)
    self.senderFarmId = streamReadInt32(streamId)
    self.recipientFarmId = streamReadInt32(streamId)
    self.state = streamReadInt8(streamId)
    self.vatAmount = streamReadInt32(streamId)
    self.totalHT = streamReadInt32(streamId)

    self.createdAt = {
        day = streamReadInt8(streamId),
        hour = streamReadInt8(streamId),
        minute = streamReadInt8(streamId),
        period = streamReadInt8(streamId),
        year = streamReadInt16(streamId)
    }

    self.createdDay = streamReadInt32(streamId)
    self.penaltyAmount = streamReadInt32(streamId)

    self.lineItems = {}
    self.totalAmount = 0

    local count = streamReadInt16(streamId)
    for _ = 1, count do
        local workTypeId = streamReadInt16(streamId)
        local amount = streamReadFloat32(streamId)

        local quantity = streamReadFloat32(streamId)
        local unitType = streamReadInt8(streamId)
        local fieldId = streamReadInt16(streamId)
        local fieldArea = streamReadFloat32(streamId)
        local note = streamReadString(streamId)
        local vatRate = streamReadFloat32(streamId)
        local name = streamReadString(streamId)
        local iconFilename = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId))
        local price = streamReadFloat32(streamId)

        local vehicleNetId = streamReadInt32(streamId)
        local vehicleUniqueId = ""
        if vehicleNetId ~= 0 then
            local vehicle = NetworkUtil.getObject(vehicleNetId)
            if vehicle ~= nil then
                vehicleUniqueId = vehicle:getUniqueId() or ""
            end
        end

        local item = {
            workTypeId = workTypeId,
            amount = amount,
            quantity = quantity,
            unitType = unitType,
            fieldId = fieldId,
            fieldArea = fieldArea,
            note = note,
            vatRate = vatRate,
            name = name,
            iconFilename = iconFilename,
            price = price,
            vehicleUniqueId = vehicleUniqueId,
            consumableXmlFilename = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId)),
            consumableFillTypeIndex = streamReadInt16(streamId),
            consumableFillLevel = streamReadFloat32(streamId)
        }

        table.insert(self.lineItems, item)
        self.totalAmount = self.totalAmount + amount
    end
end

---Resolves the display icon for a line item from local store data.
-- Vehicle items resolve from vehicleUniqueId, consumables from fillTypeIndex.
-- @param table item Line item
-- @return string Resolved icon path or empty string
function Invoice.resolveLocalIcon(item)
    if item == nil then
        return ""
    end

    -- Consumable items (palette/bale) take precedence: icon resolves via consumable
    -- store entry or fillType. vehicleUniqueId on a consumable is reserved for
    -- ownership transfer at payment, not display.
    local hasConsumable = (item.consumableXmlFilename ~= nil and item.consumableXmlFilename ~= "")
        or ((item.consumableFillTypeIndex or 0) > 0)

    if not hasConsumable then
        local uid = item.vehicleUniqueId
        if uid ~= nil and uid ~= "" then
            if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil then
                local vehicle = g_currentMission.vehicleSystem:getVehicleByUniqueId(uid)
                if vehicle ~= nil and vehicle.configFileName ~= nil then
                    local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
                    if storeItem ~= nil and storeItem.imageFilename ~= nil and storeItem.imageFilename ~= "" then
                        return storeItem.imageFilename
                    end
                end
            end
        end
    end

    -- Pellets fillType bypass: their store icon is a generic white pallet,
    -- so prefer the fillType hudOverlayFilename (the actual fill type icon).
    -- Mirrors InvoicesConsumablePipeline.resolveIcon behavior.
    local fillIdx = item.consumableFillTypeIndex
    if fillIdx ~= nil and fillIdx > 0 and g_fillTypeManager ~= nil then
        local fillTypeInfo = g_fillTypeManager:getFillTypeByIndex(fillIdx)
        if fillTypeInfo ~= nil
            and (fillTypeInfo.name == "STRAW_PELLETS" or fillTypeInfo.name == "HAY_PELLETS")
            and fillTypeInfo.hudOverlayFilename ~= nil and fillTypeInfo.hudOverlayFilename ~= "" then
            return fillTypeInfo.hudOverlayFilename
        end
    end

    local xmlFn = item.consumableXmlFilename
    if xmlFn ~= nil and xmlFn ~= "" then
        local storeItem = g_storeManager:getItemByXMLFilename(xmlFn)
        if storeItem ~= nil and storeItem.imageFilename ~= nil and storeItem.imageFilename ~= "" then
            return storeItem.imageFilename
        end
    end

    if fillIdx ~= nil and fillIdx > 0 and g_fillTypeManager ~= nil then
        local fillTypeInfo = g_fillTypeManager:getFillTypeByIndex(fillIdx)
        if fillTypeInfo ~= nil and fillTypeInfo.hudOverlayFilename ~= nil and fillTypeInfo.hudOverlayFilename ~= "" then
            return fillTypeInfo.hudOverlayFilename
        end
        return ""
    end

    return item.iconFilename or ""
end
