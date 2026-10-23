import { createHash, randomBytes } from "node:crypto";
import { type APIRequestContext, expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import type postgres from "postgres";
import { answer, callApi, fill, keep, recall } from "../support/api.ts";
import type { Http } from "../support/http.ts";
import { literal } from "../support/sql.ts";
import { Given, Then, When } from "../support/world.ts";

const author = { agent: "claude-code", model: "claude-opus-5-5" };

const inSession = (http: Http) => {
  const session = recall(http, "session");
  return session ? { session_id: session } : {};
};
const agentTokens = new WeakMap<Http, string>();

async function agentToken(sql: postgres.Sql, http: Http) {
  if (!agentTokens.has(http)) {
    const value = randomBytes(32).toString("base64url");
    const token_digest = createHash("sha256").update(value).digest("hex");
    const scopes = ["read", "write", "delete", "agents"];
    await sql`INSERT INTO api_tokens ${sql({ name: "Agent", scopes, token_digest })}`;
    agentTokens.set(http, value);
  }
  return agentTokens.get(http) as string;
}

type Ctx = { app: { sql: postgres.Sql }; http: Http; request: APIRequestContext };

async function asAgent({ app, http, request }: Ctx, method: string, path: string, body?: Record<string, unknown>) {
  const response = await callApi(
    request,
    http,
    await agentToken(app.sql, http),
    method,
    path,
    body && JSON.stringify(body),
  );
  expect(response.status(), http.body.slice(0, 500)).toBeLessThan(300);
  return answer(http);
}

const fileId = async (sql: postgres.Sql, path: string) => {
  const [found] = await sql`SELECT id FROM memory_files WHERE path = ${path.endsWith(".md") ? path : `${path}.md`}`;
  return found.id as number;
};

const factId = async (sql: postgres.Sql, text: string) => {
  const [found] =
    await sql`SELECT id FROM memory_facts WHERE text = ${text} ORDER BY removed_at NULLS FIRST, id DESC LIMIT 1`;
  return found.id as number;
};

const projectId = async (sql: postgres.Sql, name: string) =>
  ((await sql`SELECT id FROM projects WHERE name = ${name}`)[0]?.id as number) ?? 0;

const taskId = async (sql: postgres.Sql, title: string) =>
  ((await sql`SELECT id FROM tasks WHERE title = ${title}`)[0]?.id as number) ?? 0;

const keyFor = (name: string) =>
  name
    .replaceAll(/[^A-Za-z]/g, "")
    .slice(0, 4)
    .toUpperCase()
    .padEnd(2, "X");

const scopeOf = async (sql: postgres.Sql, scope: string, target: string) => {
  if (scope === "project") return { project_id: await projectId(sql, target), scope };
  if (scope === "task") return { scope, task_id: await taskId(sql, target) };
  return { scope };
};

const adminScope = async (sql: postgres.Sql, scope: string, target: string) => {
  if (scope === "project") return `project:${await projectId(sql, target)}`;
  if (scope === "task") return `task:${await taskId(sql, target)}`;
  return scope;
};

async function asOwner(http: Http, path: string, form: Record<string, string>) {
  await http.send("POST", path, { form: { _csrf_token: await http.csrf(), ...form } });
  expect(http.last?.status(), http.body).toBeLessThan(500);
}

Given("the project {string}", async ({ app }, name: string) => {
  await app.sql`INSERT INTO projects ${app.sql({ key: keyFor(name), name, visibility: "private" })}`;
});

Given("the {word} task {string}", async ({ app }, status: string, title: string) => {
  const done = ["done", "canceled"].includes(status) ? { completed_at: new Date() } : {};
  await app.sql`INSERT INTO tasks ${app.sql({ list: "next", position: 1, status, title, ...done })}`;
});

Given(
  "the agent files the global memory {string} described {string}",
  async ({ app, http, request }, path: string, description: string) => {
    await asAgent({ app, http, request }, "POST", "memory_files", {
      description,
      path,
      scope: "global",
      ...author,
      ...inSession(http),
    });
  },
);

Given(
  "the agent files the {word} memory {string} for {string} described {string}",
  async ({ app, http, request }, scope: string, path: string, target: string, description: string) => {
    await asAgent({ app, http, request }, "POST", "memory_files", {
      description,
      path,
      ...(await scopeOf(app.sql, scope, target)),
      ...author,
      ...inSession(http),
    });
  },
);

Given("I file the global memory {string} described {string}", async ({ http }, path: string, description: string) => {
  await asOwner(http, "/admin/agents/memories", {
    "memory_file[description]": description,
    "memory_file[path]": path,
    "memory_file[scope]": "global",
  });
});

Given(
  "I file the {word} memory {string} for {string} described {string}",
  async ({ app, http }, scope: string, path: string, target: string, description: string) => {
    await asOwner(http, "/admin/agents/memories", {
      "memory_file[description]": description,
      "memory_file[path]": path,
      "memory_file[scope]": await adminScope(app.sql, scope, target),
    });
  },
);

Given(
  "the agent adds the {word} {string} to {string}",
  async ({ app, http, request }, type: string, text: string, path: string) => {
    const id = await fileId(app.sql, path);
    const body = { text, type, ...author, ...inSession(http) };
    await asAgent({ app, http, request }, "POST", `memory_files/${id}/facts`, body);
  },
);

Given(
  "the agent changes {string} in {string} to {string}",
  async ({ app, http, request }, text: string, path: string, changed: string) => {
    const id = await fileId(app.sql, path);
    const fact = await factId(app.sql, text);
    await asAgent({ app, http, request }, "PATCH", `memory_files/${id}/facts/${fact}`, { text: changed, ...author });
  },
);

Given("the agent describes {string} as {string}", async ({ app, http, request }, path: string, description: string) => {
  const id = await fileId(app.sql, path);
  await asAgent({ app, http, request }, "POST", `memory_files/${id}/describe`, {
    description,
    ...author,
    ...inSession(http),
  });
});

Given("the agent starts the session {string}", async ({ app, http, request }, title: string) => {
  const started = await asAgent({ app, http, request }, "POST", "agent_sessions", { title, ...author });
  keep(http, "session", started.session_id);
});

Given(
  "the agent starts the session {string} with:",
  async ({ app, http, request }, title: string, table: DataTable) => {
    const fields: Record<string, unknown> = { ...table.rowsHash() };
    if (fields.tasks) {
      fields.tasks = await Promise.all(
        String(fields.tasks)
          .split(", ")
          .map((name) => taskId(app.sql, name)),
      );
    }
    const started = await asAgent({ app, http, request }, "POST", "agent_sessions", { title, ...author, ...fields });
    keep(http, "session", started.session_id);
    keep(http, `session:${title}`, started.session_id);
  },
);

Given(
  "the session {string} started {int} day(s) ago and ran {int} minutes",
  async ({ app }, title: string, days: number, minutes: number) => {
    const started = new Date(Date.now() - days * 86_400_000);
    const ended = new Date(started.getTime() + minutes * 60_000);
    await app.sql`
    UPDATE agent_sessions SET started_at = ${started}, last_seen_at = ${ended}, ended_at = ${ended}
    WHERE title = ${title}
  `;
  },
);

Given("the agent ends its session", async ({ app, http, request }) => {
  await asAgent({ app, http, request }, "POST", `agent_sessions/${recall(http, "session")}/end`);
});

Given("the agent searches memory for {string}", async ({ app, http, request }, query: string) => {
  const params = new URLSearchParams({ query, session_id: String(recall(http, "session")) });
  await asAgent({ app, http, request }, "GET", `memory/search?${params}`);
});

Given(
  "the agent searches memory for {string} with:",
  async ({ app, http, request }, query: string, table: DataTable) => {
    const filters = Object.fromEntries(
      Object.entries(table.rowsHash()).map(([key, value]) => [key, fill(http, value)]),
    );
    if (filters.task) filters.task_id = String(await taskId(app.sql, filters.task));
    delete filters.task;
    const params = new URLSearchParams({ query, session_id: String(recall(http, "session")), ...filters });
    await asAgent({ app, http, request }, "GET", `memory/search?${params}`);
  },
);

Given("the session loaded {string} before reads were recorded", async ({ app, http }, path: string) => {
  const id = await fileId(app.sql, path);
  await app.sql`INSERT INTO agent_session_loads ${app.sql({ agent_session_id: Number(recall(http, "session")), memory_file_id: id })}`;
});

Given("the agent writes the {word} {string}", async ({ app, http, request }, type: string, title: string) => {
  await asAgent({ app, http, request }, "POST", "artifacts", {
    body: "Add an index",
    tags: [],
    title,
    type,
    ...author,
    ...inSession(http),
  });
});

Given(
  "the agent files the global memory {string} described {string} outside its session",
  async ({ app, http, request }, path: string, description: string) => {
    await asAgent({ app, http, request }, "POST", "memory_files", { description, path, scope: "global", ...author });
  },
);

Given("the agent reads {string} in its session", async ({ app, http, request }, path: string) => {
  const id = await fileId(app.sql, path);
  await asAgent({ app, http, request }, "GET", `memory_files/${id}?session_id=${recall(http, "session")}`);
});

When("I add the {word} {string} to {string}", async ({ app, http }, type: string, text: string, path: string) => {
  const id = await fileId(app.sql, path);
  await asOwner(http, `/admin/agents/memories/${id}/facts`, { "fact[text]": text, "fact[type]": type });
});

When(
  "I change the {word} {string} in {string} to {string}",
  async ({ app, http }, type: string, text: string, path: string, changed: string) => {
    const id = await fileId(app.sql, path);
    const fact = await factId(app.sql, text);
    await asOwner(http, `/admin/agents/memories/${id}/facts/${fact}`, { "fact[text]": changed, "fact[type]": type });
  },
);

When("I remove {string} from {string}", async ({ app, http }, text: string, path: string) => {
  const id = await fileId(app.sql, path);
  await asOwner(http, `/admin/agents/memories/${id}/facts/${await factId(app.sql, text)}/delete`, {});
});

When("I describe {string} as {string}", async ({ app, http }, path: string, description: string) => {
  const id = await fileId(app.sql, path);
  await asOwner(http, `/admin/agents/memories/${id}/description`, { "memory_file[description]": description });
});

When("I move {string} to the {word} {string}", async ({ app, http }, path: string, scope: string, target: string) => {
  const id = await fileId(app.sql, path);
  await asOwner(http, `/admin/agents/memories/${id}/scope`, {
    "memory_file[scope]": await adminScope(app.sql, scope, target),
  });
});

When("I move {string} to the global scope", async ({ app, http }, path: string) => {
  const id = await fileId(app.sql, path);
  await asOwner(http, `/admin/agents/memories/${id}/scope`, { "memory_file[scope]": "global" });
});

When("I delete the memory file {string}", async ({ app, http }, path: string) => {
  await asOwner(http, `/admin/agents/memories/${await fileId(app.sql, path)}/delete`, {});
});

When("I revert change {int} of {string}", async ({ app, http }, number: number, path: string) => {
  const id = await fileId(app.sql, path);
  const events = await app.sql`SELECT id FROM memory_events WHERE memory_file_id = ${id} ORDER BY id`;
  await asOwner(http, `/admin/agents/memories/${id}/history/${events[number - 1].id}/revert`, {});
});

When("I revert the latest change to {string}", async ({ app, http }, path: string) => {
  const id = await fileId(app.sql, path);
  const [event] = await app.sql`SELECT id FROM memory_events WHERE memory_file_id = ${id} ORDER BY id DESC LIMIT 1`;
  await asOwner(http, `/admin/agents/memories/${id}/history/${event.id}/revert`, {});
});

When("I open the memory file {string}", async ({ app, http, page }, path: string) => {
  const id = await fileId(app.sql, path);
  keep(http, "file", id);
  await page.goto(`/admin/agents/memories/${id}`);
});

When("I open the memory file {string} with {string}", async ({ app, http, page }, path: string, query: string) => {
  const id = await fileId(app.sql, path);
  keep(http, "file", id);
  await page.goto(`/admin/agents/memories/${id}?${query}`);
});

When("I note the ids of {string}", async ({ app, http }, path: string) => {
  const [file] = await app.sql`SELECT id FROM memory_files WHERE path = ${`${path}.md`}`;
  const id = file?.id ?? 0;
  keep(http, "file", id);
  const events = await app.sql`SELECT id FROM memory_events WHERE memory_file_id = ${id} ORDER BY id`;
  for (const [index, event] of events.entries()) keep(http, `event${index + 1}`, event.id);
  for (const fact of await app.sql`SELECT id, text FROM memory_facts WHERE memory_file_id = ${id}`) {
    keep(http, `fact:${fact.text}`, fact.id);
  }
  const project = await app.sql`SELECT id FROM projects ORDER BY id`;
  for (const [index, row] of project.entries()) keep(http, `project${index + 1}`, row.id);
  const tasks = await app.sql`SELECT id FROM tasks ORDER BY id`;
  for (const [index, row] of tasks.entries()) keep(http, `task${index + 1}`, row.id);
});

Then("the memory events of {string} are:", async ({ app }, path: string, table: DataTable) => {
  const id = await fileId(app.sql, path);
  const events = await app.sql`
    SELECT op, coalesce(text, was_text, '') AS text, coalesce(agent, 'you') AS who
    FROM memory_events WHERE memory_file_id = ${id} ORDER BY id
  `;
  expect(events.map(({ op, text, who }) => [op, text, who])).toEqual(table.raw());
});

Then("{string} holds the facts {string}", async ({ app }, path: string, texts: string) => {
  const id = await fileId(app.sql, path);
  const facts =
    await app.sql`SELECT text FROM memory_facts WHERE memory_file_id = ${id} AND removed_at IS NULL ORDER BY id`;
  expect(facts.map(({ text }) => text).join(", ")).toBe(texts);
});

Then("{string} holds no facts", async ({ app }, path: string) => {
  const id = await fileId(app.sql, path);
  expect(await app.sql`SELECT text FROM memory_facts WHERE memory_file_id = ${id} AND removed_at IS NULL`).toHaveLength(
    0,
  );
});

When("I visit the index of memories for the project {string}", async ({ app, page }, name: string) => {
  await page.goto(`/admin/agents/memories?project=${await projectId(app.sql, name)}`);
});

Then(
  "the {string} picker offers {string} with {string} picked",
  async ({ page }, label: string, names: string, picked: string) => {
    const select = page.getByLabel(label);
    expect((await select.locator("option").allTextContents()).join(", ")).toBe(names);
    await expect(select.locator("option:checked")).toHaveText(picked);
  },
);

Then("the session's loaded memory holds no facts", async ({ app, http }) => {
  const [started] = await app.sql`SELECT id FROM agent_sessions WHERE id = ${Number(recall(http, "session"))}`;
  expect(started).toBeDefined();
  const loaded = answer(http);
  const files = (loaded.files ?? []) as { fact_count: number }[];
  expect(files.reduce((sum, file) => sum + file.fact_count, 0)).toBe(0);
});

When(
  "I add a {word} of {int} {string}s to {string}",
  async ({ app, http }, type: string, length: number, letter: string, path: string) => {
    const id = await fileId(app.sql, path);
    await asOwner(http, `/admin/agents/memories/${id}/facts`, {
      "fact[text]": letter.repeat(length),
      "fact[type]": type,
    });
  },
);

When(
  "I change the {word} of {int} {string}s in {string} to {int} {string}s",
  async ({ app, http }, type: string, length: number, letter: string, path: string, changed: number, other: string) => {
    const id = await fileId(app.sql, path);
    const fact = await factId(app.sql, letter.repeat(length));
    await asOwner(http, `/admin/agents/memories/${id}/facts/${fact}`, {
      "fact[text]": other.repeat(changed),
      "fact[type]": type,
    });
  },
);

Given("the agent adds {int} gotchas to {string}", async ({ app, http, request }, count: number, path: string) => {
  const id = await fileId(app.sql, path);
  for (let number = 1; number <= count; number++) {
    await asAgent({ app, http, request }, "POST", `memory_files/${id}/facts`, {
      text: `Fact ${number}`,
      type: "gotcha",
      ...author,
    });
  }
});

Given("the project {string} in the repo {string}", async ({ app }, name: string, repo: string) => {
  await app.sql`INSERT INTO projects ${app.sql({ key: keyFor(name), name, repo, visibility: "private" })}`;
});

When("I open the session {string}", async ({ app, page }, title: string) => {
  const [found] = await app.sql`SELECT id FROM agent_sessions WHERE title = ${title}`;
  await page.goto(`/admin/agents/sessions?session=${found.id}`);
});

const artifactId = async (sql: postgres.Sql, title: string) =>
  ((await sql`SELECT id FROM artifacts WHERE title = ${title} ORDER BY id DESC LIMIT 1`)[0]?.id as number) ?? 0;

const tagList = (tags: string) =>
  tags
    .split(",")
    .map((tag) => tag.trim())
    .filter(Boolean);

Given(
  "the agent writes the {word} {string} with the body {string}",
  async ({ app, http, request }, type: string, title: string, body: string) => {
    await asAgent({ app, http, request }, "POST", "artifacts", {
      body: body.replaceAll("\\n", "\n"),
      tags: [],
      title,
      type,
      ...author,
      ...inSession(http),
    });
    keep(http, "artifact", await artifactId(app.sql, title));
  },
);

Given(
  "the agent writes the {word} {string} tagged {string}",
  async ({ app, http, request }, type: string, title: string, tags: string) => {
    await asAgent({ app, http, request }, "POST", "artifacts", {
      body: "Add an index",
      tags: tagList(tags),
      title,
      type,
      ...author,
    });
    keep(http, "artifact", await artifactId(app.sql, title));
  },
);

Given(
  "the agent revises {string} to the body {string}",
  async ({ app, http, request }, title: string, body: string) => {
    const id = await artifactId(app.sql, title);
    await asAgent({ app, http, request }, "PATCH", `artifacts/${id}`, { body, ...author });
  },
);

Given("the agent tags {string} with {string}", async ({ app, http, request }, title: string, tags: string) => {
  const id = await artifactId(app.sql, title);
  await asAgent({ app, http, request }, "PATCH", `artifacts/${id}`, { tags: tagList(tags), ...author });
});

Given(
  "I write the {word} {string} with the body {string}",
  async ({ app, http }, type: string, title: string, body: string) => {
    await asOwner(http, "/admin/agents/artifacts", {
      "artifact[body]": body,
      "artifact[tags]": "",
      "artifact[title]": title,
      "artifact[type]": type,
    });
    keep(http, "artifact", await artifactId(app.sql, title));
  },
);

When("I save {string} with:", async ({ app, http }, title: string, table: DataTable) => {
  const id = await artifactId(app.sql, title);
  const [current] = await app.sql`
    SELECT a.title, a.type, v.body FROM artifacts a
    JOIN artifact_versions v ON v.artifact_id = a.id WHERE a.id = ${id} ORDER BY v.number DESC LIMIT 1
  `;
  const fields = { tags: "", ...current, ...table.rowsHash() };
  await asOwner(
    http,
    `/admin/agents/artifacts/${id}`,
    Object.fromEntries(Object.entries(fields).map(([key, value]) => [`artifact[${key}]`, String(value)])),
  );
});

Given("version {int} of {string} dates from {string}", async ({ app }, number: number, title: string, when: string) => {
  const id = await artifactId(app.sql, title);
  await app.sql.unsafe(
    `UPDATE artifact_versions SET created_at = ${literal(when)} WHERE artifact_id = ${id} AND number = ${number}`,
  );
});

When("I link {string} to the {word} {string}", async ({ app, http }, title: string, kind: string, other: string) => {
  const id = await artifactId(app.sql, title);
  const otherId = kind === "project" ? await projectId(app.sql, other) : await taskId(app.sql, other);
  await asOwner(http, `/admin/agents/artifacts/${id}/records`, {
    "record[other_id]": String(otherId),
    "record[other_kind]": kind,
  });
});

When("I open the artifact {string}", async ({ app, http, page }, title: string) => {
  const id = await artifactId(app.sql, title);
  keep(http, "artifact", id);
  await page.goto(`/admin/agents/artifacts/${id}`);
});

Then("the versions of {string} are {string}", async ({ app }, title: string, expected: string) => {
  const id = await artifactId(app.sql, title);
  const rows = await app.sql`
    SELECT number, coalesce(agent, 'you') AS who, coalesce(note, '') AS note FROM artifact_versions
    WHERE artifact_id = ${id} ORDER BY number
  `;
  expect(rows.map(({ number, who, note }) => `v${number} ${who}${note ? ` ${note}` : ""}`).join(", ")).toBe(expected);
});

When("I save {string} with a note of {int} characters", async ({ app, http }, title: string, length: number) => {
  const id = await artifactId(app.sql, title);
  await asOwner(http, `/admin/agents/artifacts/${id}`, {
    "artifact[body]": "Changed",
    "artifact[note]": "x".repeat(length),
    "artifact[tags]": "",
    "artifact[title]": title,
    "artifact[type]": "plan",
  });
});

Given("the agent tags its session {string}", async ({ app, http, request }, tag: string) => {
  await asAgent({ app, http, request }, "POST", `agent_sessions/${recall(http, "session")}/tags`, { tag });
});

Given("the agent tags the memory file {string} {string}", async ({ app, http, request }, path: string, tag: string) => {
  await asAgent({ app, http, request }, "POST", `memory_files/${await fileId(app.sql, path)}/tags`, { tag });
});

Then("the tags of the session are {string}", async ({ app, http }, expected: string) => {
  const rows = await app.sql`
    SELECT t.name, t.scope, p.name AS project FROM agent_session_tags st JOIN tags t ON t.id = st.tag_id
    LEFT JOIN projects p ON p.id = t.project_id WHERE st.agent_session_id = ${Number(recall(http, "session"))}
  `;
  expect(rows.map(({ name, scope, project }) => [name, scope, project].filter(Boolean).join(" ")).join(", ")).toBe(
    expected,
  );
});

Then("the tags of the memory file {string} are {string}", async ({ app }, path: string, expected: string) => {
  const rows = await app.sql`
    SELECT t.name, t.scope, p.name AS project FROM memory_file_tags ft JOIN tags t ON t.id = ft.tag_id
    LEFT JOIN projects p ON p.id = t.project_id WHERE ft.memory_file_id = ${await fileId(app.sql, path)}
  `;
  expect(rows.map(({ name, scope, project }) => [name, scope, project].filter(Boolean).join(" ")).join(", ")).toBe(
    expected,
  );
});

Then("the tag field of the artifact form offers {string}", async ({ page }, names: string) => {
  const field = await page.locator("#artifact-form .tag-pick").getAttribute("data-tag-field");
  expect((JSON.parse(field ?? "[]") as { name: string }[]).map(({ name }) => name).join(", ")).toBe(names);
});
