# Design workflow

How we iterate on SwiftUI views quickly across Eno Labs iOS apps (Eno, Curio) — replacing a Figma-style design loop with Claude-Code-driven edits and live Xcode feedback.

These docs live in `core-swift` because every iOS app has `core-swift` cloned/resolved as an SPM dependency anyway, and the workflow is shared across apps. Over time, helper code (`PreviewModifier` factories, theming primitives, preview components) will be published from this package to back these conventions.

## Goals

- Compare variants side-by-side ("nav bar vs tab bar", "12pt vs 14pt") without clicking through the app.
- Jump directly to any screen in the flow without manually navigating from the launch screen.
- Test component state matrices (loading / error / empty / populated) at a glance.
- Minimize rebuild time so iteration feels like editing a Figma frame, not like compiling code.
- Keep all designer affordances scriptable so a Claude Code agent can drive them from a prompt.

## Three-tier workflow

| Tier | Tool | When |
|---|---|---|
| 1 | **SwiftUI Previews** (`#Preview` macro + `PreviewModifier`) | Pure visual iteration — most design work lives here. Near-zero build time. |
| 2 | **Design Harness app** (via `eure/swift-storybook`) | When you need flow/interaction, deep-linking, or a gallery of everything in one place. |
| 3 | **Hot reload** (`Inject` + `InjectionNext`) | When you need the real app running but don't want to rebuild on every edit. |

Tier 1 covers most of a designer's Figma-equivalent workflow. Tiers 2 and 3 are additive when Tier 1 isn't enough.

## Status

- **2026-04-17** — Research complete. Pilot in progress on DriveByCurio. No helper code in core-swift yet; conventions-only.

## Documents

- [`research-2026-04.md`](research-2026-04.md) — Current best-practices research brief.
- [`previews-guide.md`](previews-guide.md) — Conventions, standard preview sets, component/screen split, freshness model.
- [`troubleshooting.md`](troubleshooting.md) — Remedies for spinning canvas, phantom module errors, crashed previews, and simulator weirdness.

Future (planned as helper code in `core-swift` lands):
- `harness-setup.md` — How to wire `swift-storybook` into a new app (Tier 2).
- `hot-reload-setup.md` — InjectionNext + Inject per app (Tier 3).
- `theming.md` — Design tokens and per-app theming conventions.
- `affordances.md` — Reusable preview helpers (`CompareRow`, `StateMatrix`, `TokenScrub`, `DeviceGrid`).

## Handoff to per-app agents

Each app's `WORKFLOW.md` links here. Shared tooling + conventions stay here; app-specific decisions stay in the app's repo.
