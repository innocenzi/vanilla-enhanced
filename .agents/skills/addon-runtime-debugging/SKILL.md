---
name: addon-runtime-debugging
description: Vanilla Enhanced addon runtime debugging workflow. Use when the user reports that addon behavior is not working, broken, inconsistent, misplaced, missing, or asks to help debug, paste logs, collect in-game state, or add a temporary debug command for Lua/WoW UI behavior.
---

# Addon Runtime Debugging

## Workflow

Use this skill to debug behavior that cannot be proven from static code alone and needs in-game state from the user's client.

1. Inspect the relevant module and nearby addon patterns before changing code.
2. Add the smallest useful temporary slash command for the issue, such as `/vemapdebug`.
3. Make the command open a movable in-game frame with a scroll frame and multi-line edit box so the user can select and copy the debug text.
4. Ask the user to run the command in the exact broken state and paste the output back.
5. Iterate the debug output if the first dump does not explain the issue.
6. Remove the slash command, debug window, dump builders, and all debug-only helpers before cleanup or commit.

## Debug Command Pattern

Prefer a command that is narrow to the current bug and easy to grep later.

- Register with `SlashCmdList` and one or two `/ve...debug` aliases.
- Build one plain-text dump string with section headers.
- Show it in a `BasicFrameTemplateWithInset` frame containing a `UIPanelScrollFrameTemplate` and multi-line `EditBox`.
- Select the edit box text and focus it so the user can copy immediately.
- Keep all helper names clearly debug-only, such as `Build...DebugDump`, `Show...DebugDump`, or `Register...DebugCommand`.

## Useful Dump Data

Include only data relevant to the bug, but be generous when the user will need to do another in-game round trip.

- Addon/build metadata and locale when relevant.
- Saved settings, per-character caches, and version fields for the affected module.
- Current player, map, frame, target, bag, merchant, or tooltip context needed to reproduce the issue.
- Relevant WoW API/event output captured from the same state.
- Active rendered frame state for UI placement bugs: shown/hidden, parent, strata, frame level, alpha, dimensions, anchors, map IDs, and coordinates.
- Internal render/filter decisions, including why each candidate was shown, hidden, skipped, or translated.

## Cleanup Requirement

Treat the command as temporary instrumentation, not product behavior.

- Before final cleanup or commit, remove the slash aliases, command registration, debug popup frame, dump builders, and debug-only formatting helpers.
- Run a grep for the command names and debug helper names to confirm nothing remains.
- For Lua-only debug instrumentation, prefer Lua syntax checks and targeted inspection; do not run the repository TypeScript database test suite unless the change also touches that tooling.
