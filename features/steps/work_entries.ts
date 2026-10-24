import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { Given, Then, When } from "../support/world.ts";

Given("the work entries:", async ({ app }, table: DataTable) => {
  for (const [index, row] of table.hashes().entries()) {
    await app.sql`
      INSERT INTO work_entries ${app.sql({
        blurb: row.blurb || null,
        from_year: Number(row.from || 2018),
        org: row.org || "Rackspace",
        position: Number(row.position || index + 1),
        role: row.role,
        to_year: row.to ? Number(row.to) : null,
      })}
    `;
  }
});

When("I open the work tab", async ({ page }) => {
  await page.goto("/admin/projects?filter=work");
});

Then("the work rows read:", async ({ page }, table: DataTable) => {
  const rows = page.locator(".work-row");
  await expect(rows.locator(".work-row-title")).toHaveText(table.hashes().map((row) => row.role));
  await expect(rows.locator(".work-row-meta")).toHaveText(table.hashes().map((row) => row.meta));
});

Then("the work row {string} shows the blurb {string}", async ({ page }, role: string, blurb: string) => {
  const row = page.locator(".work-row").filter({ has: page.locator(".work-row-title", { hasText: role }) });
  await expect(row.locator(".work-row-blurb")).toHaveText(blurb);
});

Then("the work row {string} shows no blurb", async ({ page }, role: string) => {
  const row = page.locator(".work-row").filter({ has: page.locator(".work-row-title", { hasText: role }) });
  await expect(row.locator(".work-row-blurb")).toHaveCount(0);
});

Then("each work row offers Remove with the trash icon and no Archive", async ({ page }) => {
  const rows = page.locator(".work-row");
  const removes = page.getByRole("button", { name: "Remove" });
  await expect(removes).toHaveCount(await rows.count());
  await expect(removes.first().locator("i.fa-regular.fa-trash-can")).toHaveCount(1);
  await expect(page.getByRole("button", { name: "Archive" })).toHaveCount(0);
});

Then("removing the work row {string} asks {string}", async ({ page }, role: string, text: string) => {
  const row = page.locator(".work-row").filter({ has: page.locator(".work-row-title", { hasText: role }) });
  await expect(row.locator("form[data-confirm]")).toHaveAttribute("data-confirm", text);
});

Then("the work tab is chosen", async ({ page }) => {
  await expect(page.locator(".seg input[name='filter'][value='work']")).toBeChecked();
  await expect(page.locator(".card-title", { hasText: "Shown under Work on /projects" })).toHaveCount(1);
  await expect(page.locator("p.hint", { hasText: "Archiving keeps the repo link" })).toHaveCount(0);
});

Then("the work tab holds one work form, posting to {string}", async ({ page }, action: string) => {
  const form = page.locator("form[data-work-form]");
  await expect(form).toHaveCount(1);
  await expect(form).toHaveAttribute("action", action);
  for (const field of ["org", "role", "from_year", "to_year", "blurb"]) {
    await expect(form.locator(`[name='work_entry[${field}]']`)).toHaveCount(1);
  }
});

Then("the page draws no work log dialog", async ({ page }) => {
  await expect(page.locator("dialog#work-log, [data-work-dialog]")).toHaveCount(0);
});

Then("Add role is {word}", async ({ page }, state: string) => {
  const button = page.getByRole("button", { name: "Add role" });
  await (state === "disabled" ? expect(button).toBeDisabled() : expect(button).toBeEnabled());
});

When("I fill in the role {string} at {string}", async ({ page }, role: string, org: string) => {
  await page.locator("[name='work_entry[org]']").fill(org);
  await page.locator("[name='work_entry[role]']").fill(role);
});

When("I fill in the organization with {string}", async ({ page }, org: string) => {
  await page.locator("[name='work_entry[org]']").fill(org);
});

When("I fill in the start year with {string}", async ({ page }, year: string) => {
  await page.locator("[name='work_entry[from_year]']").fill(year);
});

When("I click Remove on the work row {string}", async ({ page }, role: string) => {
  const row = page.locator(".work-row").filter({ has: page.locator(".work-row-title", { hasText: role }) });
  await row.hover();
  await row.getByRole("button", { name: "Remove" }).click();
});

Then("the work entries are {string}", async ({ app }, roles: string) => {
  await expect
    .poll(async () =>
      (await app.sql`SELECT role FROM work_entries ORDER BY position`).map((row) => row.role).join(", "),
    )
    .toBe(roles);
});

Then("the about page lists the roles {string}", async ({ page }, roles: string) => {
  await page.goto("/about");
  await expect(page.locator(".hd h1")).toHaveCount(1);
  await expect(page.locator(".crs .cr h3")).toHaveText(roles ? roles.split(", ") : []);
});

Then("the about page dates the role {string} {string}", async ({ page }, role: string, years: string) => {
  await page.goto("/about");
  await expect(page.locator(".crs .cr", { hasText: role }).locator(".yr")).toHaveText(years);
});

Then("the refused page says {string} under {string}", async ({ answer, page }, text: string, label: string) => {
  await page.setContent(answer.body);
  const field = page.getByLabel(label, { exact: true });
  const id = await field.getAttribute("aria-describedby");
  await expect(page.locator(`[id='${id}'].field-error`)).toHaveText(text);
});

Then("the refused page says {string}", async ({ answer, page }, text: string) => {
  await page.setContent(answer.body);
  await expect(page.locator(".field-error", { hasText: text })).toHaveCount(1);
});

Then("the refused page keeps {string} in {string}", async ({ answer, page }, text: string, label: string) => {
  await page.setContent(answer.body);
  await expect(page.getByLabel(label, { exact: true })).toHaveValue(text);
});

Then("the refused page lists the roles {string}", async ({ answer, page }, roles: string) => {
  await page.setContent(answer.body);
  await expect(page.locator(".work-row-title")).toHaveText(roles.split(", "));
});

When("I add a role with:", async ({ http, page }, table: DataTable) => {
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const form: Record<string, string> = { _csrf_token: token };
  for (const [key, value] of Object.entries(table.rowsHash())) {
    form[key === "return_to" ? key : `work_entry[${key}]`] = value.startsWith('"') ? JSON.parse(value) : value;
  }
  http.last = await page.request.post("/admin/projects/work", { form, maxRedirects: 0 });
  http.body = await http.last.text();
});
