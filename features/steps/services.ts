import { expect } from "@playwright/test";
import { defineParameterType } from "playwright-bdd";
import { services } from "../support/stub.ts";
import { Given, Then, When } from "../support/world.ts";

defineParameterType({
  name: "service",
  regexp: new RegExp(
    Object.keys(services)
      .sort((one, other) => other.length - one.length)
      .join("|"),
  ),
  transformer: (name: string) => services[name],
});

Given(
  "{service} answers {word} {string} with:",
  ({ stub }, prefix: string, method: string, path: string, body: string) => {
    stub.reply(method, `${prefix}${path}`, { body, status: 200 });
  },
);

Given(
  "{service} answers {word} {string} with status {int}",
  ({ stub }, prefix: string, method: string, path: string, status: number) => {
    stub.reply(method, `${prefix}${path}`, { body: "", status });
  },
);

When("I connect Mastodon on {string}", async ({ page }, server: string) => {
  await page.goto("/admin/settings/services");
  await page.getByRole("button", { name: "Connect a service" }).click();
  await page.getByRole("button", { name: /Mastodon/ }).click();
  const dialog = page.getByRole("dialog", { name: "Connect Mastodon" });
  await dialog.getByLabel("Your server").fill(server);
  await dialog.getByRole("button", { name: "Continue to Mastodon" }).click();
});

When("the browser asks for {string}", async ({ page }, url: string) => {
  await page.goto(url).catch(() => {});
});

Then("I see {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text)).toBeVisible();
});
