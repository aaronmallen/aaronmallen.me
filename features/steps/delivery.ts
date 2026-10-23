import { randomBytes } from "node:crypto";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { connect, heardAt, insertSocialPost, json, passwords, records, reseal } from "../support/delivery.ts";
import { insertRows } from "../support/rows.ts";
import { Given, Then, When } from "../support/world.ts";

const mastodonScopes = ["write:statuses", "write:media", "read:accounts", "read:search", "read:statuses"];
const minute = 60_000;

const onSite = (text: string, url: string) => text.replaceAll("{site}", url);

const dueNow = (sql: Parameters<typeof insertSocialPost>[0], targets: string, parts: string[]) =>
  insertSocialPost(sql, { parts, postedAt: new Date(Date.now() - minute), targets });

Given("a Mastodon account on {string} is connected", async ({ app }, host: string) => {
  await connect(app.sql, {
    account_id: host,
    credentials: { access_token: "mastodon-token" },
    host,
    label: `@ada@${host}`,
    provider: "mastodon",
    scopes: mastodonScopes,
  });
});

Given("a Bluesky account {string} is connected", async ({ app }, handle: string) => {
  passwords.set(handle, randomBytes(8).toString("hex"));
  await connect(app.sql, {
    account_id: `did:plc:${handle}`,
    credentials: { app_password: passwords.get(handle), handle },
    label: `@${handle}`,
    provider: "bluesky",
  });
});

Given("a LinkedIn account is connected", async ({ app }) => {
  await connectLinkedIn(app.sql, ["openid", "profile", "w_member_social"]);
});

Given("a LinkedIn account is connected with leave to read the member's posts", async ({ app }) => {
  await connectLinkedIn(app.sql, ["openid", "profile", "w_member_social", "r_member_social"]);
});

Given("a LinkedIn account is connected with leave to read post stats", async ({ app }) => {
  await connectLinkedIn(app.sql, ["openid", "profile", "w_member_social", "r_member_postAnalytics"]);
});

Given("a LinkedIn account is connected whose token lapsed at {string}", async ({ app }, at: string) => {
  await connectLinkedIn(app.sql, ["openid", "profile", "w_member_social"], Date.parse(at) / 1000);
});

function connectLinkedIn(sql: Parameters<typeof connect>[0], scopes: string[], expiresAt = Date.now() / 1000 + 3600) {
  return connect(sql, {
    account_id: "member-ada",
    credentials: { access_token: "linkedin-token", expires_at: Math.floor(expiresAt) },
    label: "Ada Lovelace",
    provider: "linkedin",
    scopes,
  });
}

Given("a social post due now to {string} saying {string}", async ({ app }, targets: string, text: string) => {
  await dueNow(app.sql, targets, [onSite(text, app.url)]);
});

Given("a social post due now to {string} in parts:", async ({ app }, targets: string, parts: DataTable) => {
  await dueNow(app.sql, targets, parts.raw().flat());
});

Given(
  "a social post due now to {string} saying {int} {string}s",
  async ({ app }, targets: string, count: number, letter: string) => {
    await dueNow(app.sql, targets, [letter.repeat(count)]);
  },
);

Given(
  "a social post due now to {string} saying {string} then {int} {string}s",
  async ({ app }, targets: string, first: string, count: number, letter: string) => {
    await dueNow(app.sql, targets, [first, letter.repeat(count)]);
  },
);

Given(
  "a social post due now to {string} with {int} {string}s before {string}",
  async ({ app }, targets: string, count: number, letter: string, tail: string) => {
    await dueNow(app.sql, targets, [`${letter.repeat(count)} ${tail}`]);
  },
);

Given(
  "a social post due now to {string} that fills {int} characters with a link to the site's {string}",
  async ({ app }, targets: string, length: number, path: string) => {
    const url = `${app.url}${path}`;
    await dueNow(app.sql, targets, [`${"a".repeat(length - url.length - 1)} ${url}`]);
  },
);

Given(
  "Bluesky refuses {word} {string} with status {int} and:",
  ({ stub }, method: string, path: string, status: number, body: string) => {
    stub.reply(method, `/bluesky/pds${path}`, { body, status });
  },
);

Given(
  "a social post due now to {string} in {int} parts of {int} letters",
  async ({ app }, targets: string, count: number, length: number) => {
    const parts = Array.from({ length: count }, (_, index) => String.fromCharCode(97 + index).repeat(length));
    await insertSocialPost(app.sql, { parts, postedAt: new Date(Date.now() - minute), targets });
  },
);

