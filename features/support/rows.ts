import type postgres from "postgres";

type Post = { publishedAt: Date; status: "published" | "scheduled"; title: string; webmentions?: boolean };

export const slugFor = (title: string) => title.toLowerCase().replaceAll(/\W+/g, "-");

export async function insertPost(sql: postgres.Sql, { publishedAt, status, title, webmentions = false }: Post) {
  const body = `A post called ${title}.`;
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
