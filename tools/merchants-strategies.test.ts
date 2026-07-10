import { expect, test } from "bun:test";

test("merchant scrap strategies are conservative and configurable", () => {
  const lua = Bun.which("lua") ?? Bun.which("luajit");
  if (!lua) return;

  const result = Bun.spawnSync([lua, "tools/merchants-strategies.test.lua"], {
    cwd: import.meta.dir + "/..",
    stdout: "pipe",
    stderr: "pipe",
  });

  expect(new TextDecoder().decode(result.stderr)).toBe("");
  expect(result.exitCode).toBe(0);
  expect(new TextDecoder().decode(result.stdout)).toContain("merchant strategy assertions passed");
});
