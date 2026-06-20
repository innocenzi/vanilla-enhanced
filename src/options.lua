local VanillaEnhanced = _G.VanillaEnhanced

local moduleChecks = {}
local settingChecks = {}
local addonSettingChecks = {}
local dropdowns = {}
local OPTION_WITH_HELP_OFFSET = -15
local CHECK_TEXT_OFFSET_X = 3
local CHECK_TEXT_LEFT_FALLBACK = 27

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
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

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(titleText)
    panel.title = title

    return panel
end

local function CreateSubtitle(panel, text)
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(430)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(text)
    return subtitle
end

local function AnchorBelowHelp(check, anchor)
    local bottomAnchor = anchor.optionHelpBottomAnchor or anchor

    check:ClearAllPoints()
    check:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT", 0, OPTION_WITH_HELP_OFFSET)
end

local function CreateModuleEnabledCheck(panel, name, moduleKey, label, anchor)
    local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    check.moduleKey = moduleKey

    ConfigureCheckText(check, label)

    check:SetScript("OnClick", function(self)
        ApplyModuleEnabled(self.moduleKey, self:GetChecked())
    end)

    moduleChecks[moduleKey] = check
    return check
end

local function CreateModuleSettingCheck(panel, name, moduleKey, settingKey, label, anchor)
    local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
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
    local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
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

local function CreateModuleDropdown(panel, name, moduleKey, settingKey, label, options, anchor)
    local labelText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    labelText:SetPoint("TOPLEFT", anchor.optionHelpBottomAnchor or anchor, "BOTTOMLEFT", 0, -18)
    labelText:SetText(label)

    local dropdown = CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -16, -4)
    dropdown.moduleKey = moduleKey
    dropdown.settingKey = settingKey
    dropdown.options = options
    dropdown.labelText = labelText
    dropdown.enabledWhen = nil
    dropdown.optionHelpTextAnchor = labelText
    dropdown.optionHelpLeftOffset = 0
    dropdown.optionHelpNextOffset = -22

    local helpPointAnchor = CreateFrame("Frame", nil, panel)
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
    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local textAnchor = anchor.optionHelpTextAnchor or GetCheckText(anchor) or anchor
    local checkWidth = anchor.GetWidth and anchor:GetWidth() or 0
    local textLeftOffset = anchor.optionHelpLeftOffset
        or (checkWidth > 0 and checkWidth + CHECK_TEXT_OFFSET_X or CHECK_TEXT_LEFT_FALLBACK)
    local bottomAnchor = CreateFrame("Frame", nil, panel)
    local nextOffset = anchor.optionHelpNextOffset or 0

    help:SetPoint("TOPLEFT", anchor.optionHelpPointAnchor or anchor.optionHelpBottomAnchor or textAnchor, "BOTTOMLEFT", 0, -5)
    help:SetWidth(430)
    help:SetJustifyH("LEFT")
    help:SetText(text)
    bottomAnchor:SetSize(1, 1)
    bottomAnchor:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -textLeftOffset, nextOffset)
    anchor.optionHelpBottomAnchor = bottomAnchor

    if anchor.GetChecked and anchor.SetChecked then
        CreateHelpClickTarget(help, anchor)
    end

    return help
end

local mainPanel = CreatePanel("VanillaEnhancedOptionsPanel", VanillaEnhanced.displayName)
local mainSubtitle = CreateSubtitle(mainPanel, T("options.main.subtitle"))
local mainShowChatMessagePrefixCheck = CreateAddonSettingCheck(
    mainPanel,
    "VanillaEnhancedOptionsMainShowChatMessagePrefix",
    "showChatMessagePrefix",
    T("options.main.showChatMessagePrefix.label"),
    mainSubtitle
)
CreateHelpText(
    mainPanel,
    T("options.main.showChatMessagePrefix.help"),
    mainShowChatMessagePrefixCheck
)

