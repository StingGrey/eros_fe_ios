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
    super.onTap,
    super.currentIndex,
    super.backgroundColor,
    super.activeColor,
    super.inactiveColor,
    super.iconSize,
    super.border,
    super.height = 64,
  });

  final List<String> routes;
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      DesignTokens.spaceS,
      DesignTokens.spaceXS,
      DesignTokens.spaceS,
      MediaQuery.viewPaddingOf(context).bottom + DesignTokens.spaceXS,
    ),
    child: SizedBox(
      height: height - DesignTokens.spaceS,
      child: GlassContainer(
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
