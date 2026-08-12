// Port of mac/Sources/ThrumCore/MorseTiming.swift.

import { UNITS, type MorseToken } from "./morse.ts";

export interface Timing {
  /** Always the character speed. */
  wpm: number;
  /** When set and slower, the effective speed: only the gaps stretch. */
  farnsworthWPM?: number;
}

/** One dit, in seconds. 1.2 because PARIS is 50 units and 60/50 = 1.2. */
export const unit = (t: Timing) => 1.2 / t.wpm;

export const isFarnsworth = (t: Timing) =>
  t.farnsworthWPM !== undefined && t.farnsworthWPM < t.wpm;

export const effectiveWPM = (t: Timing) =>
  isFarnsworth(t) ? t.farnsworthWPM! : t.wpm;

/**
 * ARRL Farnsworth: total padding per average word, spread over the 19 units of
 * spacing in PARIS. Degrades exactly to standard timing when the speeds match.
 */
function spacingUnit(t: Timing): number {
  if (!isFarnsworth(t)) return unit(t);
  const c = t.wpm;
  const s = t.farnsworthWPM!;
  return (60 * c - 37.2 * s) / (s * c) / 19;
}

export function duration(token: MorseToken, t: Timing): number {
  // Inside a character: never stretched.
  if (token === "charGap" || token === "wordGap") {
    return UNITS[token] * spacingUnit(t);
  }
  return UNITS[token] * unit(t);
}

export const totalDuration = (tokens: MorseToken[], t: Timing) =>
  tokens.reduce((sum, token) => sum + duration(token, t), 0);

/** Absolute start time of every token, for scheduling and for laying out the tape. */
export function timeline(tokens: MorseToken[], t: Timing) {
  let at = 0;
  return tokens.map((token) => {
    const d = duration(token, t);
    const entry = { token, start: at, duration: d };
    at += d;
    return entry;
  });
}
