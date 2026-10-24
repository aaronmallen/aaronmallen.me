import { expect, type Page } from "@playwright/test";
import type postgres from "postgres";
import {
  insertMailAccount,
  insertMailLabel,
  insertMailMessage,
  insertMailThread,
  labelMailThread,
  mailAccountId,
  mailThreadId,
  tagMailThread,
} from "../support/mail.ts";
import { Given, Then, When } from "../support/world.ts";

type Row = Record<string, string>;
type Answer = { body: string; location: string; status: number };

const minute = 60 * 1000;
const answers = new WeakMap<Page, Answer>();

const yes = (value?: string) => value === "yes";
const ago = (minutes?: string) => new Date(Date.now() - Number(minutes ?? 0) * minute);
const listed = (text: string) => (text === "" ? [] : text.split(", "));

export function localPick(hours: number) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
    minute: "2-digit",
    month: "2-digit",
    timeZone: "America/Chicago",
    year: "numeric",
  }).formatToParts(new Date(Date.now() + hours * 60 * minute));
  const part = (type: string) => parts.find((found) => found.type === type)?.value;
  return `${part("year")}-${part("month")}-${part("day")}T${part("hour")}:${part("minute")}`;
}

async function fill(sql: postgres.Sql, text: string) {
  const tomorrow = new Date(`${localPick(0).slice(0, 10)}T12:00:00Z`);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  const day = new Intl.DateTimeFormat("en-US", { day: "numeric", month: "short", timeZone: "UTC", year: "numeric" });
  let filled = text
    .replaceAll("%[a day from now]", localPick(24))
    .replaceAll("%[tomorrow at 08:00]", `${tomorrow.toISOString().slice(0, 10)}T08:00`)
    .replaceAll("%[tomorrow as a date]", day.format(tomorrow))
    .replaceAll("%[201 letters]", "a".repeat(201));
  for (const [match, subject] of text.matchAll(/#\[([^\]]+)\]/g)) {
    filled = filled.replace(match, String(await mailThreadId(sql, subject)));
  }
  for (const [match, name] of text.matchAll(/@\[([^\]]+)\]/g)) {
    filled = filled.replace(match, String(await mailAccountId(sql, name)));
  }
  return filled;
}

function message(row: Row) {
  return {
    body: row.body || undefined,
    draft: yes(row.draft),
    fromName: row.from || undefined,
    gmailId: row["message gmail id"] || undefined,
    htmlBody: row.html || undefined,
    receivedAt: row["minutes ago"] ? ago(row["minutes ago"]) : undefined,
    replyTo: row["reply to"] === "none" ? null : row["reply to"] || undefined,
  };
}

async function csrf(page: Page) {
  const html = await (await page.request.get("/admin/mail/settings")).text();
  return html.match(/name="_csrf_token" value="([^"]+)"/)?.[1] ?? "";
}

async function post(page: Page, sql: postgres.Sql, path: string, fields: string) {
  const form = new URLSearchParams({ _csrf_token: await csrf(page) });
  for (const line of (await fill(sql, fields)).split("\n").filter(Boolean)) {
    const at = line.indexOf("=");
    const value = line
      .slice(at + 1)
      .trim()
      .replace(/%([0-9A-F]{2})/g, (_, hex) => String.fromCharCode(Number.parseInt(hex, 16)));
    form.append(line.slice(0, at).trim(), value);
  }
  const response = await page.request.post(await fill(sql, path), {
    data: form.toString(),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    maxRedirects: 0,
  });
  answers.set(page, {
    body: await response.text(),
    location: response.headers().location ?? "",
    status: response.status(),
  });
}

function answer(page: Page) {
  const found = answers.get(page);
  if (!found) throw new Error("No mail route was posted to");
  return found;
}

async function toastIn(page: Page) {
  const { location } = answer(page);
  const html = await (await page.request.get(location)).text();
  const toast = html.match(/data-toast[^>]*>\s*<div class="toast[^>]*>([\s\S]*?)<\/div>/)?.[1] ?? "";
  return toast
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&#39;|&#x27;/g, "'")
    .replace(/&quot;/g, '"')
    .trim();
}

const rowOf = (page: Page, subject: string) => page.locator(`.mail-row[data-mail-drag=${JSON.stringify(subject)}]`);

const subjects = (page: Page) =>
  page
    .locator(".mail-row-subject")
    .evaluateAll((nodes) => nodes.map((node) => (node.textContent ?? "").replace(/ · \d+$/, "").trim()));

async function thread(sql: postgres.Sql, subject: string) {
  const [found] = await sql`SELECT * FROM mail_threads WHERE subject = ${subject} ORDER BY id`;
  return found;
}

Given("the mail account {string}", async ({ app }, address: string) => {
  await insertMailAccount(app.sql, address);
});

Given("the mail account {string} that may not send", async ({ app }, address: string) => {
  await insertMailAccount(app.sql, address, { sends: false });
});

Given("the mail threads:", async ({ app }, table: { hashes: () => Row[] }) => {
  for (const row of table.hashes()) {
    const id = await insertMailThread(
      app.sql,
      {
        account: row.account ? await mailAccountId(app.sql, row.account) : undefined,
        archived: yes(row.archived),
        category: row.category || undefined,
        draft: yes(row.draft),
        gmailId: row["gmail id"] || undefined,
        important: yes(row.important),
        receivedAt: ago(row["minutes ago"]),
        sent: yes(row.sent),
        snoozedUntil: row["snoozed hours"]
          ? new Date(Date.now() + Number(row["snoozed hours"]) * 60 * minute)
          : undefined,
        starred: yes(row.starred),
        status: (row.status || undefined) as "read" | "spam" | "unread" | undefined,
        subject: row.subject,
        trashed: yes(row.trashed),
      },
      message(row),
    );
    for (const name of listed(row.labels ?? "")) await labelMailThread(app.sql, id, name);
    for (const name of listed(row.tags ?? "")) await tagMailThread(app.sql, id, name);
  }
});

Given(
  "the mail thread {string} has the messages:",
  async ({ app }, subject: string, table: { hashes: () => Row[] }) => {
    const id = await mailThreadId(app.sql, subject);
    for (const row of table.hashes()) {
      const added = message(row);
      await insertMailMessage(app.sql, id, {
        ...added,
        receivedAt: added.receivedAt ?? new Date(),
        subject: row.subject || undefined,
      });
    }
  },
);

Given(
  "the mail thread {string} has a newer message of {int} letters and a tail",
  async ({ app }, subject: string, size: number) => {
    const id = await mailThreadId(app.sql, subject);
    await insertMailMessage(app.sql, id, {
      body: `${"b".repeat(size)}TAIL`,
      receivedAt: new Date(Date.now() + minute),
    });
  },
);

Given("{int} older mail threads", async ({ app }, count: number) => {
  const account = await mailAccountId(app.sql, "contact form");
  await app.sql`
    WITH made AS (
      INSERT INTO mail_threads (mail_account_id, subject, received_at)
      SELECT ${account}, 'Older ' || n, now() - n * interval '1 hour' FROM generate_series(1, ${count}) AS n
      RETURNING id, subject, received_at
    )
    INSERT INTO mail_messages (mail_thread_id, subject, body, reply_to, received_at)
    SELECT id, subject, 'An older note.', 'older-' || id || '@example.com', received_at FROM made
  `;
});

Given("the mail label {string} on {string}", async ({ app }, name: string, account: string) => {
  await insertMailLabel(app.sql, await mailAccountId(app.sql, account), name);
});

Given(
  "the mail label {string} with the Gmail ID {string} on {string}",
  async ({ app }, name: string, gmailId: string, account: string) => {
    await insertMailLabel(app.sql, await mailAccountId(app.sql, account), name, gmailId);
  },
);

Given("the contact {string} at the mail address {string}", async ({ app }, name: string, emails: string) => {
  await app.sql`
    INSERT INTO people ${app.sql({ emails: app.sql.json(emails.split(", ").map((value) => ({ value }))), name })}
  `;
});

Given("Gmail takes changes to the mail threads {string}", ({ stub }, ids: string) => {
  for (const id of listed(ids)) {
    for (const verb of ["modify", "trash", "untrash"]) {
      stub.reply("POST", `/google/gmail/users/me/threads/${id}/${verb}`, { body: "{}", status: 200 });
    }
    stub.reply("DELETE", `/google/gmail/users/me/threads/${id}`, { body: "", status: 204 });
  }
});

Given("Gmail refuses changes to the mail thread {string}", ({ stub }, id: string) => {
  for (const verb of ["modify", "trash", "untrash"]) {
    stub.reply("POST", `/google/gmail/users/me/threads/${id}/${verb}`, { body: "{}", status: 500 });
  }
  stub.reply("DELETE", `/google/gmail/users/me/threads/${id}`, { body: "", status: 500 });
});

Given("the web serves the image {string}", async ({ page }, url: string) => {
  const png = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
    "base64",
  );
  await page.route(url, (route) => route.fulfill({ body: png, contentType: "image/png" }));
});

