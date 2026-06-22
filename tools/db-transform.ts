type JsonPrimitive = null | boolean | number | string;
export type JsonValue = JsonPrimitive | JsonValue[] | { [key: string]: JsonValue };
type JsonTable = JsonValue[] | { [key: string]: JsonValue };
type JsonRecord = { [key: string]: JsonValue };

type Point = {
  uiMap: number;
  x: number;
  y: number;
  label: string;
  group: string;
  kind: ObjectiveKind;
  sourceType?: SourceType;
  sourceId?: number;
  tooltipNpcId?: number;
  dropRate?: number;
  objectiveIndex?: number;
  split: boolean;
};

type DropRatePair = [number, number];

export type Cluster = {
  x: number;
  y: number;
  r: number;
  c: number;
  o: string;
  k: ObjectiveKind;
  st?: SourceType;
  sid?: number;
  n?: number[];
  dr?: DropRatePair[];
  oi?: number;
  p?: OutlinePoint[];
};

type OutlinePoint = {
  x: number;
  y: number;
};

type ObjectiveKind = "slay" | "loot" | "event" | "object" | "talk" | "turnin" | "available";
type SourceType = "npc" | "object" | "item";

type QuestAvailability = {
  requiredLevel?: number;
  questLevel?: number;
  requiredRaces?: number;
  requiredClasses?: number;
  requiredSkill?: NumberPair;
  requiredMinRep?: NumberPair;
  requiredMaxRep?: NumberPair;
  preQuestGroup?: number[];
  preQuestSingle?: number[];
  exclusiveTo?: number[];
  nextQuestInChain?: number;
  resetFlags?: number;
  specialFlags?: number;
  breadcrumbForQuestId?: number;
  breadcrumbs?: number[];
  requiredSpell?: number;
  requiredSpecialization?: number;
  parentQuest?: number;
  requiredMaxLevel?: number;
  availableUntilCompleted?: number;
  availableStartingWith?: number;
  requiredRanks?: NumberPair[];
  disabledByQuest?: number;
};

type NumberPair = [number, number];

type CompactQuest = {
  t: string;
  z: number;
  maps: Record<number, Cluster[]>;
  turnins?: Record<number, Cluster[]>;
  starts?: Record<number, Cluster[]>;
  availability?: QuestAvailability;
  reputationQuest?: boolean;
};

export type NormalizedQuestieDb = {
  meta: {
    source?: string;
    questieRef?: string;
    questieCommit?: string;
    expansion?: string;
    locale?: string;
    correctionsApplied?: boolean;
  };
  keys: {
    quests: Record<string, number>;
    npcs: Record<string, number>;
    objects: Record<string, number>;
    items: Record<string, number>;
  };
  zones: {
    areaToUi: Record<string, JsonValue>;
    parentArea: Record<string, JsonValue>;
  };
  blacklist?: {
    quests?: Record<string, JsonValue>;
  };
  data: {
    quests: Record<string, JsonValue>;
    npcs: Record<string, JsonValue>;
    objects: Record<string, JsonValue>;
    items: Record<string, JsonValue>;
  };
  dropRates?: {
    items?: Record<string, JsonValue>;
  };
  locale?: {
    quests?: Record<string, JsonValue>;
    npcs?: Record<string, JsonValue>;
    objects?: Record<string, JsonValue>;
    items?: Record<string, JsonValue>;
  };
};

export type TransformOptions = {
  minQuestCount?: number;
  allowUnmappedAreaIds?: number[];
};

export type BuildArtifacts = {
  locationLua: string;
  localeLua?: string;
  questCount: number;
  references: {
    quests: Set<number>;
    npcs: Set<number>;
    objects: Set<number>;
    items: Set<number>;
  };
};

type KeySet = NormalizedQuestieDb["keys"];

const QUEST_GIVER = {
  creature: 1,
  object: 2,
};

const OBJECTIVE = {
  id: 1,
  text: 2,
};

const OBJECTIVES = {
  creatures: 1,
  objects: 2,
  items: 3,
  reputation: 4,
  killCredits: 5,
  spells: 6,
};

const KILL_CREDIT = {
  creatures: 1,
  text: 3,
};

const SPELL_OBJECTIVE = {
  text: 2,
  item: 3,
};

const TRIGGER = {
  text: 1,
  spawns: 2,
};

const EXTRA_OBJECTIVE = {
  spawns: 1,
  text: 3,
};

const DEFAULT_ALLOW_UNMAPPED_AREA_IDS = new Set([0, 2257, 2917, 2918]);
const QUEST_FLAG_DAILY = 4096;
const QUEST_FLAG_WEEKLY = 32768;
const QUEST_FLAG_MONTHLY = 65536;
const QUEST_RESET_FLAGS = QUEST_FLAG_DAILY | QUEST_FLAG_WEEKLY | QUEST_FLAG_MONTHLY;
const CLUSTER_KIND_IDS: Record<ObjectiveKind, number> = {
  slay: 1,
  loot: 2,
  event: 3,
  object: 4,
  talk: 5,
  turnin: 6,
  available: 7,
};
const CLUSTER_SOURCE_TYPE_IDS: Record<SourceType, number> = {
  npc: 1,
  object: 2,
  item: 3,
};

