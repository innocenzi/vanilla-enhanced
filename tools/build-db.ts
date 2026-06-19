import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

type LuaValue = null | boolean | number | string | LuaValue[] | LuaRecord;
type LuaRecord = Record<number, LuaValue>;

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
  objectiveIndex?: number;
  split: boolean;
};

type Cluster = {
  x: number;
  y: number;
  r: number;
  c: number;
  o: string;
  k: ObjectiveKind;
  st?: SourceType;
  sid?: number;
  n?: number[];
  oi?: number;
  p?: OutlinePoint[];
};

type OutlinePoint = {
  x: number;
  y: number;
};

type ObjectiveKind = "slay" | "loot" | "event" | "object" | "talk" | "turnin";
type SourceType = "npc" | "object" | "item";

class LuaParser {
  private index = 0;

  constructor(private readonly text: string) {}

  parse(): LuaValue {
    const value = this.value();
    this.ws();
    return value;
  }

  private ws(): void {
    while (this.index < this.text.length) {
      const c = this.text[this.index];
      if (/\s/.test(c)) {
        this.index++;
      } else if (this.text.startsWith("--", this.index)) {
        const end = this.text.indexOf("\n", this.index);
        this.index = end === -1 ? this.text.length : end + 1;
      } else {
        break;
      }
    }
  }

  private value(): LuaValue {
    this.ws();
    const c = this.text[this.index];
    if (c === "{") return this.table();
    if (c === "'" || c === '"') return this.string();
    if (this.text.startsWith("nil", this.index)) {
      this.index += 3;
      return null;
    }
    if (this.text.startsWith("true", this.index)) {
      this.index += 4;
      return true;
    }
    if (this.text.startsWith("false", this.index)) {
      this.index += 5;
      return false;
    }
    return this.number();
  }

  private string(): string {
    const quote = this.text[this.index++];
    let out = "";
    while (this.index < this.text.length) {
      const c = this.text[this.index++];
      if (c === quote) return out;
      if (c === "\\" && this.index < this.text.length) {
        const escaped = this.text[this.index++];
        out += ({ n: "\n", r: "\r", t: "\t" } as Record<string, string>)[escaped] ?? escaped;
      } else {
        out += c;
      }
    }
    throw new Error("Unterminated Lua string");
  }

  private number(): number {
    const start = this.index;
    if (this.text[this.index] === "-") this.index++;
    while (this.index < this.text.length && /[0-9.]/.test(this.text[this.index])) {
      this.index++;
    }
    const raw = this.text.slice(start, this.index);
    if (!raw || raw === "-") {
      throw new Error(`Expected Lua value at ${this.index}: ${this.text.slice(this.index, this.index + 20)}`);
    }
    return raw.includes(".") ? Number.parseFloat(raw) : Number.parseInt(raw, 10);
  }

  private table(): LuaValue[] | LuaRecord {
    this.index++;
    const array: LuaValue[] = [];
    const keyed: LuaRecord = {};
    let nextIndex = 1;
    let hasExplicitKeys = false;

    while (true) {
      this.ws();
      if (this.index >= this.text.length) throw new Error("Unterminated Lua table");
      if (this.text[this.index] === "}") {
        this.index++;
        break;
      }

      let key = 0;
      let explicit = false;
      if (this.text[this.index] === "[") {
        this.index++;
        key = Number(this.value());
        this.ws();
        if (this.text[this.index] !== "]") throw new Error("Expected ]");
        this.index++;
        this.ws();
        if (this.text[this.index] !== "=") throw new Error("Expected =");
        this.index++;
        explicit = true;
      }

      const value = this.value();
      if (explicit) {
        keyed[key] = value;
        hasExplicitKeys = true;
      } else {
        array.push(value);
        keyed[nextIndex++] = value;
      }

      this.ws();
      if (this.text[this.index] === "," || this.text[this.index] === ";") this.index++;
    }

    return hasExplicitKeys ? keyed : array;
  }
}

function extractReturnTable(path: string): LuaValue {
  const text = readFileSync(path, "utf8");
  const matches = [...text.matchAll(/\[\[return\s*(\{[\s\S]*?\})\]\]/g)];
  if (!matches.length) throw new Error(`Could not find serialized return table in ${path}`);
  return new LuaParser(matches[matches.length - 1][1]).parse();
}

