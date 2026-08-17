import 'dart:io';

import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class RecordedVoice {
  const RecordedVoice({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Stopwatch _stopwatch = Stopwatch();
  String? _path;

  bool get isRecording => _stopwatch.isRunning;
  Duration get elapsed => _stopwatch.elapsed;

  Future<void> start() async {
    if (isRecording) return;
    if (!await _recorder.hasPermission()) {
      throw StateError('microphone_permission_denied');
    }
    final root = await getApplicationSupportDirectory();
    final directory = Directory(paths.join(root.path, 'voice_outbox'));
    await directory.create(recursive: true);
    _path = paths.join(directory.path, '${const Uuid().v4()}.m4a');
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: _path!,
    );
    _stopwatch
      ..reset()
      ..start();
  }

  Future<RecordedVoice?> stop() async {
    if (!isRecording) return null;
    _stopwatch.stop();
    final duration = _stopwatch.elapsed;
    final path = await _recorder.stop() ?? _path;
    _path = null;
    return path == null ? null : RecordedVoice(path: path, duration: duration);
  }

  Future<void> cancel() async {
    _stopwatch
      ..stop()
      ..reset();
    await _recorder.cancel();
    _path = null;
  }

  Future<void> dispose() => _recorder.dispose();
}
