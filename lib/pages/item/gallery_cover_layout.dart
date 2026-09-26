import 'dart:math' as math;

/// Older history entries may not have cover dimensions yet.
double galleryCoverAspectRatio(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 3 / 4;
  }
  return math.max(width / height, 1 / 2);
}
