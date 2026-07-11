import { test, expect } from "bun:test";
import { spawnSync } from "node:child_process";

function canRun(command: string): boolean {
  const result = spawnSync(command, ["-v"], { stdio: "ignore" });
  return !result.error && result.status === 0;
}

test("survival statistics runtime behavior", () => {
  const lua = ["lua", "luajit"].find(canRun);
  if (!lua) return;

  const result = spawnSync(lua, ["tools/survival-statistics.test.lua"], {
    cwd: new URL("..", import.meta.url),
    encoding: "utf8",
  });

  expect(result.status, result.stderr || result.stdout).toBe(0);
  expect(result.stdout).toContain("survival statistics runtime tests passed");
});
