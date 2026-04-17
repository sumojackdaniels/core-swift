# SwiftUI iteration workflow — research brief

**Date:** 2026-04-17
**Xcode version covered:** 26.4 (current stable as of April 2026)
**Purpose:** Validate the three-tier design-workflow plan against current (late 2024 – Q1 2026) community and Apple guidance before committing to the long-term buildout.

## TL;DR — what changed from the initial proposal

1. **Use `PreviewModifier`** as the standard pattern for any environment-injected dependency (iOS 18+). Xcode caches the shared context across previews — real speedup. Container/presentational split is still the right pattern for pure presentation views, but `PreviewModifier` solves the env-injection problem more cleanly.
2. **Don't hand-build a harness app.** Adopt `eure/swift-storybook`, which automatically collects every `#Preview` in the project into a runtime gallery.
3. **Default to InjectionNext**, not InjectionIII. Same author (johnno1962); InjectionNext resolves known limitations and is the forward path.
4. **Snapshot/PNG export is a solved problem.** `BarredEwe/Prefire` generates snapshot tests from `#Preview` blocks; `PreviewSnapshots` (DoorDash) bridges preview configs to `swift-snapshot-testing`. No custom tooling needed.
5. **Tokens-as-roles theming** (what we already proposed) is the community consensus. Multiple off-the-shelf implementations exist for reference but we should roll our own in core-swift.

## Tier 1: SwiftUI Previews

### `#Preview` macro state of the art

- Replaces the older `PreviewProvider` protocol. Old syntax still works but is deprecated.
- Xcode 26 treats Previews as a core development workflow — tight integration with Predictive Code Completion and Swift 6 concurrency.
- Traits and modifiers now available via the `traits:` parameter: `.sizeThatFitsLayout`, `.fixedLayout`, `.landscapeLeft`, etc.

### `PreviewModifier` — the big addition

iOS 18+ only. Solves the "how do I feed this view a mock `@Observable` / SwiftData container / service?" problem.

Protocol shape:

```swift
protocol PreviewModifier {
    associatedtype Context
    static func makeSharedContext() async throws -> Context
    func body(content: Content, context: Context) -> some View
}
```

Applied via:

```swift
#Preview("Denied", traits: .modifier(MockLocationContext(status: .denied))) {
    LocationStatusView()
}
```

Xcode **caches** the result of `makeSharedContext()` across previews with the same modifier, so setting up a SwiftData `ModelContainer` once and reusing it across 20 previews is cheap.

**For these apps specifically:** add a `LocationService.preview(status:)` factory to `core-swift`, then a `LocationPreviewModifier` so every view reading `LocationService` becomes previewable without per-view refactoring.

### Making views previewable — the two patterns

1. **Container/presentational split.** Best when the view has clean separation between "reads env" and "displays data". One file, two structs.
2. **`PreviewModifier`** — best when many views all need the same env injection, or when the view's logic is non-trivially tied to the service.

Use (1) for leaf components, (2) for env-heavy screens.

## Tier 2: Design harness

### `eure/swift-storybook`

From Eureka Engineering. Automatically collects every `#Preview` in the project at runtime and surfaces them in a gallery app. Matches the hand-rolled "Design Harness" idea from our plan — don't re-implement.

Alternative: `aj-bartocci/Storybook-SwiftUI`.

Integration: one-time Swift Package add to a dedicated Harness target per app, plus a small bootstrap call. Then every `#Preview` in the project automatically appears.

### Deep-link-to-screen

For cases where you want to launch the real app straight into a deep screen (not just a preview), launch arguments + `ProcessInfo.processInfo.arguments` inspection at app root is the simple approach. Claude Code can flip which screen by editing a single string.

## Tier 3: Hot reload

### InjectionNext + Inject (2026)

- **InjectionNext** is johnno1962's successor to InjectionIII. Same approach (dylib injection), fewer limitations. Still requires the InjectionIII.app (or InjectionNext equivalent) running on the Mac.
- **Inject** (Krzysztof Zabłocki) is the SwiftUI convenience wrapper. Add `@ObserveInjection var inject` to a View struct, call `.enableInjection()` at the end of `body`. Works over InjectionIII or InjectionNext.
- **Xcode 26 setup note:** Xcode 16.3+ (including 26.x) no longer emits the frontend command lines that Injection needs by default. Add a User-Defined Build Setting in Debug: `EMIT_FRONTEND_COMMAND_LINES = YES`.

Not Apple-blessed. Not for release builds. Dev-only convenience. Worth it for flow/interaction iteration in the real app context; skip it for pure visual design (Tier 1 handles that better).

## Snapshot export (batch PNG)

The one designer affordance that Previews don't handle natively.

### Options, ranked

