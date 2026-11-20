import { cueStepsTotalDurationMs } from "./cueSteps";
import { effectiveCueLiveModifier } from "./cueLiveModifier";
import type {
  ActiveFadeSummary,
  CueLiveModifierState,
  CueSummary,
  DirectChildTimelineTransportSummary,
  EffectClockSync,
  EffectParamsSnapshot,
  EffectSummary,
} from "./types";

export interface ScenePlaybackIndicator {
  /** Whether to show the bottom seek/progress bar. False for settled STATIC scenes. */
  showBar: boolean;
  /** 0..1 progress value for the seekbar. */
  progress: number;
  /** Elapsed time within the current cycle or timeline in ms (null for fade-only). */
  elapsedMs: number | null;
  /** Total cycle or timeline duration in ms (null for STATIC). */
  durationMs: number | null;
  /** True for continuously looping FX / Step scenes. */
  looping: boolean;
}

const DEFAULT_FX_PERIOD_MS = 2_000;
const MIN_CYCLE_MS = 50;
const MAX_TRANSPORT_EXTRAPOLATION_MS = 250;

const clamp01 = (value: number) => Math.max(0, Math.min(1, Number.isFinite(value) ? value : 0));

const positiveFinite = (value: number | null | undefined): number | null =>
  typeof value === "number" && Number.isFinite(value) && value > 0 ? value : null;

const clockSyncPeriodMs = (
  clockSync: EffectClockSync | null | undefined,
  bpm: number,
): number | null => {
  const beats = positiveFinite(clockSync?.beats);
  const safeBpm = positiveFinite(bpm);
  if (beats === null || safeBpm === null) return null;
  return (beats * 60_000) / safeBpm;
};

export const effectParamsPeriodMs = (
  params: EffectParamsSnapshot | null | undefined,
  bpm: number,
): number | null => {
  if (!params) return null;
  if ("Lfo" in params) {
    return clockSyncPeriodMs(params.Lfo.clock_sync, bpm) ?? positiveFinite(params.Lfo.period_ms);
  }
  if ("Color" in params) {
    return clockSyncPeriodMs(params.Color.clock_sync, bpm) ?? positiveFinite(params.Color.period_ms);
  }
  if ("Move" in params) {
    return clockSyncPeriodMs(params.Move.clock_sync, bpm) ?? positiveFinite(params.Move.period_ms);
  }
  if ("Value" in params) {
    return clockSyncPeriodMs(params.Value.clock_sync, bpm) ?? positiveFinite(params.Value.period_ms);
  }
  if ("Curve" in params) {
    return clockSyncPeriodMs(params.Curve.clock_sync, bpm) ?? positiveFinite(params.Curve.period_ms);
  }
  if ("Mapping" in params) {
    return clockSyncPeriodMs(params.Mapping.clock_sync, bpm) ?? positiveFinite(params.Mapping.period_ms);
  }
  if ("ColorMapping" in params) {
    return (
      clockSyncPeriodMs(params.ColorMapping.clock_sync, bpm)
      ?? positiveFinite(params.ColorMapping.period_ms)
    );
  }
  if ("Chaser" in params) {
    const synced = clockSyncPeriodMs(params.Chaser.clock_sync, bpm);
    if (synced !== null) return synced;
    const stepMs = positiveFinite(params.Chaser.step_duration_ms);
    if (stepMs === null) return null;
    return stepMs * Math.max(1, params.Chaser.steps.length);
  }
  if ("PositionWave" in params) {
    const synced = clockSyncPeriodMs(params.PositionWave.clock_sync, bpm);
    if (synced !== null) return synced;
    const speed = positiveFinite(params.PositionWave.speed);
    const wavelength = positiveFinite(params.PositionWave.wavelength);
    return speed !== null && wavelength !== null ? (wavelength / speed) * 1_000 : DEFAULT_FX_PERIOD_MS;
  }
  return null;
};

export const sceneHasDynamicPlayback = (
  cue: Pick<CueSummary, "child_timeline" | "effect_targets" | "steps">,
): boolean => {
  if (cue.child_timeline) return true;
  if (cueStepsTotalDurationMs(cue.steps) > 0) return true;
  return cue.effect_targets.some((target) => target.enabled);
};