Given("social post {int} picked accounts {string}", async ({ app }, id: number, ids: string) => {
  await app.sql`UPDATE social_posts SET connection_ids = ${`{${ids.split(" ").join(",")}}`} WHERE id = ${id}`;
});

Given("social account {int} is disconnected", async ({ app }, id: number) => {
  await app.sql`DELETE FROM service_connections WHERE id = ${id}`;
});

Given("the deliveries of social post {int} are:", async ({ app }, id: number, rows: DataTable) => {
  await insertRows(
    app.sql,
    "social_post_deliveries",
    rows.hashes().map((row) => ({ ...row, social_post_id: String(id) })),
  );
});

When("social post {int} goes out on account {int}", async ({ app }, post: number, account: number) => {
  await app.pushJob("Social::Jobs::DeliverSocialPost", post, account);
});

When("the due social posts go out", async ({ app }) => {
  await app.pushJob("Social::Jobs::SendDueSocialPosts");
});

When("blog post {int} is handed to syndication at {string}", async ({ app }, post: number, at: string) => {
  await app.pushJob("Social::Jobs::SyndicatePost", post, Date.parse(at) / 1000);
});

When("the social counts refresh", async ({ app }) => {
  await app.pushJob("Social::Jobs::RefreshSocialEngagement");
});

let markers = 0;

When("the social jobs have all run", async ({ app }) => {
  const title = `Queue marker ${++markers}`;
  await insertRows(app.sql, "posts", [{ published_at: "1 hour ago", status: "scheduled", title }]);
  await app.pushJob("Posts::Jobs::PublishDuePosts");
  await expect
    .poll(async () => (await app.sql`SELECT status FROM posts WHERE title = ${title}`)[0].status)
    .toBe("published");
  const runs = async () => (await app.sql`SELECT count(*)::int AS count FROM performance_jobs`)[0].count;
  for (let seen = -1, now = await runs(); seen !== now; seen = now, now = await runs()) {
    await new Promise((settled) => setTimeout(settled, 500));
  }
});

When("the social networks stop answering", ({ stub }) => {
  expect(stub.misses(), "requests no Given step set a reply for").toEqual([]);
  stub.reset();
});

Then("the delivery on account {int} holds {int} remote ids", async ({ app }, account: number, count: number) => {
  await expect
    .poll(async () => {
      const [row] = await app.sql`SELECT remote_ids FROM social_post_deliveries WHERE connection_id = ${account}`;
      return row?.remote_ids.length;
    })
    .toBe(count);
});

Then("no delivery error holds {string}", async ({ app }, text: string) => {
  const rows = await app.sql`SELECT error FROM social_post_deliveries WHERE error IS NOT NULL`;
  expect(rows.length).toBeGreaterThan(0);
  for (const { error } of rows) expect(error).not.toContain(text);
});

Then("the delivery error on account {int} holds {string}", async ({ app }, account: number, text: string) => {
  await expect
    .poll(
      async () => {
        const [row] = await app.sql`SELECT error FROM social_post_deliveries WHERE connection_id = ${account}`;
        return row?.error ?? "";
      },
      { timeout: 30_000 },
    )
    .toContain(text);
});

Then("social post {int} reads {string}", async ({ app }, id: number, text: string) => {
  const parts = await app.sql`SELECT body FROM social_post_parts WHERE social_post_id = ${id} ORDER BY position`;
  expect(parts.map(({ body }) => body).join("\n")).toBe(onSite(text, app.url));
});

Then("social post {int} still links to the site's {string} untagged", async ({ app }, id: number, path: string) => {
  const [{ body }] = await app.sql`SELECT body FROM social_post_parts WHERE social_post_id = ${id}`;
  expect(body).toMatch(new RegExp(`${RegExp.escape(`${app.url}${path}`)}$`));
});

Then("social post {int} links to the site's {string}", async ({ app }, id: number, path: string) => {
  const parts = await app.sql`SELECT body FROM social_post_parts WHERE social_post_id = ${id} ORDER BY position`;
  expect(parts.map(({ body }) => body).join("\n")).toBe(`Hello\n\n${app.url}${path}`);
});

Then("the cross-post for blog post {int} went out at {string}", async ({ app }, post: number, at: string) => {
  const rows = await app.sql`SELECT posted_at, status FROM social_posts WHERE post_id = ${post}`;
  expect(rows.map(({ posted_at, status }) => [posted_at.toISOString(), status])).toEqual([
    [new Date(at).toISOString(), "scheduled"],
  ]);
});

