import { expect, test } from "bun:test";

test("shared party messages and safeguard low-health warnings", () => {
  const lua = Bun.which("lua") ?? Bun.which("luajit");
  if (!lua) return;

  const result = Bun.spawnSync([lua, "tools/safeguard-messages.test.lua"], {
    cwd: import.meta.dir + "/..",
    stdout: "pipe",
    stderr: "pipe",
  });

  expect(new TextDecoder().decode(result.stderr)).toBe("");
  expect(result.exitCode).toBe(0);
  expect(new TextDecoder().decode(result.stdout)).toContain("safeguard message assertions passed");
});
