local VanillaEnhanced = _G.VanillaEnhanced
local Training = VanillaEnhanced:GetModule("training")

local BOOKTYPE_SPELL_VALUE = BOOKTYPE_SPELL or "spell"
local BUTTON_SPACING = 3
local FAKE_SPELL_BUTTON_WIDTH = 100
local FAKE_SPELL_LABEL_WIDTH = 100
local FAKE_SPELL_NAME_HEIGHT = 28
local FAKE_SPELL_SECONDARY_HEIGHT = 13
local FAKE_SPELL_TEXT_OFFSET_X = 7
local FAKE_SPELL_TEXT_GAP = 0
local TRAINING_SKILL_LINE_TAB = ((type(MAX_SKILLLINE_TABS) == "number" and MAX_SKILLLINE_TABS) or 8) - 1
local TRAINING_TAB_TEXTURE = "Interface\\Icons\\INV_Misc_Book_09"
local STATE_COLORS = {
    trainable = { r = 0.1, g = 0.9, b = 0.25 },
    future = { r = 1, g = 0.82, b = 0 },
    ["missing-requirement"] = { r = 1, g = 0.35, b = 0.2 },
    ["missing-talent"] = { r = 1, g = 0.35, b = 0.2 },
}

Training.extensionActive = false
Training.extensionPage = 1
Training.spellbookHooksInstalled = false

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function GetSpellButton(index)
    return _G["SpellButton" .. index]
end

local function GetCurrentSkillLine()
    return SpellBookFrame and SpellBookFrame.selectedSkillLine or nil
end

function Training:IsSpellbookOnTrainingTab()
    if not SpellBookFrame or SpellBookFrame.bookType ~= BOOKTYPE_SPELL_VALUE then
        return false
    end
    return GetCurrentSkillLine() == TRAINING_SKILL_LINE_TAB
end

function Training:CanUseSpellbookExtension()
    return self:IsEnabled()
        and SpellBookFrame
        and IsShown(SpellBookFrame)
        and self:IsSpellbookOnTrainingTab()
        and self:GetPageCount() > 0
end

local function SetTextureDesaturated(texture, desaturated)
    if texture and texture.SetDesaturated then
        texture:SetDesaturated(desaturated)
    end
end

local function SetNativeNavigationButton(button, enabled)
    if not button then
        return
    end

    button:Show()
    if enabled and button.Enable then
        button:Enable()
    elseif button.Disable then
        button:Disable()
    end
end

local function ConfigureOneLineText(text, width, height)
    text:SetWidth(width)
    text:SetHeight(height)
    text:SetJustifyH("LEFT")
    if text.SetWordWrap then
        text:SetWordWrap(false)
    end
    if text.SetNonSpaceWrap then
        text:SetNonSpaceWrap(false)
    end
    if text.SetMaxLines then
        text:SetMaxLines(1)
    end
end

local function ConfigureWrappedNameText(text)
    text:SetWidth(FAKE_SPELL_LABEL_WIDTH)
    text:SetHeight(FAKE_SPELL_NAME_HEIGHT)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    if text.SetWordWrap then
        text:SetWordWrap(true)
    end
    if text.SetNonSpaceWrap then
        text:SetNonSpaceWrap(false)
    end
    if text.SetMaxLines then
        text:SetMaxLines(2)
    end
end

local function GetTextHeight(text, fallback)
    if text and text.GetStringHeight then
        local height = text:GetStringHeight()
        if height and height > 0 then
            return height
        end
    end
    return fallback
end

local function CaptureTextColor(text)
    if text and text.GetTextColor then
        local r, g, b, a = text:GetTextColor()
        return { r = r or 1, g = g or 1, b = b or 1, a = a or 1 }
    end
    return { r = 1, g = 1, b = 1, a = 1 }
end

local function SetFontStringColor(text, color)
    if text and color then
        text:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
end

local function GetStateColor(state)
    return STATE_COLORS[state] or { r = 1, g = 1, b = 1 }
end

local function IsSpellUnaffordable(spell)
    return spell
        and spell.cost
        and spell.cost > 0
        and type(GetMoney) == "function"
        and GetMoney() < spell.cost
