import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

export default defineConfig({
  forbidOnly: Boolean(process.env.CI),
  fullyParallel: true,
  reporter: process.env.CI ? "github" : "list",
  testDir: defineBddConfig({ features: "**/*.feature", steps: ["steps/*.ts", "support/world.ts"] }),
  use: { trace: "retain-on-failure" },
});