When("I visit the mail page {string}", async ({ app, page }, path: string) => {
  await page.goto(await fill(app.sql, path));
});

When("I post to the mail route {string}", async ({ app, page }, path: string) => {
  await post(page, app.sql, path, "");
});

When("I post to the mail route {string} with:", async ({ app, page }, path: string, fields: string) => {
  await post(page, app.sql, path, fields);
});

When("I submit the mail reader form {string}", async ({ page }, name: string) => {
  const form = page.locator(".mail-reader .mail-acts form").filter({ hasText: name }).first();
  const action = (await form.getAttribute("action")) ?? "";
  const fields = await form
    .locator("input[type=hidden]")
    .evaluateAll((nodes) => nodes.map((node) => [(node as HTMLInputElement).name, (node as HTMLInputElement).value]));
  const response = await page.request.post(action, { form: Object.fromEntries(fields), maxRedirects: 0 });
  answers.set(page, {
    body: await response.text(),
    location: response.headers().location ?? "",
    status: response.status(),
  });
});

When(
  "I post {int} mail thread IDs to the bulk route with the act {string}",
  async ({ app, page }, count: number, act: string) => {
    const ids = Array.from({ length: count }, (_, index) => `ids[]=${index + 1}`).join("\n");
    await post(page, app.sql, "/admin/mail/bulk", `act=${act}\nfolder=inbox\n${ids}`);
  },
);

When("I follow the mail answer", async ({ page }) => {
  await page.goto(answer(page).location);
});

When("I open the mail thread {string}", async ({ page }, subject: string) => {
  await rowOf(page, subject).locator(".mail-row-open").click();
  await expect(page.locator(".mail-reader h2.mail-title")).toHaveText(subject);
});

When("I pick the mail account {string}", async ({ page }, name: string) => {
  const select = page.locator("#mail-account");
  const value = await select
    .locator("option")
    .filter({ hasText: new RegExp(`^${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}( · \\d+)?$`) })
    .getAttribute("value");
  await Promise.all([page.waitForURL(/account=/), select.selectOption(value ?? "")]);
});

When("I open the mail folder {string}", async ({ page }, name: string) => {
  await page
    .locator(".mail-folders a")
    .filter({ has: page.getByText(name, { exact: true }) })
    .click();
  await expect(page.locator(".mail-folders a.on .mail-folder-name")).toHaveText(name);
});

When("I click {string} in the mail reader", async ({ page }, name: string) => {
  await page.locator(".mail-reader .mail-acts").getByRole("button", { exact: true, name }).click();
});

Then("the mail page {string} answers with status {int}", async ({ app, page }, path: string, status: number) => {
  const response = await page.request.get(await fill(app.sql, path), { maxRedirects: 0 });
  expect(response.status()).toBe(status);
});

Then("the mail answer has status {int}", ({ page }, status: number) => {
  expect(answer(page).status).toBe(status);
});

Then("the mail answer goes to {string}", async ({ app, page }, path: string) => {
  expect(answer(page).location).toBe(await fill(app.sql, path));
});

Then("the mail answer goes to a page starting {string}", async ({ app, page }, path: string) => {
  expect(answer(page).location.startsWith(await fill(app.sql, path))).toBe(true);
});

Then("the mail answer goes to a page with {string}", async ({ app, page }, text: string) => {
  expect(answer(page).location).toContain(await fill(app.sql, text));
});

Then("the mail page address is {string}", async ({ app, page }, path: string) => {
  const expected = await fill(app.sql, path);
  await expect.poll(() => page.url().slice(new URL(page.url()).origin.length)).toBe(expected);
});

Then("the mail answer shows {string}", ({ page }, text: string) => {
  expect(answer(page).body).toContain(text);
});

Then("the mail toast says {string}", async ({ app, page }, text: string) => {
  if (answers.has(page)) {
    expect(await toastIn(page)).toBe(await fill(app.sql, text));
  } else {
    await expect(page.locator(".toast").filter({ hasText: text }).first()).toBeAttached();
  }
});

Then("the mail list shows {string}", async ({ page }, text: string) => {
  await expect.poll(() => subjects(page)).toEqual(listed(text));
});

Then("the mail list holds {string}", async ({ page }, text: string) => {
  await expect.poll(async () => (await subjects(page)).sort()).toEqual(listed(text).sort());
});

Then("the mail list does not hold {string}", async ({ page }, subject: string) => {
  await expect.poll(() => subjects(page)).not.toContain(subject);
});

Then("the mail list says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-list .empty")).toHaveText(text);
});

Then("the mail head says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".page-head-sub")).toHaveText(text);
});

Then("the mail account picker offers {string}", async ({ page }, text: string) => {
  await expect(page.locator("#mail-account option")).toHaveText(listed(text));
});

Then("the mail account picker does not offer {string}", async ({ page }, name: string) => {
  await expect(page.locator("#mail-account option").filter({ hasText: name })).toHaveCount(0);
});

Then("the mail row {string} shows {string}", async ({ page }, subject: string, text: string) => {
  await expect(rowOf(page, subject)).toContainText(text);
});

Then("the mail row {string} does not show {string}", async ({ page }, subject: string, text: string) => {
  await expect(rowOf(page, subject)).not.toContainText(text);
});

Then("the mail row {string} reads {string}", async ({ page }, subject: string, text: string) => {
  await expect(rowOf(page, subject).locator(".mail-row-subject")).toHaveText(text);
});

Then("the mail row {string} is from {string}", async ({ page }, subject: string, text: string) => {
  await expect(rowOf(page, subject).locator(".mail-row-from")).toContainText(text);
});

Then("the mail row {string} previews {string}", async ({ page }, subject: string, text: string) => {
  await expect(rowOf(page, subject).locator(".mail-row-preview")).toHaveText(text);
});

Then(
  "the mail row {string} previews the first {int} letters alone",
  async ({ page }, subject: string, size: number) => {
    await expect(rowOf(page, subject).locator(".mail-row-preview")).toHaveText("b".repeat(size));
  },
);

Then("the mail row {string} wears a star", async ({ page }, subject: string) => {
  await expect(rowOf(page, subject).locator(".mail-row-when [aria-label='Starred']")).toHaveCount(1);
});

Then("the mail row {string} is dimmed", async ({ page }, subject: string) => {
  await expect(rowOf(page, subject)).toHaveClass(/\bsnoozed\b/);
});

Then("the mail row {string} is open", async ({ page }, subject: string) => {
  await expect(rowOf(page, subject)).toHaveClass(/\bon\b/);
});

Then("the mail row {string} has no account chip", async ({ page }, subject: string) => {
  await expect(rowOf(page, subject).locator(".mail-account")).toHaveCount(0);
});

