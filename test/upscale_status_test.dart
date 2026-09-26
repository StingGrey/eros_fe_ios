import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:eros_fe/common/service/upscale_service.dart';
import 'package:eros_fe/pages/image_view/view/upscale_status_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'page status explains skips and only reports decoded enhancement',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('eros-status-');
      const channel = MethodChannel('eros_fe/status-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var options = const UpscaleOptions();
      final service = UpscaleService(
        directory: Directory('${root.path}/cache'),
        options: () => options,
        supported: true,
        channel: channel,
      );
      addTearDown(() {
        service.onClose();
        messenger.setMockMethodCallHandler(channel, null);
        root.deleteSync(recursive: true);
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'capabilities')
          return {'models': UpscaleModel.all.map((m) => m.id).toList()};
        if (call.method == 'probe')
          return {'width': 1600, 'height': 2400, 'frames': 1};
        throw StateError('This page should be skipped or already cached');
      });
      service.enqueueWindow({'page1'});
      final source = File('${root.path}/source')..writeAsBytesSync([1, 2, 3]);
      await tester.runAsync(
        () => service.cachedOrSchedule('page1', source, 2400),
      );
      expect(service.statusFor('page1').reason, 'height');

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 160,
              height: 40,
              child: UpscaleStatusIndicator(
                service: service,
                ids: const ['page1'],
                firstPage: 1,
                totalPages: 20,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsOneWidget);
      await tester.tap(find.text('1 / 20'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Source: 1600 × 2400 px'), findsOneWidget);
      expect(find.textContaining('2000 px limit'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      options = const UpscaleOptions(always: true);
      service.refreshSettings();
      await tester.runAsync(() async {
        await service.cache.initialize();
        await service.cache
            .file(await service.cache.fingerprint(source), options)
            .writeAsBytes([4]);
        await service.cachedOrSchedule('page1', source, 2400);
      });
      await tester.pumpAndSettle();
      expect(find.text('Enhancement ready'), findsOneWidget);
      expect(find.text('Enhanced 2×'), findsNothing);
      service.reportDisplayed(
        'page1',
        signature: options.signature,
        revision: service.revision('page1'),
        enhanced: true,
        width: 3200,
        height: 4800,
      );
      await tester.pumpAndSettle();
      expect(find.text('Enhanced 2×'), findsOneWidget);
      await tester.tap(find.text('1 / 20'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Displaying: 3200 × 4800 px'), findsOneWidget);

      final oldSignature = options.signature;
      final oldRevision = service.revision('page1');
      options = const UpscaleOptions(enabled: false);
      service.refreshSettings();
      service.reportDisplayed(
        'page1',
        signature: oldSignature,
        revision: oldRevision,
        enhanced: true,
        width: 3200,
        height: 4800,
      );
      await tester.pumpAndSettle();
      expect(service.statusFor('page1').reason, 'disabled');
      expect(
        find.textContaining('Automatic enhancement is off.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
