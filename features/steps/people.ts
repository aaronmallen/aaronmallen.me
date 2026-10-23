import { expect, type Page } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { settle } from "../support/mail_sync.ts";
import { connectSocial, googleConnection, insertPerson, personNamed } from "../support/people.ts";
import { seal } from "../support/seal.ts";
import { After, Given, Then, When } from "../support/world.ts";

const contactLock: { release?: () => Promise<void> } = {};

After(async () => {
  await contactLock.release?.();
  contactLock.release = undefined;
});

const minute = 60 * 1000;
const peopleApi = "/google/people/people/me/connections";

async function csrf(page: Page) {
  const html = await (await page.request.get("/admin/contacts/new")).text();
  return html.match(/name="_csrf_token" value="([^"]+)"/)?.[1] ?? "";
}

const rowFor = (page: Page, name: string) =>
  page.locator(".contact-row").filter({ has: page.locator(".contact-row-name", { hasText: name }) });

const names = (list: string) => list.split(", ");

// Rows

Given("a contact {string}", async ({ app }, name: string) => {
  await insertPerson(app.sql, { name });
});

Given("a contact {string} with:", async ({ app }, name: string, fields: string) => {
  await insertPerson(app.sql, { name, ...JSON.parse(fields) });
});

Given("a contact with:", async ({ app }, fields: string) => {
  await insertPerson(app.sql, JSON.parse(fields));
});

Given("the contact {string} gets:", async ({ app }, name: string, fields: string) => {
  const person = await personNamed(app.sql, name);
  const changes = JSON.parse(fields);
  for (const [key, value] of Object.entries(changes)) {
    if (Array.isArray(value) && key !== "labels") changes[key] = app.sql.json(value);
  }
  await app.sql`UPDATE people SET ${app.sql(changes)} WHERE id = ${person.id}`;
});

Given(
  "the contact {string} is linked to Google as {string} under {string}",
  async ({ app }, name: string, googleId: string, account: string) => {
    const person = await personNamed(app.sql, name);
    const connection = await googleConnection(app.sql, account);
    await app.sql`
      UPDATE people SET google_connection_id = ${connection.id}, google_id = ${googleId}, google_etag = 'e1'
      WHERE id = ${person.id}
    `;
  },
);

Given("the contacts sync last failed", async ({ app }) => {
  await app.sql`
    INSERT INTO sync_states ${app.sql({
      failing_since: new Date(),
      failure_count: 1,
      failure_message: "boom",
      failure_reason: "crashed",
      kind: "failure",
      sync: "contacts",
      synced_at: new Date(),
    })}
  `;
});

Given("the Google account {string} syncs contacts without taking new ones", async ({ app }, account: string) => {
  await app.sql`
    UPDATE service_connections SET sync_contacts = true WHERE provider = 'google' AND account_id = ${account}
  `;
});

Given("mail threads with contacts:", async ({ app }, table: DataTable) => {
  const [account] = await app.sql`
    INSERT INTO mail_accounts ${app.sql({ name: "me@example.com", provider: "gmail" })} RETURNING id
  `;
  for (const { from, minutes, subject } of table.hashes()) {
    const at = new Date(Date.now() - Number(minutes) * minute);
    const [thread] = await app.sql`
      INSERT INTO mail_threads ${app.sql({ mail_account_id: account.id, received_at: at, subject })} RETURNING id
    `;
    await app.sql`
      INSERT INTO mail_messages ${app.sql({ body: "Hello", mail_thread_id: thread.id, received_at: at, reply_to: from, subject })}
    `;
  }
});

Given("the admin can search people on {string}", async ({ app }, networks: string) => {
  for (const network of networks.split(" and ")) {
    await connectSocial(app.sql, network.toLowerCase() as "bluesky" | "mastodon");
  }
});

