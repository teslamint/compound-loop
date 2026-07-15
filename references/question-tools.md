# Cross-Harness Blocking Questions

`enforces: P9`. When a skill must ask the user a blocking question (gates, approach choices, destructive confirmations), use the harness's blocking question tool. Options scaffold the answer without confining it — every blocking tool includes a free-text escape ("Other").

| Harness | Tool | Note |
|---|---|---|
| Claude Code | `AskUserQuestion` | Load the schema via ToolSearch first if deferred |
| Codex | `request_user_input` | Unavailable in some edit modes — fall back below |
| Gemini | `ask_user` | Untested by this plugin (v0.1) |

**Fallback**: numbered options in chat, waiting for a reply number — used only when no blocking tool exists in the harness or the call errors, never merely because a schema needs loading. Never silently skip the question.

## Form rules

- One question per message, even when sub-questions feel related.
- Prefer single-select; multi-select only for compatible sets (goals, constraints, non-goals) — if prioritization matters, follow up asking which is primary.
- Ask **open-ended** instead of a menu only when: (a) the answer is inherently narrative, (b) the question is diagnostic and a menu would bias the answer, or (c) you cannot write 3–4 genuinely distinct, non-strawman options. If you would strain to fill the option slots, the question is open — ask it open-ended, and make it concrete enough to bite into.
- Do not narrate the form choice; just ask.

## Destructive confirmations

Irreversible actions (discarding a branch, deleting docs) require a **typed confirmation string** (e.g. type `discard`), not a menu selection — a mis-click must not be able to destroy work. `enforces: P7`.
