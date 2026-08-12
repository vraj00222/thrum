// 600Hz sidetone on the Web Audio clock.
//
// AudioContext.currentTime is the master clock for the whole demo — the tape reads
// it too. Driving the visuals off performance.now() instead would let the two drift
// apart over a long message, which is exactly the acceptance criterion.

export interface Pulse {
  start: number;
  duration: number;
}

export interface Sidetone {
  /** Schedules every pulse and returns the context time playback began. */
  play(pulses: Pulse[], muted: boolean): number;
  stop(): void;
  now(): number;
  readonly context: AudioContext;
}

export function createSidetone(frequency = 600): Sidetone {
  const context = new AudioContext();
  const master = context.createGain();
  master.gain.value = 0;
  master.connect(context.destination);

  let oscillator: OscillatorNode | null = null;

  return {
    context,
    now: () => context.currentTime,

    play(pulses, muted) {
      this.stop();
      void context.resume();

      // One continuous oscillator, gated by envelope ramps. Starting and stopping
      // an oscillator per pulse costs a click on every one of them.
      const osc = context.createOscillator();
      osc.frequency.value = frequency;
      osc.connect(master);

      const t0 = context.currentTime + 0.06; // a beat of headroom to schedule into
      const ramp = 0.004;
      const level = muted ? 0 : 0.18;

      master.gain.cancelScheduledValues(context.currentTime);
      master.gain.setValueAtTime(0, context.currentTime);
      for (const pulse of pulses) {
        const on = t0 + pulse.start;
        const off = on + pulse.duration;
        master.gain.setValueAtTime(0, on);
        master.gain.linearRampToValueAtTime(level, on + ramp);
        master.gain.setValueAtTime(level, Math.max(on + ramp, off - ramp));
        master.gain.linearRampToValueAtTime(0, off);
      }

      osc.start(t0);
      oscillator = osc;
      return t0;
    },

    stop() {
      master.gain.cancelScheduledValues(context.currentTime);
      master.gain.setValueAtTime(0, context.currentTime);
      if (oscillator) {
        try {
          oscillator.stop();
        } catch {
          // already stopped
        }
        oscillator.disconnect();
        oscillator = null;
      }
    },
  };
}
