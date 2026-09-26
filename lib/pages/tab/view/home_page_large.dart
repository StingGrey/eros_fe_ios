import 'dart:math';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/const/design_tokens.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/route/app_pages.dart';
import 'package:eros_fe/route/first_observer.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/route/second_observer.dart';
import 'package:eros_fe/widget/glass/glass_container.dart';
import 'package:eros_fe/widget/glass/glass_route_observer.dart';
import 'package:eros_fe/widget/glass/glass_tab_bar.dart';
import 'package:get/get.dart';

import 'home_page_small.dart';

const kMinWidth = 340.0;

/// Browse fills the available space until a detail route is actually opened.
/// Both navigators remain mounted so search and list positions survive resizing.
class TabHomeLarge extends StatefulWidget {
  const TabHomeLarge({super.key, this.sideProportion = 0});
  final double sideProportion;

  @override
  State<TabHomeLarge> createState() => _TabHomeLargeState();
}

class _TabHomeLargeState extends State<TabHomeLarge> {
  final controller = Get.find<TabHomeController>();
  final detailVisible = ValueNotifier(false);
  late final NavigatorObserver detailObserver = _DetailObserver((visible) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) detailVisible.value = visible;
    });
  });

  @override
  void initState() {
    super.initState();
    controller.tabController.addListener(_tabChanged);
  }

  void _tabChanged() => setState(() {});
  bool get settingsActive =>
      controller.routeAtIndex(controller.tabController.index) ==
      EHRoutes.setting;

  @override
  void dispose() {
    controller.tabController.removeListener(_tabChanged);
    detailVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    controller.init(inContext: context);
    final mainObserver = MainNavigatorObserver();
    return ColoredBox(
      color: DesignTokens.background(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: detailVisible,
              builder: (context, visible, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final showDetail = visible || settingsActive;
                  final split = showDetail && width >= 680;
                  final masterWidth = split
                      ? (360 + max(0.0, width - 720) * widget.sideProportion)
                            .clamp(300.0, width - 340)
                      : width;
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      padding: media.padding.copyWith(
                        bottom: media.padding.bottom + 80,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: masterWidth,
                          child: ClipRect(
                            child: Navigator(
                              key: Get.nestedKey(1),
                              observers: [
                                FirstNavigatorObserver(),
                                GlassRouteObserver(),
                                if (mainObserver.navigator == null)
                                  mainObserver,
                              ],
                              onGenerateRoute: (settings) {
                                final route = AppPages.routes.firstWhereOrNull(
                                  (e) => e.name == settings.name,
                                );
                                return GetPageRoute(
                                  settings: settings,
                                  showCupertinoParallax: false,
                                  page:
                                      route != null &&
                                          route.name != EHRoutes.root &&
                                          route.name != EHRoutes.home
                                      ? route.page
                                      : () => const TabHomeSmall(
                                          hideTabBar: true,
                                        ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: split ? width - masterWidth : width,
                          child: Offstage(
                            offstage: !showDetail,
                            child: SideControllerbar(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: CupertinoDynamicColor.resolve(
                                        CupertinoColors.separator,
                                        context,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: ClipRect(
                                  child: Navigator(
                                    key: Get.nestedKey(2),
                                    observers: [
                                      SecondNavigatorObserver(),
                                      GlassRouteObserver(),
                                      detailObserver,
                                    ],
                                    initialRoute: EHRoutes.empty,
                                    onGenerateInitialRoutes:
                                        (navigator, initialRoute) => [
                                          GetPageRoute(
                                            settings: const RouteSettings(
                                              name: EHRoutes.empty,
                                            ),
                                            page: () => ListenableBuilder(
                                              listenable:
                                                  controller.tabController,
                                              builder: (context, _) => AppPages
                                                  .routes
                                                  .firstWhere(
                                                    (route) =>
                                                        route.name ==
                                                        (settingsActive
                                                            ? EHRoutes.ehSetting
                                                            : EHRoutes.empty),
                                                  )
                                                  .page(),
                                            ),
                                          ),
                                        ],
                                    onGenerateRoute: AppPages.onGenerateRoute,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Obx(() {
                    final tabs = controller.listBottomNavigationBarItem;
                    return ListenableBuilder(
                      listenable: controller.tabController,
                      builder: (context, _) => SizedBox(
                        height: 64,
                        child: GlassContainer(
                          style: 'navigation',
                          showLabels: true,
                          radius: 32,
                          items: List.generate(
                            tabs.length,
                            (index) => GlassItem(
                              id: '$index',
                              label: tabs[index].label ?? '',
                              symbol:
                                  GlassTabBar.symbols[controller.routeAtIndex(
                                    index,
                                  )] ??
                                  'square.stack',
                              selected: controller.tabController.index == index,
                              onPressed: () {
                                final route = controller.routeAtIndex(index);
                                final wasSettings =
                                    controller.routeAtIndex(
                                      controller.tabController.index,
                                    ) ==
                                    EHRoutes.setting;
                                if (route != EHRoutes.setting || !wasSettings) {
                                  Get.nestedKey(1)?.currentState
                                      ?.popUntil((route) => route.isFirst);
                                  Get.nestedKey(2)?.currentState
                                      ?.popUntil((route) => route.isFirst);
                                }
                                controller.tabController.index = index;
                                controller.onTap(index);
                                if (route == EHRoutes.setting &&
                                    !(Get.nestedKey(2)?.currentState
                                            ?.canPop() ??
                                        false)) {
                                  Get.toNamed(EHRoutes.ehSetting, id: 2);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailObserver extends NavigatorObserver {
  _DetailObserver(this.changed);
  final ValueChanged<bool> changed;
  final List<Route<dynamic>> routes = [];
  void notify() => changed(
    routes.any(
      (route) =>
          route is PageRoute &&
          route.settings.name != null &&
          route.settings.name != EHRoutes.empty &&
          route.settings.name != EHRoutes.root,
    ),
  );
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    notify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    routes.remove(oldRoute);
    if (newRoute != null) routes.add(newRoute);
    notify();
  }
}

class SideControllerbar extends StatefulWidget {
  const SideControllerbar({Key? key, required this.child}) : super(key: key);
  final Widget child;

  @override
  _SideControllerbarState createState() => _SideControllerbarState();
}

class _SideControllerbarState extends State<SideControllerbar> {
  bool isTapDown = false;
  final LayoutServices layoutServices = Get.find();

  Widget _normalBar({bool dragging = false}) {
    return AnimatedContainer(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGrey,
          context,
        ).withOpacity(0.7),
        borderRadius: BorderRadius.circular(dragging ? 5.0 : 1.5),
      ),
      margin: EdgeInsets.only(
        left: dragging ? 5.0 : 2.0,
        right: dragging ? 5.0 : 20.0,
      ),
      height: dragging ? 80 : 55,
      width: dragging ? 10 : 3,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      child: const SizedBox.expand(),
    );
  }

  Widget getbar() {
    return _normalBar(dragging: isTapDown);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        widget.child,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            setState(() {
              isTapDown = true;
            });
          },
          onPanEnd: (_) {
            setState(() {
              isTapDown = false;
            });
          },
          onPanCancel: () {
            setState(() {
              isTapDown = false;
            });
          },
          onPanUpdate: (details) {
            if (context.width <= 2 * kMinWidth) return;
            final proportion =
                layoutServices.sideProportion +
                details.delta.dx / (context.width - 2 * kMinWidth);

            layoutServices.sideProportion = max(min(1.0, proportion), 0.0);
          },
          child: getbar(),
        ),
      ],
    );
  }
}
