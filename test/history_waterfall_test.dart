import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/list/waterfall_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends EhSettingService {
  @override
  void onInit() {}
}
class _Locale extends LocaleService {
  @override
  void onInit() {}
}
class _Theme extends ThemeService {
  @override
  void onInit() {}
}
// These collaborators are only used by card actions, not rendering.
class _History extends GetxController implements HistoryController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _Favorites extends GetxController implements FavController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _Tabs extends GetxController implements TabHomeController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('history cards survive reordering, missing dimensions and pane resize', (tester) async {
    Get.testMode = true;
    Get.put<LocaleService>(_Locale());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    Get.put<HistoryController>(_History());
    Get.put<FavController>(_Favorites());
    Get.put<TabHomeController>(_Tabs());
    addTearDown(Get.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var records = [
      for (var i = 0; i < 6; i++)
        GalleryProvider(gid: '$i', englishTitle: 'Gallery $i', imgUrl: '',
          imgWidth: i == 2 ? 0 : 300, imgHeight: i == 2 ? 0 : 400,
          ratingFallBack: 4, filecount: '20'),
    ];
    late StateSetter rebuild;
    await tester.pumpWidget(GetCupertinoApp(home: StatefulBuilder(
      builder: (context, setState) {
        rebuild = setState;
        return CustomScrollView(slivers: [EhWaterfallFlow(records, 'history', large: true)]);
      },
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 6; i++) {
      expect(find.text('Gallery $i'), findsOneWidget);
      final size = tester.getSize(find.byKey(ValueKey<String?>('$i')));
      expect(size.width.isFinite && size.height.isFinite, isTrue);
      expect(size.height, greaterThan(100));
    }
    final originalElement = tester.element(find.byKey(const ValueKey<String?>('4')));
    rebuild(() { records = [records[4], ...records.where((r) => r.gid != '4')]; });
    await tester.pumpAndSettle();
    expect(tester.element(find.byKey(const ValueKey<String?>('4'))), same(originalElement));
    tester.view.physicalSize = const Size(360, 2000);
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      expect(find.text('Gallery $i').hitTestable(), findsOneWidget);
    }
    expect(find.byType(GalleryItemFlowLarge), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });
}
