import { expect, test } from "bun:test";
import { buildProfessionRecipeArtifacts, type ProfessionRecipeSource } from "./transform";

function fixture(): ProfessionRecipeSource {
  return {
    meta: {
      source: "test source",
      expansion: "TBC",
    },
    recipes: [
      { spellID: 300, professionID: 171, skill: 50, reagents: [[1000, 1], [1001, 2]] },
      { spellID: 200, professionID: 171, skill: 1, reagents: [[1000, 3]] },
      { spellID: 100, professionID: 185, reagents: [[1000, 1]] },
      { spellID: 400, professionID: 202, skill: 300, reagents: [[1002, 4]] },
    ],
  };
}

test("builds compact reagent-indexed Lua", () => {
  const artifacts = buildProfessionRecipeArtifacts(fixture());

  expect(artifacts.recipeCount).toBe(4);
  expect(artifacts.reagentCount).toBe(3);
  expect(artifacts.lua).toContain('source = "test source"');
  expect(artifacts.lua).toContain("[1000] = {{s=200,p=171,q=3,r=1},{s=300,p=171,q=1,r=50},{s=100,p=185,q=1}},");
  expect(artifacts.lua).toContain("[1001] = {{s=300,p=171,q=2,r=50}},");
});

test("rejects unsupported professions", () => {
  const source = fixture();
  source.recipes[0].professionID = 182;

  expect(() => buildProfessionRecipeArtifacts(source)).toThrow("not a supported TBC recipe profession");
});

test("rejects duplicate recipes", () => {
  const source = fixture();
  source.recipes[1].spellID = source.recipes[0].spellID;

  expect(() => buildProfessionRecipeArtifacts(source)).toThrow("duplicated");
});

test("rejects malformed reagents", () => {
  const source = fixture();
  source.recipes[0].reagents = [[1000, 0]];

  expect(() => buildProfessionRecipeArtifacts(source)).toThrow("quantity must be a positive integer");
});