Then("the mail row {string} has no why chip", async ({ page }, subject: string) => {
  await expect(rowOf(page, subject).locator(".mail-why")).toHaveCount(0);
});

Then("the mail row {string} waits in Waiting", async ({ page }, subject: string) => {
  await expect(rowOf(page, subject).locator(".mail-why")).toHaveText("in waiting");
});

Then("the mail folders count:", async ({ page }, table: { raw: () => string[][] }) => {
  for (const [name, count] of table.raw()) {
    const link = page.locator(".mail-folders > a").filter({ has: page.getByText(name, { exact: true }) });
    await expect(link).toHaveText(`${name}${count}`);
  }
});

Then("the mail folder {string} is open", async ({ page }, name: string) => {
  await expect(page.locator(".mail-folders a.on[aria-current='page'] .mail-folder-name")).toHaveText(name);
});

Then("the mail folder select picks {string}", async ({ page }, value: string) => {
  await expect(page.locator("select.mail-folder-select")).toHaveValue(value);
});

Then("the mail folder select offers the folders {string}", async ({ page }, text: string) => {
  const values = await page
    .locator("select.mail-folder-select optgroup")
    .first()
    .locator("option")
    .evaluateAll((nodes) => nodes.map((node) => (node as HTMLOptionElement).value));
  expect(values).toEqual(listed(text));
});

Then("the mail folder select offers the labels {string}", async ({ page }, text: string) => {
  await expect(page.locator("select.mail-folder-select optgroup").last().locator("option")).toHaveText(listed(text));
});

Then("the mail sidebar groups the labels:", async ({ page }, table: { raw: () => string[][] }) => {
  const rows = table.raw();
  await expect(page.locator(".mail-folder-head")).toHaveText(rows.map(([head]) => head));
  const groups = page.locator(".mail-folder-group");
  for (const [index, [, labels]] of rows.entries()) {
    await expect(groups.nth(index).locator("a")).toHaveText(listed(labels));
  }
});

Then("the mail sidebar lists the labels {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-folder-group a .mail-folder-name")).toHaveText(listed(text));
});

Then("the mail search holds {string} and shows {string}", async ({ page }, search: string, show: string) => {
  await expect(page.locator("#mail-search")).toHaveValue(search);
  await expect(page.locator(`.seg input[name='show'][value='${show}']`)).toBeChecked();
});

Then("the mail reader title is {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-reader h2.mail-title")).toHaveText(text);
});

Then("the mail reader meta shows {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-reader > .inbox-meta")).toContainText(text);
});

Then("the mail reader says why it waits: {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-reader > .inbox-meta .mail-why")).toHaveText(text);
});

Then("the mail reader shows the latest message as plain text {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-reader > .mail-message p.msg-body.mail-message-body")).toContainText(text);
});

Then("the mail reader folds {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-reader details.mail-earlier summary")).toHaveText(text);
});

Then("the mail reader marks the folded message {string} as mine", async ({ page }, text: string) => {
  await expect(
    page.locator(".mail-reader details.mail-earlier .mail-message.me").filter({ hasText: text }),
  ).toHaveCount(1);
});

Then("the mail reader shows a link {string} to {string}", async ({ app, page }, name: string, href: string) => {
  await expect(page.locator(".mail-reader").getByRole("link", { exact: true, name })).toHaveAttribute(
    "href",
    await fill(app.sql, href),
  );
});

Then("the mail reader shows a list item {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-reader .mail-rich ul > li")).toHaveText(text);
});

Then("the mail reader loads the image {string}", async ({ page }, src: string) => {
  const image = page.locator(`.mail-reader .mail-rich img[src='${src}']`);
  await expect(image).toHaveCount(1);
  await expect.poll(() => image.evaluate((node) => (node as HTMLImageElement).naturalWidth)).toBeGreaterThan(0);
});

Then("the mail sender says {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-who")).toContainText(text);
});

Then("the mail actions are {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-acts button:visible, .mail-acts a:visible").filter({ hasNotText: /^$/ })).toHaveText(
    text.split(", "),
  );
});

Then("the mail thread {string} is now {word}", async ({ app }, subject: string, state: string) => {
  const checks: Record<string, (row: postgres.Row) => boolean> = {
    archived: (row) => row.archived,
    awake: (row) => !row.snoozed_until || row.snoozed_until <= new Date(),
    inboxed: (row) => !row.archived && !row.trashed && !row.snoozed_until,
    kept: (row) => Boolean(row),
    read: (row) => row.status === "read",
    snoozed: (row) => row.snoozed_until > new Date(),
    spam: (row) => row.status === "spam",
    starred: (row) => row.starred,
    trashed: (row) => row.trashed,
    unarchived: (row) => !row.archived,
    unread: (row) => row.status === "unread",
    unstarred: (row) => !row.starred,
  };
  if (state === "gone") {
    await expect.poll(() => thread(app.sql, subject)).toBeUndefined();
    return;
  }
  await expect.poll(async () => checks[state](await thread(app.sql, subject))).toBe(true);
});

Then("the mail thread {string} wears the label {string}", async ({ app }, subject: string, gmailId: string) => {
  const labels = await app.sql`
    SELECT l.gmail_id FROM mail_thread_labels tl JOIN mail_labels l ON l.id = tl.mail_label_id
    WHERE tl.mail_thread_id = ${await mailThreadId(app.sql, subject)}
  `;
  expect(labels.map((label) => label.gmail_id)).toEqual([gmailId]);
});

Then("the mail thread {string} wears no label", async ({ app }, subject: string) => {
  const labels = await app.sql`
    SELECT 1 FROM mail_thread_labels WHERE mail_thread_id = ${await mailThreadId(app.sql, subject)}
  `;
  expect(labels.length).toBe(0);
});

Then("the mail thread {string} has the tags {string}", async ({ app }, subject: string, names: string) => {
  const tags = await app.sql`
    SELECT t.name FROM mail_thread_tags mt JOIN tags t ON t.id = mt.tag_id
    WHERE mt.mail_thread_id = ${await mailThreadId(app.sql, subject)} ORDER BY t.name
  `;
  expect(tags.map((tag) => tag.name)).toEqual(listed(names));
});

Then("no mail sender is flagged as spam", async ({ app }) => {
  const [{ count }] = await app.sql`SELECT count(*)::int AS count FROM spam_senders`;
  expect(count).toBe(0);
});

Then("Gmail got {word} {string} {int} time(s)", ({ stub }, method: string, path: string, count: number) => {
  expect(stub.received(method, `/google/gmail${path}`).length).toBe(count);
});

Then("the mail bulk bar acts are {string}", async ({ page }, text: string) => {
  const values = await page
    .locator("form#mail-bulk button[name='act']")
    .evaluateAll((nodes) => nodes.map((node) => (node as HTMLButtonElement).value));
  expect(values).toEqual(listed(text));
});

Then("the mail bulk bar moves to {string}", async ({ page }, text: string) => {
  const values = await page
    .locator("form#mail-bulk select[name='to'] option")
    .evaluateAll((nodes) => nodes.map((node) => (node as HTMLOptionElement).value));
  expect(values).toEqual(["", ...listed(text)]);
});

Then("the mail bulk bar labels with {string}", async ({ page }, text: string) => {
  await expect(page.locator("form#mail-bulk select[name='label'] option")).toHaveText(listed(text));
});

When("I make a task from the mail reader", async ({ page }) => {
  await page.locator(".mail-reader .mail-acts").getByRole("button", { exact: true, name: "Make a task" }).click();
  await expect(page.getByRole("dialog", { name: "Task from mail" })).toBeVisible();
});

Then(
  "the mail task dialog offers the title {string} on the lists {string} and archives",
  async ({ page }, title: string, lists: string) => {
    const dialog = page.getByRole("dialog", { name: "Task from mail" });
    await expect(dialog.getByLabel("Title")).toHaveValue(title);
    const values = await dialog
      .locator("input[name='task[list]']")
      .evaluateAll((nodes) => nodes.map((node) => (node as HTMLInputElement).value));
    expect(values).toEqual(listed(lists));
    await expect(dialog.getByLabel("Archive the thread now")).toBeChecked();
  },
);

