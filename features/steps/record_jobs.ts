import { randomBytes } from "node:crypto";
import { setTimeout as sleep } from "node:timers/promises";
import { expect } from "@playwright/test";
import type postgres from "postgres";
import type { createClient } from "redis";
import { seal } from "../support/seal.ts";
import type { Stub } from "../support/stub.ts";
import { Before, Given, Then, When } from "../support/world.ts";

type Worker = {
  pushJob: (job: string, ...args: unknown[]) => Promise<void>;
  redis: { client: ReturnType<typeof createClient> };
  sql: postgres.Sql;
};

const walkJob = "Record::Jobs::BackfillRepoCommits";
const walkClock = "2026-08-20T12:00:00Z";
const graphql = "/github/api/graphql";
const noted: { at?: Date; token?: string } = {};

Before(() => {
  noted.at = undefined;
  noted.token = undefined;
});

const refill = JSON.stringify({
  data: {
    rateLimit: { limit: 5000, remaining: 5000, resetAt: "2020-01-01T00:00:00Z" },
    viewer: { repositories: { nodes: [], pageInfo: { endCursor: null, hasNextPage: false } } },
  },
});

const moment = (text: string) => {
  const ago = text.match(/^(\d+) (minute|hour|day)s? ago$/);
  if (!ago) return new Date(text);
  const unit = { day: 86_400_000, hour: 3_600_000, minute: 60_000 }[ago[2] as "day" | "hour" | "minute"];
  return new Date(Date.now() - Number(ago[1]) * unit);
};

const jobRuns = async (sql: postgres.Sql) => (await sql`SELECT count(*)::int AS count FROM performance_jobs`)[0].count;

const idleSince = async (app: Worker, since: number) => {
  const processes = await app.redis.client.sMembers("processes");
  const beats = await Promise.all(processes.map((name) => app.redis.client.hmGet(name, ["busy", "beat"])));
  return beats.length > 0 && beats.every(([busy, beat]) => busy === "0" && Number(beat) * 1000 > since);
};

const settle = async (app: Worker, before: number) => {
  await expect.poll(() => jobRuns(app.sql), { timeout: 30_000 }).toBeGreaterThan(before);
  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    const runs = await jobRuns(app.sql);
    if ((await app.redis.client.lLen("queue:default")) === 0) {
      const since = Date.now();
      await expect.poll(() => idleSince(app, since), { intervals: [500], timeout: 30_000 }).toBe(true);
      if ((await jobRuns(app.sql)) === runs && (await app.redis.client.lLen("queue:default")) === 0) return;
    }
    await sleep(500);
  }
  throw new Error("the record jobs did not settle");
};

type Asked = {
  headers: Record<string, string | string[] | undefined>;
  query?: string;
  variables: Record<string, unknown>;
};

const asked = (stub: Stub, query: string) =>
  stub
    .requests()
    .filter(({ method, url }) => method === "POST" && url.pathname === graphql)
    .map(({ body, headers }): Asked => ({ headers, ...JSON.parse(body.toString() || "{}") }))
    .filter((request) => request.query?.includes(query));

const stamp = (date: Date) => `${date.toISOString().slice(0, 19)}Z`;

const page = (nodes: unknown[], cursor: string | null) => ({
  nodes,
  pageInfo: { endCursor: cursor, hasNextPage: cursor !== null },
});

const tied = (at: string, from: number, count: number) =>
  Array.from({ length: count }, (_, index) => ({
    additions: 1,
    authoredDate: at,
    committedDate: at,
    deletions: 0,
    message: `lib: tied commit ${from + index}`,
    oid: (from + index).toString(16).padStart(40, "0"),
  }));

const tiedAnswer = (branch: string, first: unknown[], rest: unknown[], more: boolean, remaining: number) =>
  JSON.stringify({
    data: {
      rateLimit: { limit: 5000, remaining, resetAt: "2099-01-01T00:00:00Z" },
      repository: {
        createdAt: null,
        defaultBranchRef: { name: branch },
        ref: { target: { history: page(rest, more ? "history-page-3" : null) } },
        refs: page([{ name: branch, target: { history: page(first, `${branch}-page-2`) } }], null),
      },
      viewer: { id: "MDQ6VXNlcjkzMTA5NA==" },
    },
  });

