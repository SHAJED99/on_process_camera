# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`on_process_camera` is a local Flutter package (`publish_to: none`) that wraps `camera` + Google ML Kit face detection into one widget, `OnCamera`, driven by an `OnCameraController`. It provides live preview, photo capture cropped to the visible preview, video recording, lens switching, zoom/focus, a per-frame face "liveliness" analyser, and a native crop/rotate helper.

Its only real consumer is the parent SDK (`../../`, `prime_mo_sdk`, see `../../CLAUDE.md`): the eKYC liveness screen (`lib/features/ekyc/liveliness/`), the NID photo screen (`lib/core/widgets/screen_take_photo.dart`) and `OnCamera.imageCropNRotate` in the MEF file picker. Changes here affect the onboarding journey directly — check those call sites before changing behaviour.

## Commands

Flutter is pinned by the SDK's `.fvmrc` (`../../.fvmrc`, 3.38.3); prefer `fvm flutter …`.

```bash
fvm flutter pub get
fvm flutter analyze lib test       # strict lints: always_specify_types, require_trailing_commas, 80 cols, strict-casts…
fvm dart format lib test
fvm flutter test                   # unit tests for the geometry (test/on_process_camera_test.dart)
fvm flutter test --plain-name "debugWindowRect"   # a single group/test
cd example && fvm flutter run      # device test bench (camera + ML Kit need hardware)
```

If `flutter test`/`analyze` fails inside the Flutter SDK itself (e.g. `dart:ui` types not found), `.dart_tool/package_config.json` was resolved by a different Flutter version — run `fvm flutter pub get` in that directory.

Unit tests reach library-private geometry through `@visibleForTesting` wrappers in `lib/src/utils/testing_hooks.dart` (`debugWindowRect`, `debugInputImageRotation`, `debugCameraShowingSize`). Camera, permission, lifecycle and ML Kit behaviour can only be verified on a device via the example app.

Source files use CRLF line endings; keep them when editing.

## Architecture

### One library built from `part` files

`lib/on_process_camera.dart` holds **all** imports and `part`s every file under `lib/src/`; each file starts with `part of`. Consequences:
- New files must be added as a `part` in `on_process_camera.dart`, and new imports go there, not in the part file.
- Underscore-private members are visible across all files, which is how the internals talk to each other (`_ScreenController`, `CameraLense._lense`, `Resolution._resolution`, `FocusPoint._focusMode`).
- Nothing from `camera` is re-exported, so consumers get types like `XFile` only by inference.

### Controller ↔ widget binding

`OnCameraController` (`src/models/on_camera_controller.dart`) is a config object plus a set of `late` private function fields (`_takePhoto`, `_startVideo`, `_switchCameraLense`, `_startAnalyser`, …) exposed through public getters. `_OnCameraState._bindController` (`src/screens/camera_wrapper.dart`) points them at methods on an internal `_ScreenController`; it runs in `initState` and again in `didUpdateWidget` when a different controller is passed (which re-opens the camera with the new config). So:
- Calling a controller method before its `OnCamera` has mounted throws `LateInitializationError`.
- One controller belongs to one `OnCamera`; the newest binder takes it over (`_owner`, debug warning).
- To add a capability: add the `late` field + getter on `OnCameraController`, implement it on `_ScreenController`, bind it in `_bindController`.
- Error contract: `takePhoto` returns null on any failure (never throws); `startVideo` throws; `stopVideo` returns null on failure.

### One camera per process (`src/controllers/screen_controller_model.dart`)

On Android the CameraX plugin calls `unbindAll()` in both `createCamera` and `dispose`, so opening or disposing **any** camera kills every other one. The design follows from that:
- All `_ScreenController`s share one static operation queue (`_enqueue`) — every open (`init`), release and `close` runs serialised app-wide. Don't call `init()` from inside a queued operation (deadlock); call `_init()` directly there.
- `_init` releases whichever other instance holds the camera (`_releaseOtherCameras` → `_release`) before opening its own. A released instance is `_isSuspended` and shows the loading widget.
- Visibility drives suspend/resume: `TickerMode.of(context)` (false while another route fully covers this one) and `AppLifecycleListener` `onPause`/`onResume` feed `updateVisibility`. Hidden → release; visible again and suspended → re-open. `close()` also hands the camera back to the newest visible suspended instance.
- `init()` without an orientation asks permissions and lists cameras; `init(orientation: …)` (from the `native_device_orientation` listener) only re-creates the camera, and is deferred while recording (`_pendingOrientation`, applied in `_stopVideo`).
- Every re-open first `dispose()`s: stops the image stream, closes the analyser's `FaceDetector` (native side recreates it on next use), disposes the camera. `dispose(isSoft: true)` stops only stream/detector — that is `stopAnalyser`. `_streamGeneration` is bumped on every dispose/stream start so frames from a stopped stream are dropped.
- Permissions: camera is required. Microphone is requested only when `OnCameraController.enableAudio` is true, asked once per controller (then only `status` is read, no dialog), and if denied the camera opens with audio off. Camera permission UI goes through `input.onPermission` if given, else the default English dialog in `src/utils/functions/get_permission.dart`.
- Status reaches the host via `onStatusChanged(CameraStatus)`; the SDK starts liveness only on `ready`, and `ready` fires again after every re-open. `_WrapperChild` checks the error view (tap = `init()` retry) before loading — keep that order, a failed init never has an initialized camera.

