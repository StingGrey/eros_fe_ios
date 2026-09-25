import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/glass/glass_route_observer.dart';
import 'package:eros_fe/widget/glass/glass_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('glass stays covered until the last modal finishes dismissing', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(CupertinoApp(navigatorKey: navigator,
      navigatorObservers: [GlassRouteObserver()],
      home: const CupertinoPageScaffold(child: SizedBox()),
    ));
    showCupertinoModalPopup<void>(context: navigator.currentContext!,
      builder: (_) => const CupertinoActionSheet(title: Text('Sheet')));
    await tester.pumpAndSettle();
    expect(GlassVisibility.covered.value, isTrue);
    final releaseOverlay = GlassVisibility.coverOverlay();
    navigator.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 50));
    expect(GlassVisibility.covered.value, isTrue);
    await tester.pumpAndSettle();
    expect(GlassVisibility.covered.value, isTrue);
    releaseOverlay();
    releaseOverlay(); // An overlay may notify dismissal more than once.
    await tester.pumpAndSettle();
    expect(GlassVisibility.covered.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab scaffold retains native bar and selection callback when cloning', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(CupertinoApp(home: CupertinoTabScaffold(
      tabBar: GlassTabBar(routes: const [EHRoutes.gallery, EHRoutes.favorite],
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: 'Favorites'),
        ], onTap: (index) => tapped = index),
      tabBuilder: (_, index) => Center(child: Text('Page $index')),
    )));
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
