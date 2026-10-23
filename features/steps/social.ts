import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { accountIds, connect, expand, insertSocialPost, split, statuses, submitForm } from "../support/social.ts";
import { Given, Then, When } from "../support/world.ts";

Given("my Mastodon account {string} on {string} is connected", async ({ app }, handle: string, host: string) => {
  await connect(app.sql, "mastodon", { host, label: `@${handle}@${host}` });
});

Given("my Bluesky account {string} is connected", async ({ app }, handle: string) => {
  await connect(app.sql, "bluesky", { label: `@${handle}` });
});

Given("my LinkedIn account {string} is connected", async ({ app }, name: string) => {
  await connect(app.sql, "linkedin", { label: name });
});

Given("Mastodon and Bluesky are connected", async ({ app }) => {
  await connect(app.sql, "mastodon", { host: "ruby.social", label: "@aaronmallen@ruby.social" });
  await connect(app.sql, "bluesky", { label: "@ada.example" });
});

Given("the social posts:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) await insertSocialPost(app.sql, row, app.url);
});

Given("{int} social posts {word} {string} apart", async ({ app }, count: number, status: string, gap: string) => {
  const step = gap === "an hour" ? 3_600_000 : 86_400_000;
  for (let index = 1; index <= count; index += 1) {
    const at = status === "scheduled" ? Date.now() + index * step : Date.now() - index * step;
    await insertSocialPost(app.sql, {
      at: status === "draft" ? "" : new Date(at).toISOString(),
      created: new Date(Date.now() - (count - index + 1) * step).toISOString(),
      status,
      text: `${status} ${index}`,
    });
  }
});

Given("the social composer remembers the accounts {string}", async ({ app, page }, names: string) => {
  const ids = names === "none still connected" ? ["0"] : await accountIds(app.sql, names);
  await page.goto("/admin/social");
  await page.evaluate((value) => localStorage.setItem("social:accounts", value), JSON.stringify(ids));
  await page.goto("/admin/social");
});

Given("the social composer remembers nothing", async ({ page }) => {
  await page.goto("/admin/social");
  await page.evaluate(() => localStorage.clear());
  await page.goto("/admin/social");
});

When("I send the social composer:", async ({ app, page }, table: DataTable) => {
  const form = table.rowsHash();
  if (!page.url().includes("/admin")) await page.goto("/admin/social");
  const accounts = "accounts" in form ? await accountIds(app.sql, form.accounts) : await accountIds(app.sql, "1");
  const fields: [string, string][] = [["social[accounts][]", ""]];
  for (const id of accounts) fields.push(["social[accounts][]", id]);
  if ("parts" in form) for (const part of split(form.parts)) fields.push(["social[parts][]", expand(part, app.url)]);
  for (const name of ["mode", "schedule_at"]) if (name in form) fields.push([`social[${name}]`, form[name]]);
  if ("photos" in form) {
    fields.push(["social[photos][]", ""]);
    for (const [, part, photo, alt] of form.photos.matchAll(/part (\d+) photo (\d+)(?: '([^']*)')?/g)) {
      const [{ key }] = await app.sql`SELECT key FROM photos WHERE id = ${Number(photo)}`;
      fields.push(
        ["social[photos][][part]", part],
        ["social[photos][][key]", key],
        ["social[photos][][alt]", alt ?? ""],
      );
    }
  }
  fields.push(["intent", form.intent ?? "send"]);
  await submitForm(page, form.to ?? "/admin/social", fields);
});

When("I remove social post {int} from the {word} queue", async ({ page }, id: number, filter: string) => {
  if (!page.url().includes("/admin")) await page.goto("/admin/social");
  await submitForm(page, `/admin/social/${id}/delete`, [["filter", filter]]);
});

When("I open social post {int} in the composer", async ({ page }, id: number) => {
  const response = await page.goto(`/admin/social?edit=${id}`);
  statuses.set(page, response?.status() ?? 0);
});

When("I open the social page at {string}", async ({ page }, query: string) => {
  const response = await page.goto(`/admin/social${query}`);
  statuses.set(page, response?.status() ?? 0);
});