function asArray(value: LuaValue | undefined): LuaValue[] | undefined {
  return Array.isArray(value) ? value : undefined;
}

function asRecord(value: LuaValue | undefined): LuaRecord | undefined {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as LuaRecord) : undefined;
}

function values(value: LuaValue | undefined): LuaValue[] {
  if (Array.isArray(value)) return value;
  const record = asRecord(value);
  return record ? Object.values(record) : [];
}

function field(row: LuaValue[] | undefined, luaIndex: number): LuaValue | undefined {
  return row?.[luaIndex - 1] ?? undefined;
}

function int(value: LuaValue | undefined): number {
  return typeof value === "number" ? Math.trunc(value) : 0;
}

function num(value: LuaValue | undefined): number {
  return typeof value === "number" ? value : 0;
}

function text(value: LuaValue | undefined): string {
  return typeof value === "string" ? value : "";
}

function addSpawns(
  points: Point[],
  spawnTable: LuaValue | undefined,
  label: string,
  group: string,
  kind: ObjectiveKind,
  sourceType: SourceType | undefined,
  sourceId: number | undefined,
  tooltipNpcId: number | undefined,
  objectiveIndex: number | undefined,
  split: boolean,
  areaToUi: LuaRecord,
  parentArea: LuaRecord,
): void {
  const spawns = asRecord(spawnTable);
  if (!spawns) return;

  for (const [rawAreaId, coordsValue] of Object.entries(spawns)) {
    const areaId = Number(rawAreaId);
    const parent = int(parentArea[areaId]);
    const uiMap = int(areaToUi[areaId]) || int(areaToUi[parent]);
    if (!uiMap) continue;

    for (const coordValue of values(coordsValue)) {
      const coord = asArray(coordValue);
      if (!coord || coord.length < 2) continue;
      const x = num(coord[0]);
      const y = num(coord[1]);
      if (x < 0 || y < 0) continue;
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
  npcDb: LuaRecord,
  areaToUi: LuaRecord,
  parentArea: LuaRecord,
  groupOverride?: string,
  kind: ObjectiveKind = "slay",
  objectiveIndex?: number,
  split = true,
  sourceType: SourceType = "npc",
  sourceId: number = npcId,
  tooltipNpcId?: number,
): void {
  const npc = asArray(npcDb[npcId]);
  if (!npc) return;
  addSpawns(points, field(npc, 7), label || text(field(npc, 1)), groupOverride ?? `npc:${npcId}`, kind, sourceType, sourceId, tooltipNpcId, objectiveIndex, split, areaToUi, parentArea);
}

function resolveObject(
  points: Point[],
  objectId: number,
  label: string,
  objectDb: LuaRecord,
  areaToUi: LuaRecord,
  parentArea: LuaRecord,
  groupOverride?: string,
  kind: ObjectiveKind = "object",
  objectiveIndex?: number,
  split = true,
  sourceType: SourceType = "object",
  sourceId: number = objectId,
): void {
  const object = asArray(objectDb[objectId]);
  if (!object) return;
  addSpawns(points, field(object, 4), label || text(field(object, 1)), groupOverride ?? `object:${objectId}`, kind, sourceType, sourceId, undefined, objectiveIndex, split, areaToUi, parentArea);
}

function resolveItem(
  points: Point[],
  itemId: number,
  label: string,
  itemDb: LuaRecord,
  npcDb: LuaRecord,
  objectDb: LuaRecord,
  areaToUi: LuaRecord,
  parentArea: LuaRecord,
  objectiveIndex?: number,
  seen = new Set<number>(),
): void {
  if (seen.has(itemId)) return;
  seen.add(itemId);

  const item = asArray(itemDb[itemId]);
  if (!item) return;
  const itemLabel = label || text(field(item, 1));
  const itemGroup = `item:${itemId}`;

  for (const npcId of values(field(item, 2))) {
    const sourceNpcId = int(npcId);
    resolveNpc(points, sourceNpcId, itemLabel, npcDb, areaToUi, parentArea, itemGroup, "loot", objectiveIndex, false, "item", itemId, sourceNpcId);
  }
  for (const objectId of values(field(item, 3))) {
    resolveObject(points, int(objectId), itemLabel, objectDb, areaToUi, parentArea, itemGroup, "object", objectiveIndex, false, "item", itemId);
  }
  for (const nestedItemId of values(field(item, 4))) {
    resolveItem(points, int(nestedItemId), itemLabel, itemDb, npcDb, objectDb, areaToUi, parentArea, objectiveIndex, seen);
  }
}

function collectPoints(
  quest: LuaValue[],
  npcDb: LuaRecord,
  objectDb: LuaRecord,
  itemDb: LuaRecord,
  areaToUi: LuaRecord,
  parentArea: LuaRecord,
): Point[] {
  const points: Point[] = [];
  const objectives = asArray(field(quest, 10));
  let objectiveIndex = 0;

  if (objectives) {
    for (const entryValue of values(field(objectives, 1))) {
      const entry = asArray(entryValue);
      const label = text(field(entry, 2));
      objectiveIndex++;
      resolveNpc(points, int(field(entry, 1)), label, npcDb, areaToUi, parentArea, undefined, npcObjectiveKind(label), objectiveIndex);
    }
    for (const entryValue of values(field(objectives, 2))) {
      const entry = asArray(entryValue);
      objectiveIndex++;
      resolveObject(points, int(field(entry, 1)), text(field(entry, 2)), objectDb, areaToUi, parentArea, undefined, "object", objectiveIndex);
    }
    for (const entryValue of values(field(objectives, 3))) {
      const entry = asArray(entryValue);
      objectiveIndex++;
      resolveItem(points, int(field(entry, 1)), text(field(entry, 2)), itemDb, npcDb, objectDb, areaToUi, parentArea, objectiveIndex);
    }
    for (const entryValue of values(field(objectives, 5))) {
      const entry = asArray(entryValue);
      const label = text(field(entry, 3));
      objectiveIndex++;
      for (const npcId of values(field(entry, 1))) {
        resolveNpc(points, int(npcId), label, npcDb, areaToUi, parentArea, undefined, npcObjectiveKind(label), objectiveIndex);
      }
    }
    for (const entryValue of values(field(objectives, 6))) {
      const entry = asArray(entryValue);
      objectiveIndex++;
      resolveItem(points, int(field(entry, 3)), text(field(entry, 2)), itemDb, npcDb, objectDb, areaToUi, parentArea, objectiveIndex);
    }
  }

  const trigger = asArray(field(quest, 9));
  if (trigger) addSpawns(points, field(trigger, 2), text(field(trigger, 1)), `trigger:${text(field(trigger, 1))}`, "event", undefined, undefined, undefined, undefined, true, areaToUi, parentArea);

  for (const itemId of values(field(quest, 21))) {
    resolveItem(points, int(itemId), "", itemDb, npcDb, objectDb, areaToUi, parentArea);
  }

  for (const extraValue of values(field(quest, 29))) {
    const extra = asArray(extraValue);
    addSpawns(points, field(extra, 1), text(field(extra, 3)), `extra:${text(field(extra, 3))}`, "event", undefined, undefined, undefined, undefined, true, areaToUi, parentArea);
  }

  return points;
}

function collectTurnInPoints(
  quest: LuaValue[],
  npcDb: LuaRecord,
  objectDb: LuaRecord,
  areaToUi: LuaRecord,
  parentArea: LuaRecord,
): Point[] {
  const points: Point[] = [];
  const finishers = asArray(field(quest, 3));

  for (const npcId of values(field(finishers, 1))) {
    resolveNpc(points, int(npcId), "Turn in", npcDb, areaToUi, parentArea, undefined, "turnin");
  }
  for (const objectId of values(field(finishers, 2))) {
    resolveObject(points, int(objectId), "Turn in", objectDb, areaToUi, parentArea, undefined, "turnin");
  }

  return points;
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
      const cluster = buildCluster(spatialGroup);
      result[spatialGroup[0].uiMap] ??= [];
      result[spatialGroup[0].uiMap].push(cluster);
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
      oi: group[0].objectiveIndex,
      p: buildOutline(group),
    };
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
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) {
      lower.pop();
    }
    lower.push(point);
  }

  const upper: Point[] = [];
  for (let index = sorted.length - 1; index >= 0; index--) {
    const point = sorted[index];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) {
      upper.pop();
    }
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
      const area = Math.abs((previous.x * (current.y - next.y)) + (current.x * (next.y - previous.y)) + (next.x * (previous.y - current.y))) / 2;

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

