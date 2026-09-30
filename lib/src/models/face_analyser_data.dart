part of './../../on_process_camera.dart';

class FaceAnalyserData {
  FaceAnalyserData({
    this.bigFacePercentage = 0.6,
    this.smallFacePercentage = 0.3,
    this.eyesClosePercentage = 0.8,
    this.lookUpPercentage = 0.8,
    this.lookDownPercentage = 0.8,
    this.lookLeftPercentage = 0.8,
    this.lookRightPercentage = 0.8,
    this.smilePercentage = 0.6,
    this.statusCheckDelay = const Duration(milliseconds: 500),
    this.autoFocusOnFace = true,
    this.autoExposureOnFace = true,
    this.onLiveliness,

    FaceDetectorOptions? faceDetectorOptions,
  }) : faceDetector = FaceDetector(
         options:
             faceDetectorOptions ??
             FaceDetectorOptions(
               performanceMode: FaceDetectorMode.accurate,
               enableLandmarks: true,
               enableContours: true,
               enableTracking: true,
               enableClassification: true,
               minFaceSize: 0.1,
             ),
       );

  final double bigFacePercentage;
  final double smallFacePercentage;
  final double eyesClosePercentage;
  final double lookUpPercentage;
  final double lookDownPercentage;
  final double lookLeftPercentage;
  final double lookRightPercentage;
  final double smilePercentage;

  /// Frames are delivered when the face status changes, or at least this
  /// often while it stays the same. Use [Duration.zero] for every frame.
  final Duration statusCheckDelay;
  final bool autoFocusOnFace;
  final bool autoExposureOnFace;

  final Future<void> Function(LivelinessModel value, InputImageModel image)?
  onLiveliness;

  final FaceDetector faceDetector;
}
