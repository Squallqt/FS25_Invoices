-- Copyright © 2026 Squallqt. All rights reserved.
-- Unified pipeline: collect, normalize, and group all consumables (pallets, bigBags, bales).
InvoicesConsumablePipeline = {}

-- Resolution

---Resolves fill type index from raw value (number or string)
-- @param any fillTypeRaw Fill type as index or name
-- @return integer|nil fillTypeIndex
function InvoicesConsumablePipeline.resolveFillType(fillTypeRaw)
    if fillTypeRaw == nil then return nil end
    if type(fillTypeRaw) == "number" then return fillTypeRaw end
    if type(fillTypeRaw) == "string" and g_fillTypeManager ~= nil then
        return g_fillTypeManager:getFillTypeIndexByName(fillTypeRaw)
    end
    return nil
end

---Builds display name from fill type, level, and container prefix
-- @param integer? fillTypeIndex Fill type index
-- @param float? fillLevel Current fill level
-- @param string? storeItemName Fallback store item name
-- @param string? containerPrefix Prefix label
-- @return string name Display name
function InvoicesConsumablePipeline.resolveName(fillTypeIndex, fillLevel, storeItemName, containerPrefix)
    local name = nil
    if fillTypeIndex ~= nil and g_fillTypeManager ~= nil then
        local fillTypeInfo = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillTypeInfo ~= nil and fillTypeInfo.title ~= nil and fillTypeInfo.title ~= "" then
            name = fillTypeInfo.title
        end
    end
    if name == nil then
        name = (storeItemName ~= nil and storeItemName ~= "") and storeItemName or "?"
    end
    if containerPrefix ~= nil and containerPrefix ~= "" then
        name = containerPrefix .. " - " .. name
    end
    if fillLevel ~= nil and fillLevel > 0 then
        name = name .. string.format(" (%.0f l)", fillLevel)
    end
    return name
end

---Returns localized bale type name from XML filename
-- @param string xmlFilename Bale XML definition
-- @return string|nil name Bale type name or nil
function InvoicesConsumablePipeline.resolveBaleTypeName(xmlFilename)
    if xmlFilename == nil or xmlFilename == "" or g_baleManager == nil then return nil end
    local isRoundBale = g_baleManager:getBaleInfoByXMLFilename(xmlFilename, true)
    if isRoundBale == nil then return nil end
    return g_i18n:getText(isRoundBale and "fillType_roundBale" or "fillType_squareBale")
end

---Resolves icon filename from fill type, XML, or store item
-- @param integer? fillTypeIndex Fill type index
-- @param string? xmlFilename Consumable XML definition
-- @param string? sourceType Source type ("bale" skips pallet lookup)
-- @return string iconFilename Icon path or empty string
function InvoicesConsumablePipeline.resolveIcon(fillTypeIndex, xmlFilename, sourceType)
    local fillTypeInfo = nil
    if fillTypeIndex ~= nil and g_fillTypeManager ~= nil then
        fillTypeInfo = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if fillTypeInfo ~= nil then
            if (fillTypeInfo.name == "STRAW_PELLETS" or fillTypeInfo.name == "HAY_PELLETS")
                and fillTypeInfo.hudOverlayFilename ~= nil and fillTypeInfo.hudOverlayFilename ~= "" then
                return fillTypeInfo.hudOverlayFilename
            end
        end
    end

    -- 1. Direct store item image
    if xmlFilename ~= nil and g_storeManager ~= nil then
        local storeItem = g_storeManager:getItemByXMLFilename(xmlFilename)
        if storeItem ~= nil and storeItem.imageFilename ~= nil and storeItem.imageFilename ~= "" then
            return storeItem.imageFilename
        end
    end

    -- 2. FillType resolution
    if fillTypeInfo ~= nil then
        -- For bales, skip palletFilename lookup (returns pallet/wooden box icon)
        -- and fall through directly to hudOverlayFilename (the actual fill type icon)
        if sourceType ~= "bale" then
            if fillTypeInfo.palletFilename ~= nil and fillTypeInfo.palletFilename ~= "" and g_storeManager ~= nil then
                local palletStoreItem = g_storeManager:getItemByXMLFilename(fillTypeInfo.palletFilename)
                if palletStoreItem ~= nil and palletStoreItem.imageFilename ~= nil and palletStoreItem.imageFilename ~= "" then
                    return palletStoreItem.imageFilename
                end
            end
        end

        if fillTypeInfo.hudOverlayFilename ~= nil and fillTypeInfo.hudOverlayFilename ~= "" then
            return fillTypeInfo.hudOverlayFilename
        end
    end

    return ""
