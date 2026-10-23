import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { expect } from "@playwright/test";
import { run } from "../support/shell.ts";
import { Given, Then, When } from "../support/world.ts";

Given("the file {string}:", async ({ shell }, path: string, content: string) => {
  const file = join(shell.dir, path);
  await mkdir(dirname(file), { recursive: true });
  await writeFile(file, `${content}\n`);
});

Given("the environment sets {word} to {string}", ({ shell }, name: string, value: string) => {
  shell.env[name] = value;
});

When("I run {string}", async ({ shell }, command: string) => {
  Object.assign(shell, await run(command, { env: shell.env }));
});

When("I run {string} in the scratch folder", async ({ shell }, command: string) => {
  Object.assign(shell, await run(command, { cwd: shell.dir, env: shell.env }));
});

When("I run {string} with:", async ({ shell }, command: string, input: string) => {
  Object.assign(shell, await run(command, { env: shell.env, input }));
});

Then("it succeeds", ({ shell }) => {
  expect(shell.status, shell.output).toBe(0);
});

Then("it fails", ({ shell }) => {
  expect(shell.status, shell.output).not.toBe(0);
});

Then("it exits with status {int}", ({ shell }, status: number) => {
  expect(shell.status, shell.output).toBe(status);
});

Then("the output includes {string}", ({ shell }, text: string) => {
  expect(shell.output).toContain(text);
});

Then("the output does not include {string}", ({ shell }, text: string) => {
  expect(shell.output).not.toContain(text);
});

Then("the output is:", ({ shell }, text: string) => {
  expect(shell.output.trimEnd()).toBe(text);
});
