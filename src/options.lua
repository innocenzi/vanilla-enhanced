local VanillaEnhanced = _G.VanillaEnhanced

local moduleChecks = {}
local settingChecks = {}
local addonSettingChecks = {}
local dropdowns = {}
local OPTION_WITH_HELP_OFFSET = -15
local OPTION_INDENT_WIDTH = 18
local OPTION_HELP_WIDTH = 430
local CHECK_TEXT_OFFSET_X = 3
local CHECK_TEXT_LEFT_FALLBACK = 27
local SCROLL_BAR_WIDTH = 28
local SCROLL_BOTTOM_PADDING = 24

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
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
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    check.settingKey = settingKey

    ConfigureCheckText(check, label)

    check:SetScript("OnClick", function(self)
        ApplyAddonSetting(self.settingKey, self:GetChecked())
    end)

    table.insert(addonSettingChecks, check)
    return check
end

local function SetSettingCheckEnabledWhen(check, moduleKey, settingKey)
    check.enabledWhen = function()
        return IsSettingEnabled(moduleKey, settingKey)
    end
    return check
end

local function CreateModuleDropdown(panel, name, moduleKey, settingKey, label, options, anchor, indentLevel)
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
    dropdown.moduleKey = moduleKey
    dropdown.settingKey = settingKey
    dropdown.options = options
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
        local settings = GetModuleOptionSettings(self.moduleKey)
        local selected = settings[self.settingKey]

        for _, option in ipairs(self.options) do
            local optionValue = option.value
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = optionValue
            info.checked = selected == optionValue
            info.func = function()
                ApplyModuleDropdownSetting(self.moduleKey, self.settingKey, optionValue)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    table.insert(dropdowns, dropdown)
    return dropdown
end

local function CreateHelpText(panel, text, anchor)
    local content = GetPanelContent(panel)
    local help = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local textAnchor = anchor.optionHelpTextAnchor or GetCheckText(anchor) or anchor
    local checkWidth = anchor.GetWidth and anchor:GetWidth() or 0
    local textLeftOffset = anchor.optionHelpLeftOffset
        or (checkWidth > 0 and checkWidth + CHECK_TEXT_OFFSET_X or CHECK_TEXT_LEFT_FALLBACK)
    local bottomAnchor = CreateFrame("Frame", nil, content)
    local nextOffset = anchor.optionHelpNextOffset or 0

    help:SetPoint("TOPLEFT", anchor.optionHelpPointAnchor or anchor.optionHelpBottomAnchor or textAnchor, "BOTTOMLEFT", 0, -5)
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
            label = option.label or T(option.labelKey),
        }
    end
    return dropdownOptions
end

local function BuildOptionControl(panel, option, anchor, moduleKey)
    local control
    local optionModuleKey = option.moduleKey or moduleKey

    if option.type == "addonCheck" then
        control = CreateAddonSettingCheck(panel, option.name, option.settingKey, T(option.labelKey), anchor)
    elseif option.type == "moduleEnabled" then
        control = CreateModuleEnabledCheck(panel, option.name, optionModuleKey, T(option.labelKey), anchor)
    elseif option.type == "dropdown" then
        control = CreateModuleDropdown(
            panel,
            option.name,
            optionModuleKey,
            option.settingKey,
            T(option.labelKey),
            BuildDropdownOptions(option.options),
            anchor,
            option.indent
        )
        if option.width then
            UIDropDownMenu_SetWidth(control, option.width)
        end
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

    ApplyOptionEnabledWhen(control, option, optionModuleKey)

    if option.helpKey then
        CreateHelpText(panel, T(option.helpKey), control)
    end

    return control
end

local function BuildOptionsPanel(definition)
    local panel = CreatePanel(definition.name, definition.title or T(definition.titleKey))
    panel.parent = definition.parent

    local subtitle = CreateSubtitle(panel, T(definition.subtitleKey))
    local anchor = subtitle

    for _, option in ipairs(definition.options or {}) do
        anchor = BuildOptionControl(panel, option, anchor, definition.moduleKey)
    end

    return panel
end

local mainPanel = BuildOptionsPanel({
    name = "VanillaEnhancedOptionsPanel",
    title = VanillaEnhanced.displayName,
    subtitleKey = "options.main.subtitle",
    options = {
        {
            type = "addonCheck",
            name = "VanillaEnhancedOptionsMainShowChatMessagePrefix",
            settingKey = "showChatMessagePrefix",
            labelKey = "options.main.showChatMessagePrefix.label",
            helpKey = "options.main.showChatMessagePrefix.help",
        },
    },
})

local questsPanel = BuildOptionsPanel({
    name = "VanillaEnhancedQuestsOptionsPanel",
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
            name = "VanillaEnhancedOptionsQuestsShowMapMarkers",
            settingKey = "showMapMarkers",
            labelKey = "options.quests.showMapMarkers.label",
            helpKey = "options.quests.showMapMarkers.help",
            indent = 0,
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
            name = "VanillaEnhancedOptionsQuestsShowCompletedMapObjectives",
            settingKey = "showCompletedMapObjectives",
            labelKey = "options.quests.showCompletedMapObjectives.label",
            helpKey = "options.quests.showCompletedMapObjectives.help",
            enabledWhenSetting = "showMapMarkers",
            indent = 1,
        },
        {
            name = "VanillaEnhancedOptionsQuestsShowCompletedTooltipObjectives",
            settingKey = "showCompletedTooltipObjectives",
            labelKey = "options.quests.showCompletedTooltipObjectives.label",
            helpKey = "options.quests.showCompletedTooltipObjectives.help",
            indent = 0,
        },
    },
})