When("I write {string} in social part {int}", async ({ app, page }, text: string, index: number) => {
  await page
    .locator("[data-social-body]")
    .nth(index - 1)
    .fill(expand(text, app.url));
});

When("I type {string} in social part {int}", async ({ page }, text: string, index: number) => {
  const body = page.locator("[data-social-body]").nth(index - 1);
  await body.click();
  await body.pressSequentially(text);
});

When("I press {word} in the social composer", async ({ page }, key: string) => {
  await page.keyboard.press(key);
});

When("I add a part to the social thread", async ({ page }) => {
  await page.getByRole("button", { name: "Add to thread" }).click();
});

When("I remove the last social part", async ({ page }) => {
  await page.locator("[data-social-remove]").last().click();
});

When("I open the social accounts menu", async ({ page }) => {
  await page.locator(".compose-accounts summary").click();
});

When("I toggle the {word} social account", async ({ page }, network: string) => {
  if (!(await page.locator(".compose-accounts[open]").count())) await page.locator(".compose-accounts summary").click();
  await page.locator(`.compose-account-group.${network.toLowerCase()} .compose-account`).first().click();
});

When("I remove the social chip {string}", async ({ page }, account: string) => {
  await page.getByRole("button", { name: `Remove ${account}` }).click();
});

When("I choose {string} on the social page", async ({ page }, option: string) => {
  await page.locator(".seg-option", { hasText: option }).click();
});

When("I press {string} in the {word} social account group", async ({ page }, name: string, network: string) => {
  await page.locator(`.compose-account-group.${network}`).getByRole("button", { name }).click();
});

Then("the social page answered {int}", ({ page }, status: number) => {
  expect(statuses.get(page)).toBe(status);
});

Then("the social composer counts {string}", async ({ page }, counts: string) => {
  await expect(page.locator("[data-social-count-text]")).toHaveText(counts.split(", "));
});

Then("the social composer holds {string}", async ({ app, page }, parts: string) => {
  await expect
    .poll(() =>
      page.locator("[data-social-body]").evaluateAll((all) => all.map((one) => (one as HTMLTextAreaElement).value)),
    )
    .toEqual(parts === "" ? [""] : split(parts).map((part) => expand(part, app.url)));
});

Then("the social composer says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".field-error", { hasText: text }).first()).toBeVisible();
});

Then("the social toast says {string}", async ({ page }, text: string) => {
  await expect(page.locator("[data-toast]", { hasText: text }).first()).toBeAttached();
});

Then("the {word} social counter is {word}", async ({ page }, network: string, state: string) => {
  const counter = page.locator(".compose-count", { hasText: network });
  if (state === "over") await expect(counter.and(page.locator(".over")).first()).toBeVisible();
  if (state === "under") await expect(page.locator(".compose-count.over", { hasText: network })).toHaveCount(0);
  if (state === "off") await expect(counter.and(page.locator(".off")).first()).toBeVisible();
});

Then("{int} {word} social counters are over", async ({ page }, count: number, network: string) => {
  await expect(page.locator(".compose-count.over", { hasText: network })).toHaveCount(count);
});

Then("the {word} social meter is {int}% full", async ({ page }, network: string, percent: number) => {
  const meter = page.locator(".compose-count", { hasText: network }).first().locator("[data-social-meter]");
  await expect(meter).toHaveAttribute("style", new RegExp(`width: ${percent}%`));
});

Then("the social {word} button is {word}", async ({ page }, button: string, state: string) => {
  const locator = page.locator(`[data-social-${button}]`).first();
  if (state === "disabled") await expect(locator).toBeDisabled();
  else await expect(locator).toBeEnabled();
});

Then("the social accounts toggle reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".compose-accounts summary")).toContainText(text);
});

Then("the social account chips read {string}", async ({ page }, chips: string) => {
  await expect(page.locator(".compose-chip:not([hidden]) .compose-chip-handle")).toHaveText(
    chips === "" ? [] : chips.split(", "),
  );
});

