import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/widget/ui_theme_bridge.dart';
import 'package:flutter/cupertino.dart' as legacy;
import 'package:flutter_localizations/flutter_localizations.dart' as old_l10n;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('migrated controls and GetX modal routes share dark appearance', (
    tester,
  ) async {
    const theme = CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: CupertinoColors.systemOrange,
    );
    await tester.pumpWidget(
      GetCupertinoApp(
        theme: legacyCupertinoTheme(theme),
        localizationsDelegates: const [
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          old_l10n.GlobalCupertinoLocalizations.delegate,
          old_l10n.GlobalMaterialLocalizations.delegate,
          old_l10n.GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => UiThemeBridge(theme: theme, child: child!),
        home: Builder(
          builder: (context) {
            expect(CupertinoTheme.of(context).brightness, Brightness.dark);
            expect(
              legacy.CupertinoTheme.of(context).brightness,
              Brightness.dark,
            );
            expect(
              CupertinoLocalizations.of(context).alertDialogLabel,
              isNotEmpty,
            );
            expect(
              legacy.CupertinoLocalizations.of(context).alertDialogLabel,
              isNotEmpty,
            );
            return CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () => Get.dialog<void>(
                    const CupertinoAlertDialog(
                      title: Text('Modal'),
                      content: Text('Readable on a dark surface'),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Modal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text('Modal'), findsNothing);
    Get.reset();
  });
}