end

local function ApplyButtonColors(button, spell)
    button.name:SetTextColor(1, 0.82, 0)
    SetFontStringColor(button.rank, button.rankDefaultColor)
    SetFontStringColor(button.level, button.levelDefaultColor)
    SetTextureDesaturated(button.icon, true)
    if IsSpellUnaffordable(spell) then
        button.icon:SetVertexColor(1, 0.25, 0.25)
    else
        button.icon:SetVertexColor(1, 1, 1)
    end
end

function Training:SetNativeSpellTooltip(tooltip, spell)
    if tooltip.SetSpellByID then
        tooltip:SetSpellByID(spell.id)
    elseif tooltip.SetHyperlink then
        tooltip:SetHyperlink("spell:" .. spell.id)
    else
        tooltip:SetText(spell.name or "")
    end
end

function Training:AddTrainingTooltipDetails(tooltip, spell)
    local stateColor = GetStateColor(spell.state)
    tooltip:AddLine(" ")
    tooltip:AddLine(self:GetStateLabel(spell.state, spell.level), stateColor.r, stateColor.g, stateColor.b, true)
    if spell.cost and spell.cost > 0 and type(GetCoinTextureString) == "function" then
        if IsSpellUnaffordable(spell) then
            tooltip:AddLine(T("training.tooltip.cost", { cost = GetCoinTextureString(spell.cost) }), 1, 0.35, 0.35, true)
        else
            tooltip:AddLine(T("training.tooltip.cost", { cost = GetCoinTextureString(spell.cost) }), 1, 1, 1, true)
        end
    end
    tooltip:Show()
end

function Training:ShowTrainingTooltip(owner, spell)
    if not GameTooltip or not spell then
        return
    end

    self.tooltipOwner = owner
    self.tooltipSpellId = spell.id
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    self:SetNativeSpellTooltip(GameTooltip, spell)
    self:AddTrainingTooltipDetails(GameTooltip, spell)

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if Training.tooltipOwner ~= owner or Training.tooltipSpellId ~= spell.id then
                return
            end
            if owner.IsMouseOver and not owner:IsMouseOver() then
                return
            end
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            Training:SetNativeSpellTooltip(GameTooltip, spell)
            Training:AddTrainingTooltipDetails(GameTooltip, spell)
        end)
    end
end

local function LinkSpell(spell)
    if not spell or not spell.link then
        return
    end

    local window = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if window then
        window:Insert(spell.link)
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(spell.link)
    end
end

function Training:CreateFakeSpellButton(index, nativeButton)
    local button = CreateFrame("Button", "VanillaEnhancedTrainingSpellButton" .. index, SpellBookFrame)
    button:SetPoint("TOPLEFT", nativeButton, "TOPLEFT", 0, 0)
    button:SetSize(FAKE_SPELL_BUTTON_WIDTH, 46)
    button:SetFrameLevel((nativeButton:GetFrameLevel() or SpellBookFrame:GetFrameLevel() or 0) + 10)
    button:RegisterForClicks("LeftButtonUp")
    button:Hide()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    icon:SetSize(36, 36)

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ConfigureWrappedNameText(name)

    local rank = button:CreateFontString(nil, "OVERLAY", "NewSubSpellFont")
    ConfigureOneLineText(rank, FAKE_SPELL_LABEL_WIDTH, FAKE_SPELL_SECONDARY_HEIGHT)

    local level = button:CreateFontString(nil, "OVERLAY", "NewSubSpellFont")
    level:SetPoint("TOPLEFT", rank, "BOTTOMLEFT", 0, -BUTTON_SPACING)
    ConfigureOneLineText(level, FAKE_SPELL_LABEL_WIDTH, FAKE_SPELL_SECONDARY_HEIGHT)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetAllPoints(icon)
    highlight:SetBlendMode("ADD")

    button.icon = icon
    button.name = name
    button.rank = rank
    button.level = level
    button.rankDefaultColor = CaptureTextColor(rank)
    button.levelDefaultColor = CaptureTextColor(level)

    button:SetScript("OnEnter", function(self)
        Training:ShowTrainingTooltip(self, self.trainingSpell)
    end)
    button:SetScript("OnLeave", function()
        Training.tooltipOwner = nil
        Training.tooltipSpellId = nil
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnClick", function(self)
        if IsShiftKeyDown and IsShiftKeyDown() then
            LinkSpell(self.trainingSpell)
        end
    end)

    return button
