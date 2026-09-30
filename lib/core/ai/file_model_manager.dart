import 'dart:async';
import 'dart:io';

import 'package:offline_study_assistant/core/ai/model_downloader.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/core/ai/model_spec.dart';
import 'package:offline_study_assistant/core/net/network_monitor.dart';

/// [ModelManager] that keeps the model in one directory.
///
/// Files: `<name>` once verified, `<name>.part` while downloading, and
/// `<name>.sha256`, a marker saying the file was verified (so startup doesn't
/// hash 600 MB every time).
class FileModelManager implements ModelManager {
  FileModelManager({
    required this.spec,
    required String directory,
    required ModelDownloader downloader,
    required NetworkMonitor network,
    required bool Function() wifiOnly,
    Future<String> Function(String path) hashFile = sha256OfFile,
    this.progressInterval = const Duration(milliseconds: 200),
  }) : _directory = directory,
       _downloader = downloader,
       _network = network,
       _wifiOnly = wifiOnly,
       _hashFile = hashFile;

  final ModelSpec spec;
  final String _directory;
  final ModelDownloader _downloader;
  final NetworkMonitor _network;
  final bool Function() _wifiOnly;
  final Future<String> Function(String path) _hashFile;

  /// Minimum time between two progress states.
  final Duration progressInterval;

  final _states = StreamController<ModelState>.broadcast();
  ModelState _state = const ModelChecking();
  DownloadCancelToken? _cancel;
  Future<void>? _running;

  File get _file => File('$_directory/${spec.fileName}');
  File get _part => File('${_file.path}.part');
  File get _marker => File('${_file.path}.sha256');

  @override
  ModelState get state => _state;

  @override
  Stream<ModelState> get states => _states.stream;

  void _emit(ModelState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  @override
  Future<void> refresh() async {
    if (_running != null) return;
    _emit(const ModelChecking());
    try {
      if (_file.existsSync()) {
        if (_file.lengthSync() == spec.sizeBytes) {
          if (_isMarkedVerified()) return _emit(ModelReady(_file.path));
          // E.g. a file copied by hand: verify it once.
          _emit(const ModelChecking(verifying: true));
          if (await _hashFile(_file.path) == spec.sha256) {
            _marker.writeAsStringSync(spec.sha256);
            return _emit(ModelReady(_file.path));
          }
        }
        _file.deleteSync();
        if (_marker.existsSync()) _marker.deleteSync();
      }
      _emit(
        ModelNotDownloaded(
          partialBytes: _partialBytes(),
          totalBytes: spec.sizeBytes,
        ),
      );
    } on FileSystemException catch (e) {
      _emit(
        ModelFailed(
          ModelErrorKind.storage,
          totalBytes: spec.sizeBytes,
          detail: '$e',
        ),
      );
    }
  }

  @override
  Future<void> download() {
    if (_state is ModelReady) return Future.value();
    return _running ??= _download().whenComplete(() => _running = null);
  }

  Future<void> _download() async {
    final wifiOnly = _wifiOnly();
    if (wifiOnly && !await _network.isOnWifi()) {
      return _fail(ModelErrorKind.wifiRequired);
    }

    final cancel = _cancel = DownloadCancelToken();
    var lostWifi = false;
    final wifiChanges = wifiOnly
        ? _network.onWifiChanged.listen((onWifi) {
            if (onWifi) return;
            lostWifi = true;
            cancel.cancel();
          })
        : null;

    try {
      Directory(_directory).createSync(recursive: true);
      _emit(
        ModelDownloading(
          receivedBytes: _partialBytes(),
          totalBytes: spec.sizeBytes,
        ),
      );
      final sinceProgress = Stopwatch()..start();
      final completed = await _downloader.download(
        url: spec.url,
        partFile: _part,
        totalBytes: spec.sizeBytes,
        cancel: cancel,
        onProgress: (received) {
          if (sinceProgress.elapsed < progressInterval) return;
          sinceProgress.reset();
          _emit(
            ModelDownloading(
              receivedBytes: received,
              totalBytes: spec.sizeBytes,
            ),
          );
        },
      );

      if (!completed) {
        if (lostWifi) return _fail(ModelErrorKind.wifiRequired);
        return _emit(
          ModelNotDownloaded(
            partialBytes: _partialBytes(),
            totalBytes: spec.sizeBytes,
          ),
        );
      }

      _emit(const ModelChecking(verifying: true));
      final hash = await _hashFile(_part.path);
      if (hash != spec.sha256) {
        _part.deleteSync();
        return _fail(
          ModelErrorKind.checksum,
          'Expected ${spec.sha256}, got $hash',
        );
      }
      _part.renameSync(_file.path);
      _marker.writeAsStringSync(spec.sha256);
      _emit(ModelReady(_file.path));
    } on ModelDownloadException catch (e) {
      _fail(e.kind, e.message);
    } on FileSystemException catch (e) {
      _fail(ModelErrorKind.storage, '$e');
    } finally {
      await wifiChanges?.cancel();
      _cancel = null;
    }
  }

  void _fail(ModelErrorKind kind, [String? detail]) {
    _emit(
      ModelFailed(
        kind,
        partialBytes: _partialBytes(),
        totalBytes: spec.sizeBytes,
        detail: detail,
      ),
    );
  }

  bool _isMarkedVerified() =>
      _marker.existsSync() && _marker.readAsStringSync().trim() == spec.sha256;

  int _partialBytes() {
    try {
      return _part.existsSync() ? _part.lengthSync() : 0;
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Future<void> pause() async {
    _cancel?.cancel();
    await _running;
  }

  @override
  Future<void> dispose() async {
    await pause();
    await _states.close();
  }
}
