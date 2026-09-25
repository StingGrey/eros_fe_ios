import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// All navigators share one cover state, but each owns its observer instance.
/// Keep native effects hidden until the dismiss animation has completed.
class GlassVisibility {
  static const channel = MethodChannel('eros_fe/glass');
  static final covered = ValueNotifier<bool>(false);
  static final Set<Route<dynamic>> _covers = {};
  static int _overlays = 0;

  static void _sync() {
    final hidden = _covers.isNotEmpty || _overlays > 0;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(
        channel
            .invokeMethod<void>('setCovered', hidden)
            .catchError((Object _) {}),
      );
    }
    // Navigator notifications can occur during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      covered.value = _covers.isNotEmpty || _overlays > 0;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static void add(Route<dynamic> route) {
    if (route is ModalRoute && !route.opaque) {
      _covers.add(route);
      _sync();
      unawaited(route.completed.then((_) => remove(route)));
    }
  }

  static void remove(Route<dynamic> route) {
    if (_covers.remove(route)) _sync();
  }

  /// For overlays that do not create Navigator routes (e.g. SmartDialog).
  static VoidCallback coverOverlay() {
    _overlays++;
    _sync();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _overlays--;
      _sync();
    };
  }

  static Future<T> duringOverlay<T>(Future<T> Function() show) async {
    final release = coverOverlay();
    try {
      return await show();
    } finally {
      release();
    }
  }
}

class GlassRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      GlassVisibility.add(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      GlassVisibility.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) GlassVisibility.remove(oldRoute);
    if (newRoute != null) GlassVisibility.add(newRoute);
  }
}
