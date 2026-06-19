local VanillaEnhanced = _G.VanillaEnhanced

local STRINGS = {
    enUS = {
        ["module.quests"] = "Quests",
        ["module.targetThreat"] = "Target threat",
        ["module.bags"] = "Bags",

        ["options.main.subtitle"] = "Turn modules on or off and adjust their options.",

        ["options.quests.subtitle"] = "Improves the quest tracker, quest log, maps, and tooltips.",
        ["options.quests.enable.label"] = "Enable",
        ["options.quests.enable.help"] = "Turn on the quest tracker, map, and tooltip changes.",
        ["options.quests.keepQuestLogWithMap.label"] = "Show quest log with map",
        ["options.quests.keepQuestLogWithMap.help"] = "Open the quest log beside the world map when possible.",
        ["options.quests.enableQuestTrackerClicks.label"] = "Clickable quest tracker",
        ["options.quests.enableQuestTrackerClicks.help"] = "Click a watched quest to open it in your quest log.",
        ["options.quests.showMapMarkers.label"] = "Quest markers on maps",
        ["options.quests.showMapMarkers.help"] = "Show quest locations on the world map and minimap.",
        ["options.quests.spreadOverlappingMarkers.label"] = "Separate stacked markers",
        ["options.quests.spreadOverlappingMarkers.help"] = "Spread nearby world map markers while you hover one.",
        ["options.quests.showCompletedMapObjectives.label"] = "Completed objectives on maps",
        ["options.quests.showCompletedMapObjectives.help"] = "Keep finished objective locations visible. Turn-in locations still appear.",
        ["options.quests.showCompletedTooltipObjectives.label"] = "Completed objectives in tooltips",
        ["options.quests.showCompletedTooltipObjectives.help"] = "Keep tooltip hints for objectives you have already finished.",

        ["options.targetThreat.subtitle"] = "Shows your threat percentage on the target frame.",
        ["options.targetThreat.enable.label"] = "Enable",
        ["options.targetThreat.enable.help"] = "Show your threat percentage near the target frame.",
        ["options.targetThreat.alwaysShow.label"] = "Show out of combat",
        ["options.targetThreat.alwaysShow.help"] = "Keep the threat text visible when you have a target, even outside combat.",

        ["options.bags.subtitle"] = "Adds bag sorting options.",
        ["options.bags.sortEnabled.label"] = "Enable sorting",
        ["options.bags.sortEnabled.help"] = "Turn on bag sorting.",
        ["options.bags.showSortButton.label"] = "Sort button",
        ["options.bags.showSortButton.help"] = "Show a sort button near the backpack.",
        ["options.bags.autoSortAfterLoot.label"] = "Sort after looting",
        ["options.bags.autoSortAfterLoot.help"] = "Sort your bags after the loot window closes.",
        ["options.bags.autoSortOnOpen.label"] = "Sort when bags open",
        ["options.bags.autoSortOnOpen.help"] = "Sort your bags when you open them.",
        ["options.bags.sortOrder.label"] = "Sort by",
        ["options.bags.sortOrder.category"] = "Category",
        ["options.bags.sortOrder.quality"] = "Quality",
        ["options.bags.sortOrder.name"] = "Name",
        ["options.bags.sortOrder.help"] = "Choose how items are ordered when the addon sorts your bags.",

        ["bags.sort.button"] = "Sort",
        ["bags.sort.tooltipTitle"] = "Sort bags",
        ["bags.sort.tooltipBody"] = "Sorts your backpack and equipped bags.",
        ["bags.sort.debugPrefix"] = "Bags debug: {message}",
        ["bags.sort.debugAutoSort"] = "auto sorting after {reason}",
        ["bags.sort.debugMove"] = "moving bag {sourceBag} slot {sourceSlot} to bag {targetBag} slot {targetSlot}",
        ["bags.sort.debugWaitLocked"] = "waiting for locked bag {bag} slot {slot}",
        ["bags.sort.reasonTrigger"] = "trigger",
        ["bags.sort.reasonOpen"] = "opening bags",
        ["bags.sort.reasonLoot"] = "looting",
        ["bags.sort.errorChanged"] = "Bag sorting stopped because item positions changed unexpectedly.",
        ["bags.sort.errorRunning"] = "Bag sorting is already running.",
        ["bags.sort.errorUnavailableClient"] = "Manual bag sorting is not available on this client.",
        ["bags.sort.errorCursor"] = "Bag sorting is unavailable while an item is on your cursor.",
        ["bags.sort.errorPickup"] = "Bag sorting stopped because an item could not be picked up.",
        ["bags.sort.errorMove"] = "Bag sorting stopped because an item could not be moved.",
        ["bags.sort.errorLocked"] = "Bag sorting stopped because bag {bag} slot {slot} stayed locked.",

        ["quests.static.turnin"] = "Turn in",
        ["quests.static.nearbyObjectives"] = "nearby objectives",
        ["quests.static.areaObjectives"] = "objective points in this area",
        ["quests.static.multipleObjectives"] = "Multiple objectives",
    },

    frFR = {
        ["module.quests"] = "Quêtes",
        ["module.targetThreat"] = "Menace",
        ["module.bags"] = "Sacs",

        ["options.main.subtitle"] = "Activez ou désactivez les modules et ajustez leurs options.",

        ["options.quests.subtitle"] = "Améliore le suivi des quêtes, le journal, les cartes et les infobulles.",
        ["options.quests.enable.label"] = "Activer",
        ["options.quests.enable.help"] = "Active le suivi des quêtes, la carte et les changements d'infobulles.",
        ["options.quests.keepQuestLogWithMap.label"] = "Afficher le journal avec la carte",
        ["options.quests.keepQuestLogWithMap.help"] = "Ouvre le journal des quêtes à côté de la carte du monde lorsque c'est possible.",
        ["options.quests.enableQuestTrackerClicks.label"] = "Suivi des quêtes cliquable",
        ["options.quests.enableQuestTrackerClicks.help"] = "Cliquez sur une quête suivie pour l'ouvrir dans votre journal.",
        ["options.quests.showMapMarkers.label"] = "Marqueurs de quêtes sur les cartes",
        ["options.quests.showMapMarkers.help"] = "Affiche les emplacements de quêtes sur la carte du monde et la minicarte.",
        ["options.quests.spreadOverlappingMarkers.label"] = "Séparer les marqueurs empilés",
        ["options.quests.spreadOverlappingMarkers.help"] = "Écarte les marqueurs proches sur la carte du monde quand vous en survolez un.",
        ["options.quests.showCompletedMapObjectives.label"] = "Objectifs terminés sur les cartes",
        ["options.quests.showCompletedMapObjectives.help"] = "Garde visibles les emplacements des objectifs terminés. Les lieux de rendu restent affichés.",
        ["options.quests.showCompletedTooltipObjectives.label"] = "Objectifs terminés dans les infobulles",
        ["options.quests.showCompletedTooltipObjectives.help"] = "Garde les indices d'infobulle pour les objectifs déjà terminés.",

        ["options.targetThreat.subtitle"] = "Affiche votre pourcentage de menace près du cadre de la cible.",
        ["options.targetThreat.enable.label"] = "Activer",
        ["options.targetThreat.enable.help"] = "Affiche votre pourcentage de menace près du cadre de la cible.",
        ["options.targetThreat.alwaysShow.label"] = "Afficher hors combat",
        ["options.targetThreat.alwaysShow.help"] = "Garde le texte de menace visible quand vous avez une cible, même hors combat.",

        ["options.bags.subtitle"] = "Ajoute des options de tri des sacs.",
        ["options.bags.sortEnabled.label"] = "Activer le tri",
        ["options.bags.sortEnabled.help"] = "Active le tri des sacs.",
        ["options.bags.showSortButton.label"] = "Bouton de tri",
        ["options.bags.showSortButton.help"] = "Affiche un bouton de tri près du sac à dos.",
        ["options.bags.autoSortAfterLoot.label"] = "Trier après le butin",
        ["options.bags.autoSortAfterLoot.help"] = "Trie automatiquement vos sacs après la fermeture de la fenêtre de butin.",
        ["options.bags.autoSortOnOpen.label"] = "Trier à l'ouverture des sacs",
        ["options.bags.autoSortOnOpen.help"] = "Trie automatiquement vos sacs quand vous les ouvrez.",
        ["options.bags.sortOrder.label"] = "Trier par",
        ["options.bags.sortOrder.category"] = "Catégorie",
        ["options.bags.sortOrder.quality"] = "Qualité",
        ["options.bags.sortOrder.name"] = "Nom",
        ["options.bags.sortOrder.help"] = "Choisissez comment les objets sont ordonnés quand l'addon trie vos sacs.",

        ["bags.sort.button"] = "Trier",
        ["bags.sort.tooltipTitle"] = "Trier les sacs",
        ["bags.sort.tooltipBody"] = "Trie votre sac à dos et vos sacs équipés.",
        ["bags.sort.debugPrefix"] = "Débogage des sacs : {message}",
        ["bags.sort.debugAutoSort"] = "tri automatique après {reason}",
        ["bags.sort.debugMove"] = "déplacement du sac {sourceBag} emplacement {sourceSlot} vers le sac {targetBag} emplacement {targetSlot}",
        ["bags.sort.debugWaitLocked"] = "attente du sac verrouillé {bag} emplacement {slot}",
        ["bags.sort.reasonTrigger"] = "déclenchement",
        ["bags.sort.reasonOpen"] = "ouverture des sacs",
        ["bags.sort.reasonLoot"] = "butin",
        ["bags.sort.errorChanged"] = "Le tri des sacs s'est arrêté parce que les emplacements des objets ont changé de manière inattendue.",
        ["bags.sort.errorRunning"] = "Le tri des sacs est déjà en cours.",
        ["bags.sort.errorUnavailableClient"] = "Le tri manuel des sacs n'est pas disponible sur ce client.",
        ["bags.sort.errorCursor"] = "Le tri des sacs est indisponible tant qu'un objet est sur votre curseur.",
        ["bags.sort.errorPickup"] = "Le tri des sacs s'est arrêté parce qu'un objet n'a pas pu être ramassé.",
        ["bags.sort.errorMove"] = "Le tri des sacs s'est arrêté parce qu'un objet n'a pas pu être déplacé.",
        ["bags.sort.errorLocked"] = "Le tri des sacs s'est arrêté parce que le sac {bag} emplacement {slot} est resté verrouillé.",

        ["quests.static.turnin"] = "Rendre la quête",
        ["quests.static.nearbyObjectives"] = "objectifs proches",
        ["quests.static.areaObjectives"] = "points d'objectif dans cette zone",
        ["quests.static.multipleObjectives"] = "Objectifs multiples",
    },
}

VanillaEnhanced.localeStrings = STRINGS

function VanillaEnhanced:GetLocaleKey()
    local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
    return locale == "frFR" and "frFR" or "enUS"
end

local function Lookup(locale, key)
    local strings = STRINGS[locale]
    return strings and strings[key] or nil
end

function VanillaEnhanced:T(key, vars)
    local text = Lookup(self:GetLocaleKey(), key) or Lookup("enUS", key) or key
    if type(vars) ~= "table" then
        return text
    end

    local localized = string.gsub(text, "{([%w_]+)}", function(name)
        local value = vars[name]
        if value == nil then
            return "{" .. name .. "}"
        end
        return tostring(value)
    end)
    return localized
end
