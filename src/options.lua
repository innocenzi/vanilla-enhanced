local VanillaEnhanced = _G.VanillaEnhanced

local moduleChecks = {}
local settingChecks = {}
local addonSettingChecks = {}
local dropdowns = {}
local sliders = {}
local optionPanels = {}
local moduleTitleKeys = {}
local categoryTitleKeys = {}
local OPTION_WITH_HELP_OFFSET = -15
local OPTION_INDENT_WIDTH = 18
local OPTION_HELP_WIDTH = 430
local OPTION_SECTION_OFFSET_Y = -36
local CHECK_TEXT_OFFSET_X = 3
local CHECK_TEXT_LEFT_FALLBACK = 27
local SCROLL_BAR_WIDTH = 28
local SCROLL_BOTTOM_PADDING = 24
local SLIDER_THUMB_EDGE_PADDING = 13
local SLIDER_VISIBLE_OFFSET_X = 10

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function GetDefaultConfigurationPresetKey()
    if VanillaEnhanced.GetDefaultConfigurationPresetKey then
        return VanillaEnhanced:GetDefaultConfigurationPresetKey()
    end
    return "explorer"
end

local function GetPanelContent(panel)
    return panel.optionContent or panel
end

local function UpdatePanelScrollContentSize(panel)
    local scrollFrame = panel.optionScrollFrame
    local content = panel.optionContent
    if not scrollFrame or not content then
        return
    end

    local width = scrollFrame:GetWidth()
    if width and width > 0 then
        content:SetWidth(width)
    end

    local visibleHeight = scrollFrame:GetHeight() or 1
    local contentHeight = visibleHeight
    local top = content.GetTop and content:GetTop() or nil
    local bottomAnchor = panel.optionBottomAnchor
    local bottom = bottomAnchor and bottomAnchor.GetBottom and bottomAnchor:GetBottom() or nil

    if top and bottom then
        local measuredHeight = math.ceil(top - bottom + SCROLL_BOTTOM_PADDING)
        if measuredHeight > contentHeight then
            contentHeight = measuredHeight
        end
    end

    if contentHeight > 0 then
        content:SetHeight(contentHeight)
    end
end

local function GetCheckText(check)
    return check.Text or _G[check:GetName() .. "Text"]
end

local function IsCheckEnabled(check)
    if check.IsEnabled then
        local enabled = check:IsEnabled()
        return enabled ~= false and enabled ~= 0
    end
    return true
end

local function ClickCheck(check)
    if not IsCheckEnabled(check) then
        return
    end

    if check.Click then
        check:Click()
        return
    end

    check:SetChecked(not check:GetChecked())
    local onClick = check.GetScript and check:GetScript("OnClick")
    if onClick then
        onClick(check)
    end
end

