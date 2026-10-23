import { createHmac } from "node:crypto";
import { expect } from "@playwright/test";
import type postgres from "postgres";
import { contactFormAccount, mailThreadId } from "./mail.ts";

type App = { pushJob: (job: string, ...args: unknown[]) => Promise<void>; sql: postgres.Sql };

const zone = "America/Chicago";
const appSecret = "test-app-secret-not-a-real-secret-do-not-use-this-one-in-production";
const day = /^(today|yesterday|(\d+) days? ago)(?: at (\d\d):(\d\d))?$/;

export const gmailPath = (path: string) => `/google/gmail/users/me${path}`;

export const listed = (text: string) => (text === "" ? [] : text.split(", "));

export const escaped = (text: string) =>
  text
    .replaceAll("\\r", "\r")
    .replaceAll("\\n", "\n")
    .replace(/\\u([0-9a-f]{4})/gi, (_, code) => String.fromCharCode(Number.parseInt(code, 16)));

export async function moment(sql: postgres.Sql, text: string): Promise<Date> {
  if (text.includes("T")) return new Date(text);
  const minutes = text.match(/^(\d+) minutes? (ago|from now)$/);
  if (minutes) return new Date(Date.now() + Number(minutes[1]) * 60_000 * (minutes[2] === "ago" ? -1 : 1));
  const found = text.match(day);
  if (!found) throw new Error(`No time reads "${text}"`);
  const back = found[1] === "today" ? 0 : found[1] === "yesterday" ? 1 : Number(found[2]);
  if (!found[3]) return new Date(Date.now() - back * 86_400_000);
  const [{ at }] = await sql`
    SELECT ((now() AT TIME ZONE ${zone})::date - ${back}::int
      + make_interval(hours => ${Number(found[3])}, mins => ${Number(found[4])})) AT TIME ZONE ${zone} AS at
  `;
  return at;
}

export async function fill(sql: postgres.Sql, text: string) {
  let filled = text;
  for (const [match, subject] of text.matchAll(/#\[([^\]]+)\]/g)) {
    filled = filled.replace(match, String(await mailThreadId(sql, subject)));
  }
  for (const [match, back] of text.matchAll(/<today(?:-(\d+))?>/g)) {
    const [{ date }] = await sql`SELECT ((now() AT TIME ZONE ${zone})::date - ${Number(back ?? 0)}::int)::text AS date`;
    filled = filled.replace(match, date);
  }
  return filled;
}

export function unwrap(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(unwrap);
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.untrusted === true && "text" in record) return record.text;
    return Object.fromEntries(Object.entries(record).map(([key, inner]) => [key, unwrap(inner)]));
  }
  return value;
}

export function mcpText(body: string) {
  const json = body.trimStart().startsWith("{") ? body : (body.match(/^data: (.*)$/m)?.[1] ?? "{}");
  const { result, error } = JSON.parse(json);
  return (result?.content?.[0]?.text ?? error?.message ?? "") as string;
}

export function mcpJson(body: string) {
  return unwrap(JSON.parse(mcpText(body))) as Record<string, unknown>;
}

export function contactStamp(at = Date.now() - 60_000) {
  const signature = createHmac("sha256", appSecret).update(`contact-form:${at}`).digest("hex");
  return `${at}--${signature}`;
}

let markers = 0;

export async function settle(app: App) {
  for (let round = 0; round < 2; round += 1) {
    markers += 1;
    const subject = `Settle marker ${markers}`;
    await app.sql`
      INSERT INTO mail_threads ${app.sql({
        mail_account_id: await contactFormAccount(app.sql),
        marked_spam_at: new Date(Date.now() - 90 * 86_400_000),
        status: "spam",
        subject,
      })}
    `;
    await app.pushJob("Mail::Jobs::ReapSpamMessages");
    await expect
      .poll(async () => (await app.sql`SELECT 1 FROM mail_threads WHERE subject = ${subject}`).length, {
        timeout: 30_000,
      })
      .toBe(0);
  }
}

export async function gmailAccount(sql: postgres.Sql, address: string) {
  const [account] = await sql`SELECT * FROM mail_accounts WHERE address = ${address}`;
  return account;
}

export async function gmailThread(sql: postgres.Sql, gmailId: string) {
  const [thread] = await sql`SELECT * FROM mail_threads WHERE gmail_id = ${gmailId}`;
  return thread;
}

export const shown = (value: unknown) =>
  value === null || value === undefined ? "none" : value instanceof Date ? value.toISOString() : String(value);

export function expectShown(value: unknown, wanted: string, field: string) {
  if (wanted === "set") expect(value ?? null, field).not.toBeNull();
  else expect(shown(value), field).toBe(wanted);
}

type Part = { attachment?: string; charset?: string; html?: string; text?: string };

function part(type: string, text: string, charset = "UTF-8", filename = "", partId?: string) {
  const bytes = Buffer.from(text, charset === "ISO-8859-1" ? "latin1" : "utf8");
  return {
    body: { data: bytes.toString("base64url"), size: bytes.length },
    filename,
    headers: [{ name: "Content-Type", value: `${type}; charset="${charset}"` }],
    mimeType: type,
    ...(partId && { partId }),
  };
}

export function gmailParts({ attachment, charset, html, text }: Part) {
  const parts = [];
  if (text !== undefined) parts.push(part("text/plain", text, charset));
  if (html !== undefined) parts.push(part("text/html", html));
  if (attachment !== undefined) {
    const [filename, type] = attachment.split("|");
    parts.push(part(type ?? "application/pdf", "%PDF", "UTF-8", filename, "2"));
  }
  return parts;
}

export function gmailMessage(
  id: string,
  {
    at = new Date(),
    labels = ["INBOX", "UNREAD"],
    parts = gmailParts({ html: "<p>Hello there</p>", text: "Hello there" }),
    from = "Ada Lovelace <ada@example.com>",
    subject = "Engines",
  }: {
    at?: Date;
    from?: string;
    labels?: string[];
    parts?: unknown[];
    subject?: string;
  },
) {
  return {
    id,
    internalDate: String(at.getTime()),
    labelIds: labels,
    payload: {
      headers: [
        { name: "From", value: from },
        { name: "Subject", value: subject },
      ],
      mimeType: "multipart/alternative",
      parts,
    },
  };
}
