"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { encodeToString, isPulse, tokenize, unsupported } from "@/lib/morse.ts";
import { timeline, totalDuration, unit, type Timing } from "@/lib/timing.ts";
import { createSidetone, type Sidetone } from "@/lib/sidetone.ts";
import TapeStrip from "./TapeStrip";
import TransportControls from "./TransportControls";

const PLACEHOLDERS = ["SOS", "hello world", "73 de thrum"];

export default function Composer() {
  const [text, setText] = useState("");
  const [wpm, setWpm] = useState(5);
  const [muted, setMuted] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [placeholder, setPlaceholder] = useState(PLACEHOLDERS[0]);
  const [reveal, setReveal] = useState({ from: 0, key: 0 });

  const sidetone = useRef<Sidetone | null>(null);
  const frame = useRef(0);
  const previous = useRef("");

  const timing: Timing = { wpm };
  const tokens = tokenize(text);
  const total = totalDuration(tokens, timing);
  const missing = unsupported(text);

  // Rotating placeholder, until you type.
  useEffect(() => {
    if (text) return;
    let i = 0;
    const id = setInterval(() => {
      i = (i + 1) % PLACEHOLDERS.length;
      setPlaceholder(PLACEHOLDERS[i]);
    }, 2600);
    return () => clearInterval(id);
  }, [text]);

  const stop = useCallback(() => {
    cancelAnimationFrame(frame.current);
    sidetone.current?.stop();
    setPlaying(false);
    setElapsed(0);
  }, []);

  const play = useCallback(
    (from = 0) => {
      if (!tokens.length) return;
      cancelAnimationFrame(frame.current);
      sidetone.current ??= createSidetone();
      const engine = sidetone.current;

      const pulses = timeline(tokens, timing)
        .filter((e) => isPulse(e.token) && e.start + e.duration > from)
        .map((e) => ({ start: Math.max(0, e.start - from), duration: e.duration }));

      const t0 = engine.play(pulses, muted);
      setPlaying(true);

      // The audio clock drives the visuals, so they cannot drift apart.
      const tick = () => {
        const position = from + (engine.now() - t0);
        if (position >= total) {
          setElapsed(total);
          setPlaying(false);
          engine.stop();
          return;
        }
        setElapsed(Math.max(0, position));
        frame.current = requestAnimationFrame(tick);
      };
      frame.current = requestAnimationFrame(tick);
    },
    [tokens, timing, muted, total],
  );

  useEffect(() => () => cancelAnimationFrame(frame.current), []);

  // Bars added by this keystroke stagger in; the rest of the tape stays put.
  const onChange = (next: string) => {
    const shared = commonPrefix(previous.current, next);
    previous.current = next;
    setReveal((r) => ({ from: tokenize(next.slice(0, shared)).length, key: r.key + 1 }));
    setText(next);
    if (playing) stop();
  };

  return (
    <section className="mx-auto w-full max-w-3xl" aria-label="Try it">
      <div className="rounded-2xl border border-rule bg-white/45 p-5 sm:p-7">
        <label htmlFor="composer" className="sr-only">
          Text to encode as Morse
        </label>
        <input
          id="composer"
          value={text}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              playing ? stop() : play();
            }
          }}
          placeholder={`Type something — ${placeholder}`}
          autoComplete="off"
          spellCheck={false}
          className="w-full rounded-lg border border-rule bg-white/70 px-4 py-3 text-lg text-ink outline-none placeholder:text-graphite focus:border-signal/50"
        />

        {missing.length > 0 && (
          <p className="mt-2 text-xs text-graphite">
            Morse has no {missing.join(" ")}. Those will be skipped.
          </p>
        )}

        <div className="mt-5">
          <TapeStrip
            tokens={tokens}
            timing={timing}
            elapsed={playing || elapsed > 0 ? elapsed : null}
            playing={playing}
            revealFrom={reveal.from}
            revealKey={reveal.key}
            onSeek={(seconds) => {
              setElapsed(seconds);
              if (playing) play(seconds);
            }}
          />
        </div>

        {tokens.length > 0 && (
          <p className="mt-3 truncate font-mono text-xs text-graphite">
            {encodeToString(text)}
          </p>
        )}

        <TransportControls
          playing={playing}
          canPlay={tokens.length > 0}
          muted={muted}
          wpm={wpm}
          ditMs={unit(timing) * 1000}
          elapsed={elapsed}
          total={total}
          onToggle={() => (playing ? stop() : play(elapsed >= total ? 0 : elapsed))}
          onSeek={(seconds) => {
            setElapsed(seconds);
            if (playing) play(seconds);
          }}
          onMute={() => setMuted((m) => !m)}
          onWpm={setWpm}
        />
      </div>

      <p className="mx-auto mt-4 max-w-xl text-center text-sm text-graphite">
        The web can&apos;t reach your trackpad — this demo is sound and light. The app is
        the one you feel.
      </p>
    </section>
  );
}

function commonPrefix(a: string, b: string) {
  let i = 0;
  while (i < a.length && i < b.length && a[i] === b[i]) i += 1;
  return i;
}