Given("Bluesky account {int} reconnects as {string}", async ({ app }, id: number, handle: string) => {
  passwords.set(handle, randomBytes(8).toString("hex"));
  await reseal(app.sql, id, { app_password: passwords.get(handle), handle });
});

Given("the network answers {word} {string} in turn:", ({ stub }, method: string, path: string, replies: string) => {
  for (const [index, { body = "", delay, headers, status = 200 }] of JSON.parse(replies).entries()) {
    const reply = { body: typeof body === "string" ? body : JSON.stringify(body), delay, headers, status };
    if (index === 0) stub.reply(method, path, reply);
    else stub.replyThen(method, path, reply);
  }
});

Given("the photo {string} is {int} by {int}", async ({ app }, key: string, width: number, height: number) => {
  await app.sql`INSERT INTO photos ${app.sql({ byte_size: 100, height, key, width })}`;
});

Given("part {int} of social post {int} shows:", async ({ app }, position: number, post: number, photos: DataTable) => {
  const [{ id }] = await app.sql`
    SELECT id FROM social_post_parts WHERE social_post_id = ${post} AND position = ${position}
  `;
  for (const [index, { alt, key }] of photos.hashes().entries()) {
    const row = { alt_text: alt || null, photo_key: key, position: index + 1, social_post_part_id: id };
    await app.sql`INSERT INTO social_post_photos ${app.sql(row)}`;
  }
});

Given("the media store holds {string}", ({ stub }, key: string) => {
  stub.objects.set(`photos/${key}`, { body: Buffer.from(`photo ${key}`), type: "image/jpeg" });
});

Then("Bluesky record {int} holds:", async ({ app, stub }, index: number, wanted: string) => {
  await expect.poll(() => records(stub)[index - 1]).toMatchObject(JSON.parse(onSite(wanted, app.url)));
});

Then("Bluesky record {int} has no {string}", async ({ stub }, index: number, key: string) => {
  await expect.poll(() => records(stub).length).toBeGreaterThanOrEqual(index);
  expect(records(stub)[index - 1].record).not.toHaveProperty(key);
});

Then("Bluesky wrote {int} record(s), each under a TID key of its own", async ({ stub }, count: number) => {
  await expect.poll(() => records(stub).length).toBe(count);
  const keys = records(stub).map(({ rkey }) => rkey);
  expect(new Set(keys).size).toBe(count);
  for (const key of keys) expect(key).toMatch(/^[2-7a-j][2-7a-z]{12}$/);
});

Then("Bluesky heard the sign-in of {string}", async ({ stub }, handle: string) => {
  await expect
    .poll(() => heardAt(stub, "POST", "/xrpc/com.atproto.server.createSession").map(json))
    .toContainEqual({ identifier: handle, password: passwords.get(handle) });
});

Then("the Bluesky parent lookup asked for {string}", async ({ stub }, uri: string) => {
  const [repo, collection, rkey] = uri.replace("at://", "").split("/");
  await expect
    .poll(() =>
      heardAt(stub, "GET", "/xrpc/com.atproto.repo.getRecord").map(({ url }) => Object.fromEntries(url.searchParams)),
    )
    .toContainEqual({ collection, repo, rkey });
});

Then(
  "the network heard {word} {string} {int} time(s)",
  async ({ stub }, method: string, path: string, count: number) => {
    await expect.poll(() => heardAt(stub, method, path).length).toBe(count);
  },
);

Then(
  "the network heard {word} {string} with the header {string} set to {string}",
  async ({ stub }, method: string, path: string, header: string, value: string) => {
    await expect
      .poll(() => heardAt(stub, method, path).map(({ headers }) => headers[header.toLowerCase()]))
      .toContain(value);
  },
);

Then(
  "the network heard these {word} {string} bodies:",
  async ({ app, stub }, method: string, path: string, rows: DataTable) => {
    const wanted = rows.hashes();
    await expect.poll(() => heardAt(stub, method, path).length).toBeGreaterThanOrEqual(wanted.length);
    const bodies = heardAt(stub, method, path).map(json);
    expect(bodies).toHaveLength(wanted.length);
    wanted.forEach((row, index) => {
      for (const [key, value] of Object.entries(row)) {
        if (value === "absent") expect(bodies[index]).not.toHaveProperty(key);
        else if (value !== "") expect(bodies[index][key]).toEqual(typed(onSite(value, app.url)));
      }
    });
  },
);

function typed(value: string): unknown {
  if (value === "null") return null;
  return value.startsWith("[") || value.startsWith("{") ? JSON.parse(value) : value.replaceAll("\\n", "\n");
}

