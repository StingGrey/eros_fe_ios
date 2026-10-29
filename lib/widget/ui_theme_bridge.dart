import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/cupertino.dart' as legacy;
import 'package:material_ui/material_ui.dart';

/// The framework Cupertino library only resolves its own dynamic color type,
/// so colors from cupertino_ui would keep their light variant there.
Color? _legacyColor(Color? color) => color is CupertinoDynamicColor
    ? legacy.CupertinoDynamicColor(
        color: color.color,
        darkColor: color.darkColor,
        highContrastColor: color.highContrastColor,
        darkHighContrastColor: color.darkHighContrastColor,
        elevatedColor: color.elevatedColor,
        darkElevatedColor: color.darkElevatedColor,
        highContrastElevatedColor: color.highContrastElevatedColor,
        darkHighContrastElevatedColor: color.darkHighContrastElevatedColor,
      )
    : color;

TextStyle _legacyTextStyle(TextStyle style) =>
    style.copyWith(color: _legacyColor(style.color));

/// GetX still builds a framework CupertinoApp. Keep its route transitions and
/// legacy plugins in the same appearance as the extracted UI packages.
legacy.CupertinoThemeData legacyCupertinoTheme(CupertinoThemeData theme) =>
    legacy.CupertinoThemeData(
      brightness: theme.brightness,
      primaryColor: _legacyColor(theme.primaryColor),
      primaryContrastingColor: _legacyColor(theme.primaryContrastingColor),
      barBackgroundColor: _legacyColor(theme.barBackgroundColor),
      scaffoldBackgroundColor: _legacyColor(theme.scaffoldBackgroundColor),
      textTheme: legacy.CupertinoTextThemeData(
        textStyle: _legacyTextStyle(theme.textTheme.textStyle),
        actionTextStyle: _legacyTextStyle(theme.textTheme.actionTextStyle),
        tabLabelTextStyle: _legacyTextStyle(theme.textTheme.tabLabelTextStyle),
        navTitleTextStyle: _legacyTextStyle(theme.textTheme.navTitleTextStyle),
        navLargeTitleTextStyle:
            _legacyTextStyle(theme.textTheme.navLargeTitleTextStyle),
        navActionTextStyle:
            _legacyTextStyle(theme.textTheme.navActionTextStyle),
        pickerTextStyle: _legacyTextStyle(theme.textTheme.pickerTextStyle),
        dateTimePickerTextStyle:
            _legacyTextStyle(theme.textTheme.dateTimePickerTextStyle),
      ),
    );

class UiThemeBridge extends StatelessWidget {
  const UiThemeBridge({super.key, required this.theme, required this.child});

  final CupertinoThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) => CupertinoTheme(
    data: theme,
    child: Theme(
      data: ThemeData(
        brightness: theme.brightness,
        cupertinoOverrideTheme: theme,
      ),
      // The app-level default text style is resolved above any theme, against
      // the platform brightness; re-resolve it against the chosen theme.
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: child,
        ),
      ),
    ),
  );
}
