import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { buildQuestsArtifacts, type NormalizedQuestieDb } from "./db-transform";

function fixture(): NormalizedQuestieDb {
  const killQuest = ["Kill Quest", [[106]], null, 5, 7, 77, 1, null, null, [[[101, "Wolf slain"]]], null, [8], [2], null, null, [3], 12] as any[];
  killQuest[17] = [185, 50];
  killQuest[18] = [609, 3000];
  killQuest[19] = [609, 42000];
  killQuest[22] = 4096;
  killQuest[23] = 1;
  killQuest[26] = 9;
  killQuest[27] = [10, 11];
  killQuest[29] = -1234;
  killQuest[30] = 202;
  killQuest[34] = [[185, 2], [202, -4]];

  return {
    meta: {
      questieRef: "test-ref",
      questieCommit: "test-commit",
      expansion: "TBC",
      locale: "frFR",
      correctionsApplied: true,
    },
    keys: {
      quests: {
        name: 1,
        startedBy: 2,
        finishedBy: 3,
        requiredLevel: 4,
        questLevel: 5,
        requiredRaces: 6,
        requiredClasses: 7,
        requiredSkill: 18,
        requiredMinRep: 19,
        requiredMaxRep: 20,
        triggerEnd: 9,
        objectives: 10,
        preQuestGroup: 12,
        preQuestSingle: 13,
        exclusiveTo: 16,
        zoneOrSort: 17,
        requiredSourceItems: 21,
        nextQuestInChain: 22,
        questFlags: 23,
        specialFlags: 24,
        parentQuest: 25,
        breadcrumbForQuestId: 27,
        breadcrumbs: 28,
        extraObjectives: 29,
        requiredSpell: 30,
        requiredSpecialization: 31,
        requiredMaxLevel: 32,
        availableUntilCompleted: 33,
        availableStartingWith: 34,
        requiredRanks: 35,
        disabledByQuest: 36,
      },
      npcs: { name: 1, spawns: 7 },
      objects: { name: 1, spawns: 4 },
      items: { name: 1, npcDrops: 2, objectDrops: 3, itemDrops: 4 },
    },
    zones: {
      areaToUi: { "12": 1411 },
      parentArea: {},
    },
    data: {
      quests: {
        "1": killQuest,
        "2": ["Loot Quest", null, null, null, null, null, null, null, null, [null, null, [[201, "Wolf pelt"]]], null, null, null, null, null, null, 12],
        "3": ["Object Quest", null, null, null, null, null, null, null, null, [null, [[301, "Open crate"]]], null, null, null, null, null, null, 12],
        "4": ["Trigger Quest", null, null, null, null, null, null, null, ["Discover camp", { "12": [[50, 50]] }], null, null, null, null, null, null, null, 12],
        "5": ["Extra Quest", null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, 12, null, null, null, null, null, null, null, null, null, null, null, [[{ "12": [[20, 20], [24, 20], [20, 24]] }, 0, "Use banner"]]],
        "6": ["Credit Quest", null, null, null, null, null, null, null, null, [null, null, null, null, [[[103, 104], 0, "Freed villager"]]], null, null, null, null, null, null, 12],
        "7": ["Spell Quest", null, null, null, null, null, null, null, null, [null, null, null, null, null, [[1234, "Use relic", 202]]], null, null, null, null, null, null, 12],
        "8": ["Turn In Quest", null, [[105]], null, null, null, null, null, null, null, null, null, null, null, null, null, 12],
      },
      npcs: {
        "101": ["Wolf", null, null, null, null, null, { "12": [[10, 10], [11, 11]] }],
        "102": ["Pelt Wolf", null, null, null, null, null, { "12": [[30, 30]] }],
        "103": ["Captive A", null, null, null, null, null, { "12": [[40, 40]] }],
        "104": ["Captive B", null, null, null, null, null, { "12": [[41, 41]] }],
        "105": ["Quest Finisher", null, null, null, null, null, { "12": [[60, 60]] }],
        "106": ["Quest Starter", null, null, null, null, null, { "12": [[15, 15]] }],
      },
      objects: {
        "301": ["Crate", null, null, { "12": [[70, 70]] }],
      },
      items: {
        "201": ["Wolf Pelt", [102], [301]],
        "202": ["Relic", null, [301]],
      },
    },
    dropRates: {
      items: {
        "201": { "102": 12.5, "999": 4.3 },
        "202": { "102": 99 },
      },
    },
    locale: {
      quests: {
        "1": ["Quete tuer", ["Tuez des loups."]],
        "999": ["Unused", ["Not emitted."]],
      },
      npcs: { "101": ["Loup", null], "999": ["Unused", null] },
      objects: { "301": ["Caisse", null] },
      items: { "201": ["Peau de loup", null], "202": ["Relique", null] },
    },
  };
}

