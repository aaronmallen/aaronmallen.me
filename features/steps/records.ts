import { expect } from "@playwright/test";
import type postgres from "postgres";
import { insertPost } from "../support/rows.ts";
import { Given, Then } from "../support/world.ts";
import { folderAt } from "./notes.ts";

const kinds = ["task", "post", "social_post", "journal_entry", "commit", "project", "work_entry", "decision"].concat([
  "pull_request",
  "mail_thread",
  "memory_file",
  "artifact",
  "note",
  "note_folder",
]);

async function recordId(sql: postgres.Sql, kind: string, name: string) {
  if (kind === "note_folder") return folderAt(sql, name);
  if (kind === "work_entry") {
    const [entry] = await sql`SELECT id FROM work_entries WHERE role = ${name}`;
    expect(entry, `the work entry ${name}`).toBeTruthy();
    return entry.id as number;
  }
  const column = kind === "note" || kind === "task" || kind === "post" ? "title" : "name";
  const [row] = await sql`SELECT id FROM ${sql(`${kind}s`)} WHERE ${sql(column)} = ${name}`;
  expect(row, `the ${kind} ${name}`).toBeTruthy();
  return row.id as number;
}

Given("a task {string}", async ({ app }, title: string) => {
  const [{ next }] = await app.sql`SELECT coalesce(max(number), 0) + 1 AS next FROM tasks`;
  await app.sql`INSERT INTO tasks ${app.sql({ list: "next", number: next, position: next, title })}`;
});

Given("a published post {string}", async ({ app }, title: string) => {
  await insertPost(app.sql, { publishedAt: new Date(), status: "published", title });
});

Given(
  "the {word} {string} links the {word} {string}",
  async ({ app }, kind: string, name: string, otherKind: string, other: string) => {
    const one = [kinds.indexOf(kind), await recordId(app.sql, kind, name), kind] as const;
    const two = [kinds.indexOf(otherKind), await recordId(app.sql, otherKind, other), otherKind] as const;
    const [left, right] = one[0] < two[0] || (one[0] === two[0] && one[1] < two[1]) ? [one, two] : [two, one];
    await app.sql`
      INSERT INTO record_links ${app.sql({ left_id: left[1], left_kind: left[2], right_id: right[1], right_kind: right[2] })}
    `;
  },
);

Then("{int} record link(s) remain(s)", async ({ app }, count: number) => {
  await expect.poll(async () => (await app.sql`SELECT id FROM record_links`).length).toBe(count);
});
