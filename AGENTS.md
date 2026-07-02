# AGENTS.md

This file is for Codex and other coding agents working on Vanilla Enhanced.

## Project Overview

Vanilla Enhanced is a standalone Burning Crusade Classic and Classic Era addon. It keeps the Blizzard UI recognizable while adding small utility modules:

- `quests`: quest tracker clicks, quest log/map pairing, world map and minimap objective markers, and quest objective tooltip hints.
- `bags`: default bag sorting, a sort button, and optional auto-sort triggers.
- `merchants`: merchant button, conservative scrap selling, optional auto-sell, optional auto-repair, and optional bag sorting after selling.
- `target-threat`: numeric threat percentage near the target frame.

The addon does not depend on Questie at runtime. Quest data is generated offline into flavor-specific files:

- Burning Crusade Classic: `data/quests/tbc/locations.lua` and `data/quests/tbc/locales.lua`
- Classic Era: `data/quests/classic/locations.lua` and `data/quests/classic/locales.lua`

## Runtime Layout

The addon folder must be named `VanillaEnhanced`.

Important files:

- `VanillaEnhanced-BCC.toc`: Burning Crusade Classic TOC and load order.
- `VanillaEnhanced-Classic.toc`: Classic Era TOC and load order.
- `core.lua`: global addon table, module registration, saved-variable helpers, chat output.
- `src/localization.lua`: addon UI strings and `VanillaEnhanced:T`.
- `src/options.lua`: options panels for all modules.
- `src/quests/*`: quest module runtime.
- `src/bags/*`: bag sorting runtime.
- `src/merchants/*`: merchant runtime and scrap strategies.
- `src/target-threat/module.lua`: target threat runtime.
- `data/quests/*`: generated quest data.
- `libs/here-be-dragons/*`: embedded map/pin library.
- `media/*`: runtime marker textures.

Keep the TOC load order in sync with dependencies. `core.lua` and `src/localization.lua` must load before modules that call addon helpers or localization.

## Development Commands

Requires Bun, Git, and a Lua 5.1-compatible CLI (`lua` or `luajit`) for database regeneration.

```powershell
bun test
bun run build:db
bun run build:db:classic
bun run build:db:all
bun run changelog
bun run release
```

`bun test` runs tooling tests, currently focused on the quest database transform.

`bun run build:db` downloads or reads the pinned Questie source and regenerates the Burning Crusade Classic quest data:

- `data/quests/tbc/locations.lua`
- `data/quests/tbc/locales.lua`

`bun run build:db:classic` regenerates the Classic Era quest data:

- `data/quests/classic/locations.lua`
- `data/quests/classic/locales.lua`

`bun run build:db:all` regenerates both TBC and Classic Era quest data. Use per-expansion builds when passing `--keep-normalized`.

Useful database flags:

```powershell
bun run build:db -- --questie-ref <tag-or-sha>
bun run build:db -- --refresh-questie
bun run build:db -- --questie-path <path>
bun run build:db -- --expansion Classic
```

`bun run changelog` regenerates `CHANGELOG.md` with the npm `git-cliff` package.

`bun run release` runs `bumpp`. It bumps `package.json`, updates both TOCs, regenerates `CHANGELOG.md`, creates a release commit, tags it, and pushes by default.

CurseForge automatic packaging uses `.pkgmeta` and does not run Bun scripts. Before pushing a release tag manually, regenerate and commit `CHANGELOG.md`, generated quest data, and any runtime files that should be packaged. When Questie source or quest-generation logic changes, run `bun run build:db:all` before release and commit both generated quest data folders. When using `bun run release`, the `bumpp` hook handles the TOC versions and changelog before the release commit/tag.

## Commit Guidelines

Use conventional commits with one of these types only: `feat`, `perf`, `fix`, `refactor`, or `chore`. The commit scope must be the module being worked on, or `core` if none apply. The commit subject should describe the feature or behavior being changed, not the technical implementation details.

## Packaging Rules

CurseForge expects a WoW addon zip with exactly one root folder and no version number in that folder name:

```text
VanillaEnhanced/
  VanillaEnhanced-BCC.toc
  VanillaEnhanced-Classic.toc
  core.lua
  src/
  data/
  libs/
  media/
  icon.png
  README.md
  CHANGELOG.md
```

`ATTRIBUTION.md` is included when present.

Do not package development-only files such as `.git`, `.agents`, `.release`, `node_modules`, `tools`, or `tools/.cache`.

`.pkgmeta` mirrors those packaging rules for CurseForge automatic packaging. If runtime assets are added, update `.pkgmeta` and the TOC when needed.

## Coding Guidelines

- Use Lua compatible with the Burning Crusade Classic and Classic Era clients.
- Avoid modern Lua features that are not available in WoW's embedded Lua runtime.
- Prefer existing addon helpers on `_G.VanillaEnhanced` for settings, modules, printing, and localization.
- Keep modules independent where practical. Shared behavior belongs in `core.lua` only when it is genuinely common.
- Localize player-facing strings through `src/localization.lua`.
- Use proper French spelling with accents for new or edited `frFR` translations.
- Keep generated quest data out of manual edits; update the generator instead.
- Preserve embedded library files unless intentionally updating the library.
- When changing runtime behavior, check the TOC load order and SavedVariables defaults.
- When changing release contents, update `.pkgmeta` and confirm CurseForge automatic packaging will include the intended runtime files.

## Current Caveats

- Some French strings in existing files appear mojibaked. New or edited French translations should still use correct accents; do not make broad encoding rewrites unless the task is specifically about localization cleanup.
- The addon targets Burning Crusade Classic via `VanillaEnhanced-BCC.toc` and `## Interface: 20505`, and Classic Era via `VanillaEnhanced-Classic.toc` and `## Interface: 11508`.
- The GitHub README is meant for humans. Keep implementation notes here rather than in `README.md`.
