// ignore_for_file: prefer_final_fields, public_member_api_docs,
// ignore_for_file: sort_constructors_first

part of './../../on_process_camera.dart';

class LivelinessModel {
  // Face Properties
  bool _isEyeClosed;
  bool _isLookingLeft;
  bool _isLookingRight;
  bool _isLookingUp;
  bool _isLookingDown;
  bool _isSmiling;

  // Face Counters
  bool _isBigFace;
  bool _isSmallFace;
  bool _isFaceInsideFrame;
  Rect? _boundingBox;
  Rect? _frameRect;

  double _headEulerAngleX;
  double _headEulerAngleY;
  double _headEulerAngleZ;

  int _faceCount;

  // get brightness / luminance of the face
  double _brightness;

  // Current focus point
  Offset? _currentFocusPoint;

  final CameraImage _cameraImage;

  image_package.Image? get image => _cameraImage._cameraImageToImage;

  // Constructor
  LivelinessModel({
    bool isEyeClosed = false,
    bool isLookingLeft = false,
    bool isLookingRight = false,
    bool isLookingUp = false,
    bool isLookingDown = false,
    bool isSmiling = false,
    bool isBigFace = false,
    bool isSmallFace = false,
    bool isFaceInsideFrame = false,
    Rect? boundingBox,
    Rect? frameRect,
    double headEulerAngleX = 0,
    double headEulerAngleY = 0,
    double headEulerAngleZ = 0,
    int faceCount = 0,
    double brightness = 0,
    Offset? currentFocusPoint,
    required CameraImage cameraImage,
  }) : _isEyeClosed = isEyeClosed,
       _isLookingLeft = isLookingLeft,
       _isLookingRight = isLookingRight,
       _isLookingUp = isLookingUp,
       _isLookingDown = isLookingDown,
       _isSmiling = isSmiling,
       _isBigFace = isBigFace,
       _isSmallFace = isSmallFace,
       _isFaceInsideFrame = isFaceInsideFrame,
       _boundingBox = boundingBox,
       _frameRect = frameRect,
       _headEulerAngleX = headEulerAngleX,
       _headEulerAngleY = headEulerAngleY,
       _headEulerAngleZ = headEulerAngleZ,
       _faceCount = faceCount,
       _brightness = brightness,
       _currentFocusPoint = currentFocusPoint,
       _cameraImage = cameraImage;

  // Getters
  bool get isEyeClosed => _isEyeClosed;
  bool get isLookingLeft => _isLookingLeft;
  bool get isLookingRight => _isLookingRight;
  bool get isLookingUp => _isLookingUp;
  bool get isLookingDown => _isLookingDown;
  bool get isSmiling => _isSmiling;
  bool get isBigFace => _isBigFace;
  bool get isSmallFace => _isSmallFace;
  bool get isFaceInsideFrame => _isFaceInsideFrame;
  Rect? get boundingBox => _boundingBox;
  Rect? get frameRect => _frameRect;
  int get faceCount => _faceCount;
  double get brightness => _brightness;
  double get headEulerAngleX => _headEulerAngleX;
  double get headEulerAngleY => _headEulerAngleY;
  double get headEulerAngleZ => _headEulerAngleZ;
  Offset? get currentFocusPoint => _currentFocusPoint;

  // Convert to Map
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'isEyeClosed': _isEyeClosed,
      'isLookingLeft': _isLookingLeft,
      'isLookingRight': _isLookingRight,
      'isLookingUp': _isLookingUp,
      'isLookingDown': _isLookingDown,
      'isSmiling': _isSmiling,
      'isBigFace': _isBigFace,
      'isSmallFace': _isSmallFace,
      'isFaceInsideFrame': _isFaceInsideFrame,
      'boundingBox': _boundingBox,
      'frameRect': _frameRect,
      'faceCount': _faceCount,
      'headEulerAngleX': _headEulerAngleX,
      'headEulerAngleY': _headEulerAngleY,
      'headEulerAngleZ': _headEulerAngleZ,
      'brightness': _brightness,
      'currentFocusPoint': _currentFocusPoint,
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }

  /// Equal when the face *status* is the same: the flags and face count.
  /// Continuous values (box, angles, brightness) are ignored, so the
  /// analyser can tell when the status changed between frames.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LivelinessModel &&
        other._faceCount == _faceCount &&
        other._isEyeClosed == _isEyeClosed &&
        other._isLookingLeft == _isLookingLeft &&
        other._isLookingRight == _isLookingRight &&
        other._isLookingUp == _isLookingUp &&
        other._isLookingDown == _isLookingDown &&
        other._isSmiling == _isSmiling &&
        other._isBigFace == _isBigFace &&
        other._isSmallFace == _isSmallFace &&
        other._isFaceInsideFrame == _isFaceInsideFrame;
  }

  @override
  int get hashCode => Object.hash(
    _faceCount,
    _isEyeClosed,
    _isLookingLeft,
    _isLookingRight,
    _isLookingUp,
    _isLookingDown,
    _isSmiling,
    _isBigFace,
    _isSmallFace,
    _isFaceInsideFrame,
  );
}