function asTable(value: JsonValue | undefined): JsonTable | undefined {
  return value && typeof value === "object" ? (value as JsonTable) : undefined;
}

function asRecord(value: JsonValue | undefined): JsonRecord | undefined {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as JsonRecord) : undefined;
}

function values(value: JsonValue | undefined): JsonValue[] {
  if (Array.isArray(value)) return value.filter((entry) => entry !== null);
  const record = asRecord(value);
  return record ? Object.values(record).filter((entry) => entry !== null) : [];
}

function at(value: JsonValue | undefined, luaIndex: number): JsonValue | undefined {
  if (Array.isArray(value)) return value[luaIndex - 1] ?? undefined;
  const record = asRecord(value);
  return record ? record[String(luaIndex)] : undefined;
}

function keyField(keys: Record<string, number>, name: string): number {
  const value = keys[name];
  if (!value) throw new Error(`Questie key map is missing '${name}'`);
  return value;
}

function byKey(value: JsonValue | undefined, keys: Record<string, number>, name: string): JsonValue | undefined {
  return at(value, keyField(keys, name));
}

function int(value: JsonValue | undefined): number {
  return typeof value === "number" ? Math.trunc(value) : 0;
}

function num(value: JsonValue | undefined): number {
  return typeof value === "number" ? value : Number.NaN;
}

function text(value: JsonValue | undefined): string {
  return typeof value === "string" ? value : "";
}

function assertNormalizedDb(value: unknown): NormalizedQuestieDb {
  const db = value as NormalizedQuestieDb;
  if (!db || typeof db !== "object" || !db.keys || !db.data || !db.zones) {
    throw new Error("Normalized Questie DB is missing required top-level sections.");
  }
  for (const section of ["quests", "npcs", "objects", "items"] as const) {
    if (!db.keys[section] || !db.data[section]) {
      throw new Error(`Normalized Questie DB is missing ${section} keys/data.`);
    }
  }
  return db;
}

function getMapRecord(record: Record<string, JsonValue>, id: number): JsonValue | undefined {
  return record[String(id)];
}

function validationError(errors: string[], message: string): void {
  if (errors.length < 100) errors.push(message);
}

function addSpawns(
  points: Point[],
  spawnTable: JsonValue | undefined,
  label: string,
  group: string,
  kind: ObjectiveKind,
  sourceType: SourceType | undefined,
  sourceId: number | undefined,
  tooltipNpcId: number | undefined,
  dropRate: number | undefined,
  objectiveIndex: number | undefined,
  split: boolean,
  db: NormalizedQuestieDb,
  errors: string[],
  context: string,
  allowUnmappedAreaIds: Set<number>,
): void {
  const spawns = asRecord(spawnTable);
  if (!spawns) return;

  for (const [rawAreaId, coordsValue] of Object.entries(spawns)) {
    const areaId = Number(rawAreaId);
    const parent = int(db.zones.parentArea[String(areaId)]);
    const uiMap = int(db.zones.areaToUi[String(areaId)]) || int(db.zones.areaToUi[String(parent)]);
    if (!uiMap) {
      if (!allowUnmappedAreaIds.has(areaId)) {
        validationError(errors, `${context}: unmapped area id ${areaId}`);
      }
      continue;
    }

    for (const coordValue of values(coordsValue)) {
      const coord = asTable(coordValue);
      if (!coord) {
        validationError(errors, `${context}: malformed coordinate in area ${areaId}`);
        continue;
      }
      const x = num(at(coord, 1));
      const y = num(at(coord, 2));
      if (x === -1 && y === -1) continue;
      if (!Number.isFinite(x) || !Number.isFinite(y) || x < 0 || y < 0 || x > 100 || y > 100) {
        validationError(errors, `${context}: invalid coordinate ${x},${y} in area ${areaId}`);
        continue;
      }
      points.push({
        uiMap,
        x,
        y,
        label: label || "Objective",
        group: group || label || "Objective",
        kind,
        sourceType,
        sourceId,
        tooltipNpcId,
        dropRate,
        objectiveIndex,
        split,
      });
    }
  }
}

function npcObjectiveKind(label: string): ObjectiveKind {
  if (/\b(rescu|free|liberat|release|speak|talk|escort|question|warn|heal|reviv|awaken|sign|interact)\w*/i.test(label)) {
    return "talk";
  }
  return "slay";
}

function resolveNpc(
  points: Point[],
  npcId: number,
  label: string,
  db: NormalizedQuestieDb,
  errors: string[],
  allowUnmappedAreaIds: Set<number>,
  groupOverride?: string,
  kind: ObjectiveKind = "slay",
  objectiveIndex?: number,
  split = true,
  sourceType: SourceType = "npc",
  sourceId: number = npcId,
  tooltipNpcId?: number,
  dropRate?: number,
): void {
  if (!npcId) return;
  const npc = getMapRecord(db.data.npcs, npcId);
  if (!npc) {
    validationError(errors, `Missing NPC ${npcId}`);
    return;
  }
  addSpawns(
    points,
    byKey(npc, db.keys.npcs, "spawns"),
    label || text(byKey(npc, db.keys.npcs, "name")),
    groupOverride ?? `npc:${npcId}`,
    kind,
    sourceType,
    sourceId,
    tooltipNpcId,
    dropRate,
    objectiveIndex,
    split,
    db,
    errors,
    `NPC ${npcId}`,
    allowUnmappedAreaIds,
  );
}

