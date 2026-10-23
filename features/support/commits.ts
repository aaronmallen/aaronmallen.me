import type postgres from "postgres";
import { seal } from "./seal.ts";

type Fields = Record<string, string>;

// Gherkin tables cannot hold a line break, so "\n" in a cell stands for one.
const withBreaks = (fields: Fields) =>
  Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, value.replaceAll("\\n", "\n")]));

export async function insertCommit(sql: postgres.Sql, fields: Fields) {
  const [{ id }] = await sql`
    INSERT INTO commits ${sql({
      branch: "main",
      commit_date: "2026-03-02",
      commit_time: "14:05",
      message: "fix the feed",
      repo: "aaronmallen/blog",
      sha: "a".repeat(40),
      ...withBreaks(fields),
    })}
    RETURNING id
  `;
  return id as number;
}

export async function insertPullRequest(sql: postgres.Sql, fields: Fields) {
  const row: Fields = { body: "", number: "4", repo: "aaronmallen/blog", title: "Fix the feed", ...withBreaks(fields) };
  const ready = row.ready_at === "none" ? null : (row.ready_at ?? new Date().toISOString());
  const [{ id }] = await sql`
    INSERT INTO pull_requests ${sql({
      ...row,
      opened_at: ready ?? new Date().toISOString(),
      ready_at: ready,
      url: row.url ?? `https://github.com/${row.repo}/pull/${row.number}`,
    })}
    RETURNING id
  `;
  return id as number;
}

export async function linkTask(sql: postgres.Sql, kind: "commit" | "pull_request", id: number, title: string) {
  const [task] = await sql`INSERT INTO tasks ${sql({ list: "next", position: 1, title })} RETURNING id`;
  await sql`
    INSERT INTO record_links ${sql({ left_id: task.id, left_kind: "task", right_id: id, right_kind: kind })}
  `;
}

export async function connectGitHub(sql: postgres.Sql) {
  await sql`
    INSERT INTO service_connections ${sql({
      account_id: "931094",
      credentials: seal(JSON.stringify({ access_token: "ghp_token" })),
      label: "@aaronmallen",
      provider: "github",
      scopes: ["repo"],
    })}
  `;
}
