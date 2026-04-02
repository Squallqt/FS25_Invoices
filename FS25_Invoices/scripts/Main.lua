--[[
    Main.lua
    Mod bootstrap: source loading, mission lifecycle hooks, late-join sync dispatch, and InGameMenu registration.
    Author: Squallqt
]]

local modDirectory = g_currentModDirectory
local modName = g_currentModName
source(modDirectory .. "scripts/Invoice.lua")
source(modDirectory .. "scripts/InvoiceRepository.lua")
source(modDirectory .. "scripts/InvoiceService.lua")
source(modDirectory .. "scripts/InvoicesManager.lua")
source(modDirectory .. "scripts/InvoicesWizardState.lua")
source(modDirectory .. "scripts/InvoiceSettings.lua")
source(modDirectory .. "events/InvoiceCreateEvent.lua")
source(modDirectory .. "events/InvoiceStateEvent.lua")
source(modDirectory .. "events/InvoiceSyncEvent.lua")
source(modDirectory .. "events/InvoiceSettingsEvent.lua")
source(modDirectory .. "gui/InvoicesListRenderer.lua")
source(modDirectory .. "gui/InvoicesFrame.lua")
source(modDirectory .. "gui/InvoicesDetailDialog.lua")
source(modDirectory .. "gui/InvoicesFillTypeDialog.lua")
source(modDirectory .. "gui/InvoicesMainDashboard.lua")

Invoices = {}
Invoices.modDirectory = modDirectory
Invoices.modName = modName
Invoices.manager = nil

local function registerFinanceStat(statName)
    if FinanceStats.statNameToIndex[statName] == nil then
        table.insert(FinanceStats.statNames, statName)
        FinanceStats.statNameToIndex[statName] = #FinanceStats.statNames
    end
end

registerFinanceStat("invoiceIncome")
registerFinanceStat("invoiceExpense")

local function loadedMission()
    Logging.devInfo("[Invoices] loadedMission() called")
    
    MoneyType.INVOICE_INCOME = MoneyType.register("invoiceIncome", "invoice_label_invoice")
    MoneyType.INVOICE_EXPENSE = MoneyType.register("invoiceExpense", "invoice_label_invoice")

    Invoices.manager = InvoicesManager.new()
    Invoices.manager:initialize()

    Invoices.manager.service:loadVatRates(Invoices.modDirectory .. "data/vatRates.xml")

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savegameFolderPath = savegameFolderPath .. "/"
    Invoices.manager:loadFromXML(savegameFolderPath)
    Logging.devInfo("[Invoices] Invoices loaded from savegame")

    g_currentMission.invoicesManager = Invoices.manager

    InvoiceSettings:loadDefaultsIfMissing()
    InvoiceSettings:loadFromXMLFile()

    Invoices.manager.service:initializeReminderSystem()
    
    Logging.devInfo("[Invoices] Loading GUI profiles")
    g_gui:loadProfiles(Invoices.modDirectory .. "gui/guiProfiles.xml")
    
    Logging.devInfo("[Invoices] Loading InvoicesFrame")
    local frame = InvoicesFrame.new(g_i18n, g_messageCenter)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesFrame.xml", "InvoicesFrame", frame, true)
    Logging.devInfo("[Invoices] InvoicesFrame loaded")
    
    Logging.devInfo("[Invoices] Loading dialogs")
    local detailDialog = InvoicesDetailDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesDetailDialog.xml", "InvoicesDetailDialog", detailDialog)
    Logging.devInfo("[Invoices] InvoicesDetailDialog loaded")
    
    local fillTypeDialog = InvoicesFillTypeDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesFillTypeDialog.xml", "InvoicesFillTypeDialog", fillTypeDialog)
    Logging.devInfo("[Invoices] InvoicesFillTypeDialog loaded")
    
    local dashboard = InvoicesMainDashboard.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesMainDashboard.xml", "InvoicesMainDashboard", dashboard)
    Logging.devInfo("[Invoices] InvoicesMainDashboard loaded")

    Logging.devInfo("[Invoices] Registering menu in InGameMenu")
    Invoices.addInGameMenuPage(frame, "InvoicesFrame", {0, 0, 1024, 1024}, function() return true end, 1)
    frame:initialize()
    Logging.devInfo("[Invoices] Menu registration complete")
    
    Invoices.frame = frame

    InvoiceSettings:injectMenu()
end

