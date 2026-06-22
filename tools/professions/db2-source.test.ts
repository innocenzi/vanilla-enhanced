import { expect, test } from "bun:test";
import { buildDb2ProfessionRecipeSource, parseCsv } from "./db2-source";

const SPELL_REAGENTS = `ID,SpellID,Reagent_0,Reagent_1,Reagent_2,Reagent_3,Reagent_4,Reagent_5,Reagent_6,Reagent_7,ReagentCount_0,ReagentCount_1,ReagentCount_2,ReagentCount_3,ReagentCount_4,ReagentCount_5,ReagentCount_6,ReagentCount_7
1,100,2000,2001,0,0,0,0,0,0,2,1,0,0,0,0,0,0
2,101,2000,-2,2002,0,0,0,0,0,1,5,0,0,0,0,0,0
3,102,2003,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0
4,103,2004,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0
`;

const SKILL_LINE_ABILITY = `RaceMask,ID,SkillLine,Spell,MinSkillLineRank,ClassMask,SupercedesSpell,AcquireMethod,TrivialSkillLineRankHigh,TrivialSkillLineRankLow,Flags,NumSkillUps,UniqueBit,TradeSkillCategoryID,SkillupSkillLineID,CharacterPoints_0,CharacterPoints_1
0,10,171,100,50,0,0,0,0,0,0,1,0,0,0,0,0
0,11,171,100,25,0,0,0,0,0,0,1,0,0,0,0,0
0,12,185,101,1,0,0,0,0,0,0,1,0,0,0,0,0
0,13,182,102,1,0,0,0,0,0,0,1,0,0,0,0,0
0,14,171,999,1,0,0,0,0,0,0,1,0,0,0,0,0
`;

test("parses quoted CSV fields", () => {
  expect(parseCsv('ID,Name\n1,"Bolt, Heavy"\n')).toEqual([{ ID: "1", Name: "Bolt, Heavy" }]);
});

test("builds normalized profession source from DB2 CSV", () => {
  const source = buildDb2ProfessionRecipeSource(SPELL_REAGENTS, SKILL_LINE_ABILITY, { build: "test-build" });

  expect(source.meta?.source).toContain("test-build");
  expect(source.recipes).toEqual([
    { spellID: 100, professionID: 171, reagents: [[2000, 2], [2001, 1]] },
    { spellID: 101, professionID: 185, reagents: [[2000, 1]] },
  ]);
});

test("rejects a spell attached to multiple supported professions", () => {
  const skillLineAbility = `${SKILL_LINE_ABILITY}0,15,185,100,1,0,0,0,0,0,0,1,0,0,0,0,0\n`;

  expect(() => buildDb2ProfessionRecipeSource(SPELL_REAGENTS, skillLineAbility)).toThrow(
    "appears under professions",
  );
});
