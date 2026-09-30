part of './../../on_process_camera.dart';

/// The direction the camera is facing.
enum CameraLense {
  /// Front facing camera (a user looking at the screen is seen by the camera).
  front(CameraLensDirection.front),

  /// Back facing camera (a user looking at the screen is not seen by the
  /// camera).
  back(CameraLensDirection.back),

  /// External camera which may not be mounted to the device.
  external(CameraLensDirection.external);

  const CameraLense(this._lense);
  final CameraLensDirection _lense;
}
