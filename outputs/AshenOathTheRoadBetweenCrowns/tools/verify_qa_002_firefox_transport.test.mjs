import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import vm from "node:vm";
import { measureFirefoxContentMemory } from "./firefox_content_memory.mjs";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const context = vm.createContext({
  WebSocket: class {}, structuredClone, setTimeout, clearTimeout, Date, JSON,
  CDP_EVALUATE_TIMEOUT_MS: 10000, OBSERVATION_WAIT_MS: 900,
});
vm.runInContext(`${source.slice(source.indexOf("class Cdp {"), source.indexOf("function loadingTimeline(cdp)"))}
globalThis.FirefoxTransport = FirefoxTransport;`, context);

function fakePage() {
  const page = new EventEmitter();
  page.calls = [];
  page.keyboard = {
    down: async (key) => page.calls.push(["keyDown", key]),
    up: async (key) => page.calls.push(["keyUp", key]),
  };
  page.mouse = {
    move: async (x, y) => page.calls.push(["move", x, y]),
    down: async (options) => page.calls.push(["mouseDown", options.button]),
    up: async (options) => page.calls.push(["mouseUp", options.button]),
  };
  page.setViewport = async (value) => page.calls.push(["viewport", value.width, value.height]);
  page.exposeFunction = async (name, callback) => { page.bindingName = name; page.binding = callback; };
  page.goto = async (url) => page.calls.push(["navigate", url]);
  page.bringToFront = async () => page.calls.push(["foreground"]);
  page.evaluate = async (expression) => expression === "7 * 6" ? 42 : null;
  page.screenshot = async () => Buffer.from("png");
  page.evaluateOnNewDocument = async () => {};
  return page;
}

test("Firefox transport preserves real input order and viewport", async () => {
  const page = fakePage();
  const transport = new context.FirefoxTransport(page);
  await transport.open();
  await transport.send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1 });
  await transport.send("Input.dispatchKeyEvent", { type: "keyDown", key: "w" });
  await transport.send("Input.dispatchKeyEvent", { type: "keyUp", key: "w" });
  await transport.send("Input.dispatchMouseEvent", { type: "mousePressed", x: 20, y: 30, button: "left" });
  await transport.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 20, y: 30, button: "left" });
  assert.deepEqual(page.calls.map((call) => call[0]), [
    "viewport", "keyDown", "keyUp", "move", "mouseDown", "move", "mouseUp",
  ]);
  assert.equal((await transport.send("Runtime.evaluate", { expression: "7 * 6" })).result.value, 42);
  await transport.send("Page.navigate", { url: "about:blank" });
  assert.deepEqual(page.calls.at(-1), ["navigate", "about:blank"]);
});

test("Firefox observation and console/network events are recorded", async () => {
  const page = fakePage();
  const transport = new context.FirefoxTransport(page);
  await transport.open();
  await transport.send("Runtime.addBinding", { name: "__ASHEN_OATH_READ_ONLY_OBSERVATION__" });
  page.binding(JSON.stringify({ zone: "greyfen" }));
  assert.equal(transport.takeObservation().zone, "greyfen");
  page.emit("console", { type: () => "error", text: () => "resource missing" });
  page.emit("pageerror", new Error("script failed"));
  const request = { url: () => "http://127.0.0.1/index.pck", failure: () => null };
  page.emit("request", request);
  page.emit("response", { request: () => request, url: request.url, status: () => 200 });
  page.emit("requestfinished", request);
  assert.equal(transport.events.filter((event) => event.method === "Network.loadingFinished").length, 1);
  assert.equal(transport.events.filter((event) => event.method === "Runtime.consoleAPICalled").length, 1);
  assert.equal(transport.events.filter((event) => event.method === "Runtime.exceptionThrown").length, 1);
});

test("Firefox transport rejects unsupported protocol commands", async () => {
  const transport = new context.FirefoxTransport(fakePage());
  await transport.open();
  await assert.rejects(transport.send("Profiler.start"), /does not support Profiler.start/);
  assert.equal(transport.transportSummary().methods["Profiler.start"].failed, 1);
});

test("live Firefox BiDi adapter accepts pointer input and read-only observation", {
  skip: !process.env.ASHENOATH_FIREFOX_LIVE_PROBE,
  timeout: 45000,
}, async () => {
  const { default: puppeteer } = await import("puppeteer-core");
  const root = "D:\\Temp\\AshenOath";
  mkdirSync(root, { recursive: true });
  const profile = mkdtempSync(join(root, "qa002-firefox-live-"));
  let browser;
  try {
    browser = await puppeteer.launch({
      browser: "firefox", executablePath: process.env.FIREFOX_EXE,
      headless: true, userDataDir: profile, args: ["--no-remote", "--new-instance"],
    });
    const page = (await browser.pages())[0] || await browser.newPage();
    const transport = new context.FirefoxTransport(page);
    await transport.open();
    await transport.send("Page.navigate", { url: "data:text/html,<body></body>" });
    await transport.send("Runtime.addBinding", { name: "__ASHEN_OATH_READ_ONLY_OBSERVATION__" });
    await transport.send("Page.addScriptToEvaluateOnNewDocument", {
      source: readFileSync(new URL("./firefox_audio_context_probe.js", import.meta.url), "utf8"),
    });
    const html = '<body style="margin:0"><button id="go" style="width:100px;height:50px" '
      + 'onclick="document.title=\'clicked\';window.__ASHEN_OATH_READ_ONLY_OBSERVATION__(JSON.stringify({zone:\'greyfen\'}));'
      + 'window.__qaAudio = new AudioContext();window.__qaAudio.resume()">Go</button></body>';
    await transport.send("Page.navigate", { url: `data:text/html,${encodeURIComponent(html)}` });
    await transport.send("Input.dispatchMouseEvent", { type: "mousePressed", x: 50, y: 25, button: "left" });
    await transport.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 50, y: 25, button: "left" });
    assert.equal(await transport.evaluate("document.title"), "clicked");
    assert.equal((await transport.waitForObservation(3000))?.zone, "greyfen");
    let audioTimeline = [];
    for (let attempt = 0; attempt < 20; attempt++) {
      audioTimeline = await transport.evaluate("window.__ASHEN_QA_AUDIO_TIMELINE__ || []");
      if (audioTimeline.some((item) => item.state === "running")) break;
      await new Promise((done) => setTimeout(done, 100));
    }
    assert.deepEqual(audioTimeline.map((item) => item.state), ["suspended", "running"]);
    const memory = measureFirefoxContentMemory(browser.process().pid, profile);
    assert.equal(memory.method, "isolated_content_process_private_upper_bound");
    assert.ok(memory.content_process_count >= 1);
    assert.ok(memory.content_private_mb > 0);
    assert.ok((await transport.send("Page.captureScreenshot", { format: "png" })).data.length > 100);
    transport.close();
  } finally {
    if (browser) await browser.close();
    const resolved = realpathSync(profile);
    assert.ok(resolved.toLowerCase().startsWith(`${root.toLowerCase()}\\`));
    rmSync(resolved, { recursive: true, force: true });
  }
});
