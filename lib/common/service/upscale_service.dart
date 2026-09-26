import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

class UpscaleOptions {
  const UpscaleOptions({
    this.enabled = true,
    this.always = false,
    this.skipHeight = 2000,
    this.needScale = 1.3,
    this.model = 'real-cugan-v1',
    this.denoise = 0,
    this.cacheGB = 4,
  });
  final bool enabled, always;
  final int skipHeight, denoise, cacheGB;
  final double needScale;
  final String model;
  String get modelKey => '${model}_2x_d$denoise';
  String get signature => '$enabled/$always/$skipHeight/$needScale/$modelKey';

  String? skipReason({
    required int width,
    required int height,
    required double physicalHeight,
    int frames = 1,
    bool thumbnail = false,
  }) {
    if (!enabled) return 'disabled';
    if (frames != 1) return 'animated';
    if (thumbnail || width < 256 || height < 256) return 'thumbnail';
    if (!always && height >= skipHeight) return 'height';
    if (!always &&
        (physicalHeight <= 0 || physicalHeight / height <= needScale))
      return 'ratio';
    return null;
  }
}

/// Disk contents are addressed by image bytes, so rotating URL tokens do not
/// duplicate results. The modification time is the persistent LRU access time.
class UpscaleCache {
  UpscaleCache(this.directory);
  final Directory directory;
  Future<void>? _initialization;
  Future<void> _maintenance = Future.value();

  Future<void> initialize() => _initialization ??= () async {
    await directory.create(recursive: true);
    await for (final entry in directory.list()) {
      if (entry is File && entry.path.endsWith('.partial'))
        await entry.delete();
    }
  }();

  Future<String> fingerprint(File source) async {
    final file = await source.open();
    try {
      final size = await file.length();
      final bytes = await file.read(65536);
      final length = ByteData(8)..setUint64(0, size, Endian.big);
      return sha1.convert([
        ...bytes,
        ...length.buffer.asUint8List(),
      ]).toString();
    } finally {
      await file.close();
    }
  }

  File file(String digest, UpscaleOptions options) =>
      File(p.join(directory.path, '${digest}_${options.modelKey}.jpg'));

  Future<File?> lookup(File source, UpscaleOptions options) async {
    await initialize();
    final result = file(await fingerprint(source), options);
    if (!await result.exists() || await result.length() == 0) return null;
    await result.setLastModified(DateTime.now());
    return result;
  }

  Future<void> trim(int maxBytes, {Set<String> protectedPaths = const {}}) {
    return _maintenance = _maintenance.catchError((Object _) {}).then((
      _,
    ) async {
      await initialize();
      final entries = <(File, FileStat)>[];
      await for (final entry in directory.list()) {
        if (entry is File &&
            (entry.path.endsWith('.jpg') || entry.path.endsWith('.rejected')))
          entries.add((entry, await entry.stat()));
      }
      entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      var total = entries.fold<int>(0, (sum, entry) => sum + entry.$2.size);
      for (final entry in entries) {
        if (total <= maxBytes) break;
        if (protectedPaths.contains(entry.$1.path)) continue;
        if (await entry.$1.exists()) await entry.$1.delete();
        total -= entry.$2.size;
      }
    });
  }
}

class _UpscaleJob {
  _UpscaleJob(
    this.id,
    this.taskId,
    this.source,
    this.options,
    this.physicalHeight,
    this.signature,
  );
  final String id, taskId, signature;
  final File source;
  final UpscaleOptions options;
  final double physicalHeight;
  bool cancelled = false;
  bool running = false;
}

class UpscaleService extends GetxService {
  UpscaleService({
    required Directory directory,
    required this.options,
    MethodChannel? channel,
    bool? supported,
  }) : cache = UpscaleCache(directory),
       channel = channel ?? const MethodChannel('eros_fe/upscale'),
       supported = supported ?? Platform.isIOS;
  final UpscaleCache cache;
  final UpscaleOptions Function() options;
  final MethodChannel channel;
  final bool supported;
  final lastError = ''.obs;
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;
  final Map<String, _UpscaleJob> _jobs = {};
  final Queue<_UpscaleJob> _queue = Queue();
  final Map<String, Set<Object>> _imageKeys = {};
  final Map<String, int> _revisions = {};
  final Map<String, String> _finished = {};
  Set<String> _window = {};
  int _running = 0, _nextTask = 0;
  bool _closed = false;
  int revision(String id) => _revisions[id] ?? 0;

  void trackImageKey(String id, Object key) {
    if (_window.contains(id)) (_imageKeys[id] ??= {}).add(key);
  }

  void enqueueWindow(Set<String> ids) {
    _window = ids;
    for (final job in _jobs.values.toList()) {
      if (!ids.contains(job.id)) _cancel(job);
    }
    _finished.removeWhere((id, _) => !ids.contains(id));
    _revisions.removeWhere((id, _) => !ids.contains(id));
    _imageKeys.removeWhere((id, keys) {
      if (ids.contains(id)) return false;
      for (final key in keys) {
        PaintingBinding.instance.imageCache.evict(key, includeLive: false);
      }
      return true;
    });
  }

  void _cancel(_UpscaleJob job) {
    job.cancelled = true;
    if (job.running) {
      unawaited(
        channel
            .invokeMethod<void>('cancel', {'taskId': job.taskId})
            .catchError((Object _) {}),
      );
    }
    if (identical(_jobs[job.id], job)) _jobs.remove(job.id);
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(
      cache
          .trim(options().cacheGB.clamp(1, 16) * 1024 * 1024 * 1024)
          .catchError((Object error) {
            lastError.value = error is PlatformException
                ? (error.message ?? error.code)
                : error.toString();
          }),
    );
  }