function resolveObject(
  points: Point[],
  objectId: number,
  label: string,
  db: NormalizedQuestieDb,
  errors: string[],
  allowUnmappedAreaIds: Set<number>,
  groupOverride?: string,
  kind: ObjectiveKind = "object",
  objectiveIndex?: number,
  split = true,
  sourceType: SourceType = "object",
  sourceId: number = objectId,
): void {
  if (!objectId) return;
  const object = getMapRecord(db.data.objects, objectId);
  if (!object) {
    validationError(errors, `Missing object ${objectId}`);
    return;
  }
  addSpawns(
    points,
    byKey(object, db.keys.objects, "spawns"),
    label || text(byKey(object, db.keys.objects, "name")),
    groupOverride ?? `object:${objectId}`,
    kind,
    sourceType,
    sourceId,
    undefined,
    undefined,
    objectiveIndex,
    split,
    db,
    errors,
    `Object ${objectId}`,
    allowUnmappedAreaIds,
  );
}

function getItemNpcDropRate(db: NormalizedQuestieDb, itemId: number, npcId: number): number | undefined {
  const itemRates = asRecord(db.dropRates?.items?.[String(itemId)]);
  const rate = itemRates?.[String(npcId)];
  return typeof rate === "number" && Number.isFinite(rate) ? rate : undefined;
}

function resolveItem(
  points: Point[],
  itemId: number,
  label: string,
  db: NormalizedQuestieDb,
  errors: string[],
  allowUnmappedAreaIds: Set<number>,
  objectiveIndex?: number,
  seen = new Set<number>(),
): void {
  if (!itemId || seen.has(itemId)) return;
  seen.add(itemId);

  const item = getMapRecord(db.data.items, itemId);
  if (!item) {
    validationError(errors, `Missing item ${itemId}`);
    return;
  }
  const itemLabel = label || text(byKey(item, db.keys.items, "name"));
  const itemGroup = `item:${itemId}`;

  for (const npcId of values(byKey(item, db.keys.items, "npcDrops"))) {
    const sourceNpcId = int(npcId);
    const dropRate = getItemNpcDropRate(db, itemId, sourceNpcId);
    resolveNpc(points, sourceNpcId, itemLabel, db, errors, allowUnmappedAreaIds, itemGroup, "loot", objectiveIndex, true, "item", itemId, sourceNpcId, dropRate);
  }
  for (const objectId of values(byKey(item, db.keys.items, "objectDrops"))) {
    resolveObject(points, int(objectId), itemLabel, db, errors, allowUnmappedAreaIds, itemGroup, "object", objectiveIndex, true, "item", itemId);
  }
  for (const nestedItemId of values(byKey(item, db.keys.items, "itemDrops"))) {
    resolveItem(points, int(nestedItemId), itemLabel, db, errors, allowUnmappedAreaIds, objectiveIndex, seen);
  }
}

function collectPoints(
  questId: number,
  quest: JsonValue,
  db: NormalizedQuestieDb,
  errors: string[],
  allowUnmappedAreaIds: Set<number>,
): Point[] {
  const points: Point[] = [];
  const objectives = byKey(quest, db.keys.quests, "objectives");
  let objectiveIndex = 0;

  if (objectives) {
    for (const entryValue of values(at(objectives, OBJECTIVES.creatures))) {
      const label = text(at(entryValue, OBJECTIVE.text));
      objectiveIndex++;
      resolveNpc(points, int(at(entryValue, OBJECTIVE.id)), label, db, errors, allowUnmappedAreaIds, undefined, npcObjectiveKind(label), objectiveIndex);
    }
    for (const entryValue of values(at(objectives, OBJECTIVES.objects))) {
      objectiveIndex++;
      resolveObject(points, int(at(entryValue, OBJECTIVE.id)), text(at(entryValue, OBJECTIVE.text)), db, errors, allowUnmappedAreaIds, undefined, "object", objectiveIndex);
    }
    for (const entryValue of values(at(objectives, OBJECTIVES.items))) {
      objectiveIndex++;
      resolveItem(points, int(at(entryValue, OBJECTIVE.id)), text(at(entryValue, OBJECTIVE.text)), db, errors, allowUnmappedAreaIds, objectiveIndex);
    }
    for (const entryValue of values(at(objectives, OBJECTIVES.killCredits))) {
      const label = text(at(entryValue, KILL_CREDIT.text));
      objectiveIndex++;
      for (const npcId of values(at(entryValue, KILL_CREDIT.creatures))) {
        resolveNpc(points, int(npcId), label, db, errors, allowUnmappedAreaIds, undefined, npcObjectiveKind(label), objectiveIndex);
      }
    }
    for (const entryValue of values(at(objectives, OBJECTIVES.spells))) {
      objectiveIndex++;
      resolveItem(points, int(at(entryValue, SPELL_OBJECTIVE.item)), text(at(entryValue, SPELL_OBJECTIVE.text)), db, errors, allowUnmappedAreaIds, objectiveIndex);
    }
  }

  const trigger = byKey(quest, db.keys.quests, "triggerEnd");
  if (trigger) {
    addSpawns(
      points,
      at(trigger, TRIGGER.spawns),
      text(at(trigger, TRIGGER.text)),
      `trigger:${text(at(trigger, TRIGGER.text))}`,
      "event",
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      true,
      db,
      errors,
      `Quest ${questId} triggerEnd`,
      allowUnmappedAreaIds,
    );
  }

  for (const itemId of values(byKey(quest, db.keys.quests, "requiredSourceItems"))) {
    resolveItem(points, int(itemId), "", db, errors, allowUnmappedAreaIds);
  }

  for (const extraValue of values(byKey(quest, db.keys.quests, "extraObjectives"))) {
    addSpawns(
      points,
      at(extraValue, EXTRA_OBJECTIVE.spawns),
      text(at(extraValue, EXTRA_OBJECTIVE.text)),
      `extra:${text(at(extraValue, EXTRA_OBJECTIVE.text))}`,
      "event",
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      true,
      db,
      errors,
      `Quest ${questId} extraObjective`,
      allowUnmappedAreaIds,
    );
  }

  return points;
}

