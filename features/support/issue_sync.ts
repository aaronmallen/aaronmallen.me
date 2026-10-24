import type { Sent, Stub } from "./stub.ts";

export const viewer = "MDQ6VXNlcjkzMTA5NA==";
export const someoneElse = "MDQ6VXNlcjE=";

type Json = Record<string, unknown>;
type Reply = { body: string; drop?: boolean; headers?: Record<string, string>; status: number };

// A GitHub that holds issues: the search answers the assigned ones a page at a time, the lookup by ID answers the
// known ones (assigned or not), and REST answers the paths set in rest. A reply set in searchReplies or
// lookupReplies answers in place of the next search or lookup, in turn.
export type FakeGitHub = {
  assigned: Json[];
  duringSearch?: () => Promise<void>;
  known: Json[];
  lookupReplies: (Reply | "missing")[];
  pageSize: number;
  rest: Record<string, Reply>;
  searchReplies: Reply[];
  stuckCursor: boolean;
};

const fakes = new WeakMap<object, FakeGitHub>();

const json = (body: unknown, status = 200): Reply => ({ body: JSON.stringify(body), status });

const rateLimit = () => ({ limit: 5000, remaining: 4999, resetAt: new Date(Date.now() + 1_800_000).toISOString() });

export const related = (ids: string) => {
  const parts = ids.split(/[\s,]+/).filter(Boolean);
  return {
    nodes: parts.filter((id) => id !== "+more").map((id) => (id === "hidden" ? null : { id })),
    pageInfo: { hasNextPage: parts.includes("+more") },
  };
};

export function comment(id: string, fields: Json = {}) {
  return {
    author: { login: "octocat" },
    body: "Looks good",
    createdAt: new Date(Date.now() - 600_000).toISOString().replace(/\.\d{3}Z$/, "Z"),
    id,
    url: `https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-${id.replace(/^IC_/, "")}`,
    ...fields,
  };
}

// Builds an issue as GitHub's GraphQL sends it from a table row.
export function issue(row: Record<string, string>): Json {
  const number = Number(row.number || 7);
  const repo = row.repo || "aaronmallen/aaronmallen.me";
  const built: Json = {
    assignees: { nodes: [{ id: row.assignee === "someone else" ? someoneElse : viewer }] },
    blockedBy: related(row.blocked_by ?? ""),
    blocking: related(row.blocking ?? ""),
    body: JSON.parse(`"${row.body ?? "Keep them in step"}"`),
    comments: {
      nodes: (row.comments ?? "")
        .split(/[\s,]+/)
        .filter((id) => id && id !== "+more")
        .map((id) => comment(id)),
      pageInfo: { hasNextPage: (row.comments ?? "").includes("+more") },
    },
    id: row.id || `I_${number}`,
    labels: {
      nodes: (row.labels ?? "")
        .split(",")
        .filter((name) => name.trim())
        .map((name) => ({ name: name.trim() })),
    },
    number,
    parent: row.parent ? { id: row.parent } : null,
    repository: { nameWithOwner: repo },
    state: row.state || "OPEN",
    stateReason: row.reason || null,
    subIssues: related(row.sub_issues ?? ""),
    title: JSON.parse(`"${row.title ?? "Sync my issues"}"`),
    url: `https://github.com/${repo}/issues/${number}`,
  };
  if (row.labels === '""') built.labels = { nodes: [{ name: "" }] };
  for (const left of (row.without ?? "").split(/[\s,]+/).filter(Boolean)) delete built[left];
  return built;
}

