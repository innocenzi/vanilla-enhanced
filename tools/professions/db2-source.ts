import type { ProfessionRecipeSource, ProfessionRecipeSourceEntry } from "./transform";

export const DEFAULT_TBC_DB2_BUILD = "2.5.4.44833";

const SUPPORTED_PROFESSIONS = new Set([129, 164, 165, 171, 185, 186, 197, 202, 333, 755]);

type CsvRow = Record<string, string>;

export type BuildDb2ProfessionSourceOptions = {
  build?: string;
};

function parseCsvLine(line: string): string[] {
  const fields: string[] = [];
  let field = "";
  let quoted = false;

  for (let index = 0; index < line.length; index++) {
    const char = line[index];
    if (quoted) {
      if (char === '"' && line[index + 1] === '"') {
        field += '"';
        index++;
      } else if (char === '"') {
        quoted = false;
      } else {
        field += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ",") {
      fields.push(field);
      field = "";
    } else {
      field += char;
    }
  }

  fields.push(field);
  return fields;
}

export function parseCsv(content: string): CsvRow[] {
  const lines = content.replace(/^\uFEFF/, "").split(/\r?\n/).filter((line) => line.length > 0);
  if (!lines.length) return [];

  const headers = parseCsvLine(lines[0]);
  return lines.slice(1).map((line, index) => {
    const fields = parseCsvLine(line);
    if (fields.length !== headers.length) {
      throw new Error(`CSV row ${index + 2} has ${fields.length} fields, expected ${headers.length}.`);
    }

    const row: CsvRow = {};
    headers.forEach((header, fieldIndex) => {
      row[header] = fields[fieldIndex];
    });
    return row;
  });
}

function numberField(row: CsvRow, field: string): number {
  const value = Number(row[field]);
  if (!Number.isFinite(value) || Math.trunc(value) !== value) {
    throw new Error(`DB2 field ${field} must be an integer, got '${row[field]}'.`);
  }
  return value;
}

function collectSpellReagents(spellReagentsCsv: string): Map<number, [number, number][]> {
  const reagentsBySpell = new Map<number, [number, number][]>();

  for (const row of parseCsv(spellReagentsCsv)) {
    const spellID = numberField(row, "SpellID");
    if (spellID <= 0) continue;

    const reagents: [number, number][] = [];
    for (let index = 0; index < 8; index++) {
      const reagentID = numberField(row, `Reagent_${index}`);
      const quantity = numberField(row, `ReagentCount_${index}`);
      if (reagentID > 0 && quantity > 0) {
        reagents.push([reagentID, quantity]);
      }
    }

    if (!reagents.length) continue;
    if (reagentsBySpell.has(spellID)) {
      throw new Error(`SpellReagents contains duplicate SpellID ${spellID}.`);
    }
    reagentsBySpell.set(spellID, reagents);
  }

  return reagentsBySpell;
}

export function buildDb2ProfessionRecipeSource(
  spellReagentsCsv: string,
  skillLineAbilityCsv: string,
  options: BuildDb2ProfessionSourceOptions = {},
): ProfessionRecipeSource {
  const reagentsBySpell = collectSpellReagents(spellReagentsCsv);
  const recipesBySpell = new Map<number, ProfessionRecipeSourceEntry>();

  for (const row of parseCsv(skillLineAbilityCsv)) {
    const professionID = numberField(row, "SkillLine");
    if (!SUPPORTED_PROFESSIONS.has(professionID)) continue;

    const spellID = numberField(row, "Spell");
    const reagents = reagentsBySpell.get(spellID);
    if (!reagents) continue;

    const existing = recipesBySpell.get(spellID);
    if (existing) {
      if (existing.professionID !== professionID) {
        throw new Error(`Spell ${spellID} appears under professions ${existing.professionID} and ${professionID}.`);
      }
      continue;
    }

    // Classic SkillLineAbility exports do not reliably expose the required
    // recipe rank here. MinSkillLineRank is commonly 1 for crafted recipes.
    recipesBySpell.set(spellID, {
      spellID,
      professionID,
      reagents,
    });
  }

  const recipes = [...recipesBySpell.values()].sort((left, right) =>
    left.professionID - right.professionID ||
    (left.skill ?? 0) - (right.skill ?? 0) ||
    left.spellID - right.spellID
  );

  return {
    meta: {
      source: `Wago Tools DB2 SpellReagents + SkillLineAbility (${options.build ?? DEFAULT_TBC_DB2_BUILD})`,
      expansion: "TBC",
    },
    recipes,
  };
}
