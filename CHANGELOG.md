# Changelog

## 0.5.3 - 2026-06-23


### Features
- **map:** configure marker clear distance


### Fixes
- **quests:** sort auto-follow tracker by distance
- **quests:** ignore objective range when using zone auto follow

## 0.5.2 - 2026-06-23


### Features
- **bags:** allow sorting scraps last


### Fixes
- **map:** avoid protected marker mouse propagation calls

## 0.5.1 - 2026-06-22


### Features
- **quests:** support hiding reputation quests
- **map:** auto clear nearby custom markers
- **merchants:** simplify scrap strategies
- **bags:** add quest icons to bag items
- **bags:** add sorting, stacking and search to banks
- **bags:** add backwards sorting option


### Fixes
- **presets:** don't show finished objectives on maps in guide mode
- **bags:** toggle off scrap marking when closing bags
- **bags:** mute quest item icons
- **bags:** prevent locked item movement without blocking use

## 0.5.0 - 2026-06-22


### Features
- **training:** add training tab
- **professions:** add profession tooltips on items


### Fixes
- **bags:** remove scrap overlay during sorting
- **professions:** prevent recursive skill refresh overflow
- **target-threat:** move threat meter to the right of the portrait
- **bags:** avoid protected bag sorting in combat


### Performance
- **quests:** decrease runtime memory usage
- **localization:** cache locale lookups

## 0.4.0 - 2026-06-22


### Features
- **map:** add map custom markers support
- **map:** support tomtom commands
- **quests:** show nearest objective direction on the minimap
- **quests:** make objective level dimming mandatory
- new setting preset
- **quests:** add option to toggle drop rates in unit tooltips
- set default preset to adventurer


### Fixes
- **map:** only show nearest quest objective marker at edge


### Performance
- **quests:** decrease quest refresh performance impact

## 0.3.1 - 2026-06-21


### Features
- **quests:** dim minimap markers on other floors
- **bags:** add option to show scrap icon on items
- **bags:** add scrap mark controls


### Fixes
- **bags:** close bags if they were not opened before opening character sheet/merchant window
- **bags:** make locked slot persistence more reliable

## 0.3.0 - 2026-06-21


### Features
- **quests:** display repeatable quests on the map
- **quests:** make level difference configurable for map quest availability
- **quests:** support displaying available quests on the minimap
- **quests:** position quest markers above other markers
- **quests:** show item drop rates
- **quests:** hide map markers in fog of war
- **quests:** add auto quest following based on location
- **options:** add tooltips
- **merchants:** support marking items as scrap
- **bags:** item locking
- **core:** add option to disable printing messages
- **bags:** add bag search field
- **bags:** support automatic bag opening
- **options:** add language switcher


### Fixes
- **quests:** display broad objectives on the minimap
- **quests:** black list event quests
- **quests:** remove available quests from the minimap
- **quests:** hide fogged quest markers
- **bags:** hide sort button from keychain
- **merchants:** prevent selling during scrap selection
- **quests:** defer pin refreshes during combat
- **bags:** persist item locks accross sessions
- **core:** persist language selection and refresh options navigation
- **bags:** prevent item right click from no longer working
- **quests:** properly item-drop objective zones
- **quests:** remove circle around named npc objectives


### Performance
- **quests:** improve marker performance

## 0.2.0 - 2026-06-20


### Features
- **quests:** quest map visual improvements and fixes
- **quests:** add minimap objective areas
- **quests:** add tooltip on minimap area hover
- **options:** add panel scrolling support
- **options:** add a way to reset settings
- **quests:** highlight map markers when selecting quests


### Fixes
- **bags:** tolerate delayed slot updates while sorting
- **threat:** move away from buffs


### Performance
- **quests:** reduce refresh work
- **target-threat:** reduce polling overhead
- **bags:** cache bag API lookups

## 0.1.0 - 2026-06-19


### Features
- initial implementation
- add settings ui
- **target-threat:** improve style and add out of combat option
- **quest-map:** add ability to keep quest log and map together
- **quest-map:** add ability to hide completed objectives from the map
- **quest-map:** only show areas on hover
- **quest-map:** spread overlapping markers
- **bags:** add bag improvements module
- add localization
- add merchant features
- add debug option


### Fixes
- improve translations

