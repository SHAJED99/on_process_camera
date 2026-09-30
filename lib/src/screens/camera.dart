part of '../../on_process_camera.dart';

class _Camera extends StatelessWidget {
  const _Camera(this.controller);
  final _ScreenController controller;

  @override
  Widget build(BuildContext context) {
    final CameraController camera = controller.cameraController!;
    final Size cameraSize = controller.cameraSize;

    Widget widget = CameraPreview(camera);

    controller.fullWindowSize = _getCameraShowingSize(
      previewSize: controller.previewSize,
      cameraSize: cameraSize,
      orientation: controller._orientation._deviceOrientation,
      onCalculatedOrientationCameraSize: (Size size) {
        controller.calculatedOrientationCameraSize = size;
      },
    );

    // It will show the camera preview in full screen
    return Container(
      height: controller.previewSize.height,
      width: controller.previewSize.width,
      decoration: const BoxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        maxWidth: controller.fullWindowSize.width,
        maxHeight: controller.fullWindowSize.height,
        child: widget,
      ),
    );
  }
}
