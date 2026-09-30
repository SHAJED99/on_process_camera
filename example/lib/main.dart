// Test bench for on_process_camera: one screen per feature group.
//
// - Photo capture: cropped / full photo, lens switch, zoom, focus mode,
//   pause/resume, crop & rotate, custom loading/error widgets.
// - Liveness + video: live face-analyser readout, frames/sec with a stall
//   warning, auto/manual selfie capture, video recording.
// - Camera lifecycle: replace / stack camera screens.
// - Cache report: leftover capture files in the temp directory.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_process_camera/on_process_camera.dart';

import 'liveness_flow.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnCamera test bench',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

//! ======================================================================= Home
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OnCamera test bench')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _FeatureTile(
            icon: Icons.photo_camera_outlined,
            title: 'Photo capture',
            subtitle:
                'Cropped / full photo, switch lens, zoom, focus mode, '
                'pause/resume, crop & rotate. Never asks for the microphone.',
            onTap: () => _push(context, const PhotoScreen()),
          ),
          _FeatureTile(
            icon: Icons.face_retouching_natural,
            title: 'Liveness + video',
            subtitle:
                'Face analyser readout, frames/sec with stall warning, '
                'auto / manual selfie, video recording, lens switch.',
            onTap: () => _push(context, const LivenessScreen()),
          ),
          _FeatureTile(
            icon: Icons.verified_user_outlined,
            title: 'SDK liveness flow',
            subtitle:
                'Same flow as the SDK eKYC liveness step: guidance messages, '
                'auto-zoom, still-face selfie, 5 s video, retake / next.',
            onTap: () => _push(context, const LivenessFlowScreen()),
          ),
          _FeatureTile(
            icon: Icons.layers_outlined,
            title: 'Camera lifecycle',
            subtitle:
                'Replace or stack camera screens and check each preview '
                'keeps working.',
            onTap: () => _push(context, const LifecycleScreen(generation: 1)),
          ),
          _FeatureTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Cache report',
            subtitle:
                'Captured photos must not be left in the temp folder. '
                'Videos are the caller\'s to delete.',
            onTap: () => _showCacheReport(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Tip: rotate the device on any camera screen to test the '
            'orientation re-initialisation. Deny camera permission once to '
            'see the error view and tap it to retry.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

//! ============================================================ Shared helpers
/// Status log, toasts and a timed action runner shared by the test screens.
mixin _BenchState<T extends StatefulWidget> on State<T> {
  final List<String> statusLog = <String>[];
  bool isReady = false;
  bool isBusy = false;

  /// Called when the camera starts (re-)opening, e.g. after rotation or a
  /// lens switch: the new camera starts unpaused at zoom ×1.
  void onCameraReopening() {}

  void onStatus(CameraStatus status) {
    if (!mounted) return;
    setState(() {
      if (status == CameraStatus.initializing) onCameraReopening();
      isReady = status == CameraStatus.ready;
      statusLog.insert(0, '${_clock()}  ${status.name}');
      if (statusLog.length > 6) statusLog.removeLast();
    });
  }

  void toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  /// Runs [action], reporting its duration or error. Ignores taps while busy.
  Future<void> run(String label, Future<void> Function() action) async {
    if (isBusy) return;
    setState(() => isBusy = true);
    final Stopwatch watch = Stopwatch()..start();
    try {
      await action();
      toast('$label · ${watch.elapsedMilliseconds} ms');
    } catch (e) {
      toast('$label failed: $e');
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }
}

String _clock() {
  final DateTime t = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

CameraLense _otherLense(CameraLense lense) =>
    lense == CameraLense.back ? CameraLense.front : CameraLense.back;

/// Camera preview with the package's corner art and custom loading / error
/// widgets (the package wraps the error widget in tap-to-retry).
class _Preview extends StatelessWidget {
  const _Preview({required this.controller, this.aspectRatio = 3 / 4});

  final OnCameraController controller;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: OnCamera(
              controller: controller,
              cornerArt: CornerArt(
                radius: 16,
                cornerSize: 40,
                strokeWidth: 4,
                color: Colors.white,
              ),
              onLoadingWidget: const Center(
                child: Text(
                  'Starting camera…',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              onErrorLoadingBuilder: (ErrorStatus error) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(height: 8),
                    Text(
                      error.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Text(
                      'Tap to retry',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLog extends StatelessWidget {
  const _StatusLog(this.entries);
  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    return Text(
      entries.isEmpty ? 'Status: —' : 'Status:  ${entries.join('   ')}',
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage(this.bytes, this.info);
  final Uint8List bytes;
  final String info;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, height: 240, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        Text(info, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Future<String> _describeImage(Uint8List bytes, String note) async {
  final image = await decodeImageFromList(bytes);
  final String info =
      '${image.width}×${image.height} · ${_kb(bytes.length)}'
      ' · $note';
  image.dispose();
  return info;
}

//! ============================================================== Photo screen
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen>
    with _BenchState<PhotoScreen> {
  late final OnCameraController _controller;
  CameraLense _lense = CameraLense.back;
  bool _doCropped = true;
  bool _paused = false;
  FocusPoint _focus = FocusPoint.auto;
  double _zoom = 1;
  Uint8List? _photo;
  String _photoInfo = '';

  @override
  void onCameraReopening() {
    _paused = false;
    _zoom = 1;
  }

  @override
  void initState() {
    super.initState();
    _controller = OnCameraController(
      cameraLense: _lense,
      resolution: Resolution.high,
      enableAudio: false, // Photo only: the microphone must not be requested
      onStatusChanged: onStatus,
    );
  }

  Future<void> _takePhoto() => run('Photo', () async {
    final Uint8List? bytes = await _controller.takePhoto(doCropped: _doCropped);
    if (bytes == null) throw 'camera not ready';
    final String info = await _describeImage(
      bytes,
      _doCropped ? 'cropped to preview' : 'full frame',
    );
    setState(() {
      _photo = bytes;
      _photoInfo = info;
    });
  });

  Future<void> _switchLense() => run('Switch lens', () async {
    final CameraLense next = _otherLense(_lense);
    await _controller.switchCameraLense(next);
    setState(() {
      _lense = next;
      _zoom = 1;
      _paused = false;
    });
  });

  Future<void> _togglePause() => run(_paused ? 'Resume' : 'Pause', () async {
    _paused
        ? await _controller.resumeCameraView()
        : await _controller.pauseCameraView();
    setState(() => _paused = !_paused);
  });

  Future<void> _setFocus(FocusPoint mode) =>
      run('Focus ${mode.name}', () async {
        await _controller.setFocusMode(mode);
        setState(() => _focus = mode);
      });

  Future<void> _setZoom(double value) =>
      run('Zoom ×${value.toStringAsFixed(1)}', () async {
        await _controller.zoomLocation(value);
      });

  /// Writes the photo to a temp file, opens the native cropper and deletes
  /// both files afterwards so they don't show up in the cache report.
  Future<void> _crop({double? aspectRatio}) => run('Crop', () async {
    final Directory dir = await Directory(
      '${Directory.systemTemp.path}/example_crop',
    ).create(recursive: true);
    final File input = File(
      '${dir.path}/input_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await input.writeAsBytes(_photo!);
    try {
      final File? output = await OnCamera.imageCropNRotate(
        input.path,
        toolbarTitle: 'Crop & rotate',
        aspectRatio: aspectRatio,
      );
      if (output == null) throw 'cancelled';
      final Uint8List bytes = await output.readAsBytes();
      await output.delete();
      final String info = await _describeImage(bytes, 'after crop & rotate');
      setState(() {
        _photo = bytes;
        _photoInfo = info;
      });
    } finally {
      if (await input.exists()) await input.delete();
    }
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = isReady && !isBusy;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo capture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Preview(controller: _controller),
          const SizedBox(height: 8),
          _StatusLog(statusLog),
          _Section('Capture', <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Crop to preview window'),
              subtitle: const Text('takePhoto(doCropped: …)'),
              value: _doCropped,
              onChanged: (bool v) => setState(() => _doCropped = v),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: enabled ? _takePhoto : null,
                  icon: const Icon(Icons.camera),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? _switchLense : null,
                  icon: const Icon(Icons.cameraswitch_outlined),
                  label: Text('Use ${_otherLense(_lense).name}'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? _togglePause : null,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  label: Text(_paused ? 'Resume preview' : 'Pause preview'),
                ),
              ],
            ),
          ]),
          _Section('Focus & zoom', <Widget>[
            SegmentedButton<FocusPoint>(
              segments: const <ButtonSegment<FocusPoint>>[
                ButtonSegment<FocusPoint>(
                  value: FocusPoint.auto,
                  label: Text('Auto focus'),
                ),
                ButtonSegment<FocusPoint>(
                  value: FocusPoint.locked,
                  label: Text('Locked'),
                ),
              ],
              selected: <FocusPoint>{_focus},
              onSelectionChanged: enabled
                  ? (Set<FocusPoint> s) => _setFocus(s.first)
                  : null,
            ),
            Row(
              children: <Widget>[
                Text('Zoom ×${_zoom.toStringAsFixed(1)}'),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 4,
                    divisions: 12,
                    value: _zoom,
                    onChanged: enabled
                        ? (double v) => setState(() => _zoom = v)
                        : null,
                    onChangeEnd: enabled ? _setZoom : null,
                  ),
                ),
              ],
            ),
          ]),
          if (_photo != null)
            _Section('Result', <Widget>[
              _ResultImage(_photo!, _photoInfo),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: isBusy ? null : () => _crop(),
                    child: const Text('Crop & rotate (free)'),
                  ),
                  OutlinedButton(
                    onPressed: isBusy ? null : () => _crop(aspectRatio: 1),
                    child: const Text('Crop 1:1'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _photo = null),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ]),
        ],
      ),
    );
  }
}

//! =========================================================== Liveness screen
class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen>
    with _BenchState<LivenessScreen> {
  late final OnCameraController _controller;
  CameraLense _lense = CameraLense.front;

  // Analyser
  bool _analysing = false;
  bool _autoCapture = true;
  bool _capturing = false;
  LivelinessModel? _last;
  DateTime? _lastFrameAt;
  int _framesThisSecond = 0;
  int _fps = 0;
  Timer? _fpsTimer;

  // Results
  Uint8List? _selfie;
  String _selfieInfo = '';
  bool _recording = false;
  DateTime? _recordingSince;
  String? _videoPath;
  String _videoInfo = '';

  @override
  void initState() {
    super.initState();
    // Same analyser settings as the SDK's liveness screen
    _controller = OnCameraController(
      cameraLense: _lense,
      faceAnalyser: FaceAnalyserData(
        statusCheckDelay: Duration.zero, // Every frame, like the SDK
        bigFacePercentage: 0.5,
        autoFocusOnFace: false,
      ),
      onStatusChanged: onStatus,
    );
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _fps = _framesThisSecond;
        _framesThisSecond = 0;
      });
    });
  }

  @override
  void dispose() {
    _fpsTimer?.cancel();
    super.dispose();
  }

  bool _isGoodFace(LivelinessModel d) =>
      d.faceCount == 1 &&
      d.isFaceInsideFrame &&
      !d.isSmallFace &&
      !d.isBigFace &&
      !d.isEyeClosed;

  Future<void> _onFrame(LivelinessModel data, InputImageModel image) async {
    if (!mounted) return;
    _framesThisSecond++;
    setState(() {
      _last = data;
      _lastFrameAt = DateTime.now();
    });
    if (_autoCapture && !_capturing && _selfie == null && _isGoodFace(data)) {
      unawaited(_captureSelfie('Auto-capture'));
    }
  }

  Future<void> _captureSelfie(String label) async {
    if (_capturing) return;
    _capturing = true;
    try {
      // Same call the SDK makes for the liveness selfie
      final Uint8List? bytes = await _controller.takePhoto(doCropped: false);
      if (bytes == null) throw 'camera not ready';
      final String info = await _describeImage(bytes, label);
      if (!mounted) return;
      setState(() {
        _selfie = bytes;
        _selfieInfo = info;
      });
      toast('$label done');
    } catch (e) {
      toast('$label failed: $e');
    } finally {
      _capturing = false;
    }
  }

  Future<void> _toggleAnalyser() =>
      run(_analysing ? 'Stop analyser' : 'Start analyser', () async {
        if (_analysing) {
          await _controller.stopAnalyser();
        } else {
          _lastFrameAt = DateTime.now();
          _controller.startAnalyser(_onFrame);
        }
        setState(() => _analysing = !_analysing);
      });

  Future<void>
  _toggleVideo() => run(_recording ? 'Stop video' : 'Start video', () async {
    if (!_recording) {
      await _controller.startVideo();
      setState(() {
        _recording = true;
        _recordingSince = DateTime.now();
      });
      return;
    }
    final Duration length = DateTime.now().difference(_recordingSince!);
    setState(() => _recording = false);
    final video = await _controller.stopVideo();
    if (video == null) throw 'no video returned';
    final int size = await File(video.path).length();
    setState(() {
      _videoPath = video.path;
      _videoInfo =
          '${length.inSeconds}s · ${_kb(size)}\n${video.path.split('/').last}';
    });
  });

  Future<void> _deleteVideo() => run('Delete video', () async {
    final File file = File(_videoPath!);
    if (await file.exists()) await file.delete();
    setState(() => _videoPath = null);
  });

  Future<void> _switchLense() => run('Switch lens', () async {
    final CameraLense next = _otherLense(_lense);
    await _controller.switchCameraLense(next);
    setState(() => _lense = next);
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = isReady && !isBusy;
    final LivelinessModel? d = _last;
    final int silentFor = _lastFrameAt == null
        ? 0
        : DateTime.now().difference(_lastFrameAt!).inSeconds;
    final bool stalled = _analysing && !_recording && silentFor >= 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Liveness + video')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Square like the SDK's liveness preview
          _Preview(controller: _controller, aspectRatio: 1),
          const SizedBox(height: 8),
          _StatusLog(statusLog),
          _Section('Controls', <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: enabled ? _toggleAnalyser : null,
                  icon: Icon(_analysing ? Icons.stop : Icons.face),
                  label: Text(_analysing ? 'Stop analyser' : 'Start analyser'),
                ),
                FilledButton.tonalIcon(
                  onPressed: enabled ? _toggleVideo : null,
                  icon: Icon(
                    _recording ? Icons.stop_circle : Icons.fiber_manual_record,
                    color: _recording ? Colors.red : null,
                  ),
                  label: Text(
                    _recording
                        ? 'Stop video '
                              '(${DateTime.now().difference(_recordingSince!).inSeconds}s)'
                        : 'Record video',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: enabled && !_recording ? _switchLense : null,
                  icon: const Icon(Icons.cameraswitch_outlined),
                  label: Text('Use ${_otherLense(_lense).name}'),
                ),
                OutlinedButton(
                  onPressed: enabled && !_capturing
                      ? () => _captureSelfie('Manual selfie')
                      : null,
                  child: const Text('Capture selfie'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-capture selfie on a good face'),
              subtitle: const Text(
                '1 face, inside frame, not too small/big, eyes open',
              ),
              value: _autoCapture,
              onChanged: (bool v) => setState(() => _autoCapture = v),
            ),
          ]),
          _Section('Analyser', <Widget>[
            Text(
              _analysing
                  ? '$_fps frames/s delivered'
                  : 'Analyser off — tap "Start analyser"',
            ),
            if (stalled)
              Text(
                'No frames for ${silentFor}s — analyser stalled?',
                style: const TextStyle(color: Colors.red),
              ),
            if (d != null) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _Flag('Faces: ${d.faceCount}', d.faceCount == 1),
                  _Flag('In frame', d.isFaceInsideFrame),
                  _Flag('Small', d.isSmallFace, warn: true),
                  _Flag('Big', d.isBigFace, warn: true),
                  _Flag('Eyes closed', d.isEyeClosed, warn: true),
                  _Flag('Smiling', d.isSmiling),
                  _Flag('Left', d.isLookingLeft),
                  _Flag('Right', d.isLookingRight),
                  _Flag('Up', d.isLookingUp),
                  _Flag('Down', d.isLookingDown),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Yaw ${d.headEulerAngleY.toStringAsFixed(1)}° · '
                'Pitch ${d.headEulerAngleX.toStringAsFixed(1)}° · '
                'Roll ${d.headEulerAngleZ.toStringAsFixed(1)}°\n'
                'Brightness ${d.brightness.toStringAsFixed(2)} '
                '(SDK asks for more light below 0.40)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _isGoodFace(d) ? 'Good face ✓' : 'Not capturable yet',
                style: TextStyle(
                  color: _isGoodFace(d) ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ]),
          if (_selfie != null)
            _Section('Selfie', <Widget>[
              _ResultImage(_selfie!, _selfieInfo),
              TextButton(
                onPressed: () => setState(() => _selfie = null),
                child: const Text('Clear (re-arms auto-capture)'),
              ),
            ]),
          if (_videoPath != null)
            _Section('Video', <Widget>[
              Text(_videoInfo),
              TextButton(
                onPressed: isBusy ? null : _deleteVideo,
                child: const Text('Delete video file'),
              ),
            ]),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.label, this.on, {this.warn = false});
  final String label;
  final bool on;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final Color color = warn ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: on ? color.withAlpha(40) : Colors.transparent,
        border: Border.all(color: on ? color : Colors.grey.shade400),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: TextStyle(color: on ? color : Colors.grey)),
    );
  }
}

//! ========================================================== Lifecycle screen
/// Each screen owns its own camera. "Replace" is the pushReplacement case:
/// the old screen is disposed after the new one has started its camera, which
/// must not kill the new preview.
class LifecycleScreen extends StatefulWidget {
  const LifecycleScreen({super.key, required this.generation});
  final int generation;

  @override
  State<LifecycleScreen> createState() => _LifecycleScreenState();
}

class _LifecycleScreenState extends State<LifecycleScreen>
    with _BenchState<LifecycleScreen> {
  late final OnCameraController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OnCameraController(
      cameraLense: CameraLense.back,
      resolution: Resolution.medium,
      enableAudio: false,
      onStatusChanged: onStatus,
    );
  }

  Route<void> _next() => MaterialPageRoute<void>(
    builder: (_) => LifecycleScreen(generation: widget.generation + 1),
  );

  Future<void> _probe() =>
      run('Photo from camera #${widget.generation}', () async {
        final Uint8List? bytes = await _controller.takePhoto();
        if (bytes == null) throw 'camera not ready';
        toast('Camera #${widget.generation} works · ${_kb(bytes.length)}');
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera screen #${widget.generation}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Preview(controller: _controller),
          const SizedBox(height: 8),
          _StatusLog(statusLog),
          _Section('Actions', <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacement(_next()),
                  child: const Text('Replace with new camera screen'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(_next()),
                  child: const Text('Push camera screen on top'),
                ),
                OutlinedButton(
                  onPressed: isReady && !isBusy ? _probe : null,
                  child: const Text('Take test photo'),
                ),
              ],
            ),
          ]),
          _Section('What to check', const <Widget>[
            Text(
              '• Replace: the new preview must stay live after the old screen '
              'is disposed, and "Take test photo" must work.\n'
              '• Push on top, then back: this screen shows "Starting '
              'camera…" while covered (only one camera can be open) and must '
              'come back live after the pop.\n'
              '• Send the app to the background and return: the preview must '
              'come back live.\n'
              '• Leave with back: the camera indicator (green dot) must turn '
              'off.',
            ),
          ]),
        ],
      ),
    );
  }
}