Then("the picked social accounts are {string}", async ({ app, page }, names: string) => {
  const ids = await accountIds(app.sql, names);
  await expect
    .poll(() => page.locator("[data-social-target]:checked").evaluateAll((all) => all.map((one) => one.value)))
    .toEqual(ids);
});

Then("the social queue shows {string}", async ({ page }, parts: string) => {
  await expect(page.locator(".sq-part")).toHaveText(split(parts).map((part) => part.replaceAll("\\n", "\n")));
});

Then("the social page shows {string} in {string}", async ({ page }, text: string, selector: string) => {
  await expect(page.locator(selector, { hasText: text }).first()).toBeAttached();
});

Then("the social page has {int} {string}", async ({ page }, count: number, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(count);
});

Then("the social page has no {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector)).toHaveCount(0);
});

Then("the social page has a visible {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).first()).toBeVisible();
});

Then("the social page has no visible {string}", async ({ page }, selector: string) => {
  await expect(page.locator(selector).filter({ visible: true })).toHaveCount(0);
});

Then("the social page lists {string} as {string}", async ({ page }, selector: string, texts: string) => {
  const found = await page.locator(selector).evaluateAll((all) => all.map((one) => (one.textContent ?? "").trim()));
  expect(found.join(" // ")).toBe(texts);
});

Then(
  "the {string} on the social page has {string} set to {string}",
  async ({ page }, selector: string, name: string, value: string) => {
    await expect(page.locator(selector).first()).toHaveAttribute(name, value);
  },
);

Then("social post {int} has the parts {string}", async ({ app }, id: number, parts: string) => {
  const site = app.url;
  await expect
    .poll(async () =>
      (await app.sql`SELECT body FROM social_post_parts WHERE social_post_id = ${id} ORDER BY position`).map(
        (row) => row.body,
      ),
    )
    .toEqual(split(parts).map((part) => expand(part, site)));
});

Then("social post {int} is {word}", async ({ app }, id: number, status: string) => {
  const [row] = await app.sql`SELECT status, posted_at FROM social_posts WHERE id = ${id}`;
  if (status === "gone") expect(row).toBeUndefined();
  else expect(row?.status).toBe(status);
});

Then("social post {int} goes out within a minute", async ({ app }, id: number) => {
  const [row] = await app.sql`SELECT posted_at FROM social_posts WHERE id = ${id}`;
  expect(Math.abs(row.posted_at.getTime() - Date.now())).toBeLessThan(60_000);
});

Then("social post {int} goes out at {string} in Chicago", async ({ app }, id: number, local: string) => {
  const [row] = await app.sql`
    SELECT to_char(posted_at AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD"T"HH24:MI') AS local FROM social_posts WHERE id = ${id}
  `;
  expect(row.local).toBe(local);
});

Then("social post {int} goes to {string}", async ({ app }, id: number, targets: string) => {
  const [row] = await app.sql`SELECT targets::text[] AS targets, connection_ids FROM social_posts WHERE id = ${id}`;
  expect(row.targets.join(",")).toBe(targets);
});

Then("social post {int} picked the accounts {string}", async ({ app }, id: number, names: string) => {
  const [row] = await app.sql`SELECT connection_ids FROM social_posts WHERE id = ${id}`;
  expect(row.connection_ids.map(String)).toEqual(await accountIds(app.sql, names));
});

Then("there are {int} social posts", async ({ app }, count: number) => {
  const [row] = await app.sql`SELECT count(*)::int AS count FROM social_posts`;
  expect(row.count).toBe(count);
});

Then("the social photos held are {string}", async ({ app }, photos: string) => {
  const rows = await app.sql`
    SELECT p.id, s.alt_text, part.position AS part
    FROM social_post_photos s
    JOIN photos p ON p.key = s.photo_key
    JOIN social_post_parts part ON part.id = s.social_post_part_id
    ORDER BY part.position, s.position
  `;
  expect(
    rows.map((row) => `part ${row.part} photo ${row.id}${row.alt_text ? ` '${row.alt_text}'` : ""}`).join(", "),
  ).toBe(photos);
});

