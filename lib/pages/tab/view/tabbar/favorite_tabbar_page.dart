import 'package:eros_fe/widget/glass/glass_container.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:get/get.dart';

import '../../comm.dart';
import '../constants.dart';
import 'favorite_sub_page.dart';

class FavoriteTabTabBarPage extends StatefulWidget {
  const FavoriteTabTabBarPage({super.key});

  @override
  State<FavoriteTabTabBarPage> createState() => _FavoriteTabTabBarPageState();
}

class _FavoriteTabTabBarPageState extends State<FavoriteTabTabBarPage> {
  final EhTabController ehTabController = EhTabController();
  final LinkScrollBarController linkScrollBarController =
      LinkScrollBarController();
  final controller = Get.find<FavoriteTabBarController>();
  late PageController pageController;

  final EhSettingService _ehSettingService = Get.find();

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: controller.index);
  }

  @override
  Widget build(BuildContext context) {
    final headerMaxHeight = context.mediaQueryPadding.top + kHeaderMaxHeight;

    return Obx(() {
      final hideTopBarOnScroll = _ehSettingService.hideTopBarOnScroll;

      final scrollView = buildNestedScrollView(
        headerMaxHeight,
        hideTopBarOnScroll,
      );

      return CupertinoPageScaffold(
        // navigationBar: navigationBar,
        child: scrollView,
      );
    });
  }

  Widget _buildTopBar(
    BuildContext context,
    double offset,
    double maxExtentCallBackValue,
  ) {
    final navBarOpacity =
        1.0 -
        (offset / (kMinInteractiveDimensionCupertino - 1)).clamp(0.0, 1.0);
    final customBarOpacity = navBarOpacity;
    return SizedBox(
      height: maxExtentCallBackValue,
      child: Stack(
        children: [
          getNavigationBar(context, opacity: navBarOpacity),
          Align(
            alignment: Alignment.bottomCenter,
            child: FavoriteTabBar(
              pageController: pageController,
              linkScrollBarController: linkScrollBarController,
              controller: controller,
              opacity: customBarOpacity,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNestedScrollView(
    double headerMaxHeight,
    bool hideTopBarOnScroll,
  ) {
    return ExtendedNestedScrollView(
      floatHeaderSlivers: true,
      onlyOneScrollInBody: true,
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
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
                    _buildTopBar(context, offset, headerMaxHeight),
                // minHeight: context.mediaQueryPadding.top + kTopTabbarHeight,
                minHeight: hideTopBarOnScroll
                    ? context.mediaQueryPadding.top + kTopTabbarHeight
                    : headerMaxHeight,
                maxHeight: headerMaxHeight,
              ),
            ),
          ),
        ];
      },
      body: buildBody(),
    );
  }

  Builder buildBody() {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onPanDown: (e) {
            // 恢复启用 scrollToItem
            linkScrollBarController.enableScrollToItem();
          },
          child: Obx(() {
            final hideTopBarOnScroll = _ehSettingService.hideTopBarOnScroll;
            return PageView(
              key: ValueKey(controller.showBarsBtn), // 登录状态变化后能刷新
              controller: pageController,
              children: [
                ...controller.favcatList.map(
                  (e) => FavoriteSubPage(
                    favcat: e.favId,
                    pinned: !hideTopBarOnScroll,
                  ),
                ),
              ],
              onPageChanged: (index) {
                linkScrollBarController.scrollToItem(index);
                controller.onPageChanged(index);
              },
            );
          }),
        );
      },
    );
  }

  Widget getNavigationBar(BuildContext context, {double? opacity}) => SafeArea(
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
                  L10n.of(context).tab_favorite,
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
            SizedBox(
              width: 132,
              height: 40,
              child: Obx(
                () => GlassContainer(
                  items: [
                    GlassItem(
                      id: 'search',
                      label: L10n.of(context).search,
                      symbol: 'magnifyingglass',
                      onPressed: () => NavigatorUtil.goSearchPage(
                        searchType: SearchType.favorite,
                      ),
                    ),
                    GlassItem(
                      id: 'sort',
                      label: controller.orderText,
                      symbol: 'arrow.up.arrow.down',
                      onPressed: () => controller.setOrder(context),
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

class FavoriteTabBar extends StatelessWidget {
  const FavoriteTabBar({
    super.key,
    required this.pageController,
    required this.linkScrollBarController,
    required this.controller,
    this.opacity = 0.0,
  });

  final PageController pageController;
  final LinkScrollBarController linkScrollBarController;
  final FavoriteTabBarController controller;
  final double opacity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
    child: SizedBox(
      height: kTopTabbarHeight - 10,
      child: Obx(
        () => GlassSegmentedBar(
          items: List.generate(
            controller.favcatList.length,
            (index) => GlassItem(
              id: '${controller.favcatList[index].favId}',
              label: controller.favcatList[index].favTitle,
              symbol: '',
              selected: index == controller.index,
              onPressed: () => pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
          action: controller.showBarsBtn
              ? GlassItem(
                  id: 'folders',
                  label: '选择收藏夹',
                  symbol: 'folder',
                  onPressed: () async {
                    final result = await Get.toNamed(
                      EHRoutes.selFavorite,
                      id: isLayoutLarge ? 1 : null,
                    );
                    if (result is Favcat) {
                      final index = controller.favcatList.indexWhere(
                        (e) => e.favId == result.favId,
                      );
                      if (index >= 0) pageController.jumpToPage(index);
                    }
                  },
                )
              : null,
        ),
      ),
    ),
  );
}
