// e2e: сайт маҳаллий (127.0.0.1/Tamir-Test/), база — маҳаллий Postgres (setup-db.sh). Test/prod Supabase ишлатилмайди.
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "tests",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : "list",
  use: {
    baseURL: "http://127.0.0.1:4173/Tamir-Test/",
    locale: "ru-RU",
    serviceWorkers: "block",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "mobile", use: { ...devices["Pixel 7"] } },
    { name: "desktop", use: { ...devices["Desktop Chrome"] } },
  ],
  webServer: { command: "node serve.mjs", url: "http://127.0.0.1:4173/Tamir-Test/", reuseExistingServer: !process.env.CI },
});