end

---Computes price from fill type, level, or sell price override
-- @param integer? fillTypeIndex Fill type index
-- @param float? fillLevel Current fill level
-- @param integer? sellPriceOverride Override sell price
-- @return integer price Computed price
function InvoicesConsumablePipeline.computePrice(fillTypeIndex, fillLevel, sellPriceOverride)
    if sellPriceOverride ~= nil and sellPriceOverride > 0 then
        return math.floor(sellPriceOverride)
    end
    if fillTypeIndex ~= nil and fillLevel ~= nil and fillLevel > 0 then
        local pricePerLiter = 0
        if g_currentMission ~= nil and g_currentMission.economyManager ~= nil then
            pricePerLiter = g_currentMission.economyManager:getPricePerLiter(fillTypeIndex) or 0
        end
        if pricePerLiter > 0 then
            return math.floor(fillLevel * pricePerLiter)
        end
    end
    return 0
end

---Normalizes filename path for comparison
-- @param string filename File path to normalize
-- @return string normalized Lowercase normalized path
function InvoicesConsumablePipeline.normalizeFilename(filename)
    if filename == nil or filename == "" then return "" end
    local norm = filename:gsub("\\", "/")
    norm = norm:gsub("^%$[^/]+/", "")
    return norm:lower()
end

---Computes grouping key from filename, fill type, and level
-- @param string xmlFilename Consumable XML definition
-- @param integer? fillTypeIndex Fill type index
-- @param float? fillLevel Current fill level
-- @return string groupKey Group key string
function InvoicesConsumablePipeline.computeGroupKey(xmlFilename, fillTypeIndex, fillLevel)
    local normFile = InvoicesConsumablePipeline.normalizeFilename(xmlFilename)
    return normFile .. "|" .. tostring(fillTypeIndex or 0) .. "|" .. tostring(math.floor(fillLevel or 0))
end

-- Adapter: Vehicle (pallets / bigBags)

