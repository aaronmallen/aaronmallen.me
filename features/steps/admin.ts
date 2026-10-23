import { expect } from "@playwright/test";
import { ownerEmail } from "../support/stub.ts";
import { Given, Then, When } from "../support/world.ts";

Given("I am signed in to the admin", async ({ app, context, owner }) => {
  await app.sql`INSERT INTO owner_identities ${app.sql({ email: ownerEmail })} ON CONFLICT DO NOTHING`;
  await app.sql`INSERT INTO devices ${app.sql(owner.device)} ON CONFLICT DO NOTHING`;
  await context.addCookies(owner.cookies);
});

When("I visit the admin", async ({ page }) => {
  await page.goto("/admin");
});

Then("I see the admin signed in", async ({ page }) => {
  await expect(page).toHaveURL(/\/admin\/?$/);
  await expect(page.getByRole("navigation", { name: "Admin" })).toBeVisible();
});

Then("I am sent to sign in", async ({ page }) => {
  await expect(page).toHaveURL(/\/admin\/sign-in$/);
});