Then("the mail task dialog says {string}", async ({ page }, text: string) => {
  await expect(page.getByRole("dialog", { name: "Task from mail" })).toContainText(text);
});

When("I save the mail task on {string} without archiving", async ({ page }, list: string) => {
  const dialog = page.getByRole("dialog", { name: "Task from mail" });
  await dialog.locator(`input[name='task[list]'][value='${list}']`).check({ force: true });
  await dialog.getByLabel("Archive the thread now").uncheck({ force: true });
  await dialog.getByRole("button", { name: "Add task" }).click();
});

When("two tabs make a task from the mail thread {string} at once", async ({ app, page }, subject: string) => {
  const id = await mailThreadId(app.sql, subject);
  const token = await csrf(page);
  const form = { _csrf_token: token, folder: "inbox", "task[list]": "next", "task[title]": "Book lunch" };
  let tabs: Promise<unknown>[] = [];
  await app.sql.begin(async (held) => {
    await held`SELECT id FROM mail_threads WHERE id = ${id} FOR UPDATE`;
    tabs = [0, 1].map(() => page.request.post(`/admin/mail/${id}/task`, { form, maxRedirects: 0 }));
    await expect
      .poll(async () => {
        const [{ count }] = await app.sql`
          SELECT count(*)::int AS count FROM pg_stat_activity
          WHERE wait_event_type = 'Lock' AND datname = current_database()
        `;
        return count;
      })
      .toBe(2);
  });
  await Promise.all(tabs);
});

Then("mail made {int} task(s) called {string}", async ({ app }, count: number, title: string) => {
  await expect
    .poll(async () => (await app.sql`SELECT count(*)::int AS count FROM tasks WHERE title = ${title}`)[0].count)
    .toBe(count);
});

Then(
  "the task {string} sits on {string} linked to the mail thread {string}",
  async ({ app }, title: string, list: string, subject: string) => {
    const [task] = await app.sql`SELECT id, list FROM tasks WHERE title = ${title}`;
    expect(task.list).toBe(list);
    const links = await app.sql`
      SELECT 1 FROM record_links WHERE left_kind = 'task' AND left_id = ${task.id}
      AND right_kind = 'mail_thread' AND right_id = ${await mailThreadId(app.sql, subject)}
    `;
    expect(links.length).toBe(1);
  },
);

Then("the mail thread {string} has no task", async ({ app }, subject: string) => {
  const links = await app.sql`
    SELECT 1 FROM record_links WHERE right_kind = 'mail_thread' AND right_id = ${await mailThreadId(app.sql, subject)}
  `;
  expect(links.length).toBe(0);
});

Then("the mail actions do not offer {string}", async ({ page }, name: string) => {
  await expect(page.locator(".mail-acts").getByRole("button", { exact: true, name })).toHaveCount(0);
});

Then("the page links {string} to the mail page {string}", async ({ app, page }, name: string, href: string) => {
  await expect(page.getByRole("link", { exact: true, name })).toHaveAttribute("href", await fill(app.sql, href));
});

type Point = { x: number; y: number };

const touches = new WeakMap<Page, Awaited<ReturnType<ReturnType<Page["context"]>["newCDPSession"]>>>();

async function touch(page: Page, type: string, point?: Point) {
  if (!touches.has(page)) touches.set(page, await page.context().newCDPSession(page));
  await touches.get(page)?.send("Input.dispatchTouchEvent", {
    touchPoints: point ? [point] : [],
    type: type as "touchStart",
  });
}

async function middle(locator: ReturnType<Page["locator"]>) {
  const box = await locator.boundingBox();
  if (!box) throw new Error("The element has no box");
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
}

const folderLink = (page: Page, name: string) =>
  page.locator(".mail-folders a").filter({ has: page.getByText(name, { exact: true }) });

function stroke(from: Point, to: Point) {
  return [1, 2, 3, 4, 5, 6].map((step) => ({
    x: from.x + ((to.x - from.x) * step) / 6,
    y: from.y + ((to.y - from.y) * step) / 6,
  }));
}

async function mouseDrag(page: Page, subject: string, folder: string, release: boolean) {
  const from = await middle(rowOf(page, subject));
  const to = await middle(folderLink(page, folder));
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  for (const point of stroke(from, to)) await page.mouse.move(point.x, point.y);
  if (release) await page.mouse.up();
}

async function touchDrag(page: Page, subject: string, folder: string, hold: boolean, release: boolean) {
  const from = await middle(rowOf(page, subject));
  const path = stroke(from, await middle(folderLink(page, folder)));
  await touch(page, "touchStart", from);
  if (hold) await page.waitForTimeout(400);
  for (const point of path) await touch(page, "touchMove", point);
  if (release) await touch(page, "touchEnd");
}

Given("I use a mail screen {int} pixels wide", async ({ page }, width: number) => {
  await page.setViewportSize({ height: 800, width });
});

Given("I use a mail screen {int} pixels wide and {int} tall", async ({ page }, width: number, height: number) => {
  await page.setViewportSize({ height, width });
});

When("I mark the mail page", async ({ page }) => {
  await page.evaluate(() => {
    (window as unknown as { kept: boolean }).kept = true;
  });
});

Then("the mail page has not reloaded", async ({ page }) => {
  expect(await page.evaluate(() => (window as unknown as { kept?: boolean }).kept)).toBe(true);
});

When("I tick every mail row", async ({ page }) => {
  await page.getByRole("button", { name: "Select" }).click();
  for (const box of await page.locator(".mail-row input[name='ids[]']").all()) await box.check();
});

When("I click {string} on the mail bulk bar", async ({ page }, name: string) => {
  await page.locator("#mail-bulk").getByRole("button", { exact: true, name }).click();
});

When("I move the ticked mail to {string}", async ({ page }, name: string) => {
  await page.locator("#mail-bulk select[name='to']").selectOption({ label: name });
});

When("I pick {string} from the mail folder select", async ({ page }, name: string) => {
  await page.locator("#mail-folder").selectOption({ label: name });
});

When("I open the mail menu on {string}", async ({ page }, subject: string) => {
  await rowOf(page, subject).locator(".mail-row-subject").click({ button: "right" });
  await expect(page.locator("[data-context-menu]")).toBeVisible();
});

When("I open the mail menu on the inbox row {string}", async ({ page }, subject: string) => {
  await page.locator(".inbox-row-title", { hasText: subject }).click({ button: "right" });
  await expect(page.locator("[data-context-menu]")).toBeVisible();
});

When("I pick {string} from the mail menu", async ({ page }, name: string) => {
  await page.locator("[data-context-menu] .ctx-item").filter({ hasText: name }).first().click();
});

When("I drag the mail row {string} onto the folder {string}", async ({ page }, subject: string, folder: string) => {
  await mouseDrag(page, subject, folder, true);
});

When(
  "I drag the mail row {string} over the folder {string} and hold it there",
  async ({ page }, subject: string, folder: string) => {
    await mouseDrag(page, subject, folder, false);
  },
);

When(
  "I drag the mail row {string} by touch onto the folder {string}",
  async ({ page }, subject: string, folder: string) => {
    await touchDrag(page, subject, folder, true, true);
  },
);

When(
  "I swipe the mail row {string} toward the folder {string} without holding first",
  async ({ page }, subject: string, folder: string) => {
    await touchDrag(page, subject, folder, false, false);
  },
);

When("I tap the mail row {string}", async ({ page }, subject: string) => {
  await touch(page, "touchStart", await middle(rowOf(page, subject)));
  await touch(page, "touchEnd");
});

