# SwiftUI Previews — conventions guide

How we write previews on the Eno Labs iOS apps (Eno, Curio) so that agents and humans can iterate on screens the way a designer iterates on Figma frames.

## Vocabulary

- **Component** — a reusable UI primitive. Lives in `core-swift` (shared across apps) or in an app's internal design layer. Examples: `PrimaryButton`, `Card`, `StatusBadge`.
- **Screen** — a full-surface composition. Lives in an app. Examples: `LocationStatusView`, `TourBrowserView`, `WalkingTourDetailView`.
- **Content view** — the pure, previewable half of a screen or component when we split container + presentational (e.g. `LocationStatusContent`).

## The standard preview set

Every screen and every component should ship a standard floor of previews. Specific views may add more; they should never have less.

### For screens

| Preview | Purpose |
|---|---|
| `#Preview` (unnamed or `"Default"`) | Happy-path state. The canonical render. |
| `#Preview("States")` | Every meaningful state stacked: loading / empty / error / populated / any domain-specific variants. One tile, quick scan. |
| `#Preview("Dark")` | Same default, `.preferredColorScheme(.dark)`. |
| `#Preview("A11y XL")` | `.environment(\.dynamicTypeSize, .accessibility3)`. Catches wrapping and truncation bugs. |

Optional, add when the view actually varies on that axis:

| Preview | When to add |
|---|---|
| `#Preview("Compact")` | Layout changes at iPhone SE width. |
| `#Preview("iPad")` | iPad-specific layout. |
| `#Preview("Localized")` | Text-heavy, has non-English strings. Preview in a long-string locale (German, Finnish) to catch overflow. |
| `#Preview("Landscape")` | Layout changes in landscape. |

### For components in `core-swift`

| Preview | Purpose |
|---|---|
| `#Preview` / `#Preview("Default")` | Default configuration. |
| `#Preview("Variants")` | Every size × every style × every state. Grid or stack. One place to audit the component. |
| `#Preview("In context")` | Component embedded in a representative surrounding (e.g. a button inside a sample form row). Catches spacing/alignment issues that solo previews miss. |
| `#Preview("Dark")` | Dark mode. |

### What not to do

- Don't write a named preview for every single state if `States` already shows them. Pick one — usually `States` wins.
- Don't preview every sub-component inside a screen's file. Sub-components have their own files with their own previews.
- Don't leave commented-out old previews. Delete them; git history is the archive.

## Component isolation vs screen context — when to use each

The rule:

> **Component-level previews live in the component's file. Screen-level previews live in the screen's file. Never duplicate.**

Concretely:

- **Reusable component in core-swift** — MUST have component-level previews (variants + dark + in-context). Consuming apps do not need to re-preview it. If it looks right in core-swift's previews, it looks right everywhere.
- **Reusable component in an app's internal design layer** — same rule; preview with the component.
- **Screen composed of known-good components** — preview the screen's states, not the components. Assume the components are correct (their own previews prove it).
- **One-off component that only this screen uses** — skip the component-level file; test it inside the screen's previews. Don't build a shared-looking abstraction that isn't shared.
- **Component that exists in one screen today but might be reused later** — leave it in the screen until actual reuse. Promote to its own file + previews when the second consumer appears. YAGNI.

### Heuristics

1. "If I changed the color tokens, where do I look first?" → **component file.** That's the audit surface.
2. "If I changed the spacing between a row's icon and its text, where do I look?" → **screen file.** The compositional intent lives there.
3. "If I want to test that this screen handles loading/empty/error correctly" → **screen file** — those are screen-level states, not component states.
4. "If I want to test every size and style of a button" → **component file.**

### The "audit surface" property

The goal is: for any design decision (a token change, a style update, a new variant), there is **one** canonical place to look. Duplicating previews across files dilutes that property — changes don't get audited because no one knows which file is the source of truth. Keep the surfaces separate.

## How previews stay in sync with code

Previews are **not** cached snapshots. They are live compilations of your code. Internalizing this changes what you expect from them.

### The mental model

When Xcode renders a preview:

1. Swift compiler builds the relevant module(s) — the one your file is in, plus its dependencies up the graph.
2. A preview-agent process launches in the simulator.
3. The preview closure runs; its returned `View` is rendered.
4. The canvas displays the render.

Every time you save a change to a file a preview depends on — transitively — steps 1–4 re-execute. Usually fast (sub-second) for same-file edits. Slower if the edit invalidates a large module graph.

### The freshness contract

> Whatever the canvas shows **is** what your current code produces, given the inputs the preview closure provides.

