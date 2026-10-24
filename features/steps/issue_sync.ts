import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { filled } from "../support/api.ts";
import { connectGitHub } from "../support/commits.ts";
import {
  comment,
  github,
  issue,
  linear,
  linearChildren,
  linearComment,
  linearIssue,
  linearQueries,
  linearWorkspace,
  lookups,
  searches,
} from "../support/issue_sync.ts";
import { settle } from "../support/mail_sync.ts";
import { seal } from "../support/seal.ts";
import { insertTask, projectId, tagId } from "../support/tasks.ts";
import { After, Given, Then, When } from "../support/world.ts";
import { send } from "./api.ts";

const linearUrl = (row: Record<string, string>) =>
  `https://linear.app/${row.workspace || "aaronmallen"}/issue/${(row.key || "ABC-1").toLowerCase()}/sync-my-issues`;

const minutesAgo = (text: string) => new Date(Date.now() - Number(text) * 60_000).toISOString();

const issueUrl = (row: Record<string, string>) =>
  `https://github.com/${row.repo || "aaronmallen/aaronmallen.me"}/issues/${row.number || 7}`;

async function taskFor(sql: postgres.Sql, remote: string) {
  const [found] = await sql`SELECT task_id FROM task_sources WHERE remote_id = ${remote}`;
  return found?.task_id as number | undefined;
}

Given("GitHub holds a token for the issue sync", async ({ answer, app }) => {
  await connectGitHub(app.sql);
  github(app.stub, answer);
});

Given("GitHub assigns me the issues:", ({ answer, app }, table: DataTable) => {
  github(app.stub, answer).assigned = table.hashes().map(issue);
});

Given("GitHub assigns me {int} issues", ({ answer, app }, count: number) => {
  github(app.stub, answer).assigned = Array.from({ length: count }, (_, at) => issue({ number: String(at + 1) }));
});

Given("GitHub assigns me no issues", ({ answer, app }) => {
  github(app.stub, answer).assigned = [];
});

Given("GitHub knows the issues:", ({ answer, app }, table: DataTable) => {
  github(app.stub, answer).known = table.hashes().map(issue);
});

Given("GitHub's search keeps sending the same next page", ({ answer, app }) => {
  const fake = github(app.stub, answer);
  fake.stuckCursor = true;
  fake.assigned = [issue({ number: "1" })];
});

Given("GitHub's search answers {int} issues a page", ({ answer, app }, size: number) => {
  github(app.stub, answer).pageSize = size;
});

Given("the GitHub issue {string} has the comments:", ({ answer, app }, id: string, table: DataTable) => {
  const fake = github(app.stub, answer);
  const found = [...fake.assigned, ...fake.known].filter((node) => node.id === id);
  const comments = table.hashes().map((row) =>
    comment(row.id, {
      author: row.author === "none" ? null : { login: row.author || "octocat" },
      body: JSON.parse(`"${row.body || "Looks good"}"`),
      ...(row.at && { createdAt: row.at }),
    }),
  );
  for (const node of found) (node.comments as { nodes: unknown[] }).nodes = comments;
});

Given("GitHub {word} the next issue {word} with:", ({ answer, app }, _verb: string, kind: string, json: string) => {
  const fake = github(app.stub, answer);
  const reply = { body: json, status: 200 };
  (kind === "search" ? fake.searchReplies : fake.lookupReplies).push(reply);
});

Given("GitHub rate limits the next issue {word}", ({ answer, app }, kind: string) => {
  const fake = github(app.stub, answer);
  const reply = { body: "", headers: { "X-RateLimit-Remaining": "0" }, status: 403 };
  (kind === "search" ? fake.searchReplies : fake.lookupReplies).push(reply);
});

Given("GitHub answers the next issue lookup with status {int}", ({ answer, app }, status: number) => {
  github(app.stub, answer).lookupReplies.push({ body: "", status });
});

Given("GitHub cannot find the issues it is asked to look up", ({ answer, app }) => {
  const fake = github(app.stub, answer);
  fake.lookupReplies.push(...Array(5).fill("missing"));
});

