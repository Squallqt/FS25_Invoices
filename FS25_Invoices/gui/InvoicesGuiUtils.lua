-- Copyright 2026 Squallqt. All rights reserved.
---Shared GUI helpers for invoice dialogs
InvoicesGuiUtils = {}

---Resizes a title separator to match the text element width
-- @param table titleElement GUI text element used for width calculation
-- @param table separatorElement GUI separator element to resize
function InvoicesGuiUtils.resizeTitleSeparator(titleElement, separatorElement)
    if separatorElement == nil or titleElement == nil then return end

    if separatorElement._invoicesTitleSepHeight == nil then
        separatorElement._invoicesTitleSepHeight = separatorElement.absSize[2]
    end

    local text = titleElement.text or ""
    local textWidth = getTextWidth(titleElement.textSize, text)
    local padding = 20 * 2 * g_pixelSizeScaledX
    local newWidth = textWidth + padding

    separatorElement:setSize(newWidth, separatorElement._invoicesTitleSepHeight)
    if separatorElement.parent ~= nil and separatorElement.parent.invalidateLayout ~= nil then
        separatorElement.parent:invalidateLayout()
    end
end

---Resizes a total separator to fit HT, VAT and total amount text
-- @param table separatorElement GUI separator element to resize
-- @param table htElement GUI text element used for HT width calculation
-- @param table vatElement GUI text element used for VAT width calculation
-- @param table totalElement GUI text element used for total width calculation
-- @param string htText Formatted HT amount text
-- @param string vatText Formatted VAT amount text
-- @param string totalText Formatted total amount text
-- @param number originalX Original separator X position
-- @param number originalWidth Original separator width
-- @return number Original separator X position
-- @return number Original separator width
function InvoicesGuiUtils.resizeTotalSeparator(separatorElement, htElement, vatElement, totalElement, htText, vatText, totalText, originalX, originalWidth)
    if separatorElement == nil or htElement == nil then return originalX, originalWidth end

    if originalX == nil then
        originalX = separatorElement.position[1]
        originalWidth = separatorElement.size[1]
    end

    local textSize = htElement.textSize
    local htWidth = getTextWidth(textSize, htText)
    local vatWidth = vatElement ~= nil and getTextWidth(vatElement.textSize, vatText) or 0
    local totalWidth = totalElement ~= nil and getTextWidth(totalElement.textSize, totalText or totalElement.text or "") or 0
    totalWidth = totalWidth + (20 * g_pixelSizeScaledX)
    local maxTextWidth = math.max(htWidth, vatWidth, totalWidth)

    local newW = math.min(maxTextWidth, originalWidth)
    local newX = originalX + originalWidth - newW
    separatorElement:setPosition(newX, separatorElement.position[2])
    separatorElement:setSize(newW, separatorElement.size[2])

    return originalX, originalWidth
end

---Shows or hides the discount line in a total breakdown
-- @param table totalRightColumn GUI BoxLayout containing the total breakdown rows
-- @param table htElement HT text element; layout is skipped when absent
-- @param table vatElement VAT text element; layout is skipped when absent
-- @param table discountElement Discount text element
-- @param number discountAmount Total discount in currency; the line shows only when > 0
-- @param table? discountTextColor Optional RGBA color applied when the discount line is shown
function InvoicesGuiUtils.layoutTotalBreakdown(totalRightColumn, htElement, vatElement, discountElement, discountAmount, discountTextColor)
    if htElement == nil or vatElement == nil then return end

    if discountElement ~= nil then
        if (discountAmount or 0) > 0 then
            local discountText = string.format("%s :  -%s", g_i18n:getText("invoice_label_discount"), g_i18n:formatMoney(discountAmount, 0, true, false))
            discountElement:setText(discountText)
            if discountTextColor ~= nil then
                discountElement:setTextColor(discountTextColor[1], discountTextColor[2], discountTextColor[3], discountTextColor[4])
            end
            discountElement:setVisible(true)
        else
            discountElement:setVisible(false)
        end
    end

    if totalRightColumn ~= nil and totalRightColumn.invalidateLayout ~= nil then
        totalRightColumn:invalidateLayout()
    end
