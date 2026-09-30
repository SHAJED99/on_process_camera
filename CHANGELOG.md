## Unreleased

- New `fps` option (needs camera_android_camerax >=0.6.25). Recording always runs at a fixed frame rate (e.g. 15-30 fps preview -> 30 fps recording), which changed brightness when video started; fixing the rate from the start avoids that. The SDK liveness step uses `fps: 30`.
- The face exposure point is held for the whole recording (focus locked while recording, restored after), instead of expiring after ~5 s.
- The camera is now owned app-wide. On Android there is one camera per process, so only one `OnCamera` holds it at a time. A covered route or a backgrounded app releases the camera, and it re-opens when visible again.
- `takePhoto` returns null instead of throwing, and can be called before the first preview frame.
- `startVideo` throws when recording can't start.
- New `enableAudio` option (on by default). The microphone is optional: it's asked for once, and without it video records with no audio.
- iOS frames are passed to ML Kit as BGRA. Frame rotation comes from the camera's sensor orientation.
- Fixed the analyser stalling for good after one failed frame. Frames from a stopped stream are now dropped.
- Frames are delivered when the face status changes, or every `statusCheckDelay`. `LivelinessModel.==` compares the status flags.
- Fixed the "inside frame" window for previews whose aspect ratio falls between the camera's ratio and 1.
- Focus and exposure are only re-pointed when the face moves.
- The error view (tap to retry) is shown when the camera fails to open.
- `OnCamera` now handles a new `controller` passed on rebuild.
- Rotating the device during a recording no longer ends the recording.
- Captured photo files are deleted from the cache.

## 0.0.1

- Initial internal version.
