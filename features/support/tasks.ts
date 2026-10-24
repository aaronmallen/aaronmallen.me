import type postgres from "postgres";
import { dayOf, formatDay, iso, zoned } from "./calendar.ts";

type Row = Record<string, string | undefined>;

export async function projectId(sql: postgres.Sql, name: string) {
  const [found] = await sql`SELECT id FROM projects WHERE name = ${name} OR key = ${name}`;
  if (found) return found.id as number;

  return insertProject(sql, { name });
}

// Inserts a project from a table row: name, key (the database picks one when left out), visibility, repo, url,
// tagline, stars, release, image, board ("published"), started and archived (days such as "today - 3", started
// 2024-01-01 when left out), updated (a time) and tags (its public tags, made when missing).
export async function insertProject(sql: postgres.Sql, row: Row) {
  const [{ id }] = await sql`
    INSERT INTO projects ${sql({
      archived_on: row.archived ? dayOf(row.archived) : null,
      board_published: row.board === "published",
      key: row.key || null,
      name: row.name ?? "Project",
      og_image_url: row.image || null,
      release: row.release || null,
      repo: row.repo || null,
      stars: Number(row.stars || 0),
      started_on: row.started ? dayOf(row.started) : "2024-01-01",
      tagline: row.tagline || null,
      updated_at: row.updated ? new Date(row.updated) : new Date(),
      url: row.url || null,
      visibility: row.visibility || "public",
    })}
    RETURNING id
  `;
  for (const tag of (row.tags ?? "").split(/[\s,]+/).filter(Boolean)) {
    const [found] = await sql`SELECT id FROM tags WHERE name = ${tag} AND scope = 'public'`;
    const tagRow =
      found ?? (await sql`INSERT INTO tags ${sql({ color: "mk-blue", name: tag, scope: "public" })} RETURNING id`)[0];
    await sql`INSERT INTO project_tags ${sql({ project_id: id, tag_id: tagRow.id })}`;
  }
  return id as number;
}

export async function sprintId(sql: postgres.Sql, day: string) {
  const sprintDate = dayOf(day);
  const [found] = await sql`SELECT id FROM sprints WHERE sprint_date = ${sprintDate}`;
  if (found) return found.id as number;

  const [{ id }] = await sql`INSERT INTO sprints ${sql({ sprint_date: sprintDate })} RETURNING id`;
  return id as number;
}

export async function tagId(sql: postgres.Sql, name: string, project?: number) {
  const scope = project ? "project" : "private";
  const [found] = await sql`
    SELECT id FROM tags WHERE name = ${name} AND scope = ${scope} AND project_id IS NOT DISTINCT FROM ${project ?? null}
  `;
  if (found) return found.id as number;

  const [{ id }] = await sql`
    INSERT INTO tags ${sql({ color: "mk-blue", name, project_id: project ?? null, scope })} RETURNING id
  `;
  return id as number;
}

// Inserts a task from a table row: title, list, sprint (a day such as "today"), status, stage, project, tags,
// note, worked (seconds) and number. A task with neither list nor sprint goes to next.
export async function insertTask(sql: postgres.Sql, row: Row) {
  const project = row.project ? await projectId(sql, row.project) : null;
  const [{ next }] = await sql`
    SELECT coalesce(max(number), 0) + 1 AS next FROM tasks WHERE project_id IS NOT DISTINCT FROM ${project}
  `;
  const [{ place }] = await sql`SELECT coalesce(max(position), 0) + 1 AS place FROM tasks`;
  const status = row.status || "open";
  const [{ id }] = await sql`
    INSERT INTO tasks ${sql({
      completed_at: status === "done" || status === "canceled" ? new Date() : null,
      list: row.sprint ? null : row.list || "next",
      note: row.note ?? "",
      number: row.number ? Number(row.number) : next,
      position: row.position ? Number(row.position) : place,
      project_id: project,
      sprint_id: row.sprint ? await sprintId(sql, row.sprint) : null,
      stage: row.stage || "backlog",
      status,
      title: row.title ?? "A task",
      worked_seconds: row.worked ? Number(row.worked) : 0,
    })}
    RETURNING id
  `;
  for (const name of (row.tags ?? "").split(/[\s,]+/).filter(Boolean)) {
    await sql`INSERT INTO task_tags ${sql({ tag_id: await tagId(sql, name), task_id: id })}`;
  }
  return id as number;
}

export async function taskId(sql: postgres.Sql, title: string) {
  const [found] = await sql`SELECT id FROM tasks WHERE title = ${title} ORDER BY id LIMIT 1`;
  if (!found) throw new Error(`no task called ${title}`);

  return found.id as number;
}

const named: Record<string, [string, string]> = {
  project: ["projects", "name"],
  rule: ["task_rules", "pattern"],
  task: ["tasks", "title"],
  work_entry: ["work_entries", "role"],
};

const longMonths = ["January", "February", "March", "April", "May", "June", "July", "August", "September"].concat([
  "October",
  "November",
  "December",
]);

// Writes a day as the admin does: long "October 23, 2026", medium "Oct 23, 2026", short "Oct 23" and weekday
// "Friday, October 23".
function written(format: string, text: string) {
  const day = dayOf(text);
  if (format === "medium" || format === "short") return formatDay(day, format);
  const [year, month, date] = day.split("-").map(Number);
  if (format === "long") return `${longMonths[month - 1]} ${date}, ${year}`;
  const weekday = new Date(Date.UTC(year, month - 1, date)).toLocaleDateString("en-US", {
    timeZone: "UTC",
    weekday: "long",
  });
  return `${weekday}, ${longMonths[month - 1]} ${date}`;
}

// Swaps each {kind:name} in a path or JSON body for that record's ID, such as {task:Write docs} or
// {sprint:today}; {session:Write docs} names the first work session of a task. {day:today + 3} swaps in the day and
// {at:today 14:00} the instant that wall clock reads, as the app's JSON writes them; {local:today 14:00} gives the
// wall clock as a datetime-local field takes it, and {medium:today}, {short:today}, {long:today} or
// {weekday:today} the day as the admin writes it.
export async function withIds(sql: postgres.Sql, text: string) {
  const found = [...text.matchAll(/\{(\w+):([^{}"]+)\}/g)];
  let out = text;
  for (const [whole, kind, name] of found) {
    let id: number | string;
    if (kind === "day") id = dayOf(name);
    else if (kind === "medium" || kind === "short" || kind === "long" || kind === "weekday") id = written(kind, name);
    else if (kind === "at") {
      const [, day, clock] = /^(.+?)\s+(\d\d:\d\d)$/.exec(name.trim()) ?? [];
      id = iso(zoned(dayOf(day), clock));
    } else if (kind === "local") {
      const [, day, clock] = /^(.+?)\s+(\d\d:\d\d)$/.exec(name.trim()) ?? [];
      id = `${dayOf(day)}T${clock}`;
    } else if (kind === "sprint") id = await sprintId(sql, name);
    else if (kind === "session")
      [{ id }] = await sql`SELECT id FROM work_sessions WHERE task_id = ${await taskId(sql, name)} ORDER BY id LIMIT 1`;
    else if (named[kind]) {
      const [table, column] = named[kind];
      const [row] = await sql`SELECT id FROM ${sql(table)} WHERE ${sql(column)} = ${name} ORDER BY id LIMIT 1`;
      if (!row) throw new Error(`no ${kind} called ${name}`);
      id = row.id;
    } else continue;
    out = out.replace(whole, String(id));
  }
  return out;
}
