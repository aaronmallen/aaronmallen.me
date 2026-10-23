import { createDecipheriv, hkdfSync } from "node:crypto";
import type postgres from "postgres";
import { seal } from "./seal.ts";

const dataKey = "test-data-key-not-a-real-secret-do-not-use-this-one-in-production";
const key = Buffer.from(hkdfSync("sha256", dataKey, "", "blog-encryptor", 32));

export function unseal(text: string) {
  const raw = Buffer.from(text, "base64");
  const decipher = createDecipheriv("aes-256-gcm", key, raw.subarray(0, 12));
  decipher.setAuthTag(raw.subarray(12, 28));
  return Buffer.concat([decipher.update(raw.subarray(28)), decipher.final()]).toString();
}

type Connection = {
  accountId: string;
  credentials: Record<string, unknown>;
  host?: string;
  label: string;
  lapsesAt?: Date;
  lastUsedAt?: Date;
  provider: string;
  revokedAt?: Date;
  scopes?: string[];
};

export async function insertConnection(sql: postgres.Sql, connection: Connection) {
  const [{ id }] = await sql`
    INSERT INTO service_connections ${sql({
      account_id: connection.accountId,
      credentials: seal(JSON.stringify(connection.credentials)),
      host: connection.host ?? null,
      label: connection.label,
      lapses_at: connection.lapsesAt ?? null,
      last_used_at: connection.lastUsedAt ?? null,
      provider: connection.provider,
      revoked_at: connection.revokedAt ?? null,
      scopes: connection.scopes ?? [],
    })}
    RETURNING id
  `;
  return id as number;
}

export async function connectionsFor(sql: postgres.Sql, provider: string) {
  const rows = await sql`SELECT * FROM service_connections WHERE provider = ${provider} ORDER BY id`;
  return rows.map((row) => ({ ...row, opened: JSON.parse(unseal(row.credentials)) }));
}
