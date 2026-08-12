"use client";

import { useEffect, useRef, useState } from "react";
import { isPulse, type MorseToken } from "@/lib/morse.ts";
import { timeline, type Timing } from "@/lib/timing.ts";

const PX_PER_SECOND = 92;
const BAR_HEIGHT = 46;
const HEIGHT = 92;
const REVEAL_MS = 180;
const STAGGER_MS = 18;

interface Props {
  tokens: MorseToken[];
  timing: Timing;
  /** Live position in seconds, or null when idle. */
  elapsed: number | null;
  playing: boolean;
  revealFrom: number;
  revealKey: number;
  onSeek?: (seconds: number) => void;
}

/**
 * SVG rects with widths proportional to real duration — never text characters,
 * which can't give correct proportional widths and would visibly disagree with the
 * audio. Laid out in time, so bar width and scroll rate come from the same number.
 */
export default function TapeStrip({
  tokens,
  timing,
  elapsed,
  playing,
  revealFrom,
  revealKey,
  onSeek,
}: Props) {
  const [width, setWidth] = useState(720);
  const [revealAge, setRevealAge] = useState(Infinity);
  const wrapper = useRef<HTMLDivElement>(null);
  const reduced = usePrefersReducedMotion();

  useEffect(() => {
    const el = wrapper.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) =>
      setWidth(entry.contentRect.width),
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // Stagger the newest bars in. One rAF loop for the whole run, not one per bar.
  useEffect(() => {
    if (revealKey === 0) return;
    const start = performance.now();
    let frame = 0;
    const total = REVEAL_MS + (tokens.length - revealFrom) * STAGGER_MS;
    const tick = () => {
      const age = performance.now() - start;
      setRevealAge(age);
      if (age < total) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [revealKey, revealFrom, tokens.length]);

  const playhead = width / 3;
  const entries = timeline(tokens, timing);
  const total = entries.length
    ? entries[entries.length - 1].start + entries[entries.length - 1].duration
    : 0;

  const position = elapsed ?? 0;
  const scroll = reduced ? snap(entries, position) : position;
  const originX = playhead - scroll * PX_PER_SECOND;
  const midY = HEIGHT / 2;

  return (
    <div
      ref={wrapper}
      className="relative overflow-hidden rounded-xl border border-rule bg-tape"
      style={{ height: HEIGHT }}
    >
      <svg
        width="100%"
        height={HEIGHT}
        role="img"
        aria-label={
          tokens.length ? `Morse tape, ${describe(tokens)}` : "Empty Morse tape"
        }
        className={onSeek && tokens.length ? "cursor-pointer" : undefined}
        onClick={(event) => {
          if (!onSeek || !tokens.length) return;
          const box = event.currentTarget.getBoundingClientRect();
          const delta = (event.clientX - box.left - playhead) / PX_PER_SECOND;
          onSeek(Math.min(Math.max(0, position + delta), total));
        }}
      >
        {entries.map((entry, index) => {
          if (!isPulse(entry.token)) return null;
          const x = originX + entry.start * PX_PER_SECOND;
          const w = entry.duration * PX_PER_SECOND;
          if (x + w < -20 || x > width + 20) return null;

          let reveal = 1;
          if (index >= revealFrom) {
            const delay = (index - revealFrom) * STAGGER_MS;
            reveal = clamp((revealAge - delay) / REVEAL_MS);
            if (reveal <= 0) return null;
          }
          const eased = reduced ? 1 : easeOutBack(reveal);

          const firing =
            playing && position >= entry.start && position < entry.start + entry.duration;
          const played = position > entry.start;
          const h = BAR_HEIGHT * eased * (firing ? 1.15 : 1);

          return (
            <rect
              key={index}
              x={x}
              y={midY - h / 2}
              width={w}
              height={h}
              rx={Math.min(4, w / 2)}
              fill={firing ? "var(--color-signal)" : "var(--color-ink)"}
              opacity={firing ? 1 : (played ? 0.35 : 0.86) * eased}
            />
          );
        })}

        <rect
          x={playhead - 1}
          y={midY - 35}
          width={2}
          height={70}
          rx={1}
          fill="var(--color-signal)"
          className={playing && !reduced ? "origin-center animate-[pulse_0.9s_ease-in-out_infinite]" : undefined}
        />
      </svg>

      <div className="pointer-events-none absolute inset-y-0 left-0 w-7 bg-gradient-to-r from-tape to-transparent" />
      <div className="pointer-events-none absolute inset-y-0 right-0 w-7 bg-gradient-to-l from-tape to-transparent" />
    </div>
  );
}

const clamp = (x: number) => Math.min(1, Math.max(0, x));

/** Slight overshoot on the way in. */
function easeOutBack(x: number) {
  const c1 = 1.70158;
  return 1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2;
}

/** Reduced motion: hold the tape on token boundaries instead of sliding. */
function snap(entries: ReturnType<typeof timeline>, position: number) {
  let last = 0;
  for (const entry of entries) {
    if (entry.start + entry.duration > position) return entry.start;
    last = entry.start;
  }
  return last;
}

function describe(tokens: MorseToken[]) {
  return tokens
    .map((t) =>
      t === "dit" ? "dot" : t === "dah" ? "dash" : t === "charGap" ? "," : t === "wordGap" ? "." : "",
    )
    .filter(Boolean)
    .join(" ");
}

export function usePrefersReducedMotion() {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(query.matches);
    const onChange = () => setReduced(query.matches);
    query.addEventListener("change", onChange);
    return () => query.removeEventListener("change", onChange);
  }, []);
  return reduced;
}
