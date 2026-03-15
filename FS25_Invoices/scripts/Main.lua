--[[
    Main.lua
    Author: Squallqt
]]

local modDirectory = g_currentModDirectory
local modName = g_currentModName
source(modDirectory .. "scripts/Invoice.lua")
source(modDirectory .. "scripts/InvoiceRepository.lua")
source(modDirectory .. "scripts/InvoiceService.lua")
source(modDirectory .. "scripts/InvoicesManager.lua")
source(modDirectory .. "scripts/InvoicesWizardState.lua")
source(modDirectory .. "events/InvoiceCreateEvent.lua")
source(modDirectory .. "events/InvoiceStateEvent.lua")
source(modDirectory .. "events/InvoiceSyncEvent.lua")
source(modDirectory .. "gui/InvoicesListRenderer.lua")
source(modDirectory .. "gui/WorkTypesRenderer.lua")
source(modDirectory .. "gui/LineItemsRenderer.lua")
source(modDirectory .. "gui/InvoicesFrame.lua")
source(modDirectory .. "gui/InvoicesDetailDialog.lua")
source(modDirectory .. "gui/InvoicesFieldDialog.lua")
source(modDirectory .. "gui/InvoicesFarmDialog.lua")
source(modDirectory .. "gui/InvoicesWizardStep1.lua")
source(modDirectory .. "gui/InvoicesWizardStep2.lua")
source(modDirectory .. "gui/InvoicesWizardStep3.lua")
source(modDirectory .. "gui/InvoicesWizardStep4.lua")

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
    
    MoneyType.INVOICE_INCOME = MoneyType.register("invoiceIncome", "invoice_moneyType_income")
    MoneyType.INVOICE_EXPENSE = MoneyType.register("invoiceExpense", "invoice_moneyType_expense")

    Invoices.manager = InvoicesManager.new()
    Invoices.manager:initialize()

    -- Load VAT rates from XML
    Invoices.manager.service:loadVatRates(Invoices.modDirectory .. "data/vatRates.xml")

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savegameFolderPath = savegameFolderPath .. "/"
    Invoices.manager:loadFromXML(savegameFolderPath)
    Logging.devInfo("[Invoices] Invoices loaded from savegame")

    g_currentMission.invoicesManager = Invoices.manager

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
    
    local fieldDialog = InvoicesFieldDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesFieldDialog.xml", "InvoicesFieldDialog", fieldDialog)
    Logging.devInfo("[Invoices] InvoicesFieldDialog loaded")
    
    local farmDialog = InvoicesFarmDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesFarmDialog.xml", "InvoicesFarmDialog", farmDialog)
    Logging.devInfo("[Invoices] InvoicesFarmDialog loaded")
    
    local wizStep1 = InvoicesWizardStep1.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesWizardStep1.xml", "InvoicesWizardStep1", wizStep1)
    Logging.devInfo("[Invoices] InvoicesWizardStep1 loaded")
    
    local wizStep2 = InvoicesWizardStep2.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesWizardStep2.xml", "InvoicesWizardStep2", wizStep2)
    Logging.devInfo("[Invoices] InvoicesWizardStep2 loaded")
    
    local wizStep3 = InvoicesWizardStep3.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesWizardStep3.xml", "InvoicesWizardStep3", wizStep3)
    Logging.devInfo("[Invoices] InvoicesWizardStep3 loaded")
    
    local wizStep4 = InvoicesWizardStep4.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesWizardStep4.xml", "InvoicesWizardStep4", wizStep4)
    Logging.devInfo("[Invoices] InvoicesWizardStep4 loaded")

    Logging.devInfo("[Invoices] Registering menu in InGameMenu")
    Invoices.addInGameMenuPage(frame, "InvoicesFrame", {0, 0, 1024, 1024}, function() return true end, 1)
    frame:initialize()
    Logging.devInfo("[Invoices] Menu registration complete")
    
    Invoices.frame = frame
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
    end)
end

initInvoices()

-- I18N extension: resolve mod keys without modEnv for Finance tab
local InvoicesI18NTexts = {
    ["finance_invoiceIncome"] = true,
    ["finance_invoiceExpense"] = true,
    ["invoice_moneyType_income"] = true,
    ["invoice_moneyType_expense"] = true,
    ["invoice_notification_new"] = true,
    ["invoice_reminder_single"] = true,
    ["invoice_reminder_multiple"] = true
}

local function invoicesGetText(self, superFunc, text, modEnv)
    if modEnv == nil and InvoicesI18NTexts[text] then
        return superFunc(self, text, modName)
    end
    return superFunc(self, text, modEnv)
end

I18N.getText = Utils.overwrittenFunction(I18N.getText, invoicesGetText)
