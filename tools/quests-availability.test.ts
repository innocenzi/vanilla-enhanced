import { expect, test } from "bun:test";

test("available quest eligibility is deterministic and conservative", () => {
  const lua = Bun.which("lua") ?? Bun.which("luajit");
  if (!lua) return;

  const result = Bun.spawnSync([lua, "tools/quests-availability.test.lua"], {
    cwd: import.meta.dir + "/..",
    stdout: "pipe",
    stderr: "pipe",
  });

  expect(new TextDecoder().decode(result.stderr)).toBe("");
  expect(result.exitCode).toBe(0);
  expect(new TextDecoder().decode(result.stdout)).toContain("quest availability assertions passed");
});
