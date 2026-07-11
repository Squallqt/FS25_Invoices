-- Copyright © 2026 Squallqt. All rights reserved.
-- Intermediate choice dialog shown before creation: create a normal invoice, or propose
-- an invoice (to be validated by the selected farm). Sets the wizard mode then opens the dashboard.
InvoicesChoiceDialog = {}
local InvoicesChoiceDialog_mt = Class(InvoicesChoiceDialog, MessageDialog)

local function getChoiceDescription(text)
    text = text or ""

    local _, asciiColonEnd = text:find(":%s*")
    if asciiColonEnd ~= nil then
        return text:sub(asciiColonEnd + 1)
    end

    local _, fullWidthColonEnd = text:find("：%s*")
    if fullWidthColonEnd ~= nil then
        return text:sub(fullWidthColonEnd + 1)
    end

    return text
end

InvoicesChoiceDialog.CONTROLS = {
    DIALOG_CIRCLE = "dialogCircle",
    ICON_INFO_ELEMENT = "iconInfoElement",
    DIALOG_TEXT_ELEMENT = "dialogTextElement",
    TITLE_SEP = "titleSep",
    CHOICE_CREATE_HINT_TEXT = "choiceCreateHintText",
    CHOICE_PROPOSE_HINT_TEXT = "choiceProposeHintText",
}

---Creates new choice dialog instance
-- @param table target Parent target element
-- @param table? customMt Optional custom metatable
-- @return InvoicesChoiceDialog instance The new dialog instance
function InvoicesChoiceDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or InvoicesChoiceDialog_mt)
    return self
end

---Loads dialog controls
function InvoicesChoiceDialog:onLoad()
    InvoicesChoiceDialog:superClass().onLoad(self)
    self:registerControls(InvoicesChoiceDialog.CONTROLS)
end

---Called when dialog opens
function InvoicesChoiceDialog:onOpen()
    InvoicesChoiceDialog:superClass().onOpen(self)
    self:setDialogType(DialogElement.TYPE_INFO)
    self.dialogTextElement:setText(g_i18n:getText("invoice_choice_body"))
    self:resizeTitleSep()
    self.choiceCreateHintText:setText(getChoiceDescription(g_i18n:getText("invoice_choice_create_hint")))
    self.choiceProposeHintText:setText(getChoiceDescription(g_i18n:getText("invoice_choice_propose_hint")))
end

---Resizes title separator to match title text width
function InvoicesChoiceDialog:resizeTitleSep()
    InvoicesGuiUtils.resizeTitleSeparator(self.dialogTextElement, self.titleSep)
end

---Sets the wizard mode and opens the creation dashboard
-- @param string mode Wizard mode (InvoicesWizardState.MODE_CREATE / MODE_PROPOSAL)
function InvoicesChoiceDialog:openDashboard(mode)
    InvoicesWizardState.getInstance(mode)
    self:close()
    g_gui:showDialog("InvoicesMainDashboard")
end

---Handles "Create an invoice" choice (current flow unchanged)
function InvoicesChoiceDialog:onClickCreate()
    self:openDashboard(InvoicesWizardState.MODE_CREATE)
end

---Handles "Propose an invoice" choice (player will be the payer; selected farm validates)
function InvoicesChoiceDialog:onClickPropose()
    self:openDashboard(InvoicesWizardState.MODE_PROPOSAL)
end

---Closes the dialog without choosing
function InvoicesChoiceDialog:onClickBack()
    self:close()
end
