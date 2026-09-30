part of './../../../on_process_camera.dart';

extension SizeExtension on Size {
  Size _sizeAccordingOrientation({
    Orientation? orientation,
    DeviceOrientation? deviceOrientation,
  }) {
    if (orientation == Orientation.portrait) {
      return this;
    }
    if (deviceOrientation == DeviceOrientation.landscapeLeft ||
        deviceOrientation == DeviceOrientation.landscapeRight) {
      return this;
    }

    return Size(height, width);
  }
}
