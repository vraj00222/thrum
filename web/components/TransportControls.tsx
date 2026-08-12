"use client";

interface Props {
  playing: boolean;
  canPlay: boolean;
  muted: boolean;
  wpm: number;
  ditMs: number;
  elapsed: number;
  total: number;
  onToggle: () => void;
  onSeek: (seconds: number) => void;
  onMute: () => void;
  onWpm: (wpm: number) => void;
}

export default function TransportControls({
  playing,
  canPlay,
  muted,
  wpm,
  ditMs,
  elapsed,
  total,
  onToggle,
  onSeek,
  onMute,
  onWpm,
}: Props) {
  const fraction = total > 0 ? Math.min(1, elapsed / total) : 0;

  return (
    <div className="mt-5 space-y-4">
      <label className="block">
        <span className="sr-only">Playback position</span>
        <input
          type="range"
          min={0}
          max={Math.max(total, 0.001)}
          step={0.01}
          value={elapsed}
          disabled={!canPlay}
          onChange={(e) => onSeek(Number(e.target.value))}
          className="h-1.5 w-full cursor-pointer appearance-none rounded-full bg-rule accent-signal disabled:cursor-default"
          style={{
            background: `linear-gradient(to right, var(--color-signal) ${fraction * 100}%, var(--color-rule) ${fraction * 100}%)`,
          }}
          aria-valuetext={`${elapsed.toFixed(1)} of ${total.toFixed(1)} seconds`}
        />
      </label>

      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          onClick={onToggle}
          disabled={!canPlay}
          className="inline-flex items-center gap-2 rounded-full bg-signal-wash px-5 py-2 text-sm font-medium text-ink transition hover:brightness-95 disabled:opacity-40"
        >
          <Glyph playing={playing} />
          {playing ? "Pause" : "Play"}
        </button>

        <button
          type="button"
          onClick={onMute}
          aria-pressed={muted}
          className="rounded-full border border-rule px-4 py-2 text-sm text-ink transition hover:bg-white/70"
        >
          {muted ? "Sound off" : "Sound on"}
        </button>

        <label className="flex items-center gap-2 text-sm text-graphite">
          <span className="sr-only sm:not-sr-only">Speed</span>
          <input
            type="range"
            min={3}
            max={13}
            step={1}
            value={wpm}
            onChange={(e) => onWpm(Number(e.target.value))}
            className="w-28 accent-signal"
            aria-label="Words per minute"
            aria-valuetext={`${wpm} words per minute`}
          />
          <span className="font-mono text-xs tabular-nums">{wpm} WPM</span>
        </label>

        <span className="ml-auto font-mono text-xs tabular-nums text-graphite">
          dit = {ditMs.toFixed(0)}ms
        </span>
      </div>
    </div>
  );
}

function Glyph({ playing }: { playing: boolean }) {
  return (
    <svg width="10" height="11" viewBox="0 0 10 11" aria-hidden="true" fill="currentColor">
      {playing ? (
        <>
          <rect x="0" y="0" width="3.5" height="11" rx="1" />
          <rect x="6.5" y="0" width="3.5" height="11" rx="1" />
        </>
      ) : (
        <path d="M0 0.5 L10 5.5 L0 10.5 Z" />
      )}
    </svg>
  );
}