const runJob = async (app: Worker, job: string, ...args: unknown[]) => {
  const before = await jobRuns(app.sql);
  await app.pushJob(job, ...args);
  await settle(app, before);
};

const listening = async (app: Worker, run: () => Promise<void>) => {
  const heard: string[] = [];
  const { unlisten } = await app.sql.listen("admin_changes", (table) => heard.push(table));
  await run();
  await sleep(500);
  await unlisten();
  return heard.join(", ") || "nothing";
};

const holdingLock = async (app: Worker, lock: string, run: () => Promise<void>) => {
  const holder = await app.sql.reserve();
  await holder`SELECT pg_advisory_lock(hashtext(${lock}))`;
  try {
    await run();
  } finally {
    await holder`SELECT pg_advisory_unlock(hashtext(${lock}))`;
    holder.release();
  }
};

const waitingWalks = async (app: Worker) => {
  const entries = await app.redis.client.zRangeWithScores("schedule", 0, -1);
  return entries
    .map(({ score, value }) => ({ ...JSON.parse(value), score }))
    .filter((job: { class: string }) => job.class === walkJob) as { args: string[]; score: number }[];
};

const state = async (sql: postgres.Sql, kind: string, repo: string) =>
  (await sql`SELECT synced_at, updated_at FROM sync_states WHERE kind = ${kind} AND repo = ${repo}`)[0];

const failure = async (sql: postgres.Sql, sync: string, repo: string | null) =>
  (
    await sql`
      SELECT * FROM sync_states
      WHERE kind = 'failure' AND sync = ${sync} AND repo IS NOT DISTINCT FROM ${repo}
    `
  )[0];

const near = (date: Date, target: number, slack: number) =>
  expect(Math.abs(date.getTime() - target)).toBeLessThan(slack);

Given("the record jobs have a GitHub token", async ({ app, stub }) => {
  noted.token = `ghp_${randomBytes(12).toString("hex")}`;
  const credentials = seal(JSON.stringify({ access_token: noted.token }));
  await app.sql`
    INSERT INTO service_connections (provider, account_id, label, credentials, scopes)
    VALUES ('github', '931094', '@aaronmallen', ${credentials}, '{repo}')
  `;
  stub.reply("POST", graphql, { body: refill, status: 200 });
  await runJob(app, "Record::Jobs::ReapSyncStates");
  expect(stub.misses(), "requests no Given step set a reply for").toEqual([]);
  stub.reset();
});

Given("the record jobs lose their GitHub token", async ({ app }) => {
  await app.sql`DELETE FROM service_connections WHERE provider = 'github'`;
});

When("GitHub's points refill for the commit walk", async ({ app, stub }) => {
  stub.reply("POST", graphql, { body: refill, status: 200 });
  await runJob(app, "Record::Jobs::ReapSyncStates");
});

Given(
  "GitHub lists {int} commits on the branch {string} all committed at {string}, and {int} more at that second on the next page",
  ({ stub }, first: number, branch: string, at: string, rest: number) => {
    const body = tiedAnswer(branch, tied(at, 0, first), tied(at, first, rest), false, 4999);
    stub.reply("POST", graphql, { body, status: 200 });
  },
);

Given(
  "GitHub lists {int} commits on the branch {string} all committed at {string}, then {int} more at that second and one at {string}, with {int} points left",
  ({ stub }, first: number, branch: string, at: string, rest: number, older: string, remaining: number) => {
    const body = tiedAnswer(
      branch,
      tied(at, 0, first),
      [...tied(at, first, rest), ...tied(older, first + rest, 1)],
      true,
      remaining,
    );
    stub.reply("POST", graphql, { body, status: 200 });
  },
);

Given("GitHub answers the record jobs next with status {int}", ({ stub }, status: number) => {
  stub.replyThen("POST", graphql, { body: "", status });
});

