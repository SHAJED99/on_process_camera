part of './../../on_process_camera.dart';

class _CropImageParametersModel {
  const _CropImageParametersModel({
    required this.file,
    required this.cameraSize,
    required this.previewSize,
    required this.orientation,
    required this.doFlip,
    required this.doCrop,
  });

  final XFile file;
  final Size cameraSize;
  final Size previewSize;
  final DeviceOrientation orientation;
  final bool doFlip;
  final bool doCrop;
}
