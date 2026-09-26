class UpscaleModel {
  const UpscaleModel(
    this.id,
    this.name,
    this.descriptionZh,
    this.descriptionEn, {
    this.denoise = false,
  });
  final String id, name, descriptionZh, descriptionEn;
  final bool denoise;
  String description(bool zh) => zh ? descriptionZh : descriptionEn;

  static const all = <UpscaleModel>[
    UpscaleModel(
      'real-cugan-v1',
      'Real-CUGAN 2×',
      '适合漫画线稿与压缩图片，可选保守修复或轻度降噪。强网点可能被误判；异常结果会保留原图。',
      'For manga lines and compressed art, with conservative or light denoising. Dense screen tones can confuse the model; rejected results keep the original.',
      denoise: true,
    ),
    UpscaleModel(
      'waifu2x-cunet-v1',
      'waifu2x CUnet 2×',
      '适合平涂插画与干净线条，可选仅放大或降噪。风格较平滑，降噪可能淡化纸张纹理和网点。',
      'For flat-colour illustrations and clean lines, with optional denoising. Smooth results may soften paper texture and screen tones.',
      denoise: true,
    ),
    UpscaleModel(
      'realesrgan-anime-v1',
      'Real-ESRGAN Anime 2×',
      '使用轻量 AnimeVideo 2× 模型，适合动画彩图和低清插画，偏向重建清晰轮廓。细节可能被重新描绘，建议从较低强度尝试。',
      'Uses the compact AnimeVideo 2× model for animation art and low-resolution illustrations. Reconstructs clear contours; details may be redrawn, so start with lower strength.',
    ),
    UpscaleModel(
      'metalfx-spatial-v1',
      'MetalFX 2×',
      'Apple GPU 空间缩放，适合优先响应速度、希望少做内容重建的页面。没有神经网络降噪与细节修复；实际速度随设备和图片而变。',
      'Apple GPU spatial scaling for responsive enlargement with less content reconstruction. No neural denoising or detail restoration; speed varies by device and image.',
    ),
  ];

  static UpscaleModel? find(String id) {
    for (final model in all) {
      if (model.id == id) return model;
    }
    return null;
  }
}
