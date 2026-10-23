import { expect } from "@playwright/test";
import {
  escaped,
  expectShown,
  gmailAccount,
  gmailMessage,
  gmailParts,
  gmailPath,
  gmailThread,
  listed,
  moment,
  settle,
  shown,
} from "../support/mail_sync.ts";
import { seal } from "../support/seal.ts";
import type { Stub } from "../support/stub.ts";
import { Given, Then, When } from "../support/world.ts";

type Row = Record<string, string>;
type Mailbox = {
  changed?: Date;
  labels: { id: string; name: string; type: string }[];
  notices: string[];
  threads: Map<string, ReturnType<typeof gmailMessage>[]>;
};

const mailboxes = new WeakMap<object, Mailbox>();

function mailbox(answer: object) {
  const found = mailboxes.get(answer) ?? { labels: [], notices: [], threads: new Map() };
  mailboxes.set(answer, found);
  return found;
}

const json = (stub: Stub, method: string, path: string, body: unknown, status = 200) =>
  stub.reply(method, gmailPath(path), { body: JSON.stringify(body), status });

function history(stub: Stub, historyId: string, records: unknown[]) {
  json(stub, "GET", "/history", { history: records, historyId });
}

Given("Gmail is at history {string}", ({ stub }, historyId: string) => {
  json(stub, "GET", "/profile", { historyId });
});

Given("Gmail is quiet at history {string} for {string}", ({ stub }, historyId: string, address: string) => {
  json(stub, "GET", "/profile", { historyId });
  json(stub, "GET", "/labels", { labels: [] });
  json(stub, "GET", `/settings/sendAs/${address}`, { signature: "" });
  json(stub, "GET", "/threads", { threads: [] });
  history(stub, historyId, []);
});

Given("Gmail has the label {string} named {string}", ({ answer, stub }, id: string, name: string) => {
  const { labels } = mailbox(answer);
  labels.push({ id, name, type: "user" });
  json(stub, "GET", "/labels", { labels: [...labels, { id: "INBOX", name: "INBOX", type: "system" }] });
});

Given("Gmail has the labels {string}", ({ answer, stub }, names: string) => {
  const box = mailbox(answer);
  box.labels = listed(names).map((pair) => {
    const [id, name] = pair.split(": ");
    return { id, name, type: "user" };
  });
  json(stub, "GET", "/labels", { labels: box.labels });
});

Given("Gmail gives {string} the signature {string}", ({ stub }, address: string, signature: string) => {
  json(stub, "GET", `/settings/sendAs/${address}`, { signature });
});

Given(
  "Gmail holds the thread {string} with the messages:",
  async ({ answer, app, stub }, id: string, table: { hashes: () => Row[] }) => {
    const messages = [];
    for (const row of table.hashes()) {
      const cell = (name: string) => (name in row ? escaped(row[name]) : undefined);
      const bodies = "text" in row || "html" in row || "attachment" in row;
      messages.push(
        gmailMessage(row.id, {
          at: row.at ? await moment(app.sql, row.at) : undefined,
          from: cell("from"),
          labels: row.labels === undefined ? undefined : row.labels.split(" ").filter(Boolean),
          parts: bodies
            ? gmailParts({
                attachment: cell("attachment") || undefined,
                charset: cell("charset") || undefined,
                html: cell("html") || undefined,
                text: cell("text") || undefined,
              })
            : undefined,
          subject: cell("subject"),
        }),
      );
    }
    mailbox(answer).threads.set(id, messages);
    json(stub, "GET", `/threads/${id}`, { id, messages: messages.map((message) => ({ ...message, threadId: id })) });
  },
);

Given(
  "Gmail holds the thread {string} with a plain body of {int} words",
  ({ answer, stub }, id: string, count: number) => {
    const text = Array.from({ length: count }, (_, index) => `word${index}`).join(" ");
    const messages = [gmailMessage("m1", { parts: gmailParts({ text }) })];
    mailbox(answer).threads.set(id, messages);
    json(stub, "GET", `/threads/${id}`, { id, messages: messages.map((message) => ({ ...message, threadId: id })) });
  },
);

