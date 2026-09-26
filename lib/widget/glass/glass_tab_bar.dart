import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/const/design_tokens.dart';
import 'package:eros_fe/route/routes.dart';

import 'glass_container.dart';

/// CupertinoTabScaffold clones its bar to inject the selected index and tap
/// callback, so the native implementation must survive copyWith.
class GlassTabBar extends CupertinoTabBar {
  const GlassTabBar({
    super.key,
    required super.items,
    required this.routes,
    this.hidden = false,
    super.onTap,
    super.currentIndex,
    super.backgroundColor,
    super.activeColor,
    super.inactiveColor,
    super.iconSize,
    super.border,
    super.height = 76,
  });

  final List<String> routes;
  final bool hidden;
  static const symbols = {
    EHRoutes.gallery: 'square.stack',
    EHRoutes.favorite: 'heart',
    EHRoutes.toplist: 'chart.bar',
    EHRoutes.history: 'clock',
    EHRoutes.download: 'arrow.down.circle',
    EHRoutes.setting: 'gearshape',
  };

  @override
  bool opaque(BuildContext context) => false;

  @override
  Widget build(BuildContext context) => hidden
      ? const SizedBox.shrink()
      : Padding(
          padding: EdgeInsets.fromLTRB(
            DesignTokens.spaceL,
            DesignTokens.spaceXS,
            DesignTokens.spaceL,
            MediaQuery.viewPaddingOf(context).bottom > 0
                ? MediaQuery.viewPaddingOf(context).bottom
                : 12,
          ),
          child: SizedBox(
            height: 60,
            child: GlassContainer(
              style: 'navigation',
              radius: 30,
              showLabels: true,
              items: List.generate(
                items.length,
                (index) => GlassItem(
                  id: '$index',
                  label: items[index].label ?? '',
                  symbol: symbols[routes[index]] ?? 'square.stack',
                  selected: index == currentIndex,
                  onPressed: () => onTap?.call(index),
                ),
              ),
            ),
          ),
        );

  @override
  GlassTabBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) => GlassTabBar(
    key: key ?? this.key,
    routes: routes,
    hidden: hidden,
    items: items ?? this.items,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    activeColor: activeColor ?? this.activeColor,
    inactiveColor: inactiveColor ?? this.inactiveColor,
    iconSize: iconSize ?? this.iconSize,
    height: height ?? this.height,
    border: border ?? this.border,
    currentIndex: currentIndex ?? this.currentIndex,
    onTap: onTap ?? this.onTap,
  );
}
