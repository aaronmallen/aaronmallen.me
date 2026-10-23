import { createHash, randomBytes } from "node:crypto";
import { gzipSync } from "node:zlib";

const zone = "America/Chicago";
const day = 86_400_000;
const parts = new Intl.DateTimeFormat("en-CA", {
  day: "2-digit",
  hour: "2-digit",
  hourCycle: "h23",
  minute: "2-digit",
  month: "2-digit",
  second: "2-digit",
  timeZone: zone,
  year: "numeric",
});
const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const token =
  /^(today|month|first|monday|sunday|fallback|edge)([+-]\d+)?(?:\s+(\d\d:\d\d|short|last|first)([+-]\d+)?)?$/;

export const sha = (text: string) => createHash("sha256").update(text).digest("hex");

export const unique = () => randomBytes(8).toString("hex");

function local(at: Date) {
  const found = Object.fromEntries(parts.formatToParts(at).map(({ type, value }) => [type, value]));
  return { day: `${found.year}-${found.month}-${found.day}`, time: `${found.hour}:${found.minute}` };
}

function shift(date: string, days: number) {
  return new Date(Date.parse(`${date}T00:00:00Z`) + days * day).toISOString().slice(0, 10);
}

function shiftMonth(date: string, count: number) {
  const [year, month] = date.split("-").map(Number);
  const first = new Date(Date.UTC(year, month - 1 + count, 1));
  return first.toISOString().slice(0, 10);
}

const weekday = (date: string) => new Date(`${date}T00:00:00Z`).getUTCDay();

export const today = () => local(new Date()).day;

export const dayOf = (at: Date) => local(at).day;

export function chicago(date: string, time = "12:00") {
  const [year, month, dayOfMonth] = date.split("-").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  for (const offset of [5, 6]) {
    const at = new Date(Date.UTC(year, month - 1, dayOfMonth, hour + offset, minute));
    const seen = local(at);
    if (seen.day === date && seen.time === time) return at;
  }
  return new Date(Date.UTC(year, month - 1, dayOfMonth, hour + 6, minute));
}

export function iso(at: Date) {
  const seen = local(at);
  const offset = Math.round((Date.parse(`${seen.day}T${seen.time}:00Z`) - at.getTime()) / 60_000);
  const sign = offset < 0 ? "-" : "+";
  const hours = String(Math.floor(Math.abs(offset) / 60)).padStart(2, "0");
  const minutes = String(Math.abs(offset) % 60).padStart(2, "0");
  return `${seen.day}T${seen.time}:${String(at.getUTCSeconds()).padStart(2, "0")}${sign}${hours}:${minutes}`;
}

function base(name: string) {
  const now = today();
  if (name === "today") return now;
  if (name === "month" || name === "first") return `${now.slice(0, 8)}01`;
  if (name === "monday") return shift(now, -((weekday(now) + 6) % 7));
  if (name === "sunday") return shift(now, -(weekday(now) || 7));
  if (name === "edge") return shift(now, shift(now, -91).endsWith("-01") ? -90 : -91);
  let found = now;
  while (!(found.slice(5, 7) === "11" && weekday(found) === 0 && Number(found.slice(8)) <= 7)) found = shift(found, 1);
  return found;
}

export function when(text: string): string | undefined {
  const found = token.exec(text.trim());
  if (!found) return;
  const [, name, step, suffix, after] = found;
  const date = name === "month" ? shiftMonth(base(name), Number(step ?? 0)) : shift(base(name), Number(step ?? 0));
  if (!suffix) return date;
  if (suffix === "short") return `${months[Number(date.slice(5, 7)) - 1]} ${Number(date.slice(8))}`;
  if (suffix === "first") return shift(`${date.slice(0, 8)}01`, Number(after ?? 0));
  if (suffix === "last") return shift(shift(shiftMonth(`${date.slice(0, 8)}01`, 1), -1), Number(after ?? 0));
  return iso(chicago(date, suffix));
}

