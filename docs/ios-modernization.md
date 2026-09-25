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