export const sceneCycleDurationMs = (
  cue: Pick<CueSummary, "child_timeline" | "effect_targets" | "steps" | "authored_beats">,
  effectsById: ReadonlyMap<number, EffectSummary>,
  bpm: number,
  speedMultiplier = 1,
): number | null => {
  if (cue.child_timeline) {
    return positiveFinite(cue.child_timeline.duration_ms);
  }
  const safeSpeed = Math.max(0.05, Number.isFinite(speedMultiplier) && speedMultiplier > 0 ? speedMultiplier : 1);
  const stepsMs = cueStepsTotalDurationMs(cue.steps);
  if (stepsMs > 0) {
    return Math.max(MIN_CYCLE_MS, stepsMs / safeSpeed);
  }
  const enabledTargets = cue.effect_targets.filter((target) => target.enabled);
  if (enabledTargets.length === 0) {
    return null;
  }
  let longestMs: number | null = null;
  for (const target of enabledTargets) {
    const effect = effectsById.get(target.effect_id);
    const candidateMs =
      effectParamsPeriodMs(target.params ?? effect?.params, bpm)
      ?? clockSyncPeriodMs(effect?.clock_sync, bpm)
      ?? positiveFinite(effect?.period_ms);
    if (candidateMs !== null && (longestMs === null || candidateMs > longestMs)) {
      longestMs = candidateMs;
    }
  }
  if (longestMs === null) {
    const authoredBeats = positiveFinite(cue.authored_beats);
    const safeBpm = positiveFinite(bpm);
    longestMs = authoredBeats !== null && safeBpm !== null
      ? (authoredBeats * 60_000) / safeBpm
      : DEFAULT_FX_PERIOD_MS;
  }
  return Math.max(MIN_CYCLE_MS, longestMs / safeSpeed);
};

export const formatScenePlaybackTime = (ms: number): string => {
  const safeMs = Math.max(0, Math.floor(Number.isFinite(ms) ? ms : 0));
  const minutes = Math.floor(safeMs / 60_000);
  const seconds = Math.floor((safeMs % 60_000) / 1_000);
  const centiseconds = Math.floor((safeMs % 1_000) / 10);
  return `${String(minutes).padStart(2, "0")}m${String(seconds).padStart(2, "0")}s${String(centiseconds).padStart(2, "0")}`;
};

export interface ComputeScenePlaybackIndicatorOptions {
  cue: CueSummary;
  nowMs: number;
  activatedAtMs: number;
  bpm: number;
  effectsById: ReadonlyMap<number, EffectSummary>;
  activeFade?: ActiveFadeSummary | null;
  cueLiveModifiers?: CueLiveModifierState[] | null;
  directChildTransport?: DirectChildTimelineTransportSummary | null;
  directChildSampledAtMs?: number;
}

export const computeScenePlaybackIndicator = (
  options: ComputeScenePlaybackIndicatorOptions,
): ScenePlaybackIndicator => {
  const { cue, nowMs, activatedAtMs, bpm, effectsById } = options;
  if (
    options.activeFade
    && options.activeFade.cue_id === cue.id
    && options.activeFade.progress < 0.999
  ) {
    return {
      showBar: true,
      progress: clamp01(options.activeFade.progress),
      elapsedMs: null,
      durationMs: cue.fade_ms > 0 ? cue.fade_ms : null,
      looping: false,
    };
  }
  if (cue.child_timeline) {
    const transport = options.directChildTransport;
    const durationMs = positiveFinite(transport?.duration_ms ?? cue.child_timeline.duration_ms);
    if (durationMs === null) {
      return { showBar: false, progress: 0, elapsedMs: null, durationMs: null, looping: false };
    }
    const basePos = Math.max(0, transport?.position_ms ?? 0);
    const extraMs = transport?.playing && (transport.count_in_remaining_ms ?? 0) === 0
      ? Math.max(0, Math.min(MAX_TRANSPORT_EXTRAPOLATION_MS, nowMs - (options.directChildSampledAtMs ?? nowMs)))
      : 0;
    const posMs = Math.min(durationMs, basePos + extraMs);
    return {
      showBar: true,
      progress: clamp01(posMs / durationMs),
      elapsedMs: posMs,
      durationMs,
      looping: false,
    };
  }
  const modifier = effectiveCueLiveModifier(cue, options.cueLiveModifiers ?? undefined);
  const cycleMs = sceneCycleDurationMs(cue, effectsById, bpm, modifier.speed);
  if (cycleMs === null) {
    return {
      showBar: false,
      progress: 1,
      elapsedMs: null,
      durationMs: null,
      looping: false,
    };
  }
  const elapsed = Math.max(0, nowMs - activatedAtMs);
  let phase = (elapsed % cycleMs) / cycleMs;
  if (modifier.direction === "Reverse") {
    phase = 1 - phase;
  } else if (modifier.direction === "Bounce") {
    const doublePhase = (elapsed % (cycleMs * 2)) / cycleMs;
    phase = doublePhase <= 1 ? doublePhase : 2 - doublePhase;
  }
  const clampedPhase = clamp01(phase);
  return {
    showBar: true,
    progress: clampedPhase,
    elapsedMs: clampedPhase * cycleMs,
    durationMs: cycleMs,
    looping: true,
  };
};
