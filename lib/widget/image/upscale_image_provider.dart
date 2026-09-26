import 'dart:io';

import 'package:eros_fe/common/service/upscale_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

/// A single decorator for downloaded files and network disk-cache files.
/// The original provider retains its network retries, progress and animation.
@immutable
class UpscaleImageProvider extends ImageProvider<UpscaleImageKey> {
  UpscaleImageProvider({
    required this.original,
    required this.source,
    required this.id,
    required this.service,
    required this.physicalHeight,
  }) : revision = service.revision(id),
       signature = service.options().signature;
  final ImageProvider original;
  final Future<File?> Function() source;
  final String id, signature;
  final UpscaleService service;
  final int revision;
  final double physicalHeight;

  @override
  Future<UpscaleImageKey> obtainKey(ImageConfiguration configuration) async {
    File? enhanced;
    try {
      final file = await source();
      if (file != null)
        enhanced = await service.cachedOrSchedule(id, file, physicalHeight);
    } catch (_) {
      /* Missing source/cache always falls back to the original. */
    }
    if (signature != service.options().signature || revision != service.revision(id)) {
      enhanced = null;
    }
    final ImageProvider provider = enhanced == null
        ? original
        : FileImage(enhanced);
    final key = UpscaleImageKey(
      provider,
      await provider.obtainKey(configuration),
      enhanced: enhanced != null,
    );
    service.trackImageKey(id, key);
    return key;
  }

  @override
  ImageStreamCompleter loadImage(
    UpscaleImageKey key,
    ImageDecoderCallback decode,
  ) => key.provider.loadImage(key.key, decode);

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    UpscaleImageKey key,
    ImageErrorListener handleError,
  ) {
    super.resolveStreamForKey(configuration, stream, key, handleError);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) {
        service.reportDisplayed(
          id,
          signature: signature,
          revision: revision,
          enhanced: key.enhanced,
          width: info.image.width,
          height: info.image.height,
        );
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  @override
  bool operator ==(Object other) =>
      other is UpscaleImageProvider &&
      original == other.original &&
      id == other.id &&
      revision == other.revision &&
      signature == other.signature &&
      physicalHeight == other.physicalHeight;
  @override
  int get hashCode =>
      Object.hash(original, id, revision, signature, physicalHeight);
}

@immutable
class UpscaleImageKey {
  const UpscaleImageKey(this.provider, this.key, {this.enhanced = false});
  final ImageProvider provider;
  final dynamic key;
  final bool enhanced;
  @override
  bool operator ==(Object other) =>
      other is UpscaleImageKey && key == other.key;
  @override
  int get hashCode => key.hashCode;
}
