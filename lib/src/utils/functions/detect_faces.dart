part of './../../../on_process_camera.dart';

Future<_Tuple2<LivelinessModel, InputImage>> _detectLiveliness(
  CameraImage image,
  _ScreenController screenController,
) async {
  final OnCameraController input = screenController.input;
  final FaceAnalyserData faceAnalyser = input.faceAnalyser!;
  final LivelinessModel liveliness = LivelinessModel(cameraImage: image);
  final Size previewSize = screenController.previewSize;
  final Size calculatedSize = screenController.calculatedOrientationCameraSize;
  final Rect windowRect = _getWindowRect(previewSize, calculatedSize);
  liveliness._frameRect = windowRect;
  final CameraController cameraController = screenController.cameraController!;
  final CameraDescription description = cameraController.description;
  final NativeDeviceOrientation orientation = screenController._orientation;
  final InputImageRotation inputImageRotation = orientation._inputImageRotation(
    description,
  );
  final InputImage inputImage = image.toInputImage(inputImageRotation);
  final FaceDetector faceDetector = faceAnalyser.faceDetector;
  final List<Face> faces = await faceDetector.processImage(inputImage);
  liveliness._faceCount = faces.length;

  //! -------------------------------- If no face or more than one face detected
  if (faces.length != 1) {
    return _Tuple2<LivelinessModel, InputImage>(liveliness, inputImage);
  }

  final Face face = faces.first;
  final ui.Rect faceRect = face.boundingBox;
  liveliness._boundingBox = faceRect;

  // Preview not laid out yet: no window to compare the face against
  if (windowRect.isEmpty) {
    return _Tuple2<LivelinessModel, InputImage>(liveliness, inputImage);
  }

  // -------------------------------------------------------- _isFaceInsideFrame
  final bool isCenter = _isCenter(faceRect, windowRect);
  liveliness._isFaceInsideFrame = isCenter;

  // --------------------------------------------------------------- isSmallFace
  final bool isSmallFace =
      windowRect.getSizePercentage(faceRect) < faceAnalyser.smallFacePercentage;
  liveliness._isSmallFace = isSmallFace;
  // ----------------------------------------------------------------- isBigFace
  final bool isBigFace =
      windowRect.getSizePercentage(faceRect) > faceAnalyser.bigFacePercentage;
  liveliness._isBigFace = isBigFace;

  // ----------------------------------------------------------------- isSmiling
  final bool isSmiling =
      (face.smilingProbability ?? 0) >= faceAnalyser.smilePercentage;
  liveliness._isSmiling = isSmiling;

  // -------------------------------------------------------------- _isEyeClosed
  final bool isEyeClosed = _isEyeClosed(face, faceAnalyser);
  liveliness._isEyeClosed = isEyeClosed;

  // ---------------------------------------------------------- _headOrientation
  _headOrientation(face, faceAnalyser, liveliness);

  return _Tuple2<LivelinessModel, InputImage>(liveliness, inputImage);
}

ui.Rect _getWindowRect(Size previewSize, Size calculatedSize) {
  if (previewSize.isEmpty || calculatedSize.isEmpty) return Rect.zero;

  //! Measuring window shape
  // previewSize convert to calculatedOrientationCameraSize. The preview is
  // cover-fitted, so the camera image fills the preview's relatively longer
  // axis: compare the two aspect ratios, not the preview's alone.
  double fw = 0, fh = 0;
  if (previewSize.aspectRatio < calculatedSize.aspectRatio) {
    fh = calculatedSize.height;
    fw = previewSize.width / previewSize.height * fh;
  } else {
    fw = calculatedSize.width;
    fh = previewSize.height / previewSize.width * fw;
  }

  Size getMiddleRange(double full, double middle) {
    double s = 0, e = 0, cm = 0, pm = 0;
    if (full % 2 == 0) {
      cm = full / 2;
      pm = middle / 2;
      s = cm - pm + 1;
      e = cm + pm;
    } else {
      cm = (full / 2) + 1;
      pm = middle / 2;
      s = cm - pm + 1;
      e = cm + pm - 1;
    }
    if (s < 0) s = 0;
    if (e < 0) e = 0;
    return Size(s, e);
  }

  //! Measuring the window mask
  // Starting width/height, ending width/height, calculated middle, preview middle
  double sw = 0, sh = 0, ew = 0, eh = 0;
  Size temp = Size.zero;
  temp = getMiddleRange(calculatedSize.width, fw);
  sw = temp.width;
  ew = temp.height;
  temp = getMiddleRange(calculatedSize.height, fh);
  sh = temp.width;
  eh = temp.height;

  return Rect.fromLTRB(sw, sh, ew, eh);
}

bool _isCenter(ui.Rect faceBoundingBox, ui.Rect windowRect) {
  if (faceBoundingBox.left < windowRect.left) return false;
  if (faceBoundingBox.right > windowRect.right) return false;
  if (faceBoundingBox.top < windowRect.top) return false;
  if (faceBoundingBox.bottom > windowRect.bottom) return false;
  return true;
}

bool _isEyeClosed(Face face, FaceAnalyserData faceAnalyser) {
  final double x = faceAnalyser.eyesClosePercentage;

  if ((face.leftEyeOpenProbability ?? 1) < x) return true;
  if ((face.rightEyeOpenProbability ?? 1) < x) return true;
  return false;
}

LivelinessModel _headOrientation(
  Face face,
  FaceAnalyserData faceAnalyser,
  LivelinessModel liveliness,
) {
  final double? headEulerY = face.headEulerAngleY; // Y axis: left/right
  final double? headEulerX = face.headEulerAngleX; // X axis: up/down
  final double? headEulerZ = face.headEulerAngleZ; // Z axis: tilt

  const double leftThreshold = -15.0;
  const double rightThreshold = 15.0;
  const double upThreshold = -10.0;
  const double downThreshold = 10.0;

  bool isLookingLeft = false;
  bool isLookingRight = false;
  bool isLookingUp = false;
  bool isLookingDown = false;

  if (headEulerY != null) {
    if (headEulerY < leftThreshold * faceAnalyser.lookLeftPercentage) {
      isLookingLeft = true;
    } else if (headEulerY > rightThreshold * faceAnalyser.lookRightPercentage) {
      isLookingRight = true;
    }
  }

  if (headEulerX != null) {
    if (headEulerX < upThreshold * faceAnalyser.lookUpPercentage) {
      isLookingUp = true;
    } else if (headEulerX > downThreshold * faceAnalyser.lookDownPercentage) {
      isLookingDown = true;
    }
  }

  liveliness
    .._isLookingLeft = isLookingLeft
    .._isLookingRight = isLookingRight
    .._isLookingUp = isLookingUp
    .._isLookingDown = isLookingDown
    .._headEulerAngleX = headEulerX ?? 0
    .._headEulerAngleY = headEulerY ?? 0
    .._headEulerAngleZ = headEulerZ ?? 0;

  return liveliness;
}