function parseArgs(): { questie: string; out: string; localeOut?: string } {
  const args = Bun.argv.slice(2);
  const get = (name: string): string | undefined => {
    const index = args.indexOf(name);
    return index >= 0 ? args[index + 1] : undefined;
  };

  const questie = get("--questie");
  const out = get("--out");
  const localeOut = get("--locale-out");
  if (!questie || !out) {
    throw new Error('Usage: bun run tools/build-db.ts --questie "path/to/Questie" --out data/quest-map/quest-locations.lua [--locale-out data/quest-map/quest-locales.lua]');
  }
  return { questie, out, localeOut };
}

function formatCluster(c: Cluster): string {
  const fields = [
    `x = ${c.x.toFixed(2)}`,
    `y = ${c.y.toFixed(2)}`,
    `r = ${c.r.toFixed(2)}`,
    `c = ${c.c}`,
    `k = ${luaString(c.k)}`,
    `o = ${luaString(c.o)}`,
  ];
  if (c.st) fields.push(`st = ${luaString(c.st)}`);
  if (c.sid) fields.push(`sid = ${c.sid}`);
  if (c.n?.length) fields.push(`n = {${c.n.join(",")}}`);
  if (c.oi) fields.push(`oi = ${c.oi}`);
  if (c.p) fields.push(`p = {${c.p.map((point) => `{${point.x.toFixed(2)},${point.y.toFixed(2)}}`).join(",")}}`);
  return `{ ${fields.join(", ")} }`;
}

