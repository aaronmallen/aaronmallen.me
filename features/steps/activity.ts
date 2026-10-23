import { expect } from "@playwright/test";
import { fill } from "../support/api.ts";
import type { Http } from "../support/http.ts";
import { Given, Then, When } from "../support/world.ts";

const tables: Record<string, { column: string; join: string; key: string; table: string }> = {
  decision: { column: "title", join: "decision_tags", key: "decision_id", table: "decisions" },
  journal: { column: "body", join: "journal_entry_tags", key: "journal_entry_id", table: "journal_entries" },
  task: { column: "title", join: "task_tags", key: "task_id", table: "tasks" },
};

Given(
  "the {word} {string} carries the private tags {string}",
  async ({ app }, kind: string, name: string, tags: string) => {
    const { column, join, key, table } = tables[kind];
    for (const tag of tags.split(", ")) {
      const [found] = await app.sql`SELECT id FROM tags WHERE name = ${tag} AND scope = 'private'`;
      const id =
        found?.id ??
        (await app.sql`INSERT INTO tags ${app.sql({ color: "mk-green", name: tag, scope: "private" })} RETURNING id`)[0]
          .id;
      await app.sql.unsafe(`INSERT INTO ${join} (${key}, tag_id) SELECT id, ${id} FROM ${table} WHERE ${column} = $1`, [
        name,
      ]);
    }
  },
);

const rows = (http: Http) =>
  JSON.parse(JSON.parse(http.body).result.content[0].text).activity as Record<string, unknown>[];

Then("the activity kinds are {string}", ({ http }, kinds: string) => {
  expect(
    rows(http)
      .map((row) => row.kind)
      .join(", "),
  ).toBe(kinds);
});

Then("the activity kinds, in any order, are {string}", ({ http }, kinds: string) => {
  expect(
    rows(http)
      .map((row) => String(row.kind))
      .sort(),
  ).toEqual(kinds.split(", ").sort());
});

Then("the activity holds no rows", ({ http }) => {
  expect(rows(http)).toEqual([]);
});

Then("the activity holds {int} rows", ({ http }, count: number) => {
  expect(rows(http)).toHaveLength(count);
});

Then("the activity names are:", ({ http }, names: string) => {
  expect(rows(http).map((row) => row.name)).toEqual(JSON.parse(fill(http, names)));
});

Then("the activity names, in any order, are:", ({ http }, names: string) => {
  const sorted = (list: unknown[]) => list.map((item) => JSON.stringify(item)).sort();
  expect(sorted(rows(http).map((row) => row.name))).toEqual(sorted(JSON.parse(fill(http, names))));
});

Then("the activity rows match, in any order:", ({ http }, expected: string) => {
  const wanted = JSON.parse(fill(http, expected)) as Record<string, unknown>[];
  const found = rows(http);
  expect(found).toHaveLength(wanted.length);
  for (const row of wanted) expect(found).toContainEqual(expect.objectContaining(row));
});

Then("the first activity row matches:", ({ http }, expected: string) => {
  expect(rows(http)[0]).toMatchObject(JSON.parse(fill(http, expected)));
});

Then("the first activity row has no {string}", ({ http }, field: string) => {
  expect(rows(http)[0]).not.toHaveProperty(field);
});

Then("every activity kind the feed holds shows", ({ http }) => {
  const kinds = [
    "commit",
    "post",
    "journal",
    "social",
    "task",
    "webmention",
    "project",
    "sprint",
    "suggestion",
    "comment",
    "decision",
    "decision_comment",
    "session",
    "pull_request_opened",
    "pull_request_merged",
    "pull_request_closed",
    "workout",
  ];
  expect([...new Set(rows(http).map((row) => String(row.kind)))].sort()).toEqual(kinds.sort());
});

Then("the summary counts every kind once", ({ http }) => {
  const counted = JSON.parse(JSON.parse(http.body).result.content[0].text).kinds as Record<string, number>;
  expect(Object.values(counted).every((count) => count === 1)).toBe(true);
  expect(Object.keys(counted)).toHaveLength(17);
});

