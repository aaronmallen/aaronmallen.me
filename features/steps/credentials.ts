import { createHash, randomBytes, randomUUID } from "node:crypto";
import type { DataTable } from "playwright-bdd";
import { literal } from "../support/sql.ts";
import { Given } from "../support/world.ts";

const digest = (value: string) => createHash("sha256").update(value).digest("hex");

Given("an API token {string}", async ({ app }, name: string) => {
  await app.sql`INSERT INTO api_tokens ${app.sql({ name, token_digest: digest(randomBytes(32).toString("hex")) })}`;
});

Given("an MCP client {string} with a live token", async ({ app }, name: string) => {
  const [client] = await app.sql`
    INSERT INTO oauth_clients ${app.sql({
      client_id: randomUUID(),
      client_name: name || null,
      grant_types: ["authorization_code", "refresh_token"],
      redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
      response_types: ["code"],
      visitor_hash: digest(`registrant-${name}`),
    })}
    RETURNING id
  `;
  await app.sql`
    INSERT INTO oauth_tokens ${app.sql({
      expires_at: new Date(Date.now() + 3600_000),
      oauth_client_id: client.id,
      token_digest: digest(randomBytes(32).toString("hex")),
      type: "access",
    })}
  `;
});

const tokenKinds: Record<string, { expires_at: string; revoked_at?: string; type: string }> = {
  access: { expires_at: "1 hour from now", type: "access" },
  "expired access": { expires_at: "1 second ago", type: "access" },
  refresh: { expires_at: "30 days from now", type: "refresh" },
  "revoked access": { expires_at: "1 hour from now", revoked_at: "now", type: "access" },
};

Given("the MCP clients:", async ({ app }, table: DataTable) => {
  for (const [index, row] of table.hashes().entries()) {
    const redirect = (row.redirect || "https://claude.ai/api/mcp/auth_callback").replace("SITE", app.url);
    const [client] = await app.sql.unsafe(`
      INSERT INTO oauth_clients
        (client_id, client_name, redirect_uris, grant_types, response_types, visitor_hash, created_at, last_used_at)
      VALUES (
        ${literal(row.client_id || randomUUID())}, ${row.name ? literal(row.name) : "NULL"}, ARRAY[${literal(redirect)}],
        '{authorization_code,refresh_token}', '{code}', ${literal(digest(`registrant-${index}`))},
        ${literal(row.connected || "now")}, ${row["last used"] ? literal(row["last used"]) : "NULL"}
      )
      RETURNING id
    `);
    for (const kind of (row.tokens ?? "access").split(", ").filter((name) => name && name !== "none")) {
      const token = tokenKinds[kind];
      await app.sql.unsafe(`
        INSERT INTO oauth_tokens (oauth_client_id, type, token_digest, expires_at, revoked_at, scopes)
        VALUES (${client.id}, '${token.type}', ${literal(digest(randomBytes(16).toString("hex")))},
          ${literal(token.expires_at)}, ${token.revoked_at ? literal(token.revoked_at) : "NULL"},
          ${literal(`{${row.scopes ?? "read"}}`)})
      `);
    }
    for (let code = 0; code < Number(row.codes ?? 0); code++) {
      await app.sql.unsafe(`
        INSERT INTO oauth_codes (oauth_client_id, code_digest, redirect_uri, code_challenge, expires_at)
        VALUES (${client.id}, ${literal(digest(randomBytes(16).toString("hex")))}, ${literal(redirect)},
          '${"a".repeat(43)}', ${literal("1 minute from now")})
      `);
    }
  }
});