When("I press and hold the mail row {string}", async ({ page }, subject: string) => {
  await touch(page, "touchStart", await middle(rowOf(page, subject)));
  await page.waitForTimeout(400);
});

When("I swipe up the mail list", async ({ page }) => {
  const { x } = await middle(page.locator(".mail-row").first());
  for (const step of [0, 1, 2, 3, 4, 5, 6])
    await touch(page, step ? "touchMove" : "touchStart", { x, y: 450 - step * 50 });
  await touch(page, "touchEnd");
});

Then("the mail list has scrolled", async ({ page }) => {
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(0);
});

Then("no mail row drags", async ({ page }) => {
  await expect(page.locator(".mail-row.mail-dragging")).toHaveCount(0);
  await touch(page, "touchCancel");
});

Then(
  "the mail drag shows {string} over {int} faded rows with {string} lit among {int} targets",
  async ({ page }, ghost: string, rows: number, folder: string, targets: number) => {
    await expect(page.locator(".mail-ghost")).toContainText(ghost);
    await expect(page.locator(".mail-row.mail-dragging")).toHaveCount(rows);
    await expect(page.locator(".mail-folder.mail-drop")).toHaveCount(targets);
    await expect(page.locator(".mail-folder.mail-drop.mail-over")).toContainText(folder);
  },
);

Then("{int} mail row(s) wear(s) a star", async ({ page }, count: number) => {
  await expect(page.locator(".mail-row .fa-star")).toHaveCount(count);
});

Then("the mail folder sidebar shows and the folder select hides", async ({ page }) => {
  await expect(page.locator("nav.mail-folders")).toBeVisible();
  await expect(page.locator("#mail-folder")).toBeHidden();
});

Then("the mail folder select shows and the sidebar hides", async ({ page }) => {
  await expect(page.locator("#mail-folder")).toBeVisible();
  await expect(page.locator("nav.mail-folders")).toBeHidden();
});

Then("the mail folders and both panes fit the screen", async ({ page }) => {
  const overflow = await page.evaluate(() => {
    const nav = document.querySelector("nav.mail-folders") as HTMLElement;
    return [nav.scrollWidth - nav.clientWidth, document.documentElement.scrollWidth - innerWidth];
  });
  expect(overflow[0]).toBe(0);
  expect(overflow[1]).toBeLessThanOrEqual(0);
  await expect(page.locator(".mail-list")).toBeVisible();
  await expect(page.locator(".mail-reader")).toBeVisible();
});

Then("the mail bulk bar has no Move button", async ({ page }) => {
  await expect(page.locator("#mail-bulk button[value='move']")).toBeHidden();
});

Then("the mail Select toggle is off", async ({ page }) => {
  await expect(page.locator("button[data-bulk-toggle][aria-pressed='false']")).toHaveText("Select");
});

const menu = (page: Page) => page.locator("[data-context-menu]");

function menuItem(page: Page, label: string, under?: string) {
  const scope = under
    ? menu(page).locator("[aria-haspopup]", { hasText: under }).locator("xpath=following-sibling::*[@role='menu']")
    : menu(page);
  return scope
    .locator(".ctx-label")
    .filter({ hasText: new RegExp(`^${label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`) })
    .first();
}

async function menuForm(page: Page, label: string, under?: string) {
  const form = menuItem(page, label, under).locator("xpath=ancestor::form[1]");
  const fields = await form
    .locator("input")
    .evaluateAll((nodes) => nodes.map((node) => [(node as HTMLInputElement).name, (node as HTMLInputElement).value]));
  return { action: await form.getAttribute("action"), fields };
}

When("I fetch the mail menu {string}", async ({ app, page }, path: string) => {
  await page.goto(await fill(app.sql, path));
  await expect(menu(page)).toBeAttached();
});

Given("the task {string} links the mail thread {string}", async ({ app }, title: string, subject: string) => {
  const [task] = await app.sql`
    INSERT INTO tasks ${app.sql({ list: "next", position: 1, status: "open", title })} RETURNING id
  `;
  await app.sql`
    INSERT INTO record_links ${app.sql({
      left_id: task.id,
      left_kind: "task",
      right_id: await mailThreadId(app.sql, subject),
      right_kind: "mail_thread",
    })}
  `;
});

Then("the mail menu is headed {string}", async ({ page }, text: string) => {
  await expect(menu(page).locator(":scope > .ctx-head")).toHaveText(text);
});

Then("the mail menu holds {string}", async ({ page }, text: string) => {
  const labels = await menu(page)
    .locator(".ctx-label")
    .evaluateAll((nodes) => nodes.map((node) => (node.textContent ?? "").trim()));
  const late = labels.includes("Later today");
  expect(labels).toEqual(text.split(", ").filter((label) => late || label !== "Later today"));
});

Then("the mail menu includes {string}", async ({ page }, text: string) => {
  const labels = await menu(page)
    .locator(".ctx-label")
    .evaluateAll((nodes) => nodes.map((node) => (node.textContent ?? "").trim()));
  expect(labels).toEqual(expect.arrayContaining(text.split(", ")));
});

Then("the mail menu leaves out {string}", async ({ page }, text: string) => {
  const labels = await menu(page)
    .locator(".ctx-label")
    .evaluateAll((nodes) => nodes.map((node) => (node.textContent ?? "").trim()));
  for (const label of text.split(", ")) expect(labels).not.toContain(label);
});

Then(
  "the mail menu item {string} posts to {string} with {string}",
  async ({ app, page }, label: string, action: string, fields: string) => {
    const form = await menuForm(page, label);
    expect(form.action).toBe(await fill(app.sql, action));
    expect(form.fields).toEqual(
      expect.arrayContaining(new URLSearchParams(await fill(app.sql, fields)).entries().toArray()),
    );
  },
);

Then(
  "the mail menu item {string} under {string} posts to {string} with {string}",
  async ({ app, page }, label: string, under: string, action: string, fields: string) => {
    const form = await menuForm(page, label, under);
    expect(form.action).toBe(await fill(app.sql, action));
    expect(form.fields).toEqual(
      expect.arrayContaining(new URLSearchParams(await fill(app.sql, fields)).entries().toArray()),
    );
  },
);

Then("the mail menu item {string} sends no {string}", async ({ page }, label: string, name: string) => {
  const form = await menuForm(page, label);
  expect(form.fields.map(([field]) => field)).not.toContain(name);
});

Then(
  "the mail menu item {string} posts the IDs of {string}",
  async ({ app, page }, label: string, subjects: string) => {
    const form = await menuForm(page, label);
    const ids = await Promise.all(
      listed(subjects).map(async (subject) => String(await mailThreadId(app.sql, subject))),
    );
    expect(form.fields.filter(([name]) => name === "ids[]").map(([, value]) => value)).toEqual(ids);
  },
);

Then("the mail menu shows {string} under {string} ticked and fixed", async ({ page }, label: string, under: string) => {
  const item = menuItem(page, label, under).locator("xpath=ancestor::button[1]");
  await expect(item).toHaveAttribute("aria-checked", "true");
  await expect(item).toBeDisabled();
});

Then(
  "the mail menu item {string} opens the task dialog of {string}",
  async ({ app, page }, label: string, subject: string) => {
    const id = await mailThreadId(app.sql, subject);
    await expect(menuItem(page, label).locator("xpath=ancestor::a[1]")).toHaveAttribute(
      "data-dialog-open",
      `mail-task-${id}`,
    );
    await expect(page.locator(`dialog#mail-task-${id} form[action='/admin/mail/${id}/task']`)).toBeAttached();
  },
);

Then("the mail menu copies {string}", async ({ page }, text: string) => {
  await expect(menu(page).locator(`[data-copy='${text}']`)).toBeAttached();
});

Then(
  "the mail menu item {string} links to a page starting {string}",
  async ({ app, page }, label: string, href: string) => {
    const link = await menuItem(page, label).locator("xpath=ancestor::a[1]").getAttribute("href");
    expect(link?.startsWith(await fill(app.sql, href))).toBe(true);
  },
);

