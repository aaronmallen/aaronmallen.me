import type postgres from "postgres";
import { seal } from "./social.ts";
import type { Sent, Stub } from "./stub.ts";

export type Heard = Omit<Sent, "body"> & { body: string };

export const heard = (stub: Stub): Heard[] => stub.requests().map((sent) => ({ ...sent, body: sent.body.toString() }));

export const passwords = new Map<string, string>();

type Connection = {
  account_id: string;
  credentials: object;
  host?: string;
  label: string;
  provider: string;
  scopes?: string[];
};

export async function connect(sql: postgres.Sql, { credentials, scopes = [], ...row }: Connection) {
  await sql`INSERT INTO service_connections ${sql({ ...row, credentials: seal(credentials), scopes })}`;
}

export async function reseal(sql: postgres.Sql, id: number, credentials: object) {
  await sql`UPDATE service_connections SET credentials = ${seal(credentials)} WHERE id = ${id}`;
}

export async function insertSocialPost(
  sql: postgres.Sql,
  { parts, postedAt, targets }: { parts: string[]; postedAt: Date; targets: string },
) {
  const [{ id }] = await sql`
    INSERT INTO social_posts ${sql({ posted_at: postedAt, status: "scheduled", targets: `{${targets.split(" ").join(",")}}` })}
    RETURNING id
  `;
  for (const [index, body] of parts.entries()) {
    await sql`INSERT INTO social_post_parts ${sql({ body, position: index + 1, social_post_id: id })}`;
  }
}

export const heardAt = (stub: Stub, method: string, path: string): Heard[] =>
  heard(stub).filter((request) => request.method === method && request.url.pathname.endsWith(path));

export const json = (request: Heard) => JSON.parse(request.body);

export const records = (stub: Stub) => heardAt(stub, "POST", "/xrpc/com.atproto.repo.putRecord").map(json);
