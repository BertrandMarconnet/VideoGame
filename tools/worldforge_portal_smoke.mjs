import { firefox } from "playwright";
import fs from "node:fs";

const baseUrl = (process.env.BLACKOUT_TEST_URL ?? "http://127.0.0.1:8080/").replace(/\?.*$/, "");
const portalUrl = new URL("developer.html", baseUrl).href;
const expectedSeed = "19870922";
const consoleLines = [];
const runtimeErrors = [];
let runtimeReady = false;
let editorOpened = false;
let launchOptionsReceived = false;

const browser = await firefox.launch({
  headless: process.env.BLACKOUT_FIREFOX_HEADLESS !== "0",
  env: {
    ...process.env,
    LIBGL_ALWAYS_SOFTWARE: process.env.LIBGL_ALWAYS_SOFTWARE ?? "1",
    MOZ_WEBRENDER: process.env.MOZ_WEBRENDER ?? "1",
  },
  firefoxUserPrefs: {
    "webgl.disabled": false,
    "webgl.force-enabled": true,
    "webgl.enable-webgl2": true,
    "gfx.webrender.software": true,
  },
});

const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await context.newPage();
page.on("console", (message) => {
  const text = message.text();
  consoleLines.push(`[${message.type()}] ${text}`);
  if (text.includes("BLACKOUT_RUNTIME_READY")) runtimeReady = true;
  if (text.includes("WORLDFORGE_EDITOR_OPENED_FROM_WEB")) editorOpened = true;
  if (text.includes("WORLDFORGE_WEB_LAUNCH") && text.includes(`seed=${expectedSeed}`)) launchOptionsReceived = true;
  const fatalPatterns = ["SCRIPT ERROR", "Invalid call", "Invalid get index", "Attempt to call", "RuntimeError"];
  const fatal = text.trimStart().startsWith("ERROR:") || fatalPatterns.some((pattern) => text.includes(pattern));
  if (message.type() === "error" && fatal) runtimeErrors.push(`[console] ${text}`);
});
page.on("pageerror", (error) => runtimeErrors.push(`[pageerror] ${error.stack ?? error.message}`));

try {
  await page.goto(portalUrl, { waitUntil: "domcontentloaded", timeout: 120_000 });
  await page.waitForSelector("#launchEditor", { state: "visible", timeout: 20_000 });
  const marker = await page.locator('meta[name="theme-color"]').count();
  if (marker < 1) throw new Error("Developer portal did not load its expected document head");
  await page.fill("#seed", expectedSeed);
  await page.screenshot({ path: "build/worldforge-portal.png", fullPage: true });
  await Promise.all([
    page.waitForURL((url) => url.searchParams.get("dev") === "worldforge" && url.searchParams.get("editor") === "1", { timeout: 30_000 }),
    page.click("#launchEditor"),
  ]);
  await page.waitForFunction(() => document.querySelector("canvas") !== null, null, { timeout: 120_000 });
  const deadline = Date.now() + 120_000;
  while (Date.now() < deadline && !(runtimeReady && editorOpened && launchOptionsReceived)) {
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: "build/worldforge-editor-open.png", fullPage: true });
  if (!runtimeReady) throw new Error("Godot runtime did not become ready from the developer portal");
  if (!launchOptionsReceived) throw new Error("WorldForge did not receive the requested seed and editor URL parameters");
  if (!editorOpened) throw new Error("WorldForge editor did not open automatically");
  if (runtimeErrors.length > 0) throw new Error(`Runtime errors detected:\n${runtimeErrors.join("\n")}`);
  consoleLines.push("[portal] one-click developer launch validated");
} finally {
  fs.mkdirSync("build", { recursive: true });
  fs.writeFileSync("build/worldforge-portal-console.log", `${consoleLines.join("\n")}\n`);
  await context.close();
  await browser.close();
}
