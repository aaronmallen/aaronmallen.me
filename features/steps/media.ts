import type { DataTable } from "playwright-bdd";
import { Given } from "../support/world.ts";
import { when } from "./public.ts";

Given("the media store is the stub", ({ app, shell }) => {
  Object.assign(shell.env, {
    MEDIA_STORE_ACCESS_KEY: "access-key",
    MEDIA_STORE_PORT: new URL(app.stub.url).port,
    MEDIA_STORE_SECRET_KEY: "secret-key",
  });
});

Given("the store holds {string} as {string}", ({ stub }, key: string, body: string) => {
  const headers = { "Content-Length": String(Buffer.byteLength(body)), "Content-Type": "image/jpeg" };
  stub.reply("GET", `/blog-development/${key}`, { body, headers, status: 200 });
  stub.reply("HEAD", `/blog-development/${key}`, { body, headers, status: 200 });
});

Given("the store has no {string}", ({ stub }, key: string) => {
  const body = "<Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message></Error>";
  for (const method of ["GET", "HEAD"]) {
    stub.reply(method, `/blog-development/${key}`, {
      body,
      headers: { "Content-Type": "application/xml" },
      status: 404,
    });
  }
});

Given("the photo {string} is claimed by:", async ({ app }, key: string, table: DataTable) => {
  const [photo] = await app.sql`SELECT id FROM photos WHERE key = ${key}`;
  for (const { owner, record } of table.hashes()) {
    const id = await ownerId(app.sql, owner, record);
    await app.sql`INSERT INTO photo_claims ${app.sql({ owner, owner_id: id, photo_id: photo.id })}`;
  }
});

async function ownerId(sql: import("postgres").Sql, owner: string, record: string) {
  if (owner === "post") return (await sql`SELECT id FROM posts WHERE title = ${record}`)[0].id;
  if (owner === "task") return (await sql`SELECT id FROM tasks WHERE title = ${record}`)[0]?.id ?? Number(record);
  if (owner === "task_comment") {
    return (
      await sql`SELECT task_comments.id FROM task_comments JOIN tasks ON tasks.id = task_id WHERE tasks.title = ${record}`
    )[0].id;
  }
  const [entry] = await sql`
    INSERT INTO journal_entries (entry_date, entry_time, body, body_html) VALUES (${when("now")}, '12:00', ${record}, ${record}) RETURNING id
  `;
  return entry.id;
}

Given("the store answers only a HEAD for {string} as {string}", ({ stub }, key: string, body: string) => {
  const headers = { "Content-Length": String(Buffer.byteLength(body)), "Content-Type": "image/jpeg" };
  stub.reply("HEAD", `/blog-development/${key}`, { body, headers, status: 200 });
});

Given("the store cannot be reached for {string}", ({ stub }, key: string) => {
  for (const method of ["GET", "HEAD"]) stub.reply(method, `/blog-development/${key}`, { body: "", status: 503 });
});

Given("the photo setup {string}", async ({ app }, owner: string) => {
  const key = "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg";
  const [photo] = await app.sql`SELECT id FROM photos WHERE key = ${key}`;
  const claim = (kind: string, id: number) =>
    app.sql`INSERT INTO photo_claims ${app.sql({ owner: kind, owner_id: id, photo_id: photo.id })}`;
  const project = async (visibility: string, board: boolean) =>
    (
      await app.sql`
        INSERT INTO projects ${app.sql({ board_published: board, name: `p-${visibility}-${board}`, started_on: "2024-01-01", visibility })}
        RETURNING id
      `
    )[0].id;
  const task = async (projectId: number | null) =>
    (
      await app.sql`INSERT INTO tasks ${app.sql({ list: "next", position: 1, project_id: projectId, title: "t" })} RETURNING id`
    )[0].id;
  if (owner === "no record claims it") return;
  if (owner.endsWith("post claims it")) {
    const status = owner.includes("draft") ? "draft" : "scheduled";
    const [post] = await app.sql`
      INSERT INTO posts ${app.sql({
        body: "x",
        body_html: "<p>x</p>",
        published_at: status === "draft" ? null : new Date(Date.now() + 86_400_000),
        read_time: 1,
        slug: status,
        status,
        title: status,
        webmentions_enabled: false,
        word_count: 1,
      })}
      RETURNING id
    `;
    return claim("post", post.id);
  }
  if (owner === "a journal entry claims it") {
    const [entry] = await app.sql`
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html) VALUES (current_date, '12:00', 'x', 'x') RETURNING id
    `;
    return claim("journal_entry", entry.id);
  }
  if (owner === "a task that is gone claims it") return claim("task", 1);
  if (owner === "a task on an unpublished board claims it")
    return claim("task", await task(await project("public", false)));
  if (owner === "a task on a private project's board claims it")
    return claim("task", await task(await project("private", true)));
  if (owner === "a task on no project claims it") return claim("task", await task(null));
  const [comment] = await app.sql`
    INSERT INTO task_comments (task_id, body) VALUES (${await task(await project("public", false))}, 'c') RETURNING id
  `;
  return claim("task_comment", comment.id);
});
