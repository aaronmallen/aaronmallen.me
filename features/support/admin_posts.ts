import { createHash } from "node:crypto";
import type postgres from "postgres";
import { cell, slugFor } from "./rows.ts";

export { seal } from "./social.ts";

const day = 86_400_000;

export const hashOf = (text: string) => createHash("sha256").update(text).digest("hex");

export function chicagoDay(daysAgo = 0) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Chicago" }).format(new Date(Date.now() - daysAgo * day));
}

export function dayCell(value: string) {
  if (value === "today") return chicagoDay();
  const ago = value.match(/^(\d+) days? ago$/);
  return ago ? chicagoDay(Number(ago[1])) : value;
}

export async function postId(sql: postgres.Sql, title: string) {
  const [row] = await sql`SELECT id FROM posts WHERE title = ${title}`;
  if (!row) throw new Error(`no post titled ${title}`);
  return row.id as number;
}

export async function tagPost(sql: postgres.Sql, id: number, names: string[]) {
  for (const name of names) {
    const [tag] = await sql`
      INSERT INTO tags (name, color, scope) VALUES (${name}, 'mk-green', 'public')
      ON CONFLICT DO NOTHING RETURNING id
    `;
    const tagId = tag?.id ?? (await sql`SELECT id FROM tags WHERE name = ${name} AND scope = 'public'`)[0].id;
    await sql`INSERT INTO post_tags (post_id, tag_id) VALUES (${id}, ${tagId})`;
  }
}

const statusTimes: Record<string, () => Date | null> = {
  draft: () => null,
  published: () => new Date(Date.now() - day),
  scheduled: () => new Date(Date.now() + 3 * day),
};

export async function writePost(sql: postgres.Sql, status: string, title: string, fields: Record<string, string> = {}) {
  const { tags, ...columns } = fields;
  const values = Object.fromEntries(Object.entries(columns).map(([column, value]) => [column, cell(value)]));
  const body = String(values.body ?? `A post called ${title}.`);
  const words = body.split(/\s+/).filter((word) => /\w/.test(word)).length;
  const [row] = await sql`
    INSERT INTO posts ${sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: statusTimes[status](),
      read_time: Math.max(1, Math.round(words / 250)),
      slug: slugFor(title),
      status,
      title,
      webmentions_enabled: false,
      word_count: words,
      ...values,
    })}
    RETURNING id
  `;
  if (tags) await tagPost(sql, row.id, tags.split(/,\s*/));
  return row.id as number;
}