end

function Training:PositionFakeSpellText(button)
    local nameHeight = GetTextHeight(button.name, 14)
    if nameHeight > FAKE_SPELL_NAME_HEIGHT then
        nameHeight = FAKE_SPELL_NAME_HEIGHT
    end

    local secondaryHeight = GetTextHeight(button.rank, FAKE_SPELL_SECONDARY_HEIGHT)
    local totalHeight = nameHeight + secondaryHeight + FAKE_SPELL_TEXT_GAP
    local topOffset = math.floor((totalHeight / 2) + 0.5)

    button.name:ClearAllPoints()
    button.name:SetHeight(nameHeight)
    button.name:SetPoint("TOPLEFT", button.icon, "RIGHT", FAKE_SPELL_TEXT_OFFSET_X, topOffset)

    button.rank:ClearAllPoints()
    button.rank:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -FAKE_SPELL_TEXT_GAP)
end

function Training:EnsureSpellbookOverlay()
    if self.spellbookOverlay then
        return true
    end
    if not SpellBookFrame then
        return false
    end

    local overlay = CreateFrame("Frame", "VanillaEnhancedTrainingSpellbookOverlay", SpellBookFrame)
    overlay:SetAllPoints(SpellBookFrame)
    overlay:SetFrameLevel((SpellBookFrame:GetFrameLevel() or 0) + 20)
    overlay:Hide()

    local fakeButtons = {}
    local perPage = self:GetSpellsPerPage()
    for index = 1, perPage do
        local nativeButton = GetSpellButton(index)
        if nativeButton then
            fakeButtons[index] = self:CreateFakeSpellButton(index, nativeButton)
        end
    end

    local nextOverlay = CreateFrame("Button", "VanillaEnhancedTrainingNextPageButton", SpellBookFrame)
    nextOverlay:SetSize(44, 34)
    nextOverlay:SetFrameLevel((SpellBookNextPageButton and SpellBookNextPageButton:GetFrameLevel() or 0) + 20)
    nextOverlay:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    if SpellBookNextPageButton then
        nextOverlay:SetPoint("CENTER", SpellBookNextPageButton, "CENTER", 0, 0)
    else
        nextOverlay:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", -70, 82)
    end
    nextOverlay:SetScript("OnClick", function()
        Training:GoToNextTrainingPage()
    end)
    nextOverlay:Hide()

    local prevOverlay = CreateFrame("Button", "VanillaEnhancedTrainingPrevPageButton", SpellBookFrame)
    prevOverlay:SetSize(44, 34)
    prevOverlay:SetFrameLevel((SpellBookPrevPageButton and SpellBookPrevPageButton:GetFrameLevel() or 0) + 20)
    prevOverlay:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    if SpellBookPrevPageButton then
        prevOverlay:SetPoint("CENTER", SpellBookPrevPageButton, "CENTER", 0, 0)
    else
        prevOverlay:SetPoint("BOTTOMLEFT", SpellBookFrame, "BOTTOMLEFT", 70, 82)
    end
    prevOverlay:SetScript("OnClick", function()
        Training:GoToPreviousTrainingPage()
    end)
    prevOverlay:Hide()

    self.spellbookOverlay = overlay
    self.fakeSpellButtons = fakeButtons
    self.nextPageOverlay = nextOverlay
    self.prevPageOverlay = prevOverlay
    return true
end

function Training:SetNativeSpellButtonsVisible(visible)
    for index = 1, self:GetSpellsPerPage() do
        local button = GetSpellButton(index)
        if button then
            if visible then
                button:Show()
            else
                button:Hide()
            end
        end
    end
end