function addReferences(references: { quests: Set<number>; npcs: Set<number>; objects: Set<number>; items: Set<number> }, questId: number, maps: Record<number, Cluster[]> | undefined): void {
  if (!maps) return;
  references.quests.add(questId);
  for (const clusters of Object.values(maps)) {
    for (const cluster of clusters) {
      if (cluster.st === "npc" && cluster.sid) references.npcs.add(cluster.sid);
      if (cluster.st === "object" && cluster.sid) references.objects.add(cluster.sid);
      if (cluster.st === "item" && cluster.sid) references.items.add(cluster.sid);
    }
  }
}

function localizedQuestTitle(value: LuaValue | undefined): string {
  const row = asArray(value);
  return text(field(row, 1));
}

function localizedQuestObjectiveLines(value: LuaValue | undefined): string[] {
  const row = asArray(value);
  return values(field(row, 2)).map(text).filter(Boolean);
}

function localizedLookupName(value: LuaValue | undefined): string {
  if (typeof value === "string") return value;
  const row = asArray(value);
  return text(field(row, 1));
}

function writeLocaleDb(
  out: string,
  questie: string,
  references: { quests: Set<number>; npcs: Set<number>; objects: Set<number>; items: Set<number> },
): void {
  const questLookup = asRecord(extractReturnTable(join(questie, "Localization", "lookups", "TBC", "lookupQuests", "frFR.lua"))) ?? {};
  const npcLookup = asRecord(extractReturnTable(join(questie, "Localization", "lookups", "TBC", "lookupNpcs", "frFR.lua"))) ?? {};
  const objectLookup = asRecord(extractReturnTable(join(questie, "Localization", "lookups", "TBC", "lookupObjects", "frFR.lua"))) ?? {};
  const itemLookup = asRecord(extractReturnTable(join(questie, "Localization", "lookups", "TBC", "lookupItems", "frFR.lua"))) ?? {};

  const lines: string[] = [
    "-- AUTO GENERATED by tools/build-db.ts. Do not edit by hand.",
    "VanillaEnhancedQuestMapLocaleDB = {",
    `  meta = { source = "Questie-derived TBC frFR locale data", locale = "frFR" },`,
    "  frFR = {",
    "    quests = {",
  ];

  for (const questId of [...references.quests].sort((a, b) => a - b)) {
    const title = localizedQuestTitle(questLookup[questId]);
    const objectives = localizedQuestObjectiveLines(questLookup[questId]);
    if (!title && !objectives.length) continue;
    const fields = [];
    if (title) fields.push(`t = ${luaString(title)}`);
    if (objectives.length) fields.push(`d = {${objectives.map(luaString).join(", ")}}`);
    lines.push(`      [${questId}] = { ${fields.join(", ")} },`);
  }

  lines.push("    },", "    npcs = {");
  for (const npcId of [...references.npcs].sort((a, b) => a - b)) {
    const name = localizedLookupName(npcLookup[npcId]);
    if (name) lines.push(`      [${npcId}] = ${luaString(name)},`);
  }

  lines.push("    },", "    objects = {");
  for (const objectId of [...references.objects].sort((a, b) => a - b)) {
    const name = localizedLookupName(objectLookup[objectId]);
    if (name) lines.push(`      [${objectId}] = ${luaString(name)},`);
  }

  lines.push("    },", "    items = {");
  for (const itemId of [...references.items].sort((a, b) => a - b)) {
    const name = localizedLookupName(itemLookup[itemId]);
    if (name) lines.push(`      [${itemId}] = ${luaString(name)},`);
  }

  lines.push("    },", "  },", "}", "");
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, lines.join("\n"), "utf8");
  console.log(`Wrote frFR locale data to ${out}`);
}

