-- Copyright © 2026 Squallqt. All rights reserved.
-- Mod bootstrap: source loading, mission lifecycle hooks, late-join sync dispatch, and InGameMenu registration.
local modDirectory = g_currentModDirectory
local modName = g_currentModName
source(modDirectory .. "scripts/Invoice.lua")
source(modDirectory .. "scripts/InvoiceRepository.lua")
source(modDirectory .. "scripts/InvoiceService.lua")
source(modDirectory .. "scripts/InvoicesManager.lua")
source(modDirectory .. "scripts/InvoicesWizardState.lua")
source(modDirectory .. "scripts/InvoiceSettings.lua")
source(modDirectory .. "scripts/InvoicesConsumablePipeline.lua")
source(modDirectory .. "events/InvoiceCreateEvent.lua")
source(modDirectory .. "events/InvoiceStateEvent.lua")
source(modDirectory .. "events/InvoiceSyncEvent.lua")
source(modDirectory .. "events/InvoiceSettingsEvent.lua")
source(modDirectory .. "events/InvoiceVehicleTransferEvent.lua")
source(modDirectory .. "events/InvoiceConsumableTransferEvent.lua")
source(modDirectory .. "events/InvoicePenaltySyncEvent.lua")
source(modDirectory .. "gui/InvoicesGuiUtils.lua")
source(modDirectory .. "gui/InvoicesListRenderer.lua")
source(modDirectory .. "gui/InvoicesFrame.lua")
source(modDirectory .. "gui/InvoicesDetailDialog.lua")
source(modDirectory .. "gui/InvoicesSelectionDialogBase.lua")
source(modDirectory .. "gui/InvoicesFillTypeDialog.lua")
source(modDirectory .. "gui/InvoicesVehicleDialog.lua")
source(modDirectory .. "gui/InvoicesConsumableDialog.lua")
source(modDirectory .. "gui/InvoicesChoiceDialog.lua")
source(modDirectory .. "gui/InvoicesMainDashboard.lua")

Invoices = {}
Invoices.modDirectory = modDirectory
Invoices.modName = modName
Invoices.manager = nil

local IN_GAME_MENU_PAGE_FIELD = "pageInvoices"
local IN_GAME_MENU_FRAME_NAME = "InvoicesFrame"
local IN_GAME_MENU_ICON_SLICE_ID = "invoices.menuIcon"
---Register finance stat entry
-- @param string statName Name of stat to register
local function registerFinanceStat(statName)
    if FinanceStats.statNameToIndex[statName] == nil then
        table.insert(FinanceStats.statNames, statName)
        FinanceStats.statNameToIndex[statName] = #FinanceStats.statNames
    end
end

registerFinanceStat("invoiceIncome")
registerFinanceStat("invoiceExpense")

---Load shared GUI assets once before creating invoice screens
local function loadGuiAssets()
    if not Invoices._guiProfilesLoaded then
        g_gui:loadProfiles(Invoices.modDirectory .. "gui/guiProfiles.xml")
        Invoices._guiProfilesLoaded = true
    end

    if g_overlayManager ~= nil
        and (g_overlayManager.textureConfigs == nil or g_overlayManager.textureConfigs.invoices == nil) then
        g_overlayManager:addTextureConfigFile(Invoices.modDirectory .. "images/gui.xml", "invoices")
    end
end

---Load mission lifecycle initiation
local function loadedMission()
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

    g_currentMission.invoicesManager = Invoices.manager

    InvoiceSettings:loadDefaultsIfMissing()
    InvoiceSettings:loadFromXMLFile()

    Invoices.manager.service:initializeReminderSystem()

    loadGuiAssets()

    InvoiceSettings:injectMenu()
end

---Apply a one-time tab list alignment reset before native tab rebuilds
local function applyTabListAlignmentFix()
    if Invoices._tabListFixApplied then
        return
    end

    if InGameMenu == nil or InGameMenu.rebuildTabList == nil then
        return
    end

    InGameMenu.rebuildTabList = Utils.prependedFunction(InGameMenu.rebuildTabList, function(self)
        if self.pagingTabList ~= nil then
            self.pagingTabList.listItemAlignmentOffset = 0
        end
    end)

    Invoices._tabListFixApplied = true
end

---Check whether the invoices InGameMenu page should be enabled
-- @return boolean isEnabled True when the page is safe to show
local function getIsInvoicesPageEnabled()
    return true
end