local targetThreatPanel = BuildOptionsPanel({
    name = "VanillaEnhancedTargetThreatOptionsPanel",
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

local bagsPanel = BuildOptionsPanel({
    name = "VanillaEnhancedBagsOptionsPanel",
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
            name = "VanillaEnhancedOptionsBagsShowSortButton",
            settingKey = "showSortButton",
            labelKey = "options.bags.showSortButton.label",
            helpKey = "options.bags.showSortButton.help",
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
            type = "dropdown",
            name = "VanillaEnhancedOptionsBagsAutoSortAfterLootMode",
            settingKey = "autoSortAfterLootMode",
            labelKey = "options.bags.autoSortAfterLootMode.label",
            helpKey = "options.bags.autoSortAfterLootMode.help",
            enabledWhenSetting = "autoSortAfterLoot",
            indent = 1,
            options = {
                { value = "tidy", labelKey = "options.bags.autoSortAfterLootMode.tidy" },
                { value = "full", labelKey = "options.bags.autoSortAfterLootMode.full" },
            },
        },
        {
            name = "VanillaEnhancedOptionsBagsAutoSortOnOpen",
            settingKey = "autoSortOnOpen",
            labelKey = "options.bags.autoSortOnOpen.label",
            helpKey = "options.bags.autoSortOnOpen.help",
            indent = 0,
        },
        {
            type = "dropdown",
            name = "VanillaEnhancedOptionsBagsSortOrder",
            settingKey = "sortOrder",
            labelKey = "options.bags.sortOrder.label",
            helpKey = "options.bags.sortOrder.help",
            indent = 0,
            options = {
                { value = "category", labelKey = "options.bags.sortOrder.category" },
                { value = "quality", labelKey = "options.bags.sortOrder.quality" },
                { value = "name", labelKey = "options.bags.sortOrder.name" },
            },
        },
    },
})

local merchantsPanel = BuildOptionsPanel({
    name = "VanillaEnhancedMerchantsOptionsPanel",
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
            options = {
                { value = "poor-sellable", labelKey = "options.merchants.scrapStrategy.poorSellable" },
                { value = "poor-unusable-equipment", labelKey = "options.merchants.scrapStrategy.poorUnusableEquipment" },
                { value = "poor-low-consumables", labelKey = "options.merchants.scrapStrategy.poorLowConsumables" },
                { value = "poor-low-equipment", labelKey = "options.merchants.scrapStrategy.poorLowEquipment" },
                { value = "smart", labelKey = "options.merchants.scrapStrategy.smart" },
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
        SetCheckEnabled(check, true)
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
        local settings = GetModuleOptionSettings(dropdown.moduleKey)
        local selected = settings[dropdown.settingKey]
        local selectedLabel = selected
        local enabled = self:IsModuleEnabled(dropdown.moduleKey)
        if dropdown.enabledWhen then
            enabled = enabled and dropdown.enabledWhen()
        end

        for _, option in ipairs(dropdown.options) do
            if option.value == selected then
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
end

local function RefreshOnShow(panel)
    VanillaEnhanced:RefreshOptions()
    UpdatePanelScrollContentSize(panel)
end

mainPanel:SetScript("OnShow", RefreshOnShow)
questsPanel:SetScript("OnShow", RefreshOnShow)
targetThreatPanel:SetScript("OnShow", RefreshOnShow)
bagsPanel:SetScript("OnShow", RefreshOnShow)
merchantsPanel:SetScript("OnShow", RefreshOnShow)

local function RegisterInterfaceOptions()
    InterfaceOptions_AddCategory(mainPanel)
    InterfaceOptions_AddCategory(questsPanel)
    InterfaceOptions_AddCategory(targetThreatPanel)
    InterfaceOptions_AddCategory(bagsPanel)
    InterfaceOptions_AddCategory(merchantsPanel)
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
        local targetOk, targetThreatCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            targetThreatPanel,
            targetThreatPanel.name
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

        if questOk and targetOk and bagsOk and merchantsOk then
            VanillaEnhanced.optionsCategories.quests = questsCategory
            VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
            VanillaEnhanced.optionsCategories.bags = bagsCategory
            VanillaEnhanced.optionsCategories.merchants = merchantsCategory
            return
        end
    end

    local questsCategory = Settings.RegisterCanvasLayoutCategory(questsPanel, questsPanel.name)
    local targetThreatCategory = Settings.RegisterCanvasLayoutCategory(targetThreatPanel, targetThreatPanel.name)
    local bagsCategory = Settings.RegisterCanvasLayoutCategory(bagsPanel, bagsPanel.name)
    local merchantsCategory = Settings.RegisterCanvasLayoutCategory(merchantsPanel, merchantsPanel.name)
    Settings.RegisterAddOnCategory(questsCategory)
    Settings.RegisterAddOnCategory(targetThreatCategory)
    Settings.RegisterAddOnCategory(bagsCategory)
    Settings.RegisterAddOnCategory(merchantsCategory)

    VanillaEnhanced.optionsCategories.quests = questsCategory
    VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
    VanillaEnhanced.optionsCategories.bags = bagsCategory
    VanillaEnhanced.optionsCategories.merchants = merchantsCategory
end

if type(InterfaceOptions_AddCategory) == "function" then
    RegisterInterfaceOptions()
elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    RegisterSettingsOptions()
end
