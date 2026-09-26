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
                  '自动增强需要放大的低清页面。阅读时点击顶部页码，可查看当前页是否已增强、像素尺寸和跳过原因。原文件保持不变。',
                  'Enhances low-resolution pages when needed. Tap the reader page counter for enhancement status, dimensions and skip reasons. Originals are preserved.',
                )
              : label(
                  '最近一次增强未完成，已保留原图。请在阅读器顶部页码查看当前页状态。',
                  'A recent enhancement did not complete; its original was preserved. Tap the reader page counter for the current page status.',
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
          () => EhCupertinoListTile(
            title: Text(label('模型 / 算法', 'Model / algorithm')),
            additionalInfo: Text(
              UpscaleModel.find(settings.upscaleModel.value)?.name ??
                  settings.upscaleModel.value,
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _selectModel(context, settings, service, zh),
          ),
        ),
        Obx(() {
          final model = UpscaleModel.find(settings.upscaleModel.value);
          final supported = service.availableModels.value?.contains(model?.id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              [
                model?.description(zh) ??
                    label('未知模型，请重新选择。', 'Unknown model. Please select again.'),
                if (supported == false)
                  label(
                    '当前设备不支持此选项，请选择其他模型。',
                    'Unavailable on this device. Select another model.',
                  ),
              ].join('\n'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          );
        }),
        Obx(
          () => _StrengthControl(
            value: settings.upscaleStrength.value,
            zh: zh,
            onChanged: (value) => settings.upscaleStrength.value = value,
          ),
        ),
        Obx(() {
          final model = UpscaleModel.find(settings.upscaleModel.value);
          if (model?.denoise != true) return const SizedBox.shrink();
          return SelectorCupertinoListTile<int>(
            key: ValueKey('${model!.id}/${settings.upscaleDenoise.value}'),
            title: label('降噪档位', 'Denoising'),
            actionMap: {
              0: model.id == 'waifu2x-cunet-v1'
                  ? label('仅放大', 'Scale only')
                  : label('保守修复', 'Conservative'),
              1: label('轻度降噪', 'Light denoising'),
            },
            initVal: settings.upscaleDenoise.value.clamp(0, 1),
            onValueChanged: (value) => settings.upscaleDenoise.value = value,
          );
        }),
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

  Future<void> _selectModel(
    BuildContext context,
    EhSettingService settings,
    UpscaleService service,
    bool zh,
  ) async {
    await service.ensureCapabilities();
    if (!context.mounted) return;
    final value = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(zh ? '选择 2× 增强方式' : 'Choose 2× enhancement'),
        actions: [
          for (final model in UpscaleModel.all)
            Semantics(
              enabled:
                  service.availableModels.value?.contains(model.id) != false,
              child: IgnorePointer(
                ignoring:
                    service.availableModels.value?.contains(model.id) == false,
                child: CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(model.id),
                  child: Column(
                    children: [
                      Text(
                        '${model.name}${settings.upscaleModel.value == model.id ? ' ✓' : ''}',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        model.description(zh),
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      if (service.availableModels.value?.contains(model.id) ==
                          false)
                        Text(
                          zh ? '当前设备不支持' : 'Unavailable on this device',
                          style: const TextStyle(fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(zh ? '取消' : 'Cancel'),
        ),
      ),
    );
    if (value != null) settings.upscaleModel.value = value;
  }
}

class _StrengthControl extends StatefulWidget {
  const _StrengthControl({
    required this.value,
    required this.zh,
    required this.onChanged,
  });
  final int value;
  final bool zh;
  final ValueChanged<int> onChanged;
  @override
  State<_StrengthControl> createState() => _StrengthControlState();
}

class _StrengthControlState extends State<_StrengthControl> {
  double? _dragValue;
  @override
  Widget build(BuildContext context) {
    final value = _dragValue ?? widget.value.clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.zh ? '处理强度' : 'Processing strength')),
              Text('${value.round()}%'),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlider(
              value: value,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (value) => setState(() => _dragValue = value),
              onChangeEnd: (value) {
                widget.onChanged(value.round());
                setState(() => _dragValue = null);
              },
            ),
          ),
          Text(
            widget.zh
                ? '0% 使用原图；1–100% 将增强结果与高质量普通放大混合，越高越接近所选算法的完整效果。调低可减弱锐化和纹理变化，倍率仍为 2×。松手后应用。'
                : '0% uses the original. 1–100% blends enhancement with high-quality standard scaling. Lower values soften sharpening and texture changes; output remains 2×. Applies when released.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