function collectTurnInPoints(
  quest: JsonValue,
  db: NormalizedQuestieDb,
  errors: string[],
  allowUnmappedAreaIds: Set<number>,
): Point[] {
  const points: Point[] = [];
  const finishers = byKey(quest, db.keys.quests, "finishedBy");

  for (const npcId of values(at(finishers, QUEST_GIVER.creature))) {
    resolveNpc(points, int(npcId), "Turn in", db, errors, allowUnmappedAreaIds, undefined, "turnin");
  }
  for (const objectId of values(at(finishers, QUEST_GIVER.object))) {
    resolveObject(points, int(objectId), "Turn in", db, errors, allowUnmappedAreaIds, undefined, "turnin");
  }

  return points;
}

function collectStarterPoints(
  quest: JsonValue,
  db: NormalizedQuestieDb,
  errors: string[],
  allowUnmappedAreaIds: Set<number>,
): Point[] {
  const points: Point[] = [];
  const starters = byKey(quest, db.keys.quests, "startedBy");

  for (const npcId of values(at(starters, QUEST_GIVER.creature))) {
    resolveNpc(points, int(npcId), "Available quest", db, errors, allowUnmappedAreaIds, undefined, "available");
  }
  for (const objectId of values(at(starters, QUEST_GIVER.object))) {
    resolveObject(points, int(objectId), "Available quest", db, errors, allowUnmappedAreaIds, undefined, "available");
  }

  return points;
}

function numericList(value: JsonValue | undefined): number[] | undefined {
  const list = values(value).map(int).filter(Boolean);
  return list.length ? list : undefined;
}

function numericPair(value: JsonValue | undefined): NumberPair | undefined {
  const pair = asTable(value);
  if (!pair) return undefined;
  const first = int(at(pair, 1));
  const second = int(at(pair, 2));
  return first ? [first, second] : undefined;
}

function numericPairList(value: JsonValue | undefined): NumberPair[] | undefined {
  const pairs = values(value)
    .map(numericPair)
    .filter((pair): pair is NumberPair => !!pair);
  return pairs.length ? pairs : undefined;
}

function collectAvailability(quest: JsonValue, db: NormalizedQuestieDb): QuestAvailability | undefined {
  const availability: QuestAvailability = {};
  const setNumber = (field: keyof QuestAvailability, key: string) => {
    const value = int(byKey(quest, db.keys.quests, key));
    if (value) (availability[field] as number) = value;
  };
  const setList = (field: keyof QuestAvailability, key: string) => {
    const value = numericList(byKey(quest, db.keys.quests, key));
    if (value) (availability[field] as number[]) = value;
  };
  const setPair = (field: keyof QuestAvailability, key: string) => {
    const value = numericPair(byKey(quest, db.keys.quests, key));
    if (value) (availability[field] as NumberPair) = value;
  };
  const setPairList = (field: keyof QuestAvailability, key: string) => {
    const value = numericPairList(byKey(quest, db.keys.quests, key));
    if (value) (availability[field] as NumberPair[]) = value;
  };

  setNumber("requiredLevel", "requiredLevel");
  setNumber("questLevel", "questLevel");
  setNumber("requiredRaces", "requiredRaces");
  setNumber("requiredClasses", "requiredClasses");
  setPair("requiredSkill", "requiredSkill");
  setPair("requiredMinRep", "requiredMinRep");
  setPair("requiredMaxRep", "requiredMaxRep");
  setList("preQuestGroup", "preQuestGroup");
  setList("preQuestSingle", "preQuestSingle");
  setList("exclusiveTo", "exclusiveTo");
  setNumber("nextQuestInChain", "nextQuestInChain");
  const resetFlags = int(byKey(quest, db.keys.quests, "questFlags")) & QUEST_RESET_FLAGS;
  if (resetFlags) availability.resetFlags = resetFlags;
  setNumber("specialFlags", "specialFlags");
  setNumber("breadcrumbForQuestId", "breadcrumbForQuestId");
  setList("breadcrumbs", "breadcrumbs");
  setNumber("requiredSpell", "requiredSpell");
  setNumber("requiredSpecialization", "requiredSpecialization");
  setNumber("parentQuest", "parentQuest");
  setNumber("requiredMaxLevel", "requiredMaxLevel");
  setNumber("availableUntilCompleted", "availableUntilCompleted");
  setNumber("availableStartingWith", "availableStartingWith");
  setPairList("requiredRanks", "requiredRanks");
  setNumber("disabledByQuest", "disabledByQuest");

  return Object.keys(availability).length ? availability : undefined;
}