1. **`BarredEwe/Prefire`** — build-tool plugin that auto-generates snapshot tests from `#Preview` blocks. Run tests, get PNGs of every variant. Closest to a single-button workflow.
2. **`PreviewSnapshots`** (DoorDash) — a struct that lives in your preview code and can be consumed by both `#Preview` and a `swift-snapshot-testing` test. One source of truth for variants.
3. **`pointfreeco/swift-snapshot-testing`** — still the standard if you want manual control; Prefire and PreviewSnapshots both build on top.

## Theming

### Consensus pattern

Environment-injected protocol-based tokens. The pattern:

1. Define a `Theme` protocol with semantic token **roles** (`accent`, `surface`, `textPrimary`, `cardRadius`, `bodyFont`) — never hex values or point sizes in the protocol itself.
2. Expose via `EnvironmentValues` so views read `@Environment(\.theme)`.
3. Each app ships a concrete `Theme` implementation (`CurioTheme`, `EnoTheme`).
4. Primitives in core-swift (`PrimaryButton`, `Card`, etc.) read tokens from environment, never hardcode values.

### Off-the-shelf references

- `rozd/theme-kit` — native-feeling theming, code generation from design tokens.
- `Charlyk/swift-theme-kit` — full design-system framework.
- Microsoft FluentUI's [Design Tokens wiki](https://github.com/microsoft/fluentui-apple/wiki/Design-Tokens) — mature tokens document.
- Shopify Polaris, Airbnb DLS — non-Swift but shape the vocabulary worth stealing.

### Our direction

Roll our own in core-swift because theme vocabulary is opinionated and we want it to match our apps specifically. Keep it small; start with `Theme` protocol + maybe 10 token roles + `@Environment` wiring. Expand as primitives grow.

## Modularization

### Consensus pattern

Majid Jabrayilov's "microapps architecture" (2022 but still referenced). Structure:

- `DesignSystem` SPM module — tokens, primitives, zero app dependencies.
- `Feature<X>` modules per flow — each owns its views, view models, mocks.
- `App` target — wires features together.
- Previews in feature modules depend on `DesignSystem` + their own feature only. Fast builds.

### For Curio specifically

Not yet modularized. Single app target, all views in `DriveByCurio/Views/`. Modularization is a bigger refactor — worth doing when Tier 1 shows build-time pain, not before.

## Open questions for later

- Do we want `PreviewModifier`-based mocks in `core-swift` itself, or in a sibling `core-swift-preview` package to keep the production target lean? TBD after we use them more.
- Is `swift-storybook`'s runtime collection mechanism fast enough for a project with 200+ previews? No community data either way.
- Does InjectionNext break with CarPlay scenes? Worth testing specifically since Curio has a CarPlay target.

## Sources

- [Mastering #Previews in Xcode 26 — Medium](https://medium.com/@amberSpadafora/mastering-previews-in-xcode-26-a-deep-dive-for-swiftui-developers-298fb99212bf)
- [The power of previews in Xcode — Swift with Majid](https://swiftwithmajid.com/2024/11/26/the-power-of-previews-in-xcode/)
- [Previews in Xcode — Apple Developer](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
- [PreviewModifier for previewing environment — Donny Wals](https://www.donnywals.com/using-previewmodifier-to-build-a-previewing-environment/)
- [How to display sample SwiftData in SwiftUI with PreviewModifier](https://appmakers.substack.com/p/how-to-display-sample-swiftdata-in-swiftui-with-previewmodifier)
- [eure/swift-storybook — auto-collect previews into a gallery](https://github.com/eure/swift-storybook)
- [aj-bartocci/Storybook-SwiftUI](https://github.com/aj-bartocci/Storybook-SwiftUI)
- [krzysztofzablocki/Inject — hot reload wrapper](https://github.com/krzysztofzablocki/Inject)
- [johnno1962/InjectionIII — original hot reload tool](https://github.com/johnno1962/InjectionIII)
- [johnno1962/HotSwiftUI](https://github.com/johnno1962/HotSwiftUI)
- [BarredEwe/Prefire — snapshot tests from #Preview](https://screenshotbot.io/blog/swiftui-previews-and-prefire-free-snapshot-tests)
- [DoorDash PreviewSnapshots](https://careersatdoordash.com/blog/how-to-speed-up-swiftui-development-and-testing-using-previewsnapshots/)
- [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
- [SwiftUI Design Tokens & Theming System — DEV](https://dev.to/sebastienlato/swiftui-design-tokens-theming-system-production-scale-b16)
- [rozd/theme-kit](https://github.com/rozd/theme-kit)
- [Charlyk/swift-theme-kit](https://github.com/Charlyk/swift-theme-kit)
- [Microsoft FluentUI — Design Tokens wiki](https://github.com/microsoft/fluentui-apple/wiki/Design-Tokens)
- [Majid — Microapps architecture, SPM basics](https://swiftwithmajid.com/2022/01/12/microapps-architecture-in-swift-spm-basics/)
- [Modularizing iOS with SwiftUI and SPM — Nimble](https://nimblehq.co/blog/modern-approach-modularize-ios-swiftui-spm)
