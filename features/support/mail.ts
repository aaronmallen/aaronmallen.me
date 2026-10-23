import { createHash } from "node:crypto";
import type postgres from "postgres";

export type MailThread = {
  account?: number;
  archived?: boolean;
  category?: string;
  draft?: boolean;
  gmailId?: string;
  important?: boolean;
  receivedAt?: Date;
  sent?: boolean;
  snoozedUntil?: Date;
  starred?: boolean;
  status?: "read" | "spam" | "unread";
  subject: string;
  trashed?: boolean;
};

export type MailMessage = {
  body?: string;
  draft?: boolean;
  fromName?: string;
  gmailId?: string;
  htmlBody?: string;
  receivedAt?: Date;
  replyTo?: string | null;
  subject?: string;
};

let senders = 0;

export async function insertMailAccount(
  sql: postgres.Sql,
  address: string,
  { sends = true, shown = true }: { sends?: boolean; shown?: boolean } = {},
) {
  const [{ id }] = await sql`
    INSERT INTO mail_accounts ${sql({ address, name: address, provider: "gmail", sends, shown })} RETURNING id
  `;
  return id as number;
}

export async function contactFormAccount(sql: postgres.Sql) {
  const [found] = await sql`SELECT id FROM mail_accounts WHERE provider = 'contact_form'`;
  if (found) return found.id as number;

  const [{ id }] = await sql`
    INSERT INTO mail_accounts ${sql({ name: "Contact form", provider: "contact_form" })} RETURNING id
  `;
  return id as number;
}

export async function insertMailMessage(sql: postgres.Sql, threadId: number, message: MailMessage) {
  const [thread] = await sql`
    SELECT t.subject, t.received_at, a.provider FROM mail_threads t
    JOIN mail_accounts a ON a.id = t.mail_account_id WHERE t.id = ${threadId}
  `;
  senders += 1;
  const replyTo = message.replyTo === undefined ? `sender-${senders}@example.com` : message.replyTo;
  const [{ id }] = await sql`
    INSERT INTO mail_messages ${sql({
      body: message.body ?? `A note from sender ${senders}.`,
      draft: message.draft ?? false,
      from_name: message.fromName ?? null,
      gmail_id: message.gmailId ?? null,
      html_body: message.htmlBody ?? null,
      mail_thread_id: threadId,
      received_at: message.receivedAt ?? thread.received_at,
      reply_to: replyTo,
      subject: message.subject ?? thread.subject,
      visitor_hash:
        thread.provider === "contact_form" ? createHash("sha256").update(`sender-${senders}`).digest("hex") : null,
    })} RETURNING id
  `;
  return id as number;
}

export async function insertMailThread(sql: postgres.Sql, thread: MailThread, message: MailMessage = {}) {
  const status = thread.status ?? "unread";
  const [{ id }] = await sql`
    INSERT INTO mail_threads ${sql({
      archived: thread.archived ?? false,
      category: thread.category ?? null,
      draft: thread.draft ?? false,
      gmail_id: thread.gmailId ?? null,
      important: thread.important ?? false,
      mail_account_id: thread.account ?? (await contactFormAccount(sql)),
      marked_spam_at: status === "spam" ? new Date() : null,
      received_at: thread.receivedAt ?? new Date(),
      sent: thread.sent ?? false,
      snoozed_until: thread.snoozedUntil ?? null,
      starred: thread.starred ?? false,
      status,
      subject: thread.subject,
      trashed: thread.trashed ?? false,
    })} RETURNING id
  `;
  await insertMailMessage(sql, id, message);
  return id as number;
}

export async function insertMailLabel(sql: postgres.Sql, account: number, name: string, gmailId = `Label_${name}`) {
  const [found] = await sql`SELECT id FROM mail_labels WHERE mail_account_id = ${account} AND name = ${name}`;
  if (found) return found.id as number;

  const [{ id }] = await sql`
    INSERT INTO mail_labels ${sql({ gmail_id: gmailId, mail_account_id: account, name })} RETURNING id
  `;
  return id as number;
}

export async function labelMailThread(sql: postgres.Sql, threadId: number, name: string) {
  const [{ mail_account_id }] = await sql`SELECT mail_account_id FROM mail_threads WHERE id = ${threadId}`;
  const label = await insertMailLabel(sql, mail_account_id, name);
  await sql`INSERT INTO mail_thread_labels ${sql({ mail_label_id: label, mail_thread_id: threadId })}`;
}

export async function tagMailThread(sql: postgres.Sql, threadId: number, name: string) {
  const [tag] = await sql`
    INSERT INTO tags ${sql({ color: "mk-pink", name, scope: "private" })}
    ON CONFLICT DO NOTHING RETURNING id
  `;
  const id = tag?.id ?? (await sql`SELECT id FROM tags WHERE name = ${name} AND scope = 'private'`)[0].id;
  await sql`INSERT INTO mail_thread_tags ${sql({ mail_thread_id: threadId, tag_id: id })}`;
}

export async function mailThreadId(sql: postgres.Sql, subject: string) {
  const [thread] = await sql`SELECT id FROM mail_threads WHERE subject = ${subject} ORDER BY id`;
  if (!thread) throw new Error(`No mail thread is called ${subject}`);
  return thread.id as number;
}

export async function mailAccountId(sql: postgres.Sql, name: string) {
  if (name.toLowerCase() === "contact form") return contactFormAccount(sql);

  const [account] = await sql`SELECT id FROM mail_accounts WHERE name = ${name}`;
  if (!account) throw new Error(`No mail account is called ${name}`);
  return account.id as number;
}