---Collects filled container vehicles owned by a farm
-- @param integer playerFarmId Farm identifier
-- @return table items Array of container items with metadata
function InvoicesConsumablePipeline.collectFromVehicles(playerFarmId)
    local items = {}
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then return items end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle ~= nil and vehicle.isPallet then
            local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
            local propertyState = vehicle.getPropertyState ~= nil and vehicle:getPropertyState() or vehicle.propertyState

            if ownerFarmId == playerFarmId and propertyState == VehiclePropertyState.OWNED then
                local uniqueId = vehicle:getUniqueId()
                if uniqueId ~= nil then
                    local xmlFilename = vehicle.configFileName
                    local fillTypeIndex = nil
                    local totalFillLevel = 0
                    local totalCapacity = 0

                    if vehicle.getFillUnits ~= nil and vehicle.getFillUnitFillLevel ~= nil and vehicle.getFillUnitCapacity ~= nil then
                        local fillUnits = vehicle:getFillUnits()
                        if fillUnits ~= nil then
                            for fillUnitIndex, _ in ipairs(fillUnits) do
                                local fl = vehicle:getFillUnitFillLevel(fillUnitIndex) or 0
                                local fc = vehicle:getFillUnitCapacity(fillUnitIndex) or 0
                                totalFillLevel = totalFillLevel + fl
                                totalCapacity = totalCapacity + fc
                                if fillTypeIndex == nil and fl > 0 and vehicle.getFillUnitFillType ~= nil then
                                    local ft = vehicle:getFillUnitFillType(fillUnitIndex)
                                    if ft ~= nil and ft > 0 then
                                        fillTypeIndex = ft
                                    end
                                end
                            end
                        end
                    end

                    local storeItem = g_storeManager:getItemByXMLFilename(xmlFilename)
                    local storeItemName = storeItem and storeItem.name or nil
                    local containerPrefix = g_i18n:getText("infohud_pallet")

                    local displayName  = InvoicesConsumablePipeline.resolveName(fillTypeIndex, totalFillLevel, storeItemName, containerPrefix)
                    local iconFilename = InvoicesConsumablePipeline.resolveIcon(fillTypeIndex, xmlFilename)

                    local basePrice = storeItem and storeItem.price or 0
                    local unitPrice
                    if basePrice > 0 and totalCapacity > 0 and totalFillLevel > 0 then
                        unitPrice = math.floor(basePrice * (totalFillLevel / totalCapacity))
                    elseif basePrice > 0 then
                        unitPrice = math.floor(basePrice)
                    else
                        unitPrice = InvoicesConsumablePipeline.computePrice(fillTypeIndex, totalFillLevel, math.floor(vehicle:getSellPrice()))
                    end

                    local groupKey     = InvoicesConsumablePipeline.computeGroupKey(xmlFilename, fillTypeIndex, totalFillLevel)

                    table.insert(items, {
                        sourceType    = "vehicle",
                        xmlFilename   = xmlFilename,
                        fillTypeIndex = fillTypeIndex,
                        fillLevel     = totalFillLevel,
                        capacity      = totalCapacity,
                        ownerFarmId   = playerFarmId,
                        displayName   = displayName,
                        iconFilename  = iconFilename,
                        unitPrice     = unitPrice,
                        groupKey      = groupKey,
                        uniqueId      = uniqueId,
                    })
                end
            end
        end
    end

    return items
end

-- Adapter: Bale (real objects in the world)

---Collects bales owned by a farm
-- @param integer playerFarmId Farm identifier
-- @return table items Array of bale items with metadata
function InvoicesConsumablePipeline.collectFromBales(playerFarmId)
    local items = {}
    if g_currentMission == nil then return items end

    local seen = {}
    for _, object in pairs(g_currentMission.nodeToObject) do
        if object.isa ~= nil and object:isa(Bale) and not object.isMissionBale and not seen[object] then
            seen[object] = true
            local ownerFarmId = object:getOwnerFarmId()
            if ownerFarmId == playerFarmId then
                local fillTypeIndex = object.fillType
                local fillLevel     = object.fillLevel or 0
                local xmlFilename   = object.xmlFilename or ""

                local storeItem     = g_storeManager ~= nil and g_storeManager:getItemByXMLFilename(xmlFilename) or nil
                local storeItemName = storeItem and storeItem.name or nil
                local containerPrefix = InvoicesConsumablePipeline.resolveBaleTypeName(xmlFilename)

                local displayName  = InvoicesConsumablePipeline.resolveName(fillTypeIndex, fillLevel, storeItemName, containerPrefix)
                local iconFilename = InvoicesConsumablePipeline.resolveIcon(fillTypeIndex, xmlFilename, "bale")
                local unitPrice    = InvoicesConsumablePipeline.computePrice(fillTypeIndex, fillLevel, object.getValue and math.floor(object:getValue()) or nil)
                local groupKey     = InvoicesConsumablePipeline.computeGroupKey(xmlFilename, fillTypeIndex, fillLevel)

                local uid = object.uniqueId
                if uid == nil then uid = "bale_" .. tostring(object.rootNode or 0) end

                table.insert(items, {
                    sourceType    = "bale",
                    xmlFilename   = xmlFilename,
                    fillTypeIndex = fillTypeIndex,
                    fillLevel     = fillLevel,
                    capacity      = fillLevel,
                    ownerFarmId   = playerFarmId,
                    displayName   = displayName,
                    iconFilename  = iconFilename,
                    unitPrice     = unitPrice,
                    groupKey      = groupKey,
                    uniqueId      = uid,
                })
            end
        end
    end

    return items