export const fill = (text: string) => text.replaceAll(/\{([^{}"]+)\}/g, (whole, inner) => when(inner) ?? whole);

const mmdbMarker = Buffer.concat([Buffer.from([0xab, 0xcd, 0xef]), Buffer.from("MaxMind.com")]);
const countryNames: Record<string, string> = { DE: "Germany", GB: "United Kingdom", US: "United States" };

export const countryNetworks: Record<string, { city?: string; country?: string }> = {
  "1.2.3.0/24": { country: "US" },
  "2001:db8::/32": { country: "DE" },
  "81.2.69.0/24": { city: "London", country: "GB" },
  "198.51.100.0/24": { city: "Nowhere" },
};

function control(type: number, size: number) {
  const [marker, extra] =
    size < 29
      ? [size, Buffer.alloc(0)]
      : size < 285
        ? [29, Buffer.from([size - 29])]
        : [30, Buffer.from([(size - 285) >> 8, (size - 285) & 0xff])];
  return Buffer.concat([Buffer.from(type < 8 ? [(type << 5) | marker] : [marker, type - 7]), extra]);
}

function encode(value: unknown): Buffer {
  if (Array.isArray(value)) return Buffer.concat([control(11, value.length), ...value.map(encode)]);
  if (typeof value === "number") {
    const number = Buffer.alloc(4);
    number.writeUInt32BE(value);
    return Buffer.concat([control(6, 4), number]);
  }
  if (value && typeof value === "object") {
    const pairs = Object.entries(value);
    return Buffer.concat([control(7, pairs.length), ...pairs.flatMap(([key, inner]) => [encode(key), encode(inner)])]);
  }
  const text = Buffer.from(String(value));
  return Buffer.concat([control(2, text.length), text]);
}

function networkBits(network: string) {
  const [address, prefix] = network.split("/");
  let bits: number[];
  if (address.includes(":")) {
    const [head, tail = ""] = address.split("::");
    const groups = (part: string) => part.split(":").filter(Boolean);
    const words = [...groups(head), ...Array(8 - groups(head).length - groups(tail).length).fill("0"), ...groups(tail)];
    bits = words.flatMap((word) => [...Number.parseInt(word, 16).toString(2).padStart(16, "0")].map(Number));
  } else {
    const octets = address.split(".").flatMap((octet) => [...Number(octet).toString(2).padStart(8, "0")].map(Number));
    bits = [...Array(96).fill(0), ...octets];
  }
  return bits.slice(0, (address.includes(":") ? 0 : 96) + Number(prefix));
}

type Node = [number | { offset: number } | null, number | { offset: number } | null];

export function countryDatabase(networks = countryNetworks) {
  const nodes: Node[] = [[null, null]];
  const offsets = new Map<string, number>();
  const section: Buffer[] = [];
  let length = 0;
  for (const [network, { city, country }] of Object.entries(networks)) {
    const record: Record<string, unknown> = {};
    if (city) record.city = { names: { en: city } };
    if (country) record.country = { iso_code: country, names: { en: countryNames[country] ?? country } };
    const key = JSON.stringify(record);
    if (!offsets.has(key)) {
      offsets.set(key, length);
      const encoded = encode(record);
      section.push(encoded);
      length += encoded.length;
    }
    const path = networkBits(network);
    let node = 0;
    path.forEach((bit, depth) => {
      if (depth === path.length - 1) nodes[node][bit] = { offset: offsets.get(key) ?? 0 };
      else {
        if (typeof nodes[node][bit] !== "number") {
          nodes[node][bit] = nodes.length;
          nodes.push([null, null]);
        }
        node = nodes[node][bit] as number;
      }
    });
  }
  const tree = Buffer.alloc(nodes.length * 8);
  nodes.flat().forEach((entry, index) => {
    const value = entry === null ? nodes.length : typeof entry === "number" ? entry : nodes.length + 16 + entry.offset;
    tree.writeUInt32BE(value, index * 4);
  });
  const metadata = {
    binary_format_major_version: 2,
    binary_format_minor_version: 0,
    build_epoch: 1_789_000_000,
    database_type: "GeoLite2-City",
    description: { en: "A database built for the features" },
    ip_version: 6,
    languages: ["en"],
    node_count: nodes.length,
    record_size: 32,
  };
  return Buffer.concat([tree, Buffer.alloc(16), ...section, mmdbMarker, encode(metadata)]);
}

export function tarball(bytes: Buffer, name = "GeoLite2-City_20260928/GeoLite2-City.mmdb") {
  const header = Buffer.alloc(512);
  const field = (text: string, at: number, size: number) =>
    header.write(text.padEnd(size, "\0").slice(0, size), at, "ascii");
  field(name, 0, 100);
  field("0000644", 100, 8);
  field("0000000", 108, 8);
  field("0000000", 116, 8);
  field(bytes.length.toString(8).padStart(11, "0"), 124, 12);
  field("00000000000", 136, 12);
  field("        ", 148, 8);
  field("0", 156, 1);
  field("ustar", 257, 6);
  field("00", 263, 2);
  const sum = header.reduce((total, byte) => total + byte, 0);
  field(`${sum.toString(8).padStart(6, "0")}\0 `, 148, 8);
  const padding = Buffer.alloc((512 - (bytes.length % 512)) % 512);
  return gzipSync(Buffer.concat([header, bytes, padding, Buffer.alloc(1024)]));
}
