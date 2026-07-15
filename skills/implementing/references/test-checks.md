# Test Checks

Ported faithfully from CE ce-work. Two gates: scenario completeness (before writing tests) and the system-wide check (before marking a unit done).

## Test Scenario Completeness

Before writing tests for a feature-bearing unit, check whether the plan's `Test scenarios` cover every category that applies to this unit. If a category is missing, or a scenario is vague (e.g. "validates correctly" without naming inputs and expected outcomes), supplement from the unit's own context before writing tests:

| Category | When it applies | How to derive if missing |
|----------|----------------|------------------------|
| **Happy path** | Always for feature-bearing units | Read the unit's Goal and Approach for core input/output pairs |
| **Edge cases** | When the unit has meaningful boundaries (inputs, state, concurrency) | Identify boundary values, empty/nil inputs, and concurrent access patterns |
| **Error/failure paths** | When the unit has failure modes (validation, external calls, permissions) | Enumerate invalid inputs the unit should reject, permission/auth denials it should enforce, and downstream failures it should handle |
| **Integration** | When the unit crosses layers (callbacks, middleware, multi-service) | Identify the cross-layer chain and write a scenario that exercises it without mocks |

## System-Wide Test Check

Before marking a unit done, pause and ask:

| Question | What to do |
|----------|------------|
| **What fires when this runs?** Callbacks, middleware, observers, event handlers — trace two levels out from your change. | Read the actual code (not docs) for callbacks on models you touch, middleware in the request chain, `after_*` hooks. |
| **Do my tests exercise the real chain?** If every dependency is mocked, the test proves your logic works *in isolation* — it says nothing about the interaction. | Write at least one integration test that uses real objects through the full callback/middleware chain. No mocks for the layers that interact. |
| **Can failure leave orphaned state?** If your code persists state (DB row, cache, file) before calling an external service, what happens when the service fails? Does retry create duplicates? | Trace the failure path with real objects. If state is created before the risky call, test that failure cleans up or that retry is idempotent. |
| **What other interfaces expose this?** Mixins, DSLs, alternative entry points (Agent vs Chat vs ChatMethods). | Grep for the method/behavior in related classes. If parity is needed, add it now — not as a follow-up. |
| **Do error strategies align across layers?** Retry middleware + application fallback + framework error handling — do they conflict or create double execution? | List the specific error classes at each layer. Verify your rescue list matches what the lower layer actually raises. |

**When to skip:** leaf-node changes with no callbacks, no state persistence, no parallel interfaces. If the change is purely additive (new helper method, new view partial), the check takes 10 seconds and the answer is "nothing fires, skip."

**When this matters most:** any change that touches models with callbacks, error handling with fallback/retry, or functionality exposed through multiple interfaces.
