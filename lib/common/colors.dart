import 'package:cupertino_ui/cupertino_ui.dart';

@immutable
class EhDynamicColor {
  const EhDynamicColor({
    required Color color,
    required Color darkColor,
    required Color darkGrayColor,
  }) : this._(
          color,
          darkColor,
          darkGrayColor,
        );

  const EhDynamicColor._(
    this.color,
    this.darkColor,
    this.darkGrayColor,
  );

  final Color color;
  final Color darkColor;
  final Color darkGrayColor;
}
