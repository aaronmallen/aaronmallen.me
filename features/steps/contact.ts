import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { signedPass } from "../support/signed.ts";
import { Given, Then, When } from "../support/world.ts";
import { ask, sendHeader } from "./http.ts";
import { digestOf } from "./oauth.ts";
import { onServer } from "./servers.ts";

export const contactStamp = (secondsAgo = 60) =>
  signedPass("contact-form", new Date(Date.now() - secondsAgo * 1000), onServer());

const decoded = (value: string) =>
  value
    .replaceAll(/\\u([0-9a-fA-F]{4})/g, (_, hex: string) => String.fromCharCode(Number.parseInt(hex, 16)))
    .replaceAll("\\n", "\n")
    .replaceAll("\\t", "\t");

const contactBody = (table: DataTable, stamp: string | null = contactStamp()) =>
  new URLSearchParams([
    ...(stamp === null ? [] : [["message[stamp]", stamp]]),
    ...table.raw().map(([name, value]) => [`message[${name}]`, decoded(value)]),
  ]).toString();

When("I send the contact form with no declared length:", async ({ app, context }, table: DataTable) => {
  await ask({ app, context }, "POST", "/contact", {
    body: contactBody(table),
    headers: { "Content-Length": null, "Content-Type": "application/x-www-form-urlencoded" },
  });
});

When("I send the contact form:", async ({ app, context }, table: DataTable) => {
  await ask({ app, context }, "POST", "/contact", {
    body: contactBody(table),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
});

When(
  "I send the contact form with a stamp from {int} seconds ago:",
  async ({ app, context }, seconds: number, table: DataTable) => {
    await ask({ app, context }, "POST", "/contact", {
      body: contactBody(table, contactStamp(seconds)),
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
  },
);

Given("my requests carry {word} {word} API token", async ({ app }, _article: string, kind: string) => {
  const token = `features-${kind}-token`;
  if (kind !== "unknown") {
    await app.sql`
      INSERT INTO api_tokens ${app.sql({
        expires_at: kind === "expired" ? new Date(Date.now() - 1000) : null,
        name: kind,
        revoked_at: kind === "revoked" ? new Date() : null,
        token_digest: digestOf(token),
      })}
    `;
  }
  sendHeader("Authorization", `Bearer ${token}`);
});

When("I send the contact form with the stamp {string}:", async ({ app, context }, stamp: string, table: DataTable) => {
  const now = contactStamp();
  const stamps: Record<string, string | null> = {
    "a forged signature": `${now.split("--")[0]}--${"0".repeat(64)}`,
    "a moved time": now.replace(/^\d+/, (issued) => String(Number(issued) - 60_000)),
    "an empty one": "",
    none: null,
  };
  const value = stamp in stamps ? stamps[stamp] : stamp;
  await ask({ app, context }, "POST", "/contact", {
    body: contactBody(table, value),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
});

When("I send the contact form {int} times", async ({ app, context }, count: number) => {
  for (let index = 0; index < count; index++) {
    await ask({ app, context }, "POST", "/contact", {
      body: new URLSearchParams({
        "message[body]": "About the beacon",
        "message[reply_to]": "ada@example.com",
        "message[stamp]": contactStamp(),
        "message[subject]": "A question",
      }).toString(),
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
  }
});

When(
  /^I send the contact form (\d+) times? (from the addresses|with the browsers) "([^"]*)"$/,
  async ({ app, context }, count: string, how: string, pattern: string) => {
    for (let index = 0; index < Number(count); index++) {
      const name = how === "with the browsers" ? "User-Agent" : "CF-Connecting-IP";
      if (pattern === "unused") {
        await ask({ app, context }, "POST", "/contact", {
          body: new URLSearchParams({
            "message[body]": "About the beacon",
            "message[reply_to]": "ada@example.com",
            "message[stamp]": contactStamp(),
            "message[subject]": "A question",
          }).toString(),
          headers: { "Content-Type": "application/x-www-form-urlencoded", "X-Forwarded-For": `203.0.113.${index + 1}` },
        });
        continue;
      }
      await ask({ app, context }, "POST", "/contact", {
        body: new URLSearchParams({
          "message[body]": "About the beacon",
          "message[reply_to]": "ada@example.com",
          "message[stamp]": contactStamp(),
          "message[subject]": "A question",
        }).toString(),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          [name]: pattern.replace("N", String(index + 1)),
        },
      });
    }
  },
);

Then("the stamp on the form was signed just now", async ({ page }) => {
  const stamp = await page.locator("input[name='message[stamp]']").getAttribute("value");
  const [issued] = (stamp ?? "").split("--");
  expect(Math.abs(Date.now() - Number(issued))).toBeLessThan(10_000);
  expect(stamp).toBe(signedPass("contact-form", new Date(Number(issued)), onServer()));
});

When("I send a contact message of {int} characters", async ({ app, context }, length: number) => {
  await ask({ app, context }, "POST", "/contact", {
    body: new URLSearchParams({
      "message[body]": "a".repeat(length),
      "message[reply_to]": "ada@example.com",
      "message[stamp]": contactStamp(),
      "message[subject]": "A question",
    }).toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
});

let opened = 0;

When("I open the contact form", async ({ page }) => {
  await page.goto("/contact");
  opened = Date.now();
});

When("I fill in the contact form:", async ({ page }, table: DataTable) => {
  for (const [label, value] of table.raw()) await page.getByLabel(label, { exact: true }).fill(decoded(value));
});

When("I send the contact form after the minimum wait", async ({ page }) => {
  await page.waitForTimeout(Math.max(0, 3500 - (Date.now() - opened)));
  await page.getByRole("button", { name: "Send message" }).click();
});

When("I send the contact form at once", async ({ page }) => {
  await page.getByRole("button", { name: "Send message" }).click();
});
