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
        objectivesText: 8,
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
        reputationReward: 26,
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
      dungeonZoneIds: { "999": "Test Dungeon" },
      dungeonZoneMapIds: { "999": 300 },
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
        "107": ["Far Pelt Wolf", null, null, null, null, null, { "12": [[80, 80], [81, 80]] }],
        "103": ["Captive A", null, null, null, null, null, { "12": [[40, 40]] }],
        "104": ["Captive B", null, null, null, null, null, { "12": [[41, 41]] }],
        "105": ["Quest Finisher", null, null, null, null, null, { "12": [[60, 60]] }],
        "106": ["Quest Starter", null, null, null, null, null, { "12": [[15, 15]] }],
      },
      objects: {
        "301": ["Crate", null, null, { "12": [[70, 70]] }],
      },
      items: {
        "201": ["Wolf Pelt", [102, 107], [301]],
        "202": ["Relic", null, [301]],
      },
    },
    dropRates: {
      items: {
        "201": { "102": 12.5, "107": 8, "999": 4.3 },
        "202": { "102": 99 },
      },
    },
    locale: {
      quests: {
        "1": ["Quete tuer", ["Tuez des loups."]],
        "999": ["Unused", ["Not emitted."]],
        "5": ["Quete supplementaire", ["Utilisez la banniere."]],
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
  expect(artifacts.locationLua).toContain("{15.00,15.00,nil,nil,7");
  expect(artifacts.locationLua).toContain("{10.00,10.00,nil,nil,1");
  expect(artifacts.locationLua).toContain("{11.00,11.00,nil,nil,1");
  expect(artifacts.locationLua).toContain("{30.00,30.00,nil,nil,2");
  expect(artifacts.locationLua).toContain("{102,12.5}");
  expect(artifacts.locationLua).not.toContain("999,4.3");
  expect(artifacts.locationLua).toContain("{70.00,70.00,nil,nil,4");
  expect(artifacts.locationLua).toContain("{50.00,50.00,nil,nil,3");
  expect(artifacts.locationLua).toContain("{60.00,60.00,nil,nil,6");
  expect(artifacts.locationLua).toContain("{20.00,20.00,24.00,20.00,20.00,24.00}");
  expect(artifacts.localeLua).toContain('[1] = { t = "Quete tuer"');
  expect(artifacts.localeLua).toContain('[5] = { t = "Quete supplementaire", d = {"Utilisez la banniere."} }');
  expect(artifacts.localeLua).toContain('[101] = "Loup"');
  expect(artifacts.localeLua).not.toContain("Unused");
});

test("uses event objective indexes for matching trigger points", () => {
  const db = fixture();
  const eventQuest = [] as any[];
  eventQuest[0] = "Event Trigger Quest";
  eventQuest[8] = ["Find captive", { "12": [[40, 40]] }];
  eventQuest[9] = [[[103, null, 3]]];
  eventQuest[16] = 12;
  db.data.quests["9"] = eventQuest;

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.locationLua).toContain('{40.00,40.00,nil,nil,3,"Find captive",nil,nil,nil,nil,1}');
});

test("marks reputation turn-in style quests without marking ordinary reputation rewards", () => {
  const db = fixture();
  const normalRepQuest = db.data.quests["1"] as any[];
  normalRepQuest[25] = [[72, 250]];

  const repTurnInQuest = ["Rep Turn In", [[106]], [[105]], 26, -1] as any[];
  repTurnInQuest[9] = [null, null, [[201, "Silk Cloth"]]];
  repTurnInQuest[16] = 12;
  repTurnInQuest[25] = [[72, 350]];
  db.data.quests["9"] = repTurnInQuest;

  const ordinaryRepItemQuest = ["Ordinary Rep Item Quest", null, [[105]], 60, 62] as any[];
  ordinaryRepItemQuest[7] = ["Bring silk cloth."];
  ordinaryRepItemQuest[9] = [null, null, [[201, "Silk Cloth"]]];
  ordinaryRepItemQuest[16] = 12;
  ordinaryRepItemQuest[18] = [72, 0];
  ordinaryRepItemQuest[25] = [[72, 250]];
  db.data.quests["10"] = ordinaryRepItemQuest;

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.locationLua).toContain('[9] = { t = "Rep Turn In", z = 12, rl = 26, ql = -1, rq = 1');
  expect(artifacts.locationLua).toContain('[1] = { t = "Kill Quest", z = 12, rl = 5, ql = 7, rr = 77, rc = 1');
  expect(artifacts.locationLua).not.toContain('[1] = { t = "Kill Quest", z = 12, rl = 5, ql = 7, rr = 77, rc = 1, rq = 1');
  expect(artifacts.locationLua).toContain('[10] = { t = "Ordinary Rep Item Quest", z = 12, rl = 60, ql = 62, rmin = {72,0}');
  expect(artifacts.locationLua).not.toContain('[10] = { t = "Ordinary Rep Item Quest", z = 12, rl = 60, ql = 62, rmin = {72,0}, rq = 1');
});

