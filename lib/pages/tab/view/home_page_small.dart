import 'package:eros_fe/widget/glass/glass_tab_bar.dart';
import 'package:eros_fe/widget/glass/glass_route_observer.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:get/get.dart';

class TabHomeSmall extends GetView<TabHomeController> {
  const TabHomeSmall({super.key, this.hideTabBar = false});
  final bool hideTabBar;
  @override
  Widget build(BuildContext context) {
    controller.init(inContext: context);

    return Obx(
      () => CupertinoTabScaffold(
        controller: controller.tabController,
        tabBar: GlassTabBar(
          hidden: hideTabBar,
          height: hideTabBar ? 0 : 76,
          routes: List.generate(
            controller.listBottomNavigationBarItem.length,
            controller.routeAtIndex,
          ),
          backgroundColor: kEnableImpeller
              ? CupertinoTheme.of(context).barBackgroundColor.withOpacity(1)
              : null,
          items: controller.listBottomNavigationBarItem,
          onTap: controller.onTap,
        ),
        tabBuilder: (BuildContext context, int index) {
          // return controller.viewList[index];
          return CupertinoTabView(
            navigatorObservers: [GlassRouteObserver()],
            builder: (BuildContext context) {
              // logger.d('build CupertinoTabView');
              final route = controller.routeAtIndex(index);
              return PageStorage(
                bucket: controller.pageStorageBucketFor(route),
                child: controller.viewList[index],
              );
            },
          );
        },
      ),
    );
  }
}
