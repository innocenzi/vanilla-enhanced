import { existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { buildQuestMapArtifacts } from "./db-transform";

type SourceConfig = {
  repo: string;
  ref: string;
  expansion: "TBC";
  locale: "frFR";
  minQuestCount: number;
};

type Args = {
  questieRef?: string;
  questiePath?: string;
  lua?: string;
  refreshQuestie: boolean;
  keepNormalized?: string;
};

const ROOT = resolve(import.meta.dir, "..");
const CONFIG_PATH = join(import.meta.dir, "questie-source.json");
const EXPORTER_PATH = join(import.meta.dir, "export-questie-db.lua");
const LOCATION_DB_PATH = "data/quest-map/quest-locations.lua";
const LOCALE_DB_PATH = "data/quest-map/quest-locales.lua";

function parseArgs(): Args {
  const args = Bun.argv.slice(2);
  const get = (name: string): string | undefined => {
    const index = args.indexOf(name);
    return index >= 0 ? args[index + 1] : undefined;
  };

  if (args.includes("--out") || args.includes("--locale-out")) {
    throw new Error("Generated DB output paths are fixed. Usage: bun run build:db -- [--questie-ref v11.29.5] [--questie-path path] [--lua lua] [--refresh-questie] [--keep-normalized path]");
  }

  return {
    questieRef: get("--questie-ref"),
    questiePath: get("--questie-path") ?? get("--questie"),
    lua: get("--lua"),
    refreshQuestie: args.includes("--refresh-questie"),
    keepNormalized: get("--keep-normalized"),
  };
}

function readConfig(): SourceConfig {
  return JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as SourceConfig;
}

function run(command: string, args: string[], options: { cwd?: string; quiet?: boolean } = {}): string {
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    encoding: "utf8",
    stdio: options.quiet ? "pipe" : ["ignore", "pipe", "pipe"],
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed\n${result.stdout ?? ""}${result.stderr ?? ""}`.trim());
  }
  return (result.stdout ?? "").trim();
}

function canRun(command: string): boolean {
  const result = spawnSync(command, ["-v"], { stdio: "ignore" });
  return !result.error && result.status === 0;
}

function resolveLua(explicit?: string): string {
  if (explicit) {
    if (!canRun(explicit)) throw new Error(`Lua executable '${explicit}' was not found or could not run '-v'.`);
    return explicit;
  }
  const candidates = [
    "lua",
    "luajit",
    process.env.LOCALAPPDATA ? join(process.env.LOCALAPPDATA, "Programs", "Lua", "bin", "lua.exe") : undefined,
  ].filter((candidate): candidate is string => !!candidate);
  for (const candidate of candidates) {
    if (canRun(candidate)) return candidate;
  }
  throw new Error("Lua 5.1-compatible CLI is required. Install lua or luajit, or pass --lua <path>.");
}

function safeRefPath(ref: string): string {
  return ref.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function ensureQuestieSource(config: SourceConfig, args: Args): { path: string; ref: string; commit: string } {
  const ref = args.questieRef ?? config.ref;
  if (args.questiePath) {
    const path = resolve(args.questiePath);
    let commit = "local-path";
    try {
      commit = run("git", ["-C", path, "rev-parse", "HEAD"], { quiet: true });
    } catch {
      // Downloaded addon folders usually are not git checkouts.
    }
    return { path, ref, commit };
  }

  const cachePath = join(import.meta.dir, ".cache", "questie", safeRefPath(ref));
  if (args.refreshQuestie && existsSync(cachePath)) {
    rmSync(cachePath, { recursive: true, force: true });
  }
  if (!existsSync(join(cachePath, ".git"))) {
    mkdirSync(cachePath, { recursive: true });
    run("git", ["init"], { cwd: cachePath });
    run("git", ["remote", "add", "origin", config.repo], { cwd: cachePath });
    run("git", ["fetch", "--depth", "1", "origin", ref], { cwd: cachePath });
    run("git", ["checkout", "--detach", "FETCH_HEAD"], { cwd: cachePath });
  }

  const commit = run("git", ["-C", cachePath, "rev-parse", "HEAD"], { quiet: true });
  return { path: cachePath, ref, commit };
}

function exportNormalizedDb(lua: string, questie: { path: string; ref: string; commit: string }, config: SourceConfig, normalizedPath: string): void {
  run(
    lua,
    [
      EXPORTER_PATH,
      "--out",
      normalizedPath,
      "--questie-ref",
      questie.ref,
      "--questie-commit",
      questie.commit,
      "--expansion",
      config.expansion,
      "--locale",
      config.locale,
    ],
    { cwd: questie.path },
  );
}

function workspacePath(path: string, label: string): string {
  const absolute = resolve(ROOT, path);
  const rel = relative(ROOT, absolute);
  if (rel.startsWith("..") || isAbsolute(rel)) {
    throw new Error(`${label} must stay inside the repository: ${path}`);
  }
  return absolute;
}

function writeGeneratedPair(locationLua: string, localeLua: string): void {
  const files = [
    { label: "location DB", path: workspacePath(LOCATION_DB_PATH, "Location DB path"), contents: locationLua },
    { label: "locale DB", path: workspacePath(LOCALE_DB_PATH, "Locale DB path"), contents: localeLua },
  ];
  const tempFiles: { tempPath: string; finalPath: string }[] = [];
  const suffix = `${process.pid}-${Date.now()}`;

  try {
    for (const file of files) {
      mkdirSync(dirname(file.path), { recursive: true });
      const tempPath = join(dirname(file.path), `.${file.label.replace(/\s+/g, "-")}.${suffix}.tmp`);
      writeFileSync(tempPath, file.contents, "utf8");
      tempFiles.push({ tempPath, finalPath: file.path });
    }
    for (const file of tempFiles) {
      renameSync(file.tempPath, file.finalPath);
    }
  } finally {
    for (const file of tempFiles) {
      if (existsSync(file.tempPath)) rmSync(file.tempPath, { force: true });
    }
  }
}

function main(): void {
  const args = parseArgs();
  const config = readConfig();
  const lua = resolveLua(args.lua);
  const questie = ensureQuestieSource(config, args);
  const tempDir = mkdtempSync(join(tmpdir(), "vanilla-enhanced-db-"));
  const normalizedPath = args.keepNormalized ? workspacePath(args.keepNormalized, "Normalized export path") : join(tempDir, "questie-normalized.json");

  mkdirSync(dirname(normalizedPath), { recursive: true });
  console.log(`Exporting Questie ${questie.ref} (${questie.commit}) with ${lua}`);
  exportNormalizedDb(lua, questie, config, normalizedPath);

  const normalized = JSON.parse(readFileSync(normalizedPath, "utf8"));
  const artifacts = buildQuestMapArtifacts(normalized, { minQuestCount: config.minQuestCount });
  if (!artifacts.localeLua) throw new Error("Normalized data did not include locale lookups.");

  writeGeneratedPair(artifacts.locationLua, artifacts.localeLua);

  console.log(`Wrote ${artifacts.questCount} quests to ${LOCATION_DB_PATH}`);
  console.log(`Wrote ${config.locale} locale data to ${LOCALE_DB_PATH}`);
  if (args.keepNormalized) console.log(`Kept normalized Questie export at ${normalizedPath}`);
}

main();
