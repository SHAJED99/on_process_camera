// Standalone copy of the SDK's liveness flow, to test it on a device without
// starting an onboarding journey.
//
// Source: onboarding_sdk/lib/features/ekyc/liveliness/
//   (bloc/bloc.dart, bloc/state.dart, bloc/event.dart, liveliness_screen.dart)
//
// Copied as is: camera settings, message priorities, auto-zoom, stillness
// check, photo capture, 5 s video with progress, retake. Replaced: server data
// (fixed English text), submit/upload/goNext ("Next" opens a result page),
// SDK widgets/colours (Material), SecureTempFile (plain delete), image
// compression (same loop, without the SDK's loader overlay). Dropped: the
// debug "fill from gallery" button. Keep in sync when the SDK flow changes.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:on_process_camera/on_process_camera.dart';

// SDK constants (components.dart)
const int _defaultDocumentSizeInBytes = 5 * 1024 * 1024; // 5 MB
const Size _defaultImageSizeLiveliness = Size(480, 640);
const double _padding = 16;
const Color _primary = Colors.teal;

/// English values of the SDK's EkycStrings used by the flow.
abstract final class _Strings {
  static const String livelinessTitle = 'Your Picture';
  static const String keepFaceInsideAndNoOtherFaces =
      'Please make sure to keep the face inside the frame and there are no '
      'other faces';
  static const String checkPictureCarefully = 'Check the picture carefully';
  static const String keepSmilingAndStayStill =
      'Please ask Applicant to stay still';
  static const String capturingImage = 'Capturing...';
  static const String unableToVerifyLiveliness =
      'Unable to verify liveliness. Please try again.';
  static const String increaseLighting =
      'Please increase lighting to capture the photo';
  static const String pleaseLookAtTheCamera =
      'Please ask Applicant to look at the camera with eyes open';
  static const String noFace = 'Please position Applicant in front of camera';
  static const String multipleFaceFound =
      'Multiple faces detected - ensure only Applicant is in frame';
  static const String keepFaceInsideFrame =
      "Please position Applicant's face inside the frame";
  static const String autoAdjustZoom = 'Adjusting zoom automatically';
  static const String moveFaceFarther =
      'Please ask Applicant to step back a little';
  static const String moveFaceCloser = 'Please ask Applicant to come closer';
  static const String keepHeadStraight =
      'Please ask Applicant to keep head straight';
  static const String lookSlightlyUpIntoCamera =
      'Please ask Applicant to look slightly up';
  static const String lookSlightlyDownIntoCamera =
      'Please ask Applicant to look slightly down';
  static const String lookSlightlyRightIntoCamera =
      'Please ask Applicant to look slightly to their right';
  static const String lookSlightlyLeftIntoCamera =
      'Please ask Applicant to look slightly to their left';
  static const String takeSelfieAgain = 'Take picture again';
  static const String next = 'Next';
  static const String switchCamera = 'Switch camera';
}

//! ===================================================================== Screen
class LivenessFlowScreen extends StatelessWidget {
  const LivenessFlowScreen({super.key, this.isFrontCamera = true});
  final bool isFrontCamera;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<_LivelinessBloc>(
      create: (_) => _LivelinessBloc(_LivelinessState(), isFrontCamera),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SDK liveness flow'),
          //! ------------------------------------------- Switch Camera Button
          actions: const <Widget>[_SwitchCameraButton(), SizedBox(width: 8)],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(_padding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight - _padding * 2,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        children: <Widget>[
                          _Heading(),
                          SizedBox(height: _padding),
                          _ImageWindow(),
                          SizedBox(height: _padding),
                          _LivelinessInfo(),
                          SizedBox(height: _padding),
                        ],
                      ),
                      _ButtonGroup(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _isPreview(_LivelinessState state) {
  if (state.livelinessImageFile == null) return false;
  if (state.livelinessVideoFile == null) return false;

  return true;
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_LivelinessBloc, _LivelinessState>(
      builder: (BuildContext context, _LivelinessState state) {
        final String subLabel = _isPreview(state)
            ? _Strings.checkPictureCarefully
            : _Strings.keepFaceInsideAndNoOtherFaces;
        final TextTheme text = Theme.of(context).textTheme;

        return Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_Strings.livelinessTitle, style: text.titleLarge),
              const SizedBox(height: 4),
              Text(subLabel, style: text.bodyMedium),
            ],
          ),
        );
      },
    );
  }
}

