import { expect, type Locator, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { Then, When } from "../support/world.ts";

const card = (page: Page, title: string) =>
  page
    .locator(".security-cred")
    .filter({ has: page.locator(".security-cred-name", { hasText: new RegExp(`^${RegExp.escape(title)}\\s`) }) })
    .or(page.locator(".card").filter({ has: page.getByText(title, { exact: true }) }));

const rows = (scope: Locator, ownDevice?: string) =>
  scope.locator(".li").filter({ hasNot: scope.page().locator(`form[action*="${ownDevice ?? "no-device"}"]`) });

const row = (page: Page, cardTitle: string, title: string) =>
  card(page, cardTitle)
    .locator(".li")
    .filter({ has: page.locator(".li-title", { hasText: title }) });

Then("the {string} card lists:", async ({ owner, page }, title: string, table: DataTable) => {
  const titles = rows(card(page, title), owner.device.id).locator(".li-title");
  await expect(titles).toHaveText(table.raw().map(([text]) => text));
});

Then("the {string} card lists nothing", async ({ owner, page }, title: string) => {
  await expect(rows(card(page, title), owner.device.id)).toHaveCount(0);
});

Then("the {string} card notes {string}", async ({ page }, title: string, note: string) => {
  await expect(card(page, title).locator(".card-note")).toHaveText(note);
});

Then("the {string} card says {string}", async ({ page }, title: string, text: string) => {
  await expect(card(page, title)).toContainText(text);
});

Then("the {string} row in {string} says {string}", async ({ page }, title: string, cardTitle: string, text: string) => {
  await expect(row(page, cardTitle, title).first()).toContainText(text);
});

Then(
  "the {string} row in {string} shows the {word} pill {string}",
  async ({ page }, title: string, cardTitle: string, color: string, pill: string) => {
    const found = row(page, cardTitle, title).first().locator(".pill", { hasText: pill });
    await expect(found).toHaveText(pill);
    if (color === "plain") await expect(found).not.toHaveClass(/green|pink/);
    else await expect(found).toHaveClass(new RegExp(`\\b${color}\\b`));
  },
);

Then(
  "the {string} row in {string} offers {string}",
  async ({ page }, title: string, cardTitle: string, button: string) => {
    await expect(row(page, cardTitle, title).first().getByRole("button", { name: button })).toBeVisible();
  },
);

Then("the {string} row in {string} offers nothing", async ({ page }, title: string, cardTitle: string) => {
  await expect(row(page, cardTitle, title).first().locator("form")).toHaveCount(0);
});

Then(
  "the {string} row in {string} shows {int} time(s)",
  async ({ page }, title: string, cardTitle: string, count: number) => {
    await expect(row(page, cardTitle, title).first().locator("time")).toHaveCount(count);
  },
);

Then("the page heading is {string}", async ({ page }, heading: string) => {
  await expect(page.locator(".page-head h1")).toHaveText(heading);
});

Then("the page says {string}", async ({ page }, text: string) => {
  await expect(page.locator("main").getByText(text, { exact: false }).first()).toBeVisible();
});

Then("the page does not say {string}", async ({ page }, text: string) => {
  await expect(page.locator("main").getByText(text, { exact: false })).toHaveCount(0);
});

Then("the page links {string} to {string}", async ({ page }, name: string, href: string) => {
  await expect(page.getByRole("link", { name }).first()).toHaveAttribute("href", href);
});

Then("the page has no link {string}", async ({ page }, name: string) => {
  await expect(page.getByRole("link", { name, exact: true })).toHaveCount(0);
});

Then("the page toasts {string}", async ({ page }, text: string) => {
  await expect(page.getByText(text).first()).toBeAttached();
});

Then("the palette offers {string}", async ({ page }, href: string) => {
  await expect(page.locator(`[data-palette-href="${href}"]`).first()).toBeAttached();
});

When(
  "I press {string} in the {string} row of {string}",
  async ({ page }, button: string, title: string, cardTitle: string) => {
    await row(page, cardTitle, title).first().getByRole("button", { name: button }).click();
  },
);

Then("I am asked {string}", async ({ page }, message: string) => {
  await expect(page.locator("[data-confirm-ask]")).toHaveAttribute("aria-label", message);
});

When("I confirm", async ({ page }) => {
  await page.locator("[data-confirm-ask] [data-confirm-accept]").click();
});

Then("the settings tabs link to:", async ({ page }, table: DataTable) => {
  const tabs = page.locator("nav[aria-label='Settings tabs'] a.screen-tab");
  await expect(tabs).toHaveCount(table.raw().length);
  for (const [index, [name, href]] of table.raw().entries()) {
    await expect(tabs.nth(index)).toContainText(name);
    await expect(tabs.nth(index)).toHaveAttribute("href", href);
  }
});

Then("the settings tab {string} is current", async ({ page }, name: string) => {
  await expect(page.locator("nav[aria-label='Settings tabs'] a[aria-current='page']")).toContainText(name);
});

const chicago = (time: Date) => {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      day: "2-digit",
      hour: "2-digit",
      hourCycle: "h23",
      minute: "2-digit",
      month: "2-digit",
      second: "2-digit",
      timeZone: "America/Chicago",
      timeZoneName: "longOffset",
      year: "numeric",
    })
      .formatToParts(time)
      .map(({ type, value }) => [type, value]),
  );
  const offset = parts.timeZoneName.replace("GMT", "");
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}${offset}`;
};

const stampsIn = async (page: Page, title: string, cardTitle: string) =>
  row(page, cardTitle, title)
    .first()
    .locator("time")
    .evaluateAll((times) => times.map((time) => time.getAttribute("datetime")));

Then(
  "the times in the {string} row of {string} begin with, in Chicago:",
  async ({ app, page }, title: string, cardTitle: string, query: string) => {
    const [found] = await app.sql.unsafe(query);
    const expected = Object.values(found).map((time) => chicago(time as Date));
    expect((await stampsIn(page, title, cardTitle)).slice(0, expected.length)).toEqual(expected);
  },
);

Then(
  "the times in the {string} row of {string} end with, in Chicago:",
  async ({ app, page }, title: string, cardTitle: string, query: string) => {
    const [found] = await app.sql.unsafe(query);
    const expected = Object.values(found).map((time) => chicago(time as Date));
    expect((await stampsIn(page, title, cardTitle)).slice(-expected.length)).toEqual(expected);
  },
);

Then("the {string} card does not say {string}", async ({ page }, title: string, text: string) => {
  await expect(card(page, title)).not.toContainText(text);
});

Then(
  "the {string} card shows {string} then the label {string}",
  async ({ page }, title: string, first: string, label: string) => {
    const texts = await card(page, title).locator(".li-title, .svc-group-label").allTextContents();
    expect(texts.indexOf(label)).toBeGreaterThan(texts.indexOf(first));
    expect(texts.indexOf(first)).toBeGreaterThanOrEqual(0);
  },
);

Then("the {string} card groups {string}", async ({ page }, title: string, summary: string) => {
  await expect(card(page, title).locator("summary", { hasText: summary })).toHaveCount(1);
});

Then(
  "the {string} group revokes clients {int} and {int}",
  async ({ page }, summary: string, first: number, second: number) => {
    const group = page.locator("details", { has: page.locator("summary", { hasText: summary }) });
    const actions = await group
      .locator("form[action$='/revoke']")
      .evaluateAll((forms) => forms.map((form) => form.getAttribute("action")));
    expect(actions.sort()).toEqual([`/admin/clients/${first}/revoke`, `/admin/clients/${second}/revoke`]);
  },
);

Then(
  "the {string} row in {string} links {string} to {string}",
  async ({ page }, title: string, cardTitle: string, name: string, href: string) => {
    await expect(row(page, cardTitle, title).first().getByRole("link", { name })).toHaveAttribute("href", href);
  },
);