function cluster(points: Point[]): Record<number, Cluster[]> {
  const grouped: Record<string, Point[]> = {};
  for (const point of points) {
    const key = `${point.uiMap}:${point.kind}:${point.group}`;
    grouped[key] ??= [];
    grouped[key].push(point);
  }

  const result: Record<number, Cluster[]> = {};
  for (const group of Object.values(grouped)) {
    const spatialGroups = group[0].split ? splitSpatialClusters(group) : [group];
    for (const spatialGroup of spatialGroups) {
      const built = buildCluster(spatialGroup);
      result[spatialGroup[0].uiMap] ??= [];
      result[spatialGroup[0].uiMap].push(built);
    }
  }
  return result;
}

function splitSpatialClusters(points: Point[]): Point[][] {
  const maxDistance = 8;
  const groups: Point[][] = [];

  for (const point of points) {
    let bestGroup: Point[] | undefined;
    let bestDistance = Number.POSITIVE_INFINITY;

    for (const group of groups) {
      const center = getCenter(group);
      const distance = Math.hypot(point.x - center.x, point.y - center.y);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestGroup = group;
      }
    }

    if (bestGroup && bestDistance <= maxDistance) {
      bestGroup.push(point);
    } else {
      groups.push([point]);
    }
  }

  return groups;
}

function getCenter(points: Point[]): { x: number; y: number } {
  return {
    x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
    y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
  };
}

function buildCluster(group: Point[]): Cluster {
  const x = group.reduce((sum, point) => sum + point.x, 0) / group.length;
  const y = group.reduce((sum, point) => sum + point.y, 0) / group.length;
  const radius = Math.max(...group.map((point) => Math.hypot(point.x - x, point.y - y)), 0);
  const label = group.find((point) => point.label)?.label ?? "Objective";
  const tooltipNpcIds = [...new Set(group.map((point) => point.tooltipNpcId).filter((id): id is number => !!id))].sort((a, b) => a - b);
  const dropRates = buildClusterDropRates(group);
  return {
    x: Number(x.toFixed(2)),
    y: Number(y.toFixed(2)),
    r: Number(radius.toFixed(2)),
    c: group.length,
    o: label,
    k: group[0].kind,
    st: group[0].sourceType,
    sid: group[0].sourceId,
    n: tooltipNpcIds.length ? tooltipNpcIds : undefined,
    dr: dropRates,
    oi: group[0].objectiveIndex,
    p: buildOutline(group),
  };
}

function buildClusterDropRates(group: Point[]): DropRatePair[] | undefined {
  const byNpc = new Map<number, number>();
  for (const point of group) {
    if (!point.tooltipNpcId || point.dropRate === undefined) continue;
    byNpc.set(point.tooltipNpcId, Number(point.dropRate.toFixed(3)));
  }
  const pairs = [...byNpc.entries()].sort((a, b) => a[0] - b[0]);
  return pairs.length ? pairs : undefined;
}

function buildOutline(group: Point[]): OutlinePoint[] | undefined {
  if (group.length < 3) return undefined;

  const unique = [...new Map(group.map((point) => [`${point.x.toFixed(2)}:${point.y.toFixed(2)}`, point])).values()];
  if (unique.length < 3) return undefined;

  const hull = convexHull(unique).map((point) => ({
    x: Number(point.x.toFixed(2)),
    y: Number(point.y.toFixed(2)),
  }));
  const simplified = simplifyOutline(hull, 16);
  return simplified.length >= 3 ? simplified : undefined;
}

function convexHull(points: Point[]): Point[] {
  const sorted = [...points].sort((a, b) => a.x - b.x || a.y - b.y);
  const cross = (origin: Point, a: Point, b: Point) =>
    (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x);

  const lower: Point[] = [];
  for (const point of sorted) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) lower.pop();
    lower.push(point);
  }

  const upper: Point[] = [];
  for (let index = sorted.length - 1; index >= 0; index--) {
    const point = sorted[index];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) upper.pop();
    upper.push(point);
  }

  lower.pop();
  upper.pop();
  return lower.concat(upper);
}