Given("Bluesky knows no account by the handle {string}", ({ stub }, _handle: string) => {
  stub.reply("GET", "/bluesky/public/xrpc/com.atproto.identity.resolveHandle", {
    body: JSON.stringify({ error: "InvalidRequest", message: "Unable to resolve handle" }),
    status: 400,
  });
});

Given("a GitHub service connection with no contacts", async ({ app }) => {
  await app.sql`
    INSERT INTO service_connections ${app.sql({
      account_id: "octocat",
      credentials: seal(JSON.stringify({ access_token: "gho_token" })),
      label: "octocat",
      provider: "github",
    })}
  `;
});

// The admin

When("I open the contact {string}", async ({ app, page }, name: string) => {
  await page.goto(`/admin/contacts/${(await personNamed(app.sql, name)).id}`);
});

When("I edit the contact {string}", async ({ app, page }, name: string) => {
  await page.goto(`/admin/contacts/${(await personNamed(app.sql, name)).id}/edit`);
});

When("I type {string} in the contacts search", async ({ page }, text: string) => {
  await page.getByLabel("Search contacts").fill(text);
  await page.getByLabel("Search contacts").press("Tab");
});

When("I open the contact {string} from the list", async ({ page }, name: string) => {
  await page.locator("a.contact-row-name", { hasText: name }).click();
});

const contactForm = (page: Page) => page.locator("form[data-contact-form], form[data-person-form]");

When("I fill in the contact field {string} with {string}", async ({ page }, label: string, value: string) => {
  await contactForm(page).getByLabel(label, { exact: true }).last().fill(value);
});

