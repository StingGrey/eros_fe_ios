import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/pages/tab/view/setting_menu.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const titles = ['E-H', '样式', '阅读', '下载', '搜索', '高级', '安全', '关于'];

  testWidgets('account and every setting remain reachable in the iPad pane', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    String? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 24, bottom: 100),
          ),
          child: CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(middle: Text('设置')),
            child: SettingMenu(
              account: SizedBox(
                height: 91,
                child: CupertinoButton(
                  onPressed: () => selected = '登录',
                  child: const Text('登录'),
                ),
              ),
              items: [
                for (final title in titles)
                  EhCupertinoListTile(
                    title: Text(title),
                    leading: const Icon(CupertinoIcons.gear),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => selected = title,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final title in ['登录', ...titles]) {
      expect(find.text(title).hitTestable(), findsOneWidget);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(selected, title);
    }

    // A short Stage Manager window must still let the user reach the final row.
    tester.view.physicalSize = const Size(320, 450);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('关于'), 120);
    await tester.pumpAndSettle();
    expect(find.text('关于').hitTestable(), findsOneWidget);
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    expect(selected, '关于');
    expect(tester.takeException(), isNull);
  });
}
