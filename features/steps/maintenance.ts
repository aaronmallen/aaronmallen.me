import { statSync, symlinkSync } from "node:fs";
import { stat } from "node:fs/promises";
import { dirname, join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { expect } from "@playwright/test";
import { signedPass } from "../support/signed.ts";
import { Given, Then, When } from "../support/world.ts";
import { sendHeader } from "./http.ts";

const pass = async (flag: string, earlier: number) =>
  encodeURIComponent(signedPass("maintenance-owner", new Date(Math.floor((await stat(flag)).mtimeMs) - earlier)));

Given("my requests carry the owner's maintenance cookie", async ({ app }) => {
  sendHeader("Cookie", `maintenance.owner=${await pass(app.env.MAINTENANCE_FLAG_PATH ?? "", 0)}`);
});

Given("my requests carry an owner's maintenance cookie from before the flag went up", async ({ app }) => {
  sendHeader("Cookie", `maintenance.owner=${await pass(app.env.MAINTENANCE_FLAG_PATH ?? "", 1000)}`);
});

Given("my requests carry a forged maintenance cookie", () => {
  sendHeader("Cookie", `maintenance.owner=${Date.now()}--${"0".repeat(64)}`);
});

Then("the maintenance flag file is {word}", async ({ app }, state: string) => {
  const there = await stat(app.env.MAINTENANCE_FLAG_PATH ?? "").then(
    () => true,
    () => false,
  );
  expect(there).toBe(state === "there");
});

Then("the request leaves no timing row", async ({ app }) => {
  await sleep(500);
  const [{ count }] = await app.sql`SELECT count(*)::int AS count FROM performance_requests`;
  expect(count).toBe(0);
});

Given("my requests carry no maintenance cookie", () => {});

const cookieName = "maintenance.owner";

Given("the maintenance flag cannot be written", ({ app }) => {
  symlinkSync(
    join(dirname(app.env.MAINTENANCE_FLAG_PATH ?? ""), "no-such-folder", "flag"),
    app.env.MAINTENANCE_FLAG_PATH ?? "",
  );
});

Then(
  "the answer sets the maintenance cookie signed for the flag, kept from scripts and other sites",
  async ({ app, http }) => {
    const issued = Math.floor(statSync(app.env.MAINTENANCE_FLAG_PATH ?? "").mtimeMs);
    const cookie =
      (http.last?.headersArray() ?? [])
        .filter(({ name }) => name.toLowerCase() === "set-cookie")
        .map(({ value }) => value)
        .find((value) => value.startsWith(`${cookieName}=`)) ?? "";
    expect(decodeURIComponent(cookie.split(";")[0].split("=")[1])).toBe(
      signedPass("maintenance-owner", new Date(issued)),
    );
    expect(cookie).toMatch(/; httponly/i);
    expect(cookie).toMatch(/; samesite=strict/i);
    expect(cookie).toMatch(/; path=\/(;|$)/i);
  },
);

Then("my browser holds {word} maintenance cookie", async ({ context }, held: string) => {
  const cookie = (await context.cookies()).find(({ name }) => name === cookieName);
  expect(Boolean(cookie?.value)).toBe(held === "a");
});

When("I open the palette and run {string}", async ({ page }, query: string) => {
  await page.keyboard.press("Meta+/");
  await page.locator("[data-palette-query]").pressSequentially(query);
  await page.locator("[data-palette-query]").press("Enter");
});

When("I press {word} in the palette", async ({ page }, key: string) => {
  await page.locator("[data-palette-query]").press(key);
});

Then("the palette's maintenance row reads {string}", async ({ page }, label: string) => {
  await expect(page.locator("#command-palette-activate-maintenance .pal-r-label")).toHaveText(label);
});

Then("the palette is shut", async ({ page }) => {
  await expect(page.locator("dialog[data-palette][open]")).toHaveCount(0);
});

When("I press {string} and confirm", async ({ page }, button: string) => {
  await page.getByRole("button", { exact: true, name: button }).click();
  await page.locator("[data-confirm-ask] [data-confirm-accept]").click();
  await page.waitForLoadState();
});

When("I press {string} and decline", async ({ page }, button: string) => {
  await page.getByRole("button", { exact: true, name: button }).click();
  await page.locator("[data-confirm-ask] [data-confirm-decline]").click();
});

Then("pressing {string} asks {string}", async ({ page }, button: string, question: string) => {
  await page.getByRole("button", { exact: true, name: button }).click();
  await expect(page.locator("[data-confirm-ask]")).toHaveAttribute("aria-label", question);
});
