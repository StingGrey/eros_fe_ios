import 'dart:async';
import 'dart:io';

import 'package:eros_fe/common/service/upscale_service.dart';
import 'package:eros_fe/models/download_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiver/core.dart';

Future<void> until(bool Function() condition) async {
  final timeout = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(timeout))
      fail('Timed out waiting for the worker');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('eros_fe/upscale-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('eros-upscale-test-');
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('thresholds, physical display ratio, animation and always policy', () {
    const options = UpscaleOptions();
    String? reason(int height, {double display = 2400, int frames = 1}) =>
        options.skipReason(
          width: 1200,
          height: height,
          physicalHeight: display,
          frames: frames,
        );
    expect(reason(1200), isNull);
    expect(reason(2000), 'height');
    expect(reason(2500), 'height');
    expect(reason(1990), 'ratio');
    expect(reason(1000, display: 1300), 'ratio');
    expect(reason(1200, frames: 2), 'animated');
    const always = UpscaleOptions(always: true);
    for (final height in [1200, 1990, 2500]) {
      expect(
        always.skipReason(width: 1200, height: height, physicalHeight: 2400),
        isNull,
      );
    }
    expect(
      always.skipReason(
        width: 1200,
        height: 2500,
        physicalHeight: 2400,
        frames: 2,
      ),
      'animated',
    );
    expect(
      always.skipReason(width: 200, height: 200, physicalHeight: 2400),
      'thumbnail',
    );
  });

  test('new reading preferences survive JSON and preserve older profiles', () {
    final old = DownloadConfig.fromJson({'preloadImage': 2});
    expect(old.upscaleEnabled, isNull);
    final edited = old.copyWith(
      upscaleEnabled: Optional.of(false),
      upscaleAlways: Optional.of(true),
      upscaleNeedScale: Optional.of(1.5),
      upscaleCacheGB: Optional.of(8),
      upscaleDenoise: Optional.of(1),
    );
    expect(DownloadConfig.fromJson(edited.toJson()), edited);
    expect(edited.clone(), edited);
    expect(edited.preloadImage, 2);
  });

  test(
    'content cache survives URL/path changes and LRU persists across instances',
    () async {
      final first = await File('${root.path}/one')
          .writeAsBytes(List.filled(70000, 7));
      final second = await first.copy('${root.path}/rotated-token');
      final cache = UpscaleCache(Directory('${root.path}/cache'));
      await cache.initialize();
      final digest = await cache.fingerprint(first);
      expect(await cache.fingerprint(second), digest);
      await second.writeAsBytes([7], mode: FileMode.append);
      expect(await cache.fingerprint(second), isNot(digest));
      const options = UpscaleOptions();
      final hit = await cache
          .file(digest, options)
          .writeAsBytes(List.filled(30, 1));
      final stale = await File('${cache.directory.path}/old.jpg')
          .writeAsBytes(List.filled(30, 2));
      await stale.setLastModified(DateTime(2020));
      expect((await cache.lookup(first, options))?.path, hit.path);
      final reopened = UpscaleCache(cache.directory);
      await reopened.trim(30);
      expect(await stale.exists(), isFalse);
      expect(await hit.exists(), isTrue);
      expect(
        await cache.lookup(first, const UpscaleOptions(denoise: 1)),
        isNull,
      );
    },
  );

  test(
    'two workers, jump cancellation, stale results discarded and cache reused',
    () async {
      final source = await File('${root.path}/source').writeAsBytes([1, 2, 3]);
      final calls = <Map<dynamic, dynamic>>[];
      final pending = <String, Completer<String>>{};
      final cancelled = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'probe')
          return {'width': 700, 'height': 1000, 'frames': 1};
        if (call.method == 'cancel') {
          cancelled.add(args['taskId'] as String);
          return null;
        }
        calls.add(args);
        final id = args['taskId'] as String;
        pending[id] = Completer<String>();
        return pending[id]!.future;
      });
      final service = UpscaleService(
        directory: Directory('${root.path}/cache'),
        options: () => const UpscaleOptions(),
        supported: true,
        channel: channel,
      );
      final changes = <String>[];
      final subscription = service.changes.listen(changes.add);
      service.enqueueWindow({'page1', 'page2', 'page3'});
      for (final id in ['page1', 'page2', 'page3']) {
        await service.cachedOrSchedule(id, source, 2400);
      }
      await until(() => calls.length == 2);
      expect(calls, hasLength(2));
      service.enqueueWindow({'page20'});
      await until(() => cancelled.length == 2);
      await service.cachedOrSchedule('page20', source, 2400);
      for (final args in calls.toList()) {
        await File(args['output'] as String).writeAsBytes([4, 5, 6]);
        pending[args['taskId']]!.complete(args['output'] as String);
      }
      await until(() => calls.length == 3);
      final finalCall = calls.last;
      await File(finalCall['output'] as String).writeAsBytes([9, 9, 9]);
      pending[finalCall['taskId']]!.complete(finalCall['output'] as String);
      await until(() => changes.contains('page20'));
      expect(changes, ['page20']);
      final cached = await service.cachedOrSchedule('page20', source, 2400);
      expect(await cached!.readAsBytes(), [9, 9, 9]);
      expect(calls, hasLength(3));
      await until(
        () => !service.cache.directory.listSync().any(
          (f) => f.path.endsWith('.partial'),
        ),
      );
      service.onClose();
      await subscription.cancel();
    },
  );

  test(
    'cold model failure preserves original and does not retry every rebuild',
    () async {
      final source = await File('${root.path}/source').writeAsBytes([1]);
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'probe')
          return {'width': 700, 'height': 1000, 'frames': 1};
        if (call.method == 'upscale') {
          calls++;
          throw PlatformException(code: 'missing-model');
        }
        return null;
      });
      final service = UpscaleService(
        directory: Directory('${root.path}/cache'),
        options: () => const UpscaleOptions(),
        supported: true,
        channel: channel,
      );
      service.enqueueWindow({'page'});
      expect(await service.cachedOrSchedule('page', source, 2400), isNull);
      await until(() => service.lastError.value.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await service.cachedOrSchedule('page', source, 2400), isNull);
      expect(calls, 1);
      service.onClose();
    },
  );
  test(
    'quality rejection persists and is not inferred again after reopening',
    () async {
      final source = await File('${root.path}/source').writeAsBytes([1, 2, 3]);
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'probe')
          return {'width': 700, 'height': 1000, 'frames': 1};
        if (call.method == 'upscale') {
          calls++;
          throw PlatformException(code: 'quality');
        }
        return null;
      });
      final directory = Directory('${root.path}/cache');
      final service = UpscaleService(
        directory: directory,
        options: () => const UpscaleOptions(),
        supported: true,
        channel: channel,
      );
      service.enqueueWindow({'page'});
      await service.cachedOrSchedule('page', source, 2400);
      await until(
        () =>
            directory.existsSync() &&
            directory.listSync().any((file) => file.path.endsWith('.rejected')),
      );
      service.onClose();
      final reopened = UpscaleService(
        directory: directory,
        options: () => const UpscaleOptions(),
        supported: true,
        channel: channel,
      );
      reopened.enqueueWindow({'page'});
      expect(await reopened.cachedOrSchedule('page', source, 2400), isNull);
      expect(calls, 1);
      reopened.onClose();
    },
  );
}