class _ImageWindow extends StatelessWidget {
  const _ImageWindow();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: AspectRatio(
        aspectRatio: 1,
        child: BlocBuilder<_LivelinessBloc, _LivelinessState>(
          builder: (BuildContext context, _LivelinessState state) {
            final File? image = state.livelinessImageFile;
            final File? video = state.livelinessVideoFile;
            final double totalSteps = context
                .read<_LivelinessBloc>()
                .totalSteps;

            final Widget child = image == null || video == null
                ? const _CameraView()
                : Image.file(image, fit: BoxFit.cover);

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipOval(child: child),

                //! ------------------------------ Circular Progress Indicator
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: state.progress / totalSteps,
                    strokeWidth: _padding / 4,
                    strokeCap: StrokeCap.round,
                    valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                    backgroundColor: Colors.grey.shade300,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SwitchCameraButton extends StatelessWidget {
  const _SwitchCameraButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_LivelinessBloc, _LivelinessState>(
      builder: (BuildContext context, _LivelinessState state) {
        if (_isPreview(state)) return const SizedBox();

        final bool isEnabled = state.isReady && !state.doingLiveliness;

        return IconButton.filled(
          tooltip: _Strings.switchCamera,
          onPressed: isEnabled
              ? () => context.read<_LivelinessBloc>().add(
                  _SwitchCameraLensEvent(),
                )
              : null,
          style: IconButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          icon: const Icon(Icons.cameraswitch_rounded),
        );
      },
    );
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView();

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  late OnCameraController cameraController;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) return;
    _isInitialized = true;

    final _LivelinessBloc bloc = BlocProvider.of<_LivelinessBloc>(context);
    final bool isFrontCamera = bloc.state.isFrontCamera;

    // Same settings as the SDK's liveness screen
    final FaceAnalyserData faceAnalyserData = FaceAnalyserData(
      // Every frame: the bloc needs consecutive frames for its stillness check
      statusCheckDelay: Duration.zero,
      bigFacePercentage: 0.5,
      autoFocusOnFace: false,
    );

    cameraController = OnCameraController(
      cameraLense: isFrontCamera ? CameraLense.front : CameraLense.back,
      resolution: Resolution.high,
      // Fixed like the recording, so brightness doesn't jump when video starts
      fps: 30,
      faceAnalyser: faceAnalyserData,
      onStatusChanged: (CameraStatus cameraStatus) {
        if (cameraStatus != CameraStatus.ready) return;
        if (!mounted) return;
        BlocProvider.of<_LivelinessBloc>(
          context,
        ).add(_OnCameraReadyEvent(cameraController, faceAnalyserData));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnCamera(controller: cameraController);
  }
}

class _LivelinessInfo extends StatelessWidget {
  const _LivelinessInfo();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_LivelinessBloc, _LivelinessState>(
      builder: (BuildContext context, _LivelinessState state) {
        if (_isPreview(state)) return const SizedBox();

        return Text(state.infoMessage, textAlign: TextAlign.center);
      },
    );
  }
}

class _ButtonGroup extends StatelessWidget {
  const _ButtonGroup();

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: BlocBuilder<_LivelinessBloc, _LivelinessState>(
        builder: (BuildContext context, _LivelinessState state) {
          if (!_isPreview(state)) {
            return _RoundedButton(
              isEnabled: state.isReady,
              isRunning: state.doingLiveliness,
              onTap: () =>
                  context.read<_LivelinessBloc>().add(_LivelinessDataEvent()),
            );
          }

          return Column(
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.read<_LivelinessBloc>().add(
                    _LivelinessRetakeEvent(),
                  ),
                  child: const Text(_Strings.takeSelfieAgain),
                ),
              ),
              const SizedBox(height: _padding / 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // SDK: compress video, upload, go to the next step.
                  // Here: show what would be submitted.
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _LivenessResultScreen(
                        image: state.livelinessImageFile!,
                        video: state.livelinessVideoFile!,
                      ),
                    ),
                  ),
                  child: const Text(_Strings.next),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Look of the SDK's RoundedButton (shutter button).
class _RoundedButton extends StatelessWidget {
  const _RoundedButton({
    required this.isEnabled,
    required this.isRunning,
    required this.onTap,
  });

  final bool isEnabled;
  final bool isRunning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isEnabled && !isRunning ? _primary : Colors.grey;

    return SizedBox.square(
      dimension: _padding * 3,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEnabled && !isRunning ? onTap : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.all(_padding / 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (isRunning)
                const Padding(
                  padding: EdgeInsets.all(_padding / 2),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

//! ============================================================= Result screen
class _LivenessResultScreen extends StatefulWidget {
  const _LivenessResultScreen({required this.image, required this.video});
  final File image;
  final File video;

  @override
  State<_LivenessResultScreen> createState() => _LivenessResultScreenState();
}

class _LivenessResultScreenState extends State<_LivenessResultScreen> {
  String _imageInfo = '';
  String _videoInfo = '';

  @override
  void initState() {
    super.initState();
    _describe();
  }

  Future<void> _describe() async {
    final Uint8List bytes = await widget.image.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    final String imageInfo =
        '${decoded.width}×${decoded.height} · ${_kb(bytes.length)}';
    decoded.dispose();
    final int videoSize = await widget.video.length();
    if (!mounted) return;
    setState(() {
      _imageInfo = imageInfo;
      _videoInfo = '${_kb(videoSize)} · ${widget.video.uri.pathSegments.last}';
    });
  }

  String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Would be submitted')),
      body: ListView(
        padding: const EdgeInsets.all(_padding),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(widget.image, height: 320, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Text('Selfie: $_imageInfo', style: text.bodyMedium),
          Text(
            'Compressed like the SDK: min '
            '${_defaultImageSizeLiveliness.width.toInt()}×'
            '${_defaultImageSizeLiveliness.height.toInt()}, max '
            '${_defaultDocumentSizeInBytes ~/ (1024 * 1024)} MB',
            style: text.bodySmall,
          ),
          const SizedBox(height: _padding),
          Text('Video: $_videoInfo', style: text.bodyMedium),
          Text(
            'The SDK compresses the video to 350 KB when submitting; '
            'this is the raw recording.',
            style: text.bodySmall,
          ),
          const SizedBox(height: _padding),
          Text(
            'Go back and tap "${_Strings.takeSelfieAgain}" to delete both '
            'files and retry.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

//! ====================================================================== Bloc
/// Copy of the SDK's _LivelinessBloc (bloc/bloc.dart) with the SDK plumbing
/// removed: no server data, no submit.
class _LivelinessBloc extends Bloc<_LivelinessEvent, _LivelinessState> {
  _LivelinessBloc(_LivelinessState initialState, bool isFrontCamera)
    : super(initialState.copyWith(isFrontCamera: isFrontCamera)) {
    on<_OnCameraReadyEvent>(_onCameraReadyEvent);
    on<_SwitchCameraLensEvent>(_onSwitchCameraLensEvent);
    on<_LivelinessDataEvent>(_onLivelinessDataEvent);
    on<_LivelinessRetakeEvent>(_onLivelinessRetakeEvent);
  }

  OnCameraController? controller;
  FaceAnalyserData faceAnalyserData = FaceAnalyserData();
  double currentZoomLevel = 1.0;
  final double livelinessDuration = 5; // Seconds
  final double totalSteps = 6;
  final double minFaceSizePercentage = 0.07; // 7% of frame minimum
  final double movementThreshold = 2; // Degrees
  final Duration requiredStillDuration = const Duration(seconds: 1);

  //! --------------------------------------------------- _onSwitchCameraLensEvent
  Future<void> _onSwitchCameraLensEvent(
    _SwitchCameraLensEvent event,
    Emitter<_LivelinessState> emit,
  ) async {
    if (controller == null) return;
    // Switching re-initialises the camera, which would break a running capture
    if (!state.isReady || state.doingLiveliness) return;
    if (state.livelinessImageFile != null) return;

    final bool isFrontCamera = !state.isFrontCamera;

    // Disable capture while the camera re-initialises
    emit(state.copyWith(isReady: false, infoMessage: ''));

    try {
      // Completes only after the camera has been re-initialised
      await controller!.switchCameraLense(
        isFrontCamera ? CameraLense.front : CameraLense.back,
      );
      currentZoomLevel = 1.0;
      ___reset();
      emit(state.copyWith(isFrontCamera: isFrontCamera));
    } catch (e) {
      debugPrint('Switch Camera Lens Error: $e');
    }

    emit(state.copyWith(isReady: true));
  }

  //! ------------------------------------------------------ _onCameraReadyEvent
  void _onCameraReadyEvent(
    _OnCameraReadyEvent event,
    Emitter<_LivelinessState> emit,
  ) {
    controller = event.controller;
    faceAnalyserData = event.faceAnalyserData;

    emit(state.copyWith(isReady: true));
  }

  //! --------------------------------------------------- _onLivelinessDataEvent
  Future<void> _onLivelinessDataEvent(
    _LivelinessDataEvent event,
    Emitter<_LivelinessState> emit,
  ) async {
    if (!state.isReady) return;
    if (controller == null) return;
    ___reset();

    emit(
      state.copyWith(
        progress: 0.0,
        infoMessage: '',
        isReady: false,
        doingLiveliness: true,
      ),
    );

    String errorMessage = '';
    bool validFace = false;
    bool sendCapturing = false;

    LivelinessModel? lastValidFrame;
    String previousMessage = '';

    try {
      //! ---------------------------------------------------------------- Image
      //! Capture image using liveliness
      final Completer<Uint8List?> completer = Completer<Uint8List?>();
      controller!.startAnalyser((
        LivelinessModel value,
        InputImageModel imageData,
      ) async {
        String message = await ___getMessage(value);
        if (message.isEmpty) {
          validFace = true;
          lastValidFrame = value;
          message = _Strings.keepSmilingAndStayStill;
        } else {
          validFace = false;
          lastValidFrame = null;
          ___reset();
        }

        bool isFaceStill = true;

        if (validFace && lastValidFrame != null) {
          // MicroTask - only trigger once when enough valid frames accumulated
          Future<void>.microtask(() async {
            if (sendCapturing) return;
            sendCapturing = true;

            isFaceStill = _isFaceStill(lastValidFrame!);
            if (!isFaceStill) {
              sendCapturing = false;
              return;
            }

            // Critical: Re-validate eyes are still open right before capture
            if (lastValidFrame!.isEyeClosed) {
              sendCapturing = false;
              return;
            }
            final Uint8List? res = await controller!.takePhoto(
              doCropped: false,
            );
            completer.complete(res);
          });
        }

        if (sendCapturing) message = _Strings.capturingImage;

        if (previousMessage != message) {
          previousMessage = message;
          emit(state.copyWith(infoMessage: message));
        }
      });

      Uint8List? photo = await completer.future;
      await controller!.stopAnalyser();

      if (photo == null) throw 'image file is null';

      //! ---------------------------------------------------------------- Video
      //! Start video recording
      await controller!.startVideo();

      //! Updating progress bar
      for (double i = 1; i <= livelinessDuration + 1; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        emit(state.copyWith(progress: i));
      }

      //! Stop video recording
      final videoFile = await controller!.stopVideo().timeout(
        const Duration(seconds: 15), // Increased timeout for slower devices
        onTimeout: () {
          debugPrint('Video recording timeout');
          return null;
        },
      );
      if (videoFile == null) throw 'video file is null';

      //! Image Compression
      photo = await _onCameraImageCompression(
        image: photo,
        maxSizeInBytes: _defaultDocumentSizeInBytes,
        minWidth: _defaultImageSizeLiveliness.width,
        minHeight: _defaultImageSizeLiveliness.height,
      );

      final Directory scratchDirectory = await Directory(
        '${Directory.systemTemp.path}/liveness_flow',
      ).create(recursive: true);
      final File imageFile = File(
        '${scratchDirectory.path}/'
        'liveliness_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      imageFile.writeAsBytesSync(photo);

      emit(
        state.copyWith(
          progress: totalSteps,
          livelinessImageFile: imageFile,
          livelinessVideoFile: File(videoFile.path),
        ),
      );
    } catch (e) {
      debugPrint('Liveliness Error: $e');
      errorMessage = _Strings.unableToVerifyLiveliness;

      if (e.toString().isNotEmpty) errorMessage = '$errorMessage\n$e';
    }

    emit(
      state.copyWith(
        isReady: true,
        progress: 0.0,
        infoMessage: errorMessage,
        doingLiveliness: false,
      ),
    );
  }

  double? pastFaceX;
  double? pastFaceY;
  double? pastFaceZ;
  DateTime? _stillStartAt;

  void ___reset() {
    pastFaceX = null;
    pastFaceY = null;
    pastFaceZ = null;
    _stillStartAt = null;
  }

  bool _isFaceStill(LivelinessModel value) {
    final DateTime now = DateTime.now();
    final double faceX = value.headEulerAngleX;
    final double faceY = value.headEulerAngleY;
    final double faceZ = value.headEulerAngleZ;

    void reset() {
      _stillStartAt = now;
      pastFaceX = faceX;
      pastFaceY = faceY;
      pastFaceZ = faceZ;
    }

    if (pastFaceX == null ||
        pastFaceY == null ||
        pastFaceZ == null ||
        _stillStartAt == null) {
      reset();
      return false;
    }

    final double diffX = (faceX - pastFaceX!).abs();
    final double diffY = (faceY - pastFaceY!).abs();
    final double diffZ = (faceZ - pastFaceZ!).abs();

    // Check if any axis movement exceeds threshold
    if (diffX > movementThreshold ||
        diffY > movementThreshold ||
        diffZ > movementThreshold) {
      reset();
      return false;
    }

    final Duration timeGap = now.difference(_stillStartAt!);
    return timeGap >= requiredStillDuration;
  }

  Future<bool> _zoom({required LivelinessModel value, bool? zoomIn}) async {
    if (zoomIn == null) {
      currentZoomLevel = 1.0;
    } else {
      final Rect? faceBoundingBox = value.boundingBox;
      final double? faceSize = faceBoundingBox == null
          ? null
          : value.frameRect?.getSizePercentage(faceBoundingBox);

      if (faceSize == null) return false;
      if (faceSize <= minFaceSizePercentage) return false;
      if (faceSize <= 0) return false;

      // Smoother zoom calculation with constraints
      final double targetSize = zoomIn
          ? faceAnalyserData.smallFacePercentage
          : faceAnalyserData.bigFacePercentage;

      double step = (faceSize - targetSize).abs();
      step = step.clamp(0.05, 0.2); // Limit step size for smoother zoom

      if (!zoomIn) step = -step;
      currentZoomLevel = (currentZoomLevel + step).clamp(1.0, 5.0);
    }

    try {
      await controller?.zoomLocation(currentZoomLevel);
      return true;
    } catch (e) {
      debugPrint('Zoom Error: $e');
    }

    return false;
  }

  Future<String> ___getMessage(LivelinessModel value) async {
    // Priority 1: Lighting check
    if (value.brightness < 0.4) {
      return _Strings.increaseLighting;
    }

    // Priority 2: Eye detection (CRITICAL - must be checked early)
    if (value.isEyeClosed) {
      return _Strings.pleaseLookAtTheCamera;
    }

    // Priority 3: Face detection
    if (value.faceCount == 0) {
      await _zoom(value: value);
      return _Strings.noFace;
    }

    // Priority 4: Multiple faces
    if (value.faceCount > 1) {
      await _zoom(value: value);
      return _Strings.multipleFaceFound;
    }

    // Priority 4: Face positioning
    if (!value.isFaceInsideFrame) {
      if (value.isBigFace) await _zoom(value: value, zoomIn: false);
      return _Strings.keepFaceInsideFrame;
    }

    // Priority 5: Face size (with auto-zoom)
    if (value.isBigFace) {
      final bool res = await _zoom(value: value, zoomIn: false);

      if (res) return _Strings.autoAdjustZoom;
      return _Strings.moveFaceFarther;
    }
    if (value.isSmallFace) {
      final bool res = await _zoom(value: value, zoomIn: true);
      if (res) return _Strings.autoAdjustZoom;
      return _Strings.moveFaceCloser;
    }

    // Priority 6: Head orientation - Roll (Z axis)
    if (value.headEulerAngleZ.abs() > 10) {
      return _Strings.keepHeadStraight;
    }

    // Priority 7: Head orientation - Pitch (X axis)
    final double headEulerAngleX = value.headEulerAngleX;
    if (headEulerAngleX.abs() > 10) {
      if (headEulerAngleX < 0) {
        return _Strings.lookSlightlyUpIntoCamera;
      } else {
        return _Strings.lookSlightlyDownIntoCamera;
      }
    }

    // Priority 8: Head orientation - Yaw (Y axis)
    final double headEulerAngleY = value.headEulerAngleY;
    if (headEulerAngleY.abs() > 10) {
      if (headEulerAngleY > 0) {
        return _Strings.lookSlightlyRightIntoCamera;
      } else {
        return _Strings.lookSlightlyLeftIntoCamera;
      }
    }

    // All checks passed
    return '';
  }

  //! ------------------------------------------------- _onLivelinessRetakeEvent
  Future<void> _onLivelinessRetakeEvent(
    _LivelinessRetakeEvent event,
    Emitter<_LivelinessState> emit,
  ) async {
    // A retake abandons the previous capture - remove the selfie and video
    await _delete(state.livelinessImageFile);
    await _delete(state.livelinessVideoFile);
    emit(state.removeFiles(infoMessage: ''));
  }

  Future<void> _delete(File? file) async {
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// The SDK's onCameraImageCompression loop, without its loader overlay.
Future<Uint8List> _onCameraImageCompression({
  required Uint8List image,
  required int maxSizeInBytes,
  double minWidth = 1920,
  double minHeight = 1080,
  int maxTry = 10,
}) async {
  final int imageSize = image.lengthInBytes;
  Uint8List? fallback;
  int tryCount = 0;
  final int sizeDistance = imageSize - maxSizeInBytes;
  final int intervalQuality = (sizeDistance / imageSize * 100).toInt();

  try {
    while (sizeDistance > 0 && intervalQuality < 100) {
      final int interval = intervalQuality ~/ (tryCount + 1);

      fallback = await FlutterImageCompress.compressWithList(
        image,
        quality: interval,
        minWidth: minWidth.toInt(),
        minHeight: minHeight.toInt(),
      );

      if (fallback.lengthInBytes < maxSizeInBytes) break;
      if (maxTry <= tryCount) break;
      tryCount++;
    }
  } catch (e) {
    debugPrint('Image compression failed: $e');
  }

  return fallback ?? image;
}

//! ===================================================================== State
/// Copy of the SDK's _LivelinessState without the server data.
class _LivelinessState {
  _LivelinessState({
    this.livelinessVideoFile,
    this.livelinessImageFile,
    this.doingLiveliness = false,
    this.infoMessage = '',
    this.isReady = false,
    this.progress = 0.0,
    this.isFrontCamera = true,
  });

  final File? livelinessVideoFile;
  final File? livelinessImageFile;
  final bool isReady;
  final bool doingLiveliness;
  final String infoMessage;
  final double progress;
  final bool isFrontCamera;

  _LivelinessState copyWith({
    File? livelinessVideoFile,
    File? livelinessImageFile,
    bool? doingLiveliness,
    String? infoMessage,
    bool? isReady,
    double? progress,
    bool? isFrontCamera,
  }) {
    return _LivelinessState(
      livelinessVideoFile: livelinessVideoFile ?? this.livelinessVideoFile,
      livelinessImageFile: livelinessImageFile ?? this.livelinessImageFile,
      doingLiveliness: doingLiveliness ?? this.doingLiveliness,
      infoMessage: infoMessage ?? this.infoMessage,
      isReady: isReady ?? this.isReady,
      progress: progress ?? this.progress,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }

  _LivelinessState removeFiles({String? infoMessage}) {
    return _LivelinessState(
      doingLiveliness: doingLiveliness,
      infoMessage: infoMessage ?? this.infoMessage,
      isReady: isReady,
      progress: progress,
      isFrontCamera: isFrontCamera,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _LivelinessState &&
        other.livelinessVideoFile == livelinessVideoFile &&
        other.livelinessImageFile == livelinessImageFile &&
        other.doingLiveliness == doingLiveliness &&
        other.infoMessage == infoMessage &&
        other.isReady == isReady &&
        other.progress == progress &&
        other.isFrontCamera == isFrontCamera;
  }

  @override
  int get hashCode => Object.hash(
    livelinessVideoFile,
    livelinessImageFile,
    doingLiveliness,
    infoMessage,
    isReady,
    progress,
    isFrontCamera,
  );
}

//! ==================================================================== Events
sealed class _LivelinessEvent {}

class _LivelinessDataEvent extends _LivelinessEvent {}

class _LivelinessRetakeEvent extends _LivelinessEvent {}

class _OnCameraReadyEvent extends _LivelinessEvent {
  _OnCameraReadyEvent(this.controller, this.faceAnalyserData);
  final OnCameraController controller;
  final FaceAnalyserData faceAnalyserData;
}

class _SwitchCameraLensEvent extends _LivelinessEvent {}