---Find the desired InGameMenu position before Map Overview
-- @param table inGameMenu InGameMenu instance
-- @return integer position Target page position
local function getInvoicesPagePosition(inGameMenu)
    local position = 1

    if inGameMenu.pageFrames ~= nil then
        position = #inGameMenu.pageFrames + 1

        for i, page in ipairs(inGameMenu.pageFrames) do
            if page == inGameMenu.pageMapOverview then
                return i
            end
        end
    end

    return position
end

---Add invoice frame to InGameMenu using the same controller for pageFrames and PagingElement
-- @param table inGameMenu InGameMenu instance
-- @return table|nil frame Registered frame, or nil on failure
function Invoices.addInGameMenuPage(inGameMenu)
    inGameMenu = inGameMenu or g_inGameMenu or g_gui.screenControllers[InGameMenu]

    if inGameMenu == nil then
        Logging.warning("[Invoices] Cannot add InGameMenu page: g_inGameMenu is nil")
        return nil
    end

    if inGameMenu.pageInvoices ~= nil then
        Invoices.frame = inGameMenu.pageInvoices
        return inGameMenu.pageInvoices
    end

    if inGameMenu.registerPage == nil or inGameMenu.addPageTab == nil then
        Logging.warning("[Invoices] Cannot add InGameMenu page: TabbedMenu registration API is unavailable")
        return nil
    end

    if inGameMenu.pagingElement == nil then
        Logging.warning("[Invoices] Cannot add InGameMenu page: pagingElement is nil")
        return nil
    end

    if inGameMenu.pagingElement.addPage == nil or inGameMenu.pagingElement.removePageByElement == nil then
        Logging.warning("[Invoices] Cannot add InGameMenu page: PagingElement page API is unavailable")
        return nil
    end

    local frameRefPath = Invoices.modDirectory .. "gui/InvoicesFrameRef.xml"
    local xmlFile = loadXMLFile("InvoicesFrameRefXML", frameRefPath)
    if xmlFile == nil or xmlFile == 0 then
        Logging.error("[Invoices] Failed to load FrameReference XML: %s", tostring(frameRefPath))
        return nil
    end

    applyTabListAlignmentFix()

    inGameMenu.controlIDs[IN_GAME_MENU_PAGE_FIELD] = nil
    g_gui:loadGuiRec(xmlFile, "FrameReferences", inGameMenu.pagingElement, inGameMenu)
    inGameMenu:exposeControlsAsFields(IN_GAME_MENU_PAGE_FIELD)
    inGameMenu.pagingElement:updatePageMapping()
    delete(xmlFile)

    local frame = g_gui:resolveFrameReference(inGameMenu[IN_GAME_MENU_PAGE_FIELD])
    if frame == nil or frame.initialize == nil then
        Logging.error("[Invoices] Failed to resolve InGameMenu frame reference '%s'", IN_GAME_MENU_PAGE_FIELD)
        return nil
    end

    if frame.elements == nil or frame.elements[1] == nil then
        Logging.warning("[Invoices] Cannot add InGameMenu page: frame root element is missing")
        return nil
    end

    frame.elements[1].title = g_i18n:getText("invoice_menu_title", Invoices.modName)
    inGameMenu[IN_GAME_MENU_PAGE_FIELD] = frame

    inGameMenu.pagingElement:removePageByElement(frame)

    local _, actualPosition = inGameMenu:registerPage(
        frame,
        getInvoicesPagePosition(inGameMenu),
        getIsInvoicesPageEnabled
    )

    inGameMenu:addPageTab(frame, nil, nil, IN_GAME_MENU_ICON_SLICE_ID)
    inGameMenu.pagingElement:addPage(
        string.upper(IN_GAME_MENU_PAGE_FIELD),
        frame,
        g_i18n:getText("invoice_menu_title", Invoices.modName),
        actualPosition
    )

    frame:onGuiSetupFinished()
    frame:initialize()
    inGameMenu.pagingElement:updateAbsolutePosition()
    inGameMenu.pagingElement:updatePageMapping()

    if inGameMenu.rebuildTabList ~= nil then
        inGameMenu:rebuildTabList()
    else
        Logging.warning("[Invoices] InGameMenu page added, but rebuildTabList is unavailable")
    end

    Invoices.frame = frame
    return frame
end