When("I post the contact form with:", async ({ answer, page }, fields: string) => {
  const form = new URLSearchParams({ _csrf_token: await csrf(page) });
  for (const [key, value] of Object.entries(JSON.parse(fields))) {
    if (Array.isArray(value)) {
      for (const row of value)
        for (const [part, text] of Object.entries(row)) form.append(`person[${key}][][${part}]`, String(text));
    } else form.append(`person[${key}]`, String(value));
  }
  const response = await page.request.post("/admin/contacts", {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  Object.assign(answer, { body: await response.text(), status: response.status() });
});

When("I add the contact row {string} as {string}", async ({ page }, list: string, value: string) => {
  const entries = page.locator(".contact-entries").filter({ has: page.locator("span.f", { hasText: list }) });
  await entries.locator("button.contact-add").click();
  await entries.getByLabel(list, { exact: true }).last().fill(value);
});

When("I add the contact address in {string}", async ({ page }, city: string) => {
  const entries = page.locator(".contact-entries").filter({ has: page.locator("span.f", { hasText: "Addresses" }) });
  await entries.locator("button.contact-add").click();
  await entries.getByLabel("City", { exact: true }).last().fill(city);
});

When("I add the custom contact field {string} as {string}", async ({ page }, key: string, value: string) => {
  const entries = page
    .locator(".contact-entries")
    .filter({ has: page.locator("span.f", { hasText: "Custom fields" }) });
  await entries.locator("button.contact-add").click();
  await entries.getByLabel("label", { exact: true }).last().fill(key);
  await entries.getByLabel("value", { exact: true }).last().fill(value);
});

When("I remove the contact row {string}", async ({ page }, label: string) => {
  await page.getByRole("button", { exact: true, name: label }).first().click();
});

When("I pick the contact label {string}", async ({ page }, label: string) => {
  await page.locator("label.contact-pick", { hasText: label }).click();
});

When("I add the new contact label {string}", async ({ page }, label: string) => {
  await page.getByLabel("New label", { exact: true }).fill(label);
  await page.locator(".contact-new-label").getByRole("button", { exact: true, name: "Add" }).click();
});

When("I star the contact in the form", async ({ page }) => {
  await page.getByLabel("Show in Google’s favorites").check();
});

When("I click the contact button {string}", async ({ page }, name: string) => {
  await page.getByRole("button", { exact: true, name }).first().click();
});

When("I submit the contact form with {string}", async ({ answer, page }, name: string) => {
  const posted = page.waitForResponse((response) => response.request().method() === "POST");
  await page.getByRole("button", { exact: true, name }).first().click();
  Object.assign(answer, { body: "", status: (await posted).status() });
  await page.waitForLoadState();
});

When("I confirm the contact delete", async ({ page }) => {
  await page.locator("[data-confirm-accept]").click();
});

When("I decline the contact delete", async ({ page }) => {
  await page.locator("[data-confirm-decline]").click();
});

When("I fetch the contact search {string}", async ({ answer, page }, path: string) => {
  const response = await page.request.get(path);
  Object.assign(answer, { body: await response.text(), status: response.status() });
});

When("I post contact options for the GitHub connection", async ({ answer, app, page }) => {
  const [connection] = await app.sql`SELECT id FROM service_connections WHERE provider = 'github'`;
  const response = await page.request.post(`/admin/services/${connection.id}/contacts`, {
    form: { _csrf_token: await csrf(page), sync_contacts: "1" },
    maxRedirects: 0,
  });
  Object.assign(answer, { body: await response.text(), status: response.status() });
});

When("I add a person through the social composer with:", async ({ answer, page }, fields: string) => {
  const form: Record<string, string> = { _csrf_token: await csrf(page), reply: "mention" };
  for (const [key, value] of Object.entries({
    bluesky_handle: "",
    key: "",
    mastodon_handle: "",
    name: "",
    ...JSON.parse(fields),
  })) {
    form[`person[${key}]`] = String(value);
  }
  const response = await page.request.post("/admin/contacts", { form, maxRedirects: 0 });
  Object.assign(answer, {
    body: await response.text(),
    cookie: response.headers()["set-cookie"] ?? "",
    status: response.status(),
  });
});

When("I open the Google account {string} in the services settings", async ({ app, page }, account: string) => {
  await page.goto(`/admin/settings/services?selected=${(await googleConnection(app.sql, account)).id}`);
});

When("I flip the contact switch {string}", async ({ page }, name: string) => {
  const navigated = page.waitForURL(/selected=/, { waitUntil: "load" });
  await page.getByRole("switch", { exact: true, name }).click();
  await navigated;
});

When("I search people on {string} for {string}", async ({ page }, network: string, query: string) => {
  const finder = page.locator("#person-finder");
  await finder.locator(`.seg-option.${network.toLowerCase()}`).click();
  await finder.getByRole("searchbox").fill(query);
  await finder.getByRole("button", { exact: true, name: "Search" }).click();
});

When("I search people on {string} for {string} with Enter", async ({ page }, network: string, query: string) => {
  const finder = page.locator("#person-finder");
  await finder.locator(`.seg-option.${network.toLowerCase()}`).click();
  await finder.getByRole("searchbox").fill(query);
  await finder.getByRole("searchbox").press("Enter");
});

When("I pick the people search network {string}", async ({ page }, network: string) => {
  await page.locator(`#person-finder .seg-option.${network.toLowerCase()}`).click();
});

When("I add the found account {string}", async ({ page }, name: string) => {
  await page.locator(".person-result", { hasText: name }).getByRole("link").click();
});

Given("another contacts sync holds the lock", async ({ app }) => {
  const held = await app.sql.reserve();
  await held`SELECT pg_advisory_lock(hashtext('contacts sync'))`;
  contactLock.release = async () => {
    await held`SELECT pg_advisory_unlock(hashtext('contacts sync'))`;
    held.release();
  };
});

When("the contacts sync job runs beside it", async ({ app }) => {
  await app.pushJob("Contacts::Jobs::SyncContacts");
  await settle(app);
});

Then("the contacts sync still records the failure {string}", async ({ app }, message: string) => {
  const [row] = await app.sql`SELECT failure_reason, failure_message FROM sync_states WHERE sync = 'contacts'`;
  expect(row && `${row.failure_reason}: ${row.failure_message}`).toBe(message);
});

When("the contacts sync job runs", async ({ app }) => {
  await app.pushJob("Contacts::Jobs::SyncContacts");
});

Then("the contacts list names {string}", async ({ page }, list: string) => {
  await expect(page.locator(".contact-row-name")).toHaveText(names(list));
});

Then("the contact row {string} shows {string}", async ({ page }, name: string, text: string) => {
  await expect(rowFor(page, name)).toContainText(text);
});

Then("the contact row {string} is starred", async ({ page }, name: string) => {
  await expect(rowFor(page, name).getByLabel("Starred", { exact: true })).toHaveCount(1);
});

Then("the contact row {string} links to {string}", async ({ page }, name: string, href: string) => {
  await expect(rowFor(page, name).locator(`a[href="${href}"]`)).toHaveCount(1);
});

Then("the contact row {string} edits from its pencil", async ({ app, page }, name: string) => {
  const { id } = await personNamed(app.sql, name);
  await expect(rowFor(page, name).locator(`a[href="/admin/contacts/${id}/edit"]`)).toHaveAccessibleName(`Edit ${name}`);
});

Then("the contact row {string} offers a menu", async ({ app, page }, name: string) => {
  const { id } = await personNamed(app.sql, name);
  await expect(rowFor(page, name)).toHaveAttribute("data-menu", `/admin/contacts/${id}/menu`);
});

Then("the contacts tab counts {int}", async ({ page }, count: number) => {
  const tab = page.locator("a.screen-tab[aria-current='page']");
  await expect(tab).toContainText("contacts");
  await expect(tab.locator(".screen-tab-note")).toHaveText(String(count));
});

Then("the admin tabs end with webmentions then contacts", async ({ page }) => {
  const hrefs = await page
    .locator("nav.screen-tabs-list a.screen-tab")
    .evaluateAll((tabs) => tabs.map((tab) => tab.getAttribute("href")));
  expect(hrefs.slice(-2)).toEqual(["/admin/webmentions", "/admin/contacts"]);
});

Then("the command palette offers the contacts", async ({ page }) => {
  await expect(page.locator("#command-palette-contacts[data-palette-href='/admin/contacts']")).toHaveCount(1);
});

Then("the browser is on the contacts list", async ({ page }) => {
  await expect(page).toHaveURL(/\/admin\/contacts$/);
});

Then("the browser is on the new contact form", async ({ page }) => {
  await expect(page).toHaveURL(/\/admin\/contacts\/new$/);
});

Then("the browser is on the page of the contact {string}", async ({ app, page }, name: string) => {
  await expect.poll(async () => (await personNamed(app.sql, name).catch(() => ({ id: 0 }))).id).not.toBe(0);
  await expect(page).toHaveURL(new RegExp(`/admin/contacts/${(await personNamed(app.sql, name)).id}$`));
});

Then("the contacts show {string} links to {string}", async ({ page }, show: string, href: string) => {
  await expect(page.locator("nav.seg a.seg-option", { hasText: show })).toHaveAttribute("href", href);
});

Then("the contacts show {string} is marked", async ({ page }, show: string) => {
  await expect(page.locator("nav.seg a[aria-current='page']")).toHaveText(show);
});

Then("the contacts label {string} links to {string}", async ({ page }, label: string, href: string) => {
  await expect(page.locator(".contacts-labels a", { hasText: label })).toHaveAttribute("href", href);
});

Then("the contacts label {string} is marked", async ({ page }, label: string) => {
  await expect(page.locator(".contacts-labels a[aria-current='page']")).toHaveText(label);
});

Then("the contacts search keeps {string} as {string}", async ({ page }, name: string, value: string) => {
  await expect(page.locator(`form.contacts-search input[type=hidden][name="${name}"]`)).toHaveValue(value);
});

Then("the contact header reads {string}", async ({ page }, text: string) => {
  await expect(page.locator("header.contact-head")).toContainText(text);
});

Then("the contact page links {string} to {string}", async ({ page }, name: string, href: string) => {
  const link = page.getByRole("link", { exact: true, name }).first();
  await expect.poll(async () => decodeURIComponent((await link.getAttribute("href")) ?? "")).toBe(href);
});

Then("the contact page shows {string} without a link", async ({ page }, text: string) => {
  await expect(page.locator(".contact-card").getByText(text, { exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: text })).toHaveCount(0);
});

Then("the contact page gives the age for the birthday {string}", async ({ page }, birthday: string) => {
  const [year, month, day] = birthday.split("-").map(Number);
  const now = new Date();
  const before = now.getMonth() + 1 < month || (now.getMonth() + 1 === month && now.getDate() < day);
  await expect(page.locator(".contact-card")).toContainText(`${now.getFullYear() - year - (before ? 1 : 0)} years`);
});

Then("the contact card reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".contact-card")).toContainText(text);
});

Then("the contact page offers the button {string}", async ({ page }, name: string) => {
  await expect(page.getByRole("button", { exact: true, name })).toBeVisible();
});

Then("the contact page has no sections", async ({ page }) => {
  await expect(page.locator(".contact-card .contact-sec")).toHaveCount(0);
});

Then("the contact page lists the threads {string}", async ({ page }, list: string) => {
  await expect(page.locator(".contact-mail-subject")).toHaveText(names(list));
});

Then("the contact thread {string} opens the mail thread", async ({ app, page }, subject: string) => {
  const [thread] = await app.sql`SELECT id FROM mail_threads WHERE subject = ${subject}`;
  await expect(page.locator("a.contact-mail", { hasText: subject })).toHaveAttribute(
    "href",
    `/admin/mail?thread=${thread.id}`,
  );
});

Then("the contact thread {string} is marked unread", async ({ page }, subject: string) => {
  await expect(page.locator("a.contact-mail", { hasText: subject }).locator(".contact-mail-meta")).toContainText(
    "unread",
  );
});

Then("the Google card reads {string}", async ({ page }, text: string) => {
  await expect(page.locator(".contact-google")).toContainText(text);
});

Then("the contact {string} is starred", async ({ app }, name: string) => {
  await expect.poll(async () => (await personNamed(app.sql, name)).starred).toBe(true);
});

Then("the contact {string} is not starred", async ({ app }, name: string) => {
  await expect.poll(async () => (await personNamed(app.sql, name)).starred).toBe(false);
});

Then("the contact {string} holds:", async ({ app }, name: string, fields: string) => {
  const expected = JSON.parse(fields);
  await expect
    .poll(async () => {
      const person = await personNamed(app.sql, name).catch(() => ({}));
      return Object.fromEntries(Object.keys(expected).map((key) => [key, person[key as keyof typeof person] ?? null]));
    })
    .toEqual(expected);
});

Then("the contacts are {string}", async ({ app }, list: string) => {
  await expect
    .poll(async () =>
      (await app.sql`SELECT coalesce(name, company) AS name FROM people ORDER BY 1`).map((row) => row.name),
    )
    .toEqual(names(list).sort());
});

Then("there are no contacts", async ({ app }) => {
  await expect.poll(async () => (await app.sql`SELECT count(*)::int AS count FROM people`)[0].count).toBe(0);
});

Then("{int} contacts are named {string}", async ({ app }, count: number, name: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT count(*)::int AS count FROM people WHERE name = ${name}`)[0].count)
    .toBe(count);
});

Then("the contact field {string} holds {string}", async ({ page }, label: string, value: string) => {
  await expect(contactForm(page).getByLabel(label, { exact: true }).first()).toHaveValue(value);
});

Then("the contact label {string} is picked", async ({ page }, label: string) => {
  await expect(page.locator("label.contact-pick", { hasText: label }).locator("input")).toBeChecked();
});

Then("the contact label {string} is not picked", async ({ page }, label: string) => {
  await expect(page.locator("label.contact-pick", { hasText: label }).locator("input")).not.toBeChecked();
});

Then("the contact labels offered are {string}", async ({ page }, list: string) => {
  await expect(page.locator("label.contact-pick")).toHaveText(names(list));
});

Then("the contact form hides {string} until asked", async ({ page }, label: string) => {
  await expect(page.getByLabel(label, { exact: true })).toBeHidden();
});

Then("the contact editor answers with status {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the contact delete asks {string}", async ({ page }, message: string) => {
  await expect(page.locator("[data-confirm-ask] [data-confirm-message]")).toHaveText(message);
});

Then("the contact form has no search box", async ({ page }) => {
  await expect(page.locator("input[type=search]")).toHaveCount(0);
});

Then("the contacts address {string} answers {int}", async ({ page }, path: string, status: number) => {
  expect((await page.goto(path))?.status()).toBe(status);
});

Then("the contacts address {string} sends me to {string}", async ({ page }, path: string, to: string) => {
  const response = await page.request.get(path, { maxRedirects: 0 });
  expect([response.status(), response.headers().location]).toEqual([302, to]);
});

Then("the contact switch {string} is off", async ({ page }, name: string) => {
  await expect(page.getByRole("switch", { exact: true, name })).not.toBeChecked();
});

Then("the contact switch {string} waits on the first", async ({ page }, name: string) => {
  await expect(page.getByRole("switch", { exact: true, name })).toBeDisabled();
});

Then(
  "the Google account {string} syncs contacts {word} and saves new ones {word}",
  async ({ app }, account: string, syncs: string, saves: string) => {
    await expect
      .poll(async () => {
        const { saves_contacts, sync_contacts } = await googleConnection(app.sql, account);
        return [sync_contacts, saves_contacts];
      })
      .toEqual([syncs === "yes", saves === "yes"]);
  },
);

Then("the contact options answer {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

// The people finder

Then("the people finder shows {string}", async ({ page }, text: string) => {
  await expect(page.locator("#person-finder")).toContainText(text);
});

Then("the people finder box reads {string}", async ({ page }, label: string) => {
  await expect(page.locator("#person-finder").getByRole("searchbox")).toHaveAccessibleName(label);
});

Then("the people finder offers {string}", async ({ page }, network: string) => {
  await expect(page.locator(`#person-finder .seg-option.${network.toLowerCase()}`)).toHaveCount(1);
});

Then("the people finder does not offer {string}", async ({ page }, network: string) => {
  await expect(page.locator(`#person-finder .seg-option.${network.toLowerCase()}`)).toHaveCount(0);
});

Then("the contacts page has no people finder", async ({ page }) => {
  await expect(page.locator("[data-person-finder]")).toHaveCount(0);
  await expect(page.locator(".g-main")).toHaveCount(0);
});

Then("the contact search answers with status {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the contact search answer holds {string}", ({ answer }, text: string) => {
  expect(answer.body).toContain(text);
});

Then("the contact search answer does not hold {string}", ({ answer }, text: string) => {
  expect(answer.body).not.toContain(text);
});

Then("the contact search offers to add {string}", ({ answer }, href: string) => {
  const link = answer.body.match(/<a[^>]*data-person-add[^>]*>/)?.[0] ?? "";
  const raw = link.match(/href="([^"]*)"/)?.[1] ?? "";
  expect(decodeURIComponent(raw.replaceAll("&amp;", "&").replaceAll("+", " "))).toBe(href);
});