Then("the mail menu item {string} asks {string} first", async ({ page }, label: string, text: string) => {
  await expect(menuItem(page, label).locator("xpath=ancestor::button[1]")).toHaveAttribute("data-confirm-inline", text);
});

Then(
  "the mail menu offers a new label field under {string} that posts {string}",
  async ({ page }, under: string, fields: string) => {
    const submenu = menu(page)
      .locator("[aria-haspopup]", { hasText: under })
      .locator("xpath=following-sibling::*[@role='menu']");
    const field = submenu.locator("input[type='text'][name='tag']");
    await expect(field).toBeAttached();
    const values = await field
      .locator("xpath=ancestor::form[1]")
      .locator("input")
      .evaluateAll((nodes) => nodes.map((node) => [(node as HTMLInputElement).name, (node as HTMLInputElement).value]));
    expect(values).toEqual(expect.arrayContaining(new URLSearchParams(fields).entries().toArray()));
  },
);

Then("the mail row {string} hangs its menu on {string}", async ({ app, page }, subject: string, path: string) => {
  await expect(rowOf(page, subject)).toHaveAttribute("data-menu", await fill(app.sql, path));
});

Then("the mail bulk bar hangs its menu on {string}", async ({ page }, path: string) => {
  await expect(page.locator("#mail-bulk")).toHaveAttribute("data-bulk-menu", path);
});

Then(
  "the inbox row for the mail thread {string} hangs its menu on {string}",
  async ({ app, page }, subject: string, path: string) => {
    const id = await mailThreadId(app.sql, subject);
    await expect(page.locator(`#message-${id}`)).toHaveAttribute("data-menu", await fill(app.sql, path));
  },
);

Then("the mail bulk bar hints {string}", async ({ page }, text: string) => {
  await expect(page.locator("#mail-bulk .bulk-hint")).toHaveText(text);
});

Then("the mail bulk bar hides until Select", async ({ page }) => {
  await expect(page.locator("#mail-bulk")).toBeHidden();
});

Then("no mail row is ticked", async ({ page }) => {
  for (const box of await page.locator(".mail-row input[name='ids[]']").all())
    expect(await box.isChecked()).toBe(false);
});

Then("the mail thread {string} now snoozes until {string}", async ({ app }, subject: string, pick: string) => {
  const [row] = await app.sql`
    SELECT to_char(snoozed_until AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD"T"HH24:MI') AS until
    FROM mail_threads WHERE subject = ${subject}
  `;
  expect(row.until).toBe(await fill(app.sql, pick));
});

When("I reload the mail page", async ({ page }) => {
  await page.reload();
});

const settingsBox = async (page: Page, sql: postgres.Sql, name: string) =>
  page.locator(`input[type='checkbox'][name=${JSON.stringify(await fill(sql, name))}]`);

Then("the mail settings tick {string}", async ({ app, page }, name: string) => {
  await expect(await settingsBox(page, app.sql, name)).toBeChecked();
});

Then("the mail settings leave {string} unticked", async ({ app, page }, name: string) => {
  await expect(await settingsBox(page, app.sql, name)).not.toBeChecked();
});

Then("the mail settings have no {string} box", async ({ app, page }, name: string) => {
  await expect(await settingsBox(page, app.sql, name)).toHaveCount(0);
});

When("I untick {string} in the mail settings", async ({ app, page }, name: string) => {
  await (await settingsBox(page, app.sql, name)).uncheck({ force: true });
});

Then("the mail settings hint says {string}", async ({ page }, text: string) => {
  await expect(page.locator("#mail-waiting .hint")).toHaveText(text);
});

Then("no mail settings are stored", async ({ app }) => {
  const [{ count }] = await app.sql`SELECT count(*)::int AS count FROM mail_settings`;
  expect(count).toBe(0);
});

Then("the mail settings store {string} as {word}", async ({ app }, rule: string, value: string) => {
  await expect.poll(async () => String((await app.sql`SELECT * FROM mail_settings`)[0]?.[rule])).toBe(value);
});

Then("the mail account {string} now sends no mail", async ({ app }, name: string) => {
  const [account] = await app.sql`SELECT sends FROM mail_accounts WHERE name = ${name}`;
  expect(account.sends).toBe(false);
});

Then("Waiting holds the mail {string}", async ({ page }, text: string) => {
  await expect
    .poll(async () => {
      await page.goto("/admin/inbox");
      return (await page.locator("[data-key-list] .inbox-row-title").allTextContents())
        .map((title) => title.trim())
        .sort();
    })
    .toEqual(listed(text).sort());
});

Then(
  "Waiting says the mail thread {string} waits for {string}",
  async ({ app, page }, subject: string, text: string) => {
    await page.goto("/admin/inbox");
    await expect(page.locator(`#message-${await mailThreadId(app.sql, subject)}`)).toContainText(text);
  },
);

Then("the command palette counts {string} for the inbox", async ({ page }, text: string) => {
  await expect(page.locator("#command-palette-inbox .pal-r-sub")).toHaveText(text);
});

Then("Today counts {string} for the inbox", async ({ page }, text: string) => {
  await expect(page.locator("section.card[data-attention] .today-line", { hasText: "Inbox" })).toContainText(text);
});

const gmailUrl = (path: string) => `/google/gmail/users/me${path}`;

function gmailJson(
  stub: { reply: (method: string, path: string, reply: { body: string; status: number }) => void },
  method: string,
  path: string,
  body: unknown,
) {
  stub.reply(method, gmailUrl(path), { body: JSON.stringify(body), status: 200 });
}

function sentThread(id: string, messageId: string, label: string) {
  return {
    id,
    messages: [
      {
        id: messageId,
        internalDate: String(Date.now()),
        labelIds: [label],
        payload: {
          headers: [
            { name: "From", value: "aaron@work.example" },
            { name: "Subject", value: "Engines" },
          ],
          mimeType: "text/html",
          body: { data: Buffer.from("<p>Hi</p>").toString("base64url") },
        },
        threadId: id,
      },
    ],
  };
}

function sentBody(stub: { received: (method: string, path: string) => string[] }, method: string, path: string) {
  const body = stub.received(method, gmailUrl(path)).at(-1);
  if (!body) throw new Error(`Gmail got no ${method} ${path}`);
  return JSON.parse(body);
}

function sentRaw(stub: { received: (method: string, path: string) => string[] }, method: string, path: string) {
  const json = sentBody(stub, method, path);
  return Buffer.from(json.message?.raw ?? json.raw, "base64url").toString("utf8");
}

const htmlPart = (raw: string) =>
  Buffer.from(raw.match(/text\/html[\s\S]*?\r\n\r\n([\s\S]*?)\r\n--/)?.[1] ?? "", "base64").toString("utf8");

Given("Gmail sends mail into the thread {string}", ({ stub }, id: string) => {
  gmailJson(stub, "POST", "/messages/send", { id: "s1", labelIds: ["SENT"], threadId: id });
  gmailJson(stub, "GET", `/threads/${id}`, sentThread(id, "s1", "SENT"));
});

Given("Gmail sends the draft {string} into the thread {string}", ({ stub }, draft: string, id: string) => {
  gmailJson(stub, "POST", "/drafts/send", { id: "s1", labelIds: ["SENT"], threadId: id });
  gmailJson(stub, "GET", `/threads/${id}`, sentThread(id, "d1", "SENT"));
  expect(draft).toBeTruthy();
});

Given("Gmail saves drafts as {string} into the thread {string}", ({ stub }, draft: string, id: string) => {
  const saved = { id: draft, message: { id: "d1", threadId: id } };
  gmailJson(stub, "POST", "/drafts", saved);
  gmailJson(stub, "PUT", `/drafts/${draft}`, saved);
  gmailJson(stub, "GET", `/threads/${id}`, sentThread(id, "d1", "DRAFT"));
  gmailJson(stub, "GET", "/messages/d1", sentThread(id, "d1", "DRAFT").messages[0]);
});

