# on_process_camera

A Flutter camera widget for Android and iOS. One widget, `OnCamera`, driven by an `OnCameraController`, gives you:

- a live preview, cover-fitted into whatever size you give it;
- photo capture, optionally cropped to exactly what the preview shows;
- video recording, with an optional fixed frame rate;
- lens switching, zoom, focus mode, and pausing/resuming the preview;
- a per-frame face liveness analyser built on Google ML Kit (face count, position inside the preview, face size, eyes open, smile, head angles, brightness);
- a native crop & rotate screen (`OnCamera.imageCropNRotate`).

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

### Face analysis

Pass `faceAnalyser: FaceAnalyserData(...)` to the controller, then start the analyser:

```dart
controller.startAnalyser(
  (LivelinessModel data, InputImageModel image) async {
    // data: face count, inside-frame / size flags, eyes, smile, head angles
  },
);
```

`stopAnalyser()` stops it again.

### Error handling

- `takePhoto` returns `null` on any failure (it never throws).
- `startVideo` throws when recording can't start.
- `stopVideo` returns `null` on failure.

### Camera lifecycle

Only one camera can be open per app on Android, so only one `OnCamera` holds the camera at a time. When a route covers it or the app goes to the background, it releases the camera, and it re-opens the camera when it becomes visible again. `onStatusChanged` reports `CameraStatus.ready` again after every re-open.

## Platform setup

Only Android and iOS are supported (Google ML Kit is mobile-only).

### Android

- Declare `com.yalantis.ucrop.UCropActivity` in the app manifest if you use `OnCamera.imageCropNRotate`:

  ```xml
  <activity
      android:name="com.yalantis.ucrop.UCropActivity"
      android:screenOrientation="portrait"
      android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
  ```

- The camera and microphone permissions come from the camera plugin.

### iOS

- Minimum iOS version 15.5 (required by ML Kit).
- Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist`.
- Enable the `permission_handler` macros in the Podfile `post_install`. Without them, iOS reports the camera permission as permanently denied:

  ```ruby
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          'PERMISSION_CAMERA=1',
          'PERMISSION_MICROPHONE=1',
        ]
      end
    end
  end
  ```

## Example

`example/` is a test bench app with one screen per feature group: photo capture, liveness and video recording, and camera lifecycle. Camera and ML Kit need real hardware, so run it on a device.

## License

MIT
