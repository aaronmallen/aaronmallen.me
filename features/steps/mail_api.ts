import { type APIRequestContext, expect } from "@playwright/test";
import { insertMailMessage, insertMailThread, mailThreadId, tagMailThread } from "../support/mail.ts";
import {
  contactStamp,
  escaped,
  expectShown,
  fill,
  mcpJson,
  mcpText,
  moment,
  settle,
  shown,
  unwrap,
} from "../support/mail_sync.ts";
import { Given, Then, When } from "../support/world.ts";

type Row = Record<string, string>;

async function api(request: APIRequestContext, token: string | undefined, method: string, path: string, body?: string) {
  const response = await request.fetch(`/api/v1${path}`, {
    ...(body && { data: JSON.parse(body) }),
    headers: { Authorization: `Bearer ${token}` },
    method,
  });
  return { body: await response.text(), status: response.status() };
}

async function mcp(request: APIRequestContext, token: string | undefined, name: string, args: string) {
  const response = await request.post("/mcp", {
    data: { id: 1, jsonrpc: "2.0", method: "tools/call", params: { arguments: JSON.parse(args), name } },
    headers: { Accept: "application/json, text/event-stream", Authorization: `Bearer ${token}` },
  });
  return { body: await response.text(), status: response.status() };
}

async function sendContact(request: APIRequestContext, fields: Record<string, string>) {
  const form: Record<string, string> = { "message[stamp]": contactStamp() };
  for (const [name, value] of Object.entries(fields)) form[`message[${name}]`] = value;
  const response = await request.post("/contact", { form, maxRedirects: 0 });
  return { body: await response.text(), status: response.status() };
}

const contact = { body: "About the beacon", reply_to: "ada@example.com", subject: "A question" };

const subjectsOf = (threads: unknown) => (threads as { subject: string }[]).map((thread) => thread.subject).join(", ");

Given("the mail thread {string} arrived {string}", async ({ app }, subject: string, when: string) => {
  const at = await moment(app.sql, when);
  const id = await mailThreadId(app.sql, subject);
  await app.sql`UPDATE mail_threads SET received_at = ${at} WHERE id = ${id}`;
  await app.sql`UPDATE mail_messages SET received_at = ${at} WHERE mail_thread_id = ${id}`;
});

Given("the mail thread {string} snoozes until {string}", async ({ app }, subject: string, when: string) => {
  const at = await moment(app.sql, when);
  await app.sql`UPDATE mail_threads SET snoozed_until = ${at} WHERE id = ${await mailThreadId(app.sql, subject)}`;
});

Given(
  "the mail thread {string} was marked spam {int} minutes ago",
  async ({ app }, subject: string, minutes: number) => {
    await app.sql`
      UPDATE mail_threads SET status = 'spam', marked_spam_at = now() - make_interval(mins => ${minutes})
      WHERE id = ${await mailThreadId(app.sql, subject)}
    `;
  },
);

Given(
  "the mail thread {string} has a later message saying {string}",
  async ({ app }, subject: string, body: string) => {
    const id = await mailThreadId(app.sql, subject);
    const [{ received_at }] = await app.sql`SELECT received_at FROM mail_threads WHERE id = ${id}`;
    await insertMailMessage(app.sql, id, {
      body,
      receivedAt: new Date(received_at.getTime() + 3_600_000),
      replyTo: null,
    });
  },
);

Given("the mail thread {string} carries the tag {string}", async ({ app }, subject: string, name: string) => {
  await tagMailThread(app.sql, await mailThreadId(app.sql, subject), name);
});

Given("{int} other visitors sent mail in the last hour", async ({ app }, count: number) => {
  for (let index = 1; index <= count; index += 1) {
    await insertMailThread(app.sql, { subject: `From visitor ${index}` }, { replyTo: `visitor-${index}@example.com` });
  }
});