// The social composer

Then(
  "the composer answer offers {string} to mention as {string} on {string}",
  ({ answer }, name: string, key: string, network: string) => {
    expect(answer.body).toMatch(
      new RegExp(
        `role="option"[^>]*data-social-mention="${key}"[^>]*data-social-mention-in="${network}"[^>]*>[^<]*${name}|data-social-mention="${key}"[^>]*>.*${name}`,
        "s",
      ),
    );
  },
);

Then("the composer answer lists the handles:", ({ answer }, handles: string) => {
  const raw = answer.body.match(/data-social-people="([^"]*)"/)?.[1] ?? "{}";
  expect(JSON.parse(raw.replaceAll("&quot;", '"').replaceAll("&amp;", "&"))).toEqual(JSON.parse(handles));
});

Then("the composer answer holds {string}", ({ answer }, text: string) => {
  expect(answer.body).toContain(text);
});

Then("the composer answer has no layout and no toast", ({ answer }) => {
  expect(answer.body).not.toContain("<html");
  expect((answer as unknown as { cookie: string }).cookie).not.toContain("Person added");
});

Then("the composer form fills the key {string}", async ({ page }, key: string) => {
  await expect(page.locator("input[name='person[key]']")).toHaveValue(key);
});

// Google and the sync

Then(
  "the contact {string} is now linked to Google as {string} under {string}",
  async ({ app }, name: string, googleId: string, account: string) => {
    const connection = await googleConnection(app.sql, account);
    await expect
      .poll(async () => {
        const person = await personNamed(app.sql, name).catch(() => ({}) as Record<string, unknown>);
        return [person.google_connection_id, person.google_id];
      })
      .toEqual([connection.id, googleId]);
  },
);

