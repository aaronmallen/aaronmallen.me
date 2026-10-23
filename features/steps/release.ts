import { chmod, mkdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { expect } from "@playwright/test";
import { run, type Shell } from "../support/shell.ts";
import { Given, Then, When } from "../support/world.ts";

const compare = "https://github.com/aaronmallen/aaronmallen.me/compare";

async function sh(shell: Shell, command: string) {
  const { output, status } = await run(command, { cwd: join(shell.dir, "repo"), env: shell.env });
  if (status !== 0) throw new Error(`${command} failed:\n${output}`);
  return output.trim();
}

const git = (shell: Shell, args: string) =>
  sh(shell, `git -c user.name=Spec -c user.email=spec@example.com -c tag.gpgSign=false ${args}`);

const release = (shell: Shell, args: string) =>
  run(`"$ROOT/scripts/release" ${args}`, { cwd: join(shell.dir, "repo"), env: shell.env });

async function setUp(shell: Shell) {
  const bin = join(shell.dir, "bin");
  await mkdir(bin, { recursive: true });
  await mkdir(join(shell.dir, "repo"));
  await writeFile(join(bin, "gh"), '#!/bin/sh\ncat "$(dirname "$0")/ci"\n');
  await chmod(join(bin, "gh"), 0o755);
  await writeFile(join(bin, "ci"), "passed");
  Object.assign(shell.env, {
    GIT_COMMITTER_EMAIL: "spec@example.com",
    GIT_COMMITTER_NAME: "Spec",
    GIT_CONFIG_GLOBAL: "/dev/null",
    GIT_CONFIG_NOSYSTEM: "1",
    JJ_CONFIG: join(shell.dir, "jj.toml"),
    JJ_EMAIL: "spec@example.com",
    JJ_USER: "Spec",
    PATH: `${bin}:${shell.env.PATH}`,
  });
}

async function initGit(shell: Shell) {
  await setUp(shell);
  await git(shell, "init --quiet");
  await git(shell, "config tag.gpgSign true");
}

async function commit(shell: Shell, message: string) {
  await git(shell, "add --all");
  await git(shell, `commit --quiet --allow-empty --message '${message}'`);
  return git(shell, "rev-parse HEAD");
}

function changelog(shell: Shell, version: string, { unreleased = "", links = "" } = {}) {
  const linked = links || `[Unreleased]: ${compare}/${version}...HEAD\n[${version}]: ${compare}/26.9.4...${version}`;
  return writeFile(
    join(shell.dir, "repo/CHANGELOG.md"),
    `# Changelog\n\n## [Unreleased]\n${unreleased}\n## [${version}] - 2026-10-14\n\n### Fixed\n\n- Something.\n\n${linked}\n`,
  );
}

async function tags(shell: Shell) {
  return git(shell, "tag --list");
}

Given("a git repo", async ({ shell }) => {
  await initGit(shell);
});

Given("a git repo tagged {string}", async ({ shell }, names: string) => {
  await initGit(shell);
  await writeFile(join(shell.dir, "repo/a.txt"), "Initial commit");
  await commit(shell, "Initial commit");
  for (const name of names.split(", ").filter(Boolean)) await git(shell, `tag --annotate ${name} --message ${name}`);
});

Given("a git repo with the changelog for {string} under two empty commits", async ({ shell }, version: string) => {
  await initGit(shell);
  await changelog(shell, version);
  await writeFile(join(shell.dir, "repo/a.txt"), "Add the changelog");
  shell.env.TARGET = await commit(shell, "Add the changelog");
  await commit(shell, "Empty");
  await commit(shell, "Also empty");
});

Given("a jj repo with the changelog for {string} under an empty commit", async ({ shell }, version: string) => {
  await setUp(shell);
  await sh(shell, "jj git init --colocate --quiet");
  await changelog(shell, version);
  await sh(shell, "jj commit --quiet --message 'Add the changelog'");
  await sh(shell, "jj commit --quiet --message 'Empty'");
  shell.env.TARGET = await sh(shell, "jj log --no-graph -r @-- -T commit_id");
});

Given("a git repo with specs that name two migrations", async ({ shell }) => {
  await initGit(shell);
  await changelog(shell, "26.10.0");
  const repo = join(shell.dir, "repo");
  await mkdir(join(repo, "config/db/migrate"), { recursive: true });
  await mkdir(join(repo, "spec/db"), { recursive: true });
  await writeFile(join(repo, "config/db/migrate/20261001000000_add_tasks.rb"), "Add a migration");
  shell.env.MIGRATION = await commit(shell, "Add a migration");
  await writeFile(join(repo, "config/db/migrate/20261002000000_add_tags.rb"), "Add another");
  await commit(shell, "Add another");
  await writeFile(join(repo, "spec/db/tasks_spec.rb"), "config/db/migrate/20261001000000_add_tasks.rb");
  await writeFile(join(repo, "spec/db/tags_spec.rb"), "20261002000000");
  await commit(shell, "Add the specs");
});

Given("the tag {string} on the commit that adds the first migration", async ({ shell }, name: string) => {
  await git(shell, `tag --annotate ${name} --message ${name} ${shell.env.MIGRATION}`);
});

Given("the changelog for {string}", async ({ shell }, version: string) => {
  await changelog(shell, version);
});

Given("the changelog for {string} with entries under [Unreleased]", async ({ shell }, version: string) => {
  await changelog(shell, version, { unreleased: "\n### Added\n\n- Something new.\n" });
});

Given("the changelog for {string} with the links:", async ({ shell }, version: string, links: string) => {
  await changelog(shell, version, { links });
});

Given("I commit the changes as {string}", async ({ shell }, message: string) => {
  await commit(shell, message);
});

Given("the repo has a remote", async ({ shell }) => {
  await run(`git init --quiet --bare ${join(shell.dir, "remote.git")}`, { env: shell.env });
  await git(shell, `remote add origin ${join(shell.dir, "remote.git")}`);
});

Given("the target carries the tag {string}", async ({ shell }, name: string) => {
  await git(shell, `tag --annotate ${name} --message ${name} ${shell.env.TARGET ?? "HEAD"}`);
});

Given("CI reports {string}", async ({ shell }, state: string) => {
  const ci = join(shell.dir, "bin/ci");
  await (state === "unreadable" ? rm(ci) : writeFile(ci, state));
});

Given("gh cannot read CI", async ({ shell }) => {
  await rm(join(shell.dir, "bin/ci"));
});

When("I release with {string}", async ({ shell }, args: string) => {
  Object.assign(shell, await release(shell, args));
});

Then("the next version on {string} is {string}", async ({ shell }, date: string, version: string) => {
  const { output } = await release(shell, `--dry-run ${date}`);

  expect(output.split("\n")[0]).toBe(version);
});

Then("the next version with no date is the first of this UTC month", async ({ shell }) => {
  const { output } = await release(shell, "--dry-run");
  const now = new Date();

  expect(output.split("\n")[0]).toBe(`${now.getUTCFullYear() % 100}.${now.getUTCMonth() + 1}.0`);
});

Then("the release refuses, saying {string}", async ({ shell }, reason: string) => {
  const before = await tags(shell);
  const { output, status } = await release(shell, "2026-10-14");

  expect(status, output).not.toBe(0);
  expect(output).toContain(reason);
  expect(await tags(shell)).toBe(before);
});

Then("{string} is an annotated tag on the target", async ({ shell }, name: string) => {
  expect(await git(shell, `cat-file -t ${name}`)).toBe("tag");
  expect(await git(shell, `rev-parse ${name}^{commit}`)).toBe(shell.env.TARGET);
});

Then("the tag {string} says {string} and carries no signature", async ({ shell }, name: string, message: string) => {
  expect(await git(shell, `tag --list --format=%\\(contents\\) ${name}`)).toBe(message);
  expect(await git(shell, `cat-file -p ${name}`)).not.toContain("SIGNATURE");
});

Then("the remote holds no tags", async ({ shell }) => {
  expect(await git(shell, "ls-remote --tags origin")).toBe("");
});

Then("the repo has no tags", async ({ shell }) => {
  expect(await tags(shell)).toBe("");
});

Then("the dry run prints {string}, the target and {string}", ({ shell }, version: string, ci: string) => {
  expect(shell.output.trimEnd().split("\n")).toEqual([version, shell.env.TARGET, ci]);
});

Then("the output includes {string} and the target", ({ shell }, text: string) => {
  expect(shell.output).toContain(`${text} ${shell.env.TARGET}.`);
});

Then("the output ends with {string}", ({ shell }, line: string) => {
  expect(shell.output.trimEnd().split("\n").at(-1)).toBe(line);
});

Then("the output ends with:", ({ shell }, text: string) => {
  expect(`\n${shell.output.trimEnd()}`.endsWith(`\n${text}`), shell.output).toBe(true);
});
