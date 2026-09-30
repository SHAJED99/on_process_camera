part of './../../on_process_camera.dart';

class _CornerOverlay extends StatelessWidget {
  const _CornerOverlay({
    required this.width,
    required this.height,
    required this.cornerArt,
  });
  final double width, height;
  final CornerArt cornerArt;

  @override
  Widget build(BuildContext context) {
    final CustomPaint customPaint = CustomPaint(
      painter: _CornerPainter(context, cornerArt),
    );
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        maxWidth: width + cornerArt.strokeWidth,
        maxHeight: height + cornerArt.strokeWidth,
        child: cornerArt.strokeWidth == 0
            ? null
            : Stack(
                children: <Widget>[
                  //! ------------------------------------------------- Top Left
                  Positioned(top: 0, left: 0, child: customPaint),

                  //! ------------------------------------------------ Top Right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Transform.rotate(
                      angle: math.pi / 2,
                      child: customPaint,
                    ),
                  ),

                  //! ---------------------------------------------- Bottom Left
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Transform.rotate(
                      angle: -math.pi / 2,
                      child: customPaint,
                    ),
                  ),

                  //! --------------------------------------------- Bottom Right
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Transform.rotate(angle: math.pi, child: customPaint),
                  ),
                ],
              ),
      ),
    );
  }
}