function Training:HideFakeButtons()
    for _, button in ipairs(self.fakeSpellButtons or {}) do
        button.trainingSpell = nil
        button:Hide()
    end
end

function Training:RenderFakeButton(button, spell)
    if not spell then
        button.trainingSpell = nil
        button:Hide()
        return
    end

    button.trainingSpell = spell
    button.icon:SetTexture(spell.icon)
    button.name:SetText(spell.name)
    if spell.rank and spell.rank ~= "" then
        button.rank:SetText(spell.rank)
        button.level:SetText("")
    else
        button.rank:SetText(T("training.spellbook.level", { level = spell.level }))
        button.level:SetText("")
    end
    self:PositionFakeSpellText(button)
    ApplyButtonColors(button, spell)
    button:Show()
end

function Training:RenderTrainingPage()
    if not self:EnsureSpellbookOverlay() then
        return
    end

    local page = self:GetPage(self.extensionPage) or {}
    for index, button in ipairs(self.fakeSpellButtons or {}) do
        self:RenderFakeButton(button, page[index])
    end

    if self.spellbookOverlay then
        self.spellbookOverlay:Show()
    end
    self:SetNativeSpellButtonsVisible(true)

    local trainingPages = self:GetPageCount()
    if SpellBookPageText then
        SpellBookPageText:SetText(T("training.spellbook.page", {
            page = self.extensionPage,
            pages = trainingPages,
        }))
    end

    if self.prevPageOverlay then
        if self.extensionPage > 1 then
            SetNativeNavigationButton(SpellBookPrevPageButton, true)
            self.prevPageOverlay:Show()
        else
            SetNativeNavigationButton(SpellBookPrevPageButton, false)
            self.prevPageOverlay:Hide()
        end
    end
    if self.nextPageOverlay then
        if self.extensionPage < trainingPages then
            SetNativeNavigationButton(SpellBookNextPageButton, true)
            self.nextPageOverlay:Show()
        else
            SetNativeNavigationButton(SpellBookNextPageButton, false)
            self.nextPageOverlay:Hide()
        end
    end
end

function Training:HideTrainingPages(refreshNative)
    self.extensionActive = false
    self.extensionPage = 1
    self:HideFakeButtons()
    if self.spellbookOverlay then
        self.spellbookOverlay:Hide()
    end
    if self.prevPageOverlay then
        self.prevPageOverlay:Hide()
    end
    if self.nextPageOverlay then
        self.nextPageOverlay:Hide()
    end

    if not InCombat() then
        self:SetNativeSpellButtonsVisible(true)
        if refreshNative and SpellBookFrame then
            if SpellBookFrame.Update then
                SpellBookFrame:Update()
            elseif type(SpellBookFrame_Update) == "function" then
                SpellBookFrame_Update()
            end
        end
    end
end

function Training:EnterTrainingPages()
    if InCombat() then
        VanillaEnhanced:PrintMessage(T("training.error.combat"))
        return
    end
    if not self:CanUseSpellbookExtension() then
        return
    end

    self.extensionActive = true
    self.extensionPage = 1
    self:RenderTrainingPage()
end

function Training:GoToNextTrainingPage()
    if self.extensionActive then
        if self.extensionPage < self:GetPageCount() then
            self.extensionPage = self.extensionPage + 1
            self:RenderTrainingPage()
        end
        return
    end

    self:EnterTrainingPages()
end

function Training:GoToPreviousTrainingPage()
    if not self.extensionActive then
        return
    end

    if self.extensionPage > 1 then
        self.extensionPage = self.extensionPage - 1
        self:RenderTrainingPage()
        return
    end

    self:RenderTrainingPage()
end

