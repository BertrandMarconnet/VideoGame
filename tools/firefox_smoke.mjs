import { firefox } from "playwright";
import { PNG } from "pngjs";
import fs from "node:fs";

const targetUrl = process.env.BLACKOUT_TEST_URL ?? "http://127.0.0.1:8080/";
const consoleLines = [];
const runtimeErrors = [];
let markReady;
let markFailed;
const runtimeReady = new Promise((resolve, reject) => {
  markReady = resolve;
  markFailed = reject;
});
const timeout = setTimeout(() => {
  markFailed(new Error("BLACKOUT_RUNTIME_READY was not emitted within 120 seconds"));
}, 120_000);

const browser = await firefox.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("console", (message) => {
  const line = `[${message.type()}] ${message.text()}`;
  consoleLines.push(line);
  if (message.text().includes("BLACKOUT_RUNTIME_READY")) {
    clearTimeout(timeout);
    markReady();
  }
  if (message.type() === "error") {
    runtimeErrors.push(line);
  }
});
page.on("pageerror", (error) => {
  const line = `[pageerror] ${error.stack ?? error.message}`;
  consoleLines.push(line);
  runtimeErrors.push(line);
});
page.on("crash", () => {
  runtimeErrors.push("[crash] Firefox page crashed");
  markFailed(new Error("Firefox page crashed"));
});

try {
  await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 120_000 });
  await runtimeReady;
  await page.waitForTimeout(2_000);
  const canvas = page.locator("canvas").first();
  if ((await canvas.count()) === 0) {
    throw new Error("Godot canvas was not created");
  }
  const bounds = await canvas.boundingBox();
  if (!bounds || bounds.width < 640 || bounds.height < 360) {
    throw new Error(`Unexpected canvas bounds: ${JSON.stringify(bounds)}`);
  }
  const screenshot = await page.screenshot({ path: "build/firefox-smoke.png", fullPage: true });
  const png = PNG.sync.read(screenshot);
  let visiblePixels = 0;
  let luminanceSum = 0;
  let luminanceSquaredSum = 0;
  const pixelCount = png.width * png.height;
  for (let index = 0; index < png.data.length; index += 4) {
    const red = png.data[index];
    const green = png.data[index + 1];
    const blue = png.data[index + 2];
    const luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
    luminanceSum += luminance;
    luminanceSquaredSum += luminance * luminance;
    if (luminance > 32) {
      visiblePixels += 1;
    }
  }
  const mean = luminanceSum / pixelCount;
  const variance = luminanceSquaredSum / pixelCount - mean * mean;
  const visibleRatio = visiblePixels / pixelCount;
  consoleLines.push(`[visual] mean=${mean.toFixed(2)} variance=${variance.toFixed(2)} visibleRatio=${visibleRatio.toFixed(4)}`);
  if (visibleRatio < 0.006 || variance < 8.0) {
    throw new Error(`Firefox rendered an effectively black frame: visibleRatio=${visibleRatio}, variance=${variance}`);
  }
  const state = await page.evaluate(() => {
    const canvasElement = document.querySelector("canvas");
    return {
      title: document.title,
      canvasWidth: canvasElement?.width ?? 0,
      canvasHeight: canvasElement?.height ?? 0,
      visibility: document.visibilityState,
      bodyText: document.body.innerText.slice(0, 500),
    };
  });
  consoleLines.push(`[state] ${JSON.stringify(state)}`);
  if (runtimeErrors.length > 0) {
    throw new Error(`Firefox emitted runtime errors:\n${runtimeErrors.join("\n")}`);
  }
} finally {
  fs.mkdirSync("build", { recursive: true });
  fs.writeFileSync("build/firefox-console.log", `${consoleLines.join("\n")}\n`);
  await browser.close();
}