Then("the social page source holds {string}", async ({ page }, text: string) => {
  expect(await page.content()).toContain(text);
});

Then("the social part template has no autofocus", async ({ page }) => {
  const html = await page.locator("template[data-social-part-template]").evaluate((one) => one.innerHTML);
  expect(html).not.toContain("autofocus");
});

Then("every social counter tags the site's host", async ({ app, page }) => {
  const hosts = await page
    .locator("[data-social-count]")
    .evaluateAll((all) => all.map((one) => one.dataset.taggedHost));
  expect(hosts.length).toBeGreaterThan(0);
  expect(new Set(hosts)).toEqual(new Set([new URL(app.url).hostname]));
});

Then("the social mention options read {string}", async ({ page }, texts: string) => {
  const found = await page
    .locator("[data-social-mentions] [role='option']")
    .evaluateAll((all) => all.map((one) => (one.textContent ?? "").trim().replaceAll(/\s+/g, " ")));
  expect(found.map((one) => one.split(" @")[0]).join(" // ")).toBe(texts);
});

const handles = async (page: import("@playwright/test").Page) =>
  JSON.parse((await page.locator("[data-social-people]").getAttribute("data-social-people")) ?? "{}");

Then(
  "the social handles give {string} on {word} as {string}",
  async ({ page }, key: string, network: string, handle: string) => {
    expect((await handles(page))[network][key]).toBe(handle);
  },
);

Then("the social handles hold no blank key", async ({ page }) => {
  for (const people of Object.values(await handles(page)) as Record<string, string>[]) {
    expect(Object.keys(people)).not.toContain("");
    expect(Object.keys(people)).not.toContain("null");
  }
});

Then("the social account targets are {string}", async ({ page }, ids: string) => {
  const values = await page.locator("[data-social-target]").evaluateAll((all) => all.map((one) => one.value));
  expect(values.join(",")).toBe(ids);
});

Then("the social account rows read {string}", async ({ page }, rows: string) => {
  const found = await page
    .locator(".compose-account")
    .evaluateAll((all) =>
      all.map((row) => [...row.querySelectorAll("span")].map((span) => (span.textContent ?? "").trim()).join(" ")),
    );
  expect(found.join(" // ")).toBe(rows);
});

Then("the social account groups read {string}", async ({ page }, labels: string) => {
  const found = await page
    .locator("details.compose-accounts [role=group][aria-label]")
    .evaluateAll((all) => all.map((one) => one.getAttribute("aria-label")));
  expect(found.join(", ")).toBe(labels);
});

When("I click outside the social accounts menu", async ({ page }) => {
  await page.locator("main").click({ position: { x: 5, y: 5 } });
});

When(
  "I post social post {int} now with scripts off, leaving only account {int} ticked",
  async ({ app, browser, context }, id: number, kept: number) => {
    const offline = await browser.newContext({ baseURL: app.url, bypassCSP: true, javaScriptEnabled: false });
    await offline.addCookies(await context.cookies());
    const page = await offline.newPage();
    await page.goto(`/admin/social?edit=${id}`);
    await page.locator(".compose-accounts summary").click();
    for (const box of await page.locator(".compose-accounts input[type=checkbox]").all()) {
      if ((await box.getAttribute("value")) !== String(kept)) await box.uncheck();
      else await box.check();
    }
    await page.getByRole("button", { name: "Post now" }).click();
    await page.waitForLoadState();
    await offline.close();
  },
);

Then(
  "the first {string} on the social page is at least {int} pixels tall",
  async ({ page }, selector: string, height: number) => {
    const box = await page.locator(selector).first().boundingBox();
    expect(box?.height).toBeGreaterThanOrEqual(height);
  },
);

Given("person {string} was taken out of the directory", async ({ app, page }, key: string) => {
  const [person] = await app.sql`SELECT id FROM people WHERE key = ${key}`;
  if (!page.url().includes("/admin")) await page.goto("/admin/social");
  await submitForm(page, `/admin/contacts/${person.id}/delete`, []);
});

Then("the first social queue item reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".sq-item .sq-part").first()).toHaveText(text);
});

