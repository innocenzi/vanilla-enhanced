# Vanilla Enhanced

A lightweight standalone Burning Crusade Classic utility addon.

Current modules:

- Quests (`quests`) improves questing UIs with tracker clicks, quest log/map pairing, map markers, and tooltip quest hints.
- `bags` adds a sort button to the default bag UI.
- `merchants` adds a merchant button and optional auto-sell for conservative scrap selling.
- `target-threat` adds a numeric threat percent widget to the target frame.

The addon does not depend on Questie at runtime. Its compact database is generated offline from a local Questie install for private/local use.

The Quests module currently supports English and French display text. English is the base data; French is selected automatically when the game client locale is `frFR`.

Slay and loot objectives are shown as areas on the world map only, while precise talk, turn-in, object, and event markers also appear on the minimap when nearby.

NPC and mob tooltips show active quest objective lines when the hovered unit is part of one of your current quests.

## Install

Copy this folder into your TBC Classic `Interface\AddOns` directory as `VanillaEnhanced`.

Disable the external `TargetsThreat` addon when using the `target-threat` module to avoid duplicate widgets.

## Regenerate The Database

Requires Bun, Git, and a Lua 5.1-compatible CLI (`lua` or `luajit`) on `PATH`.

```powershell
bun run build:db
```

The tool downloads the pinned Questie ref from `tools/questie-source.json` into `tools/.cache/`, executes Questie's Lua database and validation pipeline, then generates `data/quests/locations.lua` and `data/quests/locales.lua`. Use `--questie-ref <tag-or-sha>` to intentionally update the source data, `--refresh-questie` to refetch the cache, or `--questie-path <path>` for local Questie debugging.

Run tooling tests with:

```powershell
bun test
```

## In Game

- `/ve quests on`
- `/ve quests off`
- `/ve quests refresh`
- `/ve quests status`
- `/ve target-threat on`
- `/ve target-threat off`
- `/ve target-threat refresh`
- `/ve target-threat status`

The TBC client should load `VanillaEnhanced-BCC.toc`.
