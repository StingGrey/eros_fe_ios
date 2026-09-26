import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/item/user_item.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/pages/tab/view/setting_menu.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:get/get.dart';

class SettingTab extends GetView<SettingViewController> {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context) {
    controller.initData(context);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground,
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(L10n.of(context).tab_setting),
        border: null,
      ),
      child: SettingMenu(
        account: Obx(
          () => Get.find<EhSettingService>().isSafeMode.value
              ? const SizedBox.shrink()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: UserItem(),
                ),
        ),
        items: List.generate(
          controller.itemCount,
          controller.cupertinoListTileBuilder,
        ),
      ),
    );
  }
}
