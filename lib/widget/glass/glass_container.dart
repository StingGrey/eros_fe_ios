import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/const/design_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'glass_route_observer.dart';

class GlassItem {
  const GlassItem({
    required this.id,
    required this.label,
    required this.symbol,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
  });
  final String id;
  final String label;
  final String symbol;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;
  Map<String, Object> toMap() => {
    'id': id,
    'label': label,
    'symbol': symbol,
    'selected': selected,
    'enabled': enabled,
  };
}

/// One platform view contains the entire native glass group and its buttons.
/// Avoid a platform view per button: UIKit needs the shared container to merge.
class GlassContainer extends StatefulWidget {
  const GlassContainer({
    super.key,
    this.items = const [],
    this.child,
    this.radius = DesignTokens.radiusL,
    this.spacing = DesignTokens.glassSpacing,
    this.dark,
    this.tint,
    this.showLabels = false,
  });
  final List<GlassItem> items;
  final Widget? child;
  final double radius;
  final double spacing;
  final bool? dark;
  final Color? tint;
  final bool showLabels;
  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  MethodChannel? _channel;
  bool get native => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Map<String, Object?> parameters(BuildContext context) => {
    'radius': widget.radius,
    'spacing': widget.spacing,
    'dark':
        widget.dark ?? CupertinoTheme.brightnessOf(context) == Brightness.dark,
    'tint': widget.tint?.toARGB32(),
    'showLabels': widget.showLabels,
    'items': widget.items.map((item) => item.toMap()).toList(),
  };
  void updateNative() {
    if (_channel != null && mounted) {
      unawaited(
        _channel!
            .invokeMethod<void>('update', parameters(context))
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void didUpdateWidget(covariant GlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateNative();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateNative();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: GlassVisibility.covered,
    builder: (context, covered, _) {
      final route = ModalRoute.of(context);
      final showNative = native && !covered && (route?.isCurrent ?? true);
      final fallback = DecoratedBox(
        decoration: BoxDecoration(
          color: widget.dark == true
              ? const Color(0xE6222228)
              : DesignTokens.surface(context),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child:
            widget.child ??
            Row(
              children: widget.items
                  .map(
                    (item) => Expanded(
                      child: CupertinoButton(
                        onPressed: item.enabled ? item.onPressed : null,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DesignTokens.caption,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
      );
      if (!showNative) return fallback;
      final view = UiKitView(
        viewType: 'eros_fe/glass_container',
        creationParams: parameters(context),
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: widget.items.isEmpty
            ? PlatformViewHitTestBehavior.transparent
            : PlatformViewHitTestBehavior.opaque,
        onPlatformViewCreated: (id) {
          if (!mounted) return;
          _channel?.setMethodCallHandler(null);
          _channel = MethodChannel('eros_fe/glass/$id');
          _channel!.setMethodCallHandler((call) async {
            if (call.method == 'tap') {
              for (final item in widget.items) {
                if (item.id == call.arguments && item.enabled) {
                  item.onPressed();
                  break;
                }
              }
            }
          });
          updateNative();
        },
      );
      if (widget.child == null) return view;
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: IgnorePointer(child: view)),
          widget.child!,
        ],
      );
    },
  );
}

extension GlassSurface on Widget {
  Widget glass({bool? dark, double radius = DesignTokens.radiusL}) =>
      GlassContainer(dark: dark, radius: radius, child: this);
}
