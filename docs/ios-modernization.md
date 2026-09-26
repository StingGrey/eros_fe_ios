# iOS modernization

Baseline: `fix` at `ae900b3a`; local recovery tag: `backup/fix-before-upgrade-20260926`.

## Toolchain

Use Flutter 3.47.5 / Dart 3.13.4. The local build uses Xcode 27.0, Ruby 3.4.5 and CocoaPods 1.17.0. CI uses macOS 26 and its default Xcode 26.6 (the UIKit glass APIs require the iOS 26 SDK or newer).

SPM integration was exercised with `flutter build ios --no-codesign --no-pub`. Flutter generated the Swift package integration successfully, then required CocoaPods for remaining plugins. Keep the Podfile: flutter_downloader, flutter_inappwebview_ios, Google ML Kit, system_proxy and several other plugins still have no Package.swift.

## Dependency constraints

Do not override incompatible transitive dependencies. Isar 3.3.2 requires analyzer <11; choose compatible build_runner/intl_utils versions. archive_async requires archive 3, constraining image and basic_utils. The existing SAF fork requires permission_handler 11. Desktop plugin constraints on win32 also limit some plus plugins even in an iOS build. Existing Git plugin commits remain pinned in pubspec.lock.

The project intentionally does not depend on sentry_flutter or flutter_lints. Explicit analyzer rules remain in analysis_options.yaml.

## Validation still requiring a device

The iPad Pro M4 was not connected during setup. Installation, main-flow smoke testing, modal compositing, Core ML visual quality and Instruments memory profiling must be recorded separately from build/analyzer results.

## Extracted UI library compatibility

Application pages import material_ui/cupertino_ui. GetX 4.7.3 still uses framework UI types. `UiThemeBridge` supplies the new inherited themes inside GetX; `legacyCupertinoTheme` mirrors their colors and typography for legacy routes. Register both sets of localization delegates because their localization types differ. A widget regression test opens and closes a GetX modal with migrated controls in dark mode.

## Phase A checks

- Dependency resolution completed (87 packages changed).
- build_runner and intl_utils generation completed; Isar collection names and IDs match the baseline.
- Dart analyzer: zero errors (existing warnings/lints remain). Use `dart analyze --format=machine`; Flutter's LSP analyzer command currently fails on this checkout's non-ASCII path.
- `flutter test test/ui_theme_bridge_test.dart`: passed.
- `flutter build ios --no-codesign --no-pub`: passed on Xcode 27.0; fehviewer.app 70.1 MB.

## Phase B: native glass surfaces

`NativeGlassPlugin` uses compile-time UIKit glass APIs with one platform view per toolbar group. Buttons share one `UIVisualEffectView` with `UIGlassEffect(.regular)` per group; iOS 15.6–25 uses system material blur, and Reduce Transparency uses an opaque system surface. Library tabs, filter bars, gallery actions and reader controls use the shared tokens. List cards remain Flutter content.

All root/nested navigators install a glass observer. Non-opaque routes hide native views immediately and restore them only after their transition completes. SmartDialog loading overlays hold a separate, idempotent cover lease. Widget tests cover modal dismissal, overlapping covers, tab selection through CupertinoTabScaffold cloning, and the legacy GetX theme bridge.

Phase B checks: Dart analyzer reported zero errors; all three widget tests passed; the unsigned device build passed (70.2 MB). Modal compositing and the pre-iOS-26 fallback still require runtime checks on a device. Google ML Kit dependencies currently exclude arm64 simulators, so simulator availability alone does not validate this app.

### iPad UI corrections after simulator review

The iPad uses a centered glass navigation bar at the bottom. Gallery browsing fills the available width until a detail is opened. Settings retains its two-column layout at widths of at least 680 points, including after returning from a detail. The left pane contains the account entry and all eight settings categories; the right pane defaults to E-H options. The account card and menu now share an ordinary scrollable column instead of nested custom sliver sections.

Gallery covers use a 200-point maximum grid extent on wide layouts, and category selectors size to their labels. Removing deferred skeleton wrappers prevents cards from remaining blank after resizing. Toolbar buttons use centered content without the legacy navigation-bar padding. Reader controls use shared native glass groups; both sides of their positioned bars are constrained.

The updated full app built and launched on the iPad Pro 13-inch iOS 27 simulator. Screenshots confirm the smaller gallery grid, bottom glass navigation and corrected history-button alignment. Four widget tests pass, covering account/menu visibility and taps, scrolling to the last settings row in a short window, modal coverage, tab selection and theme compatibility. Dart analysis reports zero errors; existing warnings remain. Automated simulator input was unavailable, so the new settings screen and reader still need interactive review. The simulator remains open for that review. The six ML Kit binaries used for the simulator build were restored and verified against their original SHA-256 hashes. This UI revision has not yet been packaged as a new device IPA.

## iOS 27 launch crash correction

The first unsigned package built successfully but crashed immediately on iPadOS 27. The same app reproduced `EXC_BREAKPOINT / SIGTRAP` in an iOS 27 simulator, with `___UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke` at the top of the stack. The custom app delegate had prevented Flutter's automatic UIScene migration.

The app now declares its scene manifest and uses `FlutterSceneDelegate`. Plugin registration runs in `didInitializeImplicitFlutterEngine`, after the implicit engine exists; the downloader's background registration callback remains installed at application launch. Privacy blur follows the scene lifecycle, uses that scene's optional window, and does not force-unwrap the deprecated application key window.

The corrected full app launched and loaded the home list on iPhone 17 and iPad Pro 13-inch simulators running iOS 27. On the iPad simulator, three further cold launches and three background/foreground cycles passed; foreground returns preserved the process ID. An unsigned Release device build also passed. These checks do not validate third-party signing or the user's physical iPad.

For this local simulator check only, the `google_mlkit_commons` bundled `patch_arm64_simulator.py` helper relabeled the six vendored ML Kit binaries for arm64 simulator linking. Xcode command-line overrides selected arm64 and cleared simulator exclusions. Before the Release device build, the helper restored the iOS platform labels and SHA-256 checks confirmed all six binaries matched their original bytes. The Podfile and release dependencies were not changed by this workaround.

## Phase C: local reader upscaling

The app bundles verified Real-CUGAN conservative/light-denoise 2× Core ML models. The native engine uses 512-pixel tiles with 32-pixel overlap, JPEG q95 output, a two-instance model pool and cancellation between tiles. The Dart service reuses the existing preload count, supports local/archive/network-cache sources through one provider decorator, and persists a 4 GiB content-addressed LRU under Application Support. Reading settings persist through the existing Rx/profile mechanism.

The default rules skip source height >=2000 and required physical enlargement <=1.3. Always bypasses those two rules; animations/GIFs, thumbnails, allocation limits and output-quality checks remain. Public test samples exposed unstable colour/halftone output on one synthetic page. It now falls back to the original and records a rejection marker; do not claim universal screen-tone preservation. Details, model provenance, conversion dependencies and harness commands are in `tools/upscale/README.md`.

Local validation includes ten Flutter tests (policy, persistence, LRU, cancellation/concurrency, failure fallback, persistent quality rejection, actual provider decode, modal lifecycle and theme/tab regressions), zero analyzer errors, a successful 75.6 MB unsigned device build, native prediction/feather/cancellation checks, and a 50-job Mac allocation stress run. The latter uses two workers on a repeated 1200×1600 fixture; it is not a full-reader Instruments test. An iPad is still required for signing/installing, main-flow smoke tests, modal compositing, actual galleries and thermal/memory profiling.