local questsPanel = CreatePanel("VanillaEnhancedQuestsOptionsPanel", T("module.quests"))
questsPanel.parent = VanillaEnhanced.displayName
local questsSubtitle = CreateSubtitle(questsPanel, T("options.quests.subtitle"))
local questsEnabledCheck = CreateModuleEnabledCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsEnabled",
    "quests",
    T("options.quests.enable.label"),
    questsSubtitle
)
CreateHelpText(
    questsPanel,
    T("options.quests.enable.help"),
    questsEnabledCheck
)
local questsKeepQuestLogWithMapCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsKeepQuestLogWithMap",
    "quests",
    "keepQuestLogWithMap",
    T("options.quests.keepQuestLogWithMap.label"),
    questsEnabledCheck
)
AnchorBelowHelp(questsKeepQuestLogWithMapCheck, questsEnabledCheck)
CreateHelpText(
    questsPanel,
    T("options.quests.keepQuestLogWithMap.help"),
    questsKeepQuestLogWithMapCheck
)
local questsEnableQuestTrackerClicksCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsEnableQuestTrackerClicks",
    "quests",
    "enableQuestTrackerClicks",
    T("options.quests.enableQuestTrackerClicks.label"),
    questsKeepQuestLogWithMapCheck
)
AnchorBelowHelp(questsEnableQuestTrackerClicksCheck, questsKeepQuestLogWithMapCheck)
CreateHelpText(
    questsPanel,
    T("options.quests.enableQuestTrackerClicks.help"),
    questsEnableQuestTrackerClicksCheck
)
local questsShowMapMarkersCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowMapMarkers",
    "quests",
    "showMapMarkers",
    T("options.quests.showMapMarkers.label"),
    questsEnableQuestTrackerClicksCheck
)
AnchorBelowHelp(questsShowMapMarkersCheck, questsEnableQuestTrackerClicksCheck)
CreateHelpText(
    questsPanel,
    T("options.quests.showMapMarkers.help"),
    questsShowMapMarkersCheck
)
local questsShowMinimapObjectiveAreasCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowMinimapObjectiveAreas",
    "quests",
    "showMinimapObjectiveAreas",
    T("options.quests.showMinimapObjectiveAreas.label"),
    questsShowMapMarkersCheck
), "quests", "showMapMarkers")
AnchorBelowHelp(questsShowMinimapObjectiveAreasCheck, questsShowMapMarkersCheck)
CreateHelpText(
    questsPanel,
    T("options.quests.showMinimapObjectiveAreas.help"),
    questsShowMinimapObjectiveAreasCheck
)
local questsShowAvailableQuestsCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowAvailableQuests",
    "quests",
    "showAvailableQuests",
    T("options.quests.showAvailableQuests.label"),
    questsShowMinimapObjectiveAreasCheck
), "quests", "showMapMarkers")
AnchorBelowHelp(questsShowAvailableQuestsCheck, questsShowMinimapObjectiveAreasCheck)
CreateHelpText(
    questsPanel,
    T("options.quests.showAvailableQuests.help"),
    questsShowAvailableQuestsCheck
)
local questsOnlyShowNearbyAvailableQuestsCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsOnlyShowNearbyAvailableQuests",
    "quests",
    "onlyShowNearbyAvailableQuests",
    T("options.quests.onlyShowNearbyAvailableQuests.label"),
    questsShowAvailableQuestsCheck
), "quests", "showAvailableQuests")
AnchorBelowHelp(questsOnlyShowNearbyAvailableQuestsCheck, questsShowAvailableQuestsCheck)
questsOnlyShowNearbyAvailableQuestsCheck.enabledWhen = function()
    return IsSettingEnabled("quests", "showMapMarkers")
        and IsSettingEnabled("quests", "showAvailableQuests")