Given("the mail account {string} signs with {string}", async ({ app }, name: string, signature: string) => {
  await app.sql`UPDATE mail_accounts SET signature = ${signature} WHERE name = ${name}`;
});

Given(
  "the mail thread {string} holds the attachment {string} as part {string}",
  async ({ app }, subject: string, filename: string, part: string) => {
    const [message] = await app.sql`
    SELECT id FROM mail_messages WHERE mail_thread_id = ${await mailThreadId(app.sql, subject)} ORDER BY id LIMIT 1
  `;
    await app.sql`
    INSERT INTO mail_attachments ${app.sql({ filename, mail_message_id: message.id, mime_type: "application/pdf", part_id: part, size: 2048 })}
  `;
  },
);

When("I send mail with the file {string} holding {string}", async ({ app, page }, filename: string, text: string) => {
  const response = await page.request.post("/admin/mail/send", {
    maxRedirects: 0,
    multipart: {
      _csrf_token: await csrf(page),
      "mail[files][]": { buffer: Buffer.from(text), mimeType: "text/csv", name: filename },
      "mail[from]": String(await mailAccountId(app.sql, "aaron@work.example")),
      "mail[html]": "<p>Hi</p>",
      "mail[subject]": "Engines",
      "mail[to]": "ada@example.com",
    },
  });
  answers.set(page, {
    body: await response.text(),
    location: response.headers().location ?? "",
    status: response.status(),
  });
});

When("I look at the mail answer", async ({ page }) => {
  await page.goto("/admin/mail");
  await page.setContent(answer(page).body);
});

When("I fetch the mail page {string}", async ({ app, page }, path: string) => {
  const response = await page.request.get(await fill(app.sql, path));
  answers.set(page, {
    body: (await response.body()).toString("latin1"),
    location: response.headers()["content-disposition"] ?? "",
    status: response.status(),
  });
});

Then("the mail answer is the file {string} holding {string}", ({ page }, filename: string, text: string) => {
  const { body, location } = answer(page);
  expect(body).toBe(text);
  expect(location.startsWith(`attachment; filename="${filename}"`)).toBe(true);
});

Then("the mail answer holds the JSON:", ({ page }, json: string) => {
  expect(JSON.parse(answer(page).body)).toEqual(JSON.parse(json));
});

Then(
  "Gmail got mail at {word} {string} with the header {string}",
  ({ stub }, method: string, path: string, line: string) => {
    expect(sentRaw(stub, method, path).split("\r\n")).toContain(line);
  },
);

Then(
  "Gmail got mail at {word} {string} with no {string} header",
  ({ stub }, method: string, path: string, name: string) => {
    expect(
      sentRaw(stub, method, path)
        .split("\r\n")
        .filter((line) => line.startsWith(`${name}:`)),
    ).toEqual([]);
  },
);

Then("Gmail got mail at {word} {string} holding {string}", ({ stub }, method: string, path: string, text: string) => {
  expect(sentRaw(stub, method, path)).toContain(text);
});

Then(
  "Gmail got mail at {word} {string} with the HTML {string}",
  ({ stub }, method: string, path: string, html: string) => {
    expect(htmlPart(sentRaw(stub, method, path))).toBe(html);
  },
);

Then(
  "Gmail got mail at {word} {string} carrying the file {string} holding {string}",
  ({ stub }, method: string, path: string, filename: string, text: string) => {
    const raw = sentRaw(stub, method, path);
    const data =
      raw.split(`filename="${filename}"\r\nContent-Transfer-Encoding: base64\r\n\r\n`)[1]?.split(/\s/)[0] ?? "";
    expect(raw).toContain("multipart/mixed");
    expect(Buffer.from(data, "base64").toString("utf8")).toBe(text);
  },
);

Then("Gmail got mail at {word} {string} in a new thread", ({ stub }, method: string, path: string) => {
  expect(sentBody(stub, method, path).threadId).toBeUndefined();
});

Then(
  "Gmail got mail at {word} {string} in the thread {string}",
  ({ stub }, method: string, path: string, id: string) => {
    expect(sentBody(stub, method, path).threadId).toBe(id);
  },
);

Then(
  "Gmail got mail at {word} {string} for the draft {string}",
  ({ stub }, method: string, path: string, id: string) => {
    expect(sentBody(stub, method, path).id).toBe(id);
  },
);

Then("the Gmail thread {string} shows here as {word}", async ({ app }, gmailId: string, state: string) => {
  await expect
    .poll(async () => {
      const [found] = await app.sql`SELECT draft, sent FROM mail_threads WHERE gmail_id = ${gmailId}`;
      return found ? (found.draft ? "draft" : found.sent ? "sent" : "other") : "missing";
    })
    .toBe(state);
});

Then("the Gmail thread {string} sits on the mail account {string}", async ({ app }, gmailId: string, name: string) => {
  const [found] = await app.sql`SELECT mail_account_id FROM mail_threads WHERE gmail_id = ${gmailId}`;
  expect(found.mail_account_id).toBe(await mailAccountId(app.sql, name));
});

Then("the mail compose offers to send from {string}", async ({ page }, text: string) => {
  await expect(page.locator("#mail-compose-from option")).toHaveText(listed(text));
});

Then("the mail compose is open", async ({ page }) => {
  await expect(page.locator("#mail-compose[data-dialog-show]")).toHaveCount(1);
});

Then("the mail compose is closed", async ({ page }) => {
  await expect(page.locator("#mail-compose[data-dialog-show]")).toHaveCount(0);
});

Then("the mail compose field {string} holds {string}", async ({ page }, name: string, value: string) => {
  await expect(page.locator(`#mail-compose input[name='mail[${name}]']`)).toHaveValue(value);
});

Then("the mail compose To field says {string}", async ({ page }, text: string) => {
  await expect(page.locator("#mail-compose input[name='mail[to]']")).toHaveAttribute("placeholder", text);
});

Then("the mail compose To field suggests:", async ({ page }, table: { raw: () => string[][] }) => {
  const list = await page.locator("#mail-compose input[name='mail[to]']").getAttribute("list");
  const options = await page
    .locator(`datalist#${list} option`)
    .evaluateAll((nodes) => nodes.map((node) => [(node as HTMLOptionElement).value, node.textContent ?? ""]));
  expect(options).toEqual(table.raw());
});

Then("the mail compose signs with {string} and can drop it", async ({ page }, text: string) => {
  await expect(page.locator("#mail-compose-signature")).toBeChecked();
  await expect(page.locator(".mail-sig-text")).toContainText(text);
});

Then("the mail compose says {string}", async ({ page }, text: string) => {
  await expect(page.locator("#mail-compose .mail-compose-hint")).toContainText(text);
});

Then("the mail compose says the draft saved", async ({ page }) => {
  await expect(page.locator("#mail-compose .mail-compose-hint")).toHaveText(/draft saved \d/);
});

Then("the mail compose flags {string} with {string}", async ({ page }, field: string, text: string) => {
  const control = page.locator(`#mail-compose-${field}`);
  await expect(control).toHaveAttribute("aria-invalid", "true");
  await expect(control).toHaveAttribute("aria-describedby", `mail-compose-${field}-error`);
  await expect(page.locator(`#mail-compose-${field}-error`)).toContainText(text);
});

Then("the mail compose keeps the HTML {string}", async ({ page }, html: string) => {
  await expect(page.locator("#mail-compose input[name='mail[html]']")).toHaveValue(html);
});

Then("mail cannot be sent from any account", async ({ page }) => {
  await expect(page.locator("select[name='mail[from]']")).toHaveCount(0);
  await expect(page.locator(".mail-head-row .mail-head-none")).toHaveText(
    "No account can send. Grant Gmail send on Connected services.",
  );
  await expect(page.locator(".mail-reply-head .mail-head-none")).toHaveText("no account can send");
});

