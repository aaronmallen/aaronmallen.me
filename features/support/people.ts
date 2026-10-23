import type postgres from "postgres";
import { seal } from "./seal.ts";

const lists = ["emails", "phones", "addresses", "websites", "chats", "dates", "relations", "custom_fields"];

export type PersonFields = Record<string, unknown>;

export async function insertPerson(sql: postgres.Sql, fields: PersonFields) {
  const row: Record<string, unknown> = { ...fields };
  for (const list of lists) if (list in row) row[list] = sql.json(row[list] as postgres.JSONValue);
  const [person] = await sql`INSERT INTO people ${sql(row)} RETURNING *`;
  return person;
}

export async function personNamed(sql: postgres.Sql, name: string) {
  const [person] = await sql`SELECT * FROM people WHERE name = ${name} OR company = ${name} ORDER BY id LIMIT 1`;
  if (!person) throw new Error(`no contact is named ${name}`);
  return person;
}

export async function googleConnection(sql: postgres.Sql, account: string) {
  const [connection] =
    await sql`SELECT * FROM service_connections WHERE provider = 'google' AND account_id = ${account}`;
  if (!connection) throw new Error(`no Google account ${account}`);
  return connection;
}

export async function connectSocial(sql: postgres.Sql, network: "bluesky" | "mastodon") {
  const row =
    network === "bluesky"
      ? {
          account_id: "did:plc:owner",
          credentials: { app_password: "secret", handle: "owner.example" },
          label: "@owner.example",
        }
      : {
          account_id: "1",
          credentials: { access_token: "token" },
          host: "203.0.113.5",
          label: "@owner@203.0.113.5",
          scopes: ["write:statuses", "write:media", "read:accounts", "read:search", "read:statuses"],
        };
  await sql`
    INSERT INTO service_connections ${sql({ ...row, credentials: seal(JSON.stringify(row.credentials)), provider: network })}
  `;
}