test("builds compact quests Lua from normalized Questie data", () => {
  const artifacts = buildQuestsArtifacts(fixture(), { minQuestCount: 0 });

  expect(artifacts.questCount).toBe(8);
  expect(artifacts.locationLua).toContain('questieRef = "test-ref"');
  expect(artifacts.locationLua).toContain('[1] = { t = "Kill Quest"');
  expect(artifacts.locationLua).toContain('rl = 5');
  expect(artifacts.locationLua).toContain('ql = 7');
  expect(artifacts.locationLua).toContain('rr = 77');
  expect(artifacts.locationLua).toContain('rc = 1');
  expect(artifacts.locationLua).toContain('sk = {185,50}');
  expect(artifacts.locationLua).toContain('rmin = {609,3000}');
  expect(artifacts.locationLua).toContain('rmax = {609,42000}');
  expect(artifacts.locationLua).toContain('pg = {8}');
  expect(artifacts.locationLua).toContain('ps = {2}');
  expect(artifacts.locationLua).toContain('ex = {3}');
  expect(artifacts.locationLua).toContain('rf = 4096');
  expect(artifacts.locationLua).toContain('sf = 1');
  expect(artifacts.locationLua).toContain('bf = 9');
  expect(artifacts.locationLua).toContain('bc = {10,11}');
  expect(artifacts.locationLua).toContain('spell = -1234');
  expect(artifacts.locationLua).toContain('spec = 202');
  expect(artifacts.locationLua).toContain('rk = {{185,2},{202,-4}}');
  expect(artifacts.locationLua).toContain("starts = {");
  expect(artifacts.locationLua).toContain('k = "available"');
  expect(artifacts.locationLua).toContain('k = "slay"');
  expect(artifacts.locationLua).toContain('k = "loot"');
  expect(artifacts.locationLua).toContain('dr = {{102,12.5}}');
  expect(artifacts.locationLua).not.toContain("999,4.3");
  expect(artifacts.locationLua).toContain('k = "object"');
  expect(artifacts.locationLua).toContain('k = "event"');
  expect(artifacts.locationLua).toContain('k = "turnin"');
  expect(artifacts.locationLua).toContain('p = {{20.00,20.00},{24.00,20.00},{20.00,24.00}}');
  expect(artifacts.localeLua).toContain('[1] = { t = "Quete tuer"');
  expect(artifacts.localeLua).toContain('[101] = "Loup"');
  expect(artifacts.localeLua).not.toContain("Unused");
});

test("omits drop rate clusters when normalized data has no matching rate", () => {
  const db = fixture();
  delete db.dropRates;

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.locationLua).not.toContain("dr =");
});

test("skips quests blacklisted by Questie", () => {
  const db = fixture();
  db.blacklist = {
    quests: {
      "1": true,
      "2": false,
    },
  };

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.questCount).toBe(7);
  expect(artifacts.locationLua).not.toContain('t = "Kill Quest"');
  expect(artifacts.locationLua).toContain('t = "Loot Quest"');
  expect(artifacts.localeLua).not.toContain("Quete tuer");
});

test("fails when a referenced NPC is missing", () => {
  const db = fixture();
  delete db.data.npcs["101"];

  expect(() => buildQuestsArtifacts(db, { minQuestCount: 0 })).toThrow("Missing NPC 101");
});

test("fails on unmapped area ids", () => {
  const db = fixture();
  db.zones.areaToUi = {};

  expect(() => buildQuestsArtifacts(db, { minQuestCount: 0 })).toThrow("unmapped area id 12");
});

test("fails on malformed coordinates", () => {
  const db = fixture();
  db.data.npcs["101"] = ["Wolf", null, null, null, null, null, { "12": [[120, 10]] }];

  expect(() => buildQuestsArtifacts(db, { minQuestCount: 0 })).toThrow("invalid coordinate");
});

test("fails below minimum quest count", () => {
  expect(() => buildQuestsArtifacts(fixture(), { minQuestCount: 99 })).toThrow("below minimum 99");
});

function findLua(): string | undefined {
  const candidates = [
    "lua",
    "luajit",
    process.env.LOCALAPPDATA ? resolve(process.env.LOCALAPPDATA, "Programs", "Lua", "bin", "lua.exe") : undefined,
  ].filter((candidate): candidate is string => !!candidate);
  for (const command of candidates) {
    const result = spawnSync(command, ["-v"], { stdio: "ignore" });
    if (!result.error && result.status === 0) return command;
  }
}

test.skipIf(!findLua())("Lua exporter syntax-checks when Lua is available", () => {
  const lua = findLua()!;
  const exporter = resolve(import.meta.dir, "export-questie-db.lua").replace(/\\/g, "\\\\");
  const result = spawnSync(lua, ["-e", `assert(loadfile("${exporter}"))`], { encoding: "utf8" });

  expect(result.status).toBe(0);
});
