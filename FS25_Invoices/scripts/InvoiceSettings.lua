-- Copyright © 2026 Squallqt. All rights reserved.
-- Settings schema, InGameMenu control injection, and server-authoritative apply/broadcast for invoice flags.
InvoiceSettings = {}

InvoiceSettings.SETTINGS = {}
InvoiceSettings.CONTROLS = {}
InvoiceSettings._menuInjected = false

InvoiceSettings.menuItems = {
    'invoiceVatSimulated',
    'invoiceReminders',
    'invoicePenalties'
}

InvoiceSettings.SETTINGS.invoiceVatSimulated = {
    ['default'] = 2,
    ['serverOnly'] = true,
    ['values'] = { false, true },
    ['strings'] = { "ui_off", "ui_on" }
}

InvoiceSettings.SETTINGS.invoiceReminders = {
    ['default'] = 2,
    ['serverOnly'] = true,
    ['values'] = { false, true },
    ['strings'] = { "ui_off", "ui_on" }
}

InvoiceSettings.SETTINGS.invoicePenalties = {
    ['default'] = 2,
    ['serverOnly'] = true,
    ['values'] = { false, true },
    ['strings'] = { "ui_off", "ui_on" }
}

---Returns state index for a setting value
-- @param string id Setting identifier
-- @param any? value Current value to look up
-- @return integer index State index
function InvoiceSettings.getStateIndex(id, value)
    local current = value
    if current == nil and g_currentMission ~= nil and g_currentMission.invoiceSettings ~= nil then
        current = g_currentMission.invoiceSettings[id]
    end

    local values = InvoiceSettings.SETTINGS[id].values

    for i, v in ipairs(values) do
        if current == v then
            return i
        end
    end

    return InvoiceSettings.SETTINGS[id].default
end

InvoiceSettingsControls = {}

---Called when a menu option changes, applies and broadcasts
-- @param integer state New state index
-- @param table menuOption Menu option element
function InvoiceSettingsControls.onMenuOptionChanged(self, state, menuOption)
    local id = menuOption.id
    local value = InvoiceSettings.SETTINGS[id].values[state]

    if value ~= nil and g_currentMission ~= nil and g_currentMission.invoiceSettings ~= nil then
        g_currentMission.invoiceSettings[id] = value
    end

    if g_client ~= nil and g_client.getServerConnection ~= nil then
        g_client:getServerConnection():sendEvent(InvoiceSettingsEvent.new(g_currentMission.invoiceSettings))
    end
end

---Applies settings, validates, and broadcasts if authoritative
-- @param table newSettings Settings to apply
-- @param boolean isAuthoritative If true saves to XML and broadcasts
function InvoiceSettings:applySettings(newSettings, isAuthoritative)
    if g_currentMission == nil then return end

    g_currentMission.invoiceSettings = g_currentMission.invoiceSettings or {}
    local s = g_currentMission.invoiceSettings

    for _, id in ipairs(self.menuItems) do
        local def = self.SETTINGS[id]
        local candidate = nil
        if newSettings ~= nil then
            candidate = newSettings[id]
        end

        local ok = false
        for _, v in ipairs(def.values) do
            if candidate == v then
                ok = true
                break
            end
        end

        if ok then
            s[id] = candidate
        elseif s[id] == nil then
            s[id] = def.values[def.default]
        end
    end

    for _, id in ipairs(self.menuItems) do
        local ctrl = self.CONTROLS[id]
        if ctrl ~= nil then
            ctrl:setState(self.getStateIndex(id, s[id]))
        end
    end

    if g_currentMission.invoicesManager ~= nil then
        local service = g_currentMission.invoicesManager.service
        if s.invoiceReminders == true then
            service:activateReminder()
        elseif s.invoiceReminders == false then
            service:deactivateReminder()
        end
    end

    if isAuthoritative and g_currentMission:getIsServer() then
        self:saveToXMLFile()

        if g_server ~= nil then
            g_server:broadcastEvent(InvoiceSettingsEvent.new(s), false)
        end
    end
end

---Loads default settings if not already set
function InvoiceSettings:loadDefaultsIfMissing()
    if g_currentMission == nil then return end

    g_currentMission.invoiceSettings = g_currentMission.invoiceSettings or {}
    for _, id in ipairs(self.menuItems) do
        if g_currentMission.invoiceSettings[id] == nil then
            local def = self.SETTINGS[id]
            g_currentMission.invoiceSettings[id] = def.values[def.default]
        end
    end
