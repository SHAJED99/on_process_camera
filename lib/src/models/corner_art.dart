part of './../../on_process_camera.dart';

/// A data class to hold the properties for a corner art widget.
class CornerArt {
  /// CornerArt({required this.color, required this.cornerSize, required
  /// this.strokeWidth, required this.radius})
  CornerArt({
    this.color,
    this.cornerSize = 0,
    this.strokeWidth = 0,
    required this.radius,
  });

  /// The color of the corner art stroke.
  /// Default: Theme.of(context).colorScheme.primary
  final Color? color;

  /// The size of the corner art, defining the length of each arm of the
  /// L-shape.
  final double cornerSize;
  double get _cornerSize {
    if (radius != double.infinity) return cornerSize;

    final double min = _size.shortestSide;
    return min / 2;
  }

  /// The width of the stroke used to draw the corner art.
  final double strokeWidth;

  /// The radius of the corner
  final double radius;
  double get _radius {
    if (radius != double.infinity) return radius;

    final double min = _size.shortestSide;
    return min / 2;
  }

  Size _size = const Size(0, 0);
}