function simplifyOutline(points: OutlinePoint[], maxPoints: number): OutlinePoint[] {
  const simplified = [...points];
  while (simplified.length > maxPoints) {
    let bestIndex = 0;
    let bestArea = Number.POSITIVE_INFINITY;

    for (let index = 0; index < simplified.length; index++) {
      const previous = simplified[(index - 1 + simplified.length) % simplified.length];
      const current = simplified[index];
      const next = simplified[(index + 1) % simplified.length];
      const area = Math.abs(previous.x * (current.y - next.y) + current.x * (next.y - previous.y) + next.x * (previous.y - current.y)) / 2;
      if (area < bestArea) {
        bestArea = area;
        bestIndex = index;
      }
    }

    simplified.splice(bestIndex, 1);
  }
  return simplified;
}

function luaString(value: string): string {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, "").replace(/\n/g, "\\n")}"`;
}

function formatMeta(meta: Record<string, string | number | boolean | undefined>): string {
  const fields = Object.entries(meta)
    .filter(([, value]) => value !== undefined)
    .map(([key, value]) => `${key} = ${typeof value === "string" ? luaString(value) : String(value)}`);
  return `{ ${fields.join(", ")} }`;
}

function formatCluster(c: Cluster): string {
  const fields = [
    c.x.toFixed(2),
    c.y.toFixed(2),
    c.r ? c.r.toFixed(2) : undefined,
    c.c !== 1 ? String(c.c) : undefined,
    String(CLUSTER_KIND_IDS[c.k]),
    c.k === "turnin" || c.k === "available" ? undefined : luaString(c.o),
    c.st ? String(CLUSTER_SOURCE_TYPE_IDS[c.st]) : undefined,
    c.sid ? String(c.sid) : undefined,
    c.n?.length ? `{${c.n.join(",")}}` : undefined,
    c.dr?.length ? `{${c.dr.flatMap(([npcId, rate]) => [npcId, rate]).join(",")}}` : undefined,
    c.oi ? String(c.oi) : undefined,
    c.p ? `{${c.p.flatMap((point) => [point.x.toFixed(2), point.y.toFixed(2)]).join(",")}}` : undefined,
  ];

  let lastFieldIndex = fields.length - 1;
  while (lastFieldIndex >= 0 && fields[lastFieldIndex] === undefined) lastFieldIndex--;
  return `{${fields.slice(0, lastFieldIndex + 1).map((field) => field ?? "nil").join(",")}}`;
}

function addReferences(references: BuildArtifacts["references"], questId: number, maps: Record<number, Cluster[]> | undefined): void {
  if (!maps) return;
  references.quests.add(questId);
  for (const clusters of Object.values(maps)) {
    for (const c of clusters) {
      if (c.st === "npc" && c.sid) references.npcs.add(c.sid);
      if (c.st === "object" && c.sid) references.objects.add(c.sid);
      if (c.st === "item" && c.sid) references.items.add(c.sid);
    }
  }
}

function isBlacklistedQuest(db: NormalizedQuestieDb, questId: number): boolean {
  return db.blacklist?.quests?.[String(questId)] === true;
}

function localizedQuestTitle(value: JsonValue | undefined): string {
  return text(at(value, 1));
}

function localizedQuestObjectiveLines(value: JsonValue | undefined): string[] {
  return values(at(value, 2)).map(text).filter(Boolean);
}

function localizedLookupName(value: JsonValue | undefined): string {
  if (typeof value === "string") return value;
  return text(at(value, 1));
}

function formatNumberList(list: number[]): string {
  return `{${list.join(",")}}`;
}

function formatNumberPair(pair: NumberPair): string {
  return `{${pair[0]},${pair[1]}}`;
}

function formatNumberPairList(list: NumberPair[]): string {
  return `{${list.map(formatNumberPair).join(",")}}`;
}