const visibleTexts = (page: import("@playwright/test").Page, selector: string) =>
  page
    .locator(selector)
    .filter({ visible: true })
    .evaluateAll((all) => all.map((one) => (one.textContent ?? "").trim()));

Then("the social mention list is shut", async ({ page }) => {
  await expect(page.locator("[data-social-mentions]")).toBeHidden();
});

Then("the social mention names read {string}", async ({ page }, names: string) => {
  await expect.poll(() => visibleTexts(page, "[data-social-mention] .compose-mention-name")).toEqual(names.split(", "));
});

Then("the social mention groups read {string}", async ({ page }, groups: string) => {
  await expect
    .poll(async () => (await visibleTexts(page, ".compose-mention-group")).map((one) => one.toLowerCase()))
    .toEqual(groups.split(", "));
});

Then("the social mention choices read {string}", async ({ page }, choices: string) => {
  await expect.poll(() => visibleTexts(page, "#social-mentions [role='option']")).toEqual(choices.split(", "));
});

Then("the last social mention choice is {string}", async ({ page }, choice: string) => {
  await expect.poll(async () => (await visibleTexts(page, "#social-mentions [role='option']")).at(-1)).toBe(choice);
});

Then("the chosen social mention is {string}", async ({ page }, name: string) => {
  await expect(page.locator("#social-mentions [aria-selected='true']")).toContainText(name);
});

When("I click the social page heading", async ({ page }) => {
  await page.locator("h1").first().click();
});

When("I pick {string} from the social mention list", async ({ page }, name: string) => {
  await page.locator(".compose-mention", { hasText: name }).click();
});

Then("social part {int} reads {string}", async ({ page }, index: number, text: string) => {
  await expect(page.locator("[data-social-body]").nth(index - 1)).toHaveValue(text.replaceAll("\\n", "\n"));
});

Then("social part {int} has no {string}", async ({ page }, index: number, name: string) => {
  await expect(page.locator("[data-social-body]").nth(index - 1)).not.toHaveAttribute(name);
});

Then("the focus is in a social part", async ({ page }) => {
  await expect(page.locator("[data-social-body]:focus")).toHaveCount(1);
});

Then("the social page does not scroll sideways", async ({ page }) => {
  expect(await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth)).toBe(
    false,
  );
});

Then("the social mention list fits the screen", async ({ page }) => {
  const box = await page.locator("[data-social-mentions]").boundingBox();
  const width = page.viewportSize()?.width ?? 0;
  expect(box?.x).toBeGreaterThanOrEqual(0);
  expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(width);
});

When("I press Enter on the social Add New row", async ({ page }) => {
  await page.keyboard.press("Enter");
});

When("I press Tab on the social Add New row", async ({ page }) => {
  await page.keyboard.press("Tab");
});

When("I click the social Add New row", async ({ page }) => {
  await page.locator("[data-social-mention-add]").click();
});

const personDialog = (page: import("@playwright/test").Page) => page.locator("dialog#person-dialog[open]");

Then("the person dialog is open", async ({ page }) => {
  await expect(personDialog(page).locator("form[data-person-form='new']")).toBeVisible();
});

Then("the person dialog is shut", async ({ page }) => {
  await expect(personDialog(page)).toHaveCount(0);
});

Then("the person dialog's {string} reads {string}", async ({ page }, field: string, value: string) => {
  await expect(personDialog(page).locator(`[name='person[${field}]']`)).toHaveValue(value);
});

When("I fill in the person dialog's {string} with {string}", async ({ page }, field: string, value: string) => {
  await personDialog(page).locator(`[name='person[${field}]']`).fill(value);
});

When("I press {string} in the person dialog", async ({ page }, name: string) => {
  await personDialog(page).getByRole("button", { name }).click();
});

Then("the person dialog shows {string}", async ({ page }, selector: string) => {
  await expect(personDialog(page).locator(selector)).toBeAttached();
});

When("I cancel the person dialog", async ({ page }) => {
  await personDialog(page).locator("[data-dialog-close]").first().click();
});