//! ============================================================== Cache report
/// Lists image/video files left in the app's data folder. Camera captures
/// are named CAP… by the camera plugins and should be deleted by the package.
///
/// The whole app folder is scanned because the plugins don't write to
/// `Directory.systemTemp` on Android: that is `code_cache`, while CameraX
/// saves to the cache dir. The parent of systemTemp is the app root on both
/// platforms (Android `/data/user/0/<app>`, iOS the sandbox).
Future<void> _showCacheReport(BuildContext context) async {
  final Directory root = Directory.systemTemp.parent;
  final List<File> captures = <File>[];
  final List<File> otherImages = <File>[];
  final List<File> videos = <File>[];
  await _walk(root, (File file) {
    final String name = file.uri.pathSegments.last;
    final String lower = name.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
      videos.add(file);
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      (name.startsWith('CAP') ? captures : otherImages).add(file);
    }
  });
  if (!context.mounted) return;

  String list(List<File> files) => files.isEmpty
      ? ''
      : '\n${files.map((File f) => '  • ${f.uri.pathSegments.last}').join('\n')}';

  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Cache report'),
      content: SingleChildScrollView(
        child: Text(
          'Scanned: ${root.path}\n\n'
          'Camera photos (expected 0): ${captures.length}${list(captures)}\n\n'
          'Other images: ${otherImages.length}${list(otherImages)}\n\n'
          'Videos: ${videos.length}${list(videos)}',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            for (final File f in <File>[
              ...captures,
              ...otherImages,
              ...videos,
            ]) {
              try {
                await f.delete();
              } catch (_) {}
            }
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: const Text('Delete all'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Recursive listing that skips unreadable folders instead of stopping.
Future<void> _walk(Directory dir, void Function(File file) onFile) async {
  try {
    await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
      if (entity is File) {
        onFile(entity);
      } else if (entity is Directory) {
        await _walk(entity, onFile);
      }
    }
  } catch (_) {
    // Unreadable folder: keep what was found so far
  }
}