function formatAvailability(availability: QuestAvailability | undefined): string[] {
  if (!availability) return [];
  const fields: string[] = [];
  if (availability.requiredLevel) fields.push(`rl = ${availability.requiredLevel}`);
  if (availability.questLevel) fields.push(`ql = ${availability.questLevel}`);
  if (availability.requiredRaces) fields.push(`rr = ${availability.requiredRaces}`);
  if (availability.requiredClasses) fields.push(`rc = ${availability.requiredClasses}`);
  if (availability.requiredSkill) fields.push(`sk = ${formatNumberPair(availability.requiredSkill)}`);
  if (availability.requiredMinRep) fields.push(`rmin = ${formatNumberPair(availability.requiredMinRep)}`);
  if (availability.requiredMaxRep) fields.push(`rmax = ${formatNumberPair(availability.requiredMaxRep)}`);
  if (availability.preQuestGroup?.length) fields.push(`pg = ${formatNumberList(availability.preQuestGroup)}`);
  if (availability.preQuestSingle?.length) fields.push(`ps = ${formatNumberList(availability.preQuestSingle)}`);
  if (availability.exclusiveTo?.length) fields.push(`ex = ${formatNumberList(availability.exclusiveTo)}`);
  if (availability.nextQuestInChain) fields.push(`nc = ${availability.nextQuestInChain}`);
  if (availability.resetFlags) fields.push(`rf = ${availability.resetFlags}`);
  if (availability.specialFlags) fields.push(`sf = ${availability.specialFlags}`);
  if (availability.breadcrumbForQuestId) fields.push(`bf = ${availability.breadcrumbForQuestId}`);
  if (availability.breadcrumbs?.length) fields.push(`bc = ${formatNumberList(availability.breadcrumbs)}`);
  if (availability.requiredSpell) fields.push(`spell = ${availability.requiredSpell}`);
  if (availability.requiredSpecialization) fields.push(`spec = ${availability.requiredSpecialization}`);
  if (availability.parentQuest) fields.push(`pq = ${availability.parentQuest}`);
  if (availability.requiredMaxLevel) fields.push(`mx = ${availability.requiredMaxLevel}`);
  if (availability.availableUntilCompleted) fields.push(`au = ${availability.availableUntilCompleted}`);
  if (availability.availableStartingWith) fields.push(`as = ${availability.availableStartingWith}`);
  if (availability.requiredRanks?.length) fields.push(`rk = ${formatNumberPairList(availability.requiredRanks)}`);
  if (availability.disabledByQuest) fields.push(`db = ${availability.disabledByQuest}`);
  return fields;
}

function hasEntries(value: JsonValue | undefined): boolean {
  return values(value).length > 0;
}

function hasObjectiveText(quest: JsonValue, db: NormalizedQuestieDb): boolean {
  return values(byKey(quest, db.keys.quests, "objectivesText")).some((entry) => !!text(entry));
}

function hasReputationTurnInShape(quest: JsonValue, db: NormalizedQuestieDb): boolean {
  if (!numericPairList(byKey(quest, db.keys.quests, "reputationReward"))) return false;

  const objectives = byKey(quest, db.keys.quests, "objectives");
  const hasItemObjective = hasEntries(at(objectives, OBJECTIVES.items));
  const hasReputationObjective = !!numericPair(at(objectives, OBJECTIVES.reputation));
  if (!hasItemObjective && !hasReputationObjective) return false;

  const hasNonTurnInObjective =
    hasEntries(at(objectives, OBJECTIVES.creatures)) ||
    hasEntries(at(objectives, OBJECTIVES.objects)) ||
    hasEntries(at(objectives, OBJECTIVES.killCredits)) ||
    hasEntries(at(objectives, OBJECTIVES.spells)) ||
    !!byKey(quest, db.keys.quests, "triggerEnd") ||
    hasEntries(byKey(quest, db.keys.quests, "extraObjectives"));
  if (hasNonTurnInObjective) return false;

  const requiredMinRep = numericPair(byKey(quest, db.keys.quests, "requiredMinRep"));
  const requiredMaxRep = numericPair(byKey(quest, db.keys.quests, "requiredMaxRep"));
  const hasRequiredReputation = !!requiredMaxRep || !!(requiredMinRep && requiredMinRep[1] && requiredMinRep[2] > 0);
  const isNoLevelHandIn = int(byKey(quest, db.keys.quests, "questLevel")) < 0 && !hasObjectiveText(quest, db);
  return hasRequiredReputation || isNoLevelHandIn;
}

function renderMapClusters(lines: string[], name: string, maps: Record<number, Cluster[]>): void {
  lines.push(`    ${name} = {`);
  for (const uiMap of Object.keys(maps).map(Number).sort((a, b) => a - b)) {
    lines.push(`      [${uiMap}] = {${maps[uiMap].map(formatCluster).join(", ")}},`);
  }
  lines.push("    },");
}

function renderLocationLua(db: NormalizedQuestieDb, compact: Map<number, CompactQuest>): string {
  const lines: string[] = [
    "-- AUTO GENERATED by tools/build-db.ts. Do not edit by hand.",
    "VanillaEnhancedQuestsDB = {",
    `  meta = ${formatMeta({
      source: "Questie-derived TBC data",
      questieRef: db.meta.questieRef,
      questieCommit: db.meta.questieCommit,
      expansion: db.meta.expansion ?? "TBC",
      locale: db.meta.locale ?? "frFR",
      questCount: compact.size,
    })},`,
    "  quests = {",
  ];

  for (const questId of [...compact.keys()].sort((a, b) => a - b)) {
    const quest = compact.get(questId)!;
    const fields = [`t = ${luaString(quest.t)}`, `z = ${quest.z}`, ...formatAvailability(quest.availability)];
    if (quest.reputationQuest) fields.push("rq = 1");
    lines.push(`    [${questId}] = { ${fields.join(", ")}, maps = {`);
    for (const uiMap of Object.keys(quest.maps).map(Number).sort((a, b) => a - b)) {
      lines.push(`      [${uiMap}] = {${quest.maps[uiMap].map(formatCluster).join(", ")}},`);
    }
    lines.push("    },");
    if (quest.turnins) {
      renderMapClusters(lines, "turnins", quest.turnins);
    }
    if (quest.starts) {
      renderMapClusters(lines, "starts", quest.starts);
    }
    lines.push("    },");
  }

  lines.push("  }", "}", "");
  return lines.join("\n");
}

