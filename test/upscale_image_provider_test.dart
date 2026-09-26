import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eros_fe/common/service/upscale_service.dart';
import 'package:eros_fe/widget/image/upscale_image_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Size> decodeSize(ImageProvider provider) async {
  final done = Completer<Size>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, sync) {
      done.complete(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stack) =>
        done.completeError(error, stack),
  );
  stream.addListener(listener);
  return done.future;
}

Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(const Color(0xFF123456), BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('decorator decodes original, then content cache, for both provider branches', () async {
    final root = await Directory.systemTemp.createTemp('eros-provider-');
    const channel = MethodChannel('eros_fe/upscale-provider-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var options = const UpscaleOptions();
    final service = UpscaleService(
      directory: Directory('${root.path}/cache'),
      options: () => options,
      channel: channel,
      supported: true,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'capabilities')
        return {'models': UpscaleModel.all.map((m) => m.id).toList()};
      if (call.method == 'probe')
        return {'width': 700, 'height': 1000, 'frames': 1};
      throw StateError('No inference should run outside the active window');
    });
    try {
      final originalBytes = await png(7, 10);
      final file = await File('${root.path}/source')
          .writeAsBytes(originalBytes);
      final originals = <ImageProvider>[
        FileImage(file),
        MemoryImage(originalBytes),
      ];
      for (final original in originals) {
        final provider = UpscaleImageProvider(
          original: original,
          source: () async => file,
          id: 'page',
          service: service,
          physicalHeight: 2400,
        );
        expect(await decodeSize(provider), const Size(7, 10));
      }
      await service.cache.initialize();
      await service.cache
          .file(await service.cache.fingerprint(file), options)
          .writeAsBytes(await png(14, 20));
      service.enqueueWindow({'page'});
      for (final original in originals) {
        final provider = UpscaleImageProvider(
          original: original,
          source: () async => file,
          id: 'page',
          service: service,
          physicalHeight: 2400,
        );
        expect(await decodeSize(provider), const Size(14, 20));
        expect(service.statusFor('page').phase, UpscalePhase.enhanced);
        expect(service.statusFor('page').sourceHeight, 1000);
        expect(service.statusFor('page').outputWidth, 14);
        expect(service.statusFor('page').outputHeight, 20);
      }
      options = const UpscaleOptions(enabled: false);
      service.refreshSettings();
      expect(service.statusFor('page').reason, 'disabled');
      expect(
        await decodeSize(
          UpscaleImageProvider(
            original: FileImage(file),
            source: () async => file,
            id: 'page',
            service: service,
            physicalHeight: 2400,
          ),
        ),
        const Size(7, 10),
      );
    } finally {
      service.onClose();
      PaintingBinding.instance.imageCache.clear();
      messenger.setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    }
  });
}