end

-- Public API

---Collects all consumables (vehicles and bales) for a farm
-- @param integer playerFarmId Farm identifier
-- @return table items Array of all consumable items
function InvoicesConsumablePipeline.collectAll(playerFarmId)
    local items = {}

    for _, item in ipairs(InvoicesConsumablePipeline.collectFromVehicles(playerFarmId)) do
        table.insert(items, item)
    end
    for _, item in ipairs(InvoicesConsumablePipeline.collectFromBales(playerFarmId)) do
        table.insert(items, item)
    end

    return items
end

InvoicesConsumablePipeline._cache = nil
InvoicesConsumablePipeline._cacheFarmId = nil

---Invalidates the consumable cache
function InvoicesConsumablePipeline.invalidateCache()
    InvoicesConsumablePipeline._cache = nil
    InvoicesConsumablePipeline._cacheFarmId = nil
end

---Collects all consumables with caching for the same farm
-- @param integer playerFarmId Farm identifier
-- @return table items Array of all consumable items
function InvoicesConsumablePipeline.collectAllCached(playerFarmId)
    if InvoicesConsumablePipeline._cache ~= nil and InvoicesConsumablePipeline._cacheFarmId == playerFarmId then
        return InvoicesConsumablePipeline._cache
    end
    local items = InvoicesConsumablePipeline.collectAll(playerFarmId)
    InvoicesConsumablePipeline._cache = items
    InvoicesConsumablePipeline._cacheFarmId = playerFarmId
    return items
end

---Groups consumable items by group key for display
-- @param table items Array of consumable items
-- @return table groups Sorted array of grouped consumables
function InvoicesConsumablePipeline.groupItems(items)
    local groupMap = {}
    local groupOrder = {}

    for _, item in ipairs(items) do
        if groupMap[item.groupKey] == nil then
            groupMap[item.groupKey] = {
                groupKey     = item.groupKey,
                displayName  = item.displayName,
                iconFilename = item.iconFilename,
                items        = {},
                ownedCount   = 0,
            }
            table.insert(groupOrder, item.groupKey)
        end
        local group = groupMap[item.groupKey]
        table.insert(group.items, item)
        group.ownedCount = group.ownedCount + 1
        if item.fillTypeIndex ~= nil and group._resolvedFillType == nil then
            group.displayName  = item.displayName
            group.iconFilename = item.iconFilename
            group._resolvedFillType = true
        end
    end

    local groups = {}
    for _, key in ipairs(groupOrder) do
        local group = groupMap[key]
        table.sort(group.items, function(a, b) return a.unitPrice < b.unitPrice end)
        table.insert(groups, group)
    end

    table.sort(groups, function(a, b) return a.displayName < b.displayName end)

    return groups
end

---Returns stock count for a group key
-- @param string groupKey Group key to count
-- @param integer playerFarmId Farm identifier
-- @return integer count Number of matching items
function InvoicesConsumablePipeline.getStockForGroup(groupKey, playerFarmId)
    local all = InvoicesConsumablePipeline.collectAllCached(playerFarmId)
    local count = 0
    for _, item in ipairs(all) do
        if item.groupKey == groupKey then
            count = count + 1
        end
    end
    return count
end

---Returns items matching a group key, optionally limited
-- @param string groupKey Group key to match
-- @param integer playerFarmId Farm identifier
-- @param integer? maxCount Maximum items to return
-- @return table items Matching items sorted by price
function InvoicesConsumablePipeline.getItemsForGroup(groupKey, playerFarmId, maxCount)
    local all = InvoicesConsumablePipeline.collectAllCached(playerFarmId)
    local matching = {}
    for _, item in ipairs(all) do
        if item.groupKey == groupKey then
            table.insert(matching, item)
        end
    end
    table.sort(matching, function(a, b) return a.unitPrice < b.unitPrice end)

    if maxCount ~= nil and maxCount < #matching then
        local trimmed = {}
        for i = 1, maxCount do
            table.insert(trimmed, matching[i])
        end
        return trimmed
    end

    return matching
