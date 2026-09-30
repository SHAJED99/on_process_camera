import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:on_process_camera/on_process_camera.dart';

// Portrait camera image (a 1920x1080 sensor frame rotated upright)
const Size _portraitImage = Size(1080, 1920);

void main() {
  group('debugWindowRect', () {
    test('square preview shows the full width, centred vertically', () {
      final Rect rect = debugWindowRect(const Size(300, 300), _portraitImage);
      expect(rect.left, closeTo(0, 2));
      expect(rect.width, closeTo(1080, 2));
      expect(rect.height, closeTo(1080, 2));
      expect(rect.center.dy, closeTo(960, 2));
    });

    test('preview taller than the camera shows the full height', () {
      // 0.46 is narrower than the camera's 0.5625
      final Rect rect = debugWindowRect(const Size(390, 844), _portraitImage);
      expect(rect.top, closeTo(0, 2));
      expect(rect.height, closeTo(1920, 2));
      expect(rect.width, closeTo(390 / 844 * 1920, 2));
    });

    test('3:4 preview stays inside the image (between camera ratio and 1)', () {
      final Rect rect = debugWindowRect(const Size(300, 400), _portraitImage);
      expect(rect.width, closeTo(1080, 2));
      expect(rect.height, closeTo(1440, 2));
      expect(rect.right, lessThanOrEqualTo(1080));
      expect(rect.bottom, lessThanOrEqualTo(1920));
    });

    test('empty sizes give an empty window', () {
      expect(debugWindowRect(Size.zero, _portraitImage), Rect.zero);
      expect(debugWindowRect(const Size(300, 300), Size.zero), Rect.zero);
    });
  });

  group('debugInputImageRotation (Android formula)', () {
    const CameraDescription front = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );
    const CameraDescription back = CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );

    // The table the package hardcoded before, for standard sensors
    final Map<NativeDeviceOrientation, List<InputImageRotation>> expected =
        <NativeDeviceOrientation, List<InputImageRotation>>{
          NativeDeviceOrientation.portraitUp: <InputImageRotation>[
            InputImageRotation.rotation270deg,
            InputImageRotation.rotation90deg,
          ],
          NativeDeviceOrientation.portraitDown: <InputImageRotation>[
            InputImageRotation.rotation90deg,
            InputImageRotation.rotation270deg,
          ],
          NativeDeviceOrientation.landscapeLeft: <InputImageRotation>[
            InputImageRotation.rotation0deg,
            InputImageRotation.rotation0deg,
          ],
          NativeDeviceOrientation.landscapeRight: <InputImageRotation>[
            InputImageRotation.rotation180deg,
            InputImageRotation.rotation180deg,
          ],
        };

    expected.forEach((
      NativeDeviceOrientation orientation,
      List<InputImageRotation> rotations,
    ) {
      test('${orientation.name} matches the standard-sensor table', () {
        expect(debugInputImageRotation(orientation, front), rotations[0]);
        expect(debugInputImageRotation(orientation, back), rotations[1]);
      });
    });

    test('uses the actual sensor orientation', () {
      const CameraDescription flipped = CameraDescription(
        name: 'back-270',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 270,
      );
      expect(
        debugInputImageRotation(NativeDeviceOrientation.portraitUp, flipped),
        InputImageRotation.rotation270deg,
      );
    });
  });

  group('debugCameraShowingSize', () {
    const Size sensor = Size(1920, 1080);

    for (final Size preview in <Size>[
      const Size(300, 300),
      const Size(300, 400),
      const Size(390, 844),
    ]) {
      test('portrait ${preview.width}x${preview.height} is covered', () {
        final Size shown = debugCameraShowingSize(
          preview,
          sensor,
          DeviceOrientation.portraitUp,
        );
        expect(shown.width, greaterThanOrEqualTo(preview.width - 0.01));
        expect(shown.height, greaterThanOrEqualTo(preview.height - 0.01));
        expect(shown.aspectRatio, closeTo(1080 / 1920, 0.001));
      });
    }
  });

  group('Rect.getSizePercentage', () {
    test('ratio of areas', () {
      const Rect window = Rect.fromLTWH(0, 0, 100, 100);
      expect(window.getSizePercentage(const Rect.fromLTWH(0, 0, 50, 50)), 0.25);
    });

    test('empty rects give 0 instead of dividing by zero', () {
      expect(Rect.zero.getSizePercentage(const Rect.fromLTWH(0, 0, 5, 5)), 0);
      expect(const Rect.fromLTWH(0, 0, 5, 5).getSizePercentage(Rect.zero), 0);
    });
  });
}
