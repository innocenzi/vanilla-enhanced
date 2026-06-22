# Changelog

## 0.5.0 - 2026-06-22


### Features
- Initial implementation
- Add settings ui
- Improve style and add out of combat option
- Add ability to keep quest log and map together
- Add ability to hide completed objectives from the map
- Only show areas on hover
- Spread overlapping markers
- Add bag improvements module
- Add localization
- Add merchant features
- Add debug option
- Quest map visual improvements and fixes
- Add minimap objective areas
- Add tooltip on minimap area hover
- Add panel scrolling support
- Add a way to reset settings
- Highlight map markers when selecting quests
- Display repeatable quests on the map
- Make level difference configurable for map quest availability
- Support displaying available quests on the minimap
- Position quest markers above other markers
- Show item drop rates
- Hide map markers in fog of war
- Add auto quest following based on location
- Add tooltips
- Support marking items as scrap
- Item locking
- Add option to disable printing messages
- Add bag search field
- Support automatic bag opening
- Add language switcher
- Dim minimap markers on other floors
- Add option to show scrap icon on items
- Add scrap mark controls
- Add map custom markers support
- Support tomtom commands
- Show nearest objective direction on the minimap
- Make objective level dimming mandatory
- New setting preset
- Add option to toggle drop rates in unit tooltips
- Set default preset to adventurer
- Add training tab
- Add profession tooltips on items


### Fixes
- Improve translations
- Tolerate delayed slot updates while sorting
- Move away from buffs
- Display broad objectives on the minimap
- Black list event quests
- Remove available quests from the minimap
- Hide fogged quest markers
- Hide sort button from keychain
- Prevent selling during scrap selection
- Defer pin refreshes during combat
- Persist item locks accross sessions
- Persist language selection and refresh options navigation
- Prevent item right click from no longer working
- Properly item-drop objective zones
- Remove circle around named npc objectives
- Close bags if they were not opened before opening character sheet/merchant window
- Make locked slot persistence more reliable
- Only show nearest quest objective marker at edge
- Remove scrap overlay during sorting
- Prevent recursive skill refresh overflow
- Move threat meter to the right of the portrait
- Avoid protected bag sorting in combat


### Performance
- Reduce refresh work
- Reduce polling overhead
- Cache bag API lookups
- Improve marker performance
- Decrease quest refresh performance impact
- Decrease runtime memory usage
- Cache locale lookups

