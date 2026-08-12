# Decisions

Running log of calls made where the brief left it open.

## Phase 0

**`dlsym` instead of a bridging header for MultitouchSupport.** The brief specifies
`include/MultitouchSupport.h` + linking the private framework. Resolving the six symbols
at runtime instead means a renamed or removed symbol on a future macOS degrades to the
public engine at launch, rather than failing to link or crashing at first call. Same six
symbols, and it makes the required "wrap every private call so a failure downgrades"
behaviour the default rather than something bolted on. Revisit if we ever need a symbol
`dlsym` can't reach.

**Actuator confirmed working on macOS 26.0 / Mac16,1 (M4).** `MTDeviceCreateDefault` →
`MTDeviceGetDeviceID` → `MTActuatorCreateFromDeviceID` → `MTActuatorOpen` all return
clean. Device ID `504403158265495834`, resolved at runtime — not hardcoded, so an
external Magic Trackpad is picked up for free as specified.

**Phase 0's two questions were delegated back to me, so I chose defaults and made both
tunable at runtime.** I can't feel anything, so guessing once and hardcoding it would be
the worst option. Instead:

- Tap interval defaults to 30ms but is a live slider in Settings (15–50ms). If the train
  reads as a machine gun, the fix is dragging one slider, not a redesign.
- Dit and dah get *different actuation IDs* by default (dit = 3, dah = 6) rather than
  relying on length alone. This is the texture-per-symbol fallback the brief describes,
  shipped up front instead of held in reserve — it costs nothing and it means dit/dah stay
  distinguishable even if the tap train doesn't fuse into a continuous pulse.
- Settings has a "Test feel" row that fires dit and dah with the current pair so the two
  IDs can be re-picked by hand from all eight without rebuilding.

Rationale for 3/6 specifically: IDs 1–3 are light variants and 4–6 heavier ones, so the
pair reads as light-and-short vs heavy-and-long, which reinforces the length difference
instead of fighting it. 15/16 are available in the picker.

**First `MTActuatorActuate` call costs ~5-9ms; subsequent calls are ~0.2ms.** Measured
+9.7ms drift over a 3-tap train but only +4.3ms over 24 taps — the cost is one-time, not
per-tap. Consequence: `HapticEngine.prepare()` must fire one throwaway actuation to warm
the path, or the first dit of every message lands late. Absolute-deadline scheduling
holds after that: 24 taps at 30ms landed at 694.3ms against a 690ms target.
