part of '../../on_process_camera.dart';

// Internal Function: When the function is called outer from the SDK and define
// in the SDK, then it will be assigned with get function and a private
// variable.
//
// External Function: When the function is called inner from the SDK and define
// outer of the SDK, then it will be assigned with a final variable.

class OnCameraController {
  OnCameraController({
    this.cameraLense = CameraLense.front,
    this.resolution = Resolution.max,
    this.focusMode = FocusPoint.auto,
    this.frontFlip = true,
    this.enableAudio = true,
    this.fps,
    this.onPermission,
    this.faceAnalyser,
    this.onStatusChanged,
  });

  // The OnCamera state these functions are bound to
  Object? _owner;

  /// Returns null when the camera isn't ready, a capture is already in
  /// progress, or capturing fails.
  late Future<Uint8List?> Function(bool doCropped) _takePhoto;
  Future<Uint8List?> Function({bool doCropped}) get takePhoto =>
      ({bool doCropped = true}) => _takePhoto(doCropped); // Internal Function
  /// Throws if the camera isn't ready or recording can't start.
  late Future<void> Function() _startVideo;
  Future<void> Function() get startVideo => _startVideo; // Internal Function

  late Future<XFile?> Function() _stopVideo;
  Future<XFile?> Function() get stopVideo => _stopVideo; // Internal Function

  late Future<void> Function(CameraLense cameraLense) _switchCameraLense;
  Future<void> Function(CameraLense cameraLense) get switchCameraLense =>
      _switchCameraLense;

  late Future<void> Function() _pauseCameraView;
  Future<void> Function() get pauseCameraView => _pauseCameraView;
  late Future<void> Function() _resumeCameraView;
  Future<void> Function() get resumeCameraView => _resumeCameraView;

  // void Function() _switchCameraSensor = () {};
  // void Function() get switchCameraSensor => _switchCameraSensor;

  final CameraLense cameraLense;
  final Resolution resolution;
  final FocusPoint focusMode;
  final bool frontFlip;

  /// Record audio with video. When true the microphone permission is
  /// requested; if it is denied, video is recorded without audio. Set to false
  /// for photo-only use so the microphone is never requested.
  final bool enableAudio;

  /// Fixed camera frame rate, e.g. 30. Recording always runs at a fixed rate,
  /// so fixing it from the start stops brightness jumping when video starts.
  /// Null = camera default (a variable range, e.g. 15–30 fps).
  final int? fps;

  final Future<bool> Function(
    BuildContext context,
    PermissionStatus? permissionStatus,
  )?
  onPermission; // External Function

  final FaceAnalyserData? faceAnalyser;

  final ValueNotifier<Uint8List?> inputImageNotifier =
      ValueNotifier<Uint8List?>(null);

  late void Function(
    Future<void> Function(LivelinessModel data, InputImageModel image),
  )
  _startAnalyser; // Internal Function
  void Function(
    Future<void> Function(LivelinessModel data, InputImageModel image),
  )
  get startAnalyser => _startAnalyser;

  late Future<void> Function() _stopAnalyser; // Internal Function
  Future<void> Function() get stopAnalyser => _stopAnalyser;

  final Function(CameraStatus cameraStatus)? onStatusChanged;

  late Future<void> Function(double zoomFactor) _zoomLocation;
  Future<void> Function(double zoomFactor) get zoomLocation => _zoomLocation;

  late Future<void> Function(FocusPoint mode) _setFocusMode;
  Future<void> Function(FocusPoint mode) get setFocusMode => _setFocusMode;
}