end

-- Ownership transfer

---Transfers consumable ownership between farms by criteria
-- @param string xmlFilename Consumable XML definition
-- @param integer fillTypeIndex Fill type index
-- @param integer quantity Quantity to transfer
-- @param integer senderFarmId Sender farm identifier
-- @param integer recipientFarmId Recipient farm identifier
-- @return integer transferred Quantity transferred
function InvoicesConsumablePipeline.transferByCriteria(xmlFilename, fillTypeIndex, quantity, senderFarmId, recipientFarmId)
    local transferred = 0
    local remaining = quantity or 0
    local normTarget = InvoicesConsumablePipeline.normalizeFilename(xmlFilename)

    if remaining <= 0 or normTarget == "" then return 0 end

    transferred = transferred + InvoicesConsumablePipeline.transferFreeBales(
        normTarget, fillTypeIndex, remaining, senderFarmId, recipientFarmId
    )
    remaining = quantity - transferred

    if remaining > 0 then
        transferred = transferred + InvoicesConsumablePipeline.transferFreeVehicles(
            normTarget, fillTypeIndex, remaining, senderFarmId, recipientFarmId
        )
        remaining = quantity - transferred
    end

    if transferred < quantity then
        Logging.warning("[InvoicesConsumablePipeline] Could only transfer %d/%d objects (xml=%s, fillType=%d)", transferred, quantity, xmlFilename or "", fillTypeIndex or 0)
    end

    return transferred
end

---Transfers bale ownership between farms by criteria
-- @param string normTarget Normalized XML filename
-- @param integer fillTypeIndex Fill type index
-- @param integer maxCount Maximum bales to transfer
-- @param integer senderFarmId Current owner farm identifier
-- @param integer recipientFarmId New owner farm identifier
-- @return integer count Number of bales transferred
function InvoicesConsumablePipeline.transferFreeBales(normTarget, fillTypeIndex, maxCount, senderFarmId, recipientFarmId)
    local count = 0
    if g_currentMission == nil then return 0 end

    for _, object in pairs(g_currentMission.nodeToObject) do
        if count >= maxCount then break end
        if object.isa ~= nil and object:isa(Bale) and not object.isMissionBale then
            if object:getOwnerFarmId() == senderFarmId then
                local normFile = InvoicesConsumablePipeline.normalizeFilename(object.xmlFilename or "")
                if normFile == normTarget and object.fillType == fillTypeIndex then
                    object:setOwnerFarmId(recipientFarmId, true)
                    count = count + 1
                end
            end
        end
    end

    return count
end

---Transfers pallet vehicle ownership between farms by criteria
-- @param string normTarget Normalized XML filename
-- @param integer fillTypeIndex Fill type index
-- @param integer maxCount Maximum vehicles to transfer
-- @param integer senderFarmId Current owner farm identifier
-- @param integer recipientFarmId New owner farm identifier
-- @return integer count Number of vehicles transferred
function InvoicesConsumablePipeline.transferFreeVehicles(normTarget, fillTypeIndex, maxCount, senderFarmId, recipientFarmId)
    local count = 0
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then return 0 end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if count >= maxCount then break end
        if vehicle ~= nil and vehicle.isPallet then
            local ownerFarmId = vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() or vehicle.ownerFarmId
            if ownerFarmId == senderFarmId then
                local normFile = InvoicesConsumablePipeline.normalizeFilename(vehicle.configFileName or "")
                if normFile == normTarget then
                    local matched = false
                    if vehicle.getFillUnits ~= nil then
                        local fillUnits = vehicle:getFillUnits()
                        if fillUnits ~= nil then
                            for fillUnitIndex, _ in ipairs(fillUnits) do
                                if not matched and vehicle.getFillUnitFillType ~= nil then
                                    local t = vehicle:getFillUnitFillType(fillUnitIndex)
                                    if t == fillTypeIndex then matched = true end
                                end
                            end
                        end
                    end
                    if matched then
                        vehicle:setOwnerFarmId(recipientFarmId, true)
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end