### Face-analysis pipeline

`_startFaceDetection` → `startImageStream` → per frame (dropped while `isDetecting`, reset in `finally`):
1. `CameraImage.toInputImage` (`camera_image_conversion.dart`): Android streams `nv21`, iOS streams single-plane `bgra8888` passed to ML Kit as-is.
2. Rotation from `NativeDeviceOrientation._inputImageRotation(cameraDescription)` using the sensor orientation (ML Kit's documented formula; iOS uses the raw sensor value).
3. `_detectLiveliness` (`detect_faces.dart`) fills a `LivelinessModel`: face count, bounding box vs. the visible "window" rect, small/big face (area ratio vs. window), eyes/smile probabilities, head Euler angles against `FaceAnalyserData` thresholds. Flags are only set when exactly one face is found and the preview has been laid out.
4. `_passDataToParent` delivers the frame if it's the first, if `statusCheckDelay` has passed, or if the status changed (`LivelinessModel.==` compares face count + flags only). It sets brightness, calls `faceAnalyser.onLiveliness` and the `startAnalyser` callback, then re-points focus/exposure only when the face centre moved (>5%).

Recording start: the plugin attaches the video stream only when recording starts (and detaches image analysis), which rebuilds the camera session, and the camera switches to its fixed-rate video mode (e.g. `[15,30]` -> `[30,30]` fps, video 3A tuning) — that is what shifted brightness. `OnCameraController.fps` fixes the rate from the start (camera_android_camerax >=0.6.25 applies it to preview, analysis and video); `_holdExposureForRecording` locks focus and re-sets the exposure point so the plugin doesn't auto-cancel it (~5 s) during the recording. Not fixable from here: in video mode the Pixel HAL also reserves a stabilization crop (`crop_margin = 0.075`), so the field of view narrows when recording starts; the plugins expose no stabilization or stream-use-case control.

SDK coupling: the liveness bloc needs 3+ consecutive still frames, so the SDK passes `statusCheckDelay: Duration.zero` (every frame). Android brightness averages every 10th byte of the whole NV21 buffer (chroma included); the SDK's `brightness < 0.4` threshold is tuned to that — don't change the formula without retuning it.

### Coordinate spaces and sizing

- `previewSize` = the `LayoutBuilder` constraints of `OnCamera`, which must be bounded (asserted; e.g. `AspectRatio`). The camera preview is cover-fitted into it via `OverflowBox` (`_getCameraShowingSize`, `camera_calculation.dart`).
- `calculatedOrientationCameraSize` = the plugin's (landscape) preview size swapped for portrait (`size_calculation.dart`); face boxes and the window rect live in this space.
- `_getWindowRect` picks the cover-fit axis by comparing preview and camera aspect ratios. The SDK clips its square preview to a circle, which the rectangular window doesn't account for.
- `takePhoto(doCropped: true)` centre-crops the captured JPEG to the preview aspect ratio (`crop_image_to_window.dart`); front-camera photos are mirrored when `frontFlip` is true (default). The plugin's temp capture file is always deleted.

### Utilities

`_devPrint` (`src/utils/dev_functions/_dev_print.dart`) is the only logging — coloured, debug-mode only. `_Tuple2` is the internal pair type.

## Example app (`example/`)

`example/lib/main.dart` is a device test bench with one screen per feature group: photo capture (crop toggle, lens, pause/resume, focus, zoom, crop & rotate), liveness + video (square preview and every-frame delivery like the SDK; live `LivelinessModel` readout, frames/s with stall warning, auto/manual selfie, recording), camera lifecycle (replace / stack camera screens, background/return), and a cache report that scans the whole app data folder for leftover captures. Platform setup it relies on: `UCropActivity` in the Android manifest (required by `image_cropper`); camera/microphone usage strings in `Info.plist`; and a Podfile with iOS 15.5 (ML Kit minimum) plus `permission_handler`'s `PERMISSION_CAMERA=1` / `PERMISSION_MICROPHONE=1` — without those macros iOS reports camera permission as permanently denied. The host app (`../../app/assisted_onboarding/ios`) has the same Podfile macros and usage strings.
