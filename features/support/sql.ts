import { createHash } from "node:crypto";

const seconds: Record<string, number> = { day: 86400, hour: 3600, minute: 60, second: 1, week: 604800 };

export function literal(value: string) {
  if (value === "null") return "NULL";
  if (value === '""') return "''";
  if (value.startsWith("(")) return value;
  if (value === "now") return `'${new Date().toISOString()}'`;
  const chicagoDay = "((now() AT TIME ZONE 'America/Chicago')::date)";
  if (value === "today") return chicagoDay;
  const day = value.match(/^the day (\d+) days? ago$/);
  if (day) return `(${chicagoDay} - ${Number(day[1])})`;
  const at = value.match(/^(today|(\d+) days? ago) at (\d{2}:\d{2})$/);
  if (at) return `((${chicagoDay} - ${Number(at[2] ?? 0)} + time '${at[3]}') AT TIME ZONE 'America/Chicago')`;
  const ago = value.match(/^(\d+) (day|hour|minute|second|week)s? (ago|from now)$/);
  if (ago) {
    const shift = Number(ago[1]) * seconds[ago[2]] * 1000 * (ago[3] === "ago" ? -1 : 1);
    return `'${new Date(Date.now() + shift).toISOString()}'`;
  }
  const digest = value.match(/^sha256 of (.+)$/);
  if (digest) return `'${createHash("sha256").update(digest[1]).digest("hex")}'`;
  return `'${value.replaceAll("'", "''")}'`;
}

export const insertRows = async (
  sql: { unsafe: (query: string) => Promise<unknown> },
  table: string,
  rows: Record<string, string>[],
) => {
  for (const row of rows) {
    const columns = Object.keys(row).filter((column) => row[column] !== "");
    const values = columns.map((column) => literal(row[column]));
    await sql.unsafe(
      columns.length
        ? `INSERT INTO ${table} (${columns.join(", ")}) VALUES (${values.join(", ")})`
        : `INSERT INTO ${table} DEFAULT VALUES`,
    );
  }
};
