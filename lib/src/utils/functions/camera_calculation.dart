part of './../../../on_process_camera.dart';

Size _getCameraShowingSize({
  required Size previewSize,
  required Size cameraSize,
  required DeviceOrientation orientation,
  required Function(Size size) onCalculatedOrientationCameraSize,
}) {
  //! Preview Information
  double pW = previewSize.width;
  double pH = previewSize.height;
  // final double pR = pW / pH; // Ratio

  //! Camera Information
  final Size cSize = cameraSize._sizeAccordingOrientation(
    // orientation: orientation,
    deviceOrientation: orientation,
  );
  onCalculatedOrientationCameraSize(cSize);
  final double cW = cSize.width;
  final double cH = cSize.height;

  final double cR = cW / cH; // Ratio

  final double smallestPreviewSize = min(pW, pH);
  final double smallestCameraSize = min(cW, cH);

  double w = 0, h = 0;

  void calculateSize() {
    // Smallest: pW, cW
    if (pW == smallestPreviewSize && cW == smallestCameraSize) {
      w = pW;
      h = w / cR;
    }
    // Smallest: pW, cH
    else if (pW == smallestPreviewSize && cH == smallestCameraSize) {
      h = pH;
      w = h * cR;
    }
    // Smallest: pH, cH
    else if (pH == smallestPreviewSize && cH == smallestCameraSize) {
      h = pH;
      w = h * cR;
    }
    // Smallest: pH, cW
    else if (pH == smallestPreviewSize && cW == smallestCameraSize) {
      w = pW;
      h = w / cR;
    }
  }

  calculateSize(); //! Finding width, height;

  //   devPrint("""-------------------------------------------------------------
  // [Log] - pR = $pR      cR = $cR
  // [Log] - pW = $pW      cW = $cW
  // [Log] - pH = $pH      cH = $cH
  // [Log] - w = $w
  // [Log] - h = $h

  // [Log] - --------------------------------------------------------------""");

  if (pW == w && pH > h) {
    h = pH;
    w = h * cR;
  } else if (pH == h && pW > w) {
    w = pW;
    h = w / cR;
  }

  return Size(w, h);
}