function Training:UpdateSpellbook()
    if not self:EnsureSpellbookOverlay() then
        return
    end

    if self.extensionActive then
        if InCombat() then
            if self.prevPageOverlay then
                self.prevPageOverlay:Hide()
            end
            if self.nextPageOverlay then
                self.nextPageOverlay:Hide()
            end
        elseif self:CanUseSpellbookExtension() then
            local count = self:GetPageCount()
            if self.extensionPage > count then
                self.extensionPage = count
            end
            if count > 0 then
                self:RenderTrainingPage()
            else
                self:HideTrainingPages(false)
            end
        else
            self:HideTrainingPages(false)
        end
        return
    end

    if self:CanUseSpellbookExtension() then
        self.extensionActive = true
        if self.extensionPage < 1 then
            self.extensionPage = 1
        end
        self:RenderTrainingPage()
        return
    end

    self:HideFakeButtons()
    if self.spellbookOverlay then
        self.spellbookOverlay:Hide()
    end
    if self.prevPageOverlay then
        self.prevPageOverlay:Hide()
    end

    if self.nextPageOverlay then
        self.nextPageOverlay:Hide()
    end

end

function Training:UpdateTrainingTab()
    if not SpellBookFrame then
        return
    end

    local tab = _G["SpellBookSkillLineTab" .. TRAINING_SKILL_LINE_TAB]
    if not tab then
        return
    end

    local enabled = self:IsEnabled() and self:GetPageCount() > 0
    if enabled then
        if tab.SetID then
            tab:SetID(TRAINING_SKILL_LINE_TAB)
        end
        if tab.SetNormalTexture then
            tab:SetNormalTexture(TRAINING_TAB_TEXTURE)
        end
        tab.tooltip = T("training.spellbook.tab")
        tab:Show()
    elseif GetCurrentSkillLine() == TRAINING_SKILL_LINE_TAB then
        if SpellBookFrame then
            SpellBookFrame.selectedSkillLine = 1
            if SpellBookFrame.Update then
                SpellBookFrame:Update()
            elseif type(SpellBookFrame_Update) == "function" then
                SpellBookFrame_Update()
            end
        end
        tab:Hide()
        return
    else
        tab:Hide()
    end

    if enabled and self:IsSpellbookOnTrainingTab() then
        tab:SetChecked(true)
        if ShowAllSpellRanksCheckbox then
            ShowAllSpellRanksCheckbox:Hide()
        end
    elseif tab.SetChecked then
        tab:SetChecked(false)
    end
end

function Training:InstallSpellbookOverlay()
    if self.spellbookHooksInstalled then
        self:EnsureSpellbookOverlay()
        return
    end
    if not SpellBookFrame then
        return
    end

    self:EnsureSpellbookOverlay()

    if SpellBookFrame.HookScript then
        SpellBookFrame:HookScript("OnShow", function()
            Training:UpdateTrainingTab()
            Training:UpdateSpellbook()
        end)
        SpellBookFrame:HookScript("OnHide", function()
            Training:HideTrainingPages(false)
        end)
    end

    if type(hooksecurefunc) == "function" then
        if SpellBookFrame.UpdateSkillLineTabs then
            pcall(hooksecurefunc, SpellBookFrame, "UpdateSkillLineTabs", function()
                Training:UpdateTrainingTab()
                Training:UpdateSpellbook()
            end)
        end
        if SpellBookFrame.Update then
            pcall(hooksecurefunc, SpellBookFrame, "Update", function()
                Training:UpdateTrainingTab()
                Training:UpdateSpellbook()
            end)
        elseif type(SpellBookFrame_Update) == "function" then
            pcall(hooksecurefunc, "SpellBookFrame_Update", function()
                Training:UpdateTrainingTab()
                Training:UpdateSpellbook()
            end)
        end
    end

    for index = 1, MAX_SKILLLINE_TABS or 8 do
        local tab = _G["SpellBookSkillLineTab" .. index]
        if tab and tab.HookScript then
            tab:HookScript("OnClick", function()
                if tab.GetID and tab:GetID() ~= TRAINING_SKILL_LINE_TAB then
                    Training:HideTrainingPages(false)
                end
                Training:UpdateTrainingTab()
                Training:UpdateSpellbook()
            end)
        end
    end

    self.spellbookHooksInstalled = true
    self:UpdateTrainingTab()
    self:UpdateSpellbook()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:SetScript("OnEvent", function()
    Training:InstallSpellbookOverlay()
    Training:UpdateSpellbook()
end)