Then("the summary counts {string} and nothing else", ({ http }, counts: string) => {
  const counted = JSON.parse(JSON.parse(http.body).result.content[0].text).kinds as Record<string, number>;
  const wanted = Object.fromEntries(counts.split(", ").map((pair) => [pair.split(" ")[0], Number(pair.split(" ")[1])]));
  expect(Object.fromEntries(Object.entries(counted).filter(([, count]) => count > 0))).toEqual(wanted);
  expect(Object.keys(counted)).toHaveLength(17);
});

Then("the summary's busy months are:", ({ http }, expected: string) => {
  const months = JSON.parse(JSON.parse(http.body).result.content[0].text).months as Record<
    string,
    Record<string, number>
  >;
  const busy = Object.fromEntries(
    Object.entries(months).map(([month, counts]) => [
      month,
      Object.fromEntries(Object.entries(counts).filter(([, count]) => count > 0)),
    ]),
  );
  expect(busy).toEqual(JSON.parse(expected));
  expect(Object.keys(months)).toEqual(Object.keys(JSON.parse(expected)));
});

const chicagoDay = (shift: number) =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(new Date(Date.now() - shift * 86_400_000));

const call = async (
  request: import("@playwright/test").APIRequestContext,
  http: Http,
  token: string | undefined,
  name: string,
  args: Record<string, unknown>,
) => {
  const { rpc } = await import("../support/mcp.ts");
  http.last = await rpc(request, token, "tools/call", { arguments: args, name });
  http.body = await http.last.text();
};

When("I {word} the activity of the last {int} days", async ({ http, request, tokens }, verb: string, days: number) => {
  const name = verb === "read" ? "read_activity" : "summarize_activity";
  await call(request, http, tokens.mcp, name, { from: chicagoDay(days), to: chicagoDay(0) });
});

When(
  "I {word} the activity of the last {int} days with:",
  async ({ http, request, tokens }, verb: string, days: number, extra: string) => {
    const name = verb === "read" ? "read_activity" : "summarize_activity";
    await call(request, http, tokens.mcp, name, { from: chicagoDay(days), to: chicagoDay(0), ...JSON.parse(extra) });
  },
);

When(
  "I {word} the activity from {int} days ago to {int} days ago",
  async ({ http, request, tokens }, verb: string, from: number, to: number) => {
    const name = verb === "read" ? "read_activity" : "summarize_activity";
    await call(request, http, tokens.mcp, name, { from: chicagoDay(from), to: chicagoDay(to) });
  },
);

When(
  "I {word} the activity from {string} to {string}",
  async ({ http, request, tokens }, verb: string, from: string, to: string) => {
    const name = verb === "read" ? "read_activity" : "summarize_activity";
    await call(request, http, tokens.mcp, name, { from, to });
  },
);

When(
  "I read the activity of the last {int} days up to the day it says to carry on from",
  async ({ http, request, tokens }, days: number) => {
    const continueTo = JSON.parse(JSON.parse(http.body).result.content[0].text).continue_to;
    await call(request, http, tokens.mcp, "read_activity", { from: chicagoDay(days), to: continueTo });
  },
);

Then("the activity answer names the window of the last {int} days", ({ http }, days: number) => {
  const answer = JSON.parse(JSON.parse(http.body).result.content[0].text);
  expect([answer.from, answer.to]).toEqual([chicagoDay(days), chicagoDay(0)]);
});

Then("the activity answer carries on from the day {int} days ago", ({ http }, days: number) => {
  expect(JSON.parse(JSON.parse(http.body).result.content[0].text).continue_to).toBe(chicagoDay(days));
});

Then(
  "the activity row of the kind {string} is dated {int} days ago at {string}",
  ({ http }, kind: string, days: number, time: string) => {
    const row = rows(http).find((found) => found.kind === kind);
    expect([row?.date, row?.time]).toEqual([chicagoDay(days), time]);
  },
);

Then("the first activity row is dated today", ({ http }) => {
  expect(rows(http)[0].date).toBe(chicagoDay(0));
});