Given("person {string} now has the Mastodon handle {string}", async ({ app }, key: string, handle: string) => {
  await app.sql`UPDATE people SET mastodon_handle = ${handle} WHERE key = ${key}`;
});

Given("person {string} is gone", async ({ app }, key: string) => {
  await app.sql`DELETE FROM people WHERE key = ${key}`;
});

Then(
  "Bluesky record {int} marks {string} as a {word} facet",
  async ({ app, stub }, index: number, text: string, kind: string) => {
    await expect.poll(() => records(stub).length).toBeGreaterThanOrEqual(index);
    const { record } = records(stub)[index - 1];
    const marked = onSite(text, app.url);
    const at = record.text.indexOf(marked);
    expect(at, `${marked} in ${record.text}`).toBeGreaterThanOrEqual(0);
    const byteStart = Buffer.byteLength(record.text.slice(0, at));
    expect(record.facets).toContainEqual(
      expect.objectContaining({
        features: [expect.objectContaining({ $type: `app.bsky.richtext.facet#${kind}` })],
        index: { byteEnd: byteStart + Buffer.byteLength(marked), byteStart },
      }),
    );
  },
);

Then(
  "the network heard {word} {string} {int} time(s) with the header {string} set to {string}",
  async ({ stub }, method: string, path: string, count: number, header: string, value: string) => {
    await expect
      .poll(() => heardAt(stub, method, path).filter(({ headers }) => headers[header.toLowerCase()] === value).length)
      .toBe(count);
  },
);

Then("Bluesky records {int} and {int} went under the same key", async ({ stub }, one: number, other: number) => {
  await expect.poll(() => records(stub).length).toBeGreaterThanOrEqual(Math.max(one, other));
  expect(records(stub)[one - 1].rkey).toBe(records(stub)[other - 1].rkey);
});

Then("each Bluesky record is stamped with the time it was written", ({ stub }) => {
  expect(records(stub).length).toBeGreaterThan(0);
  for (const { record } of records(stub)) {
    expect(Math.abs(Date.parse(record.createdAt) - Date.now())).toBeLessThan(5 * minute);
  }
});

Then("LinkedIn heard {int} stats reads naming {string}", async ({ stub }, count: number, entity: string) => {
  await expect
    .poll(
      () =>
        heardAt(stub, "GET", "/rest/memberCreatorPostAnalytics").filter(
          ({ url }) => url.searchParams.get("entity") === entity,
        ).length,
    )
    .toBe(count);
});

Then(
  "the network heard {word} {string} number {int} holding {string}",
  async ({ stub }, method: string, path: string, index: number, text: string) => {
    await expect.poll(() => heardAt(stub, method, path)[index - 1]?.body ?? "").toContain(text);
  },
);

Then(
  "the network heard {word} {string} number {int} without {string}",
  async ({ stub }, method: string, path: string, index: number, text: string) => {
    await expect.poll(() => heardAt(stub, method, path).length).toBeGreaterThanOrEqual(index);
    expect(heardAt(stub, method, path)[index - 1].body).not.toContain(text);
  },
);

Then(
  "the network heard {word} {string} number {int} with the header {string} set to {string}",
  async ({ stub }, method: string, path: string, index: number, header: string, value: string) => {
    await expect.poll(() => heardAt(stub, method, path)[index - 1]?.headers[header.toLowerCase()]).toBe(value);
  },
);

const lastRun = async (sql: Parameters<typeof insertSocialPost>[0], job: string) =>
  (await sql`SELECT outcome, error_class FROM performance_jobs WHERE job = ${job} ORDER BY id DESC LIMIT 1`)[0];

Then("the delivery job fails so Sidekiq tries again", async ({ app }) => {
  await expect
    .poll(() => lastRun(app.sql, "Social::Jobs::DeliverSocialPost"), { timeout: 30_000 })
    .toEqual({ error_class: "Social::Jobs::DeliverSocialPost::NetworkUnavailable", outcome: "failed" });
});

Then("the social job {string} finishes without an error", async ({ app }, job: string) => {
  await expect
    .poll(() => lastRun(app.sql, job), { timeout: 30_000 })
    .toEqual({ error_class: null, outcome: "succeeded" });
});

Then("the social job {string} ran {int} time(s)", async ({ app }, job: string, count: number) => {
  await expect
    .poll(async () => (await app.sql`SELECT count(*)::int AS count FROM performance_jobs WHERE job = ${job}`)[0].count)
    .toBe(count);
});
