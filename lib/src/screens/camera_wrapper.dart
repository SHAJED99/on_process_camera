part of '../../on_process_camera.dart';

class OnCamera extends StatefulWidget {
  /// A reusable camera widget that renders a live camera preview and exposes
  /// programmatic controls via an [OnCameraController].
  ///
  /// The widget handles permission requests, device orientation changes and
  /// initialization of the underlying camera. Use the optional [controller]
  /// to perform actions such as taking a photo, starting/stopping a video
  /// recording, switching camera lens, or starting/stopping analyzers.
  const OnCamera({
    super.key,
    this.controller,
    this.iconSize = 36,
    this.onLoadingWidget,
    this.onErrorLoadingBuilder,
    this.cornerArt,
  });

  /// Preferred logical size (width/height constraint) for icons shown inside
  /// the camera UI (used by placeholder/error widgets).
  final double iconSize;

  /// Widget displayed while the camera is initializing or unavailable.
  /// If null, a default circular progress indicator is shown.
  final Widget? onLoadingWidget;

  /// Builder invoked when the camera fails to initialize or an error occurs.
  /// Receives an [ErrorStatus] and must return a widget to display.
  final Widget Function(ErrorStatus error)? onErrorLoadingBuilder;

  /// Optional external controller. When provided, this controller is used to
  /// expose camera operations to callers outside the widget tree. If omitted,
  /// the widget creates and uses an internal [OnCameraController].
  final OnCameraController? controller;

  /// Optional corner artwork configuration. When provided the widget draws
  /// decorative corners / rounded clipping according to the settings.
  final CornerArt? cornerArt;

  /// Crop and rotate an image using the platform cropper UI provided by the
  /// `image_cropper` plugin.
  ///
  /// This is a thin helper that opens the native crop UI and returns a new
  /// File pointing to the cropped image when the user confirms. If the user
  /// cancels the operation `null` is returned.
  ///
  /// Parameters:
  /// - [path]: absolute path to the source image file (required).
  /// - [toolbarTitle]: title shown on the cropper toolbar (Android / iOS).
  /// - [toolbarColor]: toolbar background color on Android.
  /// - [toolbarWidgetColor]: toolbar widget (icons/text) color on Android.
  /// - [aspectRatio]: optional fixed aspect ratio. When provided a custom
  ///   aspect-ratio preset is computed and passed to the native UI.
  ///
  /// Returns:
  /// - A `Future<File?>` that completes with the cropped image file or `null`
  ///   if cropping was cancelled.
  ///
  /// Throws:
  /// - Any exceptions thrown by `ImageCropper().cropImage` are forwarded to the
  ///   caller (not caught here).
  ///
  /// Example:
  /// ```dart
  /// final File? cropped = await _imageCropNRotate(
  ///   '/storage/emulated/0/DCIM/Camera/img.jpg',
  ///   toolbarTitle: 'Adjust photo',
  ///   toolbarColor: Colors.black,
  ///   aspectRatio: 4 / 3,
  /// );
  /// if (cropped != null) {
  ///   // use cropped.path
  /// }
  /// ```
  ///
  /// Android (UCrop) setup:
  /// If your native cropper implementation requires UCrop, declare this
  /// activity inside the AndroidManifest.xml `<application>` block:
  /// ```xml
  /// <activity
  ///   android:name="com.yalantis.ucrop.UCropActivity"
  ///   android:screenOrientation="portrait"
  ///   android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
  /// ```
  ///
  static Future<File?> imageCropNRotate(
    String path, {
    String toolbarTitle = 'Cropper',
    Color toolbarColor = Colors.black,
    Color toolbarWidgetColor = Colors.white,
    double? aspectRatio,
  }) async => _imageCropNRotate(
    path,
    toolbarTitle: toolbarTitle,
    toolbarColor: toolbarColor,
    toolbarWidgetColor: toolbarWidgetColor,
    aspectRatio: aspectRatio,
  );

  @override
  State<OnCamera> createState() => _OnCameraState();
}

class _OnCameraState extends State<OnCamera> {
  late final _ScreenController controller;
  StreamSubscription<NativeDeviceOrientation>? orientationSubscription;
  late final AppLifecycleListener _lifecycleListener;

