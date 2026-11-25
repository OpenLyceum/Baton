import { writeFile } from "node:fs/promises";
import { expect, test } from "@playwright/test";

const SCREEN_BUTTON = /^(?!.*full ?screen).+ screen$/i;
const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"];

test("axe checks the default state of each simulation screen", async ({ page }, testInfo) => {
  const moduleUrl = process.env["AXE_PLAYWRIGHT_MODULE"];
  if (!moduleUrl) throw new Error("Run this spec with scripts/test-axe.sh");
  const { default: AxeBuilder } = await import(moduleUrl);
  const pageErrors: string[] = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));

  await page.goto("/?ea&homeScreen=false&initialScreen=1");
  const reset = page.getByRole("button", { name: /^(reset all|reset simulation|reset)$/i }).first();
  await expect(reset).toBeVisible({ timeout: 30_000 });
  const screenButtons = page.getByRole("navigation").getByRole("button", { name: SCREEN_BUTTON });
  const screenCount = Math.max(1, await screenButtons.count());
  const findings: string[] = [];

  for (let screen = 1; screen <= screenCount; screen++) {
    await test.step(`Scan screen ${screen}`, async () => {
      if (screen > 1) await page.goto(`/?ea&homeScreen=false&initialScreen=${screen}`);
      await expect(reset).toBeVisible({ timeout: 30_000 });
      await reset.press("Space");
      const result = await new AxeBuilder({ page }).withTags(TAGS).analyze();
      const filename = `axe-screen-${screen}.json`;
      const path = testInfo.outputPath(filename);
      await writeFile(path, JSON.stringify(result, null, 2));
      await testInfo.attach(filename, { path, contentType: "application/json" });
      for (const { id, nodes } of result.violations) {
        findings.push(`Screen ${screen}: ${id} (${nodes.length} affected nodes)`);
      }
    });
  }

  console.log(findings.length > 0 ? findings.join("\n") : `No axe violations across ${screenCount} screens`);
  expect(pageErrors, "Simulation errors during the axe scan").toEqual([]);
  if (process.env["AXE_STRICT"] === "1") {
    expect(findings, "axe violations").toEqual([]);
  }
});
