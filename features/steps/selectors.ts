import { expect } from "@playwright/test";
import { fill } from "../support/api.ts";
import { Then } from "../support/world.ts";

Then("the texts of {string} are none", async ({ http, page }, selector: string) => {
  await expect(page.locator(fill(http, selector))).toHaveCount(0);
});

Then("the text of {string} is {string}", async ({ http, page }, selector: string, text: string) => {
  await expect(page.locator(fill(http, selector)).first()).toHaveText(fill(http, text));
});

Then("the text of {string} holds {string}", async ({ http, page }, selector: string, text: string) => {
  await expect(page.locator(fill(http, selector)).first()).toContainText(fill(http, text));
});

Then("the text of {string} does not hold {string}", async ({ http, page }, selector: string, text: string) => {
  await expect(page.locator(fill(http, selector)).first()).not.toContainText(fill(http, text));
});

Then("the text of {string} matches {string}", async ({ http, page }, selector: string, pattern: string) => {
  await expect(page.locator(fill(http, selector)).first()).toHaveText(new RegExp(fill(http, pattern)));
});

Then("{string} has the {string} {string}", async ({ http, page }, selector: string, name: string, value: string) => {
  await expect(page.locator(fill(http, selector)).first()).toHaveAttribute(name, fill(http, value));
});

Then("the page counts {int} of {string}", async ({ http, page }, count: number, selector: string) => {
  await expect(page.locator(fill(http, selector))).toHaveCount(count);
});
