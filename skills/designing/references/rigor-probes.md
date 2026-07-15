# Rigor-Gap Probes

`enforces: P4`. Ported from ce-brainstorm Phase 1.2/1.3. This is agent-internal analysis, not a user-facing checklist: read the opening, note which gaps actually exist, and raise only those — folded into the normal flow of dialogue in Step 6, never fired as a pre-flight gauntlet. A fuzzy opening may earn three or four probes; a concrete, well-framed one may earn zero because no scope-appropriate gap was found.

## Tier Scaling

- **Lightweight** — no rigor-gap probes. Instead ask internally:
  - Is this solving the real user problem?
  - Are we duplicating something that already covers this?
  - Is there a clearly better framing with near-zero extra cost?
- **Standard** — scan the four gap lenses below.
- **Deep / Deep-feature** — same four lenses, plus: is this a local patch, or does it move the broader system toward where it wants to be?
- **Deep-product** — all four lenses plus the durability gap (five total), plus: what adjacent product could we accidentally build instead, and why is that the wrong one? What would have to be true in the world for this to fail?

## The Four Gaps (Standard and above)

**Evidence gap.** The opening asserts want or need but doesn't point to anything the would-be user has already done — time spent, money paid, workarounds built — that would make the want observable. When present, ask for the most concrete thing someone has already done about this.

> *"What's the most concrete thing someone's already done about this — paid for it, built a workaround, quit a tool over it?"*

**Specificity gap.** The opening describes the beneficiary at a level of abstraction where the agent couldn't design without silently inventing who they are and what changes for them. When present, ask the user to name a specific person or narrow segment, and what changes for that person when this ships.

> *"Can you name a team you've actually watched hit this, or are you reasoning?"*

**Counterfactual gap.** The opening doesn't make visible what users do today when this problem arises, nor what changes if nothing ships. When present, ask what the current workaround is, even if it's messy, and what it costs them.

> *"What do teams do today when this breaks — who reconciles?"*

**Attachment gap.** The opening treats a particular solution shape as the thing being built, rather than the value that shape is supposed to deliver, and hasn't been examined against smaller forms that might deliver the same value. When present, ask what the smallest version that still delivers real value would look like.

> *"Before we move to shapes or approaches — what's the smallest version that would still prove the bet right, and what's excluded?"*

Attachment is the final rigor probe before approaches are proposed (Step 7) when the gap is present. Fire it regardless of whether a specific shape has already emerged through narrowing — its job is to pressure-test the user's implicit framing before Step 7 inherits it.

## The Fifth Gap (Deep-product only)

**Durability gap.** The opening's value proposition rests on a current state of the world that may shift in predictable ways within the horizon the user cares about. When present, ask how the idea fares under the most plausible near-term shifts — and push past rising-tide answers every competitor could make.

> *"Under the most plausible near-term shifts, how does this bet hold?"*

If the answer reveals genuine uncertainty, record it as an explicit assumption in the spec's Open Decisions section rather than skipping the probe.

## One-Gap-One-Open-Probe Discipline

Each scope-appropriate gap fires as a **separate** direct open-ended probe — one probe satisfies one gap, not multiple. Never bundle two gaps into a single question; a 4-option menu covering multiple gaps signals which kinds of evidence count and lets the user pick rather than produce. Open-ended questions force them to produce real observation or surface their uncertainty. Surface probes progressively across the conversation — interleaving with narrowing moves is fine, as long as every scope-appropriate gap found has been probed open-ended before approaches are proposed.

## Synthesis Questions (not gap lenses)

These are product judgment the agent weighs internally, not separate probes to fire verbatim:

- Is there a nearby framing that creates more user value without more carrying cost? If so, what complexity does it add?
- Given the current project state, user goal, and constraints, what is the single highest-leverage move right now: the request as framed, a reframing, one adjacent addition, a simplification, or doing nothing?

Favor moves that compound value, reduce future carrying cost, or make the product meaningfully more useful. Use the result to sharpen the conversation, not to bulldoze the user's intent.
