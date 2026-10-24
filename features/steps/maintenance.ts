import { stat } from "node:fs/promises";
import { setTimeout as sleep } from "node:timers/promises";
import { expect } from "@playwright/test";
import { signedPass } from "../support/signed.ts";
import { Given, Then } from "../support/world.ts";
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
