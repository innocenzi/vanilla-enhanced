import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import { buildDb2ProfessionRecipeSource, DEFAULT_TBC_DB2_BUILD } from "./db2-source";
import { buildProfessionRecipeArtifacts, type ProfessionRecipeSource } from "./transform";

const ROOT = resolve(import.meta.dir, "../..");
const SOURCE_PATH = resolve(import.meta.dir, "source.json");
const OUTPUT_PATH = "data/professions/recipes.lua";
const DB2_CACHE_ROOT = resolve(import.meta.dir, "../.cache/professions/db2");
const DB2_BASE_URL = "https://wago.tools/db2";

type Args = {
  refreshSource: boolean;
  refreshCache: boolean;
  build: string;
};

function parseArgs(): Args {
  const args = Bun.argv.slice(2);
  const get = (name: string): string | undefined => {
    const index = args.indexOf(name);
    return index >= 0 ? args[index + 1] : undefined;
  };

  return {
    refreshSource: args.includes("--refresh-source"),
    refreshCache: args.includes("--refresh-cache"),
    build: get("--build") ?? DEFAULT_TBC_DB2_BUILD,
  };
}

function workspacePath(path: string, label: string): string {
  const absolute = resolve(ROOT, path);
  const rel = relative(ROOT, absolute);
  if (rel.startsWith("..") || isAbsolute(rel)) {
    throw new Error(`${label} must stay inside the repository: ${path}`);
  }
  return absolute;
}

function writeGenerated(path: string, contents: string): void {
  const finalPath = workspacePath(path, "Profession recipe DB path");
  mkdirSync(dirname(finalPath), { recursive: true });
  const tempPath = `${finalPath}.${process.pid}-${Date.now()}.tmp`;

  try {
    writeFileSync(tempPath, contents, "utf8");
    renameSync(tempPath, finalPath);
  } finally {
    if (existsSync(tempPath)) rmSync(tempPath, { force: true });
  }
}

function writeFileAtomic(path: string, contents: string): void {
  mkdirSync(dirname(path), { recursive: true });
  const tempPath = `${path}.${process.pid}-${Date.now()}.tmp`;

  try {
    writeFileSync(tempPath, contents, "utf8");
    renameSync(tempPath, path);
  } finally {
    if (existsSync(tempPath)) rmSync(tempPath, { force: true });
  }
}

async function downloadDb2Csv(table: string, build: string, refreshCache: boolean): Promise<string> {
  const cachePath = join(DB2_CACHE_ROOT, build, `${table}.csv`);
  if (!refreshCache && existsSync(cachePath)) {
    return readFileSync(cachePath, "utf8");
  }

  const url = `${DB2_BASE_URL}/${table}/csv?build=${encodeURIComponent(build)}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download ${table} DB2 CSV from ${url}: HTTP ${response.status}`);
  }

  const content = await response.text();
  writeFileAtomic(cachePath, content);
  return content;
}

async function refreshSourceFromDb2(args: Args): Promise<ProfessionRecipeSource> {
  const [spellReagentsCsv, skillLineAbilityCsv] = await Promise.all([
    downloadDb2Csv("SpellReagents", args.build, args.refreshCache),
    downloadDb2Csv("SkillLineAbility", args.build, args.refreshCache),
  ]);
  const source = buildDb2ProfessionRecipeSource(spellReagentsCsv, skillLineAbilityCsv, { build: args.build });
  writeFileAtomic(SOURCE_PATH, `${JSON.stringify(source, null, 2)}\n`);
  return source;
}

async function main(): Promise<void> {
  const args = parseArgs();
  const source = args.refreshSource
    ? await refreshSourceFromDb2(args)
    : JSON.parse(readFileSync(SOURCE_PATH, "utf8")) as ProfessionRecipeSource;

  const artifacts = buildProfessionRecipeArtifacts(source);
  writeGenerated(OUTPUT_PATH, artifacts.lua);
  console.log(`Wrote ${artifacts.recipeCount} profession recipes across ${artifacts.reagentCount} reagents to ${OUTPUT_PATH}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