When("I press Escape in the person dialog", async ({ page }) => {
  await personDialog(page).locator("[name='person[name]']").press("Escape");
});

Given("the new person form fails with {int}", async ({ page }, status: number) => {
  await page.route("**/admin/contacts/new*", (route) => route.fulfill({ body: "", status }));
});

Given("the browser cannot reach the server from the social page", async ({ page }) => {
  await page.evaluate(() => {
    window.fetch = () => Promise.reject(new TypeError("offline"));
  });
});

const photoNames = async (sql: import("postgres").Sql, keys: string[]) => {
  const rows = await sql`SELECT id, key FROM photos`;
  const ids = Object.fromEntries(rows.map((row) => [row.key, row.id]));
  return keys.map((key) => ids[key.split("/").at(-1) ?? ""]);
};

Then("the photo claims read {string}", async ({ app }, claims: string) => {
  const rows = await app.sql`
    SELECT c.photo_id, part.position FROM photo_claims c
    JOIN social_post_parts part ON part.id = c.owner_id
    WHERE c.owner = 'social_post_part'
  `;
  const found = rows.map((row) => `part ${row.position} photo ${row.photo_id}`).sort();
  expect(found).toEqual(claims.split(", ").sort());
});

Then("the social photo alt texts read {string}", async ({ page }, alts: string) => {
  const found = await page
    .locator("[data-social-part] [data-social-photo-alt]")
    .evaluateAll((all) => all.map((one) => (one as HTMLTextAreaElement).value));
  expect(found.join(", ")).toBe(alts);
});

Then("the social composer photos read {string}", async ({ app, page }, photos: string) => {
  const found: string[] = [];
  const parts = await page.locator("[data-social-part]").all();
  for (const [index, part] of parts.entries()) {
    const keys = await part
      .locator("[data-social-photo-key]")
      .evaluateAll((all) => all.map((one) => (one as HTMLInputElement).value));
    for (const id of await photoNames(app.sql, keys)) found.push(`part ${index + 1} photo ${id}`);
  }
  expect(found.join(", ")).toBe(photos);
});

Then("the social preview photos read {string}", async ({ page }, alts: string) => {
  const found = await page
    .locator(".compose-preview-photo")
    .evaluateAll((all) => all.map((one) => one.getAttribute("alt")));
  expect(found.join(", ")).toBe(alts);
});

Then("the social queue photos read {string}", async ({ app, page }, photos: string) => {
  const shown = await page
    .locator(".sq-photo")
    .evaluateAll((all) => all.map((one) => [one.getAttribute("src") ?? "", one.getAttribute("alt") ?? ""]));
  const ids = await photoNames(
    app.sql,
    shown.map(([src]) => src),
  );
  expect(shown.map(([, alt], index) => `photo ${ids[index]} '${alt}'`).join(", ")).toBe(photos);
});

When("I send the social composer with a photo key no photo carries", async ({ page }) => {
  if (!page.url().includes("/admin")) await page.goto("/admin/social");
  await submitForm(page, "/admin/social", [
    ["social[accounts][]", "1"],
    ["social[parts][]", "one"],
    ["social[photos][][part]", "1"],
    ["social[photos][][key]", `${"f".repeat(32)}.png`],
    ["social[photos][][alt]", ""],
    ["intent", "draft"],
  ]);
});

Then(
  "the database refuses photo {int} at position {int} on part {int}",
  async ({ app }, photo: number, position: number, part: number) => {
    const [{ key }] = await app.sql`SELECT key FROM photos WHERE id = ${photo}`;
    await expect(
      app.sql`INSERT INTO social_post_photos ${app.sql({ photo_key: key, position, social_post_part_id: part })}`,
    ).rejects.toThrow(/social_post_photos_position_check/);
  },
);

const trusted = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(trusted);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, one]) => [key, trusted(one)]));
  }
  return value;
};

// biome-ignore lint/suspicious/noExplicitAny: answers are free-form JSON
const answered = (answer: { body: string }): any => {
  const json = JSON.parse(answer.body);
  return json?.jsonrpc ? trusted(JSON.parse(json.result.content[0].text)) : json;
};

