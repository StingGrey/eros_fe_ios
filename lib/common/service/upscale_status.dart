enum UpscalePhase { waiting, queued, processing, ready, enhanced, original }

class UpscalePageStatus {
  const UpscalePageStatus({
    this.phase = UpscalePhase.waiting,
    this.reason,
    this.sourceWidth,
    this.sourceHeight,
    this.outputWidth,
    this.outputHeight,
  });

  final UpscalePhase phase;
  final String? reason;
  final int? sourceWidth, sourceHeight, outputWidth, outputHeight;

  @override
  bool operator ==(Object other) =>
      other is UpscalePageStatus &&
      phase == other.phase &&
      reason == other.reason &&
      sourceWidth == other.sourceWidth &&
      sourceHeight == other.sourceHeight &&
      outputWidth == other.outputWidth &&
      outputHeight == other.outputHeight;

  @override
  int get hashCode => Object.hash(
    phase,
    reason,
    sourceWidth,
    sourceHeight,
    outputWidth,
    outputHeight,
  );
}
