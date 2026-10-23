import { randomBytes } from "node:crypto";
import type { createClient } from "redis";

export type Redis = ReturnType<typeof createClient>;

export type Job = Record<string, unknown>;

export const jid = () => randomBytes(12).toString("hex");

const now = () => Date.now() / 1000;

export function job(name: string, args: unknown[] = [], extra: Job = {}): Job {
  return {
    args,
    class: name,
    created_at: now() - 600,
    enqueued_at: now() - 600,
    jid: jid(),
    queue: "parked",
    ...extra,
  };
}

export function failed(name: string, args: unknown[] = [], extra: Job = {}): Job {
  return job(name, args, {
    error_class: "Faraday::TimeoutError",
    error_message: "execution expired",
    failed_at: now() - 300,
    retry_count: 2,
    ...extra,
  });
}

export async function addToSet(redis: Redis, set: string, secondsFromNow: number, entry: Job) {
  await redis.zAdd(set, { score: now() + secondsFromNow, value: JSON.stringify(entry) });
}

export async function addProcess(
  redis: Redis,
  identity: string,
  { busy = 0, beat = 0, concurrency = 10, quiet = false, queues = ["default"], hostname = identity } = {},
) {
  const info = { concurrency, hostname, identity, pid: 4120, queues, started_at: now() - 3600, tag: "" };
  await redis.sAdd("processes", identity);
  await redis.hSet(identity, {
    beat: String(now() - beat),
    busy: String(busy),
    concurrency: String(concurrency),
    info: JSON.stringify(info),
    quiet: String(quiet),
  });
}

export async function addWork(redis: Redis, identity: string, ranFor: number, entry: Job) {
  const work = { payload: JSON.stringify(entry), queue: entry.queue, run_at: Math.floor(now() - ranFor) };
  await redis.hSet(`${identity}:work`, randomBytes(4).toString("hex"), JSON.stringify(work));
}

export async function enqueue(redis: Redis, queue: string, entry: Job) {
  await redis.sAdd("queues", queue);
  await redis.lPush(`queue:${queue}`, JSON.stringify({ ...entry, queue }));
}

export async function realProcesses(redis: Redis) {
  const all = await redis.sMembers("processes");
  return all.filter((identity) => identity.includes(":"));
}