Given("Gmail serves each message of the thread {string} alone", ({ answer, stub }, threadId: string) => {
  for (const message of mailbox(answer).threads.get(threadId) ?? []) {
    json(stub, "GET", `/messages/${message.id}`, { ...message, threadId });
  }
});

Given(
  "Gmail history moves to {string} with the threads {string}",
  ({ answer, stub }, historyId: string, ids: string) => {
    const { threads } = mailbox(answer);
    const records = listed(ids).map((threadId) => ({
      messages: [{ threadId }],
      messagesAdded: (threads.get(threadId) ?? []).map(({ id, labelIds }) => ({ message: { id, labelIds, threadId } })),
    }));
    history(stub, historyId, records);
  },
);

Given(
  "Gmail history moves to {string} with the labels {string} {word} on the thread {string}",
  ({ stub }, historyId: string, labels: string, change: string, threadId: string) => {
    const key = change === "added" ? "labelsAdded" : "labelsRemoved";
    const changed = [{ labelIds: labels.split(" "), message: { id: "m1", threadId } }];
    history(stub, historyId, [{ [key]: changed, messages: [{ threadId }] }]);
  },
);

Given(
  "Gmail history moves to {string} with a message deleted from the thread {string}",
  ({ stub }, historyId: string, threadId: string) => {
    const changed = [{ message: { id: "m2", threadId } }];
    history(stub, historyId, [{ messages: [{ threadId }], messagesDeleted: changed }]);
  },
);

Given("Gmail no longer holds the history", ({ stub }) => {
  stub.reply("GET", gmailPath("/history"), { body: "", status: 404 });
});

Given("Gmail rate limits GET {string} with status {int}", ({ stub }, path: string, status: number) => {
  const body = { error: { code: status, errors: [{ domain: "usageLimits", reason: "rateLimitExceeded" }] } };
  json(stub, "GET", path.replace(/^\/users\/me/, ""), body, status);
});

Given(
  "the Gmail account {string} has synced to history {string}",
  async ({ app }, address: string, historyId: string) => {
    await app.sql`
    INSERT INTO mail_accounts ${app.sql({
      address,
      history_id: historyId,
      name: address,
      provider: "gmail",
      settings_synced_at: new Date(),
    })}
  `;
  },
);

Given("an hour passes for the Gmail account {string}", async ({ app }, address: string) => {
  await app.sql`
    UPDATE mail_accounts SET settings_synced_at = now() - interval '3601 seconds',
      backfill_held_at = backfill_held_at - interval '3601 seconds'
    WHERE address = ${address}
  `;
});

Given("the Google token for {string} has run out", async ({ app }, account: string) => {
  const credentials = {
    access_token: "ya29.old",
    expires_at: Math.floor(Date.now() / 1000) - 3600,
    refresh_token: "1//old",
  };
  await app.sql`
    UPDATE service_connections SET credentials = ${seal(JSON.stringify(credentials))} WHERE account_id = ${account}
  `;
});

Given("the Google connection for {string} is revoked", async ({ app }, account: string) => {
  await app.sql`UPDATE service_connections SET revoked_at = now() WHERE account_id = ${account}`;
});

Given("the Google connection for {string} is back", async ({ app }, account: string) => {
  await app.sql`UPDATE service_connections SET revoked_at = NULL WHERE account_id = ${account}`;
});

Given("the Google connection for {string} is gone", async ({ app }, account: string) => {
  await app.sql`DELETE FROM service_connections WHERE account_id = ${account}`;
});

Given("the mail sync failed before with {string}", async ({ app }, reason: string) => {
  await app.sql`
    INSERT INTO sync_states ${app.sql({
      failing_since: new Date(),
      failure_count: 1,
      failure_reason: reason,
      kind: "failure",
      sync: "mail",
      synced_at: new Date(),
    })}
  `;
});

When("the Gmail sync runs", async ({ app }) => {
  await app.pushJob("Mail::Jobs::SyncGmail");
  await settle(app);
});