---Load and register invoice GUI when InGameMenu has finished map setup
-- @param table inGameMenu InGameMenu instance
-- @return table|nil frame Registered frame, or nil
function Invoices.loadInGameMenuGui(inGameMenu)
    if inGameMenu == nil then
        Logging.warning("[Invoices] Cannot load InGameMenu GUI: inGameMenu is nil")
        return nil
    end

    if inGameMenu.pageInvoices ~= nil then
        Invoices.frame = inGameMenu.pageInvoices
        return inGameMenu.pageInvoices
    end

    loadGuiAssets()

    local frameTemplate = InvoicesFrame.new(g_i18n, g_messageCenter)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesFrame.xml", IN_GAME_MENU_FRAME_NAME, frameTemplate, true)

    local frame = Invoices.addInGameMenuPage(inGameMenu)
    if frame == nil then
        return nil
    end

    local detailDialog = InvoicesDetailDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesDetailDialog.xml", "InvoicesDetailDialog", detailDialog)

    local fillTypeDialog = InvoicesFillTypeDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesFillTypeDialog.xml", "InvoicesFillTypeDialog", fillTypeDialog)

    local vehicleDialog = InvoicesVehicleDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesVehicleDialog.xml", "InvoicesVehicleDialog", vehicleDialog)

    local consumableDialog = InvoicesConsumableDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesConsumableDialog.xml", "InvoicesConsumableDialog", consumableDialog)

    local choiceDialog = InvoicesChoiceDialog.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesChoiceDialog.xml", "InvoicesChoiceDialog", choiceDialog)

    local dashboard = InvoicesMainDashboard.new(frame)
    g_gui:loadGui(Invoices.modDirectory .. "gui/InvoicesMainDashboard.xml", "InvoicesMainDashboard", dashboard)

    return frame
end

---Send initial invoice state to client on connection
-- @param table self Mission instance
-- @param table connection Network connection
-- @param table user User data
-- @param table farm Farm data
local function sendInitialClientState(self, connection, user, farm)
    if g_server == nil then return end
    -- Nil guards for late-join race condition
    if connection == nil then
        return
    end
    if Invoices.manager == nil then
        return
    end

    connection:sendEvent(InvoiceSyncEvent.new())
    connection:sendEvent(InvoiceSettingsEvent.new(g_currentMission.invoiceSettings))
end

---Save invoices to XML on savegame write
local function onSaveToXMLFile()
    if not g_currentMission:getIsServer() then return end

    if Invoices.manager then
        local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory
        if savegameFolderPath == nil then
            savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
        end
        savegameFolderPath = savegameFolderPath .. "/"
        Invoices.manager:saveToXML(savegameFolderPath, g_currentMission.invoiceSettings)
    end
end

---Initialize invoices mod: register lifecycle hooks and setup
local function initInvoices()
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)

    InGameMenu.onLoadMapFinished = Utils.appendedFunction(InGameMenu.onLoadMapFinished, function(inGameMenu)
        Invoices.loadInGameMenuGui(inGameMenu)
    end)
    
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, onSaveToXMLFile)
    
    FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, sendInitialClientState)
    
    -- Cleanup on mission end
    BaseMission.delete = Utils.appendedFunction(BaseMission.delete, function()
        if Invoices.manager then
            Invoices.manager.service:cleanupReminderSystem()
            Invoices.manager:cleanup()
            Invoices.manager = nil
        end
        InvoicesWizardState.resetAll()
        g_currentMission.invoicesFrame = nil
        g_currentMission.invoicesManager = nil
        g_currentMission.invoiceSettings = nil
        Invoices.frame = nil
        InvoiceSettings.CONTROLS = {}
        InvoiceSettings._menuInjected = false
    end)
end

initInvoices()

-- I18N extension: resolve selected mod keys without modEnv across finance, notifications, and settings UI
local InvoicesI18NTexts = {
    ["finance_invoiceIncome"] = true,
    ["finance_invoiceExpense"] = true,
    ["invoice_label_invoice"] = true,
    ["invoice_notification_new"] = true,
    ["invoice_notification_proposal"] = true,
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

---Resolve selected mod translation keys without modEnv
-- @param table self I18N instance
-- @param function superFunc Original getText function
-- @param string text Translation key
-- @param string modEnv Optional mod environment name
-- @return string text Localized text
local function invoicesGetText(self, superFunc, text, modEnv)
    if modEnv == nil and InvoicesI18NTexts[text] then
        return superFunc(self, text, modName)
    end
    return superFunc(self, text, modEnv)
end

I18N.getText = Utils.overwrittenFunction(I18N.getText, invoicesGetText)
