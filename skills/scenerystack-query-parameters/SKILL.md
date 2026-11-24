---
name: scenerystack-query-parameters
description: Use when adding a URL startup option or debug flag — typed QueryStringMachine schema, validation, public flag. Trigger on ?foo=bar toggles.
---

# SceneryStack Query Parameters

URL query parameters configure a sim at launch (`index.html?snapToGrid=true&gridSpacing=2`). Declare them once in a typed schema with `QueryStringMachine.getAll`; it parses, validates, and type-checks `window.location`. Never read `location.search` by hand.

## The schema file

Declare sim-specific parameters in `src/preferences/<sim>QueryParameters.ts` and export the parsed object. Treat it as read-only startup configuration.

```typescript
import { logGlobal } from "scenerystack/phet-core";
import { QueryStringMachine } from "scenerystack/query-string-machine";
import { GRID_SPACING_MIN_M, GRID_SPACING_MAX_M } from "../OpticsLabConstants.js";
import opticsLab from "../OpticsLabNamespace.js";

const opticsLabQueryParameters = QueryStringMachine.getAll({
  // boolean flag, on by default, exposed to end users
  enabledOpticalFiber: {
    type: "boolean",
    defaultValue: true,
    public: true,
  },

  // another public startup toggle
  snapToGrid: {
    type: "boolean",
    defaultValue: false,
    public: true,
  },

  // number with range validation
  gridSpacing: {
    type: "number" as const,
    defaultValue: 1,
    public: true,
    isValidValue: (value: number) => value >= GRID_SPACING_MIN_M && value <= GRID_SPACING_MAX_M,
  },

  // integer with custom validity
  maximumLightRayDepth: {
    type: "number" as const,
    defaultValue: 50,
    public: true,
    isValidValue: (value: number) => Number.isInteger(value) && value >= 1 && value <= 100,
  },
});

opticsLab.register("opticsLabQueryParameters", opticsLabQueryParameters);
logGlobal("phet.chipper.queryParameters");

export default opticsLabQueryParameters;
```

Consumers import the parsed object and read typed fields:

```typescript
import opticsLabQueryParameters from "./preferences/opticsLabQueryParameters.js";
if (opticsLabQueryParameters.snapToGrid) { /* ... */ }
```

Register the parsed object with the sim namespace so it is visible through the SceneryStack registry. The optional `logGlobal` call above logs shared framework parameters when SceneryStack logging is enabled.

## Schema entry fields

- `type` — `"boolean" | "number" | "string" | "flag" | "array" | "custom"` (use `as const` on string literals so TS narrows).
- `defaultValue` — used when the parameter is absent.
- `isValidValue` — predicate; an out-of-range value is rejected and the default (or an error) is used.
- `public: true` — marks an end-user parameter and makes schema-rejected values warn and fall back to the default. Omitting it allows schema-rejected values to throw. `private: true` separately limits URL access to PhET team members.

## Boolean switches with existing bare links

Use one schema entry that accepts the bare key, `=true`, and `=false`. QueryStringMachine passes `null` for the bare key. `defaultValue` applies when the key is absent. For a switch that defaults off, the parser accepts the bare key and `"true"` as on:

```typescript
showEquations: {
  type: "custom",
  defaultValue: false,
  parse: (value: string | null): boolean => value === null || value === "true",
  public: true,
},
```

For a switch that defaults on, use `defaultValue: true` and `parse: (value: string | null): boolean => value !== "false"`. Unrecognized values fall back to the switch's default in either version.

## Rules

- Parse sim-specific values with `QueryStringMachine.getAll`. Use `QueryStringMachine.containsKey` when startup logic only needs to detect whether the URL supplied a framework parameter such as Joist's `screens` or `initialScreen`. Joist owns parsing and validating those values.
- Pull `defaultValue`s and validation bounds from `*Constants.ts` (see scenerystack-constants) so a parameter's range matches the model's range.
- Register the parsed object with the sim namespace (`simNamespace.register(...)`) after `getAll`.
- Mark only genuinely user-facing parameters `public: true`; keep debug switches private.
- Validate user-supplied values with the schema type, `validValues`, `isValidValue`, or a custom parser. When parameters override a preset, distinguish schema fallbacks from explicit overrides.
- A query parameter sets a **startup** value; if the user can change it live, wire it to a model `Property` and/or a preference (see scenerystack-preferences), don't re-read the URL later.

## Common mistakes

- Reading `window.location.search` directly → no validation, no typing; use the schema.
- Marking a developer/debug flag `public: true` → it leaks into the documented public API.
- Hardcoding the valid range in `isValidValue` instead of importing the same constant the model uses → the two can drift.

Related skills: scenerystack-constants, scenerystack-preferences, scenerystack-model.
