# Vanilla Enhanced

A lightweight standalone Burning Crusade Classic utility addon.

Current modules:

- `quest-map` adds numbered quest objective markers to the world map and minimap.
- `target-threat` adds a numeric threat percent widget to the target frame.

The addon does not depend on Questie at runtime. Its compact database is generated offline from a local Questie install for private/local use.

The `quest-map` module currently supports English and French display text. English is the base data; French is selected automatically when the game client locale is `frFR`.

Slay and loot objectives are shown as areas on the world map only, while precise talk, turn-in, object, and event markers also appear on the minimap when nearby.

NPC and mob tooltips show active quest objective lines when the hovered unit is part of one of your current quests.

## Install

Copy this folder into your TBC Classic `Interface\AddOns` directory as `VanillaEnhanced`.

Disable the external `TargetsThreat` addon when using the `target-threat` module to avoid duplicate widgets.

## Regenerate The Database

```powershell
bun run tools/build-db.ts --questie "D:\Games\Blizzard\World of Warcraft\_anniversary_\Interface\AddOns\Questie" --out data/quest-map/quest-locations.lua --locale-out data/quest-map/quest-locales.lua
```

## In Game

- `/ve quest-map on`
- `/ve quest-map off`
- `/ve quest-map refresh`
- `/ve quest-map status`
- `/ve target-threat on`
- `/ve target-threat off`
- `/ve target-threat refresh`
- `/ve target-threat status`

The TBC client should load `VanillaEnhanced-BCC.toc`.
