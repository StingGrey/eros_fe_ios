import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/common/service/upscale_service.dart';

class UpscaleStatusIndicator extends StatelessWidget {
  const UpscaleStatusIndicator({
    super.key,
    required this.service,
    required this.ids,
    required this.firstPage,
    required this.totalPages,
  });

  final UpscaleService service;
  final List<String> ids;
  final int firstPage, totalPages;

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return StreamBuilder<String>(
      stream: service.statusChanges.where(ids.contains),
      builder: (context, _) {
        final statuses = ids.map(service.statusFor).toList();
        final label = statuses.map((s) => _label(s, zh)).toSet().join(' / ');
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          onPressed: () => showCupertinoModalPopup<void>(
            context: context,
            builder: (context) => StreamBuilder<String>(
              stream: service.statusChanges.where(ids.contains),
              builder: (context, _) => CupertinoActionSheet(
                title: Text(zh ? '当前页面超分状态' : 'Page enhancement'),
                message: Text(
                  [
                    for (var i = 0; i < ids.length; i++)
                      '${zh ? '第 ${firstPage + i} 页' : 'Page ${firstPage + i}'}\n'
                          '${_details(service.statusFor(ids[i]), service.options(), zh)}',
                  ].join('\n\n'),
                ),
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(zh ? '关闭' : 'Close'),
                ),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$firstPage / $totalPages',
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.white,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: statuses.every((s) => s.phase == UpscalePhase.enhanced)
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _label(UpscalePageStatus status, bool zh) => switch (status.phase) {
  UpscalePhase.waiting => zh ? '等待原图' : 'Waiting for image',
  UpscalePhase.queued => zh ? '超分排队中' : 'Enhancement queued',
  UpscalePhase.processing => zh ? '超分处理中' : 'Enhancing',
  UpscalePhase.ready => zh ? '超分待显示' : 'Enhancement ready',
  UpscalePhase.enhanced => zh ? '超分 2×' : 'Enhanced 2×',
  UpscalePhase.original => zh ? '原图' : 'Original',
};

String _details(UpscalePageStatus status, UpscaleOptions options, bool zh) {
  final lines = <String>[_label(status, zh)];
  final model = UpscaleModel.find(options.model);
  lines.add('${model?.name ?? options.model} · ${options.effectiveStrength}%');
  if (model?.denoise == true) {
    lines.add(
      options.effectiveDenoise == 1
          ? (zh ? '轻度降噪' : 'Light denoising')
          : (zh ? '保守 / 仅放大' : 'Conservative / scale only'),
    );
  }
  if (status.sourceWidth != null && status.sourceHeight != null) {
    lines.add(
      '${zh ? '原图' : 'Source'}: ${status.sourceWidth} × ${status.sourceHeight} px',
    );
  }
  if (status.phase == UpscalePhase.enhanced) {
    lines.add(
      '${zh ? '当前显示' : 'Displaying'}: ${status.outputWidth} × ${status.outputHeight} px',
    );
  }
  final reason = switch (status.reason) {
    'disabled' => zh ? '自动增强已关闭。' : 'Automatic enhancement is off.',
    'strength' => zh ? '处理强度为 0%，使用原图。' : 'Strength is 0%; using the original.',
    'unsupported' => zh ? '当前设备不支持所选增强方式，请在阅读设置中选择其他模型。' : 'This device does not support the selected upscaler. Choose another in reading settings.',
    'height' =>
      zh
          ? '源图高度达到 ${options.skipHeight} px 上限，使用原图。'
          : 'Source height meets the ${options.skipHeight} px limit; using the original.',
    'ratio' =>
      zh
          ? '所需放大未超过 ${options.needScale}×，使用原图。'
          : 'Required enlargement does not exceed ${options.needScale}×.',
    'animated' => zh ? '动画图片使用原图。' : 'Animations use the original image.',
    'thumbnail' =>
      zh
          ? '缩略图或过小图片不增强。'
          : 'Thumbnails and very small images are not enhanced.',
    'quality' =>
      zh
          ? '增强结果未通过质量检查，已回退原图。'
          : 'The enhanced image failed quality checks; using the original.',
    null => null,
    _ =>
      zh
          ? '本页增强失败，使用原图。'
          : 'Enhancement failed for this page; using the original.',
  };
  if (reason != null) lines.add(reason);
  if (status.phase == UpscalePhase.processing ||
      status.phase == UpscalePhase.queued ||
      status.phase == UpscalePhase.ready) {
    lines.add(
      zh
          ? '处理完成并显示后，才会标记为「超分 2×」。'
          : 'Marked enhanced only after the output is displayed.',
    );
  }
  return lines.join('\n');
}
