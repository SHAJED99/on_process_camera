part of './../../../on_process_camera.dart';

extension NativeDeviceOrientationExtension on NativeDeviceOrientation {
  DeviceOrientation get _deviceOrientation {
    Map<NativeDeviceOrientation, DeviceOrientation>
    map = <NativeDeviceOrientation, DeviceOrientation>{
      NativeDeviceOrientation.portraitUp: DeviceOrientation.portraitUp,
      NativeDeviceOrientation.portraitDown: DeviceOrientation.portraitDown,
      NativeDeviceOrientation.landscapeLeft: DeviceOrientation.landscapeLeft,
      NativeDeviceOrientation.landscapeRight: DeviceOrientation.landscapeRight,
    };
    return map[this] ?? DeviceOrientation.portraitUp;
  }

  // int get _sensorOrientation {
  //   Map<NativeDeviceOrientation, int> map = <NativeDeviceOrientation, int>{
  //     NativeDeviceOrientation.portraitUp: 270,
  //     NativeDeviceOrientation.portraitDown: 180,
  //     NativeDeviceOrientation.landscapeLeft: 90,
  //     NativeDeviceOrientation.landscapeRight: 270,
  //   };
  //   return map[this] ?? 0;
  // }

  /// Frame rotation for ML Kit, derived from the camera's sensor orientation
  /// (as in the google_mlkit examples) rather than assuming 270° front / 90°
  /// back, which is wrong on devices with unusually mounted sensors.
  InputImageRotation _inputImageRotation(CameraDescription camera) {
    final int sensor = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensor) ??
          InputImageRotation.rotation0deg;
    }

    final Map<NativeDeviceOrientation, int> deviceRotation =
        <NativeDeviceOrientation, int>{
          NativeDeviceOrientation.portraitUp: 0,
          NativeDeviceOrientation.landscapeLeft: 90,
          NativeDeviceOrientation.portraitDown: 180,
          NativeDeviceOrientation.landscapeRight: 270,
        };
    final int device = deviceRotation[this] ?? 0;
    final bool isFront = camera.lensDirection == CameraLensDirection.front;
    final int degrees = isFront
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees) ??
        InputImageRotation.rotation0deg;
  }
}