end

---Saves current settings to savegame XML file
function InvoiceSettings:saveToXMLFile()
    if g_currentMission == nil or not g_currentMission:getIsServer() then return end
    if g_currentMission.missionInfo == nil then return end

    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory
    if savegameDirectory == nil then
        savegameDirectory = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end

    local manager = g_currentMission.invoicesManager
    if manager ~= nil and manager.repository ~= nil then
        manager.repository:saveSettingsToXML(savegameDirectory .. "/", g_currentMission.invoiceSettings or {})
    end
end

---Loads settings from savegame XML file
function InvoiceSettings:loadFromXMLFile()
    if g_currentMission == nil or not g_currentMission:getIsServer() then return end
    if g_currentMission.missionInfo == nil then return end

    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory
    if savegameDirectory == nil then
        savegameDirectory = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end

    local manager = g_currentMission.invoicesManager
    if manager ~= nil and manager.repository ~= nil then
        local loaded = manager.repository:loadSettingsFromXML(savegameDirectory .. "/")
        if loaded ~= nil then
            -- Apply loaded settings client-side without triggering a server re-save or broadcast
            self:applySettings(loaded, false)
            return
        end
    end
end

---Injects invoice settings into in-game menu
function InvoiceSettings:injectMenu()
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    if inGameMenu == nil then return end

    local settingsPage = inGameMenu.pageSettings
    if settingsPage == nil then return end

    InvoiceSettingsControls.name = settingsPage.name

    local function addBinaryMenuOption(id)
        local i18n_title = "invoice_setting_" .. id
        local i18n_tooltip = "invoice_toolTip_" .. id

        local menuOptionBox = BitmapElement.new()
        menuOptionBox:loadProfile(g_gui:getProfile("fs25_multiTextOptionContainer"), true)

        local menuBinaryOption = BinaryOptionElement.new()
        menuBinaryOption.useYesNoTexts = true
        menuBinaryOption:loadProfile(g_gui:getProfile("fs25_settingsBinaryOption"), true)
        menuBinaryOption.id = id
        menuBinaryOption.target = InvoiceSettingsControls
        menuBinaryOption:setCallback("onClickCallback", "onMenuOptionChanged")

        local setting = TextElement.new()
        setting:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOptionTitle"), true)
        setting:setText(g_i18n:getText(i18n_title))

        local toolTip = TextElement.new()
        toolTip.name = "ignore"
        toolTip:loadProfile(g_gui:getProfile("fs25_multiTextOptionTooltip"), true)
        toolTip:setText(g_i18n:getText(i18n_tooltip))

        menuBinaryOption:addElement(toolTip)
        menuOptionBox:addElement(menuBinaryOption)
        menuOptionBox:addElement(setting)

        menuBinaryOption:onGuiSetupFinished()
        setting:onGuiSetupFinished()
        toolTip:onGuiSetupFinished()

        settingsPage.gameSettingsLayout:addElement(menuOptionBox)
        menuOptionBox:onGuiSetupFinished()

        menuBinaryOption:setState(self.getStateIndex(id))

        self.CONTROLS[id] = menuBinaryOption
    end

    -- Section header
    local sectionTitle = TextElement.new()
    sectionTitle.name = "sectionHeader"
    sectionTitle:loadProfile(g_gui:getProfile("fs25_settingsSectionHeader"), true)
    sectionTitle:setText(g_i18n:getText("invoice_settings_section_title"))
    settingsPage.gameSettingsLayout:addElement(sectionTitle)
    sectionTitle:onGuiSetupFinished()

    for _, id in ipairs(self.menuItems) do
        addBinaryMenuOption(id)
    end

    settingsPage.gameSettingsLayout:invalidateLayout()
    settingsPage:updateAlternatingElements(settingsPage.gameSettingsLayout)
    settingsPage:updateGeneralSettings(settingsPage.gameSettingsLayout)

    if not InvoiceSettings._menuInjected then
        InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
            local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser
            for _, id in ipairs(InvoiceSettings.menuItems) do
                local menuOption = InvoiceSettings.CONTROLS[id]
                if menuOption ~= nil then
                    menuOption:setState(InvoiceSettings.getStateIndex(id))
                    if InvoiceSettings.SETTINGS[id].serverOnly and g_server == nil then
                        menuOption:setDisabled(not isAdmin)
                    else
                        menuOption:setDisabled(false)
                    end
                end
            end
        end)
        InvoiceSettings._menuInjected = true
    end
end
