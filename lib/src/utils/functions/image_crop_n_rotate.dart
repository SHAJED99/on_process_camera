part of './../../../on_process_camera.dart';

Future<File?> _imageCropNRotate(
  String path, {
  required String toolbarTitle,
  required Color toolbarColor,
  required Color toolbarWidgetColor,
  double? aspectRatio,
}) async {
  final CropAspectRatioPresetData ratio = _computeAspectRatio(aspectRatio);
  CroppedFile? croppedFile = await ImageCropper().cropImage(
    sourcePath: path,
    uiSettings: <PlatformUiSettings>[
      AndroidUiSettings(
        toolbarTitle: toolbarTitle,
        toolbarColor: toolbarColor,
        toolbarWidgetColor: toolbarWidgetColor,
        lockAspectRatio: true,
        initAspectRatio: ratio,
        aspectRatioPresets: <CropAspectRatioPresetData>[ratio],
      ),
      IOSUiSettings(
        title: toolbarTitle,
        aspectRatioLockEnabled: true,
        aspectRatioPresets: <CropAspectRatioPresetData>[ratio],
      ),
    ],
  );

  if (croppedFile == null) return null;

  return File(croppedFile.path);
}

CropAspectRatioPresetData _computeAspectRatio(double? aspectRatio) {
  if (aspectRatio == null) return CropAspectRatioPreset.original;

  __Fraction aspectRatioFraction = aspectRatio._aspectRatioToFraction();
  return _CropAspectRatioPresetCustom(
    aspectRatioFraction.numerator,
    aspectRatioFraction.denominator,
  );
}

class _CropAspectRatioPresetCustom implements CropAspectRatioPresetData {
  const _CropAspectRatioPresetCustom(this.x, this.y);
  final int x;
  final int y;

  @override
  (int, int)? get data => (x, y);

  @override
  // Friendly label instead of the numeric ratio
  String get name => 'Rotate Frame';
}