There is no "old version still rendering correctly" failure mode. If recompile succeeds, the canvas is fresh. If recompile fails, the canvas pauses (with a diagnostic) — the stale image stays visible but Xcode tells you it's stale.

Corollaries:

- Preview shows wrong thing? Either the code is wrong, or the preview closure is feeding it the wrong mock.
- Preview doesn't update after an edit? Recompile was blocked. Find the build error. (Often a file elsewhere in the target.)
- Preview shows inconsistent things between runs? Something in the preview closure is non-deterministic — `UUID()`, `Date()`, or a singleton.

### What can go wrong

**Build errors anywhere in the target pause all previews.** This is why feature-module SPM structure matters long-term: a broken feature shouldn't block design iteration on an unrelated screen. Until we modularize, any compile error anywhere in the app stops the canvas.

**Runtime exceptions in preview code** show "Preview crashed" with a stack trace. Common causes: force-unwrapping nil in a mock, accessing a MainActor-isolated thing off-main, touching `UIApplication.shared` in a context that doesn't have it.

**Non-deterministic inputs** cause flicker. `UUID()` regenerates every render. `Date()` does too. If you need stable output, hardcode values in the mock.

**Singleton leakage** — a preview that accidentally reads `SomeService.shared` or `UserDefaults` is reading app-wide live state. Previews should never reference singletons; always inject.

**`@AppStorage` persistence across previews** — reads/writes real UserDefaults, so stale values from one preview can surface in another. Clear them or scope them (`UserDefaults(suiteName:)`) in mocks.

**Async `.onAppear` data loads** don't complete before the preview snapshot. The preview shows the initial state. To preview loaded state, inject a pre-loaded mock service (usually via `PreviewModifier`).

**`@Observable` across files** updates correctly *if* the observed object is constructed in the preview closure. It does not update if you mutate a shared global after the snapshot renders.

### The paused-preview diagnostic cheat sheet

| Canvas message | What it means | What to do |
|---|---|---|
| "Automatic preview updating paused" | Something failed or you typed faster than the canvas could keep up | Hit Resume (`⌥⌘P`) |
| "Preview crashed" | Runtime exception while rendering | Click the error for stack trace, fix the logic |
| Spinner forever, no message | Preview agent can't attach or keeps dying | Check Low Power Mode, DerivedData, simulator state — see [troubleshooting](troubleshooting.md) |
| "Build failed" banner | Compile error somewhere in the target | `⌘5` Issue Navigator to find it |

## Applying this to the workflow

For agents implementing screens (including Claude Code sessions):

1. **New screen** — ship the four-preview floor (`Default`, `States`, `Dark`, `A11y XL`) in the initial PR. Not optional.
2. **New component in core-swift** — ship the three-preview floor (`Default`, `Variants`, `In context`).
3. **Modifying a screen** — if the change adds a state, update the `States` preview. If it adds a layout axis (new device behavior), add the corresponding preview.
4. **Modifying a component** — update `Variants` to cover the new permutation.
5. **Removing a state** — remove it from `States`. Don't leave orphaned branches.

When Claude Code is asked "try nav bar vs tab bar" or "show me 12pt vs 14pt", the output is typically a new `#Preview("<name> compare")` block that stacks the variants. Not a new file, not a new component — just a preview tile for the decision at hand. Delete the compare preview after the decision is made (or promote it to a real variant if both versions ship).

## Example skeleton for a new screen

```swift
struct MyScreen: View {
    // container — reads env, forwards to Content
}

struct MyScreenContent: View {
    // presentational — takes values, no env
}

// MARK: - Previews

#Preview {
    MyScreenContent(state: .default)
}

#Preview("States") {
    VStack(spacing: 16) {
        labeled("Loading") { MyScreenContent(state: .loading) }
        labeled("Empty")   { MyScreenContent(state: .empty) }
        labeled("Error")   { MyScreenContent(state: .error("Something broke")) }
        labeled("Loaded")  { MyScreenContent(state: .loaded(sampleData)) }
    }
    .padding()
}

#Preview("Dark") {
    MyScreenContent(state: .loaded(sampleData))
        .preferredColorScheme(.dark)
}

#Preview("A11y XL") {
    MyScreenContent(state: .loaded(sampleData))
        .environment(\.dynamicTypeSize, .accessibility3)
}

@ViewBuilder
private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.caption2).foregroundStyle(.secondary)
        content()
    }
}
```

Later, a `LabeledPreview` helper will live in `core-swift` so every screen doesn't redefine it. For now, local copies are fine.
