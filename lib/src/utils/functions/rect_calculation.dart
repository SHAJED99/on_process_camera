part of './../../../on_process_camera.dart';

extension RectExtension on ui.Rect {
  double getSizePercentage(ui.Rect rect) {
    double area1 = width * height;
    double area2 = rect.width * rect.height;

    if (area1 == 0 || area2 == 0) return 0.0; // Avoid division by zero
    return area2 / area1;
  }
}
