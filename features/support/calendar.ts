import type postgres from "postgres";

export const zone = "America/Chicago";

const dayMs = 24 * 60 * 60 * 1000;

const isoOf = (at: Date) => at.toISOString().slice(0, 10);

const utcDay = (iso: string) => new Date(`${iso}T12:00:00Z`);

export const shiftDay = (iso: string, days: number) => isoOf(new Date(utcDay(iso).getTime() + days * dayMs));

export const today = () => new Intl.DateTimeFormat("en-CA", { timeZone: zone }).format(new Date());

// A day after today whose next day still falls in this month, so both show in one month view.
function soon() {
  const now = today();
  if (shiftDay(now, 2).slice(0, 7) === now.slice(0, 7)) return shiftDay(now, 1);

  return `${shiftDay(`${now.slice(0, 7)}-28`, 7).slice(0, 7)}-01`;
}

// Reads "today", "today + 3", "soon - 1" or "2026-07-14 + 1" as an ISO day in the owner's zone.
export function dayOf(text: string) {
  const match = /^(today|soon|\d{4}-\d{2}-\d{2})(?:\s*([+-])\s*(\d+))?$/.exec(text.trim());
  if (!match) throw new Error(`no day reads ${text}`);

  const [, base, sign, count] = match;
  const start = base === "today" ? today() : base === "soon" ? soon() : base;
  return shiftDay(start, sign ? Number(`${sign}${count}`) : 0);
}

function offsetMinutes(at: Date) {
  const parts = new Intl.DateTimeFormat("en-US", {
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
    minute: "2-digit",
    month: "2-digit",
    second: "2-digit",
    timeZone: zone,
    year: "numeric",
  }).formatToParts(at);
  const part = (type: string) => Number(parts.find((found) => found.type === type)?.value);
  const local = Date.UTC(part("year"), part("month") - 1, part("day"), part("hour"), part("minute"), part("second"));

  return (local - at.getTime()) / 60000;
}

// The instant a wall clock reads on a day in the owner's zone.
export function zoned(day: string, clock: string) {
  const [hour, minute] = clock.split(":").map(Number);
  const [year, month, date] = day.split("-").map(Number);
  const guess = Date.UTC(year, month - 1, date, hour, minute);
  const first = new Date(guess - offsetMinutes(new Date(guess)) * 60000);

  return new Date(guess - offsetMinutes(first) * 60000);
}

// An instant as the app's JSON writes it, with no milliseconds.
export const iso = (at: Date) => at.toISOString().replace(/\.\d{3}Z$/, "Z");

export const minutesFromNow = (minutes: number) => new Date(Date.now() + minutes * 60000);

const formats: Record<string, Intl.DateTimeFormatOptions> = {
  full: { day: "numeric", month: "long", weekday: "long", year: "numeric" },
  medium: { day: "numeric", month: "short", year: "numeric" },
  month: { month: "long", year: "numeric" },
  short: { day: "numeric", month: "short" },
};

export const formatDay = (iso: string, format: string) =>
  new Intl.DateTimeFormat("en-US", { ...formats[format], timeZone: "UTC" }).format(utcDay(iso));

const lookups: Record<string, (sql: postgres.Sql, key: string) => Promise<postgres.Row[]>> = {
  calendar: (sql, name) => sql`SELECT id FROM calendars WHERE name = ${name}`,
  connection: (sql, account) => sql`SELECT id FROM service_connections WHERE account_id = ${account}`,
  event: (sql, title) => sql`SELECT id FROM calendar_events WHERE title = ${title}`,
  post: (sql, title) => sql`SELECT id FROM posts WHERE title = ${title}`,
  social: (sql, body) => sql`SELECT social_post_id AS id FROM social_post_parts WHERE body = ${body}`,
  sprint: (sql, day) => sql`SELECT id FROM sprints WHERE sprint_date = ${dayOf(day)}`,
  task: (sql, title) => sql`SELECT id FROM tasks WHERE title = ${title}`,
};

// Fills <today + 3>, <today + 3 medium>, <today at 09:00>, <event Standup> and the like.
export async function expand(sql: postgres.Sql, text: string) {
  const tokens = [...text.matchAll(/<([^<>]+)>/g)];
  let filled = text;

  for (const [token, inner] of tokens) {
    const [kind, ...rest] = inner.split(" ");
    let value: string;

    if (lookups[kind]) {
      const [row] = await lookups[kind](sql, rest.join(" "));
      if (!row) throw new Error(`no ${kind} called ${rest.join(" ")}`);
      value = String(row.id);
    } else {
      const [, day, format, clock] = /^(.*?)(?: (full|medium|month|short)| at (\d{1,2}:\d{2}))?$/.exec(inner) ?? [];
      value = clock ? iso(zoned(dayOf(day), clock)) : format ? formatDay(dayOf(day), format) : dayOf(day);
    }
    filled = filled.replace(token, value);
  }
  return filled;
}

const slug = (text: string) => text.toLowerCase().replaceAll(/\W+/g, "-");

export async function insertCalendar(
  sql: postgres.Sql,
  {
    account,
    hidden = false,
    name,
    writable = true,
  }: { account: string; hidden?: boolean; name: string; writable?: boolean },
) {
  const [taken] = await sql`SELECT 1 FROM calendars WHERE google_id = ${account}`;
  const google_id = taken ? slug(name) : account;

  await sql`INSERT INTO calendars ${sql({ account, google_id, hidden, name, writable })}`;
}

export type EventFields = {
  attendees?: string[];
  calendar: string;
  ends_at?: Date | null;
  ends_on: string;
  google_id?: string;
  link?: string;
  meet_url?: string;
  notes?: string;
  place?: string;
  recurring_id?: string;
  starts_at?: Date | null;
  starts_on: string;
  title: string;
};

export async function insertEvent(sql: postgres.Sql, { calendar, ...fields }: EventFields) {
  const [found] = await sql`SELECT id FROM calendars WHERE name = ${calendar}`;
  if (!found) throw new Error(`no calendar called ${calendar}`);

  await sql`
    INSERT INTO calendar_events ${sql({ calendar_id: found.id, google_id: slug(fields.title), ...fields })}
  `;
}

export async function insertDatedPost(sql: postgres.Sql, title: string, status: string, at: Date) {
  const body = `A post called ${title}.`;

  await sql`
    INSERT INTO posts ${sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: at,
      read_time: 1,
      slug: slug(title),
      status,
      title,
      webmentions_enabled: false,
      word_count: body.split(" ").length,
    })}
  `;
}

export async function insertSocialPost(sql: postgres.Sql, body: string, status: string, at: Date) {
  const [{ id }] = await sql`
    INSERT INTO social_posts (posted_at, status, targets) VALUES (${at}, ${status}, '{mastodon}') RETURNING id
  `;
  await sql`INSERT INTO social_post_parts ${sql({ body, position: 1, social_post_id: id })}`;
}

export async function insertSprintTask(sql: postgres.Sql, day: string, title: string, status: string) {
  const [sprint] = await sql`SELECT id FROM sprints WHERE sprint_date = ${day}`;
  const sprintId = sprint?.id ?? (await sql`INSERT INTO sprints (sprint_date) VALUES (${day}) RETURNING id`)[0].id;
  const closed = status === "done" || status === "canceled";
  const [{ next }] = await sql`SELECT coalesce(max(position), 0) + 1 AS next FROM tasks`;

  await sql`
    INSERT INTO tasks ${sql({
      completed_at: closed ? new Date() : null,
      position: next,
      sprint_id: sprintId,
      status,
      title,
    })}
  `;
}
