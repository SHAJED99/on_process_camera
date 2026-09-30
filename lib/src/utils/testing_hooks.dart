part of './../../on_process_camera.dart';

// Thin public wrappers so unit tests can reach the library-private geometry.
// Not part of the package API.

/// The visible "window" of the camera image, in camera-image coordinates, for
/// a preview of [previewSize] showing a camera image of [cameraSize] (already
/// oriented, i.e. portrait for a portrait device).
@visibleForTesting
Rect debugWindowRect(Size previewSize, Size cameraSize) =>
    _getWindowRect(previewSize, cameraSize);

/// ML Kit rotation for a frame from [camera] with the device in
/// [orientation]. Uses the Android formula on non-iOS hosts.
@visibleForTesting
InputImageRotation debugInputImageRotation(
  NativeDeviceOrientation orientation,
  CameraDescription camera,
) => orientation._inputImageRotation(camera);

/// Size the camera preview is drawn at to cover [previewSize], for a camera
/// preview of [cameraSize] (as reported by the plugin, landscape).
@visibleForTesting
Size debugCameraShowingSize(
  Size previewSize,
  Size cameraSize,
  DeviceOrientation orientation,
) => _getCameraShowingSize(
  previewSize: previewSize,
  cameraSize: cameraSize,
  orientation: orientation,
  onCalculatedOrientationCameraSize: (_) {},
);
