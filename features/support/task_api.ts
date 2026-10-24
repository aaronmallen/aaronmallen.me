import type postgres from "postgres";
import { filled } from "./api.ts";
import { dayOf, iso, zoned } from "./calendar.ts";
import { insertTask, taskId } from "./tasks.ts";

type Row = Record<string, string | undefined>;

// Reads "today - 3" or "today + 1 15:30" as an instant in the owner's zone, at noon when it names no time.
export function instant(text: string) {
  const ago = /^now - (\d+) days?(?: \+ (\d+) seconds?)?$/.exec(text.trim());
  if (ago) return new Date(Date.now() - Number(ago[1]) * 86_400_000 + Number(ago[2] ?? 0) * 1000);
  const [, day, clock] = /^(.+?)(?:\s+(\d{1,2}:\d{2}))?$/.exec(text.trim()) ?? [];
  return zoned(dayOf(day), clock ?? "12:00");
}

// Swaps {day:today + 2} for an ISO day and {at:today 15:00} for the instant the app's JSON writes, then names
// records by ID as filled() does.
export async function marked(sql: postgres.Sql, text: string) {
  const month = (shift: number) => {
    const [year, number] = dayOf("today").split("-").map(Number);
    const at = new Date(Date.UTC(year, number - 1 + shift, 1));
    return at.toISOString().slice(0, 7);
  };
  const days = text
    .replaceAll(/\{month:(today|next|after next)\}/g, (_, which) =>
      month({ "after next": 2, next: 1, today: 0 }[which as "today"]),
    )
    .replaceAll(/\{day:([^{}"]+)\}/g, (_, day) => dayOf(day))
    .replaceAll(/\{at:([^{}"]+)\}/g, (_, at) => iso(instant(at)));
  return filled(sql, days);
}

// Unwraps each { untrusted: true, text } and drops the keys named, at any depth.
export function plain(value: unknown, drop: string[] = []): unknown {
  if (Array.isArray(value)) return value.map((item) => plain(item, drop));
  if (!value || typeof value !== "object") return value;
  const record = value as Record<string, unknown>;
  if (record.untrusted === true && "text" in record) return record.text;

  return Object.fromEntries(
    Object.entries(record)
      .filter(([key]) => !drop.includes(key))
      .map(([key, item]) => [key, plain(item, drop)]),
  );
}

export async function insertTimedTask(sql: postgres.Sql, row: Row) {
  const id = await insertTask(sql, row);
  const times = {
    ...(row.made && { created_at: instant(row.made) }),
    ...(row.closed && { completed_at: instant(row.closed) }),
    ...(row.changed && { updated_at: instant(row.changed) }),
  };
  if (Object.keys(times).length) await sql`UPDATE tasks SET ${sql(times)} WHERE id = ${id}`;
  return id;
}

export const providerOf = (url: string) => (url.includes("linear.app") ? "linear" : "github");

export async function insertSource(sql: postgres.Sql, row: Row) {
  const url = row.url ?? "https://github.com/aaronmallen/aaronmallen.me/issues/1";
  await sql`
    INSERT INTO task_sources ${sql({
      checked_at: row.checked ? instant(row.checked) : null,
      provider: providerOf(url),
      remote_id: row.remote || url,
      remote_state: row.state || "open",
      seen_at: row.seen ? instant(row.seen) : null,
      task_id: await taskId(sql, row.task ?? ""),
      url,
    })}
  `;
}

export async function insertComment(sql: postgres.Sql, row: Row) {
  const synced = row.url
    ? { author: row.author || null, provider: providerOf(row.url), remote_id: row.url, url: row.url }
    : {};
  await sql`
    INSERT INTO task_comments ${sql({
      body: row.body ?? "A comment",
      created_at: row.at ? instant(row.at) : new Date(),
      task_id: await taskId(sql, row.task ?? ""),
      updated_at: row.changed ? instant(row.changed) : row.at ? instant(row.at) : new Date(),
      ...synced,
    })}
  `;
}