  //! ---------------------------------------------------- Initialize Controller
  @override
  void initState() {
    super.initState();
    controller = _ScreenController(
      input: widget.controller ?? OnCameraController(),
      context: context,
      updateScreen: () {
        if (mounted) setState(() {});
      },
    );
    _bindController(controller.input);
    _orientationListener();

    // The camera plugin leaves background handling to the app: release the
    // camera when backgrounded and re-open it on return
    _lifecycleListener = AppLifecycleListener(
      onPause: () => controller.updateVisibility(isAppActive: false),
      onResume: () => controller.updateVisibility(isAppActive: true),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.init();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tickers are disabled while another route fully covers this one
    controller.updateVisibility(isRouteActive: TickerMode.of(context));
  }

  //! ------------------------------------------------ Swap external controller
  @override
  void didUpdateWidget(covariant OnCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    final OnCameraController? next = widget.controller;
    if (next == null || identical(next, controller.input)) return;

    // New config (lens, resolution, analyser…): bind it and re-open
    if (identical(controller.input._owner, this)) {
      controller.input._owner = null;
    }
    controller
      ..input = next
      .._cameraLense = next.cameraLense
      ..focusPoint = next.focusMode
      ..isAnalyzing = false
      .._onLivelinessCallback = null;
    _bindController(next);
    controller.init();
  }

  //! ------------------------------------------------------- Bind controller
  /// Points the controller's public functions at this widget's camera.
  void _bindController(OnCameraController input) {
    final Object? owner = input._owner;
    if (owner is State && owner.mounted && !identical(owner, this)) {
      _devPrint(
        'OnCameraController is already used by another OnCamera; '
        'the newest one takes it over',
        color: _DevPrintColorEnum.yellow,
      );
    }
    input._owner = this;

    input._takePhoto = controller._takePhoto;
    input._pauseCameraView = () async =>
        controller.cameraController?.pausePreview();
    input._resumeCameraView = () async =>
        controller.cameraController?.resumePreview();
    input._startVideo = controller._startVideo;
    input._stopVideo = controller._stopVideo;
    input._zoomLocation = controller._zoomToLocation;
    input._setFocusMode = (FocusPoint mode) async {
      await controller._setFocusMode(mode: mode);
    };
    // Queued like any init, so a switch requested mid-init isn't dropped
    input._switchCameraLense = (CameraLense cameraLense) async {
      if (cameraLense == controller._cameraLense) return; // No need to switch

      controller._cameraLense = cameraLense;
      await controller.init();
    };
    input._startAnalyser =
        (
          Future<void> Function(LivelinessModel data, InputImageModel image)
          onLiveliness,
        ) async {
          controller._onLivelinessCallback = onLiveliness;

          await controller._setFocusMode();

          controller._startFaceDetection();
        };
    input._stopAnalyser = controller._stopAnalyser;
  }

  //! ----------------------------------------------- Orientation Listener Setup
  void _orientationListener() {
    // Add Orientation Listener
    orientationSubscription = NativeDeviceOrientationCommunicator()
        .onOrientationChanged()
        .listen((NativeDeviceOrientation orientation) async {
          await controller.init(orientation: orientation);
        });
  }

  //! ----------------------------------------------------------------- Disposed
  @override
  void dispose() {
    // Stop orientation events first so they can't re-open the camera
    orientationSubscription?.cancel();
    _lifecycleListener.dispose();
    if (identical(controller.input._owner, this)) {
      controller.input._owner = null;
    }
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    controller.context = context;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        controller.context = context;
        assert(
          box.hasBoundedWidth && box.hasBoundedHeight,
          'OnCamera needs a bounded width and height, e.g. wrap it in a '
          'SizedBox or AspectRatio.',
        );
        // Release fallback for an unbounded axis: the screen size
        final Size screen = MediaQuery.sizeOf(context);
        final Size previewSize = Size(
          box.hasBoundedWidth ? box.maxWidth : screen.width,
          box.hasBoundedHeight ? box.maxHeight : screen.height,
        );
        controller.previewSize = previewSize;
        if (widget.cornerArt != null) widget.cornerArt!._size = previewSize;

        return Stack(
          children: <Widget>[
            //! ---------------------------------------------------- Camera View
            Material(
              elevation: 0,
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(
                widget.cornerArt?._radius ?? 0,
              ),
              child: _WrapperChild(
                widget.iconSize,
                controller,
                widget.onLoadingWidget,
                widget.onErrorLoadingBuilder,
              ),
            ),

            //! ----------------------------------------------------- Corner Art
            if (widget.cornerArt != null)
              _CornerOverlay(
                width: controller.previewSize.width,
                height: controller.previewSize.height,
                cornerArt: widget.cornerArt!,
              ),
          ],
        );
      },
    );
  }
}

class _WrapperChild extends StatelessWidget {
  const _WrapperChild(
    this.iconSize,
    this.controller,
    this.onLoadingWidget,
    this.onErrorLoadingBuilder,
  );

  final double iconSize;
  final _ScreenController controller;
  final Widget? onLoadingWidget;
  final Widget Function(ErrorStatus error)? onErrorLoadingBuilder;

  Widget placeHolder(Widget child) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxHeight: iconSize, maxWidth: iconSize),
        width: double.infinity,
        height: double.infinity,
        child: FittedBox(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    //! --------------------------------------------------------------- On Error
    // Checked before loading: a failed init never has an initialized camera
    if (controller.isInit && controller.errorStatus != null) {
      Widget? errorWidget;
      if (onErrorLoadingBuilder != null) {
        errorWidget = onErrorLoadingBuilder!(controller.errorStatus!);
      }

      return InkWell(
        onTap: () async => await controller.init(),
        child:
            errorWidget ??
            placeHolder(Icon(Icons.error_rounded, color: colorScheme.error)),
      );
    }

    //! ------------------------------------------------------------- On Loading
    if (!controller.isInit || !controller.isCameraInitialized) {
      return onLoadingWidget ??
          placeHolder(
            CircularProgressIndicator(
              color: colorScheme.primary,
              strokeAlign: -1,
            ),
          );
    }

    //! -------------------------------------------------------------- On Camera
    // return const SizedBox();
    return _Camera(controller);
  }
}