Given("GitHub lists my repositories over {int} pages", ({ stub }, pages: number) => {
  for (let number = 2; number <= pages + 1; number++) {
    const repositories = page(
      [{ nameWithOwner: "aaronmallen/aaronmallen.me", pushedAt: "2026-08-01T00:00:00Z", viewerPermission: "ADMIN" }],
      `repos-page-${number}`,
    );
    const rateLimit = { limit: 5000, remaining: 999, resetAt: "2099-01-01T00:00:00Z" };
    const body = { data: { rateLimit, viewer: { repositories } } };
    stub.replyThen("POST", graphql, { body: JSON.stringify(body), status: 200 });
  }
});

Given("the commit walk for {string} starts at {string}", async ({ app }, repo: string, at: string) => {
  await app.sql`DELETE FROM sync_states WHERE kind = 'backfill' AND repo = ${repo}`;
  await app.sql`INSERT INTO sync_states ${app.sql({ kind: "backfill", repo, synced_at: moment(at) })}`;
});

Given("the commit walk for {string} last moved {string}", async ({ app }, repo: string, at: string) => {
  await app.sql`UPDATE sync_states SET updated_at = ${moment(at)} WHERE kind = 'backfill' AND repo = ${repo}`;
});

Given("the commit import read {string} through {string}", async ({ app }, repo: string, at: string) => {
  await app.sql`INSERT INTO sync_states ${app.sql({ kind: "commits", repo, synced_at: moment(at) })}`;
});

Given("the commit {string} is already stored on the branch {string}", async ({ app }, sha: string, branch: string) => {
  await app.sql`
    INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
    VALUES (${sha}, 'aaronmallen/aaronmallen.me', ${branch}, 'lib: an older commit', '2026-08-10', '09:30')
  `;
});

Given("the commit import stored a commit {string}", async ({ app }, at: string) => {
  const stamp = moment(at);
  await app.sql`
    INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time, created_at, updated_at)
    VALUES (${randomBytes(20).toString("hex")}, 'aaronmallen/elsewhere', 'main', 'lib: stored before', '2026-08-10',
            '09:30', ${stamp}, ${stamp})
  `;
});

Given("a task came from the GitHub issue {string}", async ({ app }, url: string) => {
  const [task] = await app.sql`
    INSERT INTO tasks (title, list, position) VALUES ('Credit the agent', 'next', 1) RETURNING id
  `;
  await app.sql`
    INSERT INTO task_sources ${app.sql({ provider: "github", remote_id: url, task_id: task.id, url })}
  `;
});

When("the commit walk runs for {string}", async ({ app }, repo: string) => {
  await runJob(app, walkJob, repo, walkClock);
});

When("the commit walk runs for {string} while the admin listens", async ({ app, shell }, repo: string) => {
  shell.output = await listening(app, () => runJob(app, walkJob, repo, walkClock));
});

When("the waiting commit walk comes due", async ({ app }) => {
  const before = await jobRuns(app.sql);
  const entries = await app.redis.client.zRangeWithScores("schedule", 0, -1);
  for (const { value } of entries) await app.redis.client.zAdd("schedule", { score: Date.now() / 1000, value });
  await settle(app, before);
});

When("the commit import runs", async ({ app }) => {
  await runJob(app, "Record::Jobs::ImportCommits");
});

When("the commit import runs while the admin listens", async ({ app, shell }) => {
  shell.output = await listening(app, () => runJob(app, "Record::Jobs::ImportCommits"));
});

When("the commit import runs while another run holds its lock", async ({ app }) => {
  await holdingLock(app, "commit import", () => runJob(app, "Record::Jobs::ImportCommits"));
});

When("the pull request import runs", async ({ app }) => {
  await runJob(app, "Record::Jobs::ImportPullRequests");
});

When("the pull request import runs while the admin listens", async ({ app, shell }) => {
  shell.output = await listening(app, () => runJob(app, "Record::Jobs::ImportPullRequests"));
});

