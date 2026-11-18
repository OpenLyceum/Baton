---
name: scenerystack-<topic>
description: Use when <the concrete trigger — what the contributor is doing or what file/API they touch>. Covers <the 3–5 specific things this skill teaches>. Keep ≤280 characters so skill matchers can disambiguate.
---

# SceneryStack <Topic>

One or two sentences: what this subsystem is, which `scenerystack/*` module it lives in, and the one mental model that makes the rest obvious. State the read-vs-write or model-vs-view boundary up front if there is one.

## <The main pattern>

Lead with the idiomatic code. Keep snippets short, real, and copy-pasteable; show imports with their exact `scenerystack/<module>` paths. Prefer one good example over three half-examples.

```typescript
import { Thing } from "scenerystack/<module>";

// the canonical usage
```

## <A second facet, if needed>

Only add sections that earn their place — a distinct sub-pattern, an alternate API, or the accessibility/disposal angle. Cross-reference sibling skills by name rather than repeating them.

## Rules

- Imperatives only — what to always/never do. 4–8 bullets.
- Tie each rule to *why* (the bug it prevents) when it isn't obvious.
- Point to related skills by name (e.g. "see scenerystack-constants") instead of duplicating their content.

## Common mistakes

- The wrong-way pattern → the symptom it causes. 3–5 bullets.
- Favor mistakes a reviewer actually sees, not hypotheticals.

Related skills: scenerystack-<a>, scenerystack-<b>.