Then("the mail reply goes to {string} as {string}", async ({ page }, address: string, subject: string) => {
  await expect(page.locator(".mail-reply summary")).toContainText("Reply");
  await expect(page.locator(".mail-reply-to")).toContainText(`to ${address}`);
  await expect(page.locator(".mail-reply input[name='mail[subject]']")).toHaveValue(subject);
});

Then("the mail reply hints {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-reply-hint")).toContainText(text);
});

Then("the mail reply stays open from {string}", async ({ page }, address: string) => {
  await expect(page.locator("details.mail-reply[open]")).toHaveCount(1);
  await expect(page.locator("select#mail-reply-from option:checked")).toHaveText(address);
});

Then("the mail reader offers to edit the draft of {string}", async ({ app, page }, subject: string) => {
  const href = (await page.getByRole("link", { name: "Edit draft" }).getAttribute("href")) ?? "";
  const query = new URL(href, "http://x").searchParams;
  expect([query.get("thread"), query.get("resume")]).toEqual([String(await mailThreadId(app.sql, subject)), "1"]);
});

Then("the mail reader lists the attachment {string} at {string}", async ({ app, page }, name: string, href: string) => {
  await expect(page.locator(".mail-reader").getByRole("link", { name })).toHaveAttribute(
    "href",
    await fill(app.sql, href),
  );
});

Then("the Gmail thread {string} holds the messages {string}", async ({ app }, gmailId: string, ids: string) => {
  const rows = await app.sql`
    SELECT m.gmail_id FROM mail_messages m JOIN mail_threads t ON t.id = m.mail_thread_id
    WHERE t.gmail_id = ${gmailId} ORDER BY m.gmail_id
  `;
  expect(rows.map((row) => row.gmail_id)).toEqual(listed(ids));
});

Then("the Gmail message {string} reads {string}", async ({ app }, gmailId: string, html: string) => {
  const [row] = await app.sql`SELECT html_body FROM mail_messages WHERE gmail_id = ${gmailId}`;
  expect(row.html_body).toBe(html);
});

Then("the Gmail message {string} was not rewritten", async ({ app }, gmailId: string) => {
  const [row] =
    await app.sql`SELECT updated_at < now() - interval '30 minutes' AS old FROM mail_messages WHERE gmail_id = ${gmailId}`;
  expect(row.old).toBe(true);
});

Then("the Gmail thread {string} reads {string} as a draft", async ({ app }, gmailId: string, subject: string) => {
  const [row] = await app.sql`SELECT draft, subject FROM mail_threads WHERE gmail_id = ${gmailId}`;
  expect([row.draft, row.subject]).toEqual([true, subject]);
});

Given("the messages of the mail thread {string} were stored an hour ago", async ({ app }, subject: string) => {
  await app.sql`
    UPDATE mail_messages SET updated_at = now() - interval '1 hour'
    WHERE mail_thread_id = ${await mailThreadId(app.sql, subject)}
  `;
});

Given("the mail account {string} is set not to send", async ({ app }, name: string) => {
  await app.sql`UPDATE mail_accounts SET sends = false WHERE name = ${name}`;
});

Given("the contact {string} with no mail address", async ({ app }, name: string) => {
  await app.sql`INSERT INTO people ${app.sql({ name })}`;
});

const surface = (page: Page) => page.locator("#mail-compose .mail-editor-surface");
const tool = (page: Page, name: string) => page.locator(`#mail-compose [role=toolbar] button[aria-label='${name}']`);
const composeHtml = (page: Page) => page.locator("#mail-compose input[name='mail[html]']");

async function selectSurface(page: Page) {
  await surface(page).evaluate((node) => {
    const range = document.createRange();
    range.selectNodeContents(node);
    getSelection()?.removeAllRanges();
    getSelection()?.addRange(range);
  });
}

When("I open mail compose", async ({ page }) => {
  await page.goto("/admin/mail");
  await page.getByRole("link", { name: "Compose" }).click();
  await surface(page).click();
});

When("I write {string} in the mail editor and select it", async ({ page }, text: string) => {
  await surface(page).evaluate((node) => {
    node.innerHTML = "";
  });
  await surface(page).pressSequentially(text);
  await selectSurface(page);
});

When("I click the mail editor tool {string}", async ({ page }, name: string) => {
  await tool(page, name).click();
});

When("I select everything in the mail editor", async ({ page }) => {
  await selectSurface(page);
});

When("I press {string} in the mail editor", async ({ page }, keys: string) => {
  await surface(page).press(keys);
});

When("I link the mail selection to {string} with the button", async ({ page }, url: string) => {
  await page.getByLabel("Link URL").fill(url);
  await page.getByRole("button", { name: "Add link" }).click();
});

When("I link the mail selection to {string} with Enter", async ({ page }, url: string) => {
  await page.getByLabel("Link URL").fill(url);
  await page.getByLabel("Link URL").press("Enter");
});

When("I paste into the mail editor the HTML:", async ({ page }, html: string) => {
  await surface(page).evaluate((node, pasted) => {
    const data = new DataTransfer();
    data.setData("text/html", pasted);
    node.dispatchEvent(new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: data }));
  }, html);
});

When("I address the mail to {string} about {string}", async ({ page }, to: string, subject: string) => {
  await page.locator("#mail-compose input[name='mail[to]']").fill(to);
  await page.locator("#mail-compose input[name='mail[subject]']").fill(subject);
});

When("I attach the file {string} to the mail", async ({ page }, name: string) => {
  await page
    .locator("#mail-compose-files")
    .setInputFiles({ buffer: Buffer.from("one,two\n"), mimeType: "text/csv", name });
});

When("I type {string} in the mail editor and press {string}", async ({ page }, text: string, keys: string) => {
  await surface(page).click();
  await surface(page).pressSequentially(text);
  await surface(page).press(keys);
});

Given("the mail draft route answers with status 500", async ({ page }) => {
  await page.route("**/admin/mail/draft", (route) => route.fulfill({ body: "", status: 500 }));
});

When("the mail draft route works again", async ({ page }) => {
  await page.unroute("**/admin/mail/draft");
});

When("the browser loses its network for mail", async ({ page }) => {
  await page.evaluate(() => {
    window.fetch = () => Promise.reject(new TypeError("offline"));
  });
});

When("I discard the mail draft", async ({ page }) => {
  await page.getByRole("button", { name: "Discard" }).click();
});

When("a new mail thread {string} arrives", async ({ app, page }, subject: string) => {
  const id = await insertMailThread(app.sql, { subject });
  await expect(page.locator(`#thread-${id}`)).toBeAttached({ timeout: 15_000 });
});

Then("the mail HTML holds {string}", async ({ page }, text: string) => {
  await expect.poll(() => composeHtml(page).inputValue()).toContain(text);
});

Then("the mail HTML does not hold {string}", async ({ page }, text: string) => {
  await expect.poll(() => composeHtml(page).inputValue()).not.toContain(text);
});

Then("the mail editor tool {string} is pressed", async ({ page }, name: string) => {
  await expect(tool(page, name)).toHaveAttribute("aria-pressed", "true");
});

Then("the mail compose shows no cc field", async ({ page }) => {
  await expect(page.locator("#mail-compose-cc")).toBeHidden();
});

Then("the mail compose shows the cc field", async ({ page }) => {
  await expect(page.locator("#mail-compose-cc")).toBeVisible();
});

Then("the mail compose names the files {string}", async ({ page }, text: string) => {
  await expect(page.locator(".mail-attach-names")).toHaveText(text);
});

Then("the mail page address has no {string}", async ({ page }, text: string) => {
  await expect.poll(() => page.url()).not.toContain(text);
});

When("I show the mail cc field", async ({ page }) => {
  await page.locator("#mail-compose").getByRole("button", { exact: true, name: "cc" }).click();
});