end
CreateHelpText(
    questsPanel,
    T("options.quests.onlyShowNearbyAvailableQuests.help"),
    questsOnlyShowNearbyAvailableQuestsCheck
)
local questsOnlyShowAvailableQuestsAroundPlayerLevelCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsOnlyShowAvailableQuestsAroundPlayerLevel",
    "quests",
    "onlyShowAvailableQuestsAroundPlayerLevel",
    T("options.quests.onlyShowAvailableQuestsAroundPlayerLevel.label"),
    questsOnlyShowNearbyAvailableQuestsCheck
), "quests", "showAvailableQuests")
AnchorBelowHelp(questsOnlyShowAvailableQuestsAroundPlayerLevelCheck, questsOnlyShowNearbyAvailableQuestsCheck)
questsOnlyShowAvailableQuestsAroundPlayerLevelCheck.enabledWhen = function()
    return IsSettingEnabled("quests", "showMapMarkers")
        and IsSettingEnabled("quests", "showAvailableQuests")
end
CreateHelpText(
    questsPanel,
    T("options.quests.onlyShowAvailableQuestsAroundPlayerLevel.help"),
    questsOnlyShowAvailableQuestsAroundPlayerLevelCheck
)
local questsShowCompletedMapObjectivesCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowCompletedMapObjectives",
    "quests",
    "showCompletedMapObjectives",
    T("options.quests.showCompletedMapObjectives.label"),
    questsOnlyShowAvailableQuestsAroundPlayerLevelCheck
), "quests", "showMapMarkers")
AnchorBelowHelp(questsShowCompletedMapObjectivesCheck, questsOnlyShowAvailableQuestsAroundPlayerLevelCheck)
CreateHelpText(
    questsPanel,
    T("options.quests.showCompletedMapObjectives.help"),
    questsShowCompletedMapObjectivesCheck
)
local questsShowCompletedTooltipObjectivesCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowCompletedTooltipObjectives",
    "quests",
    "showCompletedTooltipObjectives",
    T("options.quests.showCompletedTooltipObjectives.label"),
    questsShowCompletedMapObjectivesCheck
)
AnchorBelowHelp(questsShowCompletedTooltipObjectivesCheck, questsShowCompletedMapObjectivesCheck)
CreateHelpText(
    questsPanel,
    T("options.quests.showCompletedTooltipObjectives.help"),
    questsShowCompletedTooltipObjectivesCheck
)

local targetThreatPanel = CreatePanel("VanillaEnhancedTargetThreatOptionsPanel", T("module.targetThreat"))
targetThreatPanel.parent = VanillaEnhanced.displayName
local targetThreatSubtitle = CreateSubtitle(targetThreatPanel, T("options.targetThreat.subtitle"))
local targetThreatEnabledCheck = CreateModuleEnabledCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatEnabled",
    "target-threat",
    T("options.targetThreat.enable.label"),
    targetThreatSubtitle
)
CreateHelpText(
    targetThreatPanel,
    T("options.targetThreat.enable.help"),
    targetThreatEnabledCheck
)
local targetThreatAlwaysShowCheck = CreateModuleSettingCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatAlwaysShow",
    "target-threat",
    "alwaysShow",
    T("options.targetThreat.alwaysShow.label"),
    targetThreatEnabledCheck
)
AnchorBelowHelp(targetThreatAlwaysShowCheck, targetThreatEnabledCheck)
CreateHelpText(
    targetThreatPanel,
    T("options.targetThreat.alwaysShow.help"),
    targetThreatAlwaysShowCheck
)

local bagsPanel = CreatePanel("VanillaEnhancedBagsOptionsPanel", T("module.bags"))
bagsPanel.parent = VanillaEnhanced.displayName
local bagsSubtitle = CreateSubtitle(bagsPanel, T("options.bags.subtitle"))
local bagsSortEnabledCheck = CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsSortEnabled",
    "bags",
    "sortEnabled",
    T("options.bags.sortEnabled.label"),
    bagsSubtitle
)
CreateHelpText(
    bagsPanel,
    T("options.bags.sortEnabled.help"),
    bagsSortEnabledCheck
)
local bagsShowSortButtonCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsShowSortButton",
    "bags",
    "showSortButton",
    T("options.bags.showSortButton.label"),
    bagsSortEnabledCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsShowSortButtonCheck, bagsSortEnabledCheck)
