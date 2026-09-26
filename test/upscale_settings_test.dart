import 'dart:io';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/upscale_service.dart';
import 'package:eros_fe/pages/setting/setting_items/upscale_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override final upscaleEnabled = true.obs;
  @override final upscaleAlways = false.obs;
  @override final upscaleSkipHeight = 2000.obs;
  @override final upscaleNeedScale = 1.3.obs;
  @override final upscaleModel = 'real-cugan-v1'.obs;
  @override final upscaleDenoise = 0.obs;
  @override final upscaleStrength = 100.obs;
  @override final upscaleCacheGB = 4.obs;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('model explanations, MetalFX selection and strength work in a narrow pane', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final root = Directory.systemTemp.createTempSync('upscale-settings-');
    const channel = MethodChannel('upscale-settings-test');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => {'models': UpscaleModel.all.map((m) => m.id).toList()});
    Get.testMode = true;
    final settings = Get.put<EhSettingService>(_Settings());
    final service = Get.put(UpscaleService(directory: root,
      options: () => const UpscaleOptions(), supported: true, channel: channel));
    addTearDown(() async {
      Get.reset();
      messenger.setMockMethodCallHandler(channel, null);
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    await tester.runAsync(service.ensureCapabilities);
    await tester.pumpWidget(const CupertinoApp(home: CupertinoPageScaffold(
      child: CustomScrollView(slivers: [UpscaleSettings()]),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Model / algorithm'));
    await tester.pumpAndSettle();
    for (final model in UpscaleModel.all) {
      expect(find.text(model.descriptionEn), findsWidgets);
    }
    await tester.tap(find.text('MetalFX 2×'));
    await tester.pumpAndSettle();
    expect(settings.upscaleModel.value, 'metalfx-spatial-v1');
    expect(find.text('Denoising'), findsNothing);
    expect(find.textContaining('Apple GPU spatial scaling'), findsOneWidget);
    final slider = find.byType(CupertinoSlider);
    await tester.ensureVisible(slider);
    await tester.dragFrom(tester.getTopRight(slider) + const Offset(-20, 20), const Offset(-145, 0));
    await tester.pumpAndSettle();
    expect(settings.upscaleStrength.value, inInclusiveRange(40, 65));
    expect(find.text('${settings.upscaleStrength.value}%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
