import { type ChildProcess, spawn } from "node:child_process";
import { resolve } from "node:path";

export type Shell = {
  children: ChildProcess[];
  dir: string;
  env: NodeJS.ProcessEnv;
  output: string;
  status: number | null;
};

export const root = resolve(import.meta.dirname, "../..");

export function run(command: string, { cwd = root, env = process.env, input = "" } = {}) {
  return new Promise<{ output: string; status: number | null }>((done, fail) => {
    const child = spawn("sh", ["-c", command], { cwd, env, stdio: [input ? "pipe" : "ignore", "pipe", "pipe"] });
    let output = "";
    child.stdout.on("data", (chunk) => {
      output += chunk;
    });
    child.stderr.on("data", (chunk) => {
      output += chunk;
    });
    child.on("error", fail);
    child.on("close", (status) => done({ output, status }));
    child.stdin?.on("error", () => {});
    child.stdin?.end(input);
  });
}
