import type postgres from "postgres";

type Post = {
  body?: string;
  publishedAt: Date;
  status: "published" | "scheduled";
  title: string;
  webmentions?: boolean;
};

export const slugFor = (title: string) => title.toLowerCase().replaceAll(/\W+/g, "-");

export async function insertPost(
  sql: postgres.Sql,
  { body = "", publishedAt, status, title, webmentions = false }: Post,
) {
  body ||= `A post called ${title}.`;
  await sql`
    INSERT INTO posts ${sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: publishedAt,
      read_time: 1,
      slug: slugFor(title),
      status,
      title,
      webmentions_enabled: webmentions,
      word_count: body.split(" ").length,
    })}
  `;
}

const units: Record<string, number> = {
  day: 86_400_000,
  hour: 3_600_000,
  minute: 60_000,
  second: 1000,
  week: 604_800_000,
};

export function cell(value: string): string | boolean | Date | null {
  if (value === "null") return null;
  if (value === "true" || value === "false") return value === "true";
  if (value === "now") return new Date();
  const ago = value.match(/^(\d+) (second|minute|hour|day|week)s? ago$/);
  if (ago) return new Date(Date.now() - Number(ago[1]) * units[ago[2]]);
  const ahead = value.match(/^in (\d+) (second|minute|hour|day|week)s?$/);
  if (ahead) return new Date(Date.now() + Number(ahead[1]) * units[ahead[2]]);
  return value;
}

const defaults: Record<string, (row: Record<string, unknown>) => Record<string, unknown>> = {
  posts: (row) => {
    const title = String(row.title ?? "Untitled");
    const body = String(row.body ?? `A post called ${title}.`);
    return {
      body,
      body_html: `<p>${body}</p>`,
      read_time: 1,
      slug: slugFor(title),
      status: "draft",
      title,
      webmentions_enabled: false,
      word_count: body.split(/\s+/).length,
    };
  },
};

export async function insertRows(sql: postgres.Sql, table: string, rows: Record<string, string>[]) {
  for (const row of rows) {
    const values = Object.fromEntries(Object.entries(row).map(([column, value]) => [column, cell(value)]));
    await sql`INSERT INTO ${sql(table)} ${sql({ ...defaults[table]?.(values), ...values })}`;
  }
}