test("marks dungeon quests from exported dungeon zone ids", () => {
  const db = fixture();
  const dungeonQuest = ["Dungeon Quest", null, [[105]], null, null, null, null, null, null, null, null, null, null, null, null, null, 999] as any[];
  db.data.quests["11"] = dungeonQuest;

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.locationLua).toContain('[11] = { t = "Dungeon Quest", z = 999, dq = 1, dm = 300');
  expect(artifacts.locationLua).toContain('[1] = { t = "Kill Quest", z = 12, rl = 5, ql = 7, rr = 77, rc = 1');
  expect(artifacts.locationLua).not.toContain('[1] = { t = "Kill Quest", z = 12, rl = 5, ql = 7, rr = 77, rc = 1, dq = 1');
});

test("omits drop rate clusters when normalized data has no matching rate", () => {
  const db = fixture();
  delete db.dropRates;

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.locationLua).not.toContain("dr =");
});

test("spatially splits item drop clusters", () => {
  const artifacts = buildQuestsArtifacts(fixture(), { minQuestCount: 0 });

  expect(artifacts.locationLua).toContain('{30.00,30.00,nil,nil,2,"Wolf pelt",3,201,{102},{102,12.5},1}');
  expect(artifacts.locationLua).toContain('{80.00,80.00,nil,nil,2,"Wolf pelt",3,201,{107},{107,8},1}');
  expect(artifacts.locationLua).toContain('{81.00,80.00,nil,nil,2,"Wolf pelt",3,201,{107},{107,8},1}');
});

test("keeps sparse objective spawns as precise markers instead of midpoint areas", () => {
  const db = fixture();
  db.data.quests["9"] = ["Sparse Boss Quest", null, null, null, null, null, null, null, null, [null, null, [[202, "Boss paw"]]], null, null, null, null, null, null, 12];
  db.data.items["202"] = ["Boss Paw", [109]];
  db.data.npcs["109"] = [
    "Static Boss",
    null,
    null,
    null,
    null,
    null,
    { "12": [[32.21, 17.39], [31.47, 15.5]] },
  ];
  db.dropRates = {
    items: {
      "202": { "109": 100 },
    },
  };

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.locationLua).toContain('{32.21,17.39,nil,nil,2,"Boss paw",3,202,{109},{109,100},1}');
  expect(artifacts.locationLua).toContain('{31.47,15.50,nil,nil,2,"Boss paw",3,202,{109},{109,100},1}');
  expect(artifacts.locationLua).not.toContain('{31.84,16.45,1.01,2,2,"Boss paw"');
});

test("spatially splits broad NPC objective clusters", () => {
  const db = fixture();
  db.data.quests["9"] = ["Broad Kill Quest", null, null, null, null, null, null, null, null, [[[108, "Raptor slain"]]], null, null, null, null, null, null, 12];
  db.data.npcs["108"] = [
    "Raptor",
    null,
    null,
    null,
    null,
    null,
    {
      "12": [
        [33.4, 24.55],
        [33.96, 25.47],
        [32.97, 23.89],
        [32.06, 23.79],
        [32.4, 24.59],
        [32.4, 23.17],
        [31.97, 20.68],
        [32.5, 21.42],
        [30.8, 23.22],
        [30.55, 22.47],
        [30.66, 23.5],
        [30.27, 24.66],
        [30.69, 23.72],
        [30.6, 24.0],
        [38.1, 27.02],
        [38.77, 26.17],
        [38.44, 25.24],
        [37.73, 21.48],
        [37.82, 19.75],
        [37.57, 27.9],
        [38.88, 24.59],
        [35.62, 26.33],
        [38.28, 19.16],
        [35.95, 27.15],
        [38.24, 20.49],
        [38.87, 21.64],
        [39.07, 22.09],
        [38.55, 19.79],
        [39.34, 19.1],
      ],
    },
  ];

  const artifacts = buildQuestsArtifacts(db, { minQuestCount: 0 });

  expect(artifacts.locationLua).toContain('[9] = { t = "Broad Kill Quest"');
  expect(artifacts.locationLua).toContain('{31.80,23.51,2.92,14,1,"Raptor slain",1,108,nil,nil,1');
  expect(artifacts.locationLua).toContain('{38.08,23.19,4.73,15,1,"Raptor slain",1,108,nil,nil,1');
  expect(artifacts.locationLua).not.toContain('{35.05,23.35,6.04,29,1,"Raptor slain",1,108,nil,nil,1');
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
