import { setTimeout as delay } from "node:timers/promises";

/** Wait for a browser value that requires async service worker APIs. */
export async function waitForBrowserValue(page, predicate, arg, description) {
  const deadline = Date.now() + 30_000;
  do {
    const result = await page.evaluate(predicate, arg);
    if (result) return result;
    await delay(50);
  } while (Date.now() < deadline);
  throw new Error(`Timed out waiting for ${description}`);
}
