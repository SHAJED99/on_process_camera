## 0.1.1

- Raised the `camera` lower bound to 0.11.3, the first version with `enablePersistentRecording`.
- Kept `package:flutter/material.dart` so the package still works on Flutter <3.47.

## 0.1.0

First public release.

- `OnCamera` widget with `OnCameraController`: live preview, lens switching, zoom, focus mode, pause/resume.
- Photo capture, optionally cropped to the visible preview. Front-camera photos are mirrored by default (`frontFlip`). `takePhoto` returns null instead of throwing, and temporary capture files are deleted.
- Video recording. `startVideo` throws when recording can't start. Rotating the device during a recording doesn't end it.
- `fps` option to fix the frame rate from the start, so brightness doesn't jump when recording begins (Android needs camera_android_camerax >=0.6.25). The face exposure point is held for the whole recording.
- `enableAudio` option (on by default). The microphone is optional: it's asked for once, and without it video records with no audio.
- Face liveness analyser on Google ML Kit: face count, inside-frame and face size flags, eyes, smile, head angles and brightness. Frames are delivered when the face status changes, or every `statusCheckDelay`.
- One camera per app: a covered route or a backgrounded app releases the camera, and it re-opens when visible again.
- Error view (tap to retry) when the camera fails to open.
- `OnCamera.imageCropNRotate` native crop & rotate screen.