Given("the contact mail sent so far arrived {int} minutes ago", async ({ app }, minutes: number) => {
  await app.sql`UPDATE mail_threads SET received_at = now() - make_interval(mins => ${minutes})`;
  await app.sql`UPDATE mail_messages SET received_at = now() - make_interval(mins => ${minutes})`;
});

When(
  "I call the mail API with {word} {string}",
  async ({ answer, app, request, tokens }, method: string, path: string) => {
    Object.assign(answer, await api(request, tokens.api, method, await fill(app.sql, path)));
  },
);

When(
  "I call the mail API with {word} {string} and:",
  async ({ answer, app, request, tokens }, method: string, path: string, body: string) => {
    Object.assign(answer, await api(request, tokens.api, method, await fill(app.sql, path), await fill(app.sql, body)));
  },
);

When(
  "I call the MCP mail tool {string} with:",
  async ({ answer, app, request, tokens }, name: string, args: string) => {
    Object.assign(answer, await mcp(request, tokens.mcp, name, await fill(app.sql, args)));
  },
);

When("the spam reaper runs", async ({ app }) => {
  await settle(app);
});

When("the spam marks age by {int} days", async ({ app }, days: number) => {
  await app.sql`
    UPDATE mail_threads SET marked_spam_at = marked_spam_at - make_interval(days => ${days})
    WHERE marked_spam_at IS NOT NULL
  `;
});

When("the spam marks age by {int} minutes", async ({ app }, minutes: number) => {
  await app.sql`
    UPDATE mail_threads SET marked_spam_at = marked_spam_at - make_interval(mins => ${minutes})
    WHERE marked_spam_at IS NOT NULL
  `;
});

When("a visitor sends the contact form", async ({ answer, request }) => {
  Object.assign(answer, await sendContact(request, contact));
});

When("a visitor sends the contact form from {string}", async ({ answer, request }, replyTo: string) => {
  Object.assign(answer, await sendContact(request, { ...contact, reply_to: replyTo }));
});

When(
  "a visitor sends the contact form from {string} about {string} saying {string}",
  async ({ answer, request }, replyTo: string, subject: string, body: string) => {
    Object.assign(answer, await sendContact(request, { body: escaped(body), reply_to: replyTo, subject }));
  },
);

When(
  "a visitor sends the contact form with a {word} of {int} letters",
  async ({ answer, request }, field: string, size: number) => {
    const value = field === "reply_to" ? `${"a".repeat(size)}@example.com` : "a".repeat(size);
    Object.assign(answer, await sendContact(request, { ...contact, [field]: value }));
  },
);

When(
  "a visitor sends the contact form with a body of {int} lines of nine letters and {string}",
  async ({ answer, request }, lines: number, tail: string) => {
    const body = `${Array.from({ length: lines }, () => "a".repeat(9)).join("\r\n")}${tail}`;
    Object.assign(answer, await sendContact(request, { ...contact, body }));
  },
);

When("two visitors send the contact form while the mail lock is held", async ({ answer, app, request }) => {
  const held = await app.sql.reserve();
  await held`SELECT pg_advisory_lock(hashtext('mail_messages'))`;
  let sent: Promise<{ status: number }>[] = [];
  try {
    sent = [sendContact(request, contact), sendContact(request, contact)];
    await expect
      .poll(async () => {
        const [{ count }] = await app.sql`
          SELECT count(*)::int AS count FROM pg_locks WHERE locktype = 'advisory' AND NOT granted
        `;
        return count;
      })
      .toBe(2);
  } finally {
    await held`SELECT pg_advisory_unlock(hashtext('mail_messages'))`;
    held.release();
  }
  const statuses = (await Promise.all(sent)).map(({ status }) => status).sort();
  Object.assign(answer, { body: statuses.join(", "), status: 0 });
});

Then("the contact form answers with status {int}", ({ answer }, status: number) => {
  expect(answer.status).toBe(status);
});

Then("the contact form answers the two visitors with {string}", ({ answer }, statuses: string) => {
  expect(answer.body).toBe(statuses);
});

