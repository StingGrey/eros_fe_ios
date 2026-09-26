import 'package:eros_fe/widget/glass/glass_container.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_sublist_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:cupertino_ui/cupertino_ui.dart' hide CupertinoTabBar;
import 'package:get/get.dart';

import '../../comm.dart';
import '../constants.dart';
import 'custom_sub_page.dart';

class CustomTabbarList extends StatefulWidget {
  const CustomTabbarList({super.key});

  @override
  State<CustomTabbarList> createState() => _CustomTabbarListState();
}

class _CustomTabbarListState extends State<CustomTabbarList> {
  final CustomTabbarController controller = Get.find();

  final EhTabController ehTabController = EhTabController();
  final EhSettingService _ehSettingService = Get.find();

  @override
  void initState() {
    super.initState();
    controller.pageController = PageController(initialPage: controller.index);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideTopBarOnScroll = _ehSettingService.hideTopBarOnScroll;

      final Widget scrollView = buildNestedScrollView(
        context,
        hideTopBarOnScroll,
      );

      return CupertinoPageScaffold(child: scrollView);

      // return CupertinoPageScaffold(child: scrollView);
    });
  }

  Widget buildNestedScrollView(BuildContext context, bool hideTopBarOnScroll) {
    final headerMaxHeight = context.mediaQueryPadding.top + kHeaderMaxHeight;
    return ExtendedNestedScrollView(
      floatHeaderSlivers: true,
      onlyOneScrollInBody: true,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverOverlapAbsorber(
            handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
              context,
            ),
            sliver: SliverPersistentHeader(
              floating: true,
              pinned: true,
              delegate: FooSliverPersistentHeaderDelegate(
                builder: (context, offset, _) =>
                    _buildSliverTopBar(context, offset, headerMaxHeight),
                minHeight: hideTopBarOnScroll
                    ? context.mediaQueryPadding.top + kTopTabbarHeight
                    : headerMaxHeight,
                maxHeight: headerMaxHeight,
              ),
            ),
          ),
        ];
      },
      body: buildSubPages(),
    );
  }

  Builder buildSubPages() {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onPanDown: (e) {
            // 恢复启用 scrollToItem
            controller.linkScrollBarController.enableScrollToItem();
          },
          child: Obx(() {
            final hideTopBarOnScroll = _ehSettingService.hideTopBarOnScroll;
            return PageView(
              // CustomScrollPhysics对于改善滑动问题没有帮助
              // physics: const CustomScrollPhysics(),
              key: ValueKey(
                controller.profiles.map((e) => '${e.uuid}${e.name}').join(),
              ),
              controller: controller.pageController,
              children: controller.profiles.isNotEmpty
                  ? [
                      ...controller.profilesShow.map(
                        (e) => SubListView<CustomSubListController>(
                          profileUuid: e.uuid,
                          key: ValueKey(e.uuid),
                          pinned: !hideTopBarOnScroll,
                        ),
                      ),
                    ]
                  : [
                      const Center(
                        child: Text('[ ]', style: TextStyle(fontSize: 40)),
                      ),
                    ],
              onPageChanged: (index) {
                controller.linkScrollBarController.scrollToItem(index);
                controller.onPageChanged(index);
              },
            );
          }),
        );
      },
    );
  }

  Widget _buildSliverTopBar(
    BuildContext context,
    double offset,
    double maxExtentCallBackValue,
  ) {
    // final navBarHeight = maxExtentCallBackValue -
    //     kTopTabbarHeight -
    //     context.mediaQueryPadding.top;
    final navBarOpacity =
        1.0 -
        (offset / (kMinInteractiveDimensionCupertino - 1)).clamp(0.0, 1.0);
    // customBarOpacity 为 navBarOpacity 缩放
    // final customBarOpacity = navBarOpacity * 0.9 + 0.1;
    final customBarOpacity = navBarOpacity;
    // logger.d(
    //     'navBarOpacity: $navBarOpacity, customBarOpacity: $customBarOpacity');

    return SizedBox(
      height: maxExtentCallBackValue,
      // child: Column(
      //   mainAxisSize: MainAxisSize.min,
      //   children: [
      //     // 原导航栏
      //     Expanded(
      //       child: getNavigationBar(context),
      //     ),
      //     // top tabBar
      //     CustomTabBar(controller: controller),
      //   ],
      // ),
      child: Stack(
        children: [
          // 导航栏
          getNavigationBar(context, opacity: navBarOpacity),
          // TabBar固定在底部
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomTabBar(
              controller: controller,
              opacity: customBarOpacity,
            ),
          ),
        ],
      ),
    );
  }

  Widget getNavigationBar(BuildContext context, {double? opacity}) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.scrollToTop(context),
                  child: Text(
                    L10n.of(context).tab_gallery,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 40,
                child: GlassContainer(
                  child: controller.getLeading(context, compact: true),
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => SizedBox(
                  width: controller.afterJump ? 132 : 88,
                  height: 40,
                  child: GlassContainer(
                    items: [
                      GlassItem(
                        id: 'search',
                        label: L10n.of(context).search,
                        symbol: 'magnifyingglass',
                        onPressed: () => NavigatorUtil.goSearchPage(),
                      ),
                      if (controller.afterJump)
                        GlassItem(
                          id: 'top',
                          label: '回到顶部',
                          symbol: 'arrow.up.to.line',
                          onPressed: controller.jumpToTop,
                        ),
                      GlassItem(
                        id: 'jump',
                        label: '跳转页码',
                        symbol: 'arrow.turn.down.right',
                        onPressed: () => controller.showJumpDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JumpButton extends StatelessWidget {
  const JumpButton({super.key, required this.controller});

  final CustomTabbarController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minSize: 36,
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        constraints: const BoxConstraints(minWidth: 24, maxHeight: 26),
        decoration: BoxDecoration(
          border: Border.all(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.activeBlue,
              context,
            ),
            width: 1.8,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Obx(
          () => Text(
            // '${max(1, controller.curPage + 1)}',
            '1',
            textAlign: TextAlign.center,
            textScaler: const TextScaler.linear(0.9),
            // textScaler: const TextScaler.linear(0.9),
            style: TextStyle(
              height: 1.3,
              fontWeight: FontWeight.bold,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.activeBlue,
                context,
              ),
            ),
          ),
        ),
      ),
      onPressed: () {
        controller.showJumpDialog(context);
      },
    );
  }
}

class CustomTabBar extends StatelessWidget {
  const CustomTabBar({super.key, required this.controller, this.opacity = 0.0});

  final CustomTabbarController controller;
  final double opacity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
    child: SizedBox(
      height: kTopTabbarHeight - 10,
      child: Obx(
        () => GlassSegmentedBar(
          items: List.generate(controller.profilesShow.length, (index) {
            final profile = controller.profilesShow[index];
            return GlassItem(
              id: profile.uuid,
              label: profile.name,
              symbol: '',
              selected: index == controller.index,
              onPressed: () => controller.pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              ),
              onLongPress: () => controller.toEditPage(uuid: profile.uuid),
            );
          }),
          action: GlassItem(
            id: 'groups',
            label: '管理分组',
            symbol: 'line.3.horizontal.decrease',
            onPressed: controller.pressedBar,
          ),
        ),
      ),
    ),
  );
}