CreateHelpText(
    bagsPanel,
    T("options.bags.showSortButton.help"),
    bagsShowSortButtonCheck
)
local bagsAutoSortAfterLootCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsAutoSortAfterLoot",
    "bags",
    "autoSortAfterLoot",
    T("options.bags.autoSortAfterLoot.label"),
    bagsShowSortButtonCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsAutoSortAfterLootCheck, bagsShowSortButtonCheck)
CreateHelpText(
    bagsPanel,
    T("options.bags.autoSortAfterLoot.help"),
    bagsAutoSortAfterLootCheck
)
local bagsAutoSortAfterLootModeDropdown = CreateModuleDropdown(
    bagsPanel,
    "VanillaEnhancedOptionsBagsAutoSortAfterLootMode",
    "bags",
    "autoSortAfterLootMode",
    T("options.bags.autoSortAfterLootMode.label"),
    {
        { value = "tidy", label = T("options.bags.autoSortAfterLootMode.tidy") },
        { value = "full", label = T("options.bags.autoSortAfterLootMode.full") },
    },
    bagsAutoSortAfterLootCheck
)
bagsAutoSortAfterLootModeDropdown.enabledWhen = function()
    return IsSettingEnabled("bags", "sortEnabled")
        and IsSettingEnabled("bags", "autoSortAfterLoot")
end
CreateHelpText(
    bagsPanel,
    T("options.bags.autoSortAfterLootMode.help"),
    bagsAutoSortAfterLootModeDropdown
)
local bagsAutoSortOnOpenCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsAutoSortOnOpen",
    "bags",
    "autoSortOnOpen",
    T("options.bags.autoSortOnOpen.label"),
    bagsAutoSortAfterLootModeDropdown
), "bags", "sortEnabled")
AnchorBelowHelp(bagsAutoSortOnOpenCheck, bagsAutoSortAfterLootModeDropdown)
CreateHelpText(
    bagsPanel,
    T("options.bags.autoSortOnOpen.help"),
    bagsAutoSortOnOpenCheck
)
local bagsSortOrderDropdown = CreateModuleDropdown(
    bagsPanel,
    "VanillaEnhancedOptionsBagsSortOrder",
    "bags",
    "sortOrder",
    T("options.bags.sortOrder.label"),
    {
        { value = "category", label = T("options.bags.sortOrder.category") },
        { value = "quality", label = T("options.bags.sortOrder.quality") },
        { value = "name", label = T("options.bags.sortOrder.name") },
    },
    bagsAutoSortOnOpenCheck
)
bagsSortOrderDropdown.enabledWhen = function()
    return IsSettingEnabled("bags", "sortEnabled")
end
CreateHelpText(
    bagsPanel,
    T("options.bags.sortOrder.help"),
    bagsSortOrderDropdown
)

local merchantsPanel = CreatePanel("VanillaEnhancedMerchantsOptionsPanel", T("module.merchants"))
merchantsPanel.parent = VanillaEnhanced.displayName
local merchantsSubtitle = CreateSubtitle(merchantsPanel, T("options.merchants.subtitle"))
local merchantsEnabledCheck = CreateModuleEnabledCheck(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsEnabled",
    "merchants",
    T("options.merchants.enable.label"),
    merchantsSubtitle
)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.enable.help"),
    merchantsEnabledCheck
)
local merchantsSellScrapsCheck = CreateModuleSettingCheck(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsSellScraps",
    "merchants",
    "sellScrapsEnabled",
    T("options.merchants.sellScraps.label"),
    merchantsEnabledCheck
)
AnchorBelowHelp(merchantsSellScrapsCheck, merchantsEnabledCheck)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.sellScraps.help"),
    merchantsSellScrapsCheck
)
local merchantsScrapStrategyDropdown = CreateModuleDropdown(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsScrapStrategy",
    "merchants",
    "scrapStrategy",
    T("options.merchants.scrapStrategy.label"),
    {
        { value = "poor-sellable", label = T("options.merchants.scrapStrategy.poorSellable") },
        { value = "poor-unusable-equipment", label = T("options.merchants.scrapStrategy.poorUnusableEquipment") },
        { value = "poor-low-consumables", label = T("options.merchants.scrapStrategy.poorLowConsumables") },
        { value = "poor-low-equipment", label = T("options.merchants.scrapStrategy.poorLowEquipment") },
        { value = "smart", label = T("options.merchants.scrapStrategy.smart") },
    },
    merchantsSellScrapsCheck
)
merchantsScrapStrategyDropdown.enabledWhen = function()
    return IsSettingEnabled("merchants", "sellScrapsEnabled")