function Invoices.addInGameMenuPage(frame, pageName, uvs, predicateFunc, insertPosition)
    local targetPosition = 1

    for k, v in pairs({pageName}) do
        g_inGameMenu.controlIDs[v] = nil
    end

    if type(insertPosition) == "number" then
        targetPosition = insertPosition
    elseif type(insertPosition) == "string" then
        for i = 1, #g_inGameMenu.pagingElement.elements do
            local child = g_inGameMenu.pagingElement.elements[i]
            if child == g_inGameMenu[insertPosition] then
                targetPosition = i + 1
                break
            end
        end
    end

    g_inGameMenu[pageName] = frame
    g_inGameMenu.pagingElement:addElement(g_inGameMenu[pageName])

    g_inGameMenu:exposeControlsAsFields(pageName)

    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.elements, i)
            table.insert(g_inGameMenu.pagingElement.elements, targetPosition, child)
            break
        end
    end

    for i = 1, #g_inGameMenu.pagingElement.pages do
        local child = g_inGameMenu.pagingElement.pages[i]
        if child.element == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.pages, i)
            table.insert(g_inGameMenu.pagingElement.pages, targetPosition, child)
            break
        end
    end

    g_inGameMenu.pagingElement:updateAbsolutePosition()
    g_inGameMenu.pagingElement:updatePageMapping()

    g_inGameMenu:registerPage(g_inGameMenu[pageName], nil, predicateFunc)

    local iconFileName = Utils.getFilename('images/menuIcon.dds', Invoices.modDirectory)
    g_inGameMenu:addPageTab(g_inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))

    for i = 1, #g_inGameMenu.pageFrames do
        local child = g_inGameMenu.pageFrames[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pageFrames, i)
            table.insert(g_inGameMenu.pageFrames, targetPosition, child)
            break
        end
    end

    g_inGameMenu:rebuildTabList()
    Logging.devInfo("[Invoices] Menu page registered successfully")
end

local function sendInitialClientState(self, connection, user, farm)
    if g_server == nil then return end
    -- Nil guards for late-join race condition
    if connection == nil then
        Logging.warning("[Invoices] sendInitialClientState: connection is nil, skipping sync")
        return
    end
    if Invoices.manager == nil then
        Logging.warning("[Invoices] sendInitialClientState: manager not initialized, skipping sync")
        return
    end

    local invoices = Invoices.manager.repository:getAll()
    Logging.devInfo("[Invoices] sendInitialClientState() - Syncing %d invoices to new client", #invoices)
    connection:sendEvent(InvoiceSyncEvent.new())
    connection:sendEvent(InvoiceSettingsEvent.new(g_currentMission.invoiceSettings))
end

local function onSaveToXMLFile()
    if not g_currentMission:getIsServer() then return end

    if Invoices.manager then
        local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory
        if savegameFolderPath == nil then
            savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
        end
        savegameFolderPath = savegameFolderPath .. "/"
        Invoices.manager:saveToXML(savegameFolderPath)
        Logging.devInfo("[Invoices] Saved to %s", savegameFolderPath)
    end
end

local function initInvoices()
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
    
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, onSaveToXMLFile)
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, function()
        InvoiceSettings:saveToXMLFile()
    end)
    
    FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, sendInitialClientState)
    
    -- Cleanup on mission end
    BaseMission.delete = Utils.appendedFunction(BaseMission.delete, function()
        if Invoices.manager then
            Invoices.manager.service:cleanupReminderSystem()
            Invoices.manager:cleanup()
            Invoices.manager = nil
        end
        -- Reset wizard singleton
        InvoicesWizardState.instance = nil
        g_currentMission.invoicesFrame = nil
        g_currentMission.invoicesManager = nil
        g_currentMission.invoiceSettings = nil
        InvoiceSettings.CONTROLS = {}
    end)
end

initInvoices()

-- I18N extension: resolve mod keys without modEnv for Finance tab
local InvoicesI18NTexts = {
    ["finance_invoiceIncome"] = true,
    ["finance_invoiceExpense"] = true,
    ["invoice_label_invoice"] = true,
    ["invoice_notification_new"] = true,
    ["invoice_reminder_single"] = true,
    ["invoice_reminder_multiple"] = true,
    ["invoice_settings_section_title"] = true,
    ["invoice_setting_invoiceVatSimulated"] = true,
    ["invoice_toolTip_invoiceVatSimulated"] = true,
    ["invoice_setting_invoiceReminders"] = true,
    ["invoice_toolTip_invoiceReminders"] = true,
    ["invoice_label_vat"] = true,
    ["invoice_notification_vat_incl"] = true,
    ["invoice_notification_vat_excl"] = true,
    ["invoice_notification_penalty_incl"] = true,
    ["invoice_status_overdue"] = true,
    ["invoice_label_total_due"] = true,
    ["invoice_label_penalty"] = true,
    ["invoice_label_subtotal_ht"] = true,
    ["invoice_setting_invoicePenalties"] = true,
    ["invoice_toolTip_invoicePenalties"] = true,
    ["invoice_notification_overdue"] = true,
    ["invoice_notification_overdue_warning"] = true
}

local function invoicesGetText(self, superFunc, text, modEnv)
    if modEnv == nil and InvoicesI18NTexts[text] then
        return superFunc(self, text, modName)
    end
    return superFunc(self, text, modEnv)
end

I18N.getText = Utils.overwrittenFunction(I18N.getText, invoicesGetText)
