import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { root, run } from "../support/shell.ts";
import { Given, When } from "../support/world.ts";

const secrets = ["ANALYTICS_SALT", "APP_SECRET", "DATA_KEY", "READER_SALT"];

Given("the app runs in {word} with secrets of its own", async ({ app, shell }, environment: string) => {
  const [{ name }] = await app.sql`SELECT current_database() AS name`;
  Object.assign(shell.env, { HANAMI_ENV: environment, PREVIOUS_DATA_KEY: "" });
  if (environment !== "test") shell.env.DATABASE_NAME = name;
  for (const secret of secrets) shell.env[secret] = `${secret.toLowerCase()}-`.padEnd(64, "x");
});

Given("the setting {word} is {string}", async ({ shell }, name: string, value: string) => {
  const repeated = value.match(/^(\d+) × (.)$/);
  const committed = value.match(/^committed for (\w+)$/);
  if (value === "unset") {
    delete shell.env[name];
  } else if (repeated) {
    shell.env[name] = repeated[2].repeat(Number(repeated[1]));
  } else if (committed) {
    const file = await readFile(join(root, `config/settings/${committed[1]}.yml`), "utf8");
    shell.env[name] = file.match(new RegExp(`^${name.toLowerCase()}: (.+)$`, "m"))?.[1];
  } else {
    shell.env[name] = value.startsWith("$") ? shell.env[value.slice(1)] : value;
  }
});

When("I start the app", async ({ shell }) => {
  Object.assign(shell, await run("scripts/db/console 'select 1'", { env: shell.env }));
});