When("the pull request import runs while another run holds its lock", async ({ app }) => {
  await holdingLock(app, "pull request import", () => runJob(app, "Record::Jobs::ImportPullRequests"));
});

When("the sync state reap runs", async ({ app }) => {
  await runJob(app, "Record::Jobs::ReapSyncStates");
});

Then("the commit walk for {string} stands at {string}", async ({ app }, repo: string, at: string) => {
  const found = await state(app.sql, "backfill", repo);

  expect(found).toBeDefined();
  near(found.synced_at, moment(at).getTime(), at.endsWith(" ago") ? 60_000 : 1);
});

Then("the commit walk for {string} stands at about now", async ({ app }, repo: string) => {
  near((await state(app.sql, "backfill", repo)).synced_at, Date.now(), 60_000);
});

Then("the commit walk for {string} last moved just now", async ({ app }, repo: string) => {
  near((await state(app.sql, "backfill", repo)).updated_at, Date.now(), 60_000);
});

Then("the commit walk for {string} has ended", async ({ app }, repo: string) => {
  expect(await state(app.sql, "backfill", repo)).toBeUndefined();
});

Then("the commit import has read {string} through {string}", async ({ app }, repo: string, at: string) => {
  const found = await state(app.sql, "commits", repo);

  expect(found?.synced_at?.toISOString()).toBe(new Date(at).toISOString());
});

Then("the commit import has read {string} through a day ago", async ({ app }, repo: string) => {
  near((await state(app.sql, "commits", repo)).synced_at, Date.now() - 86_400_000, 120_000);
});

Then("the commit import has not read {string}", async ({ app }, repo: string) => {
  expect(await state(app.sql, "commits", repo)).toBeUndefined();
});

Then("the {string} sync records no failure", async ({ app }, sync: string) => {
  expect(await failure(app.sql, sync, null)).toBeUndefined();
});

Then("the {string} sync records no failure for {string}", async ({ app }, sync: string, repo: string) => {
  expect(await failure(app.sql, sync, repo)).toBeUndefined();
});

Then("the {string} sync failure reads {string}", async ({ app }, sync: string, reason: string) => {
  expect((await failure(app.sql, sync, null))?.failure_reason).toBe(reason);
});

Then(
  "the {string} sync failure for {string} reads {string}",
  async ({ app }, sync: string, repo: string, reason: string) => {
    expect((await failure(app.sql, sync, repo))?.failure_reason).toBe(reason);
  },
);

Then("the {string} sync failure says {string}", async ({ app }, sync: string, message: string) => {
  expect((await failure(app.sql, sync, null))?.failure_message).toBe(message);
});

Then(
  "the {string} sync failure for {string} says {string}",
  async ({ app }, sync: string, repo: string, message: string) => {
    expect((await failure(app.sql, sync, repo))?.failure_message).toBe(message);
  },
);

Then("the {string} sync failure leaves out the GitHub token", async ({ app }, sync: string) => {
  const found = await failure(app.sql, sync, null);

  expect(found?.failure_message).toBeTruthy();
  expect(found.failure_message).not.toContain(noted.token);
});

Then("the {string} sync has failed {int} time(s)", async ({ app }, sync: string, count: number) => {
  expect((await failure(app.sql, sync, null))?.failure_count).toBe(count);
});

Then(
  "the {string} sync failure for {string} has failed {int} time(s), starting just now",
  async ({ app }, sync: string, repo: string, count: number) => {
    const found = await failure(app.sql, sync, repo);

    expect(found?.failure_count).toBe(count);
    near(found.failing_since, Date.now(), 60_000);
  },
);

Then(
  "the commit walk for {string} waits in the schedule on the clock {string}",
  async ({ app }, repo: string, clock: string) => {
    expect((await waitingWalks(app)).map(({ args }) => args)).toEqual([[repo, clock]]);
  },
);

Then("the commit walk waits in the schedule until {string}", async ({ app }, at: string) => {
  const walks = await waitingWalks(app);

  expect(walks).toHaveLength(1);
  near(new Date(walks[0].score * 1000), new Date(at).getTime(), 2_000);
});

