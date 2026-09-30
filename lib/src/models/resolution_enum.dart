part of './../../on_process_camera.dart';

/// Affect the quality of video recording and image capture:
///
/// A preset is treated as a target resolution, and exact values are not
/// guaranteed. Platform implementations may fall back to a higher or lower
/// resolution if a specific preset is not available.
enum Resolution {
  /// 352x288 on iOS, ~240p on Android and Web
  low(ResolutionPreset.low),

  /// ~480p
  medium(ResolutionPreset.medium),

  /// ~720p
  high(ResolutionPreset.high),

  /// ~1080p
  veryHigh(ResolutionPreset.veryHigh),

  /// ~2160p
  ultraHigh(ResolutionPreset.ultraHigh),

  /// The highest resolution available.
  max(ResolutionPreset.max);

  const Resolution(this._resolution);
  final ResolutionPreset _resolution;
}
