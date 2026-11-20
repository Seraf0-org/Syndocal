import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import ts from "typescript";

const require = createRequire(import.meta.url);
const cache = new Map();
const root = resolve(dirname(fileURLToPath(import.meta.url)), "../src");

function load(file) {
  if (cache.has(file)) return cache.get(file);
  const exports = {};
  cache.set(file, exports);
  const js = ts.transpileModule(readFileSync(file, "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  new Function("require", "exports", js)((name) => {
    if (!name.startsWith(".")) return require(name);
    const target = resolve(dirname(file), name.endsWith(".ts") ? name : `${name}.ts`);
    assert.ok(existsSync(target), target);
    return load(target);
  }, exports);
  return exports;
}

const progress = load(resolve(root, "scenePlaybackProgress.ts"));

const baseCue = (extra = {}) => ({
  id: 1,
  cue_list_id: 1,
  cue_number: "1",
  label: "Scene 1",
  fade_ms: 0,
  pre_wait_ms: 0,
  ifcb_timing: { intensity_ms: null, focus_ms: null, color_ms: null, beam_ms: null },
  parts: [],
  mark: false,
  mib_fixture_ids: [],
  palette_targets: [],
  tracking: true,
  notes: "",
  targets: [],
  video_targets: [],
  video_output_targets: [],
  node_graph_targets: [],
  effect_targets: [],
  steps: [],
  child_timeline: null,
  ...extra,
});

const emptyEffects = new Map();

// 1. STATIC scene when settled: no seekbar, only glows active.
const staticSettled = progress.computeScenePlaybackIndicator({
  cue: baseCue(),
  nowMs: 1_500,
  activatedAtMs: 1_000,
  bpm: 120,
  effectsById: emptyEffects,
});
assert.equal(staticSettled.showBar, false);
assert.equal(staticSettled.looping, false);
assert.equal(staticSettled.elapsedMs, null);

// 2. STATIC scene during active fade: keeps exact fade progress bar.
const staticFading = progress.computeScenePlaybackIndicator({
  cue: baseCue({ fade_ms: 1_000 }),
  nowMs: 1_420,
  activatedAtMs: 1_000,
  bpm: 120,
  effectsById: emptyEffects,
  activeFade: { cue_id: 1, progress: 0.42, remaining_ms: 580, paused: false },
});
assert.equal(staticFading.showBar, true);
assert.ok(Math.abs(staticFading.progress - 0.42) < 1e-6);

// 3. FX scene loops smoothly over its period_ms and respects speed modifier.
const fxCue = baseCue({
  id: 2,
  effect_targets: [
    {
      effect_id: 10,
      enabled: true,
      params: { Lfo: { period_ms: 4_000 } },
    },
  ],
});
const fxMid = progress.computeScenePlaybackIndicator({
  cue: fxCue,
  nowMs: 2_000,
  activatedAtMs: 1_000,
  bpm: 120,
  effectsById: emptyEffects,
});
assert.equal(fxMid.showBar, true);
assert.equal(fxMid.looping, true);
assert.ok(Math.abs(fxMid.progress - 0.25) < 1e-6);
assert.equal(progress.formatScenePlaybackTime(fxMid.elapsedMs), "00m01s00");

// 2x live speed cuts cycle in half (2000ms), so 1000ms elapsed = 0.50.
const fxDoubleSpeed = progress.computeScenePlaybackIndicator({
  cue: fxCue,
  nowMs: 2_000,
  activatedAtMs: 1_000,
  bpm: 120,
  effectsById: emptyEffects,
  cueLiveModifiers: [{ cue_id: 2, speed: 2, size: 1, phase: 0, direction: "Forward", segment: 0 }],
});
assert.ok(Math.abs(fxDoubleSpeed.progress - 0.5) < 1e-6);

// 4. Steps scene cycles across sum of fade_ms + hold_ms.
const stepsCue = baseCue({
  id: 3,
  steps: [
    { values: [], fade_ms: 500, hold_ms: 500 },
    { values: [], fade_ms: 500, hold_ms: 500 },
  ],
});
const stepsMid = progress.computeScenePlaybackIndicator({
  cue: stepsCue,
  nowMs: 2_500,
  activatedAtMs: 1_000,
  bpm: 120,
  effectsById: emptyEffects,
});
assert.equal(stepsMid.showBar, true);
assert.equal(stepsMid.looping, true);
assert.ok(Math.abs(stepsMid.progress - 0.75) < 1e-6);

// 5. SuperScene (TIMELINE) follows direct_child_timeline_transports with smooth rAF extrapolation.
const superCue = baseCue({
  id: 4,
  child_timeline: { duration_ms: 10_000, events: [], layers: [] },
});
const superPlaying = progress.computeScenePlaybackIndicator({
  cue: superCue,
  nowMs: 5_100,
  activatedAtMs: 1_000,
  bpm: 120,
  effectsById: emptyEffects,
  directChildTransport: {
    cue_id: 4,
    position_ms: 2_000,
    duration_ms: 10_000,
    playing: true,
    generation: 1,
    count_in_remaining_ms: 0,
  },
  directChildSampledAtMs: 5_000,
});
assert.equal(superPlaying.showBar, true);
assert.equal(superPlaying.looping, false);
assert.ok(Math.abs(superPlaying.progress - 0.21) < 1e-6);
assert.equal(progress.formatScenePlaybackTime(2_160), "00m02s16");

console.log("PASS: scenePlaybackProgress handles STATIC glow-only, active fade, FX loop/speed, Steps, and SuperScene playback");
