# SwiftUI Previews — troubleshooting

Hands-on remedies for preview failures, derived from real incidents on the Eno Labs iOS apps. Check here before deep-diving into code.

## Symptom: preview canvas spins forever

**Most likely cause: preview agent is being killed and respawned.**

Hit these in order; stop when the canvas renders.

1. **Disable Low Power Mode.** Settings → Battery → Low Power Mode → Off. Plug in the Mac. Low Power throttles the preview agent hard enough that the watchdog kills it before it attaches. This is the #1 cause on a laptop running on battery.
2. **Clean Build Folder.** Product → Clean Build Folder (`⇧⌘K`).
3. **Reset Package Caches.** File → Packages → Reset Package Caches. Wait for SPM to finish re-resolving.
4. **Full reset.** Quit Xcode. In Terminal:
   ```
   rm -rf ~/Library/Developer/Xcode/DerivedData/<AppName>-*
   xcrun simctl shutdown all
   ```
   Reopen the project.
5. **Swap preview device.** On the canvas device picker, switch simulator (e.g. iPhone 17 Pro → iPhone 16), then back. Forces a fresh simruntime attach.
6. **Turn off auto-refresh.** Editor → Canvas → uncheck "Automatically Refresh Previews". Manually hit play on one tile. Avoids auto-refresh thrash while you isolate the problem.

## Symptom: "No such module 'X'" in the editor gutter

**Most likely cause: stale SourceKit-LSP index, not a real build error.**

The gutter (line-number strip with red ⊗ icons) is populated by SourceKit-LSP, which sometimes reports phantom module-resolution errors even when the real compiler succeeds.

**Diagnostic step first:** open the Report Navigator (`⌘9`), pick the most recent Build row, read the real compiler log. If that log shows success, trust it — the gutter is lying.

**If the real build is also failing** with a module error:

1. File → Packages → Reset Package Caches.
2. File → Packages → Update to Latest Package Versions.
3. Product → Clean Build Folder (`⇧⌘K`).
4. If the app uses XcodeGen: re-run `xcodegen` while Xcode is closed, then reopen.

Regenerating `.xcodeproj` while Xcode has the project open can leave SPM linkage in a stuck state that only a full Xcode restart clears.

## Symptom: preview renders once, then pauses

**Canvas says "Automatic preview updating paused."**

Something in the code path you just edited failed. Common causes:

- **Runtime exception** in the preview closure (force-unwrap on nil, MainActor violation). Click the error banner on the canvas for stack trace.
- **Compile error elsewhere in the target** — build errors anywhere pause all previews. `⌘5` Issue Navigator to find it.
- **Faster typing than the canvas can keep up** — just hit Resume (`⌥⌘P`).

## Symptom: "Preview crashed"

A `Swift.fatalError`, force-unwrap, or actor violation fired while the preview rendered. This is always a real logic error.

Click the crash banner → "Diagnostics" for the stack trace. Common patterns:

- Force-unwrapping a mock that wasn't populated: `tour.firstStop!` when the mock has empty stops.
- Touching `UIApplication.shared` in a preview that shouldn't have UIKit access.
- MainActor-isolated property accessed from a non-main context (rare in previews; more common when the mock spawns a `Task`).

## Symptom: preview never reflects my edit

**Freshness contract says: either recompile succeeded and the canvas is fresh, or recompile failed and the canvas is paused with a diagnostic.**

If neither of those is true from your reading:

1. Check Issue Navigator (`⌘5`) — hidden compile errors?
2. Check Report Navigator (`⌘9`) latest build — did it actually run after your save?
3. Is the file you edited in the same module as the preview? If yes, edits should take effect. If no (e.g. you edited core-swift while previewing a Curio file), SPM has to rebuild the dependency, which takes longer.
4. Did you edit a `@State`/`@Observable` initial value but are looking at a preview that already instantiated the object? Previews re-render but don't reset persistent in-memory state of singletons. Don't reference singletons from previews.

## Symptom: preview shows wrong/flickering content

**Cause: non-deterministic inputs.**

- `UUID()` or `Date()` in the mock regenerate on every render. Hardcode.
- `@AppStorage` reads real UserDefaults — stale values persist across previews. Use `UserDefaults(suiteName:)` scoped to tests, or avoid `@AppStorage` in previewable code paths.
- Shared singletons (`SomeService.shared`) read live app state. Always inject mocks; never reference singletons.

## Symptom: "Could not launch preview process" / simulator errors

Usually a simulator-state issue, not code.

```
xcrun simctl shutdown all
xcrun simctl erase all        # destructive — erases all simulator data
```

Then reopen Xcode and retry. If still broken: Xcode → Settings → Platforms → re-download the iOS simulator runtime.

## Escalation path

If all the above fail:

1. Capture a Preview Diagnostics Report: canvas → click the ⚠️ diagnostic icon → "Export Preview Report". Saves a `.txt`.
2. Open a new Claude Code session, reference the file path, ask for a diagnosis. Include what you already tried.
3. If the report is clean but the symptom persists, file an Xcode feedback with the report attached.

## What never works (don't bother)

- **Deleting the `.xcodeproj` and re-generating** without quitting Xcode first. Leaves SPM in a mess.
- **`git clean -fdx`** to "reset everything" — also blows away derived data and untracked files you care about. Use the targeted `rm -rf ~/Library/Developer/Xcode/DerivedData/<AppName>-*` instead.
- **Restarting Mac** — never the problem for preview issues. If it helps, the thing that actually fixed it was DerivedData being cleared during shutdown.
