part of './../../on_process_camera.dart';

class _CornerPainter extends CustomPainter {
  _CornerPainter(this.context, this.cornerArt);
  final BuildContext context;
  final CornerArt cornerArt;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Paint paint = Paint()
      ..color = cornerArt.color ?? Theme.of(context).colorScheme.primary
      ..strokeWidth = cornerArt.strokeWidth
      ..style = PaintingStyle
          .stroke // Use stroke for the border effect
      ..strokeCap = StrokeCap
          .round // Round the ends of the strokes
      ..strokeJoin = StrokeJoin.round;

    final ui.Path path = Path();

    // Start drawing from the top-left corner (0,0) and move right.
    path.moveTo(
      cornerArt.strokeWidth / 2,
      cornerArt._cornerSize - cornerArt.strokeWidth / 2,
    );
    // Draw a line up.
    path.lineTo(
      cornerArt.strokeWidth / 2,
      cornerArt._radius + cornerArt.strokeWidth / 2,
    );
    // Draw a rounded corner using arcToPoint
    path.arcToPoint(
      Offset(
        cornerArt._radius + cornerArt.strokeWidth / 2,
        cornerArt.strokeWidth / 2,
      ),
      radius: Radius.circular(cornerArt._radius),
    );
    // Draw a line to the right.
    path.lineTo(
      cornerArt._cornerSize - cornerArt.strokeWidth / 2,
      cornerArt.strokeWidth / 2,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
