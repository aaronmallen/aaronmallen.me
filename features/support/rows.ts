import type postgres from "postgres";

type Post = { publishedAt: Date; status: "published" | "scheduled"; title: string };

export async function insertPost(sql: postgres.Sql, { publishedAt, status, title }: Post) {
  const body = `A post called ${title}.`;
  await sql`
    INSERT INTO posts ${sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: publishedAt,
      read_time: 1,
      slug: title.toLowerCase().replaceAll(/\W+/g, "-"),
      status,
      title,
      webmentions_enabled: false,
      word_count: body.split(" ").length,
    })}
  `;
}
