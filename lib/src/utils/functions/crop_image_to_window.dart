part of './../../../on_process_camera.dart';

Future<Uint8List> _cropImageToWindow(_CropImageParametersModel data) async {
  // DateTime now = DateTime.now();
  // ignore: no_leading_underscores_for_local_identifiers
  void ____printStamp(String stamp) {
    // _devPrint('$stamp: ${DateTime.now().difference(now).inMilliseconds}');
    // now = DateTime.now();
  }

  ____printStamp('Starting...');
  XFile originalFile = data.file;
  final Size previewSize = data.previewSize;

  //! ---------------------------------------------------- Getting original data
  Uint8List originalBytes;
  try {
    originalBytes = await originalFile.readAsBytes();
  } finally {
    // Only the bytes are returned; don't leave the capture (PII) in the
    // cache, even when reading it failed
    try {
      await File(originalFile.path).delete();
    } catch (e) {
      _devPrint('Delete captured file - $e', color: _DevPrintColorEnum.red);
    }
  }
  ____printStamp('readAsBytes');

  //! ----------------------------------------------------------------- Flipping
  final bool isFront = data.doFlip;
  if (isFront) {
    final Uint8List? result = await ImageEditor.editImage(
      image: originalBytes,
      imageEditorOption: ImageEditorOption()
        ..addOption(const FlipOption(horizontal: true)),
    );
    if (result != null) originalBytes = result;
    ____printStamp('flipping');
  }

  if (!data.doCrop) return originalBytes;

  //! ----------------------------------------------------------------- Rotating
  int rotationAngle = 0;
  // final DeviceOrientation orientation = data.orientation;
  // if (orientation == DeviceOrientation.landscapeLeft) {
  //   rotationAngle = -90;
  // } else if (orientation == DeviceOrientation.landscapeRight) {
  //   rotationAngle = 90;
  // }
  final Uint8List rotatedBytes = await FlutterImageCompress.compressWithList(
    originalBytes,
    rotate: rotationAngle,
    quality: 100,
  );
  ____printStamp('rotating');

  //! -------------------------------------------------------- Decode dimensions
  final ui.Image decodedImage = await decodeImageFromList(rotatedBytes);
  final double cW = decodedImage.width.toDouble();
  final double cH = decodedImage.height.toDouble();
  final double cR = cW / cH; // Ratio

  ____printStamp('decode dimensions');

  //! ----------------------------------------------------------- Calculate crop
  // preview width, height
  final double pW = previewSize.width;
  final double pH = previewSize.height;
  final double pR = pW / pH; // Ratio

  // width, height
  double w = 0, h = 0, cropX = 0, cropY = 0;

  if (cR < pR) {
    w = cW;
    h = w / pR;
  } else {
    h = cH;
    w = h * pR;
  }

  cropX = (cW / 2) - (w / 2);
  cropY = (cH / 2) - (h / 2);

  //! ----------------------------------------------------------------- Cropping
  final Uint8List croppedBytes = await NativeImageCropper.cropRect(
    bytes: rotatedBytes,
    x: cropX.round(),
    y: cropY.round(),
    width: w.round(),
    height: h.round(),
  );
  ____printStamp('cropRect');

  // _devPrint(
  //   '''${originalBytes.lengthInBytes / 1024} -> ${croppedBytes.lengthInBytes / 1024} KB''',
  // );

  return croppedBytes;
}
