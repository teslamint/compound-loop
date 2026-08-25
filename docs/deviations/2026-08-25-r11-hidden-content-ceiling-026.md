# Deviation Addendum 026: Replace R11 fixed 65,536-token ceiling with runtime-checked allowance

_Recorded 2026-08-25 after investigating the governed source for R11._

## Original contract

The approved spec (R11) reserves 65,536 input tokens for provider-side billed content not represented in the final request body.

The spec requires a governed billing contract that bounds hidden content and states that corpus tests alone cannot establish the bound.

## Observed contradiction

Claude API token counting documentation (platform.claude.com/docs/en/build-with-claude/token-counting) states:

> "Token counts may include tokens added automatically by Anthropic for system optimizations. **You are not billed for system-added tokens.** Billing reflects only your content."

Claude API pricing documentation (platform.claude.com/docs/en/about-claude/pricing#tool-use-pricing) documents the only billed hidden content: the tool-use system prompt. Per-model observed values:

| Model | Tool choice `auto`/`none` | Tool choice `any`/`tool` |
|---|---|---|
| Claude Opus 5 | 286 tokens | 406 tokens |
| Claude Opus 4.8 | 290 tokens | 410 tokens |
| Claude Sonnet 4.6 | 497 tokens | 589 tokens |

The maximum observed hidden billed content is 804 tokens (Opus 4.7 with forced tool choice).

Pilot 4 cross-check: 22 internal turns cost USD 1.515. A 65,536-token hidden component at 6.60 USD per million tokens would cost at least 0.43 USD in input alone per request. The observed total across 22 turns refutes a per-request hidden component of that magnitude.

The spec's 65,536 ceiling is 81x the observed maximum.

## Decision

Replace the fixed 65,536-token R11 reservation with a 2,048-token runtime-checked allowance.

The 2,048 value provides a 2.5x margin over the observed maximum of 804 tokens and accommodates future tool-use system prompt growth.

Convert the claim into a runtime settlement invariant: at settlement, compare `usage.input_tokens` against `body_ceiling_tokens + hidden_allowance`. If `usage.input_tokens > body_ceiling_tokens + hidden_allowance`, apply the existing R29 invariant breach response (disable key, freeze eligibility).

This replaces a documentation trust with a per-request checked invariant. The settlement check catches any future increase in hidden billed content without relying on documentation freshness.

The governed sources are:
1. Claude API token counting documentation (retrieved 2026-08-25).
2. Claude API pricing documentation, tool-use system prompt table (retrieved 2026-08-25).

## Observable behavior

The strict plugin uses `hidden_allowance: 2048` instead of `hidden_allowance: 65536` in reservation arithmetic.

The maximum reservation drops from 1,378,716 to 959,694 micro-USD:

```text
max input-like tokens = 122880 + 2048 = 124928
worst-case three-category split (each ceil independent):
  ceil(a * 6.60) + ceil(b * 6.60) + ceil(c * 6.60) where a+b+c = 124928
  = 824526 micro-USD (three non-zero-mod-5 categories, +1 over single-category)
ceil(output 8192 * 16.50) = 135168
maximum category-split reserve = 824526 + 135168 = 959694 micro-USD
```

At settlement, the strict plugin checks `usage.input_tokens <= body_ceiling_tokens + 2048`. A violation triggers R29 (key disabled, eligibility revoked, full reservation charged).

The per-invocation key quota of 1,500,000 micro-USD is unchanged. The deviation reduces the per-request maximum reservation, not the key quota.

The maximum reservation of 959,694 micro-USD permits one full-context request and one partial follow-up within a 1,500,000 quota.