When("the Gmail sync runs while another run holds the lock", async ({ app }) => {
  const held = await app.sql.reserve();
  await held`SELECT pg_advisory_lock(hashtext('mail sync'))`;
  try {
    await app.pushJob("Mail::Jobs::SyncGmail");
    await settle(app);
  } finally {
    await held`SELECT pg_advisory_unlock(hashtext('mail sync'))`;
    held.release();
  }
});

When(
  "the Gmail sync runs to history {string} while I listen for admin notices",
  async ({ answer, app, stub }, historyId: string) => {
    const { notices } = mailbox(answer);
    const listener = await app.sql.listen("admin_changes", (table) => notices.push(table));
    try {
      await app.pushJob("Mail::Jobs::SyncGmail");
      await expect.poll(() => stub.received("GET", gmailPath("/history")).length).toBeGreaterThan(0);
      await expect
        .poll(async () => (await app.sql`SELECT history_id FROM mail_accounts WHERE provider = 'gmail'`)[0]?.history_id)
        .toBe(historyId);
      await app.sql`SELECT pg_notify('admin_changes', 'fence')`;
      await expect.poll(() => notices.includes("fence")).toBe(true);
      notices.splice(notices.indexOf("fence"), 1);
    } finally {
      await listener.unlisten();
    }
    await settle(app);
  },
);

When("the Gmail backfill runs for {string}", async ({ app }, address: string) => {
  await app.pushJob("Mail::Jobs::BackfillGmail", address);
  await settle(app);
});

When("the Gmail backfill runs for {string} from the page {string}", async ({ app }, address: string, page: string) => {
  await app.pushJob("Mail::Jobs::BackfillGmail", address, page);
  await settle(app);
});

When("the stored mail HTML is cleaned again", async ({ app }) => {
  await app.pushJob("Mail::Jobs::RecleanMailHtml");
  await settle(app);
});

When(
  "the stored mail HTML is cleaned again after {int} with {int} gone",
  async ({ app }, after: number, gone: number) => {
    await app.pushJob("Mail::Jobs::RecleanMailHtml", after, gone);
    await settle(app);
  },
);

Then("the admin hears no notice", ({ answer }) => {
  expect(mailbox(answer).notices).toEqual([]);
});

Then("the mail account {string} follows the history {string}", async ({ app }, address: string, historyId: string) => {
  expect((await gmailAccount(app.sql, address))?.history_id).toBe(historyId);
});

Then("the mail account {string} has the signature {string}", async ({ app }, address: string, signature: string) => {
  expect((await gmailAccount(app.sql, address)).signature).toBe(signature);
});

Then("the mail account {string} has no signature", async ({ app }, address: string) => {
  expect((await gmailAccount(app.sql, address)).signature).toBeNull();
});

Then("the mail account {string} holds the Gmail page {string}", async ({ app }, address: string, page: string) => {
  expect(shown((await gmailAccount(app.sql, address)).backfill_page)).toBe(page);
});

Then("the Gmail labels are {string}", async ({ app }, labels: string) => {
  const rows = await app.sql`SELECT gmail_id, name FROM mail_labels ORDER BY gmail_id`;
  expect(rows.map((row) => `${row.gmail_id}: ${row.name}`).join(", ")).toBe(labels);
});

Then("only {string} has a mail account from Gmail", async ({ app }, address: string) => {
  const rows = await app.sql`SELECT address FROM mail_accounts WHERE provider = 'gmail'`;
  expect(rows.map((row) => row.address)).toEqual([address]);
});

Then("the Gmail thread {string} reads:", async ({ app }, id: string, table: { rowsHash: () => Row }) => {
  const thread = await gmailThread(app.sql, id);
  for (const [field, value] of Object.entries(table.rowsHash())) expectShown(thread[field], value, field);
});

Then("the Gmail thread {string} has the messages:", async ({ app }, id: string, table: { hashes: () => Row[] }) => {
  const rows = await app.sql`
    SELECT m.* FROM mail_messages m JOIN mail_threads t ON t.id = m.mail_thread_id
    WHERE t.gmail_id = ${id} ORDER BY m.gmail_id
  `;
  const expected = table.hashes();
  const fields = Object.keys(expected[0] ?? {});
  expect(rows.map((row) => Object.fromEntries(fields.map((field) => [field, shown(row[field])])))).toEqual(
    expected.map((row) => Object.fromEntries(fields.map((field) => [field, escaped(row[field])]))),
  );
});