Given("the whole activity feed happened today", async ({ app }) => {
  const at = (time: string) =>
    app.sql
      .unsafe(
        `SELECT ((now() AT TIME ZONE 'America/Chicago')::date + time '${time}') AT TIME ZONE 'America/Chicago' AS at`,
      )
      .then(([row]) => row.at as Date);
  const [today] = await app.sql`SELECT (now() AT TIME ZONE 'America/Chicago')::date AS day`;
  const [post] = await app.sql`
    INSERT INTO posts ${app.sql({ body: "teh", body_html: "<p>teh</p>", published_at: await at("09:00"), read_time: 1, slug: "feed", status: "published", title: "Feed", webmentions_enabled: true, word_count: 1 })}
    RETURNING id
  `;
  await app.sql`INSERT INTO commits ${app.sql({ branch: "main", commit_date: today.day, commit_time: "09:00", message: "a commit", repo: "aaronmallen/blog", sha: "f".repeat(40) })}`;
  await app.sql`INSERT INTO journal_entries ${app.sql({ body: "A note", body_html: "<p>A note</p>", entry_date: today.day, entry_time: "09:00" })}`;
  const [social] = await app.sql`
    INSERT INTO social_posts (posted_at, status, targets) VALUES (${await at("12:00")}, 'posted', '{mastodon}') RETURNING id
  `;
  await app.sql`INSERT INTO social_post_parts ${app.sql({ body: "Out", position: 1, social_post_id: social.id })}`;
  await app.sql`INSERT INTO webmentions ${app.sql({ post_id: post.id, received_at: await at("08:00"), source_url: "https://203.0.113.5/reply", status: "approved", type: "mention" })}`;
  const [task] =
    await app.sql`INSERT INTO tasks ${app.sql({ completed_at: await at("16:00"), list: "next", position: 1, status: "done", title: "Finished" })} RETURNING id`;
  await app.sql`INSERT INTO task_comments ${app.sql({ body: "A comment", created_at: await at("10:00"), task_id: task.id })}`;
  await app.sql`INSERT INTO work_sessions ${app.sql({ ended_at: await at("10:00"), started_at: await at("09:00"), task_id: task.id })}`;
  const [decision] = await app.sql`INSERT INTO decisions ${app.sql({ problem: "Jobs", title: "Queue" })} RETURNING id`;
  await app.sql`INSERT INTO decision_events ${app.sql({ created_at: await at("11:00"), decision_id: decision.id, kind: "opened" })}`;
  await app.sql`INSERT INTO decision_comments ${app.sql({ body: "Hmm", created_at: await at("11:00"), decision_id: decision.id })}`;
  await app.sql`INSERT INTO projects ${app.sql({ key: "FEED", name: "Feed", visibility: "private" })}`;
  await app.sql`INSERT INTO sprints ${app.sql({ sprint_date: today.day })}`;
  const [suggestion] = await app.sql`INSERT INTO suggestions ${app.sql({ post_id: post.id })} RETURNING id`;
  await app.sql`INSERT INTO suggestion_edits ${app.sql({ original: "teh", position: 1, reason: "typo", replacement: "the", suggestion_id: suggestion.id })}`;
  await app.sql`INSERT INTO pull_requests ${app.sql({ merged_at: await at("10:00"), number: 1, opened_at: await at("08:00"), ready_at: await at("09:00"), repo: "aaronmallen/blog", title: "Merged", url: "https://github.com/aaronmallen/blog/pull/1" })}`;
  await app.sql`INSERT INTO pull_requests ${app.sql({ closed_at: await at("11:00"), number: 2, opened_at: new Date(Date.now() - 40 * 86_400_000), ready_at: new Date(Date.now() - 40 * 86_400_000), repo: "aaronmallen/blog", title: "Closed", url: "https://github.com/aaronmallen/blog/pull/2" })}`;
  await app.sql`INSERT INTO workouts ${app.sql({ google_id: "w-1", kind: "run", minutes: 30, started_at: await at("07:00") })}`;
});