end
UIDropDownMenu_SetWidth(merchantsScrapStrategyDropdown, 190)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.scrapStrategy.help"),
    merchantsScrapStrategyDropdown
)
local merchantsSafeManualSellCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsSafeManualSell",
    "merchants",
    "safeManualSell",
    T("options.merchants.safeManualSell.label"),
    merchantsScrapStrategyDropdown
), "merchants", "sellScrapsEnabled")
AnchorBelowHelp(merchantsSafeManualSellCheck, merchantsScrapStrategyDropdown)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.safeManualSell.help"),
    merchantsSafeManualSellCheck
)
local merchantsSortBagsAfterSellingScrapsCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsSortBagsAfterSellingScraps",
    "merchants",
    "sortBagsAfterSellingScraps",
    T("options.merchants.sortBagsAfterSellingScraps.label"),
    merchantsSafeManualSellCheck
), "merchants", "sellScrapsEnabled")
merchantsSortBagsAfterSellingScrapsCheck.enabledWhen = function()
    return IsSettingEnabled("merchants", "sellScrapsEnabled")
        and VanillaEnhanced:IsModuleEnabled("bags")
        and IsSettingEnabled("bags", "sortEnabled")
end
AnchorBelowHelp(merchantsSortBagsAfterSellingScrapsCheck, merchantsSafeManualSellCheck)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.sortBagsAfterSellingScraps.help"),
    merchantsSortBagsAfterSellingScrapsCheck
)
local merchantsAutoSellScrapsCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsAutoSellScraps",
    "merchants",
    "autoSellScraps",
    T("options.merchants.autoSellScraps.label"),
    merchantsSortBagsAfterSellingScrapsCheck
), "merchants", "sellScrapsEnabled")
AnchorBelowHelp(merchantsAutoSellScrapsCheck, merchantsSortBagsAfterSellingScrapsCheck)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.autoSellScraps.help"),
    merchantsAutoSellScrapsCheck
)
local merchantsAutoRepairCheck = CreateModuleSettingCheck(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsAutoRepair",
    "merchants",
    "autoRepair",
    T("options.merchants.autoRepair.label"),
    merchantsAutoSellScrapsCheck
)
AnchorBelowHelp(merchantsAutoRepairCheck, merchantsAutoSellScrapsCheck)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.autoRepair.help"),
    merchantsAutoRepairCheck
)
local merchantsSafeAutoSellCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    merchantsPanel,
    "VanillaEnhancedOptionsMerchantsSafeAutoSell",
    "merchants",
    "safeAutoSell",
    T("options.merchants.safeAutoSell.label"),
    merchantsAutoRepairCheck
), "merchants", "autoSellScraps")
merchantsSafeAutoSellCheck.enabledWhen = function()
    return IsSettingEnabled("merchants", "sellScrapsEnabled")
        and IsSettingEnabled("merchants", "autoSellScraps")
end
AnchorBelowHelp(merchantsSafeAutoSellCheck, merchantsAutoRepairCheck)
CreateHelpText(
    merchantsPanel,
    T("options.merchants.safeAutoSell.help"),
    merchantsSafeAutoSellCheck
)

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

local function RefreshOnShow()
    VanillaEnhanced:RefreshOptions()
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
