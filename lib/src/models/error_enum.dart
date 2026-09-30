part of './../../on_process_camera.dart';

enum ErrorStatus {
  permissionDenied('Permission Denied'),
  noCameraFound('No Camera Found'),
  selectedCameraNotFound('Selected Camera Not Found'),
  cameraCanNotBeInitialized('Camera Can Not Be Initialized'),
  unknown('Unknown Error');

  const ErrorStatus(this.message);
  final String message;
}