Then("the social answer lists the ids {string}", ({ answer }, ids: string) => {
  expect(
    answered(answer)
      .social_posts.map((one: { id: number }) => one.id)
      .join(","),
  ).toBe(ids);
});

Then("the social answer's deliveries go to {string}", ({ answer }, deliveries: string) => {
  const found = answered(answer).deliveries.map(
    (one: { network: string; account: string; state: string }) => `${one.network} ${one.account} ${one.state}`,
  );
  expect(found.join(", ")).toBe(deliveries);
});

Then("the social answer's delivery states read {string}", ({ answer }, states: string) => {
  const found = answered(answer).deliveries.map((one: { network: string; state: string; error: string | null }) =>
    [one.network, one.state, one.error].filter(Boolean).join(" "),
  );
  expect(found.join(", ")).toBe(states);
});

Then("the social answer has the stamps {string}", ({ answer }, stamps: string) => {
  for (const stamp of stamps.split(", ")) expect(answered(answer)[stamp]).toMatch(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/);
});

Then("the social answer has {int} suggested edit(s)", ({ answer }, count: number) => {
  expect(answered(answer).suggestion_edits).toHaveLength(count);
});

const earlier = new WeakMap<object, unknown>();

async function callTool(
  request: import("@playwright/test").APIRequestContext,
  token: string | undefined,
  name: string,
  args: unknown,
) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: args, name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  const body = await response.text();
  const result = response.ok() ? JSON.parse(body).result : undefined;
  const mcp = {
    body,
    content: result?.content?.[0]?.text ?? body,
    error: result?.isError ?? false,
    status: response.status(),
  };
  return mcp;
}

When(
  "I call the social MCP tool {string} with:",
  async ({ answer, app, request, tokens }, name: string, args: string) => {
    Object.assign(answer, await callTool(request, tokens.mcp, name, JSON.parse(expand(args, app.url))));
    earlier.set(answer, answered(answer));
  },
);

Then("the last two social answers match but for {string}", ({ answer }, fields: string) => {
  const drop = (value: Record<string, unknown>) =>
    Object.fromEntries(Object.entries(value).filter(([key]) => !fields.split(", ").includes(key)));
  expect(drop(answered(answer))).toEqual(drop(earlier.get(answer) as Record<string, unknown>));
});

async function viaApi(
  request: import("@playwright/test").APIRequestContext,
  token: string | undefined,
  method: string,
  path: string,
) {
  const response = await request.fetch(path, {
    data: method === "GET" ? undefined : {},
    headers: { Accept: "application/json", Authorization: `Bearer ${token}` },
    method,
  });
  return response.json();
}

const toolResult = async (
  request: import("@playwright/test").APIRequestContext,
  token: string | undefined,
  name: string,
  args: unknown,
) => JSON.parse((await callTool(request, token, name, args)).body).result;

Then(
  "the MCP tool {string} with id {int} answers as GET {string} does",
  async ({ request, tokens }, name: string, id: number, path: string) => {
    const result = await toolResult(request, tokens.mcp, name, { id });
    expect(trusted(JSON.parse(result.content[0].text))).toEqual(await viaApi(request, tokens.api, "GET", path));
  },
);

Then(
  "the MCP tool {string} with queue {string} answers as GET {string} does",
  async ({ request, tokens }, name: string, queue: string, path: string) => {
    const result = await toolResult(request, tokens.mcp, name, { queue });
    expect(trusted(JSON.parse(result.content[0].text))).toEqual(await viaApi(request, tokens.api, "GET", path));
  },
);

Then(
  "the MCP tool {string} with id {int} refuses as {word} {string} does",
  async ({ request, tokens }, name: string, id: number, method: string, path: string) => {
    const result = await toolResult(request, tokens.mcp, name, { id });
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toBe((await viaApi(request, tokens.api, method, path)).message);
  },
);

Given("my Bluesky account is no longer connected", async ({ app }) => {
  await app.sql`DELETE FROM service_connections WHERE provider = 'bluesky'`;
});

