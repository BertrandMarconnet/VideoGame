import { firefox } from "playwright";
import { PNG } from "pngjs";
import fs from "node:fs";

const targetUrl = process.env.BLACKOUT_TEST_URL ?? "http://127.0.0.1:8080/";
const headless = process.env.BLACKOUT_FIREFOX_HEADLESS !== "0";
const consoleLines = [];
const runtimeErrors = [];
let storyboardReady = false;
let storyboardArtReady = false;
let mobileControlsReady = false;
let gameplayStarted = false;
let mobileForwardPressed = false;
let mobileFlashlightPressed = false;
let mobileCrouchPressed = false;
let mobileLookActive = false;
let mobileLookReleased = false;
let markReady;
let markFailed;
const runtimeReady = new Promise((resolve, reject) => {
  markReady = resolve;
  markFailed = reject;
});
const timeout = setTimeout(() => {
  markFailed(new Error("BLACKOUT_RUNTIME_READY was not emitted within 120 seconds"));
}, 120_000);

function analyzeFrame(buffer, label) {
  const png = PNG.sync.read(buffer);
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
    if (luminance > 32) visiblePixels += 1;
  }
  const mean = luminanceSum / pixelCount;
  const variance = luminanceSquaredSum / pixelCount - mean * mean;
  const visibleRatio = visiblePixels / pixelCount;
  consoleLines.push(`[visual:${label}] mean=${mean.toFixed(2)} variance=${variance.toFixed(2)} visibleRatio=${visibleRatio.toFixed(4)}`);
  if (visibleRatio < 0.006 || variance < 8.0) {
    throw new Error(`Firefox rendered an effectively black ${label} frame: visibleRatio=${visibleRatio}, variance=${variance}`);
  }
}

async function dispatchTouchLook(page, startX, startY, endX, endY) {
  await page.evaluate(({ startX, startY, endX, endY }) => {
    const canvas = document.querySelector("canvas");
    if (!canvas) throw new Error("Godot canvas missing during touch sequence");
    const makeTouch = (x, y) => new Touch({
      identifier: 71,
      target: canvas,
      clientX: x,
      clientY: y,
      pageX: x,
      pageY: y,
      screenX: x,
      screenY: y,
      radiusX: 8,
      radiusY: 8,
      rotationAngle: 0,
      force: 0.7,
    });
    const start = makeTouch(startX, startY);
    canvas.dispatchEvent(new TouchEvent("touchstart", {
      touches: [start],
      targetTouches: [start],
      changedTouches: [start],
      bubbles: true,
      cancelable: true,
    }));
    const moved = makeTouch(endX, endY);
    canvas.dispatchEvent(new TouchEvent("touchmove", {
      touches: [moved],
      targetTouches: [moved],
      changedTouches: [moved],
      bubbles: true,
      cancelable: true,
    }));
    canvas.dispatchEvent(new TouchEvent("touchend", {
      touches: [],
      targetTouches: [],
      changedTouches: [moved],
      bubbles: true,
      cancelable: true,
    }));
  }, { startX, startY, endX, endY });
}

