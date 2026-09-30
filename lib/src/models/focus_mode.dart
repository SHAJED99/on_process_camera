part of './../../on_process_camera.dart';

/// Enum that defines the camera focus mode behavior.
///
/// This enum controls how the camera handles autofocus during capture or
/// streaming.
/// It provides two distinct modes for managing camera focus:
///
/// * [auto] - Enables automatic focus adjustment. The camera continuously
/// adjusts
///   focus to maintain sharpness of detected faces or objects in the frame.
/// * [locked] - Disables automatic focus. The camera maintains a fixed focus
/// point
///   and does not adjust focus based on detected faces or movement.
///
/// **Usage:**
/// ```dart
/// // Enable auto focus
/// cameraController.setFocusMode(FocusMode.auto);
///
/// // Lock focus at current position
/// cameraController.setFocusMode(FocusMode.locked);
/// ```
///
/// **Note:** When using face detection, the focus mode affects how the camera
/// responds to detected face positions. Use [auto] for continuous adjustment or
/// [locked] for fixed focus during specific liveness detection scenarios.
///
/// See also:
/// * [LivelinessModel] - Contains focus point information from detection
/// * [_ScreenController] - Manages camera focus mode initialization
enum FocusPoint {
  auto(FocusMode.auto),
  locked(FocusMode.locked);

  const FocusPoint(this._focusMode);
  final FocusMode _focusMode;
}