Given("GitHub answers the REST path {string} with status {int}", ({ answer, app }, path: string, status: number) => {
  github(app.stub, answer).rest[path] = { body: status < 300 ? "{}" : '{"message":"gone"}', status };
});

Given("GitHub answers the REST path {string} with:", ({ answer, app }, path: string, json: string) => {
  github(app.stub, answer).rest[path] = { body: json, status: 200 };
});

Given("GitHub moves the REST path {string} to {string}", ({ answer, app }, path: string, to: string) => {
  github(app.stub, answer).rest[path] = {
    body: "",
    headers: { Location: to.replace("{stub}", app.stub.url) },
    status: 301,
  };
});

Given("{int} tasks tracking GitHub issues", async ({ app }, count: number) => {
  for (let at = 1; at <= count; at += 1) {
    const id = await insertTask(app.sql, { list: "external", title: `Tracked ${at}` });
    await app.sql`
      INSERT INTO task_sources ${app.sql({
        provider: "github",
        remote_id: `I_${at}`,
        task_id: id,
        url: `https://github.com/aaronmallen/aaronmallen.me/issues/${at}`,
      })}
    `;
  }
});

Given("the task {string} is deleted while GitHub's search runs", ({ answer, app }, title: string) => {
  github(app.stub, answer).duringSearch = async () => {
    await app.sql`DELETE FROM tasks WHERE title = ${title}`;
  };
});

// Each row is a task already tracking an issue: title, issue (its remote ID, I_7 by default), number, repo,
// status, state (the source's remote state), checked (minutes ago), note, provider and url.
Given("the tasks tracking issues:", async ({ app }, table: DataTable) => {
  for (const row of table.hashes()) {
    const id = await insertTask(app.sql, {
      list: "external",
      note: row.note ?? "Keep them in step",
      status: row.status || "open",
      title: row.title || "Sync my issues",
    });
    await app.sql`UPDATE tasks SET updated_at = now() - interval '1 hour' WHERE id = ${id}`;
    await app.sql`
      INSERT INTO task_sources ${app.sql({
        checked_at: row.checked ? new Date(Date.now() - Number(row.checked) * 60_000) : null,
        history_cursor: row.cursor ? new Date(Date.now() - Number(row.cursor) * 60_000) : null,
        provider: row.provider || "github",
        remote_id: row.issue || `I_${row.number || 7}`,
        remote_state: row.state || "open",
        task_id: id,
        url: row.url || (row.provider === "linear" ? linearUrl(row) : issueUrl(row)),
      })}
    `;
  }
});

Given("the task {string} holds my comment {string}", async ({ app }, title: string, body: string) => {
  await app.sql`
    INSERT INTO task_comments (task_id, body) SELECT id, ${body} FROM tasks WHERE title = ${title}
  `;
});

Given("the task {string} holds the synced comment {string}", async ({ app }, title: string, remote: string) => {
  await app.sql`
    INSERT INTO task_comments (task_id, body, provider, remote_id, url, author)
    SELECT id, 'Looks good', 'github', ${remote}, ${`https://github.com/aaronmallen/aaronmallen.me/issues/7#${remote}`},
      'octocat'
    FROM tasks WHERE title = ${title}
  `;
});

Given("the private tags {string}", async ({ app }, names: string) => {
  for (const name of names.split(", ")) await tagId(app.sql, name);
});

Given("the project {string} holds the tag {string}", async ({ app }, project: string, name: string) => {
  await tagId(app.sql, name, await projectId(app.sql, project));
});

let held: postgres.ReservedSql | undefined;

After(async () => {
  if (!held) return;
  await held`SELECT pg_advisory_unlock_all()`;
  held.release();
  held = undefined;
});

Given("another run holds the {word} issue sync lock", async ({ app }, provider: string) => {
  held = await app.sql.reserve();
  await held`SELECT pg_try_advisory_lock(hashtext(${`${provider.toLowerCase()} issue sync`}))`;
});

When("the GitHub issue sync runs", async ({ app }) => {
  await app.pushJob("Tasks::Jobs::SyncIssues", "github");
  await settle(app);
});

When("the queued issue syncs run", async ({ app }) => {
  await settle(app);
});

When("the GitHub issue sync runs twice", async ({ app }) => {
  for (const _ of [1, 2]) {
    await app.pushJob("Tasks::Jobs::SyncIssues", "github");
    await settle(app);
  }
});

Then("the task from the issue {string} reads:", async ({ app }, remote: string, table: DataTable) => {
  const id = await taskFor(app.sql, remote);
  expect(id, `a task for ${remote}`).toBeTruthy();
  const [row] = await app.sql`
    SELECT tasks.title, tasks.note, tasks.status::text, coalesce(tasks.list::text, '') AS list,
      coalesce(to_char(sprints.sprint_date, 'YYYY-MM-DD'), '') AS sprint, coalesce(projects.name, '') AS project,
      task_sources.url, task_sources.remote_state::text AS state, task_sources.seen_at IS NOT NULL AS seen,
      coalesce((SELECT string_agg(tags.name || CASE WHEN tags.scope = 'project' THEN '@' || p.key ELSE '' END, ', '
        ORDER BY tags.name) FROM task_tags JOIN tags ON tags.id = tag_id LEFT JOIN projects p ON p.id = tags.project_id
        WHERE task_id = tasks.id), '') AS tags,
      tasks.completed_at IS NOT NULL AS completed, tasks.updated_at > now() - interval '30 minutes' AS touched
    FROM tasks JOIN task_sources ON task_id = tasks.id LEFT JOIN sprints ON sprints.id = sprint_id
      LEFT JOIN projects ON projects.id = tasks.project_id
    WHERE tasks.id = ${id}
  `;
  for (const [key, wanted] of Object.entries(table.rowsHash())) {
    expect(String(row[key]), key).toBe(await filled(app.sql, wanted));
  }
});

Then("no task comes from the issue {string}", async ({ app }, remote: string) => {
  expect(await taskFor(app.sql, remote)).toBeUndefined();
});

Then("the synced issues are {string}", async ({ app }, remotes: string) => {
  const rows = await app.sql`SELECT remote_id FROM task_sources ORDER BY remote_id`;
  expect(rows.map((row) => row.remote_id).join(", ")).toBe(remotes);
});

Then("{int} tasks come from GitHub", async ({ app }, count: number) => {
  const [{ found }] = await app.sql`SELECT count(*)::int AS found FROM task_sources WHERE provider = 'github'`;
  expect(found).toBe(count);
});

Then("the task from the issue {string} holds the comments:", async ({ app }, remote: string, table: DataTable) => {
  const rows = await app.sql`
    SELECT coalesce(remote_id, 'mine') AS id, coalesce(author, 'none') AS author, body,
      coalesce(to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') AS at, coalesce(url, '') AS url
    FROM task_comments WHERE task_id = ${(await taskFor(app.sql, remote)) ?? 0} ORDER BY created_at, id
  `;
  const columns = table.raw()[0];
  expect(rows.map((row) => columns.map((column) => String(row[column])))).toEqual(table.raw().slice(1));
});

Then("the task from the issue {string} holds no comments", async ({ app }, remote: string) => {
  const rows = await app.sql`SELECT id FROM task_comments WHERE task_id = ${(await taskFor(app.sql, remote)) ?? 0}`;
  expect(rows).toHaveLength(0);
});

Then("{int} task comment(s) are stored", async ({ app }, count: number) => {
  const [{ found }] = await app.sql`SELECT count(*)::int AS found FROM task_comments`;
  expect(found).toBe(count);
});

Then("the task links read {string}", async ({ app }, links: string) => {
  const rows = await app.sql`
    SELECT coalesce(f.remote_id, ft.title) || ' ' || type || ' ' || coalesce(t.remote_id, tt.title) ||
      CASE WHEN synced THEN ' synced' ELSE '' END AS line
    FROM task_links JOIN tasks ft ON ft.id = from_task_id JOIN tasks tt ON tt.id = to_task_id
      LEFT JOIN task_sources f ON f.task_id = from_task_id LEFT JOIN task_sources t ON t.task_id = to_task_id
    ORDER BY line
  `;
  expect(rows.map((row) => row.line).join(" | ")).toBe(links);
});

Then("the task events from the issue {string} read {string}", async ({ app }, remote: string, events: string) => {
  const rows = await app.sql`
    SELECT kind || coalesce(' ' || tag_name, '') AS line FROM task_events
    WHERE task_id = ${(await taskFor(app.sql, remote)) ?? 0} ORDER BY line
  `;
  expect(rows.map((row) => row.line).join(", ")).toBe(events);
});

Then("the {word} issue sync records no failure", async ({ app }, name: string) => {
  const rows = await app.sql`
    SELECT failure_reason FROM sync_states WHERE sync = ${name === "Linear" ? "linear_issues" : "issues"}
      AND failure_reason IS NOT NULL
  `;
  expect(rows).toHaveLength(0);
});

Then("the {word} issue sync records the failure {string}", async ({ app }, name: string, reason: string) => {
  const rows = await app.sql`
    SELECT failure_reason, coalesce(failure_message, '') AS message FROM sync_states
    WHERE sync = ${name === "Linear" ? "linear_issues" : "issues"} AND failure_reason IS NOT NULL
  `;
  expect(rows.map((row) => row.failure_reason)).toEqual([reason]);
});

Then("the {word} issue sync failure message holds {string}", async ({ app }, name: string, text: string) => {
  const [row] = await app.sql`
    SELECT failure_message FROM sync_states WHERE sync = ${name === "Linear" ? "linear_issues" : "issues"}
  `;
  expect(row?.failure_message ?? "").toContain(text);
});

Then("GitHub was searched {int} time(s)", ({ app }, count: number) => {
  expect(searches(app.stub)).toHaveLength(count);
});

Then("GitHub was asked to look up issues {int} time(s)", ({ app }, count: number) => {
  expect(lookups(app.stub)).toHaveLength(count);
});

Then("GitHub's issue search asked for {string}", ({ app }, text: string) => {
  expect(searches(app.stub).some((body) => JSON.parse(body).query.includes(text))).toBe(true);
});

Then("GitHub's issue lookup asked for {string}", ({ app }, fields: string) => {
  const asked = lookups(app.stub).map((body) => JSON.parse(body).query as string);
  expect(asked.some((query) => fields.split(", ").every((field) => query.includes(field)))).toBe(true);
});

Then("no GitHub query asked for {string}", ({ app }, text: string) => {
  expect(app.stub.received("POST", "/github/api/graphql").some((body) => body.includes(text))).toBe(false);
});

Then("GitHub was asked {int} time(s) for {string}", ({ app }, count: number, path: string) => {
  expect(app.stub.received("GET", `/github/api/repos/${path}`)).toHaveLength(count);
});

Then("GitHub was asked nothing", ({ app }) => {
  expect(app.stub.requests().filter((sent) => sent.url.pathname.startsWith("/github/api"))).toHaveLength(0);
});

Then("the source of the task from the issue {string} was checked just now", async ({ app }, remote: string) => {
  const [row] =
    await app.sql`SELECT checked_at > now() - interval '1 minute' AS fresh FROM task_sources WHERE remote_id = ${remote}`;
  expect(row.fresh).toBe(true);
});

// Saves each rule through the API, as the admin would: pattern, tags (comma list), projects (names) and provider.
Given("the saved task rules:", async ({ answer, app, http, request, tokens }, table: DataTable) => {
  for (const row of table.hashes()) {
    const projects = [];
    for (const name of (row.projects ?? "").split(", ").filter(Boolean)) projects.push(await projectId(app.sql, name));
    const body = {
      pattern: row.pattern,
      projects,
      provider: row.provider || "github",
      tags: (row.tags ?? "").split(", ").filter(Boolean),
    };
    await send({ app, http, request, tokens }, "POST", "/task_rules", JSON.stringify(body));
    expect(answer.status, answer.body).toBe(201);
  }
});

Then("GitHub looked up the issue {string} {int} time(s)", ({ app }, id: string, count: number) => {
  const asked = lookups(app.stub).filter((body) => (JSON.parse(body).variables.ids as string[]).includes(id));
  expect(asked).toHaveLength(count);
});

Given("Linear holds the keys {string}", async ({ answer, app }, keys: string) => {
  const fake = linear(app.stub, answer);
  for (const key of keys.split(", ").filter(Boolean)) {
    linearWorkspace(fake, key);
    await app.sql`
      INSERT INTO service_connections ${app.sql({
        account_id: key,
        credentials: seal(JSON.stringify({ api_key: key })),
        label: key,
        provider: "linear",
        scopes: [],
      })}
    `;
  }
});

Given("Linear holds no keys", ({ answer, app }) => {
  linear(app.stub, answer);
});

// Rows may name the key of the workspace that holds the issue under "in"; lin_api_one when left out.
Given("Linear assigns me the issues:", ({ answer, app }, table: DataTable) => {
  const fake = linear(app.stub, answer);
  for (const workspace of Object.values(fake.workspaces)) workspace.assigned = [];
  for (const row of table.hashes()) linearWorkspace(fake, row.in || undefined).assigned.push(linearIssue(row));
});

Given("Linear knows the issues:", ({ answer, app }, table: DataTable) => {
  const fake = linear(app.stub, answer);
  for (const workspace of Object.values(fake.workspaces)) workspace.known = [];
  for (const row of table.hashes()) linearWorkspace(fake, row.in || undefined).known.push(linearIssue(row));
});

Given("Linear answers lookups in the workspace {string}", ({ answer, app }, urlKey: string) => {
  linearWorkspace(linear(app.stub, answer)).urlKey = urlKey;
});

Given("the Linear issue {string} has the comments:", ({ answer, app }, id: string, table: DataTable) => {
  const fake = linear(app.stub, answer);
  const comments = table.hashes().map((row) =>
    linearComment(row.id, {
      body: row.body || "Looks good",
      user: row.author === "none" ? null : { displayName: row.author || "aaron" },
      ...(row.ago && { createdAt: minutesAgo(row.ago) }),
    }),
  );
  for (const workspace of Object.values(fake.workspaces)) {
    for (const node of [...workspace.assigned, ...workspace.known].filter((found) => found.id === id)) {
      (node.comments as { nodes: unknown[] }).nodes = comments;
    }
  }
});

Given("the Linear issue {string} cuts its comments short", ({ answer, app }, id: string) => {
  for (const workspace of Object.values(linear(app.stub, answer).workspaces)) {
    for (const node of [...workspace.assigned, ...workspace.known].filter((found) => found.id === id)) {
      (node.comments as { pageInfo: unknown }).pageInfo = { hasNextPage: true };
    }
  }
});

// Each row is one state change: from, to and when, in minutes ago. The issue's updatedAt becomes the latest change.
Given("Linear's history of {string} holds:", ({ answer, app }, id: string, table: DataTable) => {
  const fake = linear(app.stub, answer);
  const changes = table.hashes().map((row) => ({
    createdAt: minutesAgo(row.ago),
    fromState: row.from ? { type: row.from } : null,
    toState: row.to ? { type: row.to } : null,
  }));
  fake.history[id] = changes;
  const latest = changes
    .map((change) => change.createdAt)
    .sort()
    .at(-1);
  for (const workspace of Object.values(fake.workspaces)) {
    for (const node of [...workspace.assigned, ...workspace.known].filter((found) => found.id === id)) {
      if (latest) node.updatedAt = latest;
    }
  }
});

Given("Linear's issue {string} changed {int} minutes ago", ({ answer, app }, id: string, ago: number) => {
  for (const workspace of Object.values(linear(app.stub, answer).workspaces)) {
    for (const node of [...workspace.assigned, ...workspace.known].filter((found) => found.id === id)) {
      node.updatedAt = minutesAgo(String(ago));
    }
  }
});

Given(
  "Linear holds the children {string} of {string} on their own",
  ({ answer, app }, children: string, id: string) => {
    linear(app.stub, answer).alone[id] = {
      children: linearChildren(children),
      inverseRelations: { nodes: [], pageInfo: { hasNextPage: false } },
      parent: null,
      relations: { nodes: [], pageInfo: { hasNextPage: false } },
    };
  },
);

Given("Linear answers the next {word} query with status {int}", ({ answer, app }, kind: string, status: number) => {
  const fake = linear(app.stub, answer);
  (kind === "assigned" ? fake.assignedReplies : fake.lookupReplies).push({ body: "", status });
});

Given("Linear answers the next {word} query with:", ({ answer, app }, kind: string, json: string) => {
  const fake = linear(app.stub, answer);
  (kind === "assigned" ? fake.assignedReplies : fake.lookupReplies).push({ body: json, status: 200 });
});

Given("Linear drops the next {word} query", ({ answer, app }, kind: string) => {
  const fake = linear(app.stub, answer);
  (kind === "assigned" ? fake.assignedReplies : fake.lookupReplies).push({ body: "", drop: true, status: 0 });
});

Given(
  "Linear refuses the next assigned query with {string} saying {string}",
  ({ answer, app }, code: string, message: string) => {
    linear(app.stub, answer).assignedReplies.push({
      body: JSON.stringify({ errors: [{ extensions: { code }, message }] }),
      status: 400,
    });
  },
);

When("the Linear issue sync runs", async ({ app }) => {
  await app.pushJob("Tasks::Jobs::SyncIssues", "linear");
  await settle(app);
});

When("the Linear issue sync runs twice", async ({ app }) => {
  for (const _ of [1, 2]) {
    await app.pushJob("Tasks::Jobs::SyncIssues", "linear");
    await settle(app);
  }
});

Then("Linear was sent {int} queries holding {string}", ({ app }, count: number, text: string) => {
  expect(linearQueries(app.stub, text)).toHaveLength(count);
});

Then("Linear was sent a query holding {string}", ({ app }, text: string) => {
  expect(linearQueries(app.stub, text).length).toBeGreaterThan(0);
});

Then("Linear was sent a query holding {string} with the key {string}", ({ app }, text: string, key: string) => {
  const sent = linearQueries(app.stub, text).filter((request) => request.headers.authorization === key);
  expect(sent.length).toBeGreaterThan(0);
});

Then("Linear was asked to look up {string} with the key {string}", ({ app }, ids: string, key: string) => {
  const sent = linearQueries(app.stub, "issues(first:").filter(
    (request) =>
      request.headers.authorization === key &&
      !request.body.toString().includes("history(first:") &&
      JSON.stringify(JSON.parse(request.body.toString()).variables.ids) === JSON.stringify(ids.split(", ")),
  );
  expect(sent.length).toBeGreaterThan(0);
});

Then("Linear was asked to look up issues {int} time(s)", ({ app }, count: number) => {
  const sent = linearQueries(app.stub, "issues(first:").filter(
    (request) => !request.body.toString().includes("history(first:"),
  );
  expect(sent).toHaveLength(count);
});

Then("Linear was asked nothing", ({ app }) => {
  expect(linearQueries(app.stub, "")).toHaveLength(0);
});

Then(
  "the work sessions of the task from the issue {string} read {string}",
  async ({ app }, remote: string, spans: string) => {
    const rows = await app.sql`
    SELECT round(extract(epoch FROM now() - started_at) / 60)::int AS began,
      CASE WHEN ended_at IS NULL THEN 'open' ELSE round(extract(epoch FROM now() - ended_at) / 60)::int::text END AS ended
    FROM work_sessions WHERE task_id = ${(await taskFor(app.sql, remote)) ?? 0} ORDER BY started_at
  `;
    expect(rows.map((row) => `${row.began} to ${row.ended}`).join(", ")).toBe(spans);
  },
);

Given("the task {string} has a work session from {int} minutes ago", async ({ app }, title: string, ago: number) => {
  await app.sql`
    INSERT INTO work_sessions (task_id, started_at)
    SELECT id, now() - ${`${ago} minutes`}::interval FROM tasks WHERE title = ${title}
  `;
});

Given(
  "the task {string} has a work session from {int} to {int} minutes ago",
  async ({ app }, title: string, from: number, to: number) => {
    await app.sql`
      INSERT INTO work_sessions (task_id, started_at, ended_at)
      SELECT id, now() - ${`${from} minutes`}::interval, now() - ${`${to} minutes`}::interval FROM tasks WHERE title = ${title}
    `;
  },
);

Then(
  "the status changes of the task from the issue {string} read {string}",
  async ({ app }, remote: string, text: string) => {
    const rows = await app.sql`
    SELECT from_status || ' to ' || to_status AS line, occurred_at > now() - interval '1 minute' AS fresh
    FROM task_events WHERE kind = 'status_changed' AND task_id = ${(await taskFor(app.sql, remote)) ?? 0} ORDER BY id
  `;
    expect(rows.map((row) => row.line).join(", ")).toBe(text);
    expect(rows.every((row) => row.fresh)).toBe(true);
  },
);

Then("the task from the issue {string} comes first", async ({ app }, remote: string) => {
  const [first] = await app.sql`SELECT id FROM tasks ORDER BY position, id LIMIT 1`;
  expect(first.id).toBe(await taskFor(app.sql, remote));
});

Then(
  "the history cursor of the issue {string} sits {int} minutes ago",
  async ({ app }, remote: string, ago: number) => {
    const [row] = await app.sql`
    SELECT round(extract(epoch FROM now() - history_cursor) / 60)::int AS ago FROM task_sources WHERE remote_id = ${remote}
  `;
    expect(row.ago).toBe(ago);
  },
);

Given("{int} tasks tracking Linear issues", async ({ app }, count: number) => {
  for (let at = 1; at <= count; at += 1) {
    const id = await insertTask(app.sql, { list: "external", title: `Tracked ${at}` });
    await app.sql`
      INSERT INTO task_sources ${app.sql({
        provider: "linear",
        remote_id: `L_${at}`,
        task_id: id,
        url: `https://linear.app/aaronmallen/issue/abc-${at}/sync-my-issues`,
      })}
    `;
  }
});

When(
  "a task is captured through the API and the Linear sync imports while another session holds the task lock",
  async ({ app, request, tokens }) => {
    const holder = await app.sql.reserve();
    try {
      await holder`SELECT pg_advisory_lock(hashtext('tasks'))`;
      const captured = request.post("/api/v1/tasks", {
        data: { title: "Captured" },
        headers: { Authorization: `Bearer ${tokens.api}` },
      });
      await app.pushJob("Tasks::Jobs::SyncIssues", "linear");
      await expect
        .poll(
          async () =>
            (await app.sql`SELECT count(*)::int AS n FROM pg_stat_activity WHERE wait_event_type = 'Lock'`)[0].n,
        )
        .toBe(2);
      await holder`SELECT pg_advisory_unlock(hashtext('tasks'))`;
      expect((await captured).status()).toBe(201);
      await settle(app);
    } finally {
      holder.release();
    }
  },
);

Given("Linear assigns me {int} issues {int} a page", ({ answer, app }, count: number, size: number) => {
  const fake = linear(app.stub, answer);
  fake.pageSize = size;
  linearWorkspace(fake).assigned = Array.from({ length: count }, (_, at) => linearIssue({ key: `ABC-${at + 1}` }));
});

Given("Linear's assigned query keeps sending the same next page", ({ answer, app }) => {
  const fake = linear(app.stub, answer);
  fake.stuckCursor = true;
  linearWorkspace(fake).assigned = [linearIssue({ key: "ABC-1" })];
});

Given("the task {string} is deleted while Linear's assigned query runs", ({ answer, app }, title: string) => {
  linear(app.stub, answer).duringAssigned = async () => {
    await app.sql`DELETE FROM tasks WHERE title = ${title}`;
  };
});