Then("the newest mail thread is {word}", async ({ app }, status: string) => {
  const [thread] = await app.sql`SELECT status FROM mail_threads ORDER BY id DESC LIMIT 1`;
  expect(thread.status).toBe(status);
});

Then("{int} mail threads are kept", async ({ app }, count: number) => {
  const [{ total }] = await app.sql`SELECT count(*)::int AS total FROM mail_threads`;
  expect(total).toBe(count);
});

Then("the mail threads kept are {string}", async ({ app }, subjects: string) => {
  const rows = await app.sql`SELECT subject FROM mail_threads ORDER BY id`;
  expect(rows.map((row) => row.subject).join(", ")).toBe(subjects);
});

Then("the contact form stored the message:", async ({ app }, table: { rowsHash: () => Row }) => {
  const [message] = await app.sql`
    SELECT m.reply_to, m.subject, m.body, a.provider, m.visitor_hash IS NOT NULL AS hashed
    FROM mail_messages m JOIN mail_threads t ON t.id = m.mail_thread_id JOIN mail_accounts a ON a.id = t.mail_account_id
    ORDER BY m.id DESC LIMIT 1
  `;
  for (const [field, value] of Object.entries(table.rowsHash())) expect(shown(message[field])).toBe(escaped(value));
});

Then("the mail thread {string} reads:", async ({ app }, subject: string, table: { rowsHash: () => Row }) => {
  const [thread] = await app.sql`SELECT * FROM mail_threads WHERE id = ${await mailThreadId(app.sql, subject)}`;
  for (const [field, value] of Object.entries(table.rowsHash())) expectShown(thread[field], value, field);
});

Then("the API answer lists the mail threads {string}", ({ answer }, subjects: string) => {
  expect(subjectsOf(JSON.parse(answer.body).mail_threads)).toBe(subjects);
});

Then("the MCP answer lists the mail threads {string}", ({ answer }, subjects: string) => {
  expect(subjectsOf(mcpJson(answer.body).mail_threads)).toBe(subjects);
});

Then("the API answer reads:", async ({ answer, app }, json: string) => {
  expect(JSON.parse(answer.body)).toEqual(JSON.parse(await fill(app.sql, json)));
});

Then("the MCP answer reads:", async ({ answer, app }, json: string) => {
  expect(mcpJson(answer.body)).toEqual(JSON.parse(await fill(app.sql, json)));
});

Then("the MCP answer says {string}", ({ answer }, text: string) => {
  expect(mcpText(answer.body)).toBe(text);
});

Then("the MCP answer's {string} is {string}", ({ answer }, path: string, value: string) => {
  expect(JSON.stringify(dig(mcpJson(answer.body), path))).toBe(value);
});

Then("the MCP answer's {string} reads:", async ({ answer, app }, path: string, json: string) => {
  expect(dig(mcpJson(answer.body), path)).toEqual(JSON.parse(await fill(app.sql, json)));
});

function dig(value: unknown, path: string) {
  let found = value;
  for (const key of path.split(".").filter(Boolean)) found = (found as Record<string, unknown>)?.[key];
  return found;
}

Then("the API answer's {string} is {string}", ({ answer }, path: string, value: string) => {
  expect(JSON.stringify(dig(JSON.parse(answer.body), path))).toBe(value);
});

Then("the API answer's {string} reads:", ({ answer }, path: string, json: string) => {
  expect(dig(JSON.parse(answer.body), path)).toEqual(JSON.parse(json));
});

Then(
  "the API {word} {string} and the MCP tool {string} answer alike with:",
  async ({ app, request, tokens }, method: string, path: string, name: string, args: string) => {
    const filled = await fill(app.sql, args);
    const endpoint = await api(
      request,
      tokens.api,
      method,
      await fill(app.sql, path),
      method === "GET" ? undefined : filled,
    );
    const tool = await mcp(request, tokens.mcp, name, filled);

    expect(endpoint.status).toBe(200);
    expect(mcpJson(tool.body)).toEqual(unwrap(JSON.parse(endpoint.body)));
  },
);

