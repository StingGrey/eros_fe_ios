import 'package:flutter/foundation.dart';
import 'package:quiver/core.dart';

import 'index.dart';

@immutable
class DownloadConfig {

  const DownloadConfig({
    this.upscaleEnabled,
    this.upscaleAlways,
    this.upscaleSkipHeight,
    this.upscaleNeedScale,
    this.upscaleModel,
    this.upscaleDenoise,
    this.upscaleStrength,
    this.upscaleCacheGB,
    this.preloadImage,
    this.multiDownload,
    this.downloadLocation,
    this.downloadOrigImage,
    this.downloadOrigImageType,
    this.allowMediaScan,
    this.concurrentGalleries,
  });

  final bool? upscaleEnabled;
  final bool? upscaleAlways;
  final int? upscaleSkipHeight;
  final double? upscaleNeedScale;
  final String? upscaleModel;
  final int? upscaleDenoise;
  final int? upscaleStrength;
  final int? upscaleCacheGB;
  final int? preloadImage;
  final int? multiDownload;
  final String? downloadLocation;
  final bool? downloadOrigImage;
  final String? downloadOrigImageType;
  final bool? allowMediaScan;
  final int? concurrentGalleries;

  factory DownloadConfig.fromJson(Map<String,dynamic> json) => DownloadConfig(
    upscaleEnabled: json['upscaleEnabled'] == null ? null : bool.tryParse('${json['upscaleEnabled']}'),
    upscaleAlways: json['upscaleAlways'] == null ? null : bool.tryParse('${json['upscaleAlways']}'),
    upscaleSkipHeight: json['upscaleSkipHeight'] == null ? null : int.tryParse('${json['upscaleSkipHeight']}'),
    upscaleNeedScale: json['upscaleNeedScale'] == null ? null : double.tryParse('${json['upscaleNeedScale']}'),
    upscaleModel: json['upscaleModel']?.toString(),
    upscaleDenoise: json['upscaleDenoise'] == null ? null : int.tryParse('${json['upscaleDenoise']}'),
    upscaleStrength: json['upscaleStrength'] == null ? null : int.tryParse('${json['upscaleStrength']}'),
    upscaleCacheGB: json['upscaleCacheGB'] == null ? null : int.tryParse('${json['upscaleCacheGB']}'),
    preloadImage: json['preloadImage'] != null ? int.tryParse('${json['preloadImage']}') ?? 0 : null,
    multiDownload: json['multiDownload'] != null ? int.tryParse('${json['multiDownload']}') ?? 0 : null,
    downloadLocation: json['downloadLocation']?.toString(),
    downloadOrigImage: json['downloadOrigImage'] != null ? bool.tryParse('${json['downloadOrigImage']}', caseSensitive: false) ?? false : null,
    downloadOrigImageType: json['downloadOrigImageType']?.toString(),
    allowMediaScan: json['allowMediaScan'] != null ? bool.tryParse('${json['allowMediaScan']}', caseSensitive: false) ?? false : null,
    concurrentGalleries: json['concurrentGalleries'] != null ? int.tryParse('${json['concurrentGalleries']}') ?? 0 : null
  );
  
  Map<String, dynamic> toJson() => {
    'upscaleEnabled': upscaleEnabled,
    'upscaleAlways': upscaleAlways,
    'upscaleSkipHeight': upscaleSkipHeight,
    'upscaleNeedScale': upscaleNeedScale,
    'upscaleModel': upscaleModel,
    'upscaleDenoise': upscaleDenoise,
    'upscaleStrength': upscaleStrength,
    'upscaleCacheGB': upscaleCacheGB,
    'preloadImage': preloadImage,
    'multiDownload': multiDownload,
    'downloadLocation': downloadLocation,
    'downloadOrigImage': downloadOrigImage,
    'downloadOrigImageType': downloadOrigImageType,
    'allowMediaScan': allowMediaScan,
    'concurrentGalleries': concurrentGalleries
  };