async function answer(fake: FakeGitHub, sent: Sent): Promise<Reply> {
  const { query, variables = {} } = JSON.parse(sent.body.toString() || "{}");
  if (query.includes("search(query:")) {
    await fake.duringSearch?.();
    fake.duringSearch = undefined;
    const queued = fake.searchReplies.shift();
    if (queued) return queued;
    const start = Number(/^page-(\d+)$/.exec(variables.cursor ?? "")?.[1] ?? 1) - 1;
    const page = fake.stuckCursor ? 0 : start;
    const nodes = fake.assigned.slice(page * fake.pageSize, (page + 1) * fake.pageSize);
    const more = fake.stuckCursor || (page + 1) * fake.pageSize < fake.assigned.length;
    const cursor = fake.stuckCursor ? "page-2" : `page-${page + 2}`;
    return json({
      data: {
        rateLimit: rateLimit(),
        search: { nodes, pageInfo: { endCursor: more ? cursor : null, hasNextPage: more } },
        viewer: { id: viewer },
      },
    });
  }
  if (query.includes("nodes(ids:")) {
    const queued = fake.lookupReplies.shift();
    const ids: string[] = variables.ids ?? [];
    if (queued === "missing") {
      return json({
        data: { nodes: ids.map(() => null), rateLimit: rateLimit(), viewer: { id: viewer } },
        errors: [{ message: "Could not resolve to a node", type: "NOT_FOUND" }],
      });
    }
    if (queued) return queued;
    const nodes = ids.map(
      (id) => fake.known.find((node) => node.id === id) ?? fake.assigned.find((node) => node.id === id) ?? null,
    );
    return json({ data: { nodes, rateLimit: rateLimit(), viewer: { id: viewer } } });
  }
  return json({ data: { rateLimit: rateLimit(), viewer: { id: viewer } } });
}

// One fake per scenario, keyed by an object the scenario alone holds, such as its answer fixture.
export function github(stub: Stub, scenario: object) {
  let fake = fakes.get(scenario);
  if (fake) return fake;

  fake = { assigned: [], known: [], lookupReplies: [], pageSize: 100, rest: {}, searchReplies: [], stuckCursor: false };
  fakes.set(scenario, fake);
  const held = fake;
  stub.reply("POST", "/github/api/graphql", (sent) => answer(held, sent));
  stub.reply("GET", "/github/api/repos/*", (sent) => {
    const path = sent.url.pathname.slice("/github/api/repos/".length);
    return held.rest[path] ?? { body: '{"message":"Not Found"}', status: 404 };
  });
  return fake;
}

export const searches = (stub: Stub) =>
  stub.received("POST", "/github/api/graphql").filter((body) => body.includes("search(query:"));

export const lookups = (stub: Stub) =>
  stub.received("POST", "/github/api/graphql").filter((body) => body.includes("nodes(ids:"));

export const linearViewer = "0b7f5a52-viewer";

type Workspace = { assigned: Json[]; known: Json[]; urlKey: string };

// A Linear that holds a workspace per API key. The assigned query answers a workspace's assigned issues, the lookup
// by ID its known and assigned ones, history the changes set per issue, and issue(id:) the relations set in alone.
export type FakeLinear = {
  alone: Record<string, Json>;
  assignedReplies: Reply[];
  duringAssigned?: () => Promise<void>;
  pageSize: number;
  stuckCursor: boolean;
  history: Record<string, Json[]>;
  lookupReplies: Reply[];
  workspaces: Record<string, Workspace>;
};

const linearFakes = new WeakMap<object, FakeLinear>();

const linearRelated = (text: string, shape: (kind: string, id: string) => Json) => {
  const parts = text
    .split(";")
    .map((part) => part.trim())
    .filter(Boolean);
  return {
    nodes: parts
      .filter((part) => part !== "+more")
      .map((part) => {
        const [kind, id] = part.includes(" ") ? part.split(" ") : ["", part];
        return shape(kind, id);
      }),
    pageInfo: { hasNextPage: parts.includes("+more") },
  };
};

export const linearChildren = (text: string) => linearRelated(text, (_, id) => ({ id }));

export function linearComment(id: string, fields: Json = {}) {
  return {
    body: "Looks good",
    createdAt: new Date(Date.now() - 600_000).toISOString(),
    id,
    url: `https://linear.app/aaronmallen/issue/abc-1/sync-my-issues#comment-${id}`,
    user: { displayName: "aaron" },
    ...fields,
  };
}