Given("{int} old spam mail threads", async ({ app }, count: number) => {
  for (let index = 1; index <= count; index += 1) {
    const receivedAt = new Date(Date.now() - (900 + index) * 86_400_000);
    await insertMailThread(app.sql, { receivedAt, status: "spam", subject: `Old spam ${index}` });
  }
});

Given("the task {string}", async ({ app }, title: string) => {
  const [{ next }] = await app.sql`SELECT coalesce(max(number), 0) + 1 AS next FROM tasks`;
  await app.sql`INSERT INTO tasks ${app.sql({ list: "next", number: next, position: next, title })}`;
});

Given("a webmention on the post {string}", async ({ app }, title: string) => {
  const [post] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  await app.sql`
    INSERT INTO webmentions ${app.sql({ author_name: "Grace Hopper", post_id: post.id, source_url: "http://203.0.113.5/reply", type: "reply" })}
  `;
});

Given("the post {string} is linked to the mail thread {string}", async ({ app }, title: string, subject: string) => {
  const [post] = await app.sql`SELECT id FROM posts WHERE title = ${title}`;
  await app.sql`
    INSERT INTO record_links ${app.sql({
      left_id: post.id,
      left_kind: "post",
      right_id: await mailThreadId(app.sql, subject),
      right_kind: "mail_thread",
    })}
  `;
});

Then("the MCP answer is an error saying {string}", ({ answer }, text: string) => {
  const { result } = JSON.parse(answer.body);
  expect([result.isError, mcpText(answer.body)]).toEqual([true, text]);
});

Then("the MCP answer's {string} lists the kinds {string}", ({ answer }, path: string, kinds: string) => {
  const rows = dig(mcpJson(answer.body), path) as { kind: string }[];
  expect(
    rows
      .map((row) => row.kind)
      .sort()
      .join(", "),
  ).toBe(kinds);
});

Then("the MCP answer lists {int} mail threads, all {word}", ({ answer }, count: number, status: string) => {
  const threads = mcpJson(answer.body).mail_threads as { status: string }[];
  expect([threads.length, [...new Set(threads.map((thread) => thread.status))]]).toEqual([count, [status]]);
});

Then("the MCP answer marks {string} as untrusted", ({ answer }, path: string) => {
  const raw = dig(JSON.parse(mcpText(answer.body)), path) as { untrusted?: boolean };
  expect(raw.untrusted).toBe(true);
});

Then("the MCP answer's {string} has the keys {string}", ({ answer }, path: string, keys: string) => {
  expect(
    Object.keys(dig(mcpJson(answer.body), path) as object)
      .sort()
      .join(", "),
  ).toBe(keys);
});

Then("the mail thread {string} is linked to the task {string}", async ({ app }, subject: string, title: string) => {
  const links = await app.sql`
    SELECT 1 FROM record_links l JOIN tasks t ON t.id = l.left_id
    WHERE l.left_kind = 'task' AND l.right_kind = 'mail_thread' AND t.title = ${title}
      AND l.right_id = ${await mailThreadId(app.sql, subject)}
  `;
  expect(links.length).toBe(1);
});

Then("no record is linked to the mail thread {string}", async ({ app }, subject: string) => {
  const links = await app.sql`
    SELECT 1 FROM record_links WHERE right_kind = 'mail_thread' AND right_id = ${await mailThreadId(app.sql, subject)}
  `;
  expect(links.length).toBe(0);
});

Then("no task is called {string}", async ({ app }, title: string) => {
  expect((await app.sql`SELECT 1 FROM tasks WHERE title = ${title}`).length).toBe(0);
});

Then("Gmail received a draft holding {string}", ({ stub }, text: string) => {
  const raws = [
    ...stub.received("POST", "/google/gmail/users/me/drafts"),
    ...stub.received("PUT", "/google/gmail/users/me/drafts/r1"),
  ].map((body) => Buffer.from(JSON.parse(body).message.raw, "base64url").toString());
  expect(raws.some((raw) => raw.includes(text))).toBe(true);
});
