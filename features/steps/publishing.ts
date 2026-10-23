import { keep } from "../support/api.ts";
import { slugFor } from "../support/rows.ts";
import { Given } from "../support/world.ts";

const day = 86_400_000;

const publishedAt: Record<string, Date | null> = {
  draft: null,
  published: new Date(Date.now() - day / 24),
  scheduled: new Date(Date.now() + day),
};

Given(
  "the {word} post {string} with the body {string} as {string}",
  async ({ app, http }, status: string, title: string, body: string, name: string) => {
    const [post] = await app.sql`
    INSERT INTO posts ${app.sql({
      body,
      body_html: `<p>${body}</p>`,
      published_at: publishedAt[status],
      read_time: 1,
      slug: slugFor(title),
      status,
      title,
      webmentions_enabled: false,
      word_count: body.split(" ").length,
    })}
    RETURNING id
  `;
    keep(http, name, post.id);
  },
);

const publicTag = async (sql: import("postgres").Sql, name: string) => {
  const [found] = await sql`SELECT id FROM tags WHERE name = ${name} AND scope = 'public'`;
  if (found) return found.id as number;
  const [made] = await sql`INSERT INTO tags ${sql({ color: "mk-green", name, scope: "public" })} RETURNING id`;
  return made.id as number;
};

Given(
  "the post {string} carries the tag {string} kept as {string}",
  async ({ app, http }, title: string, tag: string, name: string) => {
    const id = await publicTag(app.sql, tag);
    await app.sql`INSERT INTO post_tags (post_id, tag_id) SELECT id, ${id} FROM posts WHERE title = ${title}`;
    keep(http, name, id);
  },
);

Given(
  "the project {string} carries the tag {string} kept as {string}",
  async ({ app, http }, project: string, tag: string, name: string) => {
    const id = await publicTag(app.sql, tag);
    await app.sql`INSERT INTO project_tags (project_id, tag_id) SELECT id, ${id} FROM projects WHERE name = ${project}`;
    keep(http, name, id);
  },
);

Given(
  "the {word} social post {string} as {string}",
  async ({ app, http }, status: string, text: string, name: string) => {
    const [post] = await app.sql`
    INSERT INTO social_posts (targets, status, posted_at)
    VALUES ('{mastodon}', ${status}, ${status === "draft" ? null : new Date(Date.now() + day)})
    RETURNING id
  `;
    await app.sql`INSERT INTO social_post_parts ${app.sql({ body: text, position: 1, social_post_id: post.id })}`;
    keep(http, name, post.id);
  },
);

Given("a pending webmention on post {string} as {string}", async ({ app, http }, title: string, name: string) => {
  const [mention] = await app.sql`
    INSERT INTO webmentions (post_id, source_url, type)
    SELECT id, 'https://203.0.113.5/reply', 'mention' FROM posts WHERE title = ${title}
    RETURNING id
  `;
  keep(http, name, mention.id);
});

Given("the task {string} sits on the project {string}", async ({ app }, title: string, project: string) => {
  await app.sql`UPDATE tasks SET project_id = (SELECT id FROM projects WHERE name = ${project}) WHERE title = ${title}`;
});

Given("the task {string} syncs from GitHub", async ({ app }, title: string) => {
  await app.sql`
    INSERT INTO task_sources (task_id, provider, remote_id, url)
    SELECT id, 'github', 'aaronmallen/aaronmallen.me#7', 'https://github.com/aaronmallen/aaronmallen.me/issues/7'
    FROM tasks WHERE title = ${title}
  `;
});

Given("I keep the id of the task {string} as {string}", async ({ app, http }, title: string, name: string) => {
  const [task] = await app.sql`SELECT id FROM tasks WHERE title = ${title}`;
  keep(http, name, task.id);
});

Given("I keep the id of the project {string} as {string}", async ({ app, http }, project: string, name: string) => {
  const [found] = await app.sql`SELECT id FROM projects WHERE name = ${project}`;
  keep(http, name, found.id);
});

Given("I keep the id of the series of {string} as {string}", async ({ app, http }, title: string, name: string) => {
  const [series] =
    await app.sql`SELECT s.id FROM task_series s JOIN tasks t ON t.id = s.task_id WHERE t.title = ${title}`;
  keep(http, name, series.id);
});

Given(
  "the {word} post {string} published {int} days ago at {string}",
  async ({ app }, status: string, title: string, days: number, time: string) => {
    const [{ at }] = await app.sql.unsafe(
      `SELECT ((now() AT TIME ZONE 'America/Chicago')::date - ${days} + time '${time}') AT TIME ZONE 'America/Chicago' AS at`,
    );
    await app.sql`
    INSERT INTO posts ${app.sql({ body: "", body_html: "", published_at: at, read_time: 1, slug: slugFor(title), status, title, webmentions_enabled: false, word_count: 0 })}
  `;
  },
);

Given(
  "the {word} social post with the parts {string} as {string}",
  async ({ app, http }, status: string, parts: string, name: string) => {
    const postedAt =
      status === "posted"
        ? new Date(Date.now() - 3_600_000)
        : status === "scheduled"
          ? new Date(Date.now() + 3_600_000)
          : null;
    const [post] = await app.sql`
    INSERT INTO social_posts (targets, status, posted_at) VALUES ('{mastodon}', ${status}, ${postedAt}) RETURNING id
  `;
    const bodies = parts ? (JSON.parse(parts) as string[]) : [];
    for (const [index, body] of bodies.entries()) {
      await app.sql`INSERT INTO social_post_parts ${app.sql({ body, position: index + 1, social_post_id: post.id })}`;
    }
    keep(http, name, post.id);
  },
);