end

local LINE_ITEM_UNIT_KEYS = {
    [Invoice.UNIT_HOUR] = "invoice_invoices_unit_hour",
    [Invoice.UNIT_HECTARE] = "invoice_invoices_unit_hectare",
    [Invoice.UNIT_LITER] = "invoice_invoices_unit_liter"
}

local function formatLineItemQuantity(unitType, quantity, pieceQuantityFormat)
    if unitType == Invoice.UNIT_HECTARE or unitType == Invoice.UNIT_HOUR then
        return string.format("%.2f", quantity or 0)
    elseif unitType == Invoice.UNIT_LITER then
        return string.format("%.0f", quantity or 0)
    end
    return string.format(pieceQuantityFormat or "%.0f", quantity or 0)
end

local function formatRatePercent(rate, decimals, fallbackText)
    rate = rate or 0
    if rate > 0 then
        return string.format("%." .. tostring(decimals or 0) .. "f%%", rate * 100)
    end
    return fallbackText
end

---Formats display values for an invoice line item
-- @param table item Invoice line item
-- @param table? options Formatting options
-- @return table Formatted display values
function InvoicesGuiUtils.formatLineItemValues(item, options)
    options = options or {}
    local unitField = options.unitField or "unitType"
    local unitType = item[unitField] or Invoice.UNIT_PIECE
    local amount = item.amount or 0
    local quantity = item.quantity or 0

    if unitType == Invoice.UNIT_HECTARE and options.useFieldAreaForHectare then
        quantity = item.fieldArea or 0
    elseif unitType == Invoice.UNIT_PIECE and options.minPieceQuantity then
        quantity = math.max(1, item.quantity or 1)
    end

    local unitPriceStr = ""
    if options.rebuildUnitPriceFromAmount then
        if item.price ~= nil and item.price > 0 then
            unitPriceStr = g_i18n:formatMoney(item.price)
        elseif quantity > 0 then
            local unitPrice = amount / quantity
            if unitType == Invoice.UNIT_LITER then
                unitPrice = amount * 1000 / quantity
            end
            unitPriceStr = g_i18n:formatMoney(unitPrice)
        end
    else
        unitPriceStr = g_i18n:formatMoney(item.price or 0, 0, true, false)
    end

    local vatStr = options.vatEnabled == false
        and g_i18n:getText("invoice_label_na")
        or formatRatePercent(item.vatRate, 1, options.zeroVatText or "—")
    local amountStr = options.useDefaultMoneyFormat
        and g_i18n:formatMoney(amount)
        or g_i18n:formatMoney(amount, 0, true, false)

    return {
        qty = formatLineItemQuantity(unitType, quantity, options.pieceQuantityFormat),
        unit = g_i18n:getText(LINE_ITEM_UNIT_KEYS[unitType] or "invoice_invoices_unit_piece"),
        unitPrice = unitPriceStr,
        vat = vatStr,
        discount = formatRatePercent(item.discountRate, 0, "—"),
        amount = amountStr
    }
end

---Returns the parenthesized portion of a display name
-- @param string? text Display name
-- @return string Parenthesized text or the original text
function InvoicesGuiUtils.getParenthesizedDisplayName(text)
    text = text or ""
    local parenStart = string.find(text, "%(")
    if parenStart ~= nil then
        local inner = string.sub(text, parenStart + 1, #text - 1)
        if inner ~= "" then
            return inner
        end
    end
    return text
end

---Adds text padding for a leading icon
-- @param string? text Display text
-- @param number textSize Text size
-- @param boolean? measureBold True to measure bold text
-- @return string Padded text
function InvoicesGuiUtils.getIconPaddedText(text, textSize, measureBold)
    setTextBold(measureBold == true)
    local spaceWidth = getTextWidth(textSize, " ")
    setTextBold(false)
    local iconPadding = 28 * g_pixelSizeScaledX
    local numSpaces = math.ceil(iconPadding / spaceWidth)
    return string.rep(" ", numSpaces) .. (text or "")
end