  DownloadConfig clone() => DownloadConfig(
    upscaleEnabled: upscaleEnabled,
    upscaleAlways: upscaleAlways,
    upscaleSkipHeight: upscaleSkipHeight,
    upscaleNeedScale: upscaleNeedScale,
    upscaleModel: upscaleModel,
    upscaleDenoise: upscaleDenoise,
    upscaleStrength: upscaleStrength,
    upscaleCacheGB: upscaleCacheGB,
    preloadImage: preloadImage,
    multiDownload: multiDownload,
    downloadLocation: downloadLocation,
    downloadOrigImage: downloadOrigImage,
    downloadOrigImageType: downloadOrigImageType,
    allowMediaScan: allowMediaScan,
    concurrentGalleries: concurrentGalleries
  );


  DownloadConfig copyWith({
    Optional<bool?>? upscaleEnabled,
    Optional<bool?>? upscaleAlways,
    Optional<int?>? upscaleSkipHeight,
    Optional<double?>? upscaleNeedScale,
    Optional<String?>? upscaleModel,
    Optional<int?>? upscaleDenoise,
    Optional<int?>? upscaleStrength,
    Optional<int?>? upscaleCacheGB,
    Optional<int?>? preloadImage,
    Optional<int?>? multiDownload,
    Optional<String?>? downloadLocation,
    Optional<bool?>? downloadOrigImage,
    Optional<String?>? downloadOrigImageType,
    Optional<bool?>? allowMediaScan,
    Optional<int?>? concurrentGalleries
  }) => DownloadConfig(
    upscaleEnabled: checkOptional(upscaleEnabled, () => this.upscaleEnabled),
    upscaleAlways: checkOptional(upscaleAlways, () => this.upscaleAlways),
    upscaleSkipHeight: checkOptional(upscaleSkipHeight, () => this.upscaleSkipHeight),
    upscaleNeedScale: checkOptional(upscaleNeedScale, () => this.upscaleNeedScale),
    upscaleModel: checkOptional(upscaleModel, () => this.upscaleModel),
    upscaleDenoise: checkOptional(upscaleDenoise, () => this.upscaleDenoise),
    upscaleStrength: checkOptional(upscaleStrength, () => this.upscaleStrength),
    upscaleCacheGB: checkOptional(upscaleCacheGB, () => this.upscaleCacheGB),
    preloadImage: checkOptional(preloadImage, () => this.preloadImage),
    multiDownload: checkOptional(multiDownload, () => this.multiDownload),
    downloadLocation: checkOptional(downloadLocation, () => this.downloadLocation),
    downloadOrigImage: checkOptional(downloadOrigImage, () => this.downloadOrigImage),
    downloadOrigImageType: checkOptional(downloadOrigImageType, () => this.downloadOrigImageType),
    allowMediaScan: checkOptional(allowMediaScan, () => this.allowMediaScan),
    concurrentGalleries: checkOptional(concurrentGalleries, () => this.concurrentGalleries),
  );

  @override
  bool operator ==(Object other) => identical(this, other)
    || other is DownloadConfig && upscaleEnabled == other.upscaleEnabled && upscaleAlways == other.upscaleAlways && upscaleSkipHeight == other.upscaleSkipHeight && upscaleNeedScale == other.upscaleNeedScale && upscaleModel == other.upscaleModel && upscaleDenoise == other.upscaleDenoise && upscaleStrength == other.upscaleStrength && upscaleCacheGB == other.upscaleCacheGB &&  preloadImage == other.preloadImage && multiDownload == other.multiDownload && downloadLocation == other.downloadLocation && downloadOrigImage == other.downloadOrigImage && downloadOrigImageType == other.downloadOrigImageType && allowMediaScan == other.allowMediaScan && concurrentGalleries == other.concurrentGalleries;

  @override
  int get hashCode => upscaleEnabled.hashCode ^ upscaleAlways.hashCode ^ upscaleSkipHeight.hashCode ^ upscaleNeedScale.hashCode ^ upscaleModel.hashCode ^ upscaleDenoise.hashCode ^ upscaleStrength.hashCode ^ upscaleCacheGB.hashCode ^ preloadImage.hashCode ^ multiDownload.hashCode ^ downloadLocation.hashCode ^ downloadOrigImage.hashCode ^ downloadOrigImageType.hashCode ^ allowMediaScan.hashCode ^ concurrentGalleries.hashCode;
}
