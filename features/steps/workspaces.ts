import { mkdir } from "node:fs/promises";
import { join } from "node:path";
import { expect } from "@playwright/test";
import type { DataTable } from "playwright-bdd";
import { run, type Shell } from "../support/shell.ts";
import { Given, Then, When } from "../support/world.ts";

async function psql(shell: Shell, statements: string[]) {
  const commands = statements.map((statement) => `-c "${statement}"`).join(" ");
  const { output, status } = await run(`scripts/util/psql -d postgres -At ${commands}`, { env: shell.env });
  if (status !== 0) throw new Error(output);
  return output.trim();
}

const prefixOf = (env: NodeJS.ProcessEnv) => `blog_prune_ws${env.WORKSPACE_ID ?? 0}_w${env.TEST_ENV_NUMBER}`;

Given("the workspace {int} has a directory", async ({ shell }, id: number) => {
  shell.env.WORKTREES_DIR = join(shell.dir, "worktrees");
  await mkdir(join(shell.env.WORKTREES_DIR, `ws${id}`), { recursive: true });
});

Given("these test databases under a scratch prefix:", async ({ shell }, table: DataTable) => {
  shell.env.DATABASE_NAME = prefixOf(shell.env);
  const names = table.hashes().map(({ name }) => `${shell.env.DATABASE_NAME}_${name}`);
  await psql(
    shell,
    names.flatMap((name) => [`drop database if exists ${name}`, `create database ${name}`]),
  );
});

When("I prune the workspaces", async ({ shell }) => {
  Object.assign(shell, await run("scripts/dev/prune-workspaces", { env: shell.env }));
});

Then("it lists the test databases {string}", ({ shell }, names: string) => {
  const prefix = `${shell.env.DATABASE_NAME}_`;

  expect(shell.output.split(/\s+/).filter(Boolean).sort()).toEqual(names.split(", ").map((name) => prefix + name));
});

Then("the test databases left are {string}", async ({ shell }, names: string) => {
  const prefix = `${shell.env.DATABASE_NAME}_`;
  const left = (await psql(shell, [`select datname from pg_database where datname like '${prefix}%'`])).split("\n");
  await psql(
    shell,
    left.map((name) => `drop database ${name}`),
  );

  expect(left.map((name) => name.slice(prefix.length)).sort()).toEqual(names.split(", "));
});