function renderLocaleLua(db: NormalizedQuestieDb, references: BuildArtifacts["references"]): string | undefined {
  const locale = db.meta.locale ?? "frFR";
  const localeDb = db.locale;
  if (!localeDb) return undefined;

  const lines: string[] = [
    "-- AUTO GENERATED by tools/build-db.ts. Do not edit by hand.",
    "VanillaEnhancedQuestsLocaleDB = {",
    `  meta = ${formatMeta({
      source: "Questie-derived TBC frFR locale data",
      questieRef: db.meta.questieRef,
      questieCommit: db.meta.questieCommit,
      expansion: db.meta.expansion ?? "TBC",
      locale,
    })},`,
    `  ${locale} = {`,
    "    quests = {",
  ];

  for (const questId of [...references.quests].sort((a, b) => a - b)) {
    const title = localizedQuestTitle(localeDb.quests?.[String(questId)]);
    const objectives = localizedQuestObjectiveLines(localeDb.quests?.[String(questId)]);
    if (!title && !objectives.length) continue;
    const fields = [];
    if (title) fields.push(`t = ${luaString(title)}`);
    if (objectives.length) fields.push(`d = {${objectives.map(luaString).join(", ")}}`);
    lines.push(`      [${questId}] = { ${fields.join(", ")} },`);
  }

  lines.push("    },", "    npcs = {");
  for (const npcId of [...references.npcs].sort((a, b) => a - b)) {
    const name = localizedLookupName(localeDb.npcs?.[String(npcId)]);
    if (name) lines.push(`      [${npcId}] = ${luaString(name)},`);
  }

  lines.push("    },", "    objects = {");
  for (const objectId of [...references.objects].sort((a, b) => a - b)) {
    const name = localizedLookupName(localeDb.objects?.[String(objectId)]);
    if (name) lines.push(`      [${objectId}] = ${luaString(name)},`);
  }

  lines.push("    },", "    items = {");
  for (const itemId of [...references.items].sort((a, b) => a - b)) {
    const name = localizedLookupName(localeDb.items?.[String(itemId)]);
    if (name) lines.push(`      [${itemId}] = ${luaString(name)},`);
  }

  lines.push("    },", "  },", "}", "");
  return lines.join("\n");
}

export function buildQuestsArtifacts(input: unknown, options: TransformOptions = {}): BuildArtifacts {
  const db = assertNormalizedDb(input);
  const errors: string[] = [];
  const allowUnmappedAreaIds = new Set([...(options.allowUnmappedAreaIds ?? []), ...DEFAULT_ALLOW_UNMAPPED_AREA_IDS]);
  const compact = new Map<number, CompactQuest>();
  const references = { quests: new Set<number>(), npcs: new Set<number>(), objects: new Set<number>(), items: new Set<number>() };

  for (const [rawQuestId, questValue] of Object.entries(db.data.quests)) {
    const questId = Number(rawQuestId);
    if (isBlacklistedQuest(db, questId)) continue;

    const objectivePoints = collectPoints(questId, questValue, db, errors, allowUnmappedAreaIds);
    const turnInPoints = collectTurnInPoints(questValue, db, errors, allowUnmappedAreaIds);
    const starterPoints = collectStarterPoints(questValue, db, errors, allowUnmappedAreaIds);
    const points = objectivePoints.length ? objectivePoints : turnInPoints;
    if (!points.length && !starterPoints.length) continue;

    const maps = points.length ? cluster(points) : {};
    if (points.length && !Object.keys(maps).length) {
      validationError(errors, `Quest ${questId}: produced no map clusters`);
      continue;
    }

    compact.set(questId, {
      t: text(byKey(questValue, db.keys.quests, "name")),
      z: int(byKey(questValue, db.keys.quests, "zoneOrSort")),
      maps,
      turnins: turnInPoints.length ? cluster(turnInPoints) : undefined,
      starts: starterPoints.length ? cluster(starterPoints) : undefined,
      availability: collectAvailability(questValue, db),
      reputationQuest: hasReputationTurnInShape(questValue, db),
    });
    const entry = compact.get(questId)!;
    addReferences(references, questId, entry.maps);
    addReferences(references, questId, entry.turnins);
    addReferences(references, questId, entry.starts);
  }

  const minQuestCount = options.minQuestCount ?? 0;
  if (compact.size < minQuestCount) {
    validationError(errors, `Generated quest count ${compact.size} is below minimum ${minQuestCount}`);
  }
  if (errors.length) {
    const suffix = errors.length >= 100 ? "\n...additional errors omitted" : "";
    throw new Error(`Quest map DB validation failed:\n${errors.join("\n")}${suffix}`);
  }

  return {
    locationLua: renderLocationLua(db, compact),
    localeLua: renderLocaleLua(db, references),
    questCount: compact.size,
    references,
  };
}