const browser = await firefox.launch({
  headless,
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
const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  hasTouch: true,
});
const page = await context.newPage();
page.on("console", (message) => {
  const text = message.text();
  const line = `[${message.type()}] ${text}`;
  consoleLines.push(line);
  if (text.includes("BLACKOUT_RUNTIME_READY")) {
    clearTimeout(timeout);
    markReady();
  }
  if (text.includes("BLACKOUT_STORYBOARD_ACT1_READY")) storyboardReady = true;
  if (text.includes("BLACKOUT_STORYBOARD_ART_V17_READY")) storyboardArtReady = true;
  if (text.includes("BLACKOUT_MOBILE_CONTROLS_READY")) mobileControlsReady = true;
  if (text.includes("BLACKOUT_GAMEPLAY_STARTED")) gameplayStarted = true;
  if (text.includes("BLACKOUT_MOBILE_ACTION_DOWN move_forward")) mobileForwardPressed = true;
  if (text.includes("BLACKOUT_MOBILE_ACTION_DOWN flashlight")) mobileFlashlightPressed = true;
  if (text.includes("BLACKOUT_MOBILE_ACTION_DOWN crouch")) mobileCrouchPressed = true;
  if (text.includes("BLACKOUT_MOBILE_LOOK_ACTIVE")) mobileLookActive = true;
  if (text.includes("BLACKOUT_MOBILE_LOOK_RELEASED")) mobileLookReleased = true;
  const fatalPatterns = [
    "The following features required to run Godot projects",
    "SCRIPT ERROR",
    "Invalid call",
    "Invalid get index",
    "Attempt to call",
    "RuntimeError",
  ];
  const fatalConsoleError = text.trimStart().startsWith("ERROR:") || fatalPatterns.some((pattern) => text.includes(pattern));
  if (message.type() === "error" && fatalConsoleError) runtimeErrors.push(line);
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
  const webgl = await page.evaluate(() => {
    const testCanvas = document.createElement("canvas");
    const context2d = testCanvas.getContext("webgl2");
    if (!context2d) return { available: false };
    return {
      available: true,
      renderer: context2d.getParameter(context2d.RENDERER),
      vendor: context2d.getParameter(context2d.VENDOR),
      version: context2d.getParameter(context2d.VERSION),
      maxTouchPoints: navigator.maxTouchPoints,
    };
  });
  consoleLines.push(`[webgl2] ${JSON.stringify(webgl)}`);
  if (!webgl.available) throw new Error("Firefox test environment does not expose WebGL2");

  await runtimeReady;
  await page.waitForTimeout(2_000);
  const canvas = page.locator("canvas").first();
  if ((await canvas.count()) === 0) throw new Error("Godot canvas was not created");
  const bounds = await canvas.boundingBox();
  if (!bounds || bounds.width < 640 || bounds.height < 360) {
    throw new Error(`Unexpected canvas bounds: ${JSON.stringify(bounds)}`);
  }
  if (!mobileControlsReady) {
    throw new Error(`Mobile controls were not created in touch-enabled Firefox; maxTouchPoints=${webgl.maxTouchPoints}`);
  }

  const menuFrame = await page.screenshot({ path: "build/firefox-smoke.png", fullPage: true });
  analyzeFrame(menuFrame, "menu");
  const state = await page.evaluate(() => {
    const canvasElement = document.querySelector("canvas");
    const compatibilityPanel = document.getElementById("blackout-webgl-error");
    return {
      title: document.title,
      canvasWidth: canvasElement?.width ?? 0,
      canvasHeight: canvasElement?.height ?? 0,
      visibility: document.visibilityState,
      compatibilityPanelVisible: compatibilityPanel ? getComputedStyle(compatibilityPanel).display !== "none" : false,
    };
  });
  consoleLines.push(`[state] ${JSON.stringify(state)}`);
  if (state.compatibilityPanelVisible) throw new Error("Compatibility panel remained visible despite WebGL2 support");

  const campaignStartPositions = [
    [0.22, 0.21],
    [0.18, 0.24],
    [0.27, 0.71],
  ];
  for (const [xRatio, yRatio] of campaignStartPositions) {
    if (storyboardReady) break;
    const x = bounds.x + bounds.width * xRatio;
    const y = bounds.y + bounds.height * yRatio;
    await page.touchscreen.tap(x, y);
    await page.waitForTimeout(350);
    if (!storyboardReady) await page.mouse.click(x, y);
    await page.waitForTimeout(650);
  }
  if (!storyboardReady) throw new Error("The left-aligned campaign button did not initialize Act I");
  if (!storyboardArtReady) throw new Error("Storyboard art pass v17 was not initialized after campaign start");

  const introSkipPositions = [
    [0.59, 0.77],
    [0.64, 0.76],
    [0.68, 0.79],
  ];
  for (const [xRatio, yRatio] of introSkipPositions) {
    if (gameplayStarted) break;
    await page.mouse.click(bounds.x + bounds.width * xRatio, bounds.y + bounds.height * yRatio);
    await page.waitForTimeout(800);
  }
  if (!gameplayStarted) throw new Error("The intro could not be closed to start the touchscreen gameplay test");

  await page.touchscreen.tap(bounds.x + bounds.width * 0.105, bounds.y + bounds.height * 0.749);
  await page.waitForTimeout(250);
  await page.touchscreen.tap(bounds.x + bounds.width * 0.942, bounds.y + bounds.height * 0.821);
  await page.waitForTimeout(250);
  await page.touchscreen.tap(bounds.x + bounds.width * 0.716, bounds.y + bounds.height * 0.821);
  await page.waitForTimeout(500);
  if (!mobileForwardPressed) throw new Error("The direct mobile move_forward control did not emit a touch action");
  if (!mobileFlashlightPressed) throw new Error("The direct mobile flashlight control did not emit a touch action");
  if (!mobileCrouchPressed) throw new Error("The direct mobile crouch control did not emit a touch action");

  await dispatchTouchLook(
    page,
    bounds.x + bounds.width * 0.89,
    bounds.y + bounds.height * 0.50,
    bounds.x + bounds.width * 0.94,
    bounds.y + bounds.height * 0.44,
  );
  await page.waitForTimeout(800);
  if (!mobileLookActive) throw new Error("The right mobile look joystick did not capture its touch identifier");
  if (!mobileLookReleased) throw new Error("The right mobile look joystick did not release its touch identifier");

  const startFrame = await page.screenshot({ path: "build/firefox-after-start.png", fullPage: true });
  analyzeFrame(startFrame, "after-start-mobile-controls-and-art");
  consoleLines.push("[interaction] movement, flashlight, crouch, right look joystick and storyboard art initialized successfully");

  if (runtimeErrors.length > 0) {
    throw new Error(`Firefox emitted runtime errors:\n${runtimeErrors.join("\n")}`);
  }
} finally {
  fs.mkdirSync("build", { recursive: true });
  fs.writeFileSync("build/firefox-console.log", `${consoleLines.join("\n")}\n`);
  await context.close();
  await browser.close();
}
