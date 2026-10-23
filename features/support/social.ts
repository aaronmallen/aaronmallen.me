import { createCipheriv, hkdfSync, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "@playwright/test";
import type postgres from "postgres";
import { cell } from "./rows.ts";

export const statuses = new WeakMap<Page, number>();

export function expand(text: string, site: string) {
  return text
    .replaceAll("{site}", site)
    .replaceAll(/\{([^{}"]+?)\*(\d+)\}/g, (_, unit: string, times: string) => unit.repeat(Number(times)))
    .replaceAll("\\n", "\n")
    .replaceAll("\\r", "\r");
}

export const split = (text: string) => (text === "" ? [] : text.split(" // "));

const dataKey = readFileSync(resolve(import.meta.dirname, "../../config/settings/test.yml"), "utf8").match(
  /^data_key: (.+)$/m,
)?.[1] as string;

export function seal(credentials: object) {
  const key = Buffer.from(hkdfSync("sha256", dataKey, "", "blog-encryptor", 32));
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const body = Buffer.concat([cipher.update(JSON.stringify(credentials)), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), body]).toString("base64");
}

const secrets: Record<string, (label: string) => object> = {
  bluesky: (label) => ({ app_password: "app-password", handle: label.slice(1) }),
  linkedin: () => ({ access_token: "li-token", expires_at: Math.floor(Date.now() / 1000) + 3600 }),
  mastodon: () => ({ access_token: "masto-token" }),
};

export async function connect(
  sql: postgres.Sql,
  provider: string,
  { host = null, label }: { host?: string | null; label: string },
) {
  const scopes =
    provider === "mastodon"
      ? "{write:statuses,write:media,read:accounts,read:search,read:statuses}"
      : provider === "linkedin"
        ? "{openid,profile,w_member_social}"
        : "{}";
  await sql`
    INSERT INTO service_connections ${sql({
      account_id: `${provider}-${label}`,
      credentials: seal(secrets[provider](label)),
      host,
      label,
      provider,
      scopes,
    })}
  `;
}

export async function accountIds(sql: postgres.Sql, names: string) {
  const ids: string[] = [];
  for (const name of names.split(",").map((part) => part.trim())) {
    if (name === "") continue;
    if (/^\d+$/.test(name)) {
      ids.push(name);
      continue;
    }
    const [row] = await sql`SELECT id FROM service_connections WHERE provider = ${name} ORDER BY id LIMIT 1`;
    ids.push(String(row.id));
  }
  return ids;
}

export async function insertSocialPost(sql: postgres.Sql, row: Record<string, string>, site = "") {
  const status = row.status ?? "draft";
  const at = row.at ? cell(row.at) : status === "draft" ? null : new Date(Date.now() + 86_400_000);
  const [made] = await sql`
    INSERT INTO social_posts ${sql({
      connection_ids: `{${row.accounts ?? ""}}`,
      created_at: row.created ? cell(row.created) : new Date(),
      post_id: row.post ? Number(row.post) : null,
      posted_at: at,
      status,
      targets: `{${row.targets ?? "mastodon"}}`,
    })}
    RETURNING id
  `;
  const parts = split(row.text ?? "a social post");
  for (const [index, body] of parts.entries()) {
    await sql`
      INSERT INTO social_post_parts ${sql({ body: expand(body, site), position: index + 1, social_post_id: made.id })}
    `;
  }
}

export async function submitForm(page: Page, action: string, fields: [string, string][]) {
  if (!(await page.locator("input[name='_csrf_token']").count())) await page.goto("/admin/social");
  const token = await page.locator("input[name='_csrf_token']").first().inputValue();
  const navigation = page.waitForNavigation();
  await page.evaluate(
    ([target, pairs]) => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = target;
      for (const [name, value] of pairs) {
        const field = document.createElement("textarea");
        field.name = name;
        field.value = value;
        form.append(field);
      }
      form.hidden = true;
      document.body.append(form);
      form.submit();
    },
    [action, [["_csrf_token", token], ...fields]] as [string, [string, string][]],
  );
  const response = await navigation;
  statuses.set(page, response?.status() ?? 0);
}