  void refreshSettings() {
    for (final job in _jobs.values.toList()) {
      _cancel(job);
    }
    _finished.clear();
    for (final id in _window) {
      _changed(id);
    }
    unawaited(
      cache
          .trim(options().cacheGB.clamp(1, 16) * 1024 * 1024 * 1024)
          .catchError((Object error) {
            lastError.value = error.toString();
          }),
    );
  }

  void _changed(String id) {
    for (final key in _imageKeys.remove(id) ?? <Object>{}) {
      PaintingBinding.instance.imageCache.evict(key);
    }
    _revisions[id] = revision(id) + 1;
    if (!_closed) _changes.add(id);
  }

  /// Cache lookup never waits for inference: the cold page displays the source.
  Future<File?> cachedOrSchedule(
    String id,
    File source,
    double physicalHeight, {
    int? sourceWidth,
    int? sourceHeight,
  }) async {
    final config = options();
    if (!supported || !config.enabled || _closed) return null;
    if (sourceWidth != null &&
        sourceHeight != null &&
        sourceWidth > 0 &&
        sourceHeight > 0) {
      final reason = config.skipReason(
        width: sourceWidth,
        height: sourceHeight,
        physicalHeight: physicalHeight,
      );
      if (reason != null) {
        debugPrint('upscale[$id]: skip=$reason (metadata)');
        return null;
      }
    }
    try {
      if (!await source.exists()) return null;
      // Probe only metadata; it also detects animated WebP/APNG despite suffixes.
      final info = await channel.invokeMapMethod<String, dynamic>('probe', {
        'path': source.path,
      });
      if (info == null) return null;
      final reason = config.skipReason(
        width: info['width'] as int,
        height: info['height'] as int,
        frames: info['gif'] == true ? 2 : info['frames'] as int? ?? 1,
        physicalHeight: physicalHeight,
      );
      if (reason != null) {
        debugPrint('upscale[$id]: skip=$reason');
        if (_window.contains(id))
          _finished[id] = '${config.signature}/${source.path}';
        return null;
      }
      final digest = await cache.fingerprint(source);
      final rejected = File('${cache.file(digest, config).path}.rejected');
      if (await rejected.exists()) {
        await rejected.setLastModified(DateTime.now());
        return null;
      }
      final cached = await cache.lookup(source, config);
      if (_closed || options().signature != config.signature) return null;
      if (cached != null) {
        debugPrint('upscale[$id]: cache hit');
        return cached;
      }
      if (!_window.contains(id)) return null;
      final signature = '${config.signature}/$digest';
      if (_finished[id] == signature) return null;
      final existing = _jobs[id];
      if (existing != null &&
          existing.source.path == source.path &&
          existing.options.signature == config.signature)
        return null;
      if (existing != null) _cancel(existing);
      final job = _UpscaleJob(
        id,
        'sr-${++_nextTask}',
        source,
        config,
        physicalHeight,
        signature,
      );
      _jobs[id] = job;
      _queue.add(job);
      _pump();
    } catch (error) {
      lastError.value = error is PlatformException
          ? (error.message ?? error.code)
          : error.toString();
    }
    return null;
  }

  void _pump() {
    while (_running < 2 && _queue.isNotEmpty && !_closed) {
      final job = _queue.removeFirst();
      if (job.cancelled || !_window.contains(job.id)) continue;
      _running++;
      job.running = true;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_UpscaleJob job) async {
    File? temporary;
    File? destination;
    try {
      await cache.initialize();
      destination = cache.file(
        await cache.fingerprint(job.source),
        job.options,
      );
      temporary = File('${destination.path}.${job.taskId}.partial');
      if (job.cancelled) return;
      await channel.invokeMethod<String>('upscale', {
        'taskId': job.taskId,
        'path': job.source.path,
        'output': temporary.path,
        'model': job.options.model,
        'scale': 2,
        'denoise': job.options.denoise,
      });
      if (job.cancelled || !_window.contains(job.id)) return;
      if (!await temporary.exists() || await temporary.length() == 0)
        throw StateError('Core ML returned no image');
      await temporary.rename(destination.path);
      await destination.setLastModified(DateTime.now());
      lastError.value = '';
      _changed(job.id);
      await cache.trim(
        job.options.cacheGB.clamp(1, 16) * 1024 * 1024 * 1024,
        protectedPaths: {destination.path},
      );
    } catch (error) {
      if (!job.cancelled) {
        lastError.value = error is PlatformException
            ? (error.message ?? error.code)
            : error.toString();
        if (error is PlatformException &&
            error.code == 'quality' &&
            destination != null) {
          try {
            await File('${destination.path}.rejected')
                .writeAsString('quality-v1');
          } catch (_) {
            /* The original remains available if storage is full. */
          }
        }
        debugPrint('upscale[${job.id}]: failed $error');
      }
    } finally {
      try {
        if (temporary != null && await temporary.exists())
          await temporary.delete();
      } catch (_) {
        /* Startup cleanup removes interrupted partial outputs. */
      }
      if (!job.cancelled) _finished[job.id] = job.signature;
      if (identical(_jobs[job.id], job)) _jobs.remove(job.id);
      _running--;
      _pump();
    }
  }

  @override
  void onClose() {
    _closed = true;
    enqueueWindow({});
    _queue.clear();
    unawaited(_changes.close());
    super.onClose();
  }
}