Given("I note when the Gmail message {string} last changed", async ({ answer, app }, id: string) => {
  const [message] = await app.sql`SELECT updated_at FROM mail_messages WHERE gmail_id = ${id}`;
  mailbox(answer).changed = message.updated_at;
});

Then("the Gmail message {string} has not changed since", async ({ answer, app }, id: string) => {
  const [message] = await app.sql`SELECT updated_at FROM mail_messages WHERE gmail_id = ${id}`;
  expect(message.updated_at).toEqual(mailbox(answer).changed);
});

Then("the Gmail thread {string} keeps a body of {int} letters", async ({ app }, id: string, size: number) => {
  const [row] = await app.sql`
    SELECT length(m.body) AS size FROM mail_messages m JOIN mail_threads t ON t.id = m.mail_thread_id WHERE t.gmail_id = ${id}
  `;
  expect(row.size).toBe(size);
});

Then("the Gmail thread {string} wears the labels {string}", async ({ app }, id: string, names: string) => {
  const rows = await app.sql`
    SELECT l.name FROM mail_thread_labels tl JOIN mail_labels l ON l.id = tl.mail_label_id
    JOIN mail_threads t ON t.id = tl.mail_thread_id WHERE t.gmail_id = ${id} ORDER BY l.name
  `;
  expect(rows.map((row) => row.name)).toEqual(listed(names));
});

Then("the Gmail threads are {string}", async ({ app }, ids: string) => {
  const rows = await app.sql`SELECT gmail_id FROM mail_threads WHERE gmail_id IS NOT NULL ORDER BY gmail_id`;
  expect(rows.map((row) => row.gmail_id)).toEqual(listed(ids));
});

Then("the Gmail attachments are {string}", async ({ app }, files: string) => {
  const rows = await app.sql`SELECT filename, mime_type FROM mail_attachments ORDER BY filename`;
  expect(rows.map((row) => `${row.filename} ${row.mime_type}`)).toEqual(listed(files));
});

Then("the mail sync records the failure {string} saying {string}", async ({ app }, reason: string, message: string) => {
  const [failure] = await app.sql`SELECT * FROM sync_states WHERE kind = 'failure' AND sync = 'mail'`;
  expect([failure?.failure_reason, failure?.failure_message, failure?.failure_count]).toEqual([reason, message, 1]);
});

Then("the mail sync still records the failure {string} once", async ({ app }, reason: string) => {
  const [failure] = await app.sql`SELECT * FROM sync_states WHERE kind = 'failure' AND sync = 'mail'`;
  expect([failure?.failure_reason, failure?.failure_count]).toEqual([reason, 1]);
});

Then("the mail sync records no failure", async ({ app }) => {
  expect(await app.sql`SELECT 1 FROM sync_states WHERE kind = 'failure' AND sync = 'mail'`).toHaveLength(0);
});

Then("Gmail received GET {string} {int} time(s)", ({ stub }, path: string, count: number) => {
  expect(stub.received("GET", gmailPath(path.replace(/^\/users\/me/, "")))).toHaveLength(count);
});

Then(
  "the jobs page lists {string} with {string} in about {int} seconds",
  async ({ page }, job: string, args: string, seconds: number) => {
    await page.goto("/admin/settings/jobs");
    const item = page.locator("#jobs-scheduled .li").filter({ hasText: job }).filter({ hasText: args });
    const at = await item.locator("time").first().getAttribute("datetime");
    expect(Math.abs((new Date(at ?? 0).getTime() - Date.now()) / 1000 - seconds)).toBeLessThan(15);
  },
);

Then("the jobs page lists no {string}", async ({ page }, job: string) => {
  await page.goto("/admin/settings/jobs");
  await expect(page.locator("#jobs-scheduled .li").filter({ hasText: job })).toHaveCount(0);
});
