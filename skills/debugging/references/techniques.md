# Investigation Techniques

Supporting recipes for `debugging` Phase 1 (Investigate). Load on demand — not part of the main flow's progressive disclosure budget.

## Backward tracing

Use when the error surfaces deep in a call stack and the immediate frame is clearly just a symptom.

1. Read the stack trace bottom-to-top, opening each frame's source in order. The bottom frame is the symptom; the root cause is upstream of it.
2. Identify the first frame (reading upward) where the input data is already invalid. That frame is the upper bound on where to look — the root cause is at or before it, never after.
3. Instrument the boundaries around that frame: targeted log/print statements, debugger breakpoints, or test assertions that capture *actual* values at function entry/exit. Assumed values lie; observed values don't.
4. Walk the boundaries upward until you find the transition where valid input became invalid output. That transition is the root-cause site.

Do not stop at the first function that merely looks wrong — the root cause is where bad state originates, not where it is first observed. Fix at the source, not at the point of observation.

## Multi-component boundary instrumentation

Use when the system spans multiple components and it's unclear which one is at fault (e.g., a build pipeline, a request that crosses several services, a client-to-database round trip).

Before proposing any fix, instrument every component boundary and run once to gather evidence showing *where* it breaks — do not guess which component is at fault from reading code alone:

```
For EACH component boundary:
  - Log what data enters the component
  - Log what data exits the component
  - Verify environment/config propagation across the boundary
  - Check state at each layer

Run once to gather evidence showing WHERE it breaks.
THEN analyze the evidence to identify the failing component.
THEN investigate that specific component in depth.
```

For example, in a pipeline with N sequential stages (source → stage A → stage B → stage C), add a boundary check at every transition:

```bash
# Boundary 1: input available to stage A?
echo "=== stage A input: ==="
echo "VALUE: ${VALUE:+SET}${VALUE:-UNSET}"

# Boundary 2: does stage A pass it to stage B?
echo "=== stage B input (from stage A): ==="
env | grep VALUE || echo "VALUE not propagated to stage B"

# Boundary 3: stage B's own state before invoking stage C
echo "=== stage B internal state: ==="
<stage-specific state dump>

# Boundary 4: stage C's actual behavior
<stage C command, run with maximum verbosity>
```

The instrumented run reveals which boundary the data survives and which one it doesn't (e.g., "source → stage A: OK; stage A → stage B: FAILS"). Only then investigate that specific boundary — instrumenting everything and analyzing afterward is faster than guessing a component and instrumenting it one at a time.

Generalize the boundary set to whatever the actual system has — CI → build → signing, API → service → database, client → gateway → worker — the recipe is the same regardless of domain.
