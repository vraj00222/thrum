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

**First `MTActuatorActuate` call costs ~5-9ms; subsequent calls are ~0.2ms.** Measured
+9.7ms drift over a 3-tap train but only +4.3ms over 24 taps — the cost is one-time, not
per-tap. Consequence: `HapticEngine.prepare()` must fire one throwaway actuation to warm
the path, or the first dit of every message lands late. Absolute-deadline scheduling
holds after that: 24 taps at 30ms landed at 694.3ms against a 690ms target.
