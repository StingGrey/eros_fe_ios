import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/upscale_service.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:get/get.dart';

import 'selector_Item.dart';

class UpscaleSettings extends StatelessWidget {
  const UpscaleSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = Get.find<EhSettingService>();
    final service = Get.find<UpscaleService>();
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    String label(String chinese, String english) => zh ? chinese : english;
    Widget toggle(String title, Rx<bool> value) => EhCupertinoListTile(
      title: Text(title),
      trailing: Obx(
        () => CupertinoSwitch(
          value: value.value,
          onChanged: (enabled) => value.value = enabled,
        ),
      ),
    );
    return SliverCupertinoListSection.listInsetGrouped(
      header: Text(label('本地超分辨率', 'Local upscaling')),
      footer: Obx(
        () => Text(
          service.lastError.value.isEmpty
              ? label(
                  '自动增强需要放大的低清页面。原文件保持不变，结果缓存在设备上。',
                  'Enhances low-resolution pages when needed. Originals are preserved; results stay on this device.',
                )
              : label(
                  '此页暂用原图：${service.lastError.value}',
                  'Using the original image: ${service.lastError.value}',
                ),
        ),
      ),
      children: [
        toggle(
          label('自动 2× 增强', 'Automatic 2× enhancement'),
          settings.upscaleEnabled,
        ),
        toggle(
          label('始终增强静态页面', 'Always enhance still pages'),
          settings.upscaleAlways,
        ),
        Obx(
          () => SelectorCupertinoListTile<int>(
            title: label('源图高度上限', 'Source height limit'),
            actionMap: const {
              1500: '1500 px',
              2000: '2000 px',
              2400: '2400 px',
            },
            initVal: settings.upscaleSkipHeight.value,
            onValueChanged: (value) => settings.upscaleSkipHeight.value = value,
          ),
        ),
        Obx(
          () => SelectorCupertinoListTile<double>(
            title: label('需要放大超过', 'Minimum required enlargement'),
            actionMap: {1.1: '1.1×', 1.3: '1.3×', 1.5: '1.5×'},
            initVal: settings.upscaleNeedScale.value,
            onValueChanged: (value) => settings.upscaleNeedScale.value = value,
          ),
        ),
        Obx(
          () => SelectorCupertinoListTile<String>(
            title: label('模型', 'Model'),
            actionMap: const {'real-cugan-v1': 'Real-CUGAN 2×'},
            initVal: settings.upscaleModel.value,
            onValueChanged: (value) => settings.upscaleModel.value = value,
          ),
        ),
        Obx(
          () => SelectorCupertinoListTile<int>(
            title: label('修复强度', 'Restoration strength'),
            actionMap: {
              0: label('保守修复', 'Conservative'),
              1: label('轻度降噪', 'Light denoising'),
            },
            initVal: settings.upscaleDenoise.value,
            onValueChanged: (value) => settings.upscaleDenoise.value = value,
          ),
        ),
        Obx(
          () => SelectorCupertinoListTile<int>(
            title: label('缓存上限', 'Cache limit'),
            actionMap: const {1: '1 GB', 2: '2 GB', 4: '4 GB', 8: '8 GB'},
            initVal: settings.upscaleCacheGB.value,
            onValueChanged: (value) => settings.upscaleCacheGB.value = value,
          ),
        ),
      ],
    );
  }
}