function main(): void {
  const { questie, out, localeOut } = parseArgs();

  const questDb = asRecord(extractReturnTable(join(questie, "Database", "TBC", "tbcQuestDB.lua")));
  const npcDb = asRecord(extractReturnTable(join(questie, "Database", "TBC", "tbcNpcDB.lua")));
  const objectDb = asRecord(extractReturnTable(join(questie, "Database", "TBC", "tbcObjectDB.lua")));
  const itemDb = asRecord(extractReturnTable(join(questie, "Database", "TBC", "tbcItemDB.lua")));
  const areaToUi = asRecord(extractReturnTable(join(questie, "Database", "Zones", "data", "areaIdToUiMapId.lua")));
  const parentArea = asRecord(extractReturnTable(join(questie, "Database", "Zones", "data", "subZoneToParentZone.lua")));

  if (!questDb || !npcDb || !objectDb || !itemDb || !areaToUi || !parentArea) {
    throw new Error("One or more Questie source tables could not be parsed.");
  }

  const compact = new Map<number, { t: string; z: number; maps: Record<number, Cluster[]>; turnins?: Record<number, Cluster[]> }>();
  const references = { quests: new Set<number>(), npcs: new Set<number>(), objects: new Set<number>(), items: new Set<number>() };
  for (const [rawQuestId, questValue] of Object.entries(questDb)) {
    const questId = Number(rawQuestId);
    const quest = asArray(questValue);
    if (!quest) continue;

    const objectivePoints = collectPoints(quest, npcDb, objectDb, itemDb, areaToUi, parentArea);
    const turnInPoints = collectTurnInPoints(quest, npcDb, objectDb, areaToUi, parentArea);
    const points = objectivePoints.length ? objectivePoints : turnInPoints;
    if (!points.length) continue;
    compact.set(questId, {
      t: text(field(quest, 1)),
      z: int(field(quest, 17)),
      maps: cluster(points),
      turnins: turnInPoints.length ? cluster(turnInPoints) : undefined,
    });
    const entry = compact.get(questId)!;
    addReferences(references, questId, entry.maps);
    addReferences(references, questId, entry.turnins);
  }

  const lines: string[] = [
    "-- AUTO GENERATED by tools/build-db.ts. Do not edit by hand.",
    "VanillaEnhancedQuestMapDB = {",
    `  meta = { source = "Questie-derived TBC data", questCount = ${compact.size} },`,
    "  quests = {",
  ];

  for (const questId of [...compact.keys()].sort((a, b) => a - b)) {
    const quest = compact.get(questId)!;
    lines.push(`    [${questId}] = { t = ${luaString(quest.t)}, z = ${quest.z}, maps = {`);
    for (const uiMap of Object.keys(quest.maps).map(Number).sort((a, b) => a - b)) {
      const clusters = quest.maps[uiMap].map(formatCluster);
      lines.push(`      [${uiMap}] = {${clusters.join(", ")}},`);
    }
    lines.push("    },");
    if (quest.turnins) {
      lines.push("    turnins = {");
      for (const uiMap of Object.keys(quest.turnins).map(Number).sort((a, b) => a - b)) {
        const clusters = quest.turnins[uiMap].map(formatCluster);
        lines.push(`      [${uiMap}] = {${clusters.join(", ")}},`);
      }
      lines.push("    },");
    }
    lines.push("    },");
  }

  lines.push("  }", "}", "");
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, lines.join("\n"), "utf8");
  console.log(`Wrote ${compact.size} quests to ${out}`);

  if (localeOut) {
    writeLocaleDb(localeOut, questie, references);
  }
}

main();
