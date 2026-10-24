import type postgres from "postgres";
import { insertTimedTask } from "./task_api.ts";
import { projectId, tagId } from "./tasks.ts";

type Row = Record<string, string | undefined>;

// Inserts a task in a project with that project's own tags, as the app files them.
export async function insertProjectTask(sql: postgres.Sql, row: Row) {
  const id = await insertTimedTask(sql, { ...row, tags: "" });
  const project = row.project ? await projectId(sql, row.project) : undefined;
  for (const name of (row.tags ?? "").split(/[\s,]+/).filter(Boolean)) {
    const tag = await tagId(sql, name, project);
    await sql`INSERT INTO task_tags ${sql({ tag_id: tag, tag_scope: project ? "project" : "private", task_id: id })}`;
  }
  return id;
}
