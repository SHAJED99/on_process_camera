# on_process_camera

A camera widget for the onboarding SDK. It shows a live preview and supports:

- photo capture, optionally cropped to exactly what the preview shows;
- video recording;
- lens switching, zoom, focus mode, and pausing/resuming the preview;
- a per-frame face "liveliness" analyser built on Google ML Kit;
- a native crop & rotate screen.

It is an internal package, used through a path dependency. It is not published.

## Usage

```dart
final OnCameraController controller = OnCameraController(
  cameraLense: CameraLense.front,
  enableAudio: false, // photo only: never asks for the microphone
  onStatusChanged: (CameraStatus status) {},
);

// Give it a bounded size, e.g. AspectRatio or SizedBox
AspectRatio(
  aspectRatio: 3 / 4,
  child: OnCamera(controller: controller),
);

final Uint8List? photo = await controller.takePhoto(); // null if it failed
```

Create the controller once, for example in `initState`, and give it to exactly one `OnCamera`. Its functions start working once that `OnCamera` has mounted.

For face analysis, pass `faceAnalyser: FaceAnalyserData(...)`, then call `controller.startAnalyser((LivelinessModel data, InputImageModel image) async {...})`.

## Platform setup

- **Android:** declare `com.yalantis.ucrop.UCropActivity` in the app manifest if you use `OnCamera.imageCropNRotate`. The camera and microphone permissions come from the camera plugin.
- **iOS:**
  - Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist`.
  - In the Podfile `post_install`, enable `PERMISSION_CAMERA=1` and `PERMISSION_MICROPHONE=1` for `permission_handler`.

## Development

See `CLAUDE.md` for the architecture. `example/` is a test bench app to run on a real device.
