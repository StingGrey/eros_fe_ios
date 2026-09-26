import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_item_flow.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class EhWaterfallFlow extends StatelessWidget {
  const EhWaterfallFlow(
    this.galleryProviders,
    this.tabTag, {
    this.next,
    this.lastComplete,
    this.large = false,
    this.centerKey,
    this.lastTopItemIndex,
    super.key,
  });

  final List<GalleryProvider> galleryProviders;
  final dynamic tabTag;
  final String? next;
  final VoidCallback? lastComplete;
  final bool large;
  final Key? centerKey;
  final int? lastTopItemIndex;

  EhSettingService get _ehSettingService => Get.find();

  @override
  Widget build(BuildContext context) {
    final indices = {
      for (var i = 0; i < galleryProviders.length; i++)
        ValueKey(galleryProviders[i].gid): i,
      if (centerKey != null && lastTopItemIndex != null)
        centerKey!: lastTopItemIndex!,
    };
    final double _padding = large
        ? EHConst.waterfallFlowLargeCrossAxisSpacing
        : EHConst.waterfallFlowCrossAxisSpacing;

    final crossAxisSpacing = large
        ? EHConst.waterfallFlowLargeCrossAxisSpacing
        : EHConst.waterfallFlowCrossAxisSpacing;

    final mainAxisSpacing = large
        ? EHConst.waterfallFlowLargeMainAxisSpacing
        : EHConst.waterfallFlowMainAxisSpacing;

    return SliverPadding(
      padding: EdgeInsets.all(_padding),
      sliver: SliverWaterfallFlow(
        key: key,
        gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: getMaxCrossAxisExtent(),
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          lastChildLayoutTypeBuilder: (int index) =>
              index == galleryProviders.length
              ? LastChildLayoutType.foot
              : LastChildLayoutType.none,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (galleryProviders.length - 1 < index) {
              return const SizedBox.shrink();
            }

            if (index == galleryProviders.length - 1 &&
                (next?.isNotEmpty ?? false)) {
              // 加载完成最后一项的回调
              lastComplete?.call();
            }

            final GalleryProvider _provider = galleryProviders[index];
            Get.lazyReplace(() => _provider, tag: _provider.gid, fenix: true);
            Get.lazyReplace(
              () => GalleryItemController(
                galleryProvider: Get.find(tag: _provider.gid),
              ),
              tag: _provider.gid,
              fenix: true,
            );

            if (large) {
              return GalleryItemFlowLarge(
                key: index == lastTopItemIndex
                    ? centerKey
                    : ValueKey(_provider.gid),
                galleryProvider: _provider,
                tabTag: tabTag,
              );
            } else {
              return GalleryItemFlow(
                key: index == lastTopItemIndex
                    ? centerKey
                    : ValueKey(_provider.gid),
                galleryProvider: _provider,
                tabTag: tabTag,
              );
            }
          },
          childCount: galleryProviders.length,
          // History moves an opened gallery to the front. Preserve each card's
          // element by gallery ID, including while the iPad pane changes width.
          findChildIndexCallback: (key) => indices[key],
        ),
      ),
    );
  }

  double getMaxCrossAxisExtent() {
    if (large) {
      final itemConfig = _ehSettingService.getItemConfig(
        ListModeEnum.waterfallLarge,
      );
      const defaultMaxCrossAxisExtent =
          EHConst.waterfallFlowLargeMaxCrossAxisExtent;
      if (itemConfig?.enableCustomWidth ?? false) {
        return itemConfig?.customWidth?.toDouble() ?? defaultMaxCrossAxisExtent;
      } else {
        return defaultMaxCrossAxisExtent;
      }
    } else {
      final itemConfig = _ehSettingService.getItemConfig(
        ListModeEnum.waterfall,
      );
      final defaultMaxCrossAxisExtent = Get.context!.isPhone
          ? EHConst.waterfallFlowMaxCrossAxisExtent
          : EHConst.waterfallFlowMaxCrossAxisExtentTablet;
      if (itemConfig?.enableCustomWidth ?? false) {
        return itemConfig?.customWidth?.toDouble() ?? defaultMaxCrossAxisExtent;
      } else {
        return defaultMaxCrossAxisExtent;
      }
    }
  }
}
