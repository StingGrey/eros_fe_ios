import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/cupertino.dart' as legacy;
import 'package:material_ui/material_ui.dart';

/// GetX still builds a framework CupertinoApp. Keep its route transitions and
/// legacy plugins in the same appearance as the extracted UI packages.
legacy.CupertinoThemeData legacyCupertinoTheme(CupertinoThemeData theme) =>
    legacy.CupertinoThemeData(
      brightness: theme.brightness,
      primaryColor: theme.primaryColor,
      primaryContrastingColor: theme.primaryContrastingColor,
      barBackgroundColor: theme.barBackgroundColor,
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      textTheme: legacy.CupertinoTextThemeData(
        textStyle: theme.textTheme.textStyle,
        actionTextStyle: theme.textTheme.actionTextStyle,
        tabLabelTextStyle: theme.textTheme.tabLabelTextStyle,
        navTitleTextStyle: theme.textTheme.navTitleTextStyle,
        navLargeTitleTextStyle: theme.textTheme.navLargeTitleTextStyle,
        navActionTextStyle: theme.textTheme.navActionTextStyle,
        pickerTextStyle: theme.textTheme.pickerTextStyle,
        dateTimePickerTextStyle: theme.textTheme.dateTimePickerTextStyle,
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
      child: child,
    ),
  );
}