Then("the commit walk waits in the schedule for about a minute", async ({ app }) => {
  const walks = await waitingWalks(app);

  expect(walks).toHaveLength(1);
  near(new Date(walks[0].score * 1000), Date.now() + 60_000, 30_000);
});

Then("no commit walk waits in the schedule", async ({ app }) => {
  expect(await waitingWalks(app)).toEqual([]);
  expect(await app.redis.client.lLen("queue:default")).toBe(0);
});

Then("the commit walks waiting in the schedule are for {string}", async ({ app }, repos: string) => {
  const walks = await waitingWalks(app);

  expect(walks.map(({ args }) => args[0]).sort()).toEqual(repos ? repos.split(", ").sort() : []);
});

Then("each commit walk waiting in the schedule runs on the import's clock", async ({ app }) => {
  const walks = await waitingWalks(app);

  expect(walks.length).toBeGreaterThan(0);
  for (const { args } of walks) near(new Date(args[1]), Date.now(), 120_000);
});

Then("the record job {string} failed with a {word}", async ({ app }, job: string, error: string) => {
  const rows = await app.sql`SELECT outcome::text, error_class FROM performance_jobs WHERE job = ${job}`;

  expect(rows.map((row) => `${row.outcome} ${row.error_class}`)).toEqual([`failed ${error}`]);
});

When("I note the forward edge for {string}", async ({ app }, repo: string) => {
  noted.at = (await state(app.sql, "commits", repo)).synced_at;
});

When("I note when the pull request import last read", async ({ app }) => {
  noted.at = (await app.sql`SELECT synced_at FROM sync_states WHERE kind = 'pull_requests'`)[0].synced_at;
});

Then("GitHub was asked {int} time(s) for the query {string}", ({ stub }, count: number, query: string) => {
  expect(asked(stub, query)).toHaveLength(count);
});

Then("GitHub was asked for the query {string}", ({ stub }, query: string) => {
  expect(asked(stub, query).length).toBeGreaterThan(0);
});

Then("GitHub was never asked for the query {string}", ({ stub }, query: string) => {
  expect(asked(stub, query)).toEqual([]);
});

Then("GitHub was asked for the query {string} with the variables:", ({ stub }, query: string, json: string) => {
  const variables = asked(stub, query).map((request) => request.variables);

  expect(variables).toContainEqual(expect.objectContaining(JSON.parse(json)));
});

Then("every GraphQL request to GitHub carried the record jobs' token as JSON", ({ stub }) => {
  const requests = asked(stub, "");

  expect(requests.length).toBeGreaterThan(0);
  for (const { headers } of requests) {
    expect(headers.authorization).toBe(`bearer ${noted.token}`);
    expect(headers["content-type"]).toContain("application/json");
  }
});

Then("GitHub was asked for a pull request search holding {string}", ({ stub }, text: string) => {
  const searches = asked(stub, "viewerDidAuthor").map(({ variables }) => String(variables.query));

  expect(
    searches.some((search) => search.includes(text)),
    searches.join("\n"),
  ).toBe(true);
});

Then("GitHub was asked for the commits since the noted forward edge", ({ stub }) => {
  const since = asked(stub, "refs(refPrefix:").map(({ variables }) => variables.since);

  expect(since).toContain(stamp(noted.at ?? new Date(Number.NaN)));
});

Then("GitHub was asked for pull requests updated since a day before the noted read", ({ stub }) => {
  const from = stamp(new Date((noted.at ?? new Date(Number.NaN)).getTime() - 86_400_000));
  const searches = asked(stub, "viewerDidAuthor").map(({ variables }) => String(variables.query));

  expect(
    searches.some((search) => search.includes(`updated:${from}..`)),
    searches.join("\n"),
  ).toBe(true);
});

Then(
  "the {string} sync failure says something starting with {string}",
  async ({ app }, sync: string, start: string) => {
    const message = String((await failure(app.sql, sync, null))?.failure_message);

    expect(message.startsWith(start), message).toBe(true);
  },
);