Then(
  "each social hit reads through read_social_post as {string}",
  async ({ answer, request, tokens }, statuses: string) => {
    const hits = answered(answer).results.filter((hit: { kind: string }) => hit.kind === "social");
    const found: string[] = [];
    for (const hit of hits) {
      const result = await toolResult(request, tokens.mcp, "read_social_post", { id: hit.id });
      found.push(JSON.parse(result.content[0].text).status);
    }
    expect(found.sort()).toEqual(statuses.split(", ").sort());
  },
);

When("I accept the suggestions on social post {int} from the admin", async ({ page }, id: number) => {
  if (!page.url().includes("/admin")) await page.goto("/admin/social");
  await submitForm(page, `/admin/social/${id}/suggestions/accept`, []);
});

const png = () => readFileSync(resolve(import.meta.dirname, "../../spec/fixtures/photos/small.png")).toString("base64");

async function handOver(page: import("@playwright/test").Page, how: string, index: number) {
  const before = await page.locator("[data-social-photo]").count();
  if (how === "pick") {
    await page
      .locator("[data-social-part]")
      .nth(index - 1)
      .locator("[data-social-photo-file]")
      .setInputFiles(resolve(import.meta.dirname, "../../spec/fixtures/photos/small.png"));
  } else {
    await page.evaluate(
      ([event, at, data]) => {
        const transfer = new DataTransfer();
        const bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
        transfer.items.add(new File([bytes], "small.png", { type: "image/png" }));
        const init = { bubbles: true, cancelable: true };
        const handed =
          event === "drop"
            ? new DragEvent("drop", { ...init, dataTransfer: transfer })
            : new ClipboardEvent("paste", { ...init, clipboardData: transfer });
        document.querySelectorAll("[data-social-body]")[Number(at)].dispatchEvent(handed);
      },
      [how, String(index - 1), png()],
    );
  }
  return before;
}

When("I {word} a photo onto social part {int}", async ({ page }, how: string, index: number) => {
  await handOver(page, how, index);
});

When("I drop {int} photos onto social part {int}", async ({ page }, count: number, index: number) => {
  for (let one = 0; one < count; one += 1) {
    const before = await handOver(page, "drop", index);
    await expect(page.locator("[data-social-photo]:not([data-social-photo-pending])")).toHaveCount(before + 1);
  }
});

Then("social part {int} holds {int} uploaded photo(s)", async ({ page }, index: number, count: number) => {
  await expect(
    page
      .locator("[data-social-part]")
      .nth(index - 1)
      .locator("[data-social-photo]:not([data-social-photo-pending])"),
  ).toHaveCount(count);
});

const photoKeys = (page: import("@playwright/test").Page) =>
  page
    .locator("[data-social-part] [data-social-photo-key]")
    .evaluateAll((all) => all.map((one) => (one as HTMLInputElement).value));

Then("every social photo key looks like a stored key", async ({ page }) => {
  for (const key of await photoKeys(page)) expect(key).toMatch(/^[0-9a-f]{32}\.png$/);
});

const firstKey = new WeakMap<object, string>();

When("I move the first social photo later", async ({ page }) => {
  firstKey.set(page, (await photoKeys(page))[0]);
  await page.locator("[data-social-photo] button[aria-label='Move later']").first().click();
});

Then("the first social photo key is now last", async ({ page }) => {
  expect((await photoKeys(page)).at(-1)).toBe(firstKey.get(page));
});

When("I remove the first social photo", async ({ page }) => {
  await page.locator("[data-social-photo] button[aria-label='Remove photo']").first().click();
});

When("I give the first social photo the alt text {string}", async ({ page }, alt: string) => {
  await page.locator("[data-social-photo-alt]").first().fill(alt);
});

Then("the social photo alt texts held are {string}", async ({ app }, alts: string) => {
  await expect
    .poll(async () =>
      (await app.sql`SELECT alt_text FROM social_post_photos ORDER BY position`)
        .map((row) => row.alt_text ?? "")
        .join(", "),
    )
    .toBe(alts);
});