Then("the contact keyed {string} is linked to Google as {string}", async ({ app }, key: string, googleId: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT google_id FROM people WHERE key = ${key}`)[0]?.google_id)
    .toBe(googleId);
});

Then("the contact keyed {string} is not linked to Google", async ({ app }, key: string) => {
  const [person] = await app.sql`SELECT google_id, google_connection_id FROM people WHERE key = ${key}`;
  expect([person.google_id, person.google_connection_id]).toEqual([null, null]);
});

Then("the contact keyed {string} holds:", async ({ app }, key: string, fields: string) => {
  const expected = JSON.parse(fields);
  const [person] = await app.sql`SELECT * FROM people WHERE key = ${key}`;
  expect(Object.fromEntries(Object.keys(expected).map((name) => [name, person[name]]))).toEqual(expected);
});

Then("the contacts sync token for {string} is {string}", async ({ app }, account: string, token: string) => {
  const connection = await googleConnection(app.sql, account);
  await expect
    .poll(
      async () =>
        (await app.sql`SELECT sync_token FROM contact_syncs WHERE google_connection_id = ${connection.id}`)[0]
          ?.sync_token,
    )
    .toBe(token);
});

Then("the contacts sync keeps no token", async ({ app }) => {
  expect(await app.sql`SELECT * FROM contact_syncs`).toEqual([]);
});

Then("each Google account holds a copy of {string}", async ({ app }, name: string) => {
  await expect
    .poll(async () => {
      const rows = await app.sql`
        SELECT c.account_id FROM people p JOIN service_connections c ON c.id = p.google_connection_id
        WHERE p.name = ${name} ORDER BY 1
      `;
      return rows.map((row) => row.account_id);
    })
    .toEqual(
      (await app.sql`SELECT account_id FROM service_connections WHERE provider = 'google' ORDER BY 1`).map(
        (row) => row.account_id,
      ),
    );
});

Then("the contacts sync records no failure", async ({ app }) => {
  expect(await app.sql`SELECT * FROM sync_states WHERE sync = 'contacts' AND kind = 'failure'`).toEqual([]);
});

Then("the contacts sync failure clears", async ({ app }) => {
  await expect
    .poll(async () => (await app.sql`SELECT * FROM sync_states WHERE sync = 'contacts'`).length, { timeout: 15_000 })
    .toBe(0);
});

Then("the contacts sync records the failure {string}", async ({ app }, message: string) => {
  await expect
    .poll(async () => {
      const [row] = await app.sql`SELECT failure_reason, failure_message FROM sync_states WHERE sync = 'contacts'`;
      return row && `${row.failure_reason}: ${row.failure_message}`;
    })
    .toBe(message);
});

Then("Google was asked for the contacts {int} times", ({ stub }, count: number) => {
  expect(stub.received("GET", peopleApi)).toHaveLength(count);
});

Then("Google was not asked for contacts", ({ stub }) => {
  expect([...stub.received("GET", peopleApi), ...stub.received("GET", "/google/people/contactGroups")]).toEqual([]);
});

// The API

When(
  "I call the people API with {word} {string} for {string}",
  async ({ answer, app, request, tokens }, method: string, path: string, name: string) => {
    const { id } = await personNamed(app.sql, name);
    const response = await request.fetch(`/api/v1${path.replace(":id", String(id))}`, {
      headers: { Authorization: `Bearer ${tokens.api}` },
      method,
    });
    Object.assign(answer, { body: await response.text(), status: response.status() });
  },
);

When(
  "I call the people API with {word} {string} for {string} and:",
  async ({ answer, app, request, tokens }, method: string, path: string, name: string, body: string) => {
    const { id } = await personNamed(app.sql, name);
    const response = await request.fetch(`/api/v1${path.replace(":id", String(id))}`, {
      data: JSON.parse(body),
      headers: { Authorization: `Bearer ${tokens.api}` },
      method,
    });
    Object.assign(answer, { body: await response.text(), status: response.status() });
  },
);

Then("the API lists the people {string}", ({ answer }, list: string) => {
  expect(JSON.parse(answer.body).people.map((person: { name: string }) => person.name)).toEqual(
    list === "" ? [] : names(list),
  );
});

Then("the API person {string} holds:", ({ answer }, name: string, fields: string) => {
  const body = JSON.parse(answer.body);
  const person = (body.people ?? [body]).find((found: { name: string }) => found.name === name);
  expect(person).toMatchObject(JSON.parse(fields));
});

Then("each API person holds only the open fields", ({ answer }) => {
  const body = JSON.parse(answer.body);
  for (const person of body.people ?? [body]) {
    expect(Object.keys(person)).toEqual(["id", "key", "name", "mastodon_handle", "bluesky_handle"]);
  }
});

Then("the API answer is exactly:", ({ answer }, body: string) => {
  expect(JSON.parse(answer.body)).toEqual(JSON.parse(body));
});

Then("the API answer gives the contact {string} as deleted", async ({ answer }, _name: string) => {
  const body = JSON.parse(answer.body);
  expect([typeof body.id, body.deleted]).toEqual(["number", true]);
});

Then("the OpenAPI document lists {string} for the people search", ({ answer }, status: string) => {
  expect(Object.keys(JSON.parse(answer.body).paths["/people/search/{network}"].get.responses)).toContain(status);
});

// MCP

async function mcp(page: Page, token: string | undefined, method: string, params: unknown) {
  const response = await page.request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method, params },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  return response.text();
}

Then("the MCP tools for people leave out {string}", async ({ page, tokens }, list: string) => {
  const body = await mcp(page, tokens.mcp, "tools/list", {});
  for (const name of names(list)) expect(body).not.toContain(`"name":"${name}"`);
});

Then("the MCP tools for people offer {string}", async ({ page, tokens }, list: string) => {
  const body = await mcp(page, tokens.mcp, "tools/list", {});
  for (const name of names(list)) expect(body).toContain(`"name":"${name}"`);
});

Then("the MCP people answer is an error", ({ answer }) => {
  expect(answer.body).toContain('"isError":true');
});

When(
  "I call the MCP tool {string} for the contact {string} with:",
  async ({ answer, app, page, tokens }, name: string, person: string, args: string) => {
    const { id } = await personNamed(app.sql, person);
    const body = await mcp(page, tokens.mcp, "tools/call", { arguments: { id, ...JSON.parse(args) }, name });
    Object.assign(answer, { body, status: 200 });
  },
);