local function RegisterCheckClickTarget(check, target)
    check.clickTargets = check.clickTargets or {}
    check.clickTargets[#check.clickTargets + 1] = target
    target:EnableMouse(true)
    target:SetScript("OnClick", function()
        ClickCheck(check)
    end)
end

local function GetRegionWidth(region, fallback)
    local width = region.GetStringWidth and region:GetStringWidth() or nil
    if not width or width <= 0 then
        width = region.GetWidth and region:GetWidth() or fallback
    end
    return width or fallback
end

local function GetRegionHeight(region, fallback)
    local height = region.GetStringHeight and region:GetStringHeight() or nil
    if not height or height <= 0 then
        height = region.GetHeight and region:GetHeight() or fallback
    end
    return height or fallback
end

local function GetOptionIndentLevel(option)
    return option and option.optionIndentLevel or 0
end

local function SetOptionIndentLevel(option, indentLevel)
    option.optionIndentLevel = indentLevel or 0
    return option
end

local function GetOptionIndentOffset(option, anchor)
    return (GetOptionIndentLevel(option) - GetOptionIndentLevel(anchor)) * OPTION_INDENT_WIDTH
end

local function GetOptionHelpWidth(option)
    local width = OPTION_HELP_WIDTH - (GetOptionIndentLevel(option) * OPTION_INDENT_WIDTH)
    if width < 300 then
        width = 300
    end
    return width
end

local function CreateCheckTextClickTarget(check, text)
    if not text or not check.GetParent then
        return
    end

    local target = CreateFrame("Button", nil, check:GetParent())
    local width = GetRegionWidth(text, 1)
    local height = GetRegionHeight(text, 12)
    target:SetPoint("LEFT", text, "LEFT", 0, 0)
    target:SetSize(math.max(1, width), math.max(12, height))
    target:SetFrameLevel((check:GetFrameLevel() or 0) + 1)
    RegisterCheckClickTarget(check, target)
end

local function CreateHelpClickTarget(help, check)
    if not help or not check or not check.GetParent then
        return
    end

    local target = CreateFrame("Button", nil, check:GetParent())
    local width = GetRegionWidth(help, 430)
    local height = GetRegionHeight(help, 12)
    target:SetPoint("TOPLEFT", help, "TOPLEFT", 0, 0)
    target:SetSize(math.max(1, width), math.max(12, height))
    target:SetFrameLevel((check:GetFrameLevel() or 0) + 1)
    RegisterCheckClickTarget(check, target)
end

local function ConfigureCheckText(check, label)
    local text = GetCheckText(check)
    if not text then
        return
    end

    text:SetText(label)
    text:ClearAllPoints()
    text:SetPoint("LEFT", check, "RIGHT", CHECK_TEXT_OFFSET_X, 0)
    CreateCheckTextClickTarget(check, text)
end

local function ApplyModuleEnabled(moduleKey, enabled)
    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.SetEnabled then
        module:SetEnabled(enabled)
    else
        VanillaEnhanced:SetModuleEnabled(moduleKey, enabled)
    end
end

local function GetModuleOptionSettings(moduleKey)
    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.GetSettings then
        return module:GetSettings()
    end
    return VanillaEnhanced:GetModuleSettings(moduleKey, {
        enabled = true,
    })
end

local function ApplyModuleSetting(moduleKey, settingKey, value)
    local settings = GetModuleOptionSettings(moduleKey)
    settings[settingKey] = not not value

    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.Update then
        module:Update()
    end

    if VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

local function ApplyAddonSetting(settingKey, value)
    local settings = VanillaEnhanced:GetSettings()
    settings[settingKey] = not not value

    if VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

local function ApplyAddonDropdownSetting(settingKey, value)
    local settings = VanillaEnhanced:GetSettings()
    if settingKey == "locale" and VanillaEnhanced.SetLocaleKey then
        VanillaEnhanced:SetLocaleKey(value)
    else
        settings[settingKey] = value
    end

    if VanillaEnhanced.RefreshLocalizedOptions then
        VanillaEnhanced:RefreshLocalizedOptions()
    elseif VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

local function ResetAddonSettings()
    if VanillaEnhanced.ResetSettings then
        VanillaEnhanced:ResetSettings()
    end
    VanillaEnhanced:PrintMessage(T("options.main.resetSettings.done"))
end

local function ConfirmResetAddonSettings()
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs.VANILLAENHANCED_RESET_SETTINGS = StaticPopupDialogs.VANILLAENHANCED_RESET_SETTINGS or {
            text = T("options.main.resetSettings.confirm"),
            button1 = T("options.main.resetSettings.accept"),
            button2 = CANCEL or T("options.main.resetSettings.cancel"),
            OnAccept = ResetAddonSettings,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopupDialogs.VANILLAENHANCED_RESET_SETTINGS.text = T("options.main.resetSettings.confirm")
        StaticPopupDialogs.VANILLAENHANCED_RESET_SETTINGS.button1 = T("options.main.resetSettings.accept")
        StaticPopupDialogs.VANILLAENHANCED_RESET_SETTINGS.button2 = CANCEL or T("options.main.resetSettings.cancel")
        StaticPopup_Show("VANILLAENHANCED_RESET_SETTINGS")
        return
    end

    ResetAddonSettings()
end

local function ApplyConfigurationPreset()
    if not VanillaEnhanced.ApplyConfigurationPreset then
        return
    end

    local settings = VanillaEnhanced:GetSettings()
    local presetKey = settings.configurationPreset
    if VanillaEnhanced.NormalizeConfigurationPresetKey then
        presetKey = VanillaEnhanced:NormalizeConfigurationPresetKey(presetKey)
    end

    local appliedPresetKey = VanillaEnhanced:ApplyConfigurationPreset(presetKey)
    local presetLabel = VanillaEnhanced.GetConfigurationPresetLabel
        and VanillaEnhanced:GetConfigurationPresetLabel(appliedPresetKey)
        or appliedPresetKey
    VanillaEnhanced:PrintMessage(T("options.main.configurationPreset.applied", { preset = presetLabel }))
end

local function ConfirmClearMapMarkers()
    local map = VanillaEnhanced:GetModule("map")
    if map and map.ConfirmClearMarkers then
        map:ConfirmClearMarkers()
    end
end

local function IsSettingEnabled(moduleKey, settingKey)
    local settings = GetModuleOptionSettings(moduleKey)
    return settings[settingKey] ~= false
end

local function ApplyModuleDropdownSetting(moduleKey, settingKey, value)
    local settings = GetModuleOptionSettings(moduleKey)
    settings[settingKey] = value

    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.Update then
        module:Update()
    end

    if VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

local function NormalizeSliderValue(value, minValue, maxValue, step, defaultValue)
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or minValue
    step = tonumber(step) or 1
    defaultValue = tonumber(defaultValue)
    if defaultValue == nil then
        defaultValue = minValue
    end

    value = tonumber(value)
    if value == nil then
        value = defaultValue
    end

    if maxValue < minValue then
        maxValue = minValue
    end
    if value < minValue then
        value = minValue
    elseif value > maxValue then
        value = maxValue
    end

    if step > 0 then
        value = minValue + (math.floor(((value - minValue) / step) + 0.5) * step)
        if value < minValue then
            value = minValue
        elseif value > maxValue then
            value = maxValue
        end
    end

    return value
end

local function FormatSliderValue(slider, value)
    if slider.valueKey then
        return T(slider.valueKey, { value = value })
    end
    return tostring(value)
end

local function UpdateSliderValueText(slider, value)
    if slider.valueText then
        slider.valueText:SetText(FormatSliderValue(slider, value))
    end
end

local function SetSliderTrackColor(slider, enabled)
    if not slider.trackBackground then
        return
    end

    local borderAlpha = enabled and 0.85 or 0.35
    if slider.trackFill then
        slider.trackFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        if slider.trackFill.SetVertexColor then
            slider.trackFill:SetVertexColor(0, 0, 0, enabled and 0.55 or 0.35)
        end
    end
    if slider.trackBorder then
        for _, border in pairs(slider.trackBorder) do
            border:SetTexture("Interface\\Buttons\\WHITE8X8")
            if border.SetVertexColor then
                border:SetVertexColor(0.65, 0.65, 0.6, borderAlpha * 0.75)
            end
        end
    end
    if slider.trackBackground.SetBackdropColor then
        slider.trackBackground:SetBackdropColor(0, 0, 0, enabled and 0.55 or 0.35)
    end
    if slider.trackBackground.SetBackdropBorderColor then
        slider.trackBackground:SetBackdropBorderColor(0.65, 0.65, 0.6, borderAlpha)
    end

    if slider.trackShine and slider.trackShine.SetVertexColor then
        slider.trackShine:SetVertexColor(1, 1, 1, enabled and 0.12 or 0.04)
    end
end

local function ApplyModuleSliderSetting(moduleKey, settingKey, value)
    local settings = GetModuleOptionSettings(moduleKey)
    settings[settingKey] = value

    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.Update then
        module:Update()
    end

    if VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

local function SetCheckEnabled(check, enabled)
    if check.SetEnabled then
        check:SetEnabled(enabled)
    elseif enabled and check.Enable then
        check:Enable()
    elseif check.Disable then
        check:Disable()
    end
    for _, target in ipairs(check.clickTargets or {}) do
        if target.SetEnabled then
            target:SetEnabled(enabled)
        end
    end
end

local function SetSliderEnabled(slider, enabled)
    if slider.SetEnabled then
        slider:SetEnabled(enabled)
    elseif enabled and slider.Enable then
        slider:Enable()
    elseif slider.Disable then
        slider:Disable()
    end

    if slider.EnableMouse then
        slider:EnableMouse(enabled)
    end

    local red, green, blue = 0.5, 0.5, 0.5
    if enabled then
        red, green, blue = 1, 1, 1
    end

    if slider.labelText then
        slider.labelText:SetTextColor(red, green, blue)
    end
    if slider.valueText then
        slider.valueText:SetTextColor(red, green, blue)
    end
    if slider.lowText then
        slider.lowText:SetTextColor(red, green, blue)
    end
    if slider.highText then
        slider.highText:SetTextColor(red, green, blue)
    end
    if slider.trackBackground then
        SetSliderTrackColor(slider, enabled)
    end
end

local function CreatePanel(name, titleText)
    local panel = CreateFrame("Frame", name, UIParent)
    panel.name = titleText

    local scrollFrame = CreateFrame("ScrollFrame", name .. "ScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 0)

    local content = CreateFrame("Frame", name .. "Content", scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    panel.optionScrollFrame = scrollFrame
    panel.optionContent = content

    scrollFrame:SetScript("OnShow", function(self)
        UpdatePanelScrollContentSize(self:GetParent())
    end)
    scrollFrame:SetScript("OnSizeChanged", function(self)
        UpdatePanelScrollContentSize(self:GetParent())
    end)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(titleText)
    panel.title = title

    return panel
end

local function CreateSubtitle(panel, text)
    local subtitle = GetPanelContent(panel):CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(430)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(text)
    return subtitle
end

local function AnchorBelowHelp(check, anchor, indentLevel)
    local bottomAnchor = anchor.optionHelpBottomAnchor or anchor

    if indentLevel then
        SetOptionIndentLevel(check, indentLevel)
    end

    check:ClearAllPoints()
    check:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT", GetOptionIndentOffset(check, anchor), OPTION_WITH_HELP_OFFSET)
end

local function CreateModuleEnabledCheck(panel, name, moduleKey, label, anchor)
    local check = CreateFrame("CheckButton", name, GetPanelContent(panel), "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    check.moduleKey = moduleKey

    ConfigureCheckText(check, label)

    check:SetScript("OnClick", function(self)
        ApplyModuleEnabled(self.moduleKey, self:GetChecked())
    end)

    moduleChecks[moduleKey] = check
    return check
end

local function CreateModuleSettingCheck(panel, name, moduleKey, settingKey, label, anchor, indentLevel)
    local check = CreateFrame("CheckButton", name, GetPanelContent(panel), "InterfaceOptionsCheckButtonTemplate")
    SetOptionIndentLevel(check, indentLevel or GetOptionIndentLevel(anchor))
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", GetOptionIndentOffset(check, anchor), -12)
    check.moduleKey = moduleKey
    check.settingKey = settingKey

    ConfigureCheckText(check, label)

    check:SetScript("OnClick", function(self)
        ApplyModuleSetting(self.moduleKey, self.settingKey, self:GetChecked())
    end)

    table.insert(settingChecks, check)
    return check
end

local function CreateAddonSettingCheck(panel, name, settingKey, label, anchor)
    local check = CreateFrame("CheckButton", name, GetPanelContent(panel), "InterfaceOptionsCheckButtonTemplate")
    local bottomAnchor = anchor.optionHelpBottomAnchor or anchor
    check:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT", 0, -12)
    check.settingKey = settingKey

    ConfigureCheckText(check, label)

    check:SetScript("OnClick", function(self)
        ApplyAddonSetting(self.settingKey, self:GetChecked())
    end)

    table.insert(addonSettingChecks, check)
    return check
end

local function CreateAddonActionButton(panel, name, label, anchor, onClick, option)
    local button = CreateFrame("Button", name, GetPanelContent(panel), "UIPanelButtonTemplate")
    local bottomAnchor = anchor.optionHelpBottomAnchor or anchor
    if option and option.inlineWithPrevious then
        button:SetPoint("LEFT", anchor, "RIGHT", option.inlineOffsetX or 0, option.inlineOffsetY or 2)
        button.optionHelpBottomAnchor = bottomAnchor
        panel.optionBottomAnchor = bottomAnchor
    else
        button:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT", 0, -16)
        panel.optionBottomAnchor = button
    end
    button:SetSize(option and option.width or 140, 22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    button.optionHelpPointAnchor = button
    button.optionHelpLeftOffset = -1
    button.optionHelpTopOffset = -4
    return button
end

local function SetSettingCheckEnabledWhen(check, moduleKey, settingKey)
    check.enabledWhen = function()
        return IsSettingEnabled(moduleKey, settingKey)
    end
    return check
end

local function HasDropdownOptionDescriptions(dropdown)
    for _, option in ipairs(dropdown.options or {}) do
        if option.description and option.description ~= "" then
            return true
        end
    end
    return false
end

local function ShowDropdownTooltip(dropdown, owner)
    if not GameTooltip or not dropdown then
        return
    end

    local hasDescriptions = HasDropdownOptionDescriptions(dropdown)
    if not hasDescriptions and (not dropdown.helpText or dropdown.helpText == "") then
        return
    end

    GameTooltip:SetOwner(owner or dropdown, "ANCHOR_RIGHT")
    GameTooltip:SetText(dropdown.tooltipTitle or dropdown.label or "", 1, 0.82, 0)

    if dropdown.helpText and dropdown.helpText ~= "" then
        GameTooltip:AddLine(dropdown.helpText, 1, 1, 1, true)
    end

    if hasDescriptions then
        if dropdown.helpText and dropdown.helpText ~= "" then
            GameTooltip:AddLine(" ")
        end

        local addedDescription = false
        for _, option in ipairs(dropdown.options or {}) do
            if option.description and option.description ~= "" then
                if addedDescription then
                    GameTooltip:AddLine(" ")
                end
                GameTooltip:AddLine(option.label, 1, 1, 1, true)
                GameTooltip:AddLine(option.description, 1, 0.82, 0, true)
                addedDescription = true
            end
        end
    end

    GameTooltip:Show()
end

local function HideDropdownTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function HookDropdownTooltipTarget(target, dropdown)
    if not target or target.vanillaEnhancedDropdownTooltipHooked then
        return
    end

    target.vanillaEnhancedDropdownTooltipHooked = true
    if target.EnableMouse then
        target:EnableMouse(true)
    end

    local function onEnter(self)
        ShowDropdownTooltip(dropdown, self)
    end
    local function onLeave()
        HideDropdownTooltip()
    end

    if target.HookScript then
        target:HookScript("OnEnter", onEnter)
        target:HookScript("OnLeave", onLeave)
        return
    end

    local oldOnEnter = target.GetScript and target:GetScript("OnEnter") or nil
    local oldOnLeave = target.GetScript and target:GetScript("OnLeave") or nil
    target:SetScript("OnEnter", function(self, ...)
        if oldOnEnter then
            oldOnEnter(self, ...)
        end
        onEnter(self)
    end)
    target:SetScript("OnLeave", function(self, ...)
        if oldOnLeave then
            oldOnLeave(self, ...)
        end
        onLeave()
    end)
end

local function ConfigureDropdownTooltip(dropdown, name)
    HookDropdownTooltipTarget(dropdown, dropdown)
    HookDropdownTooltipTarget(_G[name .. "Button"], dropdown)
end

local function GetDropdownSettings(dropdown)
    if dropdown.settingScope == "addon" then
        return VanillaEnhanced:GetSettings()
    end
    return GetModuleOptionSettings(dropdown.moduleKey)
end

local function IsDropdownOptionSelected(dropdown, selected, optionValue)
    if selected == optionValue then
        return true
    end
    return selected == nil and dropdown.defaultValue == optionValue
end

local function NormalizeDropdownSelectedValue(dropdown, selected)
    if dropdown.defaultValue == nil or selected == nil then
        return selected
    end

    for _, option in ipairs(dropdown.options or {}) do
        if option.value == selected then
            return selected
        end
    end

    return dropdown.defaultValue
end

local function CreateDropdown(panel, name, settingScope, moduleKey, settingKey, label, helpText, options, anchor, indentLevel, defaultValue, optionsProvider)
    local content = GetPanelContent(panel)
    local dropdownIndentAnchor = anchor
    local labelText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    labelText:SetText(label)

    local dropdown = CreateFrame("Frame", name, content, "UIDropDownMenuTemplate")
    SetOptionIndentLevel(dropdown, indentLevel or GetOptionIndentLevel(anchor))
    labelText:SetPoint(
        "TOPLEFT",
        dropdownIndentAnchor.optionHelpBottomAnchor or dropdownIndentAnchor,
        "BOTTOMLEFT",
        GetOptionIndentOffset(dropdown, dropdownIndentAnchor),
        -18
    )
    dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -16, -4)
    dropdown.settingScope = settingScope or "module"
    dropdown.moduleKey = moduleKey
    dropdown.settingKey = settingKey
    dropdown.options = options
    dropdown.optionsProvider = optionsProvider
    dropdown.defaultValue = defaultValue
    dropdown.label = label
    dropdown.helpText = helpText
    dropdown.tooltipTitle = label
    dropdown.labelText = labelText
    dropdown.enabledWhen = nil
    dropdown.optionHelpTextAnchor = labelText
    dropdown.optionHelpLeftOffset = 0
    dropdown.optionHelpNextOffset = 0

    local helpPointAnchor = CreateFrame("Frame", nil, content)
    helpPointAnchor:SetSize(1, 1)
    helpPointAnchor:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, 0)
    dropdown.optionHelpPointAnchor = helpPointAnchor
    dropdown.optionHelpBottomAnchor = helpPointAnchor

    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_Initialize(dropdown, function(self)
        local settings = GetDropdownSettings(self)
        local selected = NormalizeDropdownSelectedValue(self, settings[self.settingKey])

        for _, option in ipairs(self.options) do
            local optionValue = option.value
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = optionValue
            info.checked = IsDropdownOptionSelected(self, selected, optionValue)
            if option.description and option.description ~= "" then
                info.tooltipTitle = option.label
                info.tooltipText = option.description
                info.tooltipOnButton = true
                info.tooltipWhileDisabled = true
            end
            info.func = function()
                if self.settingScope == "addon" then
                    ApplyAddonDropdownSetting(self.settingKey, optionValue)
                    return
                end
                ApplyModuleDropdownSetting(self.moduleKey, self.settingKey, optionValue)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    ConfigureDropdownTooltip(dropdown, name)
    table.insert(dropdowns, dropdown)
    return dropdown
end

local function CreateModuleSlider(panel, option, moduleKey, label, anchor)
    local content = GetPanelContent(panel)
    local slider = CreateFrame("Slider", option.name, content, "OptionsSliderTemplate")
    local minValue = option.min or 0
    local maxValue = option.max or minValue
    local step = option.step or 1
    local trackWidth = option.width or 220
    local thumbEdgePadding = option.thumbEdgePadding or SLIDER_THUMB_EDGE_PADDING
    local visibleOffsetX = option.visibleOffsetX or SLIDER_VISIBLE_OFFSET_X

    SetOptionIndentLevel(slider, option.indent or GetOptionIndentLevel(anchor))
    slider:SetPoint(
        "TOPLEFT",
        anchor.optionHelpBottomAnchor or anchor,
        "BOTTOMLEFT",
        GetOptionIndentOffset(slider, anchor) + visibleOffsetX - thumbEdgePadding,
        -42
    )
    slider:SetWidth(trackWidth + (thumbEdgePadding * 2))
    slider:SetHeight(16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    if slider.SetThumbTexture then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    local thumb = slider.GetThumbTexture and slider:GetThumbTexture() or nil
    if thumb and thumb.SetSize then
        thumb:SetSize(32, 32)
    end

    slider.trackBackground = CreateFrame("Frame", nil, slider)
    if slider.trackBackground.SetFrameLevel and slider.GetFrameLevel then
        slider.trackBackground:SetFrameLevel(math.max((slider:GetFrameLevel() or 1) - 1, 0))
    end
    slider.trackBackground:SetPoint("LEFT", slider, "LEFT", thumbEdgePadding, 0)
    slider.trackBackground:SetPoint("RIGHT", slider, "RIGHT", -thumbEdgePadding, 0)
    slider.trackBackground:SetHeight(6)
    if slider.trackBackground.SetBackdrop then
        slider.trackBackground:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
    end

    slider.trackFill = slider.trackBackground:CreateTexture(nil, "BACKGROUND")
    slider.trackFill:SetPoint("TOPLEFT", slider.trackBackground, "TOPLEFT", 0, -1)
    slider.trackFill:SetPoint("BOTTOMRIGHT", slider.trackBackground, "BOTTOMRIGHT", 0, 1)
    slider.trackBorder = {}
    slider.trackBorder.top = slider.trackBackground:CreateTexture(nil, "BORDER")
    slider.trackBorder.top:SetPoint("TOPLEFT", slider.trackBackground, "TOPLEFT", 0, 0)
    slider.trackBorder.top:SetPoint("TOPRIGHT", slider.trackBackground, "TOPRIGHT", 0, 0)
    slider.trackBorder.top:SetHeight(1)
    slider.trackBorder.bottom = slider.trackBackground:CreateTexture(nil, "BORDER")
    slider.trackBorder.bottom:SetPoint("BOTTOMLEFT", slider.trackBackground, "BOTTOMLEFT", 0, 0)
    slider.trackBorder.bottom:SetPoint("BOTTOMRIGHT", slider.trackBackground, "BOTTOMRIGHT", 0, 0)
    slider.trackBorder.bottom:SetHeight(1)
    slider.trackBorder.left = slider.trackBackground:CreateTexture(nil, "BORDER")
    slider.trackBorder.left:SetPoint("TOPLEFT", slider.trackBackground, "TOPLEFT", 0, 0)
    slider.trackBorder.left:SetPoint("BOTTOMLEFT", slider.trackBackground, "BOTTOMLEFT", 0, 0)
    slider.trackBorder.left:SetWidth(1)
    slider.trackBorder.right = slider.trackBackground:CreateTexture(nil, "BORDER")
    slider.trackBorder.right:SetPoint("TOPRIGHT", slider.trackBackground, "TOPRIGHT", 0, 0)
    slider.trackBorder.right:SetPoint("BOTTOMRIGHT", slider.trackBackground, "BOTTOMRIGHT", 0, 0)
    slider.trackBorder.right:SetWidth(1)

    slider.trackShine = slider.trackBackground:CreateTexture(nil, "ARTWORK")
    slider.trackShine:SetPoint("TOPLEFT", slider.trackBackground, "TOPLEFT", 0, -1)
    slider.trackShine:SetPoint("TOPRIGHT", slider.trackBackground, "TOPRIGHT", 0, -1)
    slider.trackShine:SetHeight(1)
    slider.trackShine:SetTexture("Interface\\Buttons\\WHITE8X8")
    SetSliderTrackColor(slider, true)

    slider.moduleKey = moduleKey
    slider.settingKey = option.settingKey
    slider.minValue = minValue
    slider.maxValue = maxValue
    slider.step = step
    slider.defaultValue = option.defaultValue
    if slider.defaultValue == nil then
        slider.defaultValue = minValue
    end
    slider.valueKey = option.valueKey
    slider.labelText = _G[option.name .. "Text"]
    slider.lowText = _G[option.name .. "Low"]
    slider.highText = _G[option.name .. "High"]
    slider.optionHelpTextAnchor = slider.labelText or slider
    slider.optionHelpLeftOffset = visibleOffsetX
    slider.optionHelpTopOffset = -16
    slider.optionHelpNextOffset = 0

    local helpPointAnchor = CreateFrame("Frame", nil, content)
    helpPointAnchor:SetSize(1, 1)
    helpPointAnchor:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", thumbEdgePadding, 10)
    slider.optionHelpPointAnchor = helpPointAnchor

    if slider.labelText then
        slider.labelText:SetText(label)
        slider.labelText:ClearAllPoints()
        slider.labelText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", thumbEdgePadding, 6)
        slider.labelText:SetJustifyH("LEFT")
    end
    if slider.lowText then
        slider.lowText:SetText("")
        slider.lowText:Hide()
    end
    if slider.highText then
        slider.highText:SetText("")
        slider.highText:Hide()
    end

    slider.valueText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.valueText:SetPoint("LEFT", slider.trackBackground, "RIGHT", 14, 0)

    slider:SetScript("OnValueChanged", function(self, value)
        local normalized = NormalizeSliderValue(value, self.minValue, self.maxValue, self.step, self.defaultValue)
        UpdateSliderValueText(self, normalized)

        if self.refreshing then
            return
        end
        if normalized ~= value then
            self.refreshing = true
            self:SetValue(normalized)
            self.refreshing = false
        end
        if self.currentValue == normalized then
            return
        end

        self.currentValue = normalized
        ApplyModuleSliderSetting(self.moduleKey, self.settingKey, normalized)
    end)

    table.insert(sliders, slider)
    return slider
end

local function CreateHelpText(panel, text, anchor)
    local content = GetPanelContent(panel)
    local help = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local textAnchor = anchor.optionHelpTextAnchor or GetCheckText(anchor) or anchor
    local checkWidth = anchor.GetWidth and anchor:GetWidth() or 0
    local textLeftOffset = anchor.optionHelpLeftOffset
        or (checkWidth > 0 and checkWidth + CHECK_TEXT_OFFSET_X or CHECK_TEXT_LEFT_FALLBACK)
    local bottomAnchor = CreateFrame("Frame", nil, content)
    local topOffset = anchor.optionHelpTopOffset or -5
    local nextOffset = anchor.optionHelpNextOffset or 0

    help:SetPoint("TOPLEFT", anchor.optionHelpPointAnchor or anchor.optionHelpBottomAnchor or textAnchor, "BOTTOMLEFT", 0, topOffset)
    help:SetWidth(GetOptionHelpWidth(anchor))
    help:SetJustifyH("LEFT")
    help:SetText(text)
    bottomAnchor:SetSize(1, 1)
    bottomAnchor:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -textLeftOffset, nextOffset)
    anchor.optionHelpBottomAnchor = bottomAnchor
    panel.optionBottomAnchor = bottomAnchor

    if anchor.GetChecked and anchor.SetChecked then
        CreateHelpClickTarget(help, anchor)
    end

    return help
end

local function AreSettingsEnabled(moduleKey, settingKeys)
    for _, settingKey in ipairs(settingKeys or {}) do
        if not IsSettingEnabled(moduleKey, settingKey) then
            return false
        end
    end
    return true
end

local function ApplyOptionEnabledWhen(control, option, moduleKey)
    if option.enabledWhen then
        control.enabledWhen = option.enabledWhen
    elseif option.enabledWhenSettings then
        control.enabledWhen = function()
            return AreSettingsEnabled(moduleKey, option.enabledWhenSettings)
        end
    elseif option.enabledWhenSetting then
        SetSettingCheckEnabledWhen(control, moduleKey, option.enabledWhenSetting)
    end
    return control
end

local function BuildDropdownOptions(options)
    local dropdownOptions = {}
    for _, option in ipairs(options or {}) do
        dropdownOptions[#dropdownOptions + 1] = {
            value = option.value,
            labelKey = option.labelKey,
            descriptionKey = option.descriptionKey,
            label = option.label or (option.labelKey and T(option.labelKey)) or option.value,
            description = option.description or (option.descriptionKey and T(option.descriptionKey)) or nil,
        }
    end
    return dropdownOptions
end

local function CreateOptionSection(panel, name, label, anchor)
    local content = GetPanelContent(panel)
    local bottomAnchor = anchor.optionHelpBottomAnchor or anchor
    local section = CreateFrame("Frame", name, content)
    SetOptionIndentLevel(section, 0)
    section:SetSize(430, 18)
    section:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT", GetOptionIndentOffset(section, anchor), OPTION_SECTION_OFFSET_Y)

    local text = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    text:SetWidth(430)
    text:SetJustifyH("LEFT")
    text:SetText(label)

    section.labelText = text
    panel.optionBottomAnchor = section
    return section
end

local function BuildOptionControl(panel, option, anchor, moduleKey)
    local control
    local optionModuleKey = option.moduleKey or moduleKey
    local optionDefinitions = option.options
    if option.optionsProvider then
        optionDefinitions = option.optionsProvider()
    end

    if option.type == "addonCheck" then
        control = CreateAddonSettingCheck(panel, option.name, option.settingKey, T(option.labelKey), anchor)
    elseif option.type == "addonAction" then
        control = CreateAddonActionButton(panel, option.name, T(option.labelKey), anchor, option.onClick, option)
    elseif option.type == "moduleEnabled" then
        control = CreateModuleEnabledCheck(panel, option.name, optionModuleKey, T(option.labelKey), anchor)
    elseif option.type == "section" then
        control = CreateOptionSection(panel, option.name, T(option.labelKey), anchor)
    elseif option.type == "dropdown" or option.type == "addonDropdown" then
        control = CreateDropdown(
            panel,
            option.name,
            option.type == "addonDropdown" and "addon" or "module",
            optionModuleKey,
            option.settingKey,
            T(option.labelKey),
            option.helpKey and T(option.helpKey) or nil,
            BuildDropdownOptions(optionDefinitions),
            anchor,
            option.indent,
            option.defaultValue,
            option.optionsProvider
        )
        if option.width then
            UIDropDownMenu_SetWidth(control, option.width)
        end
    elseif option.type == "slider" then
        control = CreateModuleSlider(panel, option, optionModuleKey, T(option.labelKey), anchor)
    else
        control = CreateModuleSettingCheck(
            panel,
            option.name,
            optionModuleKey,
            option.settingKey,
            T(option.labelKey),
            anchor,
            option.indent
        )
        AnchorBelowHelp(control, anchor, option.indent)
    end

    control.optionType = option.type
    control.labelKey = option.labelKey
    control.helpKey = option.helpKey

    ApplyOptionEnabledWhen(control, option, optionModuleKey)

    if option.helpKey
        and not ((option.type == "dropdown" or option.type == "addonDropdown") and control.helpText and control.helpText ~= "") then
        control.helpRegion = CreateHelpText(panel, T(option.helpKey), control)
    end

    return control
end

local function BuildOptionsPanel(definition)
    local panel = CreatePanel(definition.name, definition.title or T(definition.titleKey))
    panel.parent = definition.parent
    panel.categoryKey = definition.categoryKey
    panel.titleKey = definition.titleKey
    panel.staticTitle = definition.title
    panel.subtitleKey = definition.subtitleKey
    panel.localizedControls = {}

    if definition.categoryKey then
        categoryTitleKeys[definition.categoryKey] = {
            titleKey = definition.titleKey,
            staticTitle = definition.title,
        }
    end

    if definition.moduleKey and definition.titleKey then
        moduleTitleKeys[definition.moduleKey] = definition.titleKey
    end

    local subtitle = CreateSubtitle(panel, T(definition.subtitleKey))
    panel.subtitle = subtitle
    local anchor = subtitle

    for _, option in ipairs(definition.options or {}) do
        anchor = BuildOptionControl(panel, option, anchor, definition.moduleKey)
        panel.localizedControls[#panel.localizedControls + 1] = anchor
    end

    optionPanels[#optionPanels + 1] = panel
    return panel
end

local function GetCategoryTitle(categoryKey)
    local definition = categoryTitleKeys[categoryKey]
    if not definition then
        return nil
    end
    return definition.staticTitle or (definition.titleKey and T(definition.titleKey)) or nil
end

local function SetRegisteredCategoryName(category, name)
    if not category or not name then
        return
    end

    category.name = name
    if category.SetName then
        pcall(category.SetName, category, name)
    end
    if category.SetTitle then
        pcall(category.SetTitle, category, name)
    end
end

local function RefreshOptionsNavigation()
    local categories = VanillaEnhanced.optionsCategories
    if categories then
        for categoryKey, category in pairs(categories) do
            SetRegisteredCategoryName(category, GetCategoryTitle(categoryKey))
        end
    end

    if type(InterfaceOptionsFrameAddOns_Update) == "function" then
        pcall(InterfaceOptionsFrameAddOns_Update)
    end
    if SettingsPanel and SettingsPanel.CategoryList then
        if SettingsPanel.CategoryList.Refresh then
            pcall(SettingsPanel.CategoryList.Refresh, SettingsPanel.CategoryList)
        elseif SettingsPanel.CategoryList.Update then
            pcall(SettingsPanel.CategoryList.Update, SettingsPanel.CategoryList)
        end
    end
end

local function SetCheckText(check, label)
    local text = GetCheckText(check)
    if text then
        text:SetText(label)
    end
end

local function RefreshDropdownText(dropdown)
    if dropdown.optionsProvider then
        dropdown.options = BuildDropdownOptions(dropdown.optionsProvider())
    else
        for _, option in ipairs(dropdown.options or {}) do
            if option.labelKey then
                option.label = T(option.labelKey)
            end
            if option.descriptionKey then
                option.description = T(option.descriptionKey)
            end
        end
    end

    if dropdown.labelKey then
        local label = T(dropdown.labelKey)
        dropdown.label = label
        dropdown.tooltipTitle = label
        if dropdown.labelText then
            dropdown.labelText:SetText(label)
        end
    end
    if dropdown.helpKey then
        dropdown.helpText = T(dropdown.helpKey)
    end
end

function VanillaEnhanced:RefreshLocalizedOptions()
    for moduleKey, titleKey in pairs(moduleTitleKeys) do
        local module = self:GetModule(moduleKey)
        if module then
            module.displayName = T(titleKey)
        end
    end

    for _, panel in ipairs(optionPanels) do
        local titleText = panel.staticTitle or (panel.titleKey and T(panel.titleKey)) or panel.name
        panel.name = titleText
        if panel.title then
            panel.title:SetText(titleText)
        end
        if panel.subtitle and panel.subtitleKey then
            panel.subtitle:SetText(T(panel.subtitleKey))
        end

        for _, control in ipairs(panel.localizedControls or {}) do
            local label = control.labelKey and T(control.labelKey) or nil
            if control.optionType == "addonAction" then
                if label and control.SetText then
                    control:SetText(label)
                end
            elseif control.optionType == "dropdown" or control.optionType == "addonDropdown" then
                RefreshDropdownText(control)
            elseif control.labelText then
                if label then
                    control.labelText:SetText(label)
                end
                if control.valueText then
                    UpdateSliderValueText(control, control.currentValue or control:GetValue())
                end
            elseif label then
                SetCheckText(control, label)
            end

            if control.helpRegion and control.helpKey then
                control.helpRegion:SetText(T(control.helpKey))
            end
        end
    end

    RefreshOptionsNavigation()

    if self.RefreshOptions then
        self:RefreshOptions()
    end
end

local mainPanel = BuildOptionsPanel({
    name = "VanillaEnhancedOptionsPanel",
    categoryKey = "main",
    title = VanillaEnhanced.displayName,
    subtitleKey = "options.main.subtitle",
    options = {
        {
            type = "addonDropdown",
            name = "VanillaEnhancedOptionsMainLocale",
            settingKey = "locale",
            labelKey = "options.main.locale.label",
            helpKey = "options.main.locale.help",
            defaultValue = "auto",
            width = 150,
            optionsProvider = function()
                return VanillaEnhanced:GetLocaleOptions()
            end,
        },
        {
            type = "addonDropdown",
            name = "VanillaEnhancedOptionsMainConfigurationPreset",
            settingKey = "configurationPreset",
            labelKey = "options.main.configurationPreset.label",
            helpKey = "options.main.configurationPreset.help",
            defaultValue = GetDefaultConfigurationPresetKey(),
            width = 170,
            optionsProvider = function()
                return VanillaEnhanced:GetConfigurationPresetOptions()
            end,
        },
        {
            type = "addonAction",
            name = "VanillaEnhancedOptionsMainApplyConfigurationPreset",
            labelKey = "options.main.applyConfigurationPreset.label",
            onClick = ApplyConfigurationPreset,
            inlineWithPrevious = true,
            inlineOffsetX = -8,
            width = 110,
        },
        {
            type = "addonCheck",
            name = "VanillaEnhancedOptionsMainChatMessagesEnabled",
            settingKey = "chatMessagesEnabled",
            labelKey = "options.main.chatMessagesEnabled.label",
            helpKey = "options.main.chatMessagesEnabled.help",
        },
        {
            type = "addonCheck",
            name = "VanillaEnhancedOptionsMainShowChatMessagePrefix",
            settingKey = "showChatMessagePrefix",
            labelKey = "options.main.showChatMessagePrefix.label",
            helpKey = "options.main.showChatMessagePrefix.help",
            enabledWhen = function()
                return VanillaEnhanced:AreChatMessagesEnabled()
            end,
        },
        {
            type = "addonAction",
            name = "VanillaEnhancedOptionsMainResetSettings",
            labelKey = "options.main.resetSettings.label",
            helpKey = "options.main.resetSettings.help",
            onClick = ConfirmResetAddonSettings,
        },
    },
})

local questsPanel = BuildOptionsPanel({
    name = "VanillaEnhancedQuestsOptionsPanel",
    categoryKey = "quests",
    titleKey = "module.quests",
    subtitleKey = "options.quests.subtitle",
    parent = VanillaEnhanced.displayName,
    moduleKey = "quests",
    options = {
        {
            type = "moduleEnabled",
            name = "VanillaEnhancedOptionsQuestsEnabled",
            labelKey = "options.quests.enable.label",
            helpKey = "options.quests.enable.help",
        },
        {
            type = "section",
            name = "VanillaEnhancedOptionsQuestsTrackerSection",
            labelKey = "options.quests.section.tracker",
        },
        {
            name = "VanillaEnhancedOptionsQuestsKeepQuestLogWithMap",
            settingKey = "keepQuestLogWithMap",
            labelKey = "options.quests.keepQuestLogWithMap.label",
            helpKey = "options.quests.keepQuestLogWithMap.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsQuestsEnableQuestTrackerClicks",
            settingKey = "enableQuestTrackerClicks",
            labelKey = "options.quests.enableQuestTrackerClicks.label",
            helpKey = "options.quests.enableQuestTrackerClicks.help",
            indent = 0,
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsQuestsAutoFollowQuestsMode",
            settingKey = "autoFollowQuestsMode",
            labelKey = "options.quests.autoFollowQuestsMode.label",
            helpKey = "options.quests.autoFollowQuestsMode.help",
            indent = 0,
            width = 210,
            options = {
                {
                    value = "disabled",
                    labelKey = "options.quests.autoFollowQuestsMode.disabled",
                    descriptionKey = "options.quests.autoFollowQuestsMode.disabled.description",
                },
                {
                    value = "movement",
                    labelKey = "options.quests.autoFollowQuestsMode.movement",
                    descriptionKey = "options.quests.autoFollowQuestsMode.movement.description",
                },
                {
                    value = "zone",
                    labelKey = "options.quests.autoFollowQuestsMode.zone",
                    descriptionKey = "options.quests.autoFollowQuestsMode.zone.description",
                },
            },
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsQuestsAutoFollowQuestsRange",
            settingKey = "autoFollowQuestsRange",
            labelKey = "options.quests.autoFollowQuestsRange.label",
            helpKey = "options.quests.autoFollowQuestsRange.help",
            enabledWhen = function()
                return GetModuleOptionSettings("quests").autoFollowQuestsMode == "movement"
            end,
            indent = 1,
            width = 180,
            options = {
                {
                    value = "close",
                    labelKey = "options.quests.autoFollowQuestsRange.close",
                    descriptionKey = "options.quests.autoFollowQuestsRange.close.description",
                },
                {
                    value = "nearby",
                    labelKey = "options.quests.autoFollowQuestsRange.nearby",
                    descriptionKey = "options.quests.autoFollowQuestsRange.nearby.description",
                },
                {
                    value = "wide",
                    labelKey = "options.quests.autoFollowQuestsRange.wide",
                    descriptionKey = "options.quests.autoFollowQuestsRange.wide.description",
                },
            },
        },
        {
            type = "section",
            name = "VanillaEnhancedOptionsQuestsMapMarkersSection",
            labelKey = "options.quests.section.mapMarkers",
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowMapMarkers",
            settingKey = "showMapMarkers",
            labelKey = "options.quests.showMapMarkers.label",
            helpKey = "options.quests.showMapMarkers.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsQuestsHideMapMarkersInFogOfWar",
            settingKey = "hideMapMarkersInFogOfWar",
            labelKey = "options.quests.hideMapMarkersInFogOfWar.label",
            helpKey = "options.quests.hideMapMarkersInFogOfWar.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowSelectedQuestDirection",
            settingKey = "showSelectedQuestDirection",
            labelKey = "options.quests.showSelectedQuestDirection.label",
            helpKey = "options.quests.showSelectedQuestDirection.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowMinimapObjectiveAreas",
            settingKey = "showMinimapObjectiveAreas",
            labelKey = "options.quests.showMinimapObjectiveAreas.label",
            helpKey = "options.quests.showMinimapObjectiveAreas.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowRepeatableQuests",
            settingKey = "showRepeatableQuests",
            labelKey = "options.quests.showRepeatableQuests.label",
            helpKey = "options.quests.showRepeatableQuests.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowReputationQuests",
            settingKey = "showReputationQuests",
            labelKey = "options.quests.showReputationQuests.label",
            helpKey = "options.quests.showReputationQuests.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowAvailableQuests",
            settingKey = "showAvailableQuests",
            labelKey = "options.quests.showAvailableQuests.label",
            helpKey = "options.quests.showAvailableQuests.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsOnlyShowNearbyAvailableQuests",
            settingKey = "onlyShowNearbyAvailableQuests",
            labelKey = "options.quests.onlyShowNearbyAvailableQuests.label",
            helpKey = "options.quests.onlyShowNearbyAvailableQuests.help",
            enabledWhenSettings = { "showMapMarkers", "showAvailableQuests" },
            indent = 2,
        },
        {
            name = "VanillaEnhancedOptionsQuestsOnlyShowAvailableQuestsAroundPlayerLevel",
            settingKey = "onlyShowAvailableQuestsAroundPlayerLevel",
            labelKey = "options.quests.onlyShowAvailableQuestsAroundPlayerLevel.label",
            helpKey = "options.quests.onlyShowAvailableQuestsAroundPlayerLevel.help",
            enabledWhenSettings = { "showMapMarkers", "showAvailableQuests" },
            indent = 2,
        },
        {
            type = "slider",
            name = "VanillaEnhancedOptionsQuestsAvailableQuestLevelsBelowPlayer",
            settingKey = "availableQuestLevelsBelowPlayer",
            labelKey = "options.quests.availableQuestLevelsBelowPlayer.label",
            helpKey = "options.quests.availableQuestLevelsBelowPlayer.help",
            enabledWhenSettings = { "showMapMarkers", "showAvailableQuests", "onlyShowAvailableQuestsAroundPlayerLevel" },
            indent = 3,
            min = 0,
            max = 10,
            step = 1,
            defaultValue = 5,
        },
        {
            type = "slider",
            name = "VanillaEnhancedOptionsQuestsAvailableQuestLevelsAbovePlayer",
            settingKey = "availableQuestLevelsAbovePlayer",
            labelKey = "options.quests.availableQuestLevelsAbovePlayer.label",
            helpKey = "options.quests.availableQuestLevelsAbovePlayer.help",
            enabledWhenSettings = { "showMapMarkers", "showAvailableQuests", "onlyShowAvailableQuestsAroundPlayerLevel" },
            indent = 3,
            min = 0,
            max = 10,
            step = 1,
            defaultValue = 3,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowIncompleteDungeonTurnins",
            settingKey = "showIncompleteDungeonTurnins",
            labelKey = "options.quests.showIncompleteDungeonTurnins.label",
            helpKey = "options.quests.showIncompleteDungeonTurnins.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowCompletedMapObjectives",
            settingKey = "showCompletedMapObjectives",
            labelKey = "options.quests.showCompletedMapObjectives.label",
            helpKey = "options.quests.showCompletedMapObjectives.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            type = "section",
            name = "VanillaEnhancedOptionsQuestsTooltipsSection",
            labelKey = "options.quests.section.tooltips",
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowObjectiveTooltipHints",
            settingKey = "showObjectiveTooltipHints",
            labelKey = "options.quests.showObjectiveTooltipHints.label",
            helpKey = "options.quests.showObjectiveTooltipHints.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowCompletedTooltipObjectives",
            settingKey = "showCompletedTooltipObjectives",
            labelKey = "options.quests.showCompletedTooltipObjectives.label",
            helpKey = "options.quests.showCompletedTooltipObjectives.help",
            enabledWhenSetting = "showObjectiveTooltipHints",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowTooltipDropRates",
            settingKey = "showTooltipDropRates",
            labelKey = "options.quests.showTooltipDropRates.label",
            helpKey = "options.quests.showTooltipDropRates.help",
            enabledWhenSetting = "showObjectiveTooltipHints",
            indent = 1,
        },
    },
})

local mapPanel = BuildOptionsPanel({
    name = "VanillaEnhancedMapOptionsPanel",
    categoryKey = "map",
    titleKey = "module.map",
    subtitleKey = "options.map.subtitle",
    parent = VanillaEnhanced.displayName,
    moduleKey = "map",
    options = {
        {
            type = "moduleEnabled",
            name = "VanillaEnhancedOptionsMapEnabled",
            labelKey = "options.map.enable.label",
            helpKey = "options.map.enable.help",
        },
        {
            name = "VanillaEnhancedOptionsMapShowWorldMapMarkers",
            settingKey = "showWorldMapMarkers",
            labelKey = "options.map.showWorldMapMarkers.label",
            helpKey = "options.map.showWorldMapMarkers.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsMapShowMinimapDirections",
            settingKey = "showMinimapDirections",
            labelKey = "options.map.showMinimapDirections.label",
            helpKey = "options.map.showMinimapDirections.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsMapAutoRemoveReachedMarkers",
            settingKey = "autoRemoveReachedMarkers",
            labelKey = "options.map.autoRemoveReachedMarkers.label",
            helpKey = "options.map.autoRemoveReachedMarkers.help",
            indent = 0,
        },
        {
            type = "slider",
            name = "VanillaEnhancedOptionsMapReachedMarkerDistanceYards",
            settingKey = "reachedMarkerDistanceYards",
            labelKey = "options.map.reachedMarkerDistanceYards.label",
            helpKey = "options.map.reachedMarkerDistanceYards.help",
            valueKey = "options.map.reachedMarkerDistanceYards.value",
            enabledWhenSettings = { "autoRemoveReachedMarkers" },
            indent = 1,
            min = 5,
            max = 100,
            step = 5,
            defaultValue = 40,
        },
        {
            name = "VanillaEnhancedOptionsMapEnableTomTomCommands",
            settingKey = "enableTomTomCommands",
            labelKey = "options.map.enableTomTomCommands.label",
            helpKey = "options.map.enableTomTomCommands.help",
            indent = 0,
            enabledWhen = function()
                local map = VanillaEnhanced:GetModule("map")
                return not (map and map.IsTomTomInstalled and map:IsTomTomInstalled())
            end,
        },
        {
            type = "addonAction",
            name = "VanillaEnhancedOptionsMapClearMarkers",
            labelKey = "options.map.clearMarkers.label",
            helpKey = "options.map.clearMarkers.help",
            onClick = ConfirmClearMapMarkers,
        },
    },
})

local targetThreatPanel = BuildOptionsPanel({
    name = "VanillaEnhancedTargetThreatOptionsPanel",
    categoryKey = "targetThreat",
    titleKey = "module.targetThreat",
    subtitleKey = "options.targetThreat.subtitle",
    parent = VanillaEnhanced.displayName,
    moduleKey = "target-threat",
    options = {
        {
            type = "moduleEnabled",
            name = "VanillaEnhancedOptionsTargetThreatEnabled",
            labelKey = "options.targetThreat.enable.label",
            helpKey = "options.targetThreat.enable.help",
        },
        {
            name = "VanillaEnhancedOptionsTargetThreatAlwaysShow",
            settingKey = "alwaysShow",
            labelKey = "options.targetThreat.alwaysShow.label",
            helpKey = "options.targetThreat.alwaysShow.help",
            indent = 0,
        },
    },
})

local trainingPanel = BuildOptionsPanel({
    name = "VanillaEnhancedTrainingOptionsPanel",
    categoryKey = "training",
    titleKey = "module.training",
    subtitleKey = "options.training.subtitle",
    parent = VanillaEnhanced.displayName,
    moduleKey = "training",
    options = {
        {
            type = "moduleEnabled",
            name = "VanillaEnhancedOptionsTrainingEnabled",
            labelKey = "options.training.enable.label",
            helpKey = "options.training.enable.help",
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsTrainingDisplayMode",
            settingKey = "displayMode",
            labelKey = "options.training.displayMode.label",
            helpKey = "options.training.displayMode.help",
            indent = 0,
            width = 210,
            options = {
                {
                    value = "trainable",
                    labelKey = "options.training.displayMode.trainable",
                    descriptionKey = "options.training.displayMode.trainable.description",
                },
                {
                    value = "all-unlearned",
                    labelKey = "options.training.displayMode.allUnlearned",
                    descriptionKey = "options.training.displayMode.allUnlearned.description",
                },
            },
        },
    },
})

local professionsPanel = BuildOptionsPanel({
    name = "VanillaEnhancedProfessionsOptionsPanel",
    categoryKey = "professions",
    titleKey = "module.professions",
    subtitleKey = "options.professions.subtitle",
    parent = VanillaEnhanced.displayName,
    moduleKey = "professions",
    options = {
        {
            type = "moduleEnabled",
            name = "VanillaEnhancedOptionsProfessionsEnabled",
            labelKey = "options.professions.enable.label",
            helpKey = "options.professions.enable.help",
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsProfessionsRecipeScope",
            settingKey = "recipeScope",
            labelKey = "options.professions.recipeScope.label",
            helpKey = "options.professions.recipeScope.help",
            indent = 0,
            width = 210,
            options = {
                {
                    value = "all",
                    labelKey = "options.professions.recipeScope.all",
                    descriptionKey = "options.professions.recipeScope.all.description",
                },
                {
                    value = "known",
                    labelKey = "options.professions.recipeScope.known",
                    descriptionKey = "options.professions.recipeScope.known.description",
                },
            },
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsProfessionsProfessionScope",
            settingKey = "professionScope",
            labelKey = "options.professions.professionScope.label",
            helpKey = "options.professions.professionScope.help",
            indent = 0,
            width = 240,
            enabledWhen = function()
                return GetModuleOptionSettings("professions").recipeScope ~= "known"
            end,
            options = {
                {
                    value = "all",
                    labelKey = "options.professions.professionScope.all",
                    descriptionKey = "options.professions.professionScope.all.description",
                },
                {
                    value = "player",
                    labelKey = "options.professions.professionScope.player",
                    descriptionKey = "options.professions.professionScope.player.description",
                },
                {
                    value = "player-skill",
                    labelKey = "options.professions.professionScope.playerSkill",
                    descriptionKey = "options.professions.professionScope.playerSkill.description",
                },
            },
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsProfessionsDisplayMode",
            settingKey = "displayMode",
            labelKey = "options.professions.displayMode.label",
            helpKey = "options.professions.displayMode.help",
            indent = 0,
            width = 210,
            options = {
                {
                    value = "recipes",
                    labelKey = "options.professions.displayMode.recipes",
                    descriptionKey = "options.professions.displayMode.recipes.description",
                },
                {
                    value = "compact",
                    labelKey = "options.professions.displayMode.compact",
                    descriptionKey = "options.professions.displayMode.compact.description",
                },
            },
        },
    },
})

local bagsPanel = BuildOptionsPanel({
    name = "VanillaEnhancedBagsOptionsPanel",
    categoryKey = "bags",
    titleKey = "module.bags",
    subtitleKey = "options.bags.subtitle",
    parent = VanillaEnhanced.displayName,
    moduleKey = "bags",
    options = {
        {
            type = "moduleEnabled",
            name = "VanillaEnhancedOptionsBagsEnabled",
            labelKey = "options.bags.enable.label",
            helpKey = "options.bags.enable.help",
        },
        {
            type = "section",
            name = "VanillaEnhancedOptionsBagsControlsSection",
            labelKey = "options.bags.section.controls",
        },
        {
            name = "VanillaEnhancedOptionsBagsShowSortButton",
            settingKey = "showSortButton",
            labelKey = "options.bags.showSortButton.label",
            helpKey = "options.bags.showSortButton.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsShowSearchField",
            settingKey = "showSearchField",
            labelKey = "options.bags.showSearchField.label",
            helpKey = "options.bags.showSearchField.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsEnableItemLocking",
            settingKey = "enableItemLocking",
            labelKey = "options.bags.enableItemLocking.label",
            helpKey = "options.bags.enableItemLocking.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsShowQuestIcon",
            settingKey = "showQuestIcon",
            labelKey = "options.bags.showQuestIcon.label",
            helpKey = "options.bags.showQuestIcon.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsShowScrapIcon",
            settingKey = "showScrapIcon",
            labelKey = "options.bags.showScrapIcon.label",
            helpKey = "options.bags.showScrapIcon.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsShowScrapToggleButton",
            settingKey = "showScrapToggleButton",
            labelKey = "options.bags.showScrapToggleButton.label",
            helpKey = "options.bags.showScrapToggleButton.help",
            enabledWhen = function()
                local Merchants = VanillaEnhanced:GetModule("merchants")
                return IsSettingEnabled("bags", "showScrapIcon")
                    and Merchants
                    and Merchants.IsSellScrapsEnabled
                    and Merchants:IsSellScrapsEnabled()
            end,
            indent = 1,
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsBagsAutoOpenMode",
            settingKey = "autoOpenMode",
            labelKey = "options.bags.autoOpenMode.label",
            helpKey = "options.bags.autoOpenMode.help",
            indent = 0,
            width = 220,
            options = {
                {
                    value = "disabled",
                    labelKey = "options.bags.autoOpenMode.disabled",
                    descriptionKey = "options.bags.autoOpenMode.disabled.description",
                },
                {
                    value = "character",
                    labelKey = "options.bags.autoOpenMode.character",
                    descriptionKey = "options.bags.autoOpenMode.character.description",
                },
                {
                    value = "merchant",
                    labelKey = "options.bags.autoOpenMode.merchant",
                    descriptionKey = "options.bags.autoOpenMode.merchant.description",
                },
                {
                    value = "both",
                    labelKey = "options.bags.autoOpenMode.both",
                    descriptionKey = "options.bags.autoOpenMode.both.description",
                },
            },
        },
        {
            type = "section",
            name = "VanillaEnhancedOptionsBagsSortingSection",
            labelKey = "options.bags.section.sorting",
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsBagsSortOrder",
            settingKey = "sortOrder",
            labelKey = "options.bags.sortOrder.label",
            helpKey = "options.bags.sortOrder.help",
            indent = 0,
            options = {
                {
                    value = "category",
                    labelKey = "options.bags.sortOrder.category",
                    descriptionKey = "options.bags.sortOrder.category.description",
                },
                {
                    value = "quality",
                    labelKey = "options.bags.sortOrder.quality",
                    descriptionKey = "options.bags.sortOrder.quality.description",
                },
            },
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsBagsSortFillDirection",
            settingKey = "sortFillDirection",
            labelKey = "options.bags.sortFillDirection.label",
            helpKey = "options.bags.sortFillDirection.help",
            indent = 0,
            width = 190,
            options = {
                {
                    value = "backpack-first",
                    labelKey = "options.bags.sortFillDirection.backpackFirst",
                    descriptionKey = "options.bags.sortFillDirection.backpackFirst.description",
                },
                {
                    value = "backpack-last",
                    labelKey = "options.bags.sortFillDirection.backpackLast",
                    descriptionKey = "options.bags.sortFillDirection.backpackLast.description",
                },
            },
        },
        {
            name = "VanillaEnhancedOptionsBagsSortScrapsLast",
            settingKey = "sortScrapsLast",
            labelKey = "options.bags.sortScrapsLast.label",
            helpKey = "options.bags.sortScrapsLast.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsAutoSortAfterLoot",
            settingKey = "autoSortAfterLoot",
            labelKey = "options.bags.autoSortAfterLoot.label",
            helpKey = "options.bags.autoSortAfterLoot.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsAutoSortOnOpen",
            settingKey = "autoSortOnOpen",
            labelKey = "options.bags.autoSortOnOpen.label",
            helpKey = "options.bags.autoSortOnOpen.help",
            indent = 0,
        },
        {
            name = "VanillaEnhancedOptionsBagsAutoSortOnClose",
            settingKey = "autoSortOnClose",
            labelKey = "options.bags.autoSortOnClose.label",
            helpKey = "options.bags.autoSortOnClose.help",
            indent = 0,
        },
    },
})

local merchantsPanel = BuildOptionsPanel({
    name = "VanillaEnhancedMerchantsOptionsPanel",
    categoryKey = "merchants",
    titleKey = "module.merchants",
    subtitleKey = "options.merchants.subtitle",
    parent = VanillaEnhanced.displayName,
    moduleKey = "merchants",
    options = {
        {
            type = "moduleEnabled",
            name = "VanillaEnhancedOptionsMerchantsEnabled",
            labelKey = "options.merchants.enable.label",
            helpKey = "options.merchants.enable.help",
        },
        {
            name = "VanillaEnhancedOptionsMerchantsSellScraps",
            settingKey = "sellScrapsEnabled",
            labelKey = "options.merchants.sellScraps.label",
            helpKey = "options.merchants.sellScraps.help",
            indent = 0,
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsMerchantsScrapStrategy",
            settingKey = "scrapStrategy",
            labelKey = "options.merchants.scrapStrategy.label",
            helpKey = "options.merchants.scrapStrategy.help",
            enabledWhenSetting = "sellScrapsEnabled",
            indent = 1,
            width = 190,
            defaultValue = "poor-sellable",
            options = {
                {
                    value = "poor-sellable",
                    labelKey = "options.merchants.scrapStrategy.poorSellable",
                    descriptionKey = "options.merchants.scrapStrategy.poorSellable.description",
                },
                {
                    value = "low-level",
                    labelKey = "options.merchants.scrapStrategy.lowLevel",
                    descriptionKey = "options.merchants.scrapStrategy.lowLevel.description",
                },
                {
                    value = "smart",
                    labelKey = "options.merchants.scrapStrategy.smart",
                    descriptionKey = "options.merchants.scrapStrategy.smart.description",
                },
            },
        },
        {
            name = "VanillaEnhancedOptionsMerchantsSafeManualSell",
            settingKey = "safeManualSell",
            labelKey = "options.merchants.safeManualSell.label",
            helpKey = "options.merchants.safeManualSell.help",
            enabledWhenSetting = "sellScrapsEnabled",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsMerchantsSortBagsAfterSellingScraps",
            settingKey = "sortBagsAfterSellingScraps",
            labelKey = "options.merchants.sortBagsAfterSellingScraps.label",
            helpKey = "options.merchants.sortBagsAfterSellingScraps.help",
            enabledWhen = function()
                return IsSettingEnabled("merchants", "sellScrapsEnabled")
                    and VanillaEnhanced:IsModuleEnabled("bags")
            end,
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsMerchantsAutoSellScraps",
            settingKey = "autoSellScraps",
            labelKey = "options.merchants.autoSellScraps.label",
            helpKey = "options.merchants.autoSellScraps.help",
            enabledWhenSetting = "sellScrapsEnabled",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsMerchantsSafeAutoSell",
            settingKey = "safeAutoSell",
            labelKey = "options.merchants.safeAutoSell.label",
            helpKey = "options.merchants.safeAutoSell.help",
            enabledWhenSettings = { "sellScrapsEnabled", "autoSellScraps" },
            indent = 2,
        },
        {
            name = "VanillaEnhancedOptionsMerchantsAutoRepair",
            settingKey = "autoRepair",
            labelKey = "options.merchants.autoRepair.label",
            helpKey = "options.merchants.autoRepair.help",
            indent = 0,
        },
    },
})

function VanillaEnhanced:RefreshOptions()
    local addonSettings = self:GetSettings()
    for _, check in ipairs(addonSettingChecks) do
        check:SetChecked(addonSettings[check.settingKey] ~= false)
        local enabled = true
        if check.enabledWhen then
            enabled = check.enabledWhen()
        end
        SetCheckEnabled(check, enabled)
    end
    for moduleKey, check in pairs(moduleChecks) do
        check:SetChecked(self:IsModuleEnabled(moduleKey))
    end
    for _, check in ipairs(settingChecks) do
        local settings = GetModuleOptionSettings(check.moduleKey)
        local enabled = self:IsModuleEnabled(check.moduleKey)
        if check.enabledWhen then
            enabled = enabled and check.enabledWhen()
        end
        check:SetChecked(settings[check.settingKey] == true)
        SetCheckEnabled(check, enabled)
    end
    for _, dropdown in ipairs(dropdowns) do
        local settings = GetDropdownSettings(dropdown)
        local selected = NormalizeDropdownSelectedValue(dropdown, settings[dropdown.settingKey])
        local selectedLabel = selected
        if selected == nil then
            selected = dropdown.defaultValue
            selectedLabel = selected
        end
        local enabled = dropdown.settingScope == "addon" or self:IsModuleEnabled(dropdown.moduleKey)
        if dropdown.enabledWhen then
            enabled = enabled and dropdown.enabledWhen()
        end

        for _, option in ipairs(dropdown.options) do
            if IsDropdownOptionSelected(dropdown, selected, option.value) then
                selectedLabel = option.label
                break
            end
        end

        UIDropDownMenu_SetText(dropdown, selectedLabel)
        if enabled then
            UIDropDownMenu_EnableDropDown(dropdown)
            if dropdown.labelText then
                dropdown.labelText:SetTextColor(1, 1, 1)
            end
        else
            UIDropDownMenu_DisableDropDown(dropdown)
            if dropdown.labelText then
                dropdown.labelText:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end
    for _, slider in ipairs(sliders) do
        local settings = GetModuleOptionSettings(slider.moduleKey)
        local selected = NormalizeSliderValue(
            settings[slider.settingKey],
            slider.minValue,
            slider.maxValue,
            slider.step,
            slider.defaultValue
        )
        local enabled = self:IsModuleEnabled(slider.moduleKey)
        if slider.enabledWhen then
            enabled = enabled and slider.enabledWhen()
        end

        slider.refreshing = true
        slider:SetValue(selected)
        slider.refreshing = false
        slider.currentValue = selected
        UpdateSliderValueText(slider, selected)
        SetSliderEnabled(slider, enabled)
    end
end

local function RefreshOnShow(panel)
    VanillaEnhanced:RefreshOptions()
    UpdatePanelScrollContentSize(panel)
end

mainPanel:SetScript("OnShow", RefreshOnShow)
questsPanel:SetScript("OnShow", RefreshOnShow)
bagsPanel:SetScript("OnShow", RefreshOnShow)
merchantsPanel:SetScript("OnShow", RefreshOnShow)
mapPanel:SetScript("OnShow", RefreshOnShow)
targetThreatPanel:SetScript("OnShow", RefreshOnShow)
professionsPanel:SetScript("OnShow", RefreshOnShow)
trainingPanel:SetScript("OnShow", RefreshOnShow)

local function RegisterInterfaceOptions()
    InterfaceOptions_AddCategory(mainPanel)
    InterfaceOptions_AddCategory(questsPanel)
    InterfaceOptions_AddCategory(bagsPanel)
    InterfaceOptions_AddCategory(merchantsPanel)
    InterfaceOptions_AddCategory(mapPanel)
    InterfaceOptions_AddCategory(targetThreatPanel)
    InterfaceOptions_AddCategory(professionsPanel)
    InterfaceOptions_AddCategory(trainingPanel)

    VanillaEnhanced.optionsCategories = {
        main = mainPanel,
        quests = questsPanel,
        bags = bagsPanel,
        merchants = merchantsPanel,
        map = mapPanel,
        targetThreat = targetThreatPanel,
        professions = professionsPanel,
        training = trainingPanel,
    }
end

local function RegisterSettingsOptions()
    local mainCategory = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(mainCategory)

    VanillaEnhanced.optionsCategories = {
        main = mainCategory,
    }

    if type(Settings.RegisterCanvasLayoutSubcategory) == "function" then
        local questOk, questsCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            questsPanel,
            questsPanel.name
        )
        local bagsOk, bagsCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            bagsPanel,
            bagsPanel.name
        )
        local merchantsOk, merchantsCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            merchantsPanel,
            merchantsPanel.name
        )
        local mapOk, mapCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            mapPanel,
            mapPanel.name
        )
        local targetOk, targetThreatCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            targetThreatPanel,
            targetThreatPanel.name
        )
        local professionsOk, professionsCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            professionsPanel,
            professionsPanel.name
        )
        local trainingOk, trainingCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            trainingPanel,
            trainingPanel.name
        )

        if questOk and mapOk and targetOk and trainingOk and professionsOk and bagsOk and merchantsOk then
            VanillaEnhanced.optionsCategories.quests = questsCategory
            VanillaEnhanced.optionsCategories.bags = bagsCategory
            VanillaEnhanced.optionsCategories.merchants = merchantsCategory
            VanillaEnhanced.optionsCategories.map = mapCategory
            VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
            VanillaEnhanced.optionsCategories.professions = professionsCategory
            VanillaEnhanced.optionsCategories.training = trainingCategory
            return
        end
    end

    local questsCategory = Settings.RegisterCanvasLayoutCategory(questsPanel, questsPanel.name)
    local bagsCategory = Settings.RegisterCanvasLayoutCategory(bagsPanel, bagsPanel.name)
    local merchantsCategory = Settings.RegisterCanvasLayoutCategory(merchantsPanel, merchantsPanel.name)
    local mapCategory = Settings.RegisterCanvasLayoutCategory(mapPanel, mapPanel.name)
    local targetThreatCategory = Settings.RegisterCanvasLayoutCategory(targetThreatPanel, targetThreatPanel.name)
    local professionsCategory = Settings.RegisterCanvasLayoutCategory(professionsPanel, professionsPanel.name)
    local trainingCategory = Settings.RegisterCanvasLayoutCategory(trainingPanel, trainingPanel.name)
    Settings.RegisterAddOnCategory(questsCategory)
    Settings.RegisterAddOnCategory(bagsCategory)
    Settings.RegisterAddOnCategory(merchantsCategory)
    Settings.RegisterAddOnCategory(mapCategory)
    Settings.RegisterAddOnCategory(targetThreatCategory)
    Settings.RegisterAddOnCategory(professionsCategory)
    Settings.RegisterAddOnCategory(trainingCategory)

    VanillaEnhanced.optionsCategories.quests = questsCategory
    VanillaEnhanced.optionsCategories.bags = bagsCategory
    VanillaEnhanced.optionsCategories.merchants = merchantsCategory
    VanillaEnhanced.optionsCategories.map = mapCategory
    VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
    VanillaEnhanced.optionsCategories.professions = professionsCategory
    VanillaEnhanced.optionsCategories.training = trainingCategory
end

if type(InterfaceOptions_AddCategory) == "function" then
    RegisterInterfaceOptions()
elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    RegisterSettingsOptions()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == VanillaEnhanced.addonName then
        self:UnregisterEvent("ADDON_LOADED")
        VanillaEnhanced:GetSettings()
        VanillaEnhanced:RefreshLocalizedOptions()
    end
end)
