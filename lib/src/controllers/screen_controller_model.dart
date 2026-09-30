part of '../../on_process_camera.dart';

class _ScreenController {
  _ScreenController({
    required this.input,
    required void Function() updateScreen,
    required this.context,
  }) : _cameraLense = input.cameraLense,
       ____updateScreen = updateScreen,
       focusPoint = input.focusMode {
    _instances.add(this);
  }

  //! ------------------------------------------------------ Process-wide camera
  // Android (CameraX) keeps one camera per process: opening or disposing any
  // camera unbinds every other one. So every OnCamera shares one operation
  // queue, and opening a camera first releases the one another OnCamera holds.
  static Future<void> _cameraQueue = Future<void>.value();
  static final List<_ScreenController> _instances = <_ScreenController>[];

  static Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> next = _cameraQueue.then((_) => operation());
    _cameraQueue = next.catchError((Object _) {});
    return next;
  }

  // Initialize variables
  OnCameraController input;
  Function(CameraStatus cameraStatus)? get onStatusChanged =>
      input.onStatusChanged;
  CameraLense _cameraLense;
  final void Function() ____updateScreen;
  BuildContext context;
  bool isRecording = false;

  // Local variables
  NativeDeviceOrientation _orientation = NativeDeviceOrientation.portraitUp;
  bool isInit = false;
  bool isDetecting = false;
  ErrorStatus? errorStatus;
  CameraController? cameraController;
  List<CameraDescription> cameras = <CameraDescription>[];
  LivelinessModel? _liveliness;
  DateTime? _lastAnalyzedTime;

  // Lifecycle
  bool _isClosed = false;
  bool _isSuspended = false; // Camera released while hidden or taken over
  bool _isRouteActive = true; // Route not covered (TickerMode)
  bool _isAppActive = true; // App in the foreground
  bool get _isVisible => _isRouteActive && _isAppActive;
  bool _audioEnabled = false;
  bool? _hasMicPermission; // Asked once; later only the status is read
  NativeDeviceOrientation? _pendingOrientation; // Deferred while recording
  int _streamGeneration = 0; // Invalidates frames from a stopped stream
  bool _isTakingPhoto = false;
  bool _isAdjusting = false;
  Offset? _lastAdjustPoint;
  FocusPoint? _focusBeforeRecording; // Restored when the recording stops

  // Sizes
  Size previewSize = Size.zero;
  Size fullWindowSize = Size.zero;
  Size calculatedOrientationCameraSize = Size.zero;
  Size cameraSize = Size.zero;

  bool isAnalyzing = false;
  Future<void> Function(LivelinessModel data, InputImageModel image)?
  _onLivelinessCallback;

  FocusPoint focusPoint = FocusPoint.auto;

  //! ------------------------------------------------------------------ Getters
  bool get isCameraInitialized => cameraController?.value.isInitialized == true;
  bool get isCameraStreaming =>
      cameraController?.value.isStreamingImages == true;

  //! -------------------------------------------------------------- Initialized
  /// Queued behind every other camera operation, so overlapping requests
  /// (orientation events, lens switches, retries, other OnCameras) never open
  /// two cameras at once.
  Future<void> init({NativeDeviceOrientation? orientation}) =>
      _enqueue(() => _init(orientation: orientation));

  Future<void> _init({NativeDeviceOrientation? orientation}) async {
    if (_isClosed) return;
    if (orientation != null) {
      if (_orientation == orientation) return;
      if (!isInit) return;
      if (errorStatus != null) return;
      if (isRecording) {
        // Re-initialising would end the recording: apply once it stops
        _pendingOrientation = orientation;
        return;
      }
    }
    if (!_isVisible) {
      _isSuspended = true; // Opened by _updateVisibility once visible again
      return;
    }
    _pendingOrientation = null;
    onStatusChanged?.call(CameraStatus.initializing);

    isInit = false;
    errorStatus = null;
    _isSuspended = false;
    ____updateScreen();
    await dispose();
    ____updateScreen();

    await _errorHandler(() async {
      if (orientation == null) {
        await _getPermission;
        cameras = await availableCameras();
      }
      await _releaseOtherCameras();
      await _initCamera(orientation);
    });

    // Widget was disposed while initialising: release the new camera
    if (_isClosed) {
      await dispose();
      return;
    }

    await _setFocusMode();

    isInit = true;
    ____updateScreen();
    onStatusChanged?.call(
      errorStatus == null ? CameraStatus.ready : CameraStatus.error,
    );
  }

  //! ----------------------------------------------------------------- Disposed
  Future<void> dispose({bool isSoft = false}) async {
    final _DevPrintColorEnum color = _DevPrintColorEnum.black;
    final String tag = '_ScreenController - Dispose';
    _streamGeneration++; // Drop frames still being processed
    try {
      if (isCameraStreaming) {
        await cameraController?.stopImageStream();
        if (cameraController != null) {
          await Future<void>.delayed(
            const Duration(milliseconds: 120),
          ); // Give some time to stop stream from method channel
        }
      }
    } catch (e) {
      _devPrint('$tag - Stop Image Stream - $e', color: color);
    }

    try {
      await input.faceAnalyser?.faceDetector.close();
    } catch (e) {
      _devPrint('$tag - Close Face Detector - $e', color: color);
    }
    if (isSoft) return;
    final CameraController? camera = cameraController;
    cameraController = null;
    isRecording = false; // A recording ends with its camera
    _lastAdjustPoint = null;
    try {
      await camera?.dispose();
    } catch (e) {
      _devPrint('$tag - Camera Controller - $e', color: color);
    }
  }

  //! -------------------------------------------------------------------- Close
  /// Final teardown when the widget is disposed. Queued, so a camera opened
  /// by an in-flight [init] is released too; then the camera is handed back
  /// to a visible OnCamera that gave it up for this one.
  Future<void> close() {
    _isClosed = true;
    _instances.remove(this);
    return _enqueue(() async {
      await dispose();
      for (final _ScreenController other in _instances.reversed) {
        if (other._isClosed || !other._isSuspended || !other._isVisible) {
          continue;
        }
        await other._init();
        return;
      }
    });
  }

  //! ----------------------------------------------- Suspend / resume (hidden)
  /// Frees the camera without closing the widget; it re-opens when visible.
  Future<void> _release() async {
    _isSuspended = true;
    isInit = false;
    ____updateScreen();
    await dispose();
  }

  Future<void> _releaseOtherCameras() async {
    for (final _ScreenController other in List<_ScreenController>.of(
      _instances,
    )) {
      if (identical(other, this) || other.cameraController == null) continue;
      await other._release();
    }
  }

  /// Called when the route is covered/uncovered or the app goes to the
  /// background/foreground. A hidden OnCamera must not hold the only camera.
  void updateVisibility({bool? isRouteActive, bool? isAppActive}) {
    final bool wasVisible = _isVisible;
    _isRouteActive = isRouteActive ?? _isRouteActive;
    _isAppActive = isAppActive ?? _isAppActive;
    if (_isVisible == wasVisible) return;

    _enqueue(() async {
      if (_isClosed) return;
      // Current state, not the captured one: rapid toggles collapse
      if (!_isVisible) {
        if (cameraController != null) await _release();
        return;
      }
      if (_isSuspended) await _init();
    });
  }

  //! ----------------------------------------------------------- Ask Permission
  Future<void> get _getPermission async {
    final bool hasCamera = await _askPermission(
      context,
      Permission.camera,
      input.onPermission,
    );
    if (!hasCamera) throw ErrorStatus.permissionDenied;

    // Microphone is optional: without it, video is recorded without audio.
    // Asked once, so a denial doesn't bring up a dialog on every re-init.
    _audioEnabled = false;
    if (!input.enableAudio || !context.mounted) return;
    if (_hasMicPermission == null) {
      _hasMicPermission = input.onPermission == null
          ? (await Permission.microphone.request()).isGranted
          : await _askPermission(
              context,
              Permission.microphone,
              input.onPermission,
            );
    } else if (_hasMicPermission == false) {
      // Picks up a grant made in Settings, without prompting
      _hasMicPermission = (await Permission.microphone.status).isGranted;
    }
    _audioEnabled = _hasMicPermission!;
  }

  //! ------------------------------------------------------------ Select Camera
  CameraDescription get _selectCamera {
    if (cameras.isEmpty) throw ErrorStatus.noCameraFound;

    for (final CameraDescription camera in cameras) {
      if (camera.lensDirection == _cameraLense._lense) {
        return camera;
      }
    }
    throw ErrorStatus.selectedCameraNotFound;
  }

  //! ------------------------------------------------------------ Error Handler
  Future<void> _errorHandler(Future<void> Function() function) async {
    try {
      await function();
    } catch (e) {
      ErrorStatus? errorStatus_;
      if (e is ErrorStatus) errorStatus_ = e;

      _devPrint(
        '''Error: ${errorStatus_ == null ? e : '${errorStatus_.message} (${errorStatus_.name})'}''',
        color: _DevPrintColorEnum.red,
      );
      errorStatus = errorStatus_ ?? ErrorStatus.unknown;
    }
  }

  //! -------------------------------------------------------- Initialize Camera
  Future<void> _initCamera(NativeDeviceOrientation? orientation) async {
    cameraController = CameraController(
      _selectCamera,
      input.resolution._resolution,
      enableAudio: _audioEnabled,
      fps: input.fps,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await cameraController!.initialize();
    _orientation =
        orientation ??
        await NativeDeviceOrientationCommunicator().orientation();
    await _setPreviewOrientation(_orientation);

    Size? previewSize_ = cameraController!.value.previewSize;

    if (previewSize_ == null) throw ErrorStatus.cameraCanNotBeInitialized;
    cameraSize = previewSize_;

    if (isAnalyzing) {
      _startFaceDetection(); // Reattach analyser on re-init
    }
  }

  //! -------------------------------------------------- Set Preview Orientation
  Future<void> _setPreviewOrientation(
    NativeDeviceOrientation orientation,
  ) async {
    if (!cameraController!.value.isInitialized) return;
    final DeviceOrientation deviceOrientation = orientation._deviceOrientation;
    _devPrint('''Set Preview Orientation: ${deviceOrientation.name}''');
    await cameraController!.lockCaptureOrientation(deviceOrientation);
  }

  //! --------------------------------------------------------------- Take Photo
  /// Returns null instead of throwing (camera not ready, capture already in
  /// progress, plugin error), so callers never wait on a lost exception.
  Future<Uint8List?> _takePhoto(bool doCropped) async {
    final CameraController? camera = cameraController;
    if (camera == null || !camera.value.isInitialized) return null;
    if (_isTakingPhoto) return null; // The plugin rejects overlapping captures

    _isTakingPhoto = true;
    try {
      final XFile file = await camera.takePicture();
      final bool isFront =
          camera.description.lensDirection == CameraLensDirection.front;

      return await _cropImageToWindow(
        _CropImageParametersModel(
          file: file,
          cameraSize: cameraSize,
          previewSize: previewSize,
          orientation: camera.value.deviceOrientation,
          doFlip: isFront && input.frontFlip,
          doCrop: doCropped,
        ),
      );
    } catch (e) {
      _devPrint('Take photo - $e', color: _DevPrintColorEnum.red);
      return null;
    } finally {
      _isTakingPhoto = false;
    }
  }

  //! ----------------------------------------------------- Start Face Detection
  void _startFaceDetection() {
    if (input.faceAnalyser == null) return;
    if (!isCameraInitialized) return;
    if (isCameraStreaming) return;

    isDetecting = false;
    final int generation = ++_streamGeneration;

    cameraController!.startImageStream((CameraImage image) async {
      if (isDetecting || _isClosed) return; // Drop frame (busy or disposed)
      if (generation != _streamGeneration) return; // Stream was stopped

      isDetecting = true;
      try {
        //! --------------------------------- Detect Liveliness from CameraImage
        final _Tuple2<LivelinessModel, InputImage> data =
            await _detectLiveliness(image, this);
        // Stopped or restarted meanwhile (e.g. lens switch): stale frame
        if (generation != _streamGeneration || _isClosed) return;
        await _passDataToParent(data);
      } catch (e) {
        // A failed frame must not leave isDetecting stuck and stall analysis
        _devPrint('Face Analyser - $e', color: _DevPrintColorEnum.red);
      } finally {
        // A newer stream has already reset the flag for itself
        if (generation == _streamGeneration) isDetecting = false;
      }
    });
    isAnalyzing = true;
    _devPrint('Face Analyser started', color: _DevPrintColorEnum.green);
  }

  /// Delivers a frame when it is the first one, when `statusCheckDelay` has
  /// passed since the last delivery, or when the face status changed.
  Future<void> _passDataToParent(
    _Tuple2<LivelinessModel, InputImage> data,
  ) async {
    Future<void> sendData() async {
      _liveliness = data.item1;
      _lastAnalyzedTime = DateTime.now();

      // get Lumen / brightness from the InputImage (before any callback)
      final double brightness = estimateBrightnessFromInputImage(data.item2);
      data.item1._brightness = brightness;

      await input.faceAnalyser!.onLiveliness?.call(
        data.item1,
        InputImageModel._fromInputImage(data.item2),
      );

      await _onLivelinessCallback?.call(
        data.item1,
        InputImageModel._fromInputImage(data.item2),
      );

      final ui.Rect? faceRect = data.item1._boundingBox;
      if (faceRect != null) {
        Future<void>.microtask(() => _adjustCamera(faceRect));
      }
    }

    //! First time send data
    if (_lastAnalyzedTime == null) {
      await sendData();
      return;
    }

    //! Check time difference
    final Duration statusCheckDelay = input.faceAnalyser!.statusCheckDelay;
    final Duration sinceLastSent = DateTime.now().difference(
      _lastAnalyzedTime!,
    );
    if (sinceLastSent >= statusCheckDelay) {
      await sendData();
      return;
    }

    //! Status changed since the last delivered frame
    if (_liveliness != data.item1) {
      await sendData();
      return;
    }
  }

  Future<void> _adjustCamera(ui.Rect faceRect) async {
    if (_isAdjusting) return;
    try {
      if (!isCameraInitialized) return;
      if (cameraController == null) return;
      final FaceAnalyserData? analyser = input.faceAnalyser;
      final bool autoFocus = analyser?.autoFocusOnFace ?? false;
      final bool autoExposure = analyser?.autoExposureOnFace ?? false;

      if (!autoExposure && !autoFocus) return;

      final Size camSize = calculatedOrientationCameraSize;
      if (camSize.width == 0 || camSize.height == 0) return;

      // Face center in image coords
      final double cx = (faceRect.left + faceRect.right) / 2.0;
      final double cy = (faceRect.top + faceRect.bottom) / 2.0;

      // Normalize to 0..1 relative to camera image size
      double nx = cx / camSize.width;
      double ny = cy / camSize.height;

      // If front camera mirror is used, flip X
      final bool isFront = _cameraLense._lense == CameraLensDirection.front;
      if (isFront) nx = 1.0 - nx;

      nx = nx.clamp(0.0, 1.0);
      ny = ny.clamp(0.0, 1.0);

      // Re-point only when the face moved: doing it on every frame makes
      // focus/exposure hunt and floods the camera with requests
      final Offset point = Offset(nx, ny);
      final Offset? last = _lastAdjustPoint;
      if (last != null && (point - last).distance < 0.05) return;
      _isAdjusting = true;
      _lastAdjustPoint = point;

      String errorMessage = '';

      if (autoFocus) {
        try {
          await cameraController!.setFocusPoint(point); // Set Focus
        } catch (e) {
          errorMessage = e.toString();
        }
      }
      if (autoExposure) {
        try {
          await cameraController!.setExposurePoint(point); // Exposure
        } catch (e) {
          errorMessage = e.toString();
        }
      }

      if (errorMessage.isNotEmpty) throw Exception(errorMessage);
    } catch (e) {
      _devPrint('_Adjust Camera - $e', color: _DevPrintColorEnum.red);
    } finally {
      _isAdjusting = false;
    }
  }

  /// Throws if the camera isn't ready or recording can't start, so callers
  /// find out now rather than when [_stopVideo] returns null.
  Future<void> _startVideo() async {
    if (isRecording) return;
    final CameraController? camera = cameraController;
    if (camera == null || !camera.value.isInitialized) {
      throw StateError('Camera is not ready');
    }
    try {
      await _holdExposureForRecording(camera);
      await camera.startVideoRecording(enablePersistentRecording: false);
      isRecording = true;
    } catch (e) {
      _devPrint(
        'Error starting video recording: $e',
        color: _DevPrintColorEnum.red,
      );
      // No recording: undo the focus lock from _holdExposureForRecording
      final FocusPoint? focusBefore = _focusBeforeRecording;
      _focusBeforeRecording = null;
      if (focusBefore != null) await _setFocusMode(mode: focusBefore);
      rethrow;
    }
    _devPrint(
      'Video recording started${isAnalyzing ? ' with streaming' : ''}',
      color: _DevPrintColorEnum.magenta,
    );
  }

  Future<XFile?> _stopVideo() async {
    if (!isCameraInitialized) return null;
    if (cameraController == null) return null;
    if (!isRecording) return null;
    XFile? video;
    bool isStreaming = isCameraStreaming || isAnalyzing;
    try {
      if (isStreaming) await _stopAnalyser();
      if (cameraController?.value.isRecordingVideo == true) {
        video = await cameraController!.stopVideoRecording();
      }
    } catch (e) {
      _devPrint(
        'Error stopping video recording: $e',
        color: _DevPrintColorEnum.red,
      );
    } finally {
      // Reset even on failure so a later startVideo isn't silently ignored
      isRecording = false;
    }

    _devPrint(
      'Video recording stopped. File saved at: ${video?.path}',
      color: _DevPrintColorEnum.magenta,
    );

    if (isStreaming) {
      _devPrint(
        'Restarting analyser after video stop',
        color: _DevPrintColorEnum.magenta,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _startFaceDetection();
    }

    // Back to the focus mode used before the recording
    final FocusPoint? focusBefore = _focusBeforeRecording;
    _focusBeforeRecording = null;
    if (focusBefore != null) await _setFocusMode(mode: focusBefore);

    // Orientation changed during the recording
    final NativeDeviceOrientation? pending = _pendingOrientation;
    if (pending != null) unawaited(init(orientation: pending));
    return video;
  }

  /// Keeps the face exposure for the whole recording. The analyser is stopped
  /// while recording, so nothing re-points exposure, and the plugin cancels
  /// an exposure point after ~5 s unless focus is locked: lock focus, then
  /// set the point again so the plugin sets it without auto-cancel.
  Future<void> _holdExposureForRecording(CameraController camera) async {
    final Offset? point = _lastAdjustPoint;
    final bool autoExposure = input.faceAnalyser?.autoExposureOnFace ?? false;
    if (point == null || !autoExposure) return;

    _focusBeforeRecording = focusPoint;
    await _setFocusMode(mode: FocusPoint.locked);
    try {
      await camera.setExposurePoint(point);
    } catch (e) {
      _devPrint('Hold exposure - $e', color: _DevPrintColorEnum.red);
    }
  }

  Future<void> _stopAnalyser() async {
    await dispose(isSoft: true);
    isAnalyzing = false;
    _devPrint('Face Analyser stopped', color: _DevPrintColorEnum.green);
  }

  /// Returns lumen/brightness value between 0.0 – 1.0
  double estimateBrightnessFromInputImage(InputImage image) {
    if (image.bytes == null || image.bytes!.isEmpty) return -1; // Not usable

    final Uint8List bytes = image.bytes!;
    int sum = 0;

    // BGRA frames (iOS): average the colour channels of every 10th pixel
    if (image.metadata?.format == InputImageFormat.bgra8888) {
      int count = 0;
      for (int i = 0; i + 2 < bytes.length; i += 40) {
        sum += (bytes[i] + bytes[i + 1] + bytes[i + 2]) ~/ 3;
        count++;
      }
      return count == 0 ? -1 : sum / count / 255.0;
    }

    // Sample pixels to reduce CPU (every 10th byte)
    for (int i = 0; i < bytes.length; i += 10) {
      sum += bytes[i];
    }

    final double avg = sum / (bytes.length / 10);
    return avg / 255.0; // Normalize 0–1
  }

  // Zoom to the specified location
  Future<void> _zoomToLocation(double zoomFactor) async {
    if (!isCameraInitialized) return;
    if (cameraController == null) return;

    await cameraController!.setZoomLevel(zoomFactor);
  }

  Future<void> _setFocusMode({FocusPoint? mode}) async {
    if (!isCameraInitialized) return;

    try {
      await cameraController?.setFocusMode(
        mode?._focusMode ?? focusPoint._focusMode,
      );
      if (mode != null) focusPoint = mode;
    } catch (e) {
      _devPrint('_setFocusMode: $e', color: _DevPrintColorEnum.red);
    }
  }
}
