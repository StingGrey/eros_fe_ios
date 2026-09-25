import 'package:cupertino_ui/cupertino_ui.dart';

/// Shared rhythm for the library, gallery and reader surfaces.
abstract final class DesignTokens {
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXL = 24;
  static const double radiusS = 10;
  static const double radiusM = 18;
  static const double radiusL = 26;
  static const double controlSize = 44;
  static const double glassSpacing = 12;
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  static const body = TextStyle(fontSize: 15, height: 1.35);
  static const caption = TextStyle(fontSize: 12, height: 1.25);
  static Color surface(BuildContext context) => CupertinoDynamicColor.resolve(
    CupertinoColors.secondarySystemGroupedBackground,
    context,
  );
  static Color background(BuildContext context) =>
      CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground,
        context,
      );
  static Color secondary(BuildContext context) =>
      CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
}