// Builds an issue as Linear's GraphQL sends it from a table row.
export function linearIssue(row: Record<string, string>): Json {
  const key = row.key || "ABC-1";
  const workspace = row.workspace || "aaronmallen";
  const assignee =
    row.assignee === "someone else" ? { id: "someone-else" } : row.assignee === "none" ? null : { id: linearViewer };
  const built: Json = {
    assignee,
    children: linearChildren(row.children ?? ""),
    comments: {
      nodes: (row.comments ?? "")
        .split(/[\s,]+/)
        .filter((id) => id && id !== "+more")
        .map((id) => linearComment(id)),
      pageInfo: { hasNextPage: (row.comments ?? "").includes("+more") },
    },
    description: JSON.parse(`"${row.description ?? "Keep them in step"}"`),
    id: row.id || `L_${key.split("-")[1]}`,
    identifier: key,
    inverseRelations: linearRelated(row.inverse ?? "", (type, id) => ({ issue: { id }, type })),
    labels: {
      nodes: (row.labels ?? "")
        .split(",")
        .filter((name) => name.trim())
        .map((name) => {
          const [group, label] = name.includes("/") ? name.trim().split("/") : [null, name.trim()];
          return group ? { name: label, parent: { name: group } } : { name: label };
        }),
    },
    parent: row.parent ? { id: row.parent } : null,
    relations: linearRelated(row.relations ?? "", (type, id) => ({ relatedIssue: { id }, type })),
    state: { type: row.state || "unstarted" },
    title: JSON.parse(`"${row.title ?? "Sync my issues"}"`),
    trashed: row.trashed === "yes" ? true : null,
    url: `https://linear.app/${workspace}/issue/${key.toLowerCase()}/sync-my-issues`,
  };
  if (row.archived) built.archivedAt = "2026-09-20T12:00:00.000Z";
  if (row.updated) built.updatedAt = row.updated;
  return built;
}

async function linearAnswer(fake: FakeLinear, sent: Sent): Promise<Reply> {
  const { query, variables = {} } = JSON.parse(sent.body.toString() || "{}");
  const key = String(sent.headers.authorization ?? "");
  const workspace = fake.workspaces[key] ?? { assigned: [], known: [], urlKey: "nowhere" };
  if (query.includes("assignedIssues(")) {
    await fake.duringAssigned?.();
    fake.duringAssigned = undefined;
    const queued = fake.assignedReplies.shift();
    if (queued) return queued;
    const page = fake.stuckCursor ? 0 : Number(/^page-(\d+)$/.exec(variables.cursor ?? "")?.[1] ?? 1) - 1;
    const nodes = workspace.assigned.slice(page * fake.pageSize, (page + 1) * fake.pageSize);
    const more = fake.stuckCursor || (page + 1) * fake.pageSize < workspace.assigned.length;
    const endCursor = more ? (fake.stuckCursor ? "page-2" : `page-${page + 2}`) : null;
    return json({
      data: { viewer: { assignedIssues: { nodes, pageInfo: { endCursor, hasNextPage: more } }, id: linearViewer } },
    });
  }
  if (query.includes("history(first:")) {
    const ids: string[] = variables.ids ?? [variables.id];
    const nodes = ids.map((id) => ({
      history: { nodes: [...(fake.history[id] ?? [])].reverse(), pageInfo: { endCursor: null, hasNextPage: false } },
      id,
    }));
    return json({ data: { issues: { nodes } } });
  }
  if (query.includes("issue(id:")) {
    return json({ data: { issue: fake.alone[variables.id] ?? {} } });
  }
  if (query.includes("issues(first:")) {
    const queued = fake.lookupReplies.shift();
    if (queued) return queued;
    const ids: string[] = variables.ids ?? [];
    const nodes = [...workspace.known, ...workspace.assigned].filter(
      (node, at, all) => ids.includes(node.id as string) && all.findIndex((other) => other.id === node.id) === at,
    );
    return json({
      data: { issues: { nodes }, organization: { urlKey: workspace.urlKey }, viewer: { id: linearViewer } },
    });
  }
  return json({ data: { organization: { id: "ws-root", name: "ROOT", urlKey: workspace.urlKey } } });
}

export function linear(stub: Stub, scenario: object) {
  let fake = linearFakes.get(scenario);
  if (fake) return fake;

  fake = {
    alone: {},
    assignedReplies: [],
    history: {},
    lookupReplies: [],
    pageSize: 25,
    stuckCursor: false,
    workspaces: {},
  };
  linearFakes.set(scenario, fake);
  const held = fake;
  stub.reply("POST", "/linear/graphql", (sent) => linearAnswer(held, sent));
  return fake;
}

export const linearWorkspace = (fake: FakeLinear, key = "lin_api_one") => {
  fake.workspaces[key] ??= { assigned: [], known: [], urlKey: key === "lin_api_one" ? "aaronmallen" : key };
  return fake.workspaces[key];
};

export const linearQueries = (stub: Stub, text: string) =>
  stub
    .requests()
    .filter((sent) => sent.url.pathname === "/linear/graphql" && JSON.parse(sent.body.toString()).query.includes(text));
